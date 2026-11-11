import Foundation
import Combine
import WebKit
import Vision
import UIKit

// Local diagnostics: no screenshots, page contents or credentials are sent to any server.
@MainActor
final class PageReader: ObservableObject {
    @Published var isBusy=false
    @Published var status="Leitor ainda não testado nesta página."
    @Published var domTokens:[String]=[]
    @Published var imageTokens:[String]=[]
    @Published var canvasCount=0
    @Published var svgCount=0
    @Published var imgCount=0
    @Published var cssBackgroundCount=0
    @Published var frameCount=0
    @Published var rankClues:[String]=[]

    private func isBrasa(_ url:URL?) -> Bool {
        guard let host=url?.host?.lowercased() else {return false}
        return host == "brasa.poker" || host.hasSuffix(".brasa.poker")
    }

    func inspectPage(_ webView:WKWebView) {
        guard !isBusy else{return}
        guard isBrasa(webView.url) else {
            status="Diagnóstico disponível somente em brasa.poker.";return
        }
        isBusy=true
        status="Inspecionando elementos visíveis..."
        let script = #"""
        (() => {
          const visible = el => {
            if (!el || !el.getBoundingClientRect) return false;
            const r=el.getBoundingClientRect();
            const st=window.getComputedStyle(el);
            return r.width>0 && r.height>0 && st.visibility!=='hidden' && st.display!=='none';
          };
          const text=(document.body?.innerText||'').slice(0,30000);
          const attributes=Array.from(document.querySelectorAll('[aria-label],[title],img[alt]'))
            .filter(visible).slice(0,500)
            .map(el=>[el.getAttribute('aria-label'),el.getAttribute('title'),el.getAttribute('alt')].filter(Boolean).join(' '))
            .join(' ');
          const tokens=(text+' '+attributes).match(/(?:10|[2-9AJQK])\s*[♠♣♥♦]/gi)||[];
          const visibleElements = Array.from(document.querySelectorAll('body *')).filter(visible);
          let backgroundCount=0;
          for (const el of visibleElements.slice(0,3500)) {
            if (window.getComputedStyle(el).backgroundImage !== 'none') backgroundCount++;
          }
          return {canvas:document.querySelectorAll('canvas').length,
                  svg:document.querySelectorAll('svg').length,
                  img:visibleElements.filter(el=>el.tagName==='IMG').length,
                  backgrounds:backgroundCount,
                  frames:document.querySelectorAll('iframe').length,
                  tokens:Array.from(new Set(tokens.map(s=>s.replace(/\s/g,'')))).slice(0,15)};
        })()
        """#
        webView.evaluateJavaScript(script){ [weak self] value,error in
            guard let self else{return}
            self.isBusy=false
            if let error {self.status="Falha na inspeção: \(error.localizedDescription)";return}
            guard let result=value as? [String:Any] else { self.status="O navegador não retornou elementos utilizáveis.";return }
            self.canvasCount=result["canvas"] as? Int ?? 0
            self.svgCount=result["svg"] as? Int ?? 0
            self.imgCount=result["img"] as? Int ?? 0
            self.cssBackgroundCount=result["backgrounds"] as? Int ?? 0
            self.frameCount=result["frames"] as? Int ?? 0
            self.domTokens=result["tokens"] as? [String] ?? []
            self.status=self.domTokens.isEmpty
              ? "Texto HTML não contém cartas legíveis. Verifique imagens, estilos CSS, SVG e teste OCR. A leitura ainda não foi validada."
              : "Possíveis cartas no HTML. A posição e a origem não foram verificadas."
        }
    }

    func inspectImage(_ webView:WKWebView) {
        guard !isBusy else{return}
        guard isBrasa(webView.url) else {
            status="Leitura visual disponível somente em brasa.poker.";return
        }
        isBusy=true
        status="Analisando imagem localmente no iPhone..."
        webView.takeSnapshot(with:nil) { [weak self] image,error in
            guard let self else{return}
            guard let cgImage=image?.cgImage else {
                self.isBusy=false
                self.status="Falha na captura da página: \(error?.localizedDescription ?? "erro desconhecido")"
                return
            }
            DispatchQueue.global(qos:.userInitiated).async {
                let request=VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                do {
                    try VNImageRequestHandler(cgImage:cgImage).perform([request])
                    let observations=request.results ?? []
                    let lines=observations.compactMap { $0.topCandidates(1).first?.string }
                    // Collect rank-like OCR fragments only near the lower center,
                    // where the player's cards appear in the supplied 6-max screenshot.
                    // A rank alone cannot identify a card, and these are NOT reliable detections.
                    var possibleRanks=[String]()
                    for obs in observations {
                        guard obs.boundingBox.midY < 0.47,
                              obs.boundingBox.midX > 0.30,
                              obs.boundingBox.midX < 0.92,
                              let candidate=obs.topCandidates(1).first else {continue}
                        let value=candidate.string.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
                        guard ["A","K","Q","J","10","9","8","7","6","5","4","3","2"].contains(value) else {continue}
                        let xpos=Int(obs.boundingBox.midX*100)
                        let ypos=Int((1-obs.boundingBox.midY)*100)
                        possibleRanks.append("\(value) (x\(xpos)%, y\(ypos)%)")
                    }
                    let regex=try NSRegularExpression(pattern:"(?i)(?:10|[2-9AJQK])\\s*[♠♣♥♦]")
                    var matches=[String]()
                    for line in lines {
                        let range=NSRange(line.startIndex..<line.endIndex,in:line)
                        for match in regex.matches(in:line,range:range) {
                            if let r=Range(match.range,in:line) {
                                let token=String(line[r]).replacingOccurrences(of:" ",with:"")
                                if !matches.contains(token) {matches.append(token)}
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.isBusy=false
                        self.imageTokens=Array(matches.prefix(15))
                        self.rankClues=Array(possibleRanks.prefix(12))
                        self.status=matches.isEmpty
                          ? "OCR concluído. Os símbolos dos naipes não foram confirmados. Veja pistas de valores isolados, se disponíveis."
                          : "OCR gerou candidatos, mas sem confirmação de quais cartas pertencem à mesa."
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isBusy=false
                        self.status="Falha no OCR: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

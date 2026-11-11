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

    func inspectPage(_ webView:WKWebView) {
        guard !isBusy else{return}
        guard webView.url?.host?.lowercased().hasSuffix("brasa.poker")==true else {
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
          return {canvas:document.querySelectorAll('canvas').length,
                  svg:document.querySelectorAll('svg').length,
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
            self.domTokens=result["tokens"] as? [String] ?? []
            self.status=self.domTokens.isEmpty
              ? "Nenhuma carta identificada no texto da página. Elas podem ser imagens ou Canvas."
              : "Possíveis cartas no HTML. A posição e a origem não foram verificadas."
        }
    }

    func inspectImage(_ webView:WKWebView) {
        guard !isBusy else{return}
        guard webView.url?.host?.lowercased().hasSuffix("brasa.poker")==true else {
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
                    let lines=(request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
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
                        self.status=matches.isEmpty
                          ? "OCR concluído; nenhuma carta reconhecida com segurança."
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

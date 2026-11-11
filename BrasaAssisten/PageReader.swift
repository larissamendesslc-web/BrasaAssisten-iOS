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
    @Published var liveTokens:[String]=[]
    @Published var liveBoard:[String]=[]
    @Published var liveSource="nenhuma"
    @Published var boardRankHints:[String]=[]
    @Published var boardNeedsReview=false
    @Published var liveStatus="Aguardando cartas"
    @Published var handSerial=0
    @Published var streetLabel="Pré-flop"
    @Published var diagnosticReport="Nenhum diagnóstico registrado."
    private var handSession=HandSession()
    private var scanPending=false
    private var pendingSnapshotKey=""
    private var stableSamples=0

    // Fast, local, read-only scan; never reads network calls, private state,
    // cookies, passwords or hidden opponent cards.
    // The mini-card display near the TOP is considered the main source of
    // the user's cards. Community cards come from the MIDDLE of the viewport.
    func quickScan(_ webView:WKWebView) {
        guard !scanPending, isBrasa(webView.url) else { return }
        scanPending=true
        let script = #"""
        (() => {
          const W=innerWidth,H=innerHeight;
          if (!W || !H || !document.body) return {hero:[],board:[],source:"empty",boardHint:[]};
          const full=/(?:10|[2-9AJQK])\s*[♠♣♥♦]/gi;
          const rankOnly=/^(?:10|[2-9AJQK])$/i;
          const suitOnly=/^[♠♣♥♦]$/;
          const pts=[],ranks=[],suits=[];
          const isShown=e=>{
            if (!e || !e.getBoundingClientRect) return false;
            const r=e.getBoundingClientRect(),style=getComputedStyle(e);
            return r.width>0 && r.height>0 && style.display!=="none" &&
                   style.visibility!=="hidden" && r.bottom>0 && r.top<H;
          };
          const push=(value,x,y,source)=>{
            const token=value.toUpperCase().replace(/\s+/g,"");
            if (!/^(?:10|[2-9AJQK])[♠♣♥♦]$/.test(token)) return;
            if (x<0 || x>W || y<0 || y>H) return;
            pts.push({token,x,y,source});
          };
          const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
          let node,n=0;
          while((node=walker.nextNode()) && n++<3200) {
            const parent=node.parentElement;
            const text=node.textContent||"";
            if (!text.trim() || text.length>100) continue;
            const clean=text.trim().toUpperCase();
            const isPart=rankOnly.test(clean) || suitOnly.test(clean);
            full.lastIndex=0;
            if (!isPart && !full.test(text)) continue;
            if (!isShown(parent) || ["SCRIPT","STYLE","NOSCRIPT"].includes(parent.tagName)) continue;
            full.lastIndex=0;
            let match;
            while((match=full.exec(text))!==null) {
              const range=document.createRange();
              try {
                range.setStart(node,match.index);
                range.setEnd(node,match.index+match[0].length);
                const rect=range.getBoundingClientRect();
                if(rect.width>0 && rect.height>0)
                  push(match[0],rect.left+rect.width/2,rect.top+rect.height/2,"text");
              } catch(_) {}
            }
            const clean=text.trim().toUpperCase();
            if ((rankOnly.test(clean)||suitOnly.test(clean)) && text.length<=6) {
              const range=document.createRange();
              range.selectNodeContents(node);
              const rect=range.getBoundingClientRect();
              if (rect.width<=0 || rect.height<=0) continue;
              const point={value:clean,x:rect.left+rect.width/2,y:rect.top+rect.height/2};
              if(rankOnly.test(clean)) ranks.push(point);
              else suits.push(point);
            }
          }
          // Cards may split their rank and suit into neighboring text nodes.
          const usedSuits=new Set();
          for(const r of ranks){
            let best=-1,dist=1e6;
            for(let i=0;i<suits.length;i++){
              if(usedSuits.has(i))continue;
              const dx=Math.abs(suits[i].x-r.x),dy=Math.abs(suits[i].y-r.y);
              if(dx>30 || dy>40)continue;
              const d=dx+dy*0.8;
              if(d<dist){dist=d;best=i}
            }
            if(best>=0){usedSuits.add(best);push(r.value+suits[best].value,r.x,r.y,"split")}
          }
          // Labels and image descriptions may provide card names, independent
          // of whether the rank is drawn as text or an SVG.
          const attrEls=document.querySelectorAll('[aria-label],[title],img[alt]');
          for(let i=0;i<Math.min(attrEls.length,450);i++){
            const el=attrEls[i];
            if(!isShown(el)) continue;
            const label=[el.getAttribute("aria-label"),el.getAttribute("title"),el.getAttribute("alt")].filter(Boolean).join(" ");
            if(label.length>90) continue;
            full.lastIndex=0;
            let m;const rect=el.getBoundingClientRect();
            while((m=full.exec(label))!==null)push(m[0],rect.left+rect.width/2,rect.top+rect.height/2,"attribute");
          }
          // Remove near-duplicates from the same card, not distinct cards.
          const points=[];
          pts.sort((a,b)=>a.y-b.y || a.x-b.x);
          for(const p of pts){
            if(!points.some(q=>q.token===p.token && Math.abs(q.x-p.x)<25 && Math.abs(q.y-p.y)<26)){
              points.push(p);
            }
          }
          const heroTop=points.filter(p=>p.y/H<0.19 && p.x/W>0.20 && p.x/W<0.80).sort((a,b)=>a.x-b.x);
          const heroBottom=points.filter(p=>p.y/H>0.72 && p.x/W>0.28 && p.x/W<0.88).sort((a,b)=>a.x-b.x);
          const community=points.filter(p=>p.y/H>0.34 && p.y/H<0.70 && p.x/W>0.13 && p.x/W<0.88).sort((a,b)=>a.x-b.x);
          const distinct=xs=>xs.length===new Set(xs).size;
          let hero=[],source="not-found";
          if(heroTop.length===2 && distinct(heroTop.map(p=>p.token))){
            hero=heroTop.map(p=>p.token);source="top";
          }else if(heroBottom.length===2 && distinct(heroBottom.map(p=>p.token))){
            hero=heroBottom.map(p=>p.token);source="bottom";
          }
          // Last-resort fallback, useful when the small top banner is one text
          // node without useful per-card geometry.
          if(hero.length===0) {
            const txt=(document.body.innerText||"").slice(0,12000);
            const matches=(txt.match(/(?:10|[2-9AJQK])\s*[♠♣♥♦]/gi)||[])
              .map(x=>x.toUpperCase().replace(/\s+/g,""));
            if(matches.length===2 && distinct(matches)) {
              hero=matches;source="text-only";
            }
          }
          let board=[];
          if(community.length>=3 && community.length<=5 && distinct(community.map(p=>p.token))){
            board=community.map(p=>p.token);
          }
          // If three or more ranks are visible in the board's area but their
          // suits are not resolved, never assume this is still pre-flop.
          const boardHints=ranks.filter(p=>p.y/H>0.34 && p.y/H<0.70 && p.x/W>0.13 && p.x/W<0.88)
            .sort((a,b)=>a.x-b.x).map(p=>p.value).slice(0,7);
          return {hero,board,source,boardHint:boardHints,
                  boardNeedsReview:board.length===0 && boardHints.length>=3};
        })()
        """#
        webView.evaluateJavaScript(script) { [weak self] result,error in
            guard let self else {return}
            self.scanPending=false
            guard error == nil, let data=result as? [String:Any] else {
                self.pendingSnapshotKey=""
                self.stableSamples=0
                self.liveStatus="Leitura indisponível"
                return
            }
            let hero=data["hero"] as? [String] ?? []
            let board=data["board"] as? [String] ?? []
            let hints=data["boardHint"] as? [String] ?? []
            let pending=data["boardNeedsReview"] as? Bool ?? false
            let source=data["source"] as? String ?? "unknown"
            let validHero=hero.count==2 && PokerEngine.parseCards(hero.joined(separator:" "))?.count==2
            let validBoard=[0,3,4,5].contains(board.count)
            let all=hero+board
            let validCards=PokerEngine.parseCards(all.joined(separator:" "))?.count == all.count
            if !validHero || !validBoard || !validCards {
                self.pendingSnapshotKey=""
                self.stableSamples=0
                self.liveTokens=[]
                self.liveBoard=[]
                self.boardRankHints=hints
                self.boardNeedsReview=pending
                self.liveStatus="Não foi possível validar as cartas."
                return
            }
            let key=hero.joined(separator:"|") + "/" + board.joined(separator:"|") + "/" + String(pending)
            if self.pendingSnapshotKey == key {self.stableSamples += 1}
            else {self.pendingSnapshotKey=key;self.stableSamples=1}
            // Two equal samples are normally taken ~0.6 sec apart.
            guard self.stableSamples>=2 else {return}
            guard let parsedHero=PokerEngine.parseCards(hero.joined(separator:" ")),
                  let parsedBoard=PokerEngine.parseCards(board.joined(separator:" ")) else {
                self.liveTokens=[]
                self.liveBoard=[]
                self.boardNeedsReview=true
                self.liveStatus="Leitura inválida, aguardando cartas novas."
                return
            }
            let change=self.handSession.ingest(hero:parsedHero, board:parsedBoard, uncertain:pending)
            self.boardRankHints=hints
            self.liveSource=source
            self.handSerial=self.handSession.serial
            self.streetLabel=self.handSession.street.rawValue
            let report="BrasaAssisten scanner / mão #" + String(self.handSerial)
                + "\nEtapa: " + self.streetLabel
                + "\nLeitura: " + source
                + "\nMão (provisória): " + hero.joined(separator:" ")
                + "\nMesa (provisória): " + board.joined(separator:" ")
                + "\nValores comunitários candidatos: " + hints.joined(separator:" ")
                + "\nComunidade incerta: " + String(pending)
                + "\nTransição: " + String(describing:change)
            if self.diagnosticReport != report {self.diagnosticReport=report}
            switch change {
            case .newHand, .advanced, .unchanged:
                self.liveTokens=hero
                self.liveBoard=board
                self.boardNeedsReview=self.handSession.boardUncertain
                self.liveStatus=self.boardNeedsReview
                  ? "Comunitárias incompletas. Aguarde ou corrija."
                  : board.isEmpty ? "Pré-flop detectado (prévia)"
                    : "\(self.streetLabel): \(board.count) cartas (prévia)"
            case .boardUncertain:
                self.liveTokens=hero
                self.liveBoard=[]
                self.boardNeedsReview=true
                self.liveStatus="A mesa mudou, mas as cartas não estão confirmadas."
            case .invalid, .awaiting:
                self.liveTokens=[]
                self.liveBoard=[]
                self.boardNeedsReview=true
                self.liveStatus="Leitura inválida."
            }
        }
    }

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

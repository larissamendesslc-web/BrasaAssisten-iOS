import SwiftUI
import Combine
import UIKit

/// Official-style HUD: the table remains the primary surface. Developer tools
/// are accessible only from a long press on the BrasaAssisten title.
struct ContentView: View {
    @StateObject private var browser = BrasaBrowser()
    @StateObject private var reader = PageReader()
    @StateObject private var equityEstimator = EquityEstimator()

    @State private var isPanelOpen = false
    @State private var showDetails = false
    @State private var showCorrections = false
    @State private var showDeveloperTools = false
    @State private var holeInput = ""
    @State private var boardInput = ""
    @State private var opponents = 1
    @State private var floatingOffset = CGSize.zero
    @GestureState private var floatingDrag = CGSize.zero
    @State private var panelLift: CGFloat = 0
    @GestureState private var panelDrag: CGFloat = 0

    private let gold = Color(red: 0.99, green: 0.72, blue: 0.27)
    private let background = Color(red: 0.10, green: 0.065, blue: 0.073)

    private var hole: [PlayingCard]? {
        let manual=holeInput.trimmingCharacters(in:.whitespacesAndNewlines)
        return PokerEngine.parseCards(
            manual.isEmpty ? reader.liveTokens.joined(separator:" ") : manual
        )
    }
    private var board: [PlayingCard]? {
        let manual=boardInput.trimmingCharacters(in:.whitespacesAndNewlines)
        return PokerEngine.parseCards(
            manual.isEmpty ? reader.liveBoard.joined(separator:" ") : manual
        )
    }

    private var insight: CoachReport {
        if reader.boardNeedsReview && boardInput.isEmpty {
            return CoachReport(tone:"neutral",action:"MESA INCOMPLETA",
                title:"Aguardando os naipes",
                reason:"Encontrei valores comunitários, mas não consegui confirmar todas as cartas. A análise anterior foi suspensa.",
                alternatives:["O leitor continua procurando as cartas.",
                              "Você também pode corrigir a mesa manualmente."],
                alerts:[],confidence:"Leitura parcial",
                street:reader.streetLabel,estimatedEquity:nil,
                callThreshold:nil,handName:"—")
        }
        guard let h=hole, let b=board else {
            return PokerCoach.assess(hole:[],board:[])
        }
        return PokerCoach.assess(
            hole:h,board:b,
            pot:PotMath.parseBRL(reader.observedPot),
            toCall:PotMath.parseBRL(reader.amountToCall),
            equity:equityEstimator.equity,
            confirmed:!holeInput.isEmpty && (b.isEmpty || !boardInput.isEmpty)
        )
    }

    private var signal: Color {
        switch insight.tone {
        case "green": return Color(red:0.14,green:0.79,blue:0.38)
        case "yellow": return Color(red:1.0,green:0.70,blue:0.18)
        case "red": return Color(red:0.96,green:0.25,blue:0.29)
        default: return gold
        }
    }

    private func refreshEquity() {
        if reader.boardNeedsReview && boardInput.isEmpty {
            equityEstimator.refresh(hole:nil,board:nil,opponents:opponents)
            return
        }
        equityEstimator.refresh(hole:hole,board:board,opponents:opponents)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment:.bottom) {
                Color.black.ignoresSafeArea()
                BrowserView(browser:browser).ignoresSafeArea(edges:.bottom)

                if isPanelOpen {
                    VStack {
                        Spacer()
                        if showDetails { detailPanel }
                        else { quickPanel }
                    }
                    .padding(.horizontal, 10)
                    // Keep the poker controls at the bottom unobstructed.
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 8)+122)
                    .offset(y:panelLift + panelDrag)
                    .transition(.move(edge:.bottom).combined(with:.opacity))
                    .zIndex(10)
                } else {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response:0.3)) {
                                    showDetails=false
                                    isPanelOpen=true
                                }
                            } label: {
                                Image(systemName:"flame.fill")
                                    .font(.system(size:22,weight:.bold))
                                    .foregroundStyle(.orange)
                                    .frame(width:54,height:54)
                                    .background(background.opacity(0.94),in:Circle())
                                    .overlay(Circle().stroke(signal,lineWidth:2.5))
                                    .shadow(color:signal.opacity(0.32),radius:10)
                            }
                            .accessibilityLabel("Abrir BrasaAssisten")
                            .offset(x:floatingOffset.width+floatingDrag.width,
                                    y:floatingOffset.height+floatingDrag.height)
                            .simultaneousGesture(
                                DragGesture(minimumDistance:14)
                                    .updating($floatingDrag) { value,state,_ in
                                        state=value.translation
                                    }
                                    .onEnded { value in
                                        floatingOffset.width=min(0,max(-geometry.size.width+75,
                                            floatingOffset.width+value.translation.width))
                                        floatingOffset.height=min(100,max(-geometry.size.height+180,
                                            floatingOffset.height+value.translation.height))
                                    }
                            )
                            .padding(.trailing,12)
                        }
                        Spacer().frame(height:128)
                    }
                    .zIndex(10)
                }

                if browser.isLoading {
                    VStack {
                        ProgressView().tint(gold)
                        Spacer()
                    }
                    .padding(.top,12)
                    .allowsHitTesting(false)
                }

                if let error=browser.errorText {
                    VStack(spacing:9) {
                        Image(systemName:"wifi.exclamationmark").font(.title)
                        Text("Não foi possível carregar o Brasa Poker").font(.headline)
                        Text(error).font(.footnote).multilineTextAlignment(.center)
                        Button("Tentar novamente") {browser.openHome()}
                            .buttonStyle(.borderedProminent).tint(.orange)
                    }
                    .padding(20)
                    .background(background,in:RoundedRectangle(cornerRadius:18))
                    .padding(20)
                }
            }
        }
        .sheet(isPresented:$showDeveloperTools) { developerSheet }
        .onReceive(Timer.publish(every:0.6,on:.main,in:.common).autoconnect()) { _ in
            reader.quickScan(browser.webView)
        }
        .onReceive(browser.$domRevision.removeDuplicates()
            .debounce(for:.milliseconds(230),scheduler:RunLoop.main)) { _ in
            reader.quickScan(browser.webView)
        }
        .onChange(of:reader.liveTokens) { _ in refreshEquity() }
        .onChange(of:reader.liveBoard) { _ in refreshEquity() }
        .onChange(of:reader.boardNeedsReview) { _ in refreshEquity() }
        .onChange(of:holeInput) { _ in refreshEquity() }
        .onChange(of:boardInput) { _ in refreshEquity() }
        .onChange(of:opponents) { _ in refreshEquity() }
        .onChange(of:reader.handSerial) { _ in
            holeInput=""
            boardInput=""
            refreshEquity()
        }
        .onChange(of:reader.observing) { isObserving in
            if isObserving {holeInput="";boardInput="";refreshEquity()}
        }
    }

    private var header: some View {
        HStack(spacing:7) {
            Image(systemName:"flame.fill")
                .foregroundStyle(.orange)
            Text("BrasaAssisten").font(.system(size:16,weight:.bold))
                .foregroundStyle(gold)
            Spacer(minLength:4)
            Text(reader.streetLabel)
                .font(.system(size:11,weight:.medium))
                .foregroundStyle(.white.opacity(0.65))
            Image(systemName:"line.3.horizontal")
                .font(.system(size:12))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width:24,height:28)
                .gesture(
                    DragGesture(minimumDistance:5)
                        .updating($panelDrag) { value,state,_ in
                            state=value.translation.height
                        }
                        .onEnded { value in
                            panelLift=max(-340,min(160,panelLift+value.translation.height))
                        }
                )
                .accessibilityLabel("Arrastar painel")
            Button {
                withAnimation(.easeInOut(duration:0.2)) {showDetails.toggle()}
            } label: {
                Image(systemName:showDetails
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size:13,weight:.semibold))
                    .frame(width:28,height:30)
            }
            .accessibilityLabel(showDetails ? "Compactar" : "Ver análise completa")
            Button {
                withAnimation(.easeInOut(duration:0.2)) {isPanelOpen=false}
            } label: {
                Image(systemName:"xmark").font(.system(size:15,weight:.semibold))
                    .frame(width:28,height:30)
            }
            .accessibilityLabel("Fechar painel")
        }
        .onLongPressGesture(minimumDuration:1.3) {showDeveloperTools=true}
    }

    private func statusChip(_ text:String,_ tone:String) -> some View {
        let selected=insight.tone==tone
        let color=tone=="green" ? Color.green :
                  tone=="yellow" ? Color.orange : Color.red
        return Text(text)
            .font(.system(size:10,weight:.bold))
            .frame(maxWidth:.infinity)
            .padding(.vertical,7)
            .background(color.opacity(selected ? 0.94 : 0.13),
                        in:RoundedRectangle(cornerRadius:8))
            .foregroundStyle(selected ? Color.black : Color.white.opacity(0.55))
    }

    private var quickPanel: some View {
        VStack(alignment:.leading,spacing:9) {
            header
            HStack(spacing:5) {
                statusChip("DESISTIR","red")
                statusChip("CAUTELA","yellow")
                statusChip("FORTE","green")
            }
            HStack(alignment:.center,spacing:10) {
                RoundedRectangle(cornerRadius:3)
                    .fill(signal)
                    .frame(width:5,height:50) // Never allow an infinite vertical shape.
                VStack(alignment:.leading,spacing:3) {
                    Text(insight.action)
                        .font(.system(size:18,weight:.heavy))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(insight.title)
                        .font(.system(size:12,weight:.medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
                Spacer(minLength:0)
            }
            .padding(9)
            .background(signal.opacity(0.10),
                        in:RoundedRectangle(cornerRadius:11))

            if !reader.liveTokens.isEmpty || !reader.liveBoard.isEmpty {
                HStack(spacing:8) {
                    if !reader.liveTokens.isEmpty {
                        Text("Mão: "+reader.liveTokens.joined(separator:" "))
                            .lineLimit(1)
                    } else {
                        Text("Observando")
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    Spacer(minLength:0)
                    if !reader.liveBoard.isEmpty {
                        Text("Mesa: "+reader.liveBoard.joined(separator:" "))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .font(.system(size:11,weight:.semibold))
                .foregroundStyle(gold)
            } else if reader.boardNeedsReview {
                Text("Mesa incompleta: "+reader.boardRankHints.joined(separator:" "))
                    .font(.caption).foregroundStyle(.orange).lineLimit(1)
            }

            Text(insight.reason)
                .font(.system(size:11))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(2)
                .fixedSize(horizontal:false,vertical:true)

            HStack {
                if !reader.observedPot.isEmpty {
                    Text("Pote: BRL "+reader.observedPot)
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
                Button("Análise completa") {
                    withAnimation(.easeInOut(duration:0.2)) {showDetails=true}
                }
                .foregroundStyle(gold)
            }
            .font(.system(size:11,weight:.medium))
        }
        .padding(12)
        .frame(maxWidth:.infinity)
        .fixedSize(horizontal:false,vertical:true)
        .foregroundStyle(.white)
        .background(background,in:RoundedRectangle(cornerRadius:18))
        .overlay(RoundedRectangle(cornerRadius:18)
            .stroke(gold.opacity(0.85),lineWidth:1))
        .shadow(color:.black.opacity(0.36),radius:9)
        .accessibilityElement(children:.contain)
    }

    private var detailPanel: some View {
        VStack(alignment:.leading,spacing:0) {
            header.padding(.horizontal,13).padding(.top,12).padding(.bottom,8)
            ScrollView {
                VStack(alignment:.leading,spacing:11) {
                    HStack(spacing:5) {
                        statusChip("DESISTIR","red")
                        statusChip("CAUTELA","yellow")
                        statusChip("FORTE","green")
                    }
                    HStack(alignment:.top,spacing:10) {
                        RoundedRectangle(cornerRadius:3)
                            .fill(signal).frame(width:5,height:58)
                        VStack(alignment:.leading,spacing:4) {
                            Text(insight.action).font(.title3).bold()
                            Text(insight.title).font(.subheadline)
                            Text(insight.reason)
                                .font(.caption).foregroundStyle(.white.opacity(0.78))
                        }
                        Spacer(minLength:0)
                    }
                    .padding(10)
                    .background(signal.opacity(0.12),
                        in:RoundedRectangle(cornerRadius:11))

                    HStack {
                        Label(reader.observing ? "Observando" : "Jogando",
                              systemImage:reader.observing ? "eye" : "suit.spade.fill")
                        Spacer()
                        Text(insight.confidence)
                            .lineLimit(1).minimumScaleFactor(0.78)
                    }
                    .font(.system(size:11))
                    .foregroundStyle(.white.opacity(0.70))
                    if !reader.liveTokens.isEmpty {
                        Text("Suas cartas: "+reader.liveTokens.joined(separator:" "))
                            .font(.subheadline).foregroundStyle(gold)
                    }
                    if !reader.liveBoard.isEmpty {
                        Text("Comunitárias: "+reader.liveBoard.joined(separator:" "))
                            .font(.subheadline).foregroundStyle(gold)
                    }
                    if reader.boardNeedsReview {
                        Text("Alguns naipes não foram confirmados. Valores: "+
                             reader.boardRankHints.joined(separator:" "))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if !reader.observedPot.isEmpty {
                        HStack {
                            Text("Pote BRL "+reader.observedPot)
                            Spacer()
                            if !reader.amountToCall.isEmpty {
                                Text("Pagar BRL "+reader.amountToCall)
                            }
                        }
                        .font(.caption).foregroundStyle(.white.opacity(0.8))
                    }

                    if let value=equityEstimator.equity, hole?.count==2 {
                        VStack(alignment:.leading,spacing:3) {
                            Text(String(format:"Equidade simulada: %.1f%%",value*100))
                                .font(.subheadline).bold()
                            Text("Contra \(opponents) mão(s) aleatória(s), não contra o range real dos jogadores.")
                                .font(.caption2).foregroundStyle(.white.opacity(0.6))
                            if let threshold=insight.callThreshold {
                                Text(String(format:"Preço mínimo de equilíbrio: %.1f%%",threshold*100))
                                    .font(.caption2).foregroundStyle(gold)
                            }
                        }
                    } else if equityEstimator.computing {
                        Text("Calculando equidade matemática…").font(.caption)
                    }

                    if !insight.alerts.isEmpty {
                        Text("RISCOS DA MESA")
                            .font(.caption).bold().foregroundStyle(gold)
                        ForEach(insight.alerts,id:\.self) { item in
                            Label(item,systemImage:"exclamationmark.triangle")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    if !insight.alternatives.isEmpty {
                        Text("POSSIBILIDADES")
                            .font(.caption).bold().foregroundStyle(gold)
                        ForEach(insight.alternatives,id:\.self) { item in
                            Text("• "+item)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }

                    HStack {
                        Text("Simular contra:")
                            .font(.caption).foregroundStyle(.secondary)
                        Picker("Mãos aleatórias",selection:$opponents) {
                            ForEach(1...5,id:\.self) { number in
                                Text("\(number)").tag(number)
                            }
                        }
                        .pickerStyle(.menu).tint(gold)
                        Spacer()
                        Button(showCorrections ? "Ocultar ajustes" : "Ajustar cartas") {
                            withAnimation(.easeInOut(duration:0.2)){
                                showCorrections.toggle()
                            }
                        }
                        .font(.caption).foregroundStyle(gold)
                    }

                    if showCorrections {
                        TextField("Suas cartas: Ke Kd",text:$holeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(.black)
                        TextField("Comunitárias: Qd 7e 6c",text:$boardInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(.black)
                        HStack {
                            Text("a♣ c♥ e♠ d♦")
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button("Limpar ajustes") {
                                holeInput=""
                                boardInput=""
                            }
                            .font(.caption2).foregroundStyle(gold)
                        }
                    }
                    if !reader.visibleShowdown.isEmpty {
                        Text("Cartas reveladas publicamente:")
                            .font(.caption).foregroundStyle(gold)
                        Text(reader.visibleShowdown.map{$0.joined(separator:" ")}
                            .joined(separator:" • "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Análise educacional: nenhuma decisão ou ganho é garantido.")
                        .font(.caption2).foregroundStyle(.white.opacity(0.47))
                }
                .padding(.horizontal,13)
                .padding(.bottom,14)
            }
            .frame(maxHeight:380)
        }
        .foregroundStyle(.white)
        .background(background,in:RoundedRectangle(cornerRadius:18))
        .overlay(RoundedRectangle(cornerRadius:18)
            .stroke(gold.opacity(0.85),lineWidth:1))
        .shadow(color:.black.opacity(0.36),radius:9)
    }

    /// Intentionally excluded from the playing interface.
    private var developerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    Text("Diagnóstico de leitura").font(.title3).bold()
                    Text("Área técnica. Não contém recomendações de apostas.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(reader.liveStatus)
                    Text(reader.diagnosticReport)
                        .font(.system(.caption,design:.monospaced))
                        .textSelection(.enabled)
                    Button("Copiar diagnóstico") {
                        UIPasteboard.general.string=reader.diagnosticReport
                    }
                    .buttonStyle(.bordered)
                    HStack {
                        Button("Inspecionar HTML") {
                            reader.inspectPage(browser.webView)
                        }
                        Button("Testar imagem") {
                            reader.inspectImage(browser.webView)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(reader.isBusy)
                    Text(reader.status).font(.caption)
                    if !reader.domTokens.isEmpty {
                        Text(reader.domTokens.joined(separator:" "))
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("Diagnóstico técnico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button("Fechar") {showDeveloperTools=false}
                }
            }
        }
    }
}

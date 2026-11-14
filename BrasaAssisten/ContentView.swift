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
    @AppStorage("brasa.v2.sideCollapsed") private var sideCollapsed = false
    @AppStorage("brasa.v2.sideOnLeft") private var sideOnLeft = false
    @AppStorage("brasa.v2.sideOffset") private var sideOffset = 0.0
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

    private var safety: RiskReport {
        RiskInspector.assess(
            hole:hole ?? [],
            board:board ?? [],
            uncertain:reader.boardNeedsReview && boardInput.isEmpty
        )
    }

    private var signal: Color {
        switch safety.level {
        case "danger": return Color(red:0.88,green:0.30,blue:0.27)
        case "blocked": return Color(red:0.46,green:0.46,blue:0.49)
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
                                    showDetails=true
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
            .overlay(alignment: sideOnLeft ? .leading : .trailing) {
                // Keep the side HUD on top of the site but outside its touch
                // targets everywhere except the 86pt native HUD surface.
                // The website's original controls and card DOM are untouched.
                if !isPanelOpen {
                    SideHUD(
                        phase: reader.streetLabel,
                        personalCards: reader.liveTokens,
                        communityCards: reader.liveBoard,
                        observing: reader.observing,
                        reviewNeeded: reader.boardNeedsReview,
                        tone: insight.tone,
                        action: insight.action,
                        risk: safety,
                        viewportHeight: geometry.size.height,
                        collapsed: $sideCollapsed,
                        onLeft: $sideOnLeft,
                        verticalOffset: $sideOffset
                    ) {
                        withAnimation(.spring(response:0.3)) {
                            showDetails = true
                            isPanelOpen = true
                        }
                    }
                    .padding(.leading, sideOnLeft ? 2 : 0)
                    .padding(.trailing, sideOnLeft ? 0 : 2)
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
            HStack(spacing:6) {
                Image(systemName:"exclamationmark.triangle.fill")
                    .foregroundStyle(signal)
                Text(safety.label)
                    .font(.system(size:13,weight:.heavy))
                    .foregroundStyle(.white)
                Spacer(minLength:0)
            }
            .padding(.vertical,7)
            .padding(.horizontal,9)
            .background(signal.opacity(0.24),in:RoundedRectangle(cornerRadius:8))
            HStack(alignment:.center,spacing:10) {
                RoundedRectangle(cornerRadius:3)
                    .fill(signal)
                    .frame(width:5,height:50) // Never allow an infinite vertical shape.
                VStack(alignment:.leading,spacing:3) {
                    Text(safety.label)
                        .font(.system(size:18,weight:.heavy))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(safety.hand)
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

            Text(safety.explanation)
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
            header
                .padding(.horizontal,13)
                .padding(.top,12)
                .padding(.bottom,8)
            ScrollView {
                VStack(alignment:.leading,spacing:12) {
                    detailSummary
                    detailCards
                    // Random-opponent equity is withheld from live decision interface.
                    detailWarnings
                    detailControls
                    detailShowdown
                    Text("Análise educacional. Nenhuma jogada ou ganho é garantido.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.47))
                }
                .padding(.horizontal,13)
                .padding(.bottom,14)
            }
            .frame(maxHeight:260)
        }
        .foregroundStyle(.white)
        .background(background,in:RoundedRectangle(cornerRadius:18))
        .overlay(RoundedRectangle(cornerRadius:18)
            .stroke(gold.opacity(0.85),lineWidth:1))
        .shadow(color:.black.opacity(0.36),radius:9)
    }

    private var detailSummary: some View {
        VStack(alignment:.leading,spacing:9) {
            HStack(spacing:6) {
                Image(systemName:"exclamationmark.triangle.fill")
                    .foregroundStyle(signal)
                Text(safety.label)
                    .font(.system(size:13,weight:.heavy))
                    .foregroundStyle(.white)
                Spacer(minLength:0)
            }
            .padding(.vertical,7)
            .padding(.horizontal,9)
            .background(signal.opacity(0.24),in:RoundedRectangle(cornerRadius:8))
            HStack(alignment:.top,spacing:10) {
                RoundedRectangle(cornerRadius:3)
                    .fill(signal)
                    .frame(width:5,height:58)
                VStack(alignment:.leading,spacing:3) {
                    Text(safety.label).font(.title3).bold()
                    Text(safety.hand).font(.subheadline)
                    Text(safety.explanation)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer(minLength:0)
            }
            .padding(10)
            .background(signal.opacity(0.12),
                        in:RoundedRectangle(cornerRadius:11))
        }
    }

    private var detailCards: some View {
        VStack(alignment:.leading,spacing:7) {
            HStack {
                Label(reader.observing ? "Observando" : "Jogando",
                      systemImage:reader.observing ? "eye" : "suit.spade.fill")
                Spacer(minLength:0)
                Text(insight.confidence)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            .font(.system(size:11))
            .foregroundStyle(.white.opacity(0.70))
            if !reader.liveTokens.isEmpty {
                Text("Suas cartas: " + reader.liveTokens.joined(separator:" "))
                    .font(.subheadline)
                    .foregroundStyle(gold)
            }
            if !reader.liveBoard.isEmpty {
                Text("Comunitárias: " + reader.liveBoard.joined(separator:" "))
                    .font(.subheadline)
                    .foregroundStyle(gold)
            }
            if reader.boardNeedsReview {
                Text("Naipes não confirmados. Valores: " +
                     reader.boardRankHints.joined(separator:" "))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !reader.observedPot.isEmpty {
                HStack {
                    Text("Pote BRL " + reader.observedPot)
                    Spacer()
                    if !reader.amountToCall.isEmpty {
                        Text("Pagar BRL " + reader.amountToCall)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var detailOdds: some View {
        VStack(alignment:.leading,spacing:4) {
            if let value=equityEstimator.equity, hole?.count==2 {
                Text(String(format:"Equidade simulada: ≈ %.0f%%",value*100))
                    .font(.subheadline).bold()
                Text("650 simulações contra \(opponents) adversário(s) hipotético(s), não contra os jogadores reais.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
                if let required=insight.callThreshold {
                    Text(String(format:"Equidade matemática de equilíbrio: %.1f%%",required*100))
                        .font(.caption2).foregroundStyle(gold)
                }
            } else if equityEstimator.computing {
                Text("Calculando simulação matemática…")
                    .font(.caption)
            }
        }
    }

    private var detailWarnings: some View {
        VStack(alignment:.leading,spacing:6) {
            Text("RISCOS E LIMITES")
                .font(.caption).bold().foregroundStyle(gold)
            ForEach(safety.alerts,id:\.self) { warning in
                Label(warning,systemImage:"exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text("As cartas adversárias são desconhecidas. Não use este indicador como autorização para apostar.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.67))
        }
    }

    private var detailControls: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text("Conferência de leitura")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button(showCorrections ? "Ocultar ajustes" : "Ajustar cartas") {
                    withAnimation(.easeInOut(duration:0.2)) {
                        showCorrections.toggle()
                    }
                }
                .font(.caption)
                .foregroundStyle(gold)
            }
            if showCorrections {
                TextField("Sua mão: Ke Kd",text:$holeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.black)
                TextField("Mesa: Qd 7e 6c",text:$boardInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.black)
                HStack {
                    Text("a♣ c♥ e♠ d♦")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Limpar ajustes") {
                        holeInput=""
                        boardInput=""
                    }
                    .font(.caption2)
                    .foregroundStyle(gold)
                }
            }
        }
    }

    private var detailShowdown: some View {
        VStack(alignment:.leading,spacing:4) {
            if !reader.visibleShowdown.isEmpty {
                Text("Cartas reveladas publicamente:")
                    .font(.caption)
                    .foregroundStyle(gold)
                Text(reader.visibleShowdown.map{
                    $0.joined(separator:" ")
                }.joined(separator:" • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

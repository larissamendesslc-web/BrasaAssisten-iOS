import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var browser = BrasaBrowser()
    @StateObject private var reader = PageReader()
    @State private var showTraining = false
    @State private var showPanel = false
    @State private var holeInput = ""
    @State private var boardInput = ""
    private var assessed: DecisionAdvice {
        let userHole=holeInput.trimmingCharacters(in:.whitespacesAndNewlines)
        let userBoard=boardInput.trimmingCharacters(in:.whitespacesAndNewlines)
        let fromAuto=userHole.isEmpty
        let holeText=userHole.isEmpty ? reader.liveTokens.joined(separator:" ") : userHole
        let boardText=userBoard.isEmpty ? reader.liveBoard.joined(separator:" ") : userBoard
        if reader.boardNeedsReview && userBoard.isEmpty {
            return DecisionAdvice(color:"neutral", action:"MESA NÃO LIDA",
                strength:"Aguardando cartas comunitárias",
                reason:"O jogo já mostra cartas no centro, mas os naipes não foram reconhecidos. Não vou repetir uma sugestão pré-flop.",
                condition:"Digite as cartas da mesa ou aguarde uma leitura válida.")
        }
        guard let h=PokerEngine.parseCards(holeText), h.count==2,
              let b=PokerEngine.parseCards(boardText),
              [0,3,4,5].contains(b.count),
              Set(h+b).count==h.count+b.count else {
            return DecisionEngine.assess(hole:[],board:[])
        }
        let result=DecisionEngine.assess(hole:h,board:b)
        if fromAuto || (userBoard.isEmpty && !reader.liveBoard.isEmpty) {
            return DecisionAdvice(color:result.color,
                action:"PRÉVIA: " + result.action,
                strength:result.strength,
                reason:result.reason,
                condition:"Cartas detectadas pelo leitor, ainda não confirmadas. " + result.condition)
        }
        return result
    }
    private var signal: Color {
        switch assessed.color {
        case "green": return Color(red: 0.17, green: 0.70, blue: 0.38)
        case "yellow": return Color(red: 1.0, green: 0.73, blue: 0.22)
        case "red": return Color(red: 0.93, green: 0.25, blue: 0.24)
        default: return gold
        }
    }

    @State private var floatingOffset = CGSize.zero
    @GestureState private var floatingDrag = CGSize.zero

    private let gold = Color(red: 0.98, green: 0.70, blue: 0.27)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                BrowserView(browser: browser)
                    .ignoresSafeArea(edges: .bottom)

                if !showPanel {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { withAnimation(.spring(response: 0.32)) { showPanel = true } }) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 23, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .frame(width: 54, height: 54)
                                    .background(.black.opacity(0.88), in: Circle())
                                    .overlay(Circle().stroke(signal, lineWidth: 2))
                                    .shadow(color: .orange.opacity(0.4), radius: 12)
                            }
                            .accessibilityLabel("Abrir BrasaAssisten")
                            .offset(
                                x: floatingOffset.width + floatingDrag.width,
                                y: floatingOffset.height + floatingDrag.height
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 12)
                                    .updating($floatingDrag) { value, state, _ in state = value.translation }
                                    .onEnded { value in
                                        floatingOffset.width = min(0, max(-geometry.size.width + 82,
                                            floatingOffset.width + value.translation.width))
                                        floatingOffset.height = min(110, max(-geometry.size.height + 190,
                                            floatingOffset.height + value.translation.height))
                                    }
                            )
                            .padding(.trailing, 12)
                        }
                        Spacer().frame(height: 132)
                    }
                } else {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showPanel = false } }
                    panel
                        .padding(.horizontal, 10)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 10))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if browser.isLoading {
                    VStack {
                        ProgressView().tint(gold)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .allowsHitTesting(false)
                }
                if let error = browser.errorText {
                    VStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark").font(.title2)
                        Text("Não foi possível carregar o Brasa Poker").font(.headline)
                        Text(error).font(.footnote).multilineTextAlignment(.center)
                        Button("Tentar novamente") { browser.openHome() }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                    }
                    .padding(20)
                    .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
                    .padding(26)
                }
            }
        }
.sheet(isPresented: $showTraining) { TrainingView() }
        .onReceive(Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()) { _ in
            reader.quickScan(browser.webView)
        }
        .onChange(of: reader.liveTokens) { newCards in
            // A new pair invalidates confirmations from the previous hand.
            if newCards.count==2 && !holeInput.isEmpty,
               let old=PokerEngine.parseCards(holeInput),
               let new=PokerEngine.parseCards(newCards.joined(separator:" ")),
               old != new {
                holeInput=""
                boardInput=""
            }
        }
        .onChange(of: reader.liveBoard) { community in
            // Automatically resume scanning after a manually entered partial board
            // only if the new complete read is an extension of that same board.
            if !boardInput.isEmpty,
               let entered=PokerEngine.parseCards(boardInput),
               let latest=PokerEngine.parseCards(community.joined(separator:" ")),
               latest.count>entered.count,
               Array(latest.prefix(entered.count)) == entered {
                boardInput=""
            }
        }
    }

    private func statusChip(_ title: String, color: Color, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(active ? 0.95 : 0.19), in: RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(active ? Color.black : Color.white.opacity(0.65))
    }

    private var panel: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("BrasaAssisten").bold().foregroundStyle(gold)
                Spacer()
                Button(action: { browser.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }.accessibilityLabel("Recarregar site")
                Button(action: { browser.back() }) {
                    Image(systemName: "chevron.backward")
                }.accessibilityLabel("Voltar no site")
                Button(action: { withAnimation { showPanel = false } }) {
                    Image(systemName: "chevron.down")
                }.accessibilityLabel("Minimizar painel")
            }.font(.system(size: 16))

            Divider().overlay(gold.opacity(0.45))
            Label("Página: \(browser.pageTitle)", systemImage: "globe")
                .font(.subheadline).lineLimit(1)
            Label(browser.isLoading ? "Carregando site..." : "Navegador pronto", systemImage: "checkmark.circle")
                .font(.subheadline)
            Text("ASSISTENTE — TREINO")
                .font(.caption).bold().foregroundStyle(gold)
            HStack(spacing: 6) {
                statusChip("DESISTIR", color: .red, active: assessed.color == "red")
                statusChip("CAUTELA", color: .yellow, active: assessed.color == "yellow")
                statusChip("FORTE", color: .green, active: assessed.color == "green")
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(signal).frame(width: 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(assessed.action).font(.headline).bold()
                    Text(assessed.strength).font(.subheadline)
                    Text(assessed.reason).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(signal.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))

            if reader.liveTokens.count == 2 {
                Text("Sua mão (prévia): " + reader.liveTokens.joined(separator:" "))
                    .font(.caption).foregroundStyle(.yellow)
                if !reader.liveBoard.isEmpty {
                    Text("Cartas comunitárias (prévia): " + reader.liveBoard.joined(separator:" "))
                        .font(.caption).foregroundStyle(.yellow)
                }
                if reader.boardNeedsReview {
                    Text("Cartas comunitárias visíveis, mas incompletas.")
                        .font(.caption).foregroundStyle(.orange)
                    if !reader.boardRankHints.isEmpty {
                        Text("Valores candidatos: " + reader.boardRankHints.joined(separator:" "))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Button("Confirmar minhas duas cartas") {
                    holeInput=reader.liveTokens.joined(separator:" ")
                }.buttonStyle(.bordered)
            }
            Text(reader.liveStatus).font(.caption2).foregroundStyle(.secondary)
            Text("Você pode corrigir cartas manualmente. Sem confirmação, o sinal é só uma prévia.")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("Sua mão: Ae Kd", text: $holeInput)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                TextField("Mesa: 6e 5d 10a", text: $boardInput)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
            }
            .font(.caption)
            .padding(10)
            .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button("Limpar correções") { holeInput = "";boardInput = "" }
                    .font(.caption).buttonStyle(.bordered)
                Spacer()
                Text("a♣ c♥ e♠ d♦").font(.caption2).foregroundStyle(.secondary)
            }
            Text(assessed.condition).font(.caption2).foregroundStyle(.secondary)
            Divider().overlay(gold.opacity(0.45))
            Text("DIAGNÓSTICO DO LEITOR").font(.caption).bold().foregroundStyle(gold)
            HStack {
                Button("Inspecionar HTML") { reader.inspectPage(browser.webView) }
                    .buttonStyle(.bordered).disabled(reader.isBusy)
                Button("Testar imagem") { reader.inspectImage(browser.webView) }
                    .buttonStyle(.bordered).disabled(reader.isBusy)
            }.font(.caption)
            Text(reader.status).font(.footnote).fixedSize(horizontal: false, vertical: true)
            Text("Elementos: \(reader.canvasCount) Canvas • \(reader.svgCount) SVG • \(reader.imgCount) imagens • \(reader.cssBackgroundCount) fundos CSS • \(reader.frameCount) iframes")
                .font(.caption2).foregroundStyle(.secondary)
            if !reader.domTokens.isEmpty {
                Text("Candidatos HTML: " + reader.domTokens.joined(separator: "  "))
                    .font(.caption2).foregroundStyle(.orange)
            }
            if !reader.imageTokens.isEmpty {
                Text("Candidatos OCR (com naipe): " + reader.imageTokens.joined(separator: "  "))
                    .font(.caption2).foregroundStyle(.orange)
            }
            if !reader.rankClues.isEmpty {
                Text("Pistas de valores no rodapé: " + reader.rankClues.joined(separator: "  "))
                    .font(.caption2).foregroundStyle(.orange)
            }
            Text("Cartas listadas acima são candidatos, não identificações verificadas. Não use este teste para decidir apostas.")
                .font(.caption2).foregroundStyle(.secondary)
            Button("Abrir calculadora de treino") {
                showPanel = false
                showTraining = true
            }
                .font(.subheadline).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            Button("Voltar ao Brasa") { withAnimation { showPanel = false } }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.black)
                .background(gold, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        }
        .frame(maxHeight: 450)
        .foregroundStyle(.white)
        .background(Color(red: 0.09, green: 0.065, blue: 0.07), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(gold.opacity(0.8), lineWidth: 1))
        .shadow(radius: 15)
    }
}

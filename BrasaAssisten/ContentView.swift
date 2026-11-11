import SwiftUI

struct ContentView: View {
    @StateObject private var browser = BrasaBrowser()
    @StateObject private var reader = PageReader()
    @State private var showTraining = false
    @State private var showPanel = false
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
                                    .overlay(Circle().stroke(gold, lineWidth: 1.5))
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
            HStack(spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(gold)
                Text("Leitura de cartas e análises automáticas ainda não estão implementadas. Este é o protótipo funcional do navegador e overlay.")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            Divider().overlay(gold.opacity(0.45))
            Text("LEITOR — TESTE NO IPHONE").font(.caption).bold().foregroundStyle(gold)
            HStack {
                Button("Inspecionar HTML") { reader.inspectPage(browser.webView) }
                    .buttonStyle(.bordered).disabled(reader.isBusy)
                Button("Testar imagem") { reader.inspectImage(browser.webView) }
                    .buttonStyle(.bordered).disabled(reader.isBusy)
            }.font(.caption)
            Text(reader.status).font(.footnote).fixedSize(horizontal: false, vertical: true)
            if reader.canvasCount > 0 || reader.svgCount > 0 {
                Text("Elementos: \(reader.canvasCount) Canvas • \(reader.svgCount) SVG")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if !reader.domTokens.isEmpty {
                Text("Candidatos HTML: " + reader.domTokens.joined(separator: "  "))
                    .font(.caption2).foregroundStyle(.orange)
            }
            if !reader.imageTokens.isEmpty {
                Text("Candidatos OCR: " + reader.imageTokens.joined(separator: "  "))
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
        .frame(maxHeight: 490)
        .foregroundStyle(.white)
        .background(Color(red: 0.09, green: 0.065, blue: 0.07), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(gold.opacity(0.8), lineWidth: 1))
        .shadow(radius: 15)
    }
}

import SwiftUI

// Offline/manual educational calculator, not connected to live bets.
struct TrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hole="Ae Ke"
    @State private var board=""
    @State private var opponents=1
    @State private var isCalculating=false
    @State private var result="Preencha as cartas e toque em Calcular."

    var body: some View {
        NavigationStack {
            Form {
                Section("Cartas do jogador — treino") {
                    TextField("Ex.: Ae Ke",text:$hole).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    TextField("Mesa: ex. Qe Je 10e",text:$board).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Text("Código: a=paus, c=copas, e=espadas, d=ouros. Aceita também ♠♥♦♣.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Adversários desconhecidos") {
                    Stepper("Adversários: \(opponents)",value:$opponents,in:1...8)
                    Text("A simulação usa cartas aleatórias para os adversários. Não conhece as cartas reais nem o estilo de cada um.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Resultado") {
                    Text(result).font(.callout).textSelection(.enabled)
                    Button(isCalculating ? "Calculando..." : "Calcular mãos e equidade") { calculate() }
                        .disabled(isCalculating)
                }
                Section {
                    Text("Ferramenta de estudo. Resultado por amostragem Monte Carlo, não garantia de vitória nem recomendação de aposta.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Treino de Hold'em")
            .toolbar {ToolbarItem(placement:.topBarTrailing) {Button("Fechar"){dismiss()}}}
        }
    }
    private func calculate() {
        guard let h=PokerEngine.parseCards(hole),h.count==2,
              let b=PokerEngine.parseCards(board),[0,3,4,5].contains(b.count),
              Set(h+b).count==h.count+b.count else {
            result="Dados inválidos. Informe 2 cartas suas e 0, 3, 4 ou 5 da mesa, sem duplicatas."
            return
        }
        isCalculating=true
        result="Simulando 1.200 cenários aleatórios..."
        let name=PokerEngine.evaluate(h+b)?.name ?? "Pré-flop"
        let count=opponents
        DispatchQueue.global(qos:.userInitiated).async {
            let equity=PokerEngine.sampledEquity(hero:h,board:b,opponents:count,trials:1200)
            DispatchQueue.main.async {
                isCalculating=false
                if let equity {
                    result="Combinação atual: \(name)\nEquidade estimada contra \(count) adversário(s) aleatório(s): \(String(format:"%.1f",equity*100))%\nAmostra: 1.200 cenários. Empates dividem o pote."
                } else {result="Não foi possível calcular. Confira as cartas."}
            }
        }
    }
}

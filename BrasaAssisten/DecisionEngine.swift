import Foundation

struct DecisionAdvice {
    let color: String       // green, yellow, red, neutral
    let action: String
    let strength: String
    let reason: String
    let condition: String
}

enum DecisionEngine {
    static func assess(hole: [PlayingCard], board: [PlayingCard]) -> DecisionAdvice {
        guard hole.count == 2, [0,3,4,5].contains(board.count),
              Set(hole + board).count == hole.count + board.count else {
            return DecisionAdvice(color: "neutral", action: "AGUARDANDO", strength: "Dados insuficientes", reason: "Informe duas cartas válidas e as cartas comunitárias disponíveis.", condition: "Sem análise até os dados estarem corretos.")
        }
        let ranks = hole.map(\.rank).sorted(by: >)
        let paired = ranks[0] == ranks[1]
        let suited = hole[0].suit == hole[1].suit
        let gap = ranks[0] - ranks[1]

        func advice(_ color: String, _ action: String, _ strength: String, _ reason: String, _ condition: String) -> DecisionAdvice {
            DecisionAdvice(color: color, action: action, strength: strength, reason: reason, condition: condition)
        }
        if board.isEmpty {
            if (paired && ranks[0] >= 11) || (ranks[0] == 14 && ranks[1] == 13) || (suited && ranks[0] == 14 && ranks[1] == 12) {
                return advice("green", "AUMENTAR", "Mão inicial forte", "Par alto ou combinação premium. Boa candidata a aumento pré-flop.", "A intensidade depende da posição e dos aumentos anteriores.")
            }
            if paired || (ranks[0] == 14 && ranks[1] >= 10) || (ranks[0] == 13 && ranks[1] >= 11) || (suited && ((ranks[0] >= 9 && gap <= 2) || (ranks[0] >= 12 && ranks[1] >= 10))) {
                return advice("yellow", "PAGAR BARATO", "Mão jogável com cautela", "Potencial razoável, mas muito dependente de posição, tamanho da aposta e jogadores.", "Contra aumentos altos, prefira não se comprometer sem contexto.")
            }
            return advice("red", "DESISTIR", "Mão inicial fraca", "Pouca força pré-flop e/ou cartas com baixa conexão.", "Se puder dar mesa gratuitamente, veja o flop sem investir.")
        }

        guard let score = PokerEngine.evaluate(hole + board) else {
            return advice("neutral", "AGUARDANDO", "Sem classificação", "Não foi possível identificar a combinação.", "Confira as cartas inseridas.")
        }
        if board.count == 5, let boardScore = PokerEngine.evaluate(board), boardScore == score {
            return advice("yellow", "MESA / CAUTELA", "Mão compartilhada: \(score.name)", "Sua melhor combinação também está inteira na mesa. Outros jogadores podem empatar ou superar.", "Não trate a combinação da mesa como uma mão exclusiva sua.")
        }
        if score.category >= 3 {
            return advice("green", "MÃO FORTE", score.name, "Você formou \(score.name.lowercased()). A força relativa ainda depende das cartas comunitárias e dos adversários.", "Sem informação das apostas, não é possível escolher um valor de aumento confiável.")
        }
        if score.category == 2 {
            return advice("yellow", "MESA / CAUTELA", "Dois pares", "Dois pares são úteis, mas podem perder para trinca, sequência, flush e mãos superiores.", "Verifique se o par da mesa beneficia todos os jogadores.")
        }
        if score.category == 1 {
            let pairRank = score.kickers[0]
            let pairInHand = hole.contains { $0.rank == pairRank }
            if pairInHand && paired && hole[0].rank > (board.map(\.rank).max() ?? 0) {
                return advice("green", "MÃO FORTE", "Overpair", "Seu par na mão supera todas as cartas comunitárias.", "Cuidado com textura da mesa e apostas grandes.")
            }
            if pairInHand && hole.contains(where: { $0.rank == (board.map(\.rank).max() ?? 0) }) {
                return advice("yellow", "MESA / PAGAR POUCO", "Par mais alto", "Você acertou a maior carta comunitária, mas o kicker e os adversários importam.", "Não pague automaticamente apostas altas.")
            }
            return advice("yellow", "MESA / CAUTELA", "Um par", "Há um par, mas a força relativa na mesa pode ser baixa.", "Sem tamanho de aposta, uma recomendação definitiva seria arriscada.")
        }
        if board.count < 5 {
            let all = hole + board
            let counts = Dictionary(grouping: all, by: { $0.suit })
            let flushDraw = counts.contains { suit, cards in cards.count == 4 && hole.contains(where: { $0.suit == suit }) }
            let values = Set(all.map(\.rank))
            let withAce = values.contains(14) ? values.union([1]) : values
            let straightDraw = (5...14).contains { high in
                (0..<5).filter { withAce.contains(high - $0) }.count == 4
            }
            if flushDraw || straightDraw {
                return advice("yellow", "MESA / PAGAR POUCO", "Projeto de \(flushDraw ? "flush" : "sequência")", "Você ainda não formou uma combinação forte, mas pode melhorar nas próximas cartas.", "A chance de completar depende dos outs e do número de cartas restantes.")
            }
        }
        return advice("red", "MESA OU DESISTIR", score.name, "Sua mão não apresenta força feita relevante neste momento.", "Se for grátis, dar mesa é diferente de pagar uma aposta.")
    }
}

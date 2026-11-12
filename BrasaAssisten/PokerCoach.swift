import Foundation

/// A local and deterministic poker coach. No remote AI, unseen cards or
/// promises of profit. Suggestions are conditional on the visible information.
struct CoachReport {
    let tone: String
    let action: String
    let title: String
    let reason: String
    let alternatives: [String]
    let alerts: [String]
    let confidence: String
    let street: String
    let estimatedEquity: Double?
    let callThreshold: Double?
    let handName: String
}

enum PokerCoach {
    private static func report(
        _ tone: String, _ action: String, _ title: String, _ reason: String,
        alternatives: [String], alerts: [String] = [],
        confidence: String, street: String, equity: Double?, threshold: Double?,
        hand: String
    ) -> CoachReport {
        CoachReport(tone: tone, action: action, title: title,
            reason: reason, alternatives: alternatives, alerts: alerts,
            confidence: confidence, street: street,
            estimatedEquity: equity, callThreshold: threshold, handName: hand)
    }

    static func assess(
        hole: [PlayingCard], board: [PlayingCard],
        pot: Double? = nil, toCall: Double? = nil,
        equity: Double? = nil, confirmed: Bool = false
    ) -> CoachReport {
        let street: String
        switch board.count {
        case 3: street = "Flop"
        case 4: street = "Turn"
        case 5: street = "River"
        default: street = "Pré-flop"
        }
        let confidence = confirmed ? "Cartas confirmadas • contexto parcial"
                                   : "Leitura automática • verificar cartas"
        let threshold: Double?
        if let pot, let toCall, pot >= 0, toCall > 0 {
            threshold = toCall / (pot + toCall)
        } else {
            threshold = nil
        }
        guard [0,2].contains(hole.count), [0,3,4,5].contains(board.count),
              Set(hole + board).count == hole.count + board.count else {
            return report("neutral", "AGUARDANDO", "Leitura incompleta",
                "Não há cartas suficientes e verificadas para avaliar esta mão.",
                alternatives:["Abra uma mesa para começar a acompanhar a partida."],
                confidence:"Sem leitura", street:street, equity:nil,
                threshold:nil, hand:"—")
        }

        let suits = Dictionary(grouping: board, by:\.suit).mapValues(\.count)
        let maximumSuit = suits.values.max() ?? 0
        let boardPairs = Dictionary(grouping:board,by:\.rank).values.filter{$0.count>=2}.count
        let ranks = Set(board.map(\.rank))
        let extendedRanks = ranks.contains(14) ? ranks.union([1]) : ranks
        let straightThreat = board.count>=3 && (5...14).contains { high in
            (0..<5).filter{extendedRanks.contains(high-$0)}.count>=3
        }
        var alerts: [String] = []
        if maximumSuit >= 4 { alerts.append("Quatro ou mais comunitárias do mesmo naipe: risco elevado de flush.") }
        else if maximumSuit == 3 { alerts.append("Três comunitárias do mesmo naipe: atenção a flush.") }
        if straightThreat { alerts.append("A mesa contém cartas conectadas: sequência possível.") }
        if boardPairs > 0 { alerts.append("Mesa emparelhada: trincas e full houses ficam mais relevantes.") }
        if board.count >= 3 && board.isEmpty == false && hole.isEmpty {
            return report("neutral", "OBSERVANDO", "Mesa em análise",
                TableInsights.describe(board:board),
                alternatives:[
                    "Sem suas cartas, só é possível avaliar a textura pública da mesa.",
                    "Acompanhe turn e river para ver se novas combinações surgem."
                ], alerts:alerts, confidence:"Comunitárias detectadas • sem cartas pessoais",
                street:street, equity:nil, threshold:nil,
                hand:board.map(\.description).joined(separator:" "))
        }
        guard hole.count == 2 else {
            return report("neutral", "ACOMPANHANDO", "Aguardando próxima mão",
                "Nenhuma carta pessoal está visível. O navegador permanece acompanhando a mesa.",
                alternatives:["Entre em uma mesa ou continue observando."],
                confidence:"Sem cartas pessoais",street:street,equity:nil,
                threshold:nil,hand:"—")
        }

        if board.isEmpty {
            let ranks=hole.map(\.rank).sorted(by:>)
            let paired=ranks[0]==ranks[1]
            let suited=hole[0].suit==hole[1].suit
            let gap=ranks[0]-ranks[1]
            let premium = (paired && ranks[0]>=11) ||
                (ranks[0]==14 && ranks[1]==13) ||
                (suited && ranks[0]==14 && ranks[1]==12)
            let playable = paired || (ranks[0]==14 && ranks[1]>=9) ||
                (ranks[0]==13 && ranks[1]>=10) ||
                (suited && ((ranks[0]>=8 && gap<=2) || (ranks[0]>=12 && ranks[1]>=9))) ||
                (ranks[0]>=10 && gap==1)
            if premium {
                return report("green","AUMENTAR","Mão inicial premium",
                    "Boa força pré-flop, mas a posição e os aumentos anteriores ainda precisam ser considerados.",
                    alternatives:["Contra 3-bet forte, reavalie o tamanho dos stacks e a posição.",
                                  "Se não houver informações sobre a ação anterior, o valor exato do aumento fica indefinido."],
                    confidence:confidence,street:street,equity:equity,threshold:threshold,
                    hand:hole.map(\.description).joined(separator:" "))
            }
            // Offsuit Ax with a middle kicker is not a premium hand, but
            // a categorical fold is misleading when position, previous bets
            // and check availability have not been observed.
            let marginalAce = ranks[0] == 14 &&
                (ranks[1] >= 6 || suited)
            if marginalAce && !playable {
                return report("yellow","CAUTELA","Ás com kicker vulnerável",
                    "Seu ás pode estar dominado por outro ás com kicker mais alto. A posição e o preço para continuar são decisivos.",
                    alternatives:["Em posição inicial e contra aumentos, esta mão normalmente perde valor.",
                                  "Em posição final e sem aumento, existem cenários para continuar com cautela.",
                                  "Se puder dar mesa sem pagar, veja o flop sem custo adicional."],
                    confidence:confidence,street:street,equity:equity,threshold:threshold,
                    hand:hole.map(\.description).joined(separator:" "))
            }
            if playable {
                return report("yellow","CAUTELA","Mão inicial jogável",
                    "Potencial de jogo, mas a posição e o preço para entrar são decisivos.",
                    alternatives:["Se puder dar mesa, veja o flop sem custo extra.",
                                  "Contra aumento grande ou vários adversários, a mão perde valor."],
                    confidence:confidence,street:street,equity:equity,threshold:threshold,
                    hand:hole.map(\.description).joined(separator:" "))
            }
            if toCall == 0 {
                return report("yellow","MESA","Mão fraca • sem custo",
                    "Você pode ver a próxima etapa sem pagar. Dar mesa não equivale a apostar com esta mão.",
                    alternatives:["Reavalie se houver aumento depois de sua vez.",
                                  "A posição ainda é importante."],
                    confidence:confidence,street:street,equity:equity,threshold:threshold,
                    hand:hole.map(\.description).joined(separator:" "))
            }
            return report("red","DESISTIR","Mão inicial fraca",
                "Pouca força imediata ou baixa conexão entre as cartas. Este é um sinal conservador, não uma decisão definitiva sem o histórico de apostas.",
                alternatives:["Se a mesa for gratuita, não é necessário desistir.",
                              "Evite pagar um aumento apenas para ver o flop."],
                confidence:confidence,street:street,equity:equity,threshold:threshold,
                hand:hole.map(\.description).joined(separator:" "))
        }

        guard let score=PokerEngine.evaluate(hole+board) else {
            return report("neutral","VERIFICAR","Cartas conflitantes",
                "Não foi possível formar uma avaliação válida de cinco cartas.",
                alternatives:["Verifique se alguma carta foi duplicada."],
                confidence:"Baixa",street:street,equity:nil,threshold:threshold,hand:"—")
        }

        if board.count==5, let shared=PokerEngine.evaluate(board), shared==score {
            return report("yellow","CONTROLAR POTE","Combinação compartilhada",
                "Sua melhor combinação já está inteiramente na mesa: \(score.name). Você pode empatar ou perder para cartas pessoais melhores.",
                alternatives:["Evite assumir que a combinação pública está ganhando.",
                              "Observe se o preço de uma aposta justifica buscar o empate."],
                alerts:alerts,confidence:confidence,street:street,
                equity:equity,threshold:threshold,hand:score.name)
        }

        let heroRanks=Set(hole.map(\.rank))
        let boardMax=board.map(\.rank).max() ?? 0
        let flushDanger=maximumSuit>=4 && !hole.contains(where:{suits[$0.suit] == maximumSuit})
        let tripsBoardOnly=boardPairs>0 && Dictionary(grouping:board,by:\.rank).values.contains{$0.count>=3}
        let holePairs=hole[0].rank==hole[1].rank
        let bestPair=score.category==1 ? score.kickers[0] : 0
        let contributedPair=heroRanks.contains(bestPair)
        let overpair=score.category==1 && holePairs && hole[0].rank > boardMax
        let topPair=score.category==1 && heroRanks.contains(boardMax) && boardMax == bestPair
        let isWeakBoardPair=score.category==1 && !contributedPair
        var tone="red",action="MESA / DESISTIR",title=score.name
        var reason="Sem combinação particular forte. Dar mesa gratuitamente é diferente de pagar uma aposta."
        var alternatives=["Se houver aposta grande, não continue sem dados adicionais.",
                          "Se puder dar mesa, preserve suas fichas."]
        if score.category>=5 || score.category==4 {
            tone = flushDanger ? "yellow" : "green"
            action = flushDanger ? "CAUTELA" : "FORTE"
            title=score.name
            reason="Combinação alta formada. Compare-a com as possibilidades da própria mesa antes de investir mais."
            alternatives=["Se outro jogador mostrar muita força, reavalie as combinações superiores possíveis.",
                          "Não existe valor de aumento confiável sem saber apostas e stacks."]
        } else if score.category==3 && !tripsBoardOnly {
            tone="green";action="FORTE";title="Trinca"
            reason="Você formou uma trinca; a mesa pode permitir sequência, flush ou full house dos adversários."
        } else if score.category==3 {
            tone="yellow";action="CAUTELA";title="Trinca comunitária"
            reason="A trinca está visível para todos. O kicker e a combinação dos oponentes fazem diferença."
        } else if score.category==2 {
            tone="yellow";action="CONTROLAR POTE";title="Dois pares"
            reason="Dois pares podem ter bom valor, mas pares públicos e cartas conectadas mudam o risco."
            if flushDanger { action="CAUTELA" }
        } else if score.category==1 {
            if overpair {
                tone=flushDanger ? "yellow":"green"
                action=flushDanger ? "CAUTELA":"FORTE"
                title="Overpair"
                reason="Seu par de mão é mais alto que as cartas comunitárias. Cuidado com sequência, flush e trinca."
            } else if topPair {
                tone="yellow";action="CONTROLAR POTE";title="Par mais alto"
                reason="Você acertou o maior valor da mesa, mas o kicker e a agressividade adversária importam."
            } else if isWeakBoardPair {
                tone="red";action="MESA / DESISTIR";title="Par comunitário"
                reason="O par está na mesa e pode ser usado por todos. Suas cartas ainda não demonstram vantagem."
            } else {
                tone="yellow";action="CAUTELA";title="Par baixo ou médio"
                reason="Você possui um par, mas há muitas combinações que podem superá-lo."
            }
        }

        let combined=hole+board
        let suitGroups=Dictionary(grouping:combined,by:\.suit)
        let flushDraw=board.count<5 && score.category<5 &&
            suitGroups.contains { suit,cards in cards.count==4 && hole.contains{$0.suit==suit} }
        let cardRanks=Set(combined.map(\.rank))
        let effective=cardRanks.contains(14) ? cardRanks.union([1]) : cardRanks
        var openEnded=false,inside=false
        if board.count<5 && score.category<4 {
            for low in 1...10 {
                let run=(low...low+3).allSatisfy{effective.contains($0)}
                guard run else {continue}
                let usesHero=hole.contains{(low...low+3).contains($0.rank) ||
                    ($0.rank==14 && low==1)}
                guard usesHero else {continue}
                if low>1 && low+4<=14 && !effective.contains(low-1) &&
                    !effective.contains(low+4) {openEnded=true}
                else {inside=true}
            }
        }
        if score.category<2 && (flushDraw || openEnded || inside) {
            tone="yellow";action="PROJETO • CAUTELA"
            let outs=flushDraw ? 9 : (openEnded ? 8 : 4)
            let remaining=board.count==3 ? 47.0 : 46.0
            let next=Double(outs)/remaining*100
            title=flushDraw ? "Projeto de flush" : (openEnded ? "Projeto de sequência" : "Projeto interno")
            reason="Você tem um projeto com cerca de \(outs) saídas teóricas. Aproximadamente \(Int(next.rounded()))% de chance de completá-lo na próxima carta, antes de descontar saídas que possam não vencer."
            alternatives=["Compare o preço da aposta com a chance de melhorar.",
                          "Um projeto não é uma mão já vencedora."]
        }
        if flushDanger && score.category<5 {
            alerts.append("Há quatro cartas de um naipe na mesa e você não tem esse naipe.")
            if tone=="green" { tone="yellow";action="CAUTELA" }
        }
        if let threshold, let equity, equity+0.05<threshold {
            alerts.append("Equidade simulada contra mão aleatória abaixo da exigida pelo preço; isso não representa o range real do adversário.")
        }
        if board.count==5 { alternatives=["No river não há mais cartas para melhorar a mão.",
                           "Uma aposta agressiva pode representar mãos bem diferentes da sua."] }
        return report(tone,action,title,reason,alternatives:alternatives,
                      alerts:alerts,confidence:confidence,street:street,
                      equity:equity,threshold:threshold,hand:score.name)
    }
}

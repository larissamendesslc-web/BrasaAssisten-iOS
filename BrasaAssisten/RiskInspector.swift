import Foundation

/// Conservative inspection based only on verified visible cards.
/// It does not infer opponents' actual hands and never recommends a wager.
struct RiskReport {
    let level: String       // blocked, uncertain, danger
    let label: String
    let hand: String
    let shortAlert: String
    let alerts: [String]
    let explanation: String
}

enum RiskInspector {
    private static func report(_ level:String,_ label:String,_ hand:String,_ alerts:[String],_ explanation:String) -> RiskReport {
        RiskReport(level:level,label:label,hand:hand,
                   shortAlert:alerts.prefix(2).joined(separator:" • "),
                   alerts:alerts,explanation:explanation)
    }

    static func assess(hole:[PlayingCard], board:[PlayingCard], uncertain:Bool) -> RiskReport {
        if uncertain {
            return report("blocked","SEM ANÁLISE","Cartas não confirmadas",
                ["Leitura incompleta: confira os naipes e os valores.",
                 "Um resultado anterior não pode valer para outra mão."],
                "A avaliação foi bloqueada porque há cartas incertas.")
        }
        guard hole.count == 2, [0,3,4,5].contains(board.count),
              Set(hole + board).count == hole.count + board.count else {
            return report("blocked","SEM ANÁLISE","Cartas incompletas",
                ["Confirme duas cartas pessoais e todas as comunitárias visíveis."],
                "Não é possível classificar a situação com dados insuficientes.")
        }
        if board.isEmpty {
            return report("uncertain","RESULTADO INCERTO","Pré-flop",
                ["As cartas comunitárias ainda são desconhecidas.",
                 "Força inicial não prevê resultado nem autoriza um all-in."],
                "A força inicial depende de contexto que o leitor pode não ter.")
        }
        guard let ours = PokerEngine.evaluate(hole + board) else {
            return report("blocked","SEM ANÁLISE","Cartas inválidas",
                ["Não foi possível avaliar as cartas reconhecidas."],
                "Confira a leitura visual antes de interpretar a mão.")
        }

        let name: String
        if (ours.category == 4 || ours.category == 8), let top=ours.kickers.first {
            let rankName = [14:"Ás",13:"Rei",12:"Dama",11:"Valete"][top] ?? String(top)
            name = ours.name + " até " + rankName
        } else { name = ours.name }

        var alerts:[String] = []
        let suits = Dictionary(grouping:board,by:\.suit).mapValues(\.count)
        let ranks = Dictionary(grouping:board,by:\.rank).mapValues(\.count)
        var danger = false
        if suits.values.contains(where:{$0 >= 3}) {
            danger = true
            alerts.append("Flush possível com cartas ocultas")
        } else if board.count < 5 && suits.values.contains(2) {
            alerts.append("Flush poderá surgir nas próximas cartas")
        }
        if ranks.values.contains(where:{$0 >= 2}) {
            danger = true
            alerts.append("Mesa pareada: full house ou quadra possíveis")
        }

        if board.count == 5 {
            let used=Set(hole+board)
            let available=PokerEngine.deck.filter{!used.contains($0)}
            var higher:[Int:Int] = [:]
            for i in 0..<available.count {
                for j in (i+1)..<available.count {
                    if let theirs=PokerEngine.evaluate(board+[available[i],available[j]]),
                       theirs > ours {
                        higher[theirs.category,default:0] += 1
                    }
                }
            }
            if higher.isEmpty {
                alerts=["Nenhuma mão superior encontrada entre as cartas restantes; isso não garante lucro."]
                danger=false
            } else {
                danger=true
                for cat in higher.keys.sorted(by:>) {
                    let short: String
                    switch cat {
                    case 8: short="Straight flush superior possível"
                    case 7: short="Quadra pode superar sua mão"
                    case 6: short="Full house pode superar sua mão"
                    case 5: short="Flush pode superar sua mão"
                    case 4: short="Sequência superior possível"
                    case 3: short="Trinca superior possível"
                    case 2: short="Dois pares superiores possíveis"
                    case 1: short="Par superior possível"
                    default: short="Carta alta superior possível"
                    }
                    if !alerts.contains(short) { alerts.append(short) }
                }
            }
        } else {
            alerts.append("Turn/river ainda podem mudar a melhor combinação")
        }

        if alerts.isEmpty {
            alerts=["As cartas adversárias permanecem ocultas"]
        }
        return report(danger ? "danger":"uncertain",
                      danger ? "RISCO ELEVADO":"RESULTADO INCERTO",
                      name,alerts,
                      "Combinações possíveis não são a chance real de ganhar. O assistente desconhece as cartas fechadas e o comportamento adversário. Não use como indicação para apostar.")
    }
}

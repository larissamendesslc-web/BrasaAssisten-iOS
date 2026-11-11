import Foundation

enum TableInsights {
    static func describe(board:[PlayingCard]) -> String {
        guard [3,4,5].contains(board.count),
              Set(board).count == board.count else {
            return "Aguardando ao menos três cartas comunitárias visíveis."
        }
        let counts=Dictionary(grouping: board, by: \.rank).mapValues(\.count)
        let maxGroup=counts.values.max() ?? 1
        let pairs=counts.values.filter{$0==2}.count
        let suits=Dictionary(grouping:board,by:\.suit).mapValues(\.count)
        let maxSuit=suits.values.max() ?? 1
        let ranks=Set(board.map(\.rank))
        var text:String
        if maxGroup==4 {text="Quadra visível na mesa."}
        else if maxGroup==3 && pairs>0 {text="Full house possível na própria mesa."}
        else if maxGroup==3 {text="Trinca na mesa: todos os jogadores compartilham essas três cartas."}
        else if pairs>=2 {text="Dois pares comunitários: a carta pessoal mais alta pode decidir."}
        else if pairs==1 {text="A mesa tem um par. Outros jogadores podem ter trinca ou dois pares."}
        else {text="Mesa sem pares comunitários."}
        if maxSuit>=3 {text+=" Atenção: há \(maxSuit) cartas do mesmo naipe."}
        if ranks.contains(14) {text+=" Há um ás na mesa."}
        return text
    }
}

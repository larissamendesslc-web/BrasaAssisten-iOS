import Foundation

struct PlayingCard: Hashable, CustomStringConvertible {
    let rank: Int
    let suit: Character // s,h,d,c
    var description: String {
        let r = rank == 14 ? "A" : rank == 13 ? "K" : rank == 12 ? "Q" : rank == 11 ? "J" : rank == 10 ? "10" : String(rank)
        let suits: [Character: String] = ["s":"♠", "h":"♥", "d":"♦", "c":"♣"]
        return r + (suits[suit] ?? "?")
    }
    static func parse(_ input: String) -> PlayingCard? {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard s.count >= 2 else { return nil }
        let suit: Character
        switch s.last! {
        case "S", "E", "♠": suit = "s"
        case "H", "C", "♥": suit = "h"
        case "D", "♦": suit = "d"
        case "P", "A", "♣": suit = "c"
        default: return nil
        }
        let part = String(s.dropLast())
        let ranks = ["A":14,"K":13,"Q":12,"J":11,"T":10]
        let rank = ranks[part] ?? Int(part) ?? 0
        guard (2...14).contains(rank) else { return nil }
        return PlayingCard(rank: rank, suit: suit)
    }
}

struct HandScore: Comparable {
    let category: Int
    let kickers: [Int]
    static func < (lhs: HandScore, rhs: HandScore) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (a,b) in zip(lhs.kickers,rhs.kickers) where a != b { return a < b }
        return false
    }
    var name: String {
        switch category {
        case 8: return "Straight flush"
        case 7: return "Quadra"
        case 6: return "Full house"
        case 5: return "Flush"
        case 4: return "Sequência"
        case 3: return "Trinca"
        case 2: return "Dois pares"
        case 1: return "Um par"
        default: return "Carta alta"
        }
    }
}

enum PokerEngine {
    static let deck: [PlayingCard] = (2...14).flatMap { r in [Character("s"),Character("h"),Character("d"),Character("c")].map { PlayingCard(rank:r,suit:$0) } }
    private static func straightHigh(_ ranks: [Int]) -> Int? {
        var set = Set(ranks)
        if set.contains(14) { set.insert(1) }
        for high in stride(from:14, through:5, by:-1) where (0..<5).allSatisfy({ set.contains(high - $0) }) { return high }
        return nil
    }
    static func evaluate(_ cards: [PlayingCard]) -> HandScore? {
        guard (5...7).contains(cards.count), Set(cards).count == cards.count else { return nil }
        let counts = Dictionary(cards.map {($0.rank,1)}, uniquingKeysWith: +)
        let groups = counts.keys.sorted { counts[$0]! == counts[$1]! ? $0 > $1 : counts[$0]! > counts[$1]! }
        let bySuit = Dictionary(grouping:cards, by: { $0.suit })
        let flushCards = bySuit.values.first(where: { $0.count >= 5 })
        if let f=flushCards, let high=straightHigh(f.map(\.rank)) { return HandScore(category:8,kickers:[high]) }
        if let q=groups.first(where:{counts[$0] == 4}) { return HandScore(category:7,kickers:[q,counts.keys.filter({$0 != q}).max()!]) }
        let trips=groups.filter { counts[$0]! >= 3 }
        if let t=trips.first, let p=groups.first(where:{ $0 != t && counts[$0]! >= 2 }) { return HandScore(category:6,kickers:[t,p]) }
        if let f=flushCards { return HandScore(category:5,kickers:Array(f.map(\.rank).sorted(by:>).prefix(5))) }
        if let high=straightHigh(Array(counts.keys)) { return HandScore(category:4,kickers:[high]) }
        if let t=trips.first { return HandScore(category:3,kickers:[t] + Array(counts.keys.filter({$0 != t}).sorted(by:>).prefix(2))) }
        let pairs=groups.filter { counts[$0]! >= 2 }
        if pairs.count >= 2 {
            let p=Array(pairs.prefix(2))
            return HandScore(category:2,kickers:p + [counts.keys.filter({!p.contains($0)}).max()!])
        }
        if let p=pairs.first { return HandScore(category:1,kickers:[p] + Array(counts.keys.filter({$0 != p}).sorted(by:>).prefix(3))) }
        return HandScore(category:0,kickers:Array(counts.keys.sorted(by:>).prefix(5)))
    }
    // Fractional tie equity versus uniformly random opponent cards.
    // Never treat Monte Carlo results as exact odds against human betting ranges.
    static func sampledEquity(hero:[PlayingCard],board:[PlayingCard],opponents:Int,trials:Int=1200) -> Double? {
        guard hero.count == 2, (0...5).contains(board.count), (1...8).contains(opponents) else { return nil }
        let known=hero+board
        guard Set(known).count == known.count else { return nil }
        let toDraw=(5-board.count)+opponents*2
        let available=deck.filter { !Set(known).contains($0) }
        guard available.count >= toDraw else { return nil }
        var equity=0.0
        for _ in 0..<max(trials,1) {
            let draw=Array(available.shuffled().prefix(toDraw))
            let finalBoard=board + draw.prefix(5-board.count)
            guard let ours=evaluate(hero+finalBoard) else { return nil }
            var winners=1
            var beaten=false
            var index=5-board.count
            for _ in 0..<opponents {
                let opp=[draw[index],draw[index+1]]
                index+=2
                guard let score=evaluate(opp+finalBoard) else { return nil }
                if score > ours { beaten=true;break }
                if score == ours { winners+=1 }
            }
            if !beaten { equity+=1.0/Double(winners) }
        }
        return equity/Double(max(trials,1))
    }
    static func parseCards(_ input:String)->[PlayingCard]? {
        let tokens=input.replacingOccurrences(of:",",with:" ").split(whereSeparator:{$0.isWhitespace}).map(String.init)
        var cards=[PlayingCard]()
        for token in tokens { guard let c=PlayingCard.parse(token) else{return nil};cards.append(c) }
        return Set(cards).count == cards.count ? cards : nil
    }
}

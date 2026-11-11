import Foundation

enum TableTransition: String {
    case waiting, newHand, advanced, unchanged, uncertain, invalid
}

/// Visible-card-only state machine: a folded player or spectator can still
/// follow the community board without exposing anyone's hidden cards.
struct TableSession {
    private(set) var hero: [PlayingCard] = []
    private(set) var board: [PlayingCard] = []
    private(set) var serial = 0
    private(set) var uncertain = false
    private(set) var spectating = true
    private(set) var visibleBoardCount = 0

    var streetLabel: String {
        let count=max(visibleBoardCount,board.count)
        switch count {
        case 3: return "Flop"
        case 4: return "Turn"
        case 5: return "River"
        default: return "Pré-flop"
        }
    }

    mutating func ingest(
        hero newHero: [PlayingCard],
        board newBoard: [PlayingCard],
        rankHints: [String],
        incomplete: Bool
    ) -> TableTransition {
        guard [0,2].contains(newHero.count), [0,3,4,5].contains(newBoard.count),
              Set(newHero+newBoard).count == newHero.count+newBoard.count else {
            uncertain=true
            return .invalid
        }
        // If no hole cards are exposed this is observation mode, or the
        // local player has folded. Never infer invisible opponents' cards.
        spectating = newHero.isEmpty
        let observedCount=max(newBoard.count, rankHints.count >= 3 ? min(5,rankHints.count) : 0)
        visibleBoardCount=observedCount

        if incomplete {
            uncertain=true
            // Keep the last valid board for historical continuity, but the
            // UI must not display any betting advice while it is uncertain.
            if !newHero.isEmpty && Set(newHero) != Set(hero) {
                hero=newHero
                board=[]
                serial+=1
            } else if newHero.isEmpty {
                hero=[]
            }
            return .uncertain
        }

        if !newHero.isEmpty && Set(newHero) != Set(hero) {
            hero=newHero
            board=newBoard
            uncertain=false
            serial+=1
            return .newHand
        }
        if newHero.isEmpty { hero=[] }

        if newBoard.isEmpty && !board.isEmpty {
            board=[]
            uncertain=false
            serial+=1
            return .newHand
        }
        if newBoard.isEmpty && board.isEmpty {
            uncertain=false
            return newHero.isEmpty ? .waiting : .unchanged
        }
        if board.isEmpty && !newBoard.isEmpty {
            board=newBoard
            uncertain=false
            if serial==0 {serial+=1;return .newHand}
            return .advanced
        }
        if newBoard==board {
            uncertain=false
            return .unchanged
        }
        if newBoard.count>board.count &&
           Array(newBoard.prefix(board.count))==board {
            board=newBoard
            uncertain=false
            return .advanced
        }
        uncertain=true
        return .uncertain
    }

    mutating func reset() {
        hero=[]
        board=[]
        serial+=1
        uncertain=false
        spectating=true
        visibleBoardCount=0
    }
}

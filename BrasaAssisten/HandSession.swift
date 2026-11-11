import Foundation

/// One isolated Hold'em hand, fed only verified card values.
/// Keeps older community-card snapshots from leaking into the next hand.
enum Street: String {
    case preflop = "Pré-flop"
    case flop = "Flop"
    case turn = "Turn"
    case river = "River"
}

enum HandTransition: Equatable {
    case awaiting
    case newHand
    case advanced
    case unchanged
    case boardUncertain
    case invalid
}

struct HandSession {
    private(set) var hero: [PlayingCard] = []
    private(set) var board: [PlayingCard] = []
    private(set) var serial: Int = 0
    private(set) var boardUncertain: Bool = false

    var street: Street {
        switch board.count {
        case 3: return .flop
        case 4: return .turn
        case 5: return .river
        default: return .preflop
        }
    }

    mutating func ingest(hero newHero: [PlayingCard], board newBoard: [PlayingCard], uncertain: Bool) -> HandTransition {
        guard newHero.count == 2,
              [0,3,4,5].contains(newBoard.count),
              Set(newHero + newBoard).count == newHero.count + newBoard.count else {
            return .invalid
        }
        if newHero != hero {
            hero = newHero
            board = newBoard
            boardUncertain = uncertain
            serial += 1
            return .newHand
        }
        if uncertain {
            boardUncertain = true
            return .boardUncertain
        }
        // A board that becomes empty may be a new round, even when the same
        // starting cards appear. Never reuse a prior turn or river blindly.
        if newBoard.isEmpty && !board.isEmpty {
            board = []
            boardUncertain = false
            serial += 1
            return .newHand
        }
        if newBoard == board {
            boardUncertain = false
            return .unchanged
        }
        // The flop adds three cards; then the turn/river add one at a time.
        // A legitimate new board keeps the old known prefix.
        if newBoard.count > board.count && Array(newBoard.prefix(board.count)) == board {
            board = newBoard
            boardUncertain = false
            return .advanced
        }
        // If a board changes unexpectedly, treat it as uncertain rather than
        // overwriting verified data from a previous stage.
        boardUncertain = true
        return .boardUncertain
    }

    mutating func reset() {
        hero = []
        board = []
        boardUncertain = false
        serial += 1
    }
}

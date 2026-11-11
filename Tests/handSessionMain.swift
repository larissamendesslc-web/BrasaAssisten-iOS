import Foundation

func hand(_ value: String) -> [PlayingCard] { PokerEngine.parseCards(value)! }
func verify(_ condition: @autoclosure () -> Bool, _ name: String) {
    assert(condition(), "Hand session regression: \(name)")
}
var session=HandSession()
verify(session.ingest(hero:hand("Ke Kd"),board:[],uncertain:false) == .newHand, "starts hand")
let first=session.serial
verify(session.street == .preflop, "preflop")
verify(session.ingest(hero:hand("Ke Kd"),board:hand("Qc 7e 6c"),uncertain:false) == .advanced, "reads flop")
verify(session.street == .flop, "flop")
verify(session.ingest(hero:hand("Ke Kd"),board:hand("Qc 7e 6c 3c"),uncertain:false) == .advanced, "reads turn")
verify(session.street == .turn, "turn")
verify(session.ingest(hero:hand("Ke Kd"),board:hand("Qc 7e 6c 3c 8e"),uncertain:false) == .advanced, "reads river")
verify(session.street == .river, "river")
verify(session.serial == first, "same hand throughout all streets")
verify(session.ingest(hero:hand("Ke Kd"),board:hand("Qc 7e 6c 3c 8e"),uncertain:false) == .unchanged, "same river snapshot")
verify(session.ingest(hero:hand("Ke Kd"),board:[],uncertain:true) == .boardUncertain, "no false preflop on unreadable board")
verify(session.boardUncertain, "blocks stale recommendations")
verify(session.ingest(hero:hand("9c 2a"),board:[],uncertain:false) == .newHand, "new hero clears board")
verify(session.street == .preflop && session.board.isEmpty, "no river leakage")
verify(session.serial == first + 1, "increments session id")
verify(session.ingest(hero:hand("9c 2a"),board:hand("5c Je Je"),uncertain:false) == .advanced, "new flop")
verify(session.ingest(hero:hand("9c 2a"),board:hand("5c Je 9e"),uncertain:false) == .boardUncertain, "reject changed flop")
verify(session.board == hand("5c Je Je"), "keeps prior board")
verify(session.ingest(hero:hand("9c 2a"),board:hand("5c Je Je 4e"),uncertain:false) == .advanced, "recovery on next street")
verify(session.ingest(hero:hand("9c 2a"),board:[],uncertain:false) == .newHand, "new round on board clearing")
verify(session.board.isEmpty && session.street == .preflop, "no previous board")
verify(session.ingest(hero:hand("9c 9c"),board:[],uncertain:false) == .invalid, "reject duplicate cards")
print("HandSession: 20+ lifecycle conditions passed.")

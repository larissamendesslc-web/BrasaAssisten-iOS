import Foundation

func c(_ s:String)->[PlayingCard]{PokerEngine.parseCards(s)!}
func expect(_ condition:@autoclosure ()->Bool,_ message:String) {
    assert(condition(),"TableSession: "+message)
}
var session=TableSession()
expect(session.ingest(hero:c("10c 4e"),board:[],rankHints:[],incomplete:false)==.newHand,"first hero")
let serial=session.serial
expect(session.ingest(hero:c("10c 4e"),board:[],rankHints:["Q","4","6"],incomplete:true)==.uncertain,"partially seen flop")
expect(session.uncertain && session.streetLabel=="Flop","no false pre-flop if community ranks present")
expect(session.ingest(hero:c("10c 4e"),board:c("Qd 4d 6e"),rankHints:["Q","4","6"],incomplete:false)==.advanced,"flop")
expect(session.streetLabel=="Flop" && !session.uncertain,"flop phase")
expect(session.ingest(hero:c("10c 4e"),board:c("Qd 4d 6e 2e"),rankHints:["Q","4","6","2"],incomplete:false)==.advanced,"turn")
expect(session.ingest(hero:c("10c 4e"),board:c("Qd 4d 6e 2e Ad"),rankHints:["Q","4","6","2","A"],incomplete:false)==.advanced,"river")
expect(session.streetLabel=="River" && session.serial==serial,"stable hand through river")
expect(session.ingest(hero:[],board:c("Qd 4d 6e 2e Ad"),rankHints:["Q","4","6","2","A"],incomplete:false)==.unchanged,"folded/spectator still sees river")
expect(session.spectating && session.board.count==5,"observation mode keeps board")
expect(session.ingest(hero:[],board:[],rankHints:[],incomplete:false)==.newHand,"new hand after board clears")
expect(session.board.isEmpty && session.streetLabel=="Pré-flop","river cleared")
expect(session.ingest(hero:[],board:c("5a Je 9e"),rankHints:["5","J","9"],incomplete:false)==.advanced,"spectator flop without hero")
expect(session.spectating && session.streetLabel=="Flop","spectator flop recognized")
expect(session.ingest(hero:[],board:c("5a Je 9e 8c"),rankHints:["5","J","9","8"],incomplete:false)==.advanced,"spectator turn")
expect(session.ingest(hero:[],board:c("5a Je 9e 8c 3d"),rankHints:["5","J","9","8","3"],incomplete:false)==.advanced,"spectator river")
expect(session.ingest(hero:[],board:c("5a Je 2e"),rankHints:["5","J","2"],incomplete:false)==.uncertain,"reject changed old flop")
expect(session.uncertain && session.board.count==5,"don't overwrite old board with error")
let duplicates=[PlayingCard(rank:14,suit:"s"),PlayingCard(rank:14,suit:"s")]
expect(session.ingest(hero:duplicates,board:[],rankHints:[],incomplete:false)==.invalid,"duplicate cards invalid")
print("TableSession regression cases passed.")

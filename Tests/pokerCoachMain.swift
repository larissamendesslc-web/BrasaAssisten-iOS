import Foundation
func cards(_ s:String)->[PlayingCard]{PokerEngine.parseCards(s)!}
func check(_ hole:String,_ board:String,_ color:String,_ title:String=""){
 let r=PokerCoach.assess(hole:cards(hole),board:cards(board))
 assert(r.tone==color,"wrong color for \(hole)|\(board): \(r.tone) \(r.title)")
 if !title.isEmpty {assert(r.title.contains(title),"wrong title: \(r.title)")}
 print("\(hole) | \(board) => \(r.tone) \(r.action) \(r.title)")
}
check("Ae Ka","","green")
check("8c 2a","","red")
check("Kd 10d","","yellow")
check("Ke Kd","Qc 7e 6c","green","Overpair")
check("Ae 9d","5e 5c 2a","red","comunitário")
check("Ae 2d","3a 4c 5e 8d Ke","green","Sequência")
check("9d 8d","6d Ke 5d","yellow","Projeto")
let observer=PokerCoach.assess(hole:[],board:cards("10a Ad Ac"))
assert(observer.action=="OBSERVANDO" && observer.reason.contains("par"))
let missing=PokerCoach.assess(hole:[],board:[])
assert(missing.tone=="neutral")
let shared=PokerCoach.assess(hole:cards("2a 3a"),board:cards("10d Jd Qd Kd Ad"))
assert(shared.title=="Combinação compartilhada")
let priced=PokerCoach.assess(hole:cards("Ae Ka"),board:[],pot:65,toCall:45)
assert(abs(priced.callThreshold!-45.0/110.0)<0.000001)
print("PokerCoach regression suite passed.")

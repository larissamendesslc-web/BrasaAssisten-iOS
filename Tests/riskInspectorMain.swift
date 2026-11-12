import Foundation
func cards(_ str:String)->[PlayingCard]{PokerEngine.parseCards(str)!}
let screenshot=RiskInspector.assess(hole:cards("9a 5e"),board:cards("7a 8c 6c 7c Je"),uncertain:false)
assert(screenshot.label=="RISCO ELEVADO")
assert(screenshot.hand=="Sequência até 9")
assert(screenshot.alerts.contains{$0.contains("Flush")})
assert(screenshot.alerts.contains{$0.contains("full house")})
let missing=RiskInspector.assess(hole:cards("9a 5e"),board:[],uncertain:true)
assert(missing.level=="blocked")
let preflop=RiskInspector.assess(hole:cards("Ae Ka"),board:[],uncertain:false)
assert(preflop.label=="RESULTADO INCERTO")
let invalid=RiskInspector.assess(hole:cards("Ae Ka"),board:cards("Ae 2c 3d"),uncertain:false)
assert(invalid.level=="blocked")
print("RiskInspector: screenshot, uncertainty, duplicate and preflop checks passed.")

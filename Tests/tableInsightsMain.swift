import Foundation
func cards(_ text:String)->[PlayingCard]{PokerEngine.parseCards(text)!}
assert(TableInsights.describe(board:cards("Qd 4d 6e")).contains("sem pares"))
assert(TableInsights.describe(board:cards("Qd 4d 6e 2e Ad")).contains("3 cartas"))
assert(TableInsights.describe(board:cards("5c Je Jc")).contains("um par"))
assert(TableInsights.describe(board:cards("5c Je Jc 5d")).contains("Dois pares"))
assert(TableInsights.describe(board:cards("5c 5e 5d")).contains("Trinca"))
assert(TableInsights.describe(board:[]).contains("Aguardando"))
print("Spectator insights regression tests passed.")

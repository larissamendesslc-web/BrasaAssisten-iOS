import Foundation

func cards(_ s:String)->[PlayingCard] { PokerEngine.parseCards(s)! }
func check(_ s:String, expected:Int) {
    let score=PokerEngine.evaluate(cards(s))!
    assert(score.category == expected, "Unexpected result for \(s): \(score)")
}
check("As Ks Qs Js 10s 2h 3c",expected:8)
check("Ae 2d 3c 4s 5h 9h Jh",expected:4)
check("6e 6d 6a 3a 7e 4e Kc",expected:3)
check("5d 5h 6c 6s 6d 2h Kd",expected:6)
check("Ae Ad Ac Aa Kd 5h 2c",expected:7)
check("Ae 2e 7e Je Ke 3c 4d",expected:5)
check("Ae Ad Ke Kd Qs 3h 2c",expected:2)
check("Ae Ac 4a 7c 9d 3e 2d",expected:1)
check("Ae Kd Qc Jh 9d 3h 2c",expected:0)
assert(PokerEngine.parseCards("Ae Ae") == nil)
assert(PokerEngine.parseCards("9z") == nil)
let equity=PokerEngine.sampledEquity(hero:cards("Ae Ad"),board:[],opponents:1,trials:1000)!
assert((0.65...0.98).contains(equity))
let royal=PokerEngine.sampledEquity(hero:cards("Ae Ke"),board:cards("Qe Je 10e 2c 3d"),opponents:5,trials:200)!
assert(royal == 1.0)
print("Poker engine tests passed. Equity(A-A vs random)=\(equity)")

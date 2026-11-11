import Foundation

func c(_ value:String) -> [PlayingCard] { PokerEngine.parseCards(value)! }
func test(_ hole:String,_ board:String,_ action:String) {
    let result=DecisionEngine.assess(hole:c(hole), board:c(board))
    assert(result.action==action,"\(hole) + \(board) got \(result.action) expected \(action)")
    print("\(hole) / \(board) -> \(result.color) \(result.action)")
}
test("Ae Ka","","AUMENTAR")
test("Ke 10e","","PAGAR BARATO")
test("8c 2a","","DESISTIR")
test("6e 6d","6a 7e 4e","MÃO FORTE")
test("9d 8d","6d Ke 5c","MESA / PAGAR POUCO")
test("Ae 2d","3a 4c 5e 8d Ke","MÃO FORTE")
test("Ae Kd","5c Jh Je 3e 8c","MESA / CAUTELA")

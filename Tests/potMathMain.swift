import Foundation
assert(PotMath.parseBRL("2.565,00")==2565)
assert(PotMath.parseBRL("R$ 65,00")==65)
assert(PotMath.parseBRL("BRL 45,00")==45)
assert(PotMath.parseBRL("abc")==nil)
assert(abs(PotMath.breakEvenCall(pot:"65,00",call:"45,00")!-45.0/110.0)<0.000001)
assert(PotMath.breakEvenCall(pot:"65,00",call:"0,00")==nil)
print("PotMath regression tests passed.")

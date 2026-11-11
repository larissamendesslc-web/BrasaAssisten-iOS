import Foundation

enum PotMath {
    static func parseBRL(_ value:String) -> Double? {
        let stripped=value.replacingOccurrences(of:"BRL",with:"")
            .replacingOccurrences(of:"R$",with:"")
            .replacingOccurrences(of:" ",with:"")
            .replacingOccurrences(of:".",with:"")
            .replacingOccurrences(of:",",with:".")
        guard let amount=Double(stripped),amount>=0,amount.isFinite else {return nil}
        return amount
    }
    /// Ratio of a call to the pot after calling, without future action/rake.
    static func breakEvenCall(pot:String,call:String) -> Double? {
        guard let p=parseBRL(pot), let c=parseBRL(call),c>0 else {return nil}
        return c/(p+c)
    }
}

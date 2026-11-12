import Foundation
import Combine

/// Throttled Monte Carlo simulation against uniformly random opponents.
/// Runs off the main thread only when the cards/opponent selection change.
@MainActor
final class EquityEstimator: ObservableObject {
    @Published private(set) var equity: Double?
    @Published private(set) var computing = false
    @Published private(set) var label = "Ainda sem cartas"

    private var latestKey = ""
    private var revision = 0

    func refresh(hole: [PlayingCard]?, board: [PlayingCard]?, opponents: Int) {
        guard let hole, hole.count == 2, let board,
              [0,3,4,5].contains(board.count),
              Set(hole + board).count == hole.count + board.count,
              (1...5).contains(opponents) else {
            if latestKey != "invalid" {
                latestKey = "invalid"
                revision += 1
                equity = nil
                computing = false
                label = "Sem cartas confirmadas"
            }
            return
        }
        let newKey = (hole + board).map(\.description).joined(separator:" ")
            + "/\(opponents)"
        guard newKey != latestKey else {return}
        latestKey = newKey
        revision += 1
        let currentRevision = revision
        computing = true
        equity = nil
        label = "Calculando simulação"
        Task.detached(priority: .utility) {
            let result = PokerEngine.sampledEquity(
                hero:hole,board:board,opponents:opponents,trials:650
            )
            await MainActor.run {
                guard self.revision == currentRevision else {return}
                self.equity = result
                self.computing = false
                self.label = result == nil ? "Simulação indisponível"
                    : "Equidade simulada contra \(opponents) mão(s) aleatória(s)"
            }
        }
    }
}

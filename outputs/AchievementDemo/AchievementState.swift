import Foundation

/// Каждые 20 новых оценённых товаров открывают следующий уровень.
struct AchievementState: Equatable {
    let target = 20
    private(set) var count: Int
    private(set) var ratings: [String: Int] = [:]

    var level: Int { count / target + 1 }
    var countInLevel: Int { count % target }
    var progress: Double { Double(countInLevel) / Double(target) }

    init(initialCount: Int = 16) {
        count = max(0, initialCount)
    }

    @discardableResult
    mutating func rate(productID: String, stars: Int) -> Bool {
        guard (1...5).contains(stars), count < Int.max else { return false }
        let isNewProduct = ratings[productID] == nil
        ratings[productID] = stars
        guard isNewProduct else { return false }
        count += 1
        return countInLevel == 0
    }

    mutating func reset(initialCount: Int = 16) {
        self = AchievementState(initialCount: initialCount)
    }
}

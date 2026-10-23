import Foundation

@main
enum StateChecks {
    static func main() {
        var state = AchievementState(initialCount: 0)
        var events = 0
        for index in 1...41 {
            let unlocked = state.rate(productID: "product-\(index)", stars: 5)
            if unlocked { events += 1 }
            precondition(unlocked == (index == 20 || index == 40))
            precondition(state.level == index / 20 + 1)
            precondition(state.countInLevel == index % 20)
            precondition(state.progress == Double(index % 20) / 20)
        }
        precondition(events == 2 && state.level == 3 && state.countInLevel == 1)
        var almost = AchievementState(initialCount: 19)
        precondition(almost.rate(productID: "last", stars: 1))
        precondition(almost.level == 2 && almost.progress == 0)
        precondition(!almost.rate(productID: "last", stars: 4))
        precondition(almost.count == 20 && almost.ratings["last"] == 4)
        precondition(!almost.rate(productID: "next", stars: 5))
        precondition(almost.progress == 0.05)
        let saved = almost
        for invalid in [Int.min, -1, 0, 6, Int.max] {
            precondition(!almost.rate(productID: "invalid", stars: invalid))
            precondition(almost == saved)
        }
        var nextLevel = AchievementState(initialCount: 39)
        precondition(nextLevel.rate(productID: "fortieth", stars: 3))
        precondition(nextLevel.level == 3 && nextLevel.progress == 0)
        nextLevel.reset(initialCount: 20)
        precondition(nextLevel.level == 2 && nextLevel.countInLevel == 0 && nextLevel.ratings.isEmpty)
        precondition(!nextLevel.rate(productID: "new", stars: 5))
        nextLevel.reset(initialCount: Int.min)
        precondition(nextLevel.count == 0 && nextLevel.level == 1)
        var limit = AchievementState(initialCount: Int.max)
        precondition(!limit.rate(productID: "overflow", stars: 5))
        precondition(limit.count == Int.max)
        print("Проверки пройдены: 19→20→21, 39→40, 0→41, сброс шкалы, дубликаты, неверные оценки и переполнение.")
    }
}

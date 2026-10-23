import SwiftUI
import UIKit

@MainActor
struct ReviewsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var achievement: AchievementState
    @State private var displayedProgress: Double
    @State private var displayedLevel: Int
    @State private var productCount: Int
    @State private var selectedTab = 0
    @State private var wavePhase: Double = 0
    @State private var badgeScale: CGFloat = 1
    @State private var numberScale: CGFloat = 1
    @State private var rewardFocus: CGFloat = 0
    @State private var confettiStart: Date?
    @State private var transitioning = false
    @State private var celebrationTask: Task<Void, Never>?
    @State private var automationTask: Task<Void, Never>?
    @State private var automationStarted = false

    private let confettiEnabled = false
    private let automaticallyCompletes: Bool

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let count: Int
        if let index = arguments.firstIndex(of: "--demo-count"),
           arguments.indices.contains(index + 1),
           let requested = Int(arguments[index + 1]) {
            count = max(0, requested)
        } else {
            count = 16
        }
        let initial = AchievementState(initialCount: count)
        _achievement = State(initialValue: initial)
        _displayedProgress = State(initialValue: initial.progress)
        _displayedLevel = State(initialValue: initial.level)
        _productCount = State(initialValue: initial.target - initial.countInLevel)
        automaticallyCompletes = arguments.contains("--auto-complete")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Раздел отзывов", selection: $selectedTab) {
                        Text("Ждут оценки").tag(0)
                        Text("Мои отзывы").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 8)

                    AchievementCard(
                        count: min(achievement.target, max(0, achievement.count - (displayedLevel - 1) * achievement.target)),
                        target: achievement.target,
                        progress: displayedProgress,
                        level: displayedLevel,
                        wavePhase: wavePhase,
                        badgeScale: badgeScale,
                        numberScale: numberScale,
                        rewardFocus: rewardFocus,
                        confettiStart: confettiStart,
                        reduceMotion: reduceMotion
                    )
                    .zIndex(10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedTab == 0 ? "Ваши покупки" : "Ваши оценки")
                            .font(.custom("Onest-SemiBold", size: 20, relativeTo: .title3))
                            .foregroundStyle(Color("TextPrimary"))
                            .padding(.horizontal, 8)

                        if visibleProducts.isEmpty {
                            emptyState
                        } else {
                            ForEach(visibleProducts) { product in
                                ProductRatingRow(
                                    product: product,
                                    rating: achievement.ratings[product.id],
                                    onRate: { stars in rate(productID: product.id, stars: stars) }
                                )
                                .disabled(transitioning)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Отзывы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Демо") {
                        Button("Начать с нуля") { reset(initialCount: 0) }
                        Button("До уровня — 1 оценка") { reset(initialCount: 19) }
                        Button("Повторить с 16") { reset(initialCount: 16) }
                        Button("Показать уровень 2") { reset(initialCount: 20) }
                        Button("До уровня 3 — 1 оценка") { reset(initialCount: 39) }
                    }
                    .font(.custom("Onest-Medium", size: 14, relativeTo: .subheadline))
                }
            }
        }
        .tint(Color(red: 0, green: 0.33, blue: 1))
        .onAppear { startAutomationIfNeeded() }
        .onDisappear { cancelEffects() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startAutomationIfNeeded() }
            else { cancelEffects() }
        }
        .onChange(of: reduceMotion) { _, _ in cancelEffects() }
    }

    private var visibleProducts: [DemoProduct] {
        let available = Array(DemoProduct.all.prefix(productCount))
        return selectedTab == 0 ? available : available.filter { achievement.ratings[$0.id] != nil }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedTab == 0 ? "checkmark.circle" : "star.bubble")
                .font(.system(size: 28))
                .foregroundStyle(Color("TextSecondary"))
            Text(selectedTab == 0 ? "Все товары оценены" : "Здесь появятся ваши оценки")
                .font(.custom("Onest-Regular", size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    private func rate(productID: String, stars: Int) {
        guard !transitioning else { return }
        let previousCount = achievement.count
        let completed = achievement.rate(productID: productID, stars: stars)
        guard achievement.count != previousCount else { return }
        celebrationTask?.cancel()
        guard completed else {
            withAnimation(reduceMotion ? nil : .linear(duration: 0.25)) {
                displayedProgress = achievement.progress
            }
            return
        }
        transitioning = true
        celebrationTask?.cancel()
        celebrationTask = Task { @MainActor in
            do {
                if reduceMotion {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedLevel = achievement.level
                        displayedProgress = 0
                    }
                    productCount += achievement.target
                    transitioning = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    return
                }
                withAnimation(.easeOut(duration: 0.65)) { displayedProgress = 1 }
                try await Task.sleep(for: .milliseconds(950))
                try Task.checkCancellation()
                withAnimation(.spring(duration: 0.5, bounce: 0.15)) { badgeScale = 1.25 }
                if confettiEnabled { confettiStart = .now }
                withAnimation(.linear(duration: 0.9)) { wavePhase = 1 }
                try await Task.sleep(for: .milliseconds(450))
                try Task.checkCancellation()
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { displayedProgress = 0 }
                try await Task.sleep(for: .milliseconds(450))
                try Task.checkCancellation()
                withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                    badgeScale = 1
                    rewardFocus = 1
                    numberScale = 2.2
                }
                try await Task.sleep(for: .milliseconds(600))
                try Task.checkCancellation()
                withAnimation(.spring(duration: 0.5, bounce: 0.1)) {
                    displayedLevel = achievement.level
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                UIAccessibility.post(notification: .announcement, argument: "Уровень \(achievement.level). До следующего уровня оцените 20 товаров.")
                try await Task.sleep(for: .milliseconds(700))
                try Task.checkCancellation()
                withAnimation(.spring(duration: 0.5, bounce: 0.1)) {
                    numberScale = 1
                    rewardFocus = 0
                    badgeScale = 1
                }
                productCount += achievement.target
                try await Task.sleep(for: .milliseconds(2300))
                try Task.checkCancellation()
                confettiStart = nil
                wavePhase = 0
                transitioning = false
            } catch { }
        }
    }

    private func reset(initialCount: Int) {
        cancelEffects()
        achievement.reset(initialCount: initialCount)
        productCount = achievement.target - achievement.countInLevel
        selectedTab = 0
        settlePresentation()
    }

    private func cancelEffects() {
        celebrationTask?.cancel()
        celebrationTask = nil
        automationTask?.cancel()
        automationTask = nil
        settlePresentation()
    }

    private func settlePresentation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedProgress = achievement.progress
            displayedLevel = achievement.level
            productCount = max(productCount, achievement.ratings.count + achievement.target - achievement.countInLevel)
            wavePhase = 0
            badgeScale = 1
            numberScale = 1
            rewardFocus = 0
            confettiStart = nil
            transitioning = false
        }
    }

    private func startAutomationIfNeeded() {
        guard automaticallyCompletes, !automationStarted, scenePhase == .active else { return }
        automationStarted = true
        automationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(1_500))
                for product in DemoProduct.all.prefix(productCount) {
                    try Task.checkCancellation()
                    guard scenePhase == .active else { return }
                    rate(productID: product.id, stars: 5)
                    try await Task.sleep(for: .milliseconds(400))
                }
            } catch { }
        }
    }
}

private struct AchievementCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var titleLineHeight = 16.0
    @ScaledMetric(relativeTo: .caption) private var subtitleLineHeight = 16.0

    let count: Int
    let target: Int
    let progress: Double
    let level: Int
    let wavePhase: Double
    let badgeScale: CGFloat
    let numberScale: CGFloat
    let rewardFocus: CGFloat
    let confettiStart: Date?
    let reduceMotion: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            badge
                .offset(y: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Мастер оценок")
                    .font(.custom("Onest-SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : titleLineHeight)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.custom("Onest-Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : subtitleLineHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)

                GeometryReader { proxy in
                    Capsule().fill(Color("ProgressTrack"))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color(red: 109 / 255, green: 203 / 255, blue: 1), Color(red: 0, green: 85 / 255, blue: 1)],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                .frame(width: proxy.size.width)
                                .scaleEffect(x: max(0, min(1, progress)), y: 1, anchor: .leading)
                        }
                        .clipShape(Capsule())
                }
                .frame(height: 7)
                .padding(.top, 6)
                .accessibilityLabel("Прогресс достижения")
                .accessibilityValue("Оценено \(count) из \(target) товаров")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(minHeight: 81, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("LayerFloor1"))
        }
        .overlay {
            WidgetWhiteSweep(phase: wavePhase)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            if let confettiStart, !reduceMotion {
                WidgetConfetti(start: confettiStart)
                    .frame(height: 360)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("achievement-card")
    }

    private var subtitle: String {
        let remaining = max(0, target - count)
        let suffix = remaining == 1 ? "товар" : (2...4).contains(remaining) ? "товара" : "товаров"
        if level >= 2 { return "До \(level + 1)-го уровня — оцените \(remaining) \(suffix)" }
        if remaining == 0 { return "20 из 20 товаров оценено" }
        return count == 0 ? "Оцените 20 товаров" : "Оцените ещё \(remaining) \(suffix)"
    }

    private var badge: some View {
        ZStack(alignment: .topLeading) {
            Image("AchievementBadge")
                .resizable()
                .frame(width: 45 * 1.0816, height: 43 * 1.1277)
                .offset(x: -45 * 0.0408, y: -43 * 0.0638)
                .frame(width: 45, height: 43, alignment: .topLeading)
                .clipped()
                .scaleEffect(0.85 * (reduceMotion ? 1 : badgeScale))
                .offset(y: reduceMotion ? 0 : 60 * rewardFocus)
                .frame(width: 45, height: 43)
                .clipped()
                .accessibilityHidden(true)

            ZStack {
                Text(level, format: .number)
                    .font(.custom("Onest-Bold", fixedSize: 12.63))
                    .foregroundStyle(.white)
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(level)))
                    .frame(width: 15, height: 15.79)
                    .background {
                        RoundedRectangle(cornerRadius: 4.736)
                            .fill(Color("LevelGreen"))
                    }

            }
                .frame(width: 15, height: 15.79)
                .scaleEffect(reduceMotion ? 1 : numberScale)
                .offset(x: 1 - (reduceMotion ? 0 : rewardFocus),
                        y: -25.605 + (reduceMotion ? 0 : 20.605 * rewardFocus))
                .frame(width: 45, height: 43, alignment: .center)
                .accessibilityLabel("Уровень достижения")
                .accessibilityValue(String(level))
                .accessibilityIdentifier("achievement-level")
        }
        .frame(width: 45, height: 43)

    }
}

/// Узкий полупрозрачный световой проход, содержимое карточки остаётся видно.
private struct WidgetWhiteSweep: View {
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 12) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.85), .white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 42)
                Rectangle().fill(.white.opacity(0.5)).frame(width: 12)
            }
            .frame(height: proxy.size.height * 3)
            .rotationEffect(.degrees(20))
            .offset(x: -100 + phase * (proxy.size.width + 200), y: -proxy.size.height)
        }
    }
}

/// A dense upward burst from the widget's lower edge, followed by gravity and flutter.
private struct WidgetConfetti: View {
    let start: Date
    private let colors: [Color] = [.pink, .cyan, .purple, .orange, Color("LevelGreen"), .blue]

    private func random(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index * 127 + salt * 311)) * 43758.5453
        return value - floor(value)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                for index in 0..<96 {
                    let time = elapsed - random(index, 1) * 0.045
                    let lifetime = 3.0 + random(index, 15) * 0.8
                    guard time >= 0, time < lifetime else { continue }
                    // Linear air drag gives a sharp launch and a slow terminal fall.
                    let drag = 3.8 + random(index, 2) * 1.6
                    let terminalSpeed = 75 + random(index, 3) * 30
                    let launchSpeed = 1150 + random(index, 4) * 800
                    let verticalTravel = terminalSpeed * time
                        - (launchSpeed + terminalSpeed) * (1 - exp(-drag * time)) / drag
                    let spread = (random(index, 5) - 0.5) * 1450
                    let horizontalDrag = 2.1 + random(index, 6) * 1.3
                    let drift = (random(index, 7) - 0.5) * 24
                    let x = size.width / 2 + (random(index, 8) - 0.5) * 16
                        + spread * (1 - exp(-horizontalDrag * time)) / horizontalDrag + drift * time
                    let y = size.height - 3 + verticalTravel
                    let rotationTime = (1 - exp(-3 * time)) / 3
                    let roll = random(index, 9) * .pi * 2
                        + (random(index, 10) - 0.5) * (rotationTime * 15 + time * 3)
                    let pitch = random(index, 11) * .pi * 2 + time * (2 + random(index, 12) * 7)
                    let yaw = random(index, 13) * .pi * 2 + time * (1 + random(index, 14) * 4)
                    let width = 4 + random(index, 16) * 4
                    let height = 6 + random(index, 17) * 5
                    var paper = Path()
                    let oval = index.isMultiple(of: 4)
                    let vertexCount = oval ? 20 : 4
                    for vertex in 0..<vertexCount {
                        let px: Double
                        let py: Double
                        if oval {
                            let angle = Double(vertex) / Double(vertexCount) * .pi * 2
                            px = cos(angle) * width / 2
                            py = sin(angle) * height / 2
                        } else {
                            px = (vertex == 0 || vertex == 3 ? -1 : 1) * width / 2
                            py = (vertex < 2 ? -1 : 1) * height / 2
                        }
                        let tiltedY = py * cos(pitch)
                        let z = py * sin(pitch)
                        let tiltedX = px * cos(yaw) + z * sin(yaw)
                        let depth = -px * sin(yaw) + z * cos(yaw)
                        let perspective = 70 / (70 + depth)
                        let projectedX = (tiltedX * cos(roll) - tiltedY * sin(roll)) * perspective
                        let projectedY = (tiltedX * sin(roll) + tiltedY * cos(roll)) * perspective
                        let point = CGPoint(x: x + projectedX, y: y + projectedY)
                        if vertex == 0 { paper.move(to: point) } else { paper.addLine(to: point) }
                    }
                    paper.closeSubpath()
                    var particle = context
                    particle.opacity = min(1, max(0, (lifetime - time) / 0.65))
                    let illumination = 0.72 + 0.28 * abs(cos(pitch) * cos(yaw))
                    particle.fill(paper, with: .color(colors[index % colors.count].opacity(illumination)))
                }
            }
        }
    }
}

private struct DemoProduct: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let usesPerfumeImage: Bool

    static let all: [DemoProduct] = (0..<120).map { index in
        let titles = ["Парфюмерная вода", "Увлажняющий крем", "Беспроводные наушники", "Керамическая кружка"]
        let details = ["30 мл · Цветочный аромат", "Для ежедневного ухода · 50 мл", "Белые · В зарядном футляре", "350 мл · Молочный цвет"]
        let symbols = ["sparkles", "drop.fill", "headphones", "cup.and.saucer.fill"]
        let kind = index % titles.count
        return DemoProduct(id: "product-\(index)", title: titles[kind], detail: details[kind], symbol: symbols[kind], usesPerfumeImage: kind == 0)
    }
}

private struct ProductRatingRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let product: DemoProduct
    let rating: Int?
    let onRate: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if product.usesPerfumeImage {
                        Image("ProductPerfume").resizable().scaledToFit()
                    } else {
                        Image(systemName: product.symbol)
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(Color("TextSecondary"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .systemGroupedBackground))
                    }
                }
                .frame(width: 64, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(product.title)
                        .font(.custom("Onest-Medium", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color("TextPrimary"))
                    Text(product.detail)
                        .font(.custom("Onest-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(Color("TextSecondary"))
                    if rating != nil {
                        Label("Оценка сохранена", systemImage: "checkmark.circle.fill")
                            .font(.custom("Onest-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Color("LevelGreen"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { stars in
                    Button { onRate(stars) } label: {
                        Image(systemName: stars <= (rating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(stars <= (rating ?? 0) ? Color.orange : Color("TextSecondary"))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(product.title): оценить на \(stars) из 5")
                    .accessibilityAddTraits(stars == rating ? [.isSelected] : [])
                    .accessibilityIdentifier("\(product.id)-star-\(stars)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ReviewsView()
}

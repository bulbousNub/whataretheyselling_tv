//
// GameModel.swift
//  whataretheyselling_tv
//
//  Created by TeJay Guilliams on 8/30/25.
//

// GameModel.swift
import Foundation

struct Player: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var score: Int = 0
}

enum Category: String, CaseIterable, Identifiable {
    case fashion, beauty, home, electronics, kitchen, toys, misc
    var id: String { rawValue }
}

struct Prompt: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let category: Category
}

final class GameState: ObservableObject {
    @Published var players: [Player] = [
        Player(name: "Player 1"),
        Player(name: "Player 2")
    ]
    @Published var category: Category = .misc
    @Published var currentPrompt: Prompt?
    @Published var isRoundActive = false
    @Published var roundSecondsRemaining: Int = 90

    private var roundLength: Int = 90
    private var timer: Timer?
    private let promptsByCategory: [Category: [String]] = [
        .fashion: ["“Weekend Wardrobe Refresh”", "“Statement Accessories”", "“Cozy Layers”"],
        .beauty: ["“Glow-Up Essentials”", "“Hydration Heroes”", "“Flawless Finish”"],
        .home: ["“Declutter Magic”", "“Cozy Living Room”", "“Sleep Upgrade”"],
        .electronics: ["“Smart Home Starter”", "“Creators’ Kit”", "“Work From Couch”"],
        .kitchen: ["“Meal-Prep Masters”", "“Brunch at Home”", "“Knife Skills 101”"],
        .toys: ["“STEM Surprise”", "“Rainy-Day Fun”", "“Family Game Night”"],
        .misc: ["“Deal of the Hour”", "“Impulse Saver”", "“Host’s Wildcard”"]
    ]

    // MARK: - Round control
    func startRound(seconds: Int? = nil) {
        if let s = seconds { roundLength = s }
        roundSecondsRemaining = roundLength
        isRoundActive = true
        scheduleTick()
    }

    func endRound() {
        isRoundActive = false
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.roundSecondsRemaining > 0 {
                self.roundSecondsRemaining -= 1
            } else {
                self.endRound()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    // MARK: - Prompts
    func nextPrompt() {
        let bank = promptsByCategory[category] ?? promptsByCategory[ .misc ]!
        currentPrompt = Prompt(text: bank.randomElement()!, category: category)
    }

    // MARK: - Scoring
    func award(points: Int, to player: Player) {
        guard let idx = players.firstIndex(of: player) else { return }
        players[idx].score += points
        persist()
    }

    func resetScores() {
        for i in players.indices { players[i].score = 0 }
        persist()
    }

    // MARK: - Persistence (simple UserDefaults)
    private let saveKey = "what-are-they-selling-classic-state"
    init() { restore() }

    func persist() {
        let payload = players.map { ["name": $0.name, "score": $0.score] }
        UserDefaults.standard.set(payload, forKey: saveKey)
    }
    private func restore() {
        guard let payload = UserDefaults.standard.array(forKey: saveKey) as? [[String: Any]] else { return }
        var restored: [Player] = []
        for p in payload {
            if let name = p["name"] as? String, let score = p["score"] as? Int {
                restored.append(Player(name: name, score: score))
            }
        }
        if !restored.isEmpty { self.players = restored }
    }
}

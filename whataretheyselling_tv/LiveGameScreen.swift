import SwiftUI
import AVKit
import UIKit

struct LiveGameScreen: View {
    // MARK: - Inputs
    let streamURL: URL

    // MARK: - State
    @State private var player = AVPlayer()
    @State private var players: [Player] = []
    @State private var newPlayerNameRail: String = ""
    private let playersStorageKey = "WATS_players_v1"

    // Game session + history
    @State private var gameStartedAt: Date = Date()
    @State private var recentGames: [GameRecord] = []
    private let recentGamesStorageKey = "WATS_recentGames_v1"
    // All-time leaderboard (name -> total score)
    @State private var allTimeTotals: [String: Int] = [:]
    private let allTimeTotalsStorageKey = "WATS_allTimeTotals_v1"
    @State private var showConfirmEndGame: Bool = false
    // Right-rail overlay panel state
    private enum RailPanel { case none, settings, recent, allTime }
    @State private var activePanel: RailPanel = .none

    // Scene phase to manage screensaver/idle timer
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height

            // Right rail width: slim but readable
            let minRail: CGFloat = 360
            let railW = max(minRail, totalW * 0.22)

            // Gap between video and rail
            let gutter: CGFloat = 24

            // Largest 16:9 video that fits beside the rail accounting for the gutter
            let availableW = totalW - railW - gutter
            let videoW = min(availableW, totalH * (16.0/9.0))
            let videoH = videoW * (9.0/16.0)

            VStack(spacing: 0) {
                ZStack {
                    Color.black // full-canvas background
                    HStack(spacing: gutter) {
                        // LEFT: Video
                        ZStack {
                            Color.black
                            VideoPlayer(player: player)
                                .frame(width: videoW, height: videoH)
                                .clipped()
                        }
                        .frame(width: availableW, height: totalH)

                        // RIGHT: Rail
                        rightRail(width: railW, height: totalH)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Global bottom bar under the video & rail
                bottomBar
            }
            .ignoresSafeArea()
            .onAppear {
                setIdleTimerDisabled(true)
                let item = AVPlayerItem(url: streamURL)
                player.replaceCurrentItem(with: item)
                player.play()

                if let restored = loadPlayers(), !restored.isEmpty {
                    players = restored
                } else if players.isEmpty { // first run
                    players = [Player(name: "TeJay"), Player(name: "Shay")]
                    savePlayers()
                }
                if recentGames.isEmpty, let restoredGames = loadRecentGames() {
                    recentGames = restoredGames
                }
                if allTimeTotals.isEmpty, let restoredTotals = loadAllTimeTotals() {
                    allTimeTotals = restoredTotals
                }
                // Ensure we have a start time for the current game
                if Calendar.current.isDateInToday(gameStartedAt) == false {
                    gameStartedAt = Date()
                }
            }
            .onDisappear {
                player.pause()
                setIdleTimerDisabled(false)
            }
            .onChange(of: players) { savePlayers() }
            .onChange(of: recentGames) { saveRecentGames() }
            .onChange(of: allTimeTotals) { saveAllTimeTotals() }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    setIdleTimerDisabled(true)
                default:
                    setIdleTimerDisabled(false)
                }
            }
        }
    }

    // MARK: - Right Rail pieces
    @ViewBuilder
    private func rightRail(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            switch activePanel {
            case .none:
                // Default: scorekeeper
                titleView
                Divider()
                addPlayerRow
                playersList
                Spacer()
            case .recent:
                panelHeader(title: "Recent Games")
                Divider()
                recentGamesListContent
                Spacer()
            case .allTime:
                panelHeader(title: "All-Time Leaderboard", twoLine: true, centered: true)
                Divider()
                allTimeLeaderboardListContent
                Spacer()
            case .settings:
                panelHeader(title: "Settings")
                Divider()
                SettingsScreen(
                    players: $players,
                    onResetRecentGames: { resetRecentGames() },
                    onClearAllTime: { clearAllTimeLeaderboard() }
                )
            }
        }
        .frame(width: width, height: height)
        .background(Color.black.opacity(0.35))
    }


    @ViewBuilder
    private func panelHeader(title: String, twoLine: Bool = false, centered: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.title2)
                .bold()
                .lineLimit(twoLine ? 2 : 1)
                .minimumScaleFactor(0.6)
                .truncationMode(.tail)
                .allowsTightening(true)
                .multilineTextAlignment(centered ? .center : .leading)
            Spacer()
        }
        .padding([.top, .horizontal])
    }

    @ViewBuilder
    private var recentGamesListContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if recentGames.isEmpty {
                    Text("No recent games yet")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    ForEach(recentGames.reversed()) { game in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(dateShort(game.startedAt)) → \(dateShort(game.endedAt))")
                                .font(.headline)
                            ForEach(game.entries) { entry in
                                HStack {
                                    Text(entry.name)
                                    Spacer()
                                    Text("\(entry.score)")
                                        .monospacedDigit()
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var allTimeLeaderboardListContent: some View {
        let sortedTotals: [(name: String, score: Int)] = allTimeTotals.map { ($0.key, $0.value) }.sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.name < rhs.name }
            return lhs.score > rhs.score
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if sortedTotals.isEmpty {
                    Text("No scores yet")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    ForEach(Array(sortedTotals.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(item.score)")
                                .monospacedDigit()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding()
        }
    }

    private func dateShort(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: d)
    }

    @ViewBuilder
    private var titleView: some View {
        VStack(spacing: 0) {
            Text("What Are")
                .lineLimit(1)
            Text("They Selling?")
                .lineLimit(1)
        }
        .font(.largeTitle)
        .bold()
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top)
    }

    @ViewBuilder
    private var addPlayerRow: some View {
        HStack(spacing: 12) {
            TextField("Add Player Name", text: $newPlayerNameRail)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 0, maxWidth: .infinity)
            Button("Add") {
                addPlayer(named: newPlayerNameRail)
                newPlayerNameRail = ""
            }
            .buttonStyle(.bordered)
            .disabled(newPlayerNameRail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding([.horizontal, .top])
    }

    @ViewBuilder
    private var playersList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if players.isEmpty {
                    Text("No players yet")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    ForEach(players.indices, id: \.self) { idx in
                        playerCell(idx: idx)
                        Divider()
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func playerCell(idx: Int) -> some View {
        let p = players[idx]
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(p.name)
                    .font(.title3)
                    .bold()
                    .lineLimit(1)
                Spacer()
                Text("\(p.score)")
                    .font(.title3)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            scoreButtons(idx: idx)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func scoreButtons(idx: Int) -> some View {
        HStack(spacing: 12) {
            scoreButton(label: "+3", points: 3, idx: idx)
            scoreButton(label: "+1", points: 1, idx: idx)
            scoreButton(label: "+5", points: 5, idx: idx)
        }
    }

    // MARK: - tvOS-safe focused button
    private func scoreButton(label: String, points: Int, idx: Int) -> some View {
        FocusScoreButton(label: label) {
            award(points: points, toIndex: idx)
            savePlayers()
        }
    }

    private struct FocusScoreButton: View {
        let label: String
        let action: () -> Void
        @FocusState private var isFocused: Bool

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            ZStack {
                shape
                    .fill(Color.white.opacity(isFocused ? 0.18 : 0.10))
                shape
                    .stroke(Color.white.opacity(isFocused ? 0.75 : 0.35), lineWidth: isFocused ? 2 : 1)
                Text(label)
                    .font(.title3).bold()
                    .foregroundColor(.white)
            }
            .frame(width: 96, height: 60)
            .contentShape(shape)
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .focusable(true)
            .focused($isFocused)
            .onTapGesture {
                action()
            }
        }
    }


    @ViewBuilder
    private var bottomBar: some View {
        // A single row along the bottom of the screen, full width
        ZStack {
            Color.black.opacity(0.35)
        }
        .overlay(
            HStack(spacing: 16) {
                switch activePanel {
                case .none:
                    // Left-side actions
                    Button("📜 Recent Games") { activePanel = .recent }
                        .buttonStyle(.bordered)
                        .lineLimit(1)
                    Button("🏆 All-Time Leaderboard") { activePanel = .allTime }
                        .buttonStyle(.bordered)
                        .lineLimit(1)

                    Spacer()

                    // Right-side primary actions
                    Button("🏁 End Game") { showConfirmEndGame = true }
                        .buttonStyle(.borderedProminent)
                        .lineLimit(1)
                    Button("⚙️ Settings") { activePanel = .settings }
                        .buttonStyle(.bordered)
                        .lineLimit(1)

                case .recent:
                    // Left-side actions (replace selected with Back)
                    Button("⬅️ Back to Scores") { activePanel = .none }
                        .buttonStyle(.bordered)
                        .lineLimit(1)
                    Button("🏆 All-Time Leaderboard") { activePanel = .allTime }
                        .buttonStyle(.bordered)
                        .lineLimit(1)

                    Spacer()

                    // Right-side primary actions
                    Button("🏁 End Game") { showConfirmEndGame = true }
                        .buttonStyle(.borderedProminent)
                        .lineLimit(1)
                    Button("⚙️ Settings") { activePanel = .settings }
                        .buttonStyle(.bordered)
                        .lineLimit(1)

                case .allTime:
                    // Left-side actions (replace selected with Back)
                    Button("📜 Recent Games") { activePanel = .recent }
                        .buttonStyle(.bordered)
                        .lineLimit(1)
                    Button("⬅️ Back to Scores") { activePanel = .none }
                        .buttonStyle(.bordered)
                        .lineLimit(1)

                    Spacer()

                    // Right-side primary actions
                    Button("🏁 End Game") { showConfirmEndGame = true }
                        .buttonStyle(.borderedProminent)
                        .lineLimit(1)
                    Button("⚙️ Settings") { activePanel = .settings }
                        .buttonStyle(.bordered)
                        .lineLimit(1)

                case .settings:
                    // Left-side actions (show other panels)
                    Button("📜 Recent Games") { activePanel = .recent }
                        .buttonStyle(.bordered)
                        .lineLimit(1)
                    Button("🏆 All-Time Leaderboard") { activePanel = .allTime }
                        .buttonStyle(.bordered)
                        .lineLimit(1)

                    Spacer()

                    // Right-side primary actions (Back to Scores replaces Settings here)
                    Button("🏁 End Game") { showConfirmEndGame = true }
                        .buttonStyle(.borderedProminent)
                        .lineLimit(1)
                    Button("⬅️ Back to Scores") { activePanel = .none }
                        .buttonStyle(.bordered)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 24)
        )
        .confirmationDialog(
            "End current game?",
            isPresented: $showConfirmEndGame,
            titleVisibility: .visible
        ) {
            Button("End Game", role: .destructive) { endGame() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will record the current scores to Recent Games, add them to the All-Time Leaderboard, reset all scores to 0, and start a new game.")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
    }

    // MARK: - Logic
    private func award(points: Int, toIndex idx: Int) {
        guard players.indices.contains(idx) else { return }
        players[idx].score += points
        // Force a state change even if Player is a reference type
        players = Array(players)
    }

    private func addPlayer(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !players.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            players.append(Player(name: trimmed))
            savePlayers()
        }
    }

    private func savePlayers() {
        let payload: [[String: Any]] = players.map { ["name": $0.name, "score": $0.score] }
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            UserDefaults.standard.set(data, forKey: playersStorageKey)
        }
    }

    private func loadPlayers() -> [Player]? {
        guard let data = UserDefaults.standard.data(forKey: playersStorageKey),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        var restored: [Player] = []
        for item in raw {
            if let name = item["name"] as? String {
                let score = (item["score"] as? Int) ?? 0
                var p = Player(name: name)
                p.score = score
                restored.append(p)
            }
        }
        return restored
    }

    private func endGame() {
        let ended = Date()
        let start = gameStartedAt
        // Snapshot player scores
        let snapshot = players.map { ScoreEntry(name: $0.name, score: $0.score) }
        let record = GameRecord(startedAt: start, endedAt: ended, entries: snapshot)
        // Accumulate into all-time totals
        for entry in snapshot {
            allTimeTotals[entry.name, default: 0] += entry.score
        }
        saveAllTimeTotals()
        recentGames.append(record)
        saveRecentGames()
        // Reset scores and begin a new game
        resetScores()
        gameStartedAt = Date()
    }
    private func saveAllTimeTotals() {
        let dict = allTimeTotals
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            UserDefaults.standard.set(data, forKey: allTimeTotalsStorageKey)
        }
    }

    private func loadAllTimeTotals() -> [String: Int]? {
        guard let data = UserDefaults.standard.data(forKey: allTimeTotalsStorageKey),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var totals: [String: Int] = [:]
        for (k, v) in raw {
            totals[k] = v as? Int ?? 0
        }
        return totals
    }

    private func resetRecentGames() {
        recentGames.removeAll()
        saveRecentGames()
    }

    private func clearAllTimeLeaderboard() {
        allTimeTotals.removeAll()
        saveAllTimeTotals()
    }

    private func resetScores() {
        for i in players.indices { players[i].score = 0 }
        players = Array(players) // trigger UI refresh
        savePlayers()
    }

    private func saveRecentGames() {
        let payload: [[String: Any]] = recentGames.map { rec in
            return [
                "startedAt": rec.startedAt.timeIntervalSince1970,
                "endedAt": rec.endedAt.timeIntervalSince1970,
                "entries": rec.entries.map { ["name": $0.name, "score": $0.score] }
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            UserDefaults.standard.set(data, forKey: recentGamesStorageKey)
        }
    }

    private func loadRecentGames() -> [GameRecord]? {
        guard let data = UserDefaults.standard.data(forKey: recentGamesStorageKey),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        var records: [GameRecord] = []
        for item in raw {
            guard let s = item["startedAt"] as? Double,
                  let e = item["endedAt"] as? Double,
                  let arr = item["entries"] as? [[String: Any]] else { continue }
            let started = Date(timeIntervalSince1970: s)
            let ended = Date(timeIntervalSince1970: e)
            var entries: [ScoreEntry] = []
            for ent in arr {
                if let name = ent["name"] as? String {
                    let score = (ent["score"] as? Int) ?? 0
                    entries.append(ScoreEntry(name: name, score: score))
                }
            }
            records.append(GameRecord(startedAt: started, endedAt: ended, entries: entries))
        }
        return records
    }
    private func setIdleTimerDisabled(_ disabled: Bool) {
        // tvOS: prevent screensaver/sleep while app is active
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
    }
}

// MARK: - Settings Screen
struct SettingsScreen: View {
    @Binding var players: [Player]
    let onResetRecentGames: () -> Void
    let onClearAllTime: () -> Void
    @State private var newPlayerName: String = ""
    @State private var showConfirmResetRecent = false
    @State private var showConfirmClearAllTime = false
    private let protectedNames: Set<String> = ["TeJay", "Shay"]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    TextField("Add Player Name", text: $newPlayerName)
                        .textFieldStyle(.plain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 0, maxWidth: .infinity)
                    Button("Add") { addPlayer() }
                        .buttonStyle(.bordered)
                        .disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                List {
                    ForEach(players.indices, id: \.self) { idx in
                        let p = players[idx]
                        HStack(spacing: 12) {
                            Text(p.name)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            if !protectedNames.contains(p.name) {
                                FocusTrashIcon { remove(at: idx) }
                            } else {
                                Text("Required")
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Button(role: .destructive) { showConfirmResetRecent = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Reset Recent Games")
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .confirmationDialog(
                        "Reset Recent Games?",
                        isPresented: $showConfirmResetRecent,
                        titleVisibility: .visible
                    ) {
                        Button("Reset Recent Games", role: .destructive) { onResetRecentGames() }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will permanently clear the entire list of past games. Current scores are unaffected.")
                    }

                    Button(role: .destructive) { showConfirmClearAllTime = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "list.number")
                            Text("Clear All-Time Leaderboard")
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .confirmationDialog(
                        "Clear All-Time Leaderboard?",
                        isPresented: $showConfirmClearAllTime,
                        titleVisibility: .visible
                    ) {
                        Button("Clear All-Time Leaderboard", role: .destructive) { onClearAllTime() }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will permanently clear all cumulative scores for every player.")
                    }
                }
                .padding(.top, 8)
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
        }
    }
    private func addPlayer() {
        let trimmed = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !players.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            players.append(Player(name: trimmed))
        }
        newPlayerName = ""
    }

    private func remove(at index: Int) {
        guard players.indices.contains(index) else { return }
        let name = players[index].name
        guard !protectedNames.contains(name) else { return }
        players.remove(at: index)
    }
    private struct FocusTrashIcon: View {
        let action: () -> Void
        @FocusState private var isFocused: Bool

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            ZStack {
                shape
                    .fill(Color.red.opacity(isFocused ? 0.22 : 0.12))
                shape
                    .stroke(Color.red.opacity(isFocused ? 0.90 : 0.50), lineWidth: isFocused ? 2 : 1)
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                    .imageScale(.large)
            }
            .frame(width: 44, height: 44)
            .contentShape(shape)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isFocused)
            .focusable(true)
            .focused($isFocused)
            .onTapGesture { action() }
        }
    }
}

// MARK: - Game History Models
struct GameRecord: Identifiable, Equatable {
    let id = UUID()
    let startedAt: Date
    let endedAt: Date
    let entries: [ScoreEntry]
}

struct ScoreEntry: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let score: Int
}

// MARK: - Recent Games Screen
struct RecentGamesScreen: View {
    let games: [GameRecord]

    private static let df: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if games.isEmpty {
                        Text("No recent games yet")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(games.reversed()) { game in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(Self.df.string(from: game.startedAt)) → \(Self.df.string(from: game.endedAt))")
                                    .font(.headline)
                                ForEach(game.entries) { entry in
                                    HStack {
                                        Text(entry.name)
                                        Spacer()
                                        Text("\(entry.score)")
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Recent Games")
        }
    }
}

// MARK: - All-Time Leaderboard Screen
struct AllTimeLeaderboardScreen: View {
    let totals: [String: Int]

    var sortedTotals: [(name: String, score: Int)] {
        totals.map { ($0.key, $0.value) }.sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.name < rhs.name }
            return lhs.score > rhs.score
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if sortedTotals.isEmpty {
                        Text("No scores yet")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(sortedTotals.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(item.score)")
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("All-Time Leaderboard")
        }
    }
}

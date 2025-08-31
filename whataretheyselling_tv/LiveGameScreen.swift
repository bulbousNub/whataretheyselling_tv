import SwiftUI
import AVKit

struct LiveGameScreen: View {
    // MARK: - Inputs
    let streamURL: URL

    // MARK: - State
    @State private var player = AVPlayer()
    @State private var players: [Player] = []
    @State private var showSettings = false
    @State private var newPlayerNameRail: String = ""
    private let playersStorageKey = "WATS_players_v1"

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height

            // Right rail width: slim but readable
            let minRail: CGFloat = 360
            let railW = max(minRail, totalW * 0.22)

            // Largest 16:9 video that fits beside the rail
            let availableW = totalW - railW
            let videoW = min(availableW, totalH * (16.0/9.0))
            let videoH = videoW * (9.0/16.0)

            ZStack {
                Color.black // full-canvas background
                HStack(spacing: 0) {
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
            .ignoresSafeArea()
            .onAppear {
                let item = AVPlayerItem(url: streamURL)
                player.replaceCurrentItem(with: item)
                player.play()

                if let restored = loadPlayers(), !restored.isEmpty {
                    players = restored
                } else if players.isEmpty { // first run
                    players = [Player(name: "TeJay"), Player(name: "Shay")]
                    savePlayers()
                }
            }
            .onDisappear { player.pause() }
            .onChange(of: players) { _ in savePlayers() }
            .sheet(isPresented: $showSettings) {
                SettingsScreen(players: $players)
            }
        }
    }

    // MARK: - Right Rail pieces
    @ViewBuilder
    private func rightRail(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            titleView
            Divider()
            addPlayerRow
            playersList
            Spacer()
            settingsButton
        }
        .frame(width: width, height: height)
        .background(Color.black.opacity(0.35))
    }

    @ViewBuilder
    private var titleView: some View {
        Text("What Are They Selling?")
            .font(.largeTitle)
            .bold()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top)
    }

    @ViewBuilder
    private var addPlayerRow: some View {
        HStack(spacing: 12) {
            TextField("Add player name", text: $newPlayerNameRail)
                .textFieldStyle(.plain)
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
                Spacer()
                Text("\(p.score)")
                    .font(.title3)
                    .monospacedDigit()
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
        @State private var isFocused: Bool = false

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
            .focusable(true) { focused in
                isFocused = focused
            }
            .onTapGesture {
                action()
            }
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            HStack {
                Image(systemName: "gear")
                Text("Settings")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .padding()
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
}

// MARK: - Settings Screen
struct SettingsScreen: View {
    @Binding var players: [Player]
    @State private var newPlayerName: String = ""
    private let protectedNames: Set<String> = ["TeJay", "Shay"]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    TextField("Add player name", text: $newPlayerName)
                        .textFieldStyle(.plain)
                    Button("Add") { addPlayer() }
                        .buttonStyle(.bordered)
                        .disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                List {
                    ForEach(players.indices, id: \.self) { idx in
                        let p = players[idx]
                        HStack {
                            Text(p.name)
                            Spacer()
                            if !protectedNames.contains(p.name) {
                                Button(role: .destructive) { remove(at: idx) } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            } else {
                                Text("Required").foregroundColor(.secondary).font(.footnote)
                            }
                        }
                    }
                }
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
}

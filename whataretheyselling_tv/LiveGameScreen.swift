import SwiftUI
import AVKit
import UIKit
import AVFoundation

struct LiveGameScreen: View {
    // MARK: - Inputs
    let streamURL: URL

    // MARK: - State
    @State private var player = AVPlayer()
    // Scrollable channel picker model/state
    private struct ChannelItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let url: URL
    }
    @State private var channelItems: [ChannelItem] = []
    @State private var selectedChannelIndex: Int = 0
    // Fullscreen presentation state for the video player
    @State private var isPresentingFullscreen = false
    // tvOS focus routing
    private enum FocusTarget { case player, channelBar, rightRail, bottomBar }
    @FocusState private var focusTarget: FocusTarget?
    // Horizontal scroll state for channel bar
    @State private var channelContentWidth: CGFloat = 0
    @State private var channelScrollOffset: CGFloat = 0
    @State private var channelHasMoreLeft: Bool = false
    @State private var channelHasMoreRight: Bool = false
    @State private var channelCanScroll: Bool = false
    private let qvc2URL = URL(string: "https://qvc-amd-live.akamaized.net/hls/live/2034113/lsqvc2us/master.m3u8")!
    private let hsnURL = URL(string: "https://qvc-amd-live.akamaized.net/hls/live/2034113/lshsn1us/master.m3u8")!
    private let hsn2URL = URL(string: "https://qvc-amd-live.akamaized.net/hls/live/2034113/lshsn2us/master.m3u8")!
    // Additional channels
    private let qvc1URL = URL(string: "https://qvc-amd-live.akamaized.net/hls/live/2034113/lsqvc1us/master.m3u8")!
    private let qvc3URL = URL(string: "https://qvc-amd-live.akamaized.net/hls/live/2034113/lsqvc3us/master.m3u8")!
    private let inTheKitchenURL = URL(string: "https://qvc-amd-live.akamaized.net/hls/live/2034113/lsqvc4us/master.m3u8")!
    private let qvcUKURL = URL(string: "https://qvcuk-live.akamaized.net/hls/live/2097112/qvc/master.m3u8")!
    private let qvcUKBeautyURL = URL(string: "https://qvcuk-live.akamaized.net/hls/live/2097112/qby/master.m3u8")!
    private let qvcUKStyleURL = URL(string: "https://qvcuk-live.akamaized.net/hls/live/2097112/qst/master.m3u8")!
    private let qvcUKExtraURL = URL(string: "https://qvcuk-live.akamaized.net/hls/live/2097112/qex/master.m3u8")!
    private let qvcJapanURL = URL(string: "https://cdn-live1.qvc.jp/iPhone/1501/1501.m3u8")!
    private let qvcItaliaURL = URL(string: "https://qrg.akamaized.net/hls/live/2017383/lsqvc1it/master.m3u8")!
    private let qvcGermanyURL = URL(string: "https://qvcde-live.akamaized.net/hls/live/2097104/qvc/master.m3u8")!
    private let qvc2GermanyURL = URL(string: "https://qvcde-live.akamaized.net/hls/live/2097104/qps/master.m3u8")!
    private let bigDishURL = URL(string: "https://amg01717-qvc-amg01717c1-stirr-us-2651.playouts.now.amagi.tv/qvc-bigdishdelayed-switcher-localnow/playlist.m3u8")!
    private let qvcWestURL = URL(string: "https://qvc-amd-live.akamaized.net/hls/live/2034113/lsqvc1uswest/master.m3u8")!
    private let hsnWestURL = URL(string: "https://qvc-amd-live.akamaized.net/hls/live/2034113/lshsn1uswest/master.m3u8")!
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
    // Full Rules & Scoring content (from iOS version)
    @State private var rulesText: String = """
RULES & SCORING

OBJECTIVE
Guess what product or category is being sold on screen before the reveal. The app is the scorekeeper; the host controls scoring.

SETUP
• Agree on acceptable categories up front (see list below).
• Players can shout guesses at any time; the host decides when to award points.
• The app only tracks scores and game history; it does not auto-judge answers.

HOW TO PLAY
1) Watch a segment.
2) Before the reveal, players guess the product/category.
3) On reveal, the host decides who was correct and awards points.
4) Use the +1 / +3 / +5 buttons to assign points.
5) Tap “End Game” to record the session; a new game starts automatically.

SCORING
• +3  Exact Match – Player names the correct primary category (or the exact product category you agreed counts).
• +1  Fastest Correct (optional) – First correct guess gets an extra +1.
• +5  Wildcard “Nailed It” (optional) – For an especially precise or clever guess (brand/subcategory/feature) at host’s discretion.
• +1  Partial Credit – For close-but-not-quite answers to keep momentum.

CLOSE CALLS & JUDGING
• Use the retailer’s PRIMARY category or the on-screen classification when in doubt.
• If an item spans multiple categories, accept the primary one.
• House rules: award partials generously to keep the pace fun.

WINNING & VARIATIONS
• Target Score – First to 21 (or 31) wins.
• Lightning Round – 30–60 sec clips, rapid-fire guesses, award +1 only.
• Category Draft – Each player drafts 2–3 categories; they alone can score +3 in their drafted categories (others still earn +1 partials).
• Loser’s Tax – Lowest score hosts the next round.

ACCEPTABLE CATEGORIES
• Beauty & Personal Care
• Fashion, Footwear & Accessories (includes Jewelry & Watches)
• Home & Furniture (includes Cleaning & Organization)
• Kitchen & Dining
• Appliances
• Electronics (phones, computers, TV & home theater)
• Sports, Fitness & Outdoors
• Grocery, Snacks & Beverages
• Baby, Kids, Toys & Games
• Pets
• Auto, DIY & Tools
• Garden & Outdoor Living
• Travel, Office & School
• Seasonal & Holiday
• Miscellaneous
"""
    @State private var showConfirmEndGame: Bool = false
    // Right-rail overlay panel state
    private enum RailPanel { case none, settings, recent, allTime, rules }
    @State private var activePanel: RailPanel = .none

    // Scene phase to manage screensaver/idle timer
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height

            let bottomBarH: CGFloat = 88
            let bottomInset = geo.safeAreaInsets.bottom

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
                        // LEFT: Video + Channel pills above the video box
                        VStack(spacing: 12) {
                            // Channel selector centered over the video frame (scrollable + end indicators)
                            ZStack { // keep indicators layered over the capsule
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(channelItems.enumerated()), id: \.offset) { idx, item in
                                            CompactChannelSegment(
                                                title: item.title,
                                                isSelected: selectedChannelIndex == idx
                                            ) {
                                                selectedChannelIndex = idx
                                                setStream(url: item.url)
                                            }
                                            if idx < channelItems.count - 1 {
                                                Rectangle()
                                                    .fill(Color.white.opacity(0.25))
                                                    .frame(width: 1, height: 18)
                                                    .padding(.vertical, 6)
                                            }
                                        }
                                    }
                                    .background(
                                        GeometryReader { gp in
                                            Color.clear
                                                .preference(key: HContentWidthPreferenceKey.self, value: gp.size.width)
                                                .preference(key: HOffsetPreferenceKey.self, value: -gp.frame(in: .named("ChannelScroll")).minX)
                                        }
                                    )
                                    .padding(6)
                                }
                                .coordinateSpace(name: "ChannelScroll")
                                .background(Capsule().fill(Color.black.opacity(0.35)))
                                .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                                .clipShape(Capsule())

                                // Edge fades (always show when scrollable)
                                if channelCanScroll {
                                    HStack {
                                        // Left fade
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)]),
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                        .frame(width: 72, height: 36)
                                        .opacity(channelHasMoreLeft ? 0.9 : 0.35)
                                        Spacer(minLength: 0)
                                    }
                                    .allowsHitTesting(false)

                                    HStack {
                                        Spacer(minLength: 0)
                                        // Right fade
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)]),
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                        .frame(width: 72, height: 36)
                                        .opacity(channelHasMoreRight ? 0.9 : 0.35)
                                    }
                                    .allowsHitTesting(false)
                                }

                                // Chevrons (only when there is more in that direction)
                                if channelHasMoreLeft {
                                    HStack { indicatorLeft; Spacer(minLength: 0) }
                                        .allowsHitTesting(false)
                                        .transition(.opacity)
                                }
                                if channelHasMoreRight {
                                    HStack { Spacer(minLength: 0); indicatorRight }
                                        .allowsHitTesting(false)
                                        .transition(.opacity)
                                }
                            }
                            .frame(width: videoW)
                            .padding(.top, 8)
                            .clipped()
                            .focusSection()
                            .onPreferenceChange(HContentWidthPreferenceKey.self) { contentW in
                                // Guard to avoid re-rendering on tiny changes while scrolling
                                if abs(contentW - channelContentWidth) > 0.5 {
                                    channelContentWidth = contentW
                                    let canScroll = contentW > (videoW + 1)
                                    if canScroll != channelCanScroll { channelCanScroll = canScroll }
                                    let hasRight = (channelScrollOffset + videoW) < (contentW - 2)
                                    if hasRight != channelHasMoreRight { channelHasMoreRight = hasRight }
                                    let hasLeft = channelScrollOffset > 2
                                    if hasLeft != channelHasMoreLeft { channelHasMoreLeft = hasLeft }
                                }
                            }
                            .onPreferenceChange(HOffsetPreferenceKey.self) { offset in
                                // Quantize offset to reduce frequent tiny updates; only mutate when it materially changes
                                let quantized = (offset / 2.0).rounded() * 2.0
                                if abs(quantized - channelScrollOffset) > 0.5 {
                                    channelScrollOffset = quantized
                                    let hasRight = (quantized + videoW) < (channelContentWidth - 2)
                                    if hasRight != channelHasMoreRight { channelHasMoreRight = hasRight }
                                    let hasLeft = quantized > 2
                                    if hasLeft != channelHasMoreLeft { channelHasMoreLeft = hasLeft }
                                }
                            }
                            // Video box
                            ZStack {
                                Color.black
                                TVPlayerView(player: player)
                                    .clipped()
                                    .focusable(true)
                                    .focused($focusTarget, equals: .player)

                                // Invisible, full-frame click target to enter Full Screen
                                Button(action: { isPresentingFullscreen = true }) {
                                    Color.clear
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity, maxHeight: .infinity) // fill video area for taps
                                .focusable(false)          // do not steal focus from the player
                                .focusEffectDisabled(true) // prevent any tvOS focus halo
                                .opacity(0.0)              // no draw; remain hittable
                                .allowsHitTesting(focusTarget == .player)       // only intercept when player focused
                                .accessibilityHidden(true)

                                // Small visible badge in the corner (dim until the player is focused)
                                FullscreenBadge { isPresentingFullscreen = true }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                    .opacity(focusTarget == .player ? 1.0 : 0.35)
                                    .allowsHitTesting(true)
                                    .zIndex(1)
                            }
                            .frame(width: videoW, height: videoH)
                            .focusSection()
                        }
                        .frame(width: availableW, height: totalH, alignment: .top)

                        // RIGHT: Rail (full height; we’ll pad the scroll content instead)
                        rightRail(width: railW, height: totalH)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Global bottom bar under the video & rail
                bottomBar
            }
            .ignoresSafeArea()
            .onAppear {
                // Configure audio session & player for smoother HLS playback
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                try? AVAudioSession.sharedInstance().setActive(true)
                player.automaticallyWaitsToMinimizeStalling = true
                // Build full channel list (order matters)
                channelItems = [
                    ChannelItem(title: "QVC", url: qvc1URL),
                    ChannelItem(title: "QVC 2", url: qvc2URL),
                    ChannelItem(title: "QVC 3", url: qvc3URL),
                    ChannelItem(title: "HSN", url: hsnURL),
                    ChannelItem(title: "HSN 2", url: hsn2URL),
                    ChannelItem(title: "QVC In The Kitchen", url: inTheKitchenURL),
                    ChannelItem(title: "QVC UK", url: qvcUKURL),
                    ChannelItem(title: "QVC UK Beauty", url: qvcUKBeautyURL),
                    ChannelItem(title: "QVC UK Style", url: qvcUKStyleURL),
                    ChannelItem(title: "QVC UK Extra", url: qvcUKExtraURL),
                    ChannelItem(title: "QVC Japan", url: qvcJapanURL),
                    ChannelItem(title: "QVC Italia", url: qvcItaliaURL),
                    ChannelItem(title: "QVC Germany", url: qvcGermanyURL),
                    ChannelItem(title: "QVC 2 Germany", url: qvc2GermanyURL),
                    ChannelItem(title: "The Big Dish", url: bigDishURL),
                    ChannelItem(title: "QVC West", url: qvcWestURL),
                    ChannelItem(title: "HSN West", url: hsnWestURL),
                ]

                // Pick initial index based on incoming streamURL if present
                if let idx = channelItems.firstIndex(where: { $0.url.absoluteString == streamURL.absoluteString }) {
                    selectedChannelIndex = idx
                } else {
                    selectedChannelIndex = 0 // default to QVC
                }

                if player.currentItem == nil {
                    setStream(url: channelItems[selectedChannelIndex].url)
                }

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
                // Default focus to the player so the Siri Remote can bring up controls immediately
                if focusTarget == nil { focusTarget = .player }
            }
            .onDisappear {
                player.pause()
            }
            .onChange(of: selectedChannelIndex) { setStream(url: channelItems[selectedChannelIndex].url) }
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
            .fullScreenCover(isPresented: $isPresentingFullscreen) {
                FullscreenPlayerContainer(player: player)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Right Rail pieces
    @ViewBuilder
    private func rightRail(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            switch activePanel {
            case .rules:
                panelHeader(title: "Rules & Scoring", twoLine: true, centered: true)
                Divider()
                rulesPanelContent
                Spacer()
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
                SettingsScreen(
                    players: $players,
                    onResetRecentGames: { resetRecentGames() },
                    onClearAllTime: { clearAllTimeLeaderboard() }
                )
            }
        }
        .frame(width: width, height: height)
        .background(Color.black.opacity(0.35))
        .focusSection()
    }
    @ViewBuilder
    private var rulesPanelContent: some View {
        FocusableRulesList(text: rulesText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private struct FocusableRulesList: View {
        let paragraphs: [String]
        @FocusState private var focusedIndex: Int?

        init(text: String) {
            self.paragraphs = Self.makeParagraphs(from: text)
        }

        private static func makeParagraphs(from text: String) -> [String] {
            // Split on blank lines, but further split any block that contains bullet lines ("• ")
            let blocks = text.components(separatedBy: "\n\n")
            var result: [String] = []
            for raw in blocks {
                let block = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !block.isEmpty else { continue }
                if block.contains("\n• ") || block.hasPrefix("• ") {
                    // Separate non-bullet header lines from bullet lines so each bullet becomes its own focusable row
                    let lines = block.components(separatedBy: .newlines)
                    var headerLines: [String] = []
                    var bulletLines: [String] = []
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("•") {
                            bulletLines.append(trimmed)
                        } else if !trimmed.isEmpty {
                            headerLines.append(trimmed)
                        }
                    }
                    let header = headerLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !header.isEmpty { result.append(header) }
                    result.append(contentsOf: bulletLines)
                } else {
                    result.append(block)
                }
            }
            return result
        }

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, para in
                            ParagraphRow(text: para, isFocused: focusedIndex == index)
                                .focusable(true)
                                .focused($focusedIndex, equals: index)
                                .id(index)
                        }
                        // Focusable runway tail: minimally visible so tvOS will assign focus reliably
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .focusable(true)
                            .focused($focusedIndex, equals: paragraphs.count)
                            .focusEffectDisabled(true)
                            .id("rules_tail")
                            .accessibilityHidden(true)
                    }
                    .padding()
                    .padding(.bottom, 0)
                }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 40) }
                .focusSection()
                .onAppear {
                    // Ensure something is focused so the remote can scroll immediately
                    if focusedIndex == nil { focusedIndex = 0 }
                }
                .onChange(of: focusedIndex) { _, newVal in
                    // When the tail is focused, force-scroll to absolute bottom
                    if newVal == paragraphs.count {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("rules_tail", anchor: .bottom)
                        }
                    }
                }
                .onMoveCommand { direction in
                    switch direction {
                    case .down:
                        let lastIndex = max(0, paragraphs.count - 1)
                        if focusedIndex == lastIndex {
                            // Move focus to tail immediately, then scroll to ensure it’s fully visible
                            focusedIndex = paragraphs.count
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("rules_tail", anchor: .bottom)
                            }
                        }
                    case .up:
                        let lastIndex = max(0, paragraphs.count - 1)
                        if focusedIndex == paragraphs.count { // on the runway tail
                            // Move focus back to the last paragraph first, then scroll it into view
                            focusedIndex = lastIndex
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
    }

    private struct ParagraphRow: View {
        let text: String
        let isFocused: Bool
        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            Text(text)
                .font(.body)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .padding(8)
                .background(shape.fill(Color.white.opacity(isFocused ? 0.08 : 0.00)))
                .overlay(shape.stroke(Color.white.opacity(isFocused ? 0.25 : 0.00), lineWidth: 1))
        }
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
        FocusableRecentGamesList(games: recentGames)
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

    private static let dfShort: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()

    private func dateShort(_ d: Date) -> String { Self.dfShort.string(from: d) }

    @ViewBuilder
    private var titleView: some View {
        VStack {
            Image("GameLogo") // <- the asset name you gave it in Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 500, maxHeight: 250) // adjust as needed
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
            .focusEffectDisabled(true)   // kill the large tvOS halo
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .focusable(true)
            .focused($isFocused)
            .onTapGesture { action() }   // gesture-based tap to avoid Button focus ring
            .accessibilityLabel("Add \(label) points")
        }
    }



    private struct CompactChannelSegment: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        @FocusState private var isFocused: Bool

        var body: some View {
            let segmentShape = Capsule()
            Text(title)
                .font(.footnote).bold()
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    segmentShape.fill(
                        isSelected ? Color.white.opacity(isFocused ? 0.28 : 0.22)
                                   : Color.white.opacity(isFocused ? 0.18 : 0.10)
                    )
                )
                .overlay(
                    segmentShape.stroke(Color.white.opacity(isFocused ? 0.7 : 0.35), lineWidth: isFocused ? 1 : 0.8)
                )
                .contentShape(segmentShape)
                .focusable(true)
                .focused($isFocused)
                .focusEffectDisabled(true)
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .animation(.easeOut(duration: 0.10), value: isFocused)
                .onTapGesture { action() }
        }
    }


    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 16) {
            switch activePanel {
            case .none:
                // Left-side actions
                Button("📘 Rules") { activePanel = .rules }
                    .buttonStyle(.bordered)
                    .lineLimit(1)
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
                Button("📘 Rules") { activePanel = .rules }
                    .buttonStyle(.bordered)
                    .lineLimit(1)
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
                Button("📘 Rules") { activePanel = .rules }
                    .buttonStyle(.bordered)
                    .lineLimit(1)
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
                Button("📘 Rules") { activePanel = .rules }
                    .buttonStyle(.bordered)
                    .lineLimit(1)
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

            case .rules:
                // Left-side actions: Back to Scores, plus usual nav
                Button("⬅️ Back to Scores") { activePanel = .none }
                    .buttonStyle(.bordered)
                    .lineLimit(1)
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
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(Color.black.opacity(0.35))
        .ignoresSafeArea(edges: .bottom)
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
        .focusSection()
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

    // Codable helper for Player persistence (backward compatible)
    private struct PlayerCodec: Codable { let name: String; let score: Int }

    private func savePlayers() {
        let payload: [PlayerCodec] = players.map { PlayerCodec(name: $0.name, score: $0.score) }
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: playersStorageKey)
        }
    }

    private func loadPlayers() -> [Player]? {
        guard let data = UserDefaults.standard.data(forKey: playersStorageKey) else { return nil }
        // Try Codable first
        if let decoded = try? JSONDecoder().decode([PlayerCodec].self, from: data) {
            return decoded.map { codec in var p = Player(name: codec.name); p.score = codec.score; return p }
        }
        // Fallback to legacy dict array
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
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
        return nil
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
        if let data = try? JSONEncoder().encode(allTimeTotals) {
            UserDefaults.standard.set(data, forKey: allTimeTotalsStorageKey)
        }
    }

    private func loadAllTimeTotals() -> [String: Int]? {
        guard let data = UserDefaults.standard.data(forKey: allTimeTotalsStorageKey) else { return nil }
        // Try Codable first
        if let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            return decoded
        }
        // Fallback to legacy dict
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var totals: [String: Int] = [:]
            for (k, v) in raw { totals[k] = v as? Int ?? 0 }
            return totals
        }
        return nil
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
        if let data = try? JSONEncoder().encode(recentGames) {
            UserDefaults.standard.set(data, forKey: recentGamesStorageKey)
        }
    }

    private func loadRecentGames() -> [GameRecord]? {
        guard let data = UserDefaults.standard.data(forKey: recentGamesStorageKey) else { return nil }
        // Try Codable first
        if let decoded = try? JSONDecoder().decode([GameRecord].self, from: data) {
            return decoded
        }
        // Fallback to legacy dict array
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
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
        return nil
    }
    // MARK: - Playback helpers (asset-first, system-managed captions)
    private func playURL(_ url: URL, preferredCaptionLang: String?) {
        let asset = AVURLAsset(url: url)
        let keys = ["playable"]
        asset.loadValuesAsynchronously(forKeys: keys) {
            var error: NSError?
            let status = asset.statusOfValue(forKey: "playable", error: &error)
            DispatchQueue.main.async {
                guard status == .loaded, error == nil else { return }
                let item = AVPlayerItem(asset: asset)
                // Let AVPlayerViewController handle subtitles/audio via its native UI
                self.player.replaceCurrentItem(with: item)
                self.player.play()
            }
        }
    }

    private func setStream(url: URL) {
        playURL(url, preferredCaptionLang: nil)
    }

    private func setIdleTimerDisabled(_ disabled: Bool) {
        // tvOS: prevent screensaver/sleep while app is active
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
    }
}


// MARK: - Native tvOS Player Wrapper (AVPlayerViewController)
struct TVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.requiresLinearPlayback = false
        vc.videoGravity = .resizeAspect
        vc.view.isUserInteractionEnabled = true
        return vc
    }
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player { vc.player = player }
    }
}

// MARK: - Full Screen Player Container
private struct FullscreenPlayerContainer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.requiresLinearPlayback = false
        vc.videoGravity = .resizeAspect
        vc.view.isUserInteractionEnabled = true
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player { vc.player = player }
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
            .focusEffectDisabled(true)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isFocused)
            .focusable(true)
            .focused($isFocused)
            .onTapGesture { action() }
        }
    }


}


// MARK: - Game History Models
struct GameRecord: Identifiable, Equatable, Codable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let entries: [ScoreEntry]

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date, entries: [ScoreEntry]) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entries = entries
    }
}

struct ScoreEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let score: Int

    init(id: UUID = UUID(), name: String, score: Int) {
        self.id = id
        self.name = name
        self.score = score
    }
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


fileprivate enum _WATSFormatters {
    static let short: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
}
fileprivate func dateShortStatic(_ d: Date) -> String {
    _WATSFormatters.short.string(from: d)
}

    private struct FocusableRecentGamesList: View {
        let games: [GameRecord]
        @FocusState private var focusedIndex: Int?

        private var displayGames: [GameRecord] { games.reversed() }

        var body: some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if displayGames.isEmpty {
                        Text("No recent games yet")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach(Array(displayGames.enumerated()), id: \.offset) { index, game in
                            GameCard(game: game, isFocused: focusedIndex == index)
                                .focusable(true)
                                .focused($focusedIndex, equals: index)
                        }
                        // Extra scroll runway so final items aren’t clipped and remain reachable by focus on tvOS
                        Color.clear
                            .frame(height: 240)
                    }
                }
                .padding()
            }
            .onAppear {
                if focusedIndex == nil { focusedIndex = 0 }
            }
        }
    }

    private struct GameCard: View {
        let game: GameRecord
        let isFocused: Bool
        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(dateShortStatic(game.startedAt)) → \(dateShortStatic(game.endedAt))")
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
            .background(shape.fill(Color.white.opacity(isFocused ? 0.10 : 0.06)))
            .overlay(shape.stroke(Color.white.opacity(isFocused ? 0.30 : 0.00), lineWidth: 1))
        }
    }

    // MARK: - Channel bar scroll indicators
    private var indicatorLeft: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left")
                .font(.title2.weight(.black))
                .foregroundColor(.white.opacity(0.95))
        }
        .padding(.leading, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.65), Color.black.opacity(0.0)]), startPoint: .leading, endPoint: .trailing)
                .clipShape(Capsule())
        )
    }

    private var indicatorRight: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.title2.weight(.black))
                .foregroundColor(.white.opacity(0.95))
        }
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.65)]), startPoint: .leading, endPoint: .trailing)
                .clipShape(Capsule())
        )
    }

    // MARK: - Scroll offset preference keys for channel bar
    private struct HOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
    private struct HContentWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }


// MARK: - Small on-video badge for entering Full Screen
private struct FullscreenBadge: View {
    let action: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        // Gesture-based, so no tvOS Button halo
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .imageScale(.medium)
            .padding(6)
            .background(
                shape.fill(Color.black.opacity(focused ? 0.75 : 0.45)) // slightly brighter when focused
            )
            .overlay(
                shape.stroke(Color.white.opacity(focused ? 1.0 : 0.5), lineWidth: focused ? 3 : 1.5) // stronger outline
            )
            .foregroundColor(.white)
            .contentShape(shape)
            .focusable(true)
            .focused($focused)
            .focusEffectDisabled(true)
            .scaleEffect(focused ? 1.12 : 1.0) // slightly larger on focus
            .shadow(color: Color.white.opacity(focused ? 0.60 : 0), radius: focused ? 10 : 0) // slightly stronger glow on focus
            .animation(.easeOut(duration: 0.12), value: focused)
            .onTapGesture { action() }
            .accessibilityLabel("Enter Full Screen")
            .accessibilityHint("Play video in full-screen mode")
    }
}

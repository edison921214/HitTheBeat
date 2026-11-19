import SwiftUI
import Combine
import AVFoundation

private let lime = Color(red: 0.83, green: 1, blue: 0.27)
private enum Phase { case ready, playing, done }

private final class GameState: ObservableObject {
    @Published var phase = Phase.ready
    @Published var round = Round()
    @Published var accentAt = -10.0
    @Published var start = 0.0
    @Published var player: AVAudioPlayer?
    @Published var time = 0.0
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scene
    @StateObject private var game = GameState()
    private let clock = Timer.publish(every: 1 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("POPPING", systemImage: "waveform")
                Spacer()
                Text("80 BPM")
            }
            .font(.system(.subheadline, design: .monospaced).bold())
            .foregroundStyle(lime)
            Text("Hit the Beat")
                .font(.system(size: 50, weight: .black, design: .rounded))
            Text("幫舞者練習對拍，把每個 hit 卡在鼓點上。")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 5) {
                ForEach(game.round.hits.indices, id: \.self) { i in
                    Capsule().fill(color(for: i)).frame(height: 7)
                }
            }
            HStack {
                Text(game.phase == .playing ? (Round.index(at: game.time) < 0 ? "預備　" : "拍數　") + centerLabel : game.phase == .done ? "八拍結算" : "八拍卡拍挑戰")
                Spacer()
                Text("\(game.round.score) / 16").monospacedDigit()
            }
            Spacer(minLength: 4)
            ZStack {
                Circle().stroke(lime.opacity(0.6), lineWidth: 2)
                Circle().fill(lime).scaleEffect(scale)
                if game.phase == .done {
                    VStack {
                        Text(centerLabel).font(.system(size: 44, weight: .black))
                        Text("總分").bold()
                    }.foregroundStyle(.black)
                } else {
                    BeatDancer(time: game.phase == .playing ? max(0, game.time) : 0,
                               accentAge: game.time - game.accentAt)
                        .padding(28)
                        .accessibilityLabel("跟著節拍跳 Popping 的舞者")
                }
            }
            .aspectRatio(1, contentMode: .fit).frame(maxWidth: 265, maxHeight: 265)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 4)
            Text(message)
                .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                .multilineTextAlignment(.center)
            Button {
                if game.phase == .playing {
                    let now = ProcessInfo.processInfo.systemUptime - game.start
                    let before = game.round.perfects
                    game.round.tap(at: now)
                    if game.round.perfects > before { game.accentAt = now }
                } else { begin() }
            } label: {
                Text(game.phase == .ready ? "開始挑戰" : game.phase == .done ? "再跳一次" : "HIT！")
                    .font(.title2.bold()).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(lime, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black)
            }.buttonStyle(.plain)
        }
        .padding(24).foregroundStyle(.white)
        .background(Color(red: 0.065, green: 0.08, blue: 0.11).ignoresSafeArea())
        .onReceive(clock) { _ in
            guard game.phase == .playing else { return }
            game.time = ProcessInfo.processInfo.systemUptime - game.start
            game.round.closePrevious(at: game.time)
            if Round.index(at: game.time) >= 8 { game.phase = .done }
        }
        .onChange(of: scene) { _, newValue in
            if newValue != .active && game.phase == .playing {
                game.player?.stop()
                game.round = Round()
                game.phase = .ready
            }
        }
    }

    private func begin() {
        if game.player == nil, let url = Bundle.main.url(forResource: "Beat", withExtension: "wav") {
            game.player = try? AVAudioPlayer(contentsOf: url)
        }
        game.player?.currentTime = 0
        game.player?.prepareToPlay()
        game.round = Round()
        game.accentAt = -10
        game.start = ProcessInfo.processInfo.systemUptime + 0.12
        if let player = game.player { player.play(atTime: player.deviceCurrentTime + 0.12) }
        game.time = -0.12
        game.phase = .playing
    }

    private var scale: CGFloat {
        guard game.phase == .playing else { return 0.87 }
        let position = max(0, game.time) / Round.beat
        return 1 - 0.75 * abs(position - position.rounded())
    }

    private var centerLabel: String {
        if game.phase == .ready { return "HIT" }
        if game.phase == .done { return String(game.round.score) }
        if Round.index(at: game.time) < 0 { return String(max(1, 4 - Int(max(0, game.time) / Round.beat))) }
        return String(min(8, Round.index(at: game.time) + 1))
    }

    private var message: String {
        if game.phase == .ready { return "先聽四拍預備，圓點碰到外圈時按 HIT！" }
        if game.phase == .done { return "Perfect × \(game.round.perfects)　 Good × \(game.round.goods)\n未得分　\(8 - game.round.perfects - game.round.goods) 拍" }
        if let last = game.round.hits.compactMap({ $0 }).last { return last.label }
        return Round.index(at: game.time) < 0 ? "預備，跟著圓點數拍" : "抓準拍點！"
    }

    private func color(for index: Int) -> Color {
        switch game.round.hits[index] {
        case .perfect: return lime
        case .good: return .cyan
        case nil: return .white.opacity(0.2)
        default: return .orange
        }
    }
}

// 四組手臂角度依序切換。舞者在正拍定格，後半拍才移向下一個姿勢。
private struct BeatDancer: View {
    let time: Double
    let accentAge: Double

    private let poses: [[Double]] = [
        [160, -95, 20, -80], [115, 175, -15, -90],
        [195, -95, 65, 5], [145, 75, -45, -115]
    ]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 200
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            let beat = time / Round.beat
            let index = Int(beat) % poses.count
            let phase = beat - floor(beat)
            let t = min(1, max(0, (phase - 0.23) / 0.77))
            let blend = t * t * (3 - 2 * t)
            let accent = accentAge >= 0 ? max(0, 1 - accentAge / 0.19) : 0
            let sway = 8 * cos(.pi * beat)
            let bounce = 5 * (1 - cos(2 * .pi * beat))
            let ink = Color(red: 0.09, green: 0.09, blue: 0.14)
            let shirt = Color(red: 0.33, green: 0.19, blue: 0.54)
            let skin = Color(red: 0.75, green: 0.49, blue: 0.34)
            func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
            func line(_ a: CGPoint, _ b: CGPoint, _ width: CGFloat, _ color: Color) {
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            func end(_ p: CGPoint, _ joint: Int, _ length: Double) -> CGPoint {
                let a = poses[index][joint]
                let b = poses[(index + 1) % poses.count][joint]
                let delta = (b - a + 540).truncatingRemainder(dividingBy: 360) - 180
                let angle = (a + delta * blend) * .pi / 180
                return point(p.x + length * cos(angle), p.y + length * sin(angle))
            }

            let chest = point(sway, -27 + bounce - 7 * accent)
            let hip = point(sway / 2, 11 + bounce)
            for side in [-1.0, 1.0] {
                let knee = point(side * 29 + sway, 42 + bounce / 2)
                let heel = point(side * 25, 73)
                line(hip, knee, 19, ink)
                line(knee, heel, 16, ink)
                line(heel, point(heel.x + side * 11, 74), 9, .white)
            }
            line(hip, chest, 36, shirt)
            for side in [-1.0, 1.0] {
                let shoulder = point(chest.x + side * (14 + accent * 3), chest.y)
                let joint = side < 0 ? 0 : 2
                let elbow = end(shoulder, joint, 28)
                let wrist = end(elbow, joint + 1, 24)
                line(shoulder, elbow, 13, shirt)
                line(elbow, wrist, 8, skin)
            }
            let head = point(chest.x + 2, chest.y - 23)
            context.fill(Path(ellipseIn: CGRect(x: head.x - 12, y: head.y - 13,
                                                width: 24, height: 27)), with: .color(skin))
            line(point(head.x - 7, head.y - 10), point(head.x + 6, head.y - 10), 14, ink)
            line(point(head.x - 11, head.y - 7), point(head.x + 17, head.y - 7), 5, ink)
        }
        .allowsHitTesting(false)
    }
}

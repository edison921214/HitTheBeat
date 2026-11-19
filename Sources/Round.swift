import Foundation

enum Hit: Equatable {
    case perfect, good, early, late, missed

    var label: String {
        switch self {
        case .perfect: return "Perfect！"
        case .good: return "Good！"
        case .early: return "太早了"
        case .late: return "太晚了"
        case .missed: return "漏拍"
        }
    }
}

struct Round {
    static let beat = 0.75  // 80 BPM
    static let first = 3.0 // 四拍預備
    var hits = [Hit?](repeating: nil, count: 8)

    var perfects: Int { hits.filter { $0 == .perfect }.count }
    var goods: Int { hits.filter { $0 == .good }.count }
    var score: Int { perfects * 2 + goods }

    static func index(at time: Double) -> Int {
        Int(floor((time - first) / beat + 0.5))
    }

    mutating func tap(at time: Double) {
        let index = Self.index(at: time)
        guard hits.indices.contains(index), hits[index] == nil else { return }
        let offset = time - (Self.first + Double(index) * Self.beat)
        let errorMS = Int((abs(offset) * 1000).rounded())
        if errorMS <= 100 {
            hits[index] = .perfect
        } else if errorMS <= 250 {
            hits[index] = .good
        } else {
            hits[index] = offset < 0 ? .early : .late
        }
    }

    mutating func closePrevious(at time: Double) {
        let end = min(8, max(0, Self.index(at: time)))
        for index in 0..<end where hits[index] == nil { hits[index] = .missed }
    }
}

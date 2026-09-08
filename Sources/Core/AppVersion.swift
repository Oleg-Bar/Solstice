import Foundation

public enum AppVersion {
    public static func isNewer(_ candidate: String,than current: String) -> Bool {
        let lhs = components(candidate), rhs = components(current)
        for index in 0..<max(lhs.count,rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func components(_ value: String) -> [Int] {
        value.split { !$0.isNumber }.compactMap { Int($0) }
    }
}

import Foundation

/// Line-based diff engine: Myers O(ND) shortest-edit script, unified/hunk
/// rendering, word-level intra-line diff, binary detection, stats.
public enum DiffEngine {

    public struct Line: Hashable, Sendable {
        public var text: String
        /// True for the artificial trailing empty line handling; we keep
        /// "\n" attached semantics simple: lines do NOT include the newline.
    }

    public enum Edit: Sendable {
        case equal(Int, Int)      // a-index, b-index
        case delete(Int)          // a-index
        case insert(Int)          // b-index
    }

    /// Splits data into lines (without terminators). A trailing newline does
    /// not produce an extra empty element.
    public static func splitLines(_ data: Data) -> [String] {
        let text = String(decoding: data, as: UTF8.self)
        if text.isEmpty { return [] }
        var lines = text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        return lines
    }

    public static func isBinary(_ data: Data) -> Bool {
        // NUL byte in first 8000 bytes → binary (same heuristic class as git).
        let sample = data.prefix(8000)
        return sample.contains(0)
    }

    // MARK: - Myers diff

    /// Computes the edit script between two line arrays using the Myers
    /// O(ND) algorithm with linear space refinement (simple recursive version
    /// is avoided; we use the standard V-array trace approach).
    public static func diff(_ a: [String], _ b: [String]) -> [Edit] {
        let n = a.count, m = b.count
        if n == 0 { return b.indices.map { .insert($0) } }
        if m == 0 { return a.indices.map { .delete($0) } }

        // Strip common prefix/suffix to reduce problem size.
        var start = 0
        while start < n && start < m && a[start] == b[start] { start += 1 }
        var endA = n, endB = m
        while endA > start && endB > start && a[endA - 1] == b[endB - 1] {
            endA -= 1; endB -= 1
        }
        let midA = Array(a[start..<endA])
        let midB = Array(b[start..<endB])

        var edits: [Edit] = []
        for i in 0..<start { edits.append(.equal(i, i)) }
        edits.append(contentsOf: myersCore(midA, midB, offsetA: start, offsetB: start))
        for i in 0..<(n - endA) {
            edits.append(.equal(endA + i, endB + i))
        }
        return edits
    }

    /// Myers O(ND) shortest-edit script with linear-space trace backtracking.
    /// V maps k-line → furthest x reached; trace[d] is the V after d edits.
    private static func myersCore(_ a: [String], _ b: [String],
                                  offsetA: Int, offsetB: Int) -> [Edit] {
        let n = a.count, m = b.count
        let max = n + m
        var v: [Int: Int] = [1: 0]
        var trace: [[Int: Int]] = []
        var foundD = -1

        for d in 0...max {
            var current: [Int: Int] = [:]
            var k = -d
            while k <= d {
                let x: Int
                if k == -d || (k != d && (v[k - 1] ?? Int.min) < (v[k + 1] ?? Int.min)) {
                    x = v[k + 1] ?? 0
                } else {
                    x = (v[k - 1] ?? 0) + 1
                }
                var y = x - k
                var fx = x, fy = y
                while fx < n && fy < m && a[fx] == b[fy] { fx += 1; fy += 1 }
                current[k] = fx
                if fx >= n && fy >= m {
                    foundD = d
                    break
                }
                k += 2
            }
            trace.append(current)
            v = current
            if foundD >= 0 { break }
        }
        guard foundD >= 0 else {
            return a.indices.map { .delete(offsetA + $0) } + b.indices.map { .insert(offsetB + $0) }
        }

        // Backtrack through the trace.
        var edits: [Edit] = []
        var x = n, y = m
        if trace.count > foundD { /* trace has foundD+1 entries */ }
        for d in stride(from: foundD, through: 1, by: -1) {
            let vPrev = trace[d - 1]
            let k = x - y
            let prevK: Int
            if k == -d || (k != d && (vPrev[k - 1] ?? Int.min) < (vPrev[k + 1] ?? Int.min)) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }
            let prevX = vPrev[prevK] ?? 0
            let prevY = prevX - prevK
            // Snake backwards (equal lines).
            while x > prevX && y > prevY {
                x -= 1; y -= 1
                edits.append(.equal(offsetA + x, offsetB + y))
            }
            if x == prevX {
                // Down move: insertion from b.
                edits.append(.insert(offsetB + (y - 1)))
                y -= 1
            } else {
                // Right move: deletion from a.
                edits.append(.delete(offsetA + (x - 1)))
                x -= 1
            }
        }
        // d = 0 snake.
        while x > 0 && y > 0 {
            x -= 1; y -= 1
            edits.append(.equal(offsetA + x, offsetB + y))
        }
        edits.reverse()
        return edits
    }

    // MARK: - Hunks

    public struct Hunk: Sendable {
        public var aStart: Int   // 1-based line number of first a-line in hunk
        public var aCount: Int
        public var bStart: Int   // 1-based line number of first b-line in hunk
        public var bCount: Int
        public var lines: [HunkLine]
    }

    public enum HunkLine: Sendable {
        case context(String)
        case addition(String)
        case deletion(String)
    }

    /// One rendered operation in diff order.
    private enum DiffOp {
        case equal(a: Int, b: Int)
        case delete(a: Int)
        case insert(b: Int)
    }

    /// Groups edits into hunks with `context` lines of surrounding context.
    public static func hunks(edits: [Edit], a: [String], b: [String],
                             context: Int = 3) -> [Hunk] {
        // Materialize ops with absolute indices.
        var ops: [DiffOp] = edits.map { e in
            switch e {
            case .equal(let x, let y): return .equal(a: x, b: y)
            case .delete(let x): return .delete(a: x)
            case .insert(let y): return .insert(b: y)
            }
        }
        // Indices of ops that are changes (not equal).
        let changeIdx = ops.indices.filter {
            if case .equal = ops[$0] { return false }
            return true
        }
        guard !changeIdx.isEmpty else { return [] }

        // Group change indices: new hunk when the equal-run between two
        // changes exceeds 2*context.
        var groups: [[Int]] = [[changeIdx[0]]]
        for idx in changeIdx.dropFirst() {
            let prev = groups[groups.count - 1].last!
            if idx - prev - 1 > context * 2 {
                groups.append([idx])
            } else {
                groups[groups.count - 1].append(idx)
            }
        }

        return groups.map { group in buildHunk(ops: ops, group: group,
                                               a: a, b: b, context: context) }
    }

    private static func buildHunk(ops: [DiffOp], group: [Int],
                                  a: [String], b: [String],
                                  context: Int) -> Hunk {
        let firstChange = group.first!, lastChange = group.last!
        // Expand window by `context` equal ops on each side.
        var lo = firstChange
        var eqBefore = 0
        var i = firstChange - 1
        while i >= 0, eqBefore < context {
            if case .equal = ops[i] { eqBefore += 1; lo = i } else { break }
            i -= 1
        }
        var end = lastChange
        var eqAfter = 0
        i = lastChange + 1
        while i < ops.count, eqAfter < context {
            if case .equal = ops[i] { eqAfter += 1; end = i } else { break }
            i += 1
        }

        var lines: [HunkLine] = []
        var aCount = 0, bCount = 0
        var aStart = -1, bStart = -1
        for idx in lo...end {
            switch ops[idx] {
            case .equal(let x, let y):
                if aStart < 0 { aStart = x + 1; bStart = y + 1 }
                lines.append(.context(a[x])); aCount += 1; bCount += 1
            case .delete(let x):
                if aStart < 0 { aStart = x + 1; bStart = nextB(ops: ops, before: idx, b: b) }
                lines.append(.deletion(a[x])); aCount += 1
            case .insert(let y):
                if aStart < 0 { aStart = nextA(ops: ops, before: idx, a: a); bStart = y + 1 }
                lines.append(.addition(b[y])); bCount += 1
            }
        }
        return Hunk(aStart: max(1, aStart), aCount: aCount,
                    bStart: max(1, bStart), bCount: bCount, lines: lines)
    }

    /// For a hunk whose first op is an insertion at op-index `idx`, find the
    /// 1-based a-line number it sits before.
    private static func nextA(ops: [DiffOp], before idx: Int, a: [String]) -> Int {
        // Walk back to last equal/delete to get a-coordinate.
        var i = idx - 1
        while i >= 0 {
            switch ops[i] {
            case .equal(let x, _): return x + 2 // line after x
            case .delete(let x): return x + 2
            case .insert: i -= 1
            }
        }
        return 1
    }

    private static func nextB(ops: [DiffOp], before idx: Int, b: [String]) -> Int {
        var i = idx - 1
        while i >= 0 {
            switch ops[i] {
            case .equal(_, let y): return y + 2
            case .insert(let y): return y + 2
            case .delete: i -= 1
            }
        }
        return 1
    }

    // MARK: - Patch rendering

    /// Renders hunks as a unified diff body (without file headers).
    public static func unifiedPatch(hunks: [Hunk], aPath: String, bPath: String) -> String {
        var out = "--- a/\(aPath)\n+++ b/\(bPath)\n"
        for h in hunks {
            out += "@@ -\(h.aStart),\(h.aCount) +\(h.bStart),\(h.bCount) @@\n"
            for line in h.lines {
                switch line {
                case .context(let t): out += " \(t)\n"
                case .addition(let t): out += "+\(t)\n"
                case .deletion(let t): out += "-\(t)\n"
                }
            }
        }
        return out
    }

    /// Diff statistics: added/removed line counts.
    public static func stats(hunks: [Hunk]) -> (added: Int, removed: Int) {
        var added = 0, removed = 0
        for h in hunks {
            for l in h.lines {
                switch l {
                case .addition: added += 1
                case .deletion: removed += 1
                case .context: break
                }
            }
        }
        return (added, removed)
    }

    /// Word-level diff within a changed line pair (simple token diff).
    public static func wordDiff(_ a: String, _ b: String) -> [(String, Bool)] {
        let aw = a.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let bw = b.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        // LCS on words.
        let n = aw.count, m = bw.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                dp[i][j] = aw[i] == bw[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        var result: [(String, Bool)] = []
        var i = 0, j = 0
        while i < n && j < m {
            if aw[i] == bw[j] { result.append((aw[i], false)); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { result.append((aw[i], true)); i += 1 }
            else { result.append((bw[j], true)); j += 1 }
        }
        while i < n { result.append((aw[i], true)); i += 1 }
        while j < m { result.append((bw[j], true)); j += 1 }
        return result
    }
}

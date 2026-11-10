import Foundation

/// A node in an exported graph (function or basic block).
public struct GraphNode: Codable, Sendable, Hashable {
    public var id: String
    public var label: String
    /// Layer assigned by the layered layout (0 = sources).
    public var layer: Int
    /// Deterministic x position computed by the layout.
    public var x: Double
    /// Deterministic y position computed by the layout.
    public var y: Double

    public init(id: String, label: String, layer: Int = 0, x: Double = 0, y: Double = 0) {
        self.id = id; self.label = label; self.layer = layer; self.x = x; self.y = y
    }
}

/// A directed edge between two graph nodes.
public struct GraphEdge: Codable, Sendable, Hashable {
    public var from: String
    public var to: String

    public init(from: String, to: String) {
        self.from = from; self.to = to
    }
}

/// A positioned graph ready for JSON or SVG export.
public struct Graph: Codable, Sendable {
    public var title: String
    public var nodes: [GraphNode]
    public var edges: [GraphEdge]

    public init(title: String, nodes: [GraphNode], edges: [GraphEdge]) {
        self.title = title; self.nodes = nodes; self.edges = edges
    }
}

/// Builds call/basic-block graphs from analysis models and exports them
/// as JSON or a simple SVG rendering with a deterministic layered layout.
/// No external dependencies.
public enum GraphExporter {
    // MARK: - Graph construction

    /// Call graph over functions: edge caller → callee for every recorded
    /// callee address that resolves to a known function.
    public static func callGraph(functions: [DecompilerFunction]) -> Graph {
        let byAddress = Dictionary(uniqueKeysWithValues: functions.map { ($0.address.value, $0) })
        var edges: [GraphEdge] = []
        var seen = Set<String>()
        for fn in functions {
            for callee in fn.callees {
                guard let target = byAddress[callee.value] else { continue }
                let key = "\(fn.id)->\(target.id)"
                if seen.insert(key).inserted {
                    edges.append(GraphEdge(from: fn.id, to: target.id))
                }
            }
        }
        let nodes = functions.map {
            GraphNode(id: $0.id, label: $0.displayName)
        }
        return Graph(title: "Call graph", nodes: nodes, edges: edges)
    }

    /// Basic-block graph for one function. Node ids are prefixed with the
    /// function address so graphs from multiple functions can be merged
    /// without collisions.
    public static func basicBlockGraph(functionAddress: DecompilerAddress,
                                       blocks: [BasicBlock]) -> Graph {
        let prefix = functionAddress.hexString
        var nodes: [GraphNode] = []
        var edges: [GraphEdge] = []
        var seen = Set<String>()
        for block in blocks.sorted(by: { $0.startAddress.value < $1.startAddress.value }) {
            let nodeID = "\(prefix)/\(block.id)"
            nodes.append(GraphNode(id: nodeID,
                                   label: "\(block.startAddress.hexString)"))
            for succ in block.successors {
                let key = "\(nodeID)->\(prefix)/bb-\(succ.hexString)"
                if seen.insert(key).inserted {
                    edges.append(GraphEdge(from: nodeID, to: "\(prefix)/bb-\(succ.hexString)"))
                }
            }
        }
        return Graph(title: "Basic blocks \(functionAddress.hexString)",
                     nodes: nodes, edges: edges)
    }

    /// Merge several per-function basic-block graphs into one.
    public static func merge(_ graphs: [Graph], title: String = "Basic-block graphs") -> Graph {
        var nodes: [GraphNode] = []
        var edges: [GraphEdge] = []
        for g in graphs {
            nodes.append(contentsOf: g.nodes)
            edges.append(contentsOf: g.edges)
        }
        return Graph(title: title, nodes: nodes, edges: edges)
    }

    // MARK: - Layout

    /// Assign deterministic (x, y) positions using a longest-path layering:
    /// each node's layer is 1 + max(layer of predecessors), iterated to a
    /// fixed point so cycles still terminate. Nodes within a layer are
    /// spaced evenly in id order.
    public static func layout(_ graph: Graph) -> [GraphNode] {
        let nodeIDs = Set(graph.nodes.map(\.id))

        var layer: [String: Int] = [:]
        for id in nodeIDs { layer[id] = 0 }
        // Longest-path relaxation; bounded by node count so cycles end.
        for _ in 0..<max(nodeIDs.count, 1) {
            var changed = false
            for edge in graph.edges where nodeIDs.contains(edge.from) && nodeIDs.contains(edge.to) {
                let candidate = (layer[edge.from] ?? 0) + 1
                if candidate > (layer[edge.to] ?? 0) {
                    layer[edge.to] = candidate
                    changed = true
                }
            }
            if !changed { break }
        }

        let maxLayer = layer.values.max() ?? 0
        var perLayer: [Int: [String]] = [:]
        for (id, l) in layer { perLayer[l, default: []].append(id) }
        for key in perLayer.keys { perLayer[key]?.sort() }

        let horizontalSpacing: Double = 180
        let verticalSpacing: Double = 110
        var positioned: [GraphNode] = []
        for (l, ids) in perLayer.sorted(by: { $0.key < $1.key }) {
            let offset = Double(ids.count - 1) * horizontalSpacing / 2
            for (i, id) in ids.enumerated() {
                guard let node = graph.nodes.first(where: { $0.id == id }) else { continue }
                var copy = node
                copy.layer = l
                copy.x = Double(i) * horizontalSpacing - offset
                copy.y = Double(maxLayer - l) * verticalSpacing // sources on top
                positioned.append(copy)
            }
        }
        // Deterministic final order.
        positioned.sort {
            if $0.layer != $1.layer { return $0.layer < $1.layer }
            if $0.y != $1.y { return $0.y < $1.y }
            if $0.x != $1.x { return $0.x < $1.x }
            return $0.id < $1.id
        }
        return positioned
    }

    // MARK: - Export

    /// JSON document: `{ "title", "nodes": [...], "edges": [...] }`
    /// with layout coordinates included.
    public static func exportJSON(_ graph: Graph) throws -> Data {
        let laidOut = Graph(title: graph.title, nodes: layout(graph), edges: graph.edges)
        return try JSONEncoder.decompiler.encode(laidOut)
    }

    /// JSON string variant.
    public static func exportJSONText(_ graph: Graph) throws -> String {
        String(decoding: try exportJSON(graph), as: UTF8.self)
    }

    /// Simple SVG rendering: nodes as rectangles with text labels,
    /// edges as straight lines with an arrow marker. Pure Foundation.
    public static func exportSVG(_ graph: Graph,
                                 nodeWidth: Double = 150,
                                 nodeHeight: Double = 34) -> String {
        let nodes = layout(graph)
        guard !nodes.isEmpty else {
            return "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>\n"
        }
        let maxX = nodes.map(\.x).max() ?? 0
        let maxY = nodes.map(\.y).max() ?? 0
        let margin: Double = 40
        let width = maxX + nodeWidth + margin * 2
        let height = maxY + nodeHeight + margin * 2
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" " +
            "width=\"\(Int(width))\" height=\"\(Int(height))\" " +
            "viewBox=\"0 0 \(width) \(height)\">\n"
        svg += "<defs><marker id=\"arrow\" viewBox=\"0 0 10 10\" " +
            "refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" " +
            "orient=\"auto-start-reverse\"><path d=\"M0,0 L10,5 L0,10 z\" " +
            "fill=\"#666\"/></marker></defs>\n"
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"#fff\"/>\n"
        svg += "<text x=\"\(margin)\" y=\"\(margin - 10)\" font-family=\"monospace\" " +
            "font-size=\"14\">\(escapeXML(graph.title))</text>\n"

        // Edges first so nodes paint on top.
        for edge in graph.edges {
            guard let from = byID[edge.from], let to = byID[edge.to] else { continue }
            let x1 = from.x + margin + nodeWidth / 2
            let y1 = from.y + margin + nodeHeight / 2
            let x2 = to.x + margin + nodeWidth / 2
            let y2 = to.y + margin + nodeHeight / 2
            svg += "<line x1=\"\(x1)\" y1=\"\(y1)\" x2=\"\(x2)\" y2=\"\(y2)\" " +
                "stroke=\"#666\" stroke-width=\"1\" marker-end=\"url(#arrow)\"/>\n"
        }
        for node in nodes {
            let x = node.x + margin
            let y = node.y + margin
            svg += "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(nodeWidth)\" " +
                "height=\"\(nodeHeight)\" rx=\"6\" fill=\"#eef\" stroke=\"#446\"/>\n"
            svg += "<text x=\"\(x + nodeWidth / 2)\" y=\"\(y + nodeHeight / 2 + 4)\" " +
                "text-anchor=\"middle\" font-family=\"monospace\" font-size=\"11\" " +
                "fill=\"#112\">\(escapeXML(node.label))</text>\n"
        }
        svg += "</svg>\n"
        return svg
    }

    private static func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

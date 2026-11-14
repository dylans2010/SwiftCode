import Foundation



public enum ControlFlowAnalyzer {
    
    
    public static func basicBlocks(instructions: [Instruction],
                                   functionStart: DecompilerAddress) -> [BasicBlock] {
        guard !instructions.isEmpty else { return [] }
        let sorted = instructions.sorted { $0.address.value < $1.address.value }
        var leaders = Set<UInt64>([sorted[0].address.value])
        for (i, ins) in sorted.enumerated() {
            if ins.classification == .branch || ins.classification == .call ||
               ins.classification == .returnInstruction {
                if i + 1 < sorted.count { leaders.insert(sorted[i + 1].address.value) }
            }
            if let target = ins.branchTarget { leaders.insert(target.value) }
        }
        let leaderList = leaders.sorted()
        var blocks: [BasicBlock] = []
        for (i, leader) in leaderList.enumerated() {
            let end = i + 1 < leaderList.count ? leaderList[i + 1] : (sorted.last!.address.value + UInt64(max(sorted.last!.size, 1)))
            let members = sorted.filter { $0.address.value >= leader && $0.address.value < end }
            guard !members.isEmpty else { continue }
            let last = members.last!
            var successors: [DecompilerAddress] = []
            var predecessors: [DecompilerAddress] = []
            var isExit = false
            var branchKind: BasicBlock.BranchKind? = nil
            if last.classification == .branch, let t = last.branchTarget {
                successors.append(t)
                
                if i + 1 < leaderList.count, last.mnemonic.lowercased() != "b" {
                    successors.append(DecompilerAddress(virtual: end))
                    branchKind = .conditional
                } else {
                    branchKind = .unconditional
                }
            } else if last.classification == .returnInstruction {
                isExit = true
                branchKind = .return_
            } else if i + 1 < leaderList.count {
                successors.append(DecompilerAddress(virtual: end))
            } else {
                isExit = true
            }
            blocks.append(BasicBlock(
                startAddress: DecompilerAddress(virtual: leader),
                endAddress: DecompilerAddress(virtual: end),
                instructions: members.map(\.address),
                successors: successors,
                predecessors: predecessors,
                isEntry: leader == functionStart.value,
                isExit: isExit,
                branchKind: branchKind))
        }
        
        var byStart = Dictionary(uniqueKeysWithValues: blocks.map { ($0.startAddress.value, $0) })
        for i in blocks.indices {
            for succ in blocks[i].successors {
                if var target = byStart[succ.value] {
                    if !target.predecessors.contains(blocks[i].startAddress) {
                        target.predecessors.append(blocks[i].startAddress)
                        byStart[succ.value] = target
                    }
                }
            }
        }
        return byStart.values.sorted { $0.startAddress.value < $1.startAddress.value }
    }
}

// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import DistributedTracingBridge
import Bytes

@Suite("IDGeneration")
struct IDGenerationTests {
    @Test("traceID is 16 bytes; deterministic counter produces predictable bytes")
    func traceIDDeterministic() {
        var counter: UInt64 = 0
        let next: () -> UInt64 = {
            counter += 1
            return counter
        }
        let id = IDGeneration.newTraceID(next: next)
        #expect(id.count == 16)
        let prefix: [UInt8] = [0x01, 0, 0, 0, 0, 0, 0, 0]
        let suffix: [UInt8] = [0x02, 0, 0, 0, 0, 0, 0, 0]
        #expect(Array(id.storage[0..<8]) == prefix)
        #expect(Array(id.storage[8..<16]) == suffix)
    }

    @Test("spanID is 8 bytes; deterministic counter produces predictable bytes")
    func spanIDDeterministic() {
        var counter: UInt64 = 0xAA
        let next: () -> UInt64 = {
            counter += 1
            return counter
        }
        let id = IDGeneration.newSpanID(next: next)
        #expect(id.count == 8)
        #expect(Array(id.storage) == [0xAB, 0, 0, 0, 0, 0, 0, 0])
    }
}

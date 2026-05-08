// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import DistributedTracingBridge
import Tracing
import Bytes

@Suite("OTLPTraceIDs")
struct OTLPTraceIDsTests {
    @Test("OTLPTraceIDs is Sendable, Equatable")
    func conformances() {
        let a = OTLPTraceIDs(
            traceID: Bytes(repeating: 0xAA, count: 16),
            spanID: Bytes(repeating: 0xBB, count: 8)
        )
        let b = OTLPTraceIDs(
            traceID: Bytes(repeating: 0xAA, count: 16),
            spanID: Bytes(repeating: 0xBB, count: 8)
        )
        #expect(a == b)
        let _: any Sendable = a
    }

    @Test("ServiceContext.otlpTraceIDs round-trips")
    func contextRoundTrip() {
        var ctx = ServiceContext.topLevel
        #expect(ctx.otlpTraceIDs == nil)

        let ids = OTLPTraceIDs(
            traceID: Bytes(repeating: 0x11, count: 16),
            spanID: Bytes(repeating: 0x22, count: 8)
        )
        ctx.otlpTraceIDs = ids
        #expect(ctx.otlpTraceIDs == ids)
    }

    @Test("Setting otlpTraceIDs to nil clears it")
    func clear() {
        var ctx = ServiceContext.topLevel
        ctx.otlpTraceIDs = OTLPTraceIDs(
            traceID: Bytes(repeating: 0x11, count: 16),
            spanID: Bytes(repeating: 0x22, count: 8)
        )
        ctx.otlpTraceIDs = nil
        #expect(ctx.otlpTraceIDs == nil)
    }
}

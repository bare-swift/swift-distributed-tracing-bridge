// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import DistributedTracingBridge
import Tracing
import OTLPExporter
import Bytes
import Synchronization

@Suite("ServiceContext propagation")
struct ServiceContextPropagationTests {
    private func makeTracer() -> OTLPTracer {
        let counter: Mutex<UInt64> = Mutex(0)
        return OTLPTracer(
            resource: OTLP.Resource(),
            scope: OTLP.InstrumentationScope(name: "t"),
            nextRandomUInt64: { counter.withLock { c in c += 1; return c } }
        )
    }

    @Test("root span has its own traceID, no parentSpanID")
    func rootSpan() {
        let tracer = makeTracer()
        let span = tracer.startSpan(
            "root", context: .topLevel, ofKind: .internal,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        let ids = span.context.otlpTraceIDs
        #expect(ids != nil)
        #expect(ids?.traceID.count == 16)
        #expect(ids?.spanID.count == 8)
        span.end(at: TestInstant(nanosecondsSinceEpoch: 2))
        let otlp = tracer.takeBufferedSpans()[0]
        // Parent span ID is empty Bytes (no parent).
        #expect(otlp.parentSpanID.isEmpty)
    }

    @Test("child span inherits traceID from parent context")
    func childInheritsTraceID() {
        let tracer = makeTracer()
        let parent = tracer.startSpan(
            "parent", context: .topLevel, ofKind: .server,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        let parentTraceID = parent.context.otlpTraceIDs!.traceID
        let parentSpanID = parent.context.otlpTraceIDs!.spanID

        let child = tracer.startSpan(
            "child", context: parent.context, ofKind: .internal,
            at: TestInstant(nanosecondsSinceEpoch: 2),
            function: #function, file: #fileID, line: #line
        )
        let childIDs = child.context.otlpTraceIDs!
        #expect(childIDs.traceID == parentTraceID)
        #expect(childIDs.spanID != parentSpanID)

        child.end(at: TestInstant(nanosecondsSinceEpoch: 3))
        parent.end(at: TestInstant(nanosecondsSinceEpoch: 4))

        let buffered = tracer.takeBufferedSpans()
        let childOTLP = buffered.first { $0.name == "child" }!
        #expect(childOTLP.traceID == parentTraceID)
        #expect(childOTLP.parentSpanID == parentSpanID)
    }
}

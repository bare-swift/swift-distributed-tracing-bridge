// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import DistributedTracingBridge
import Tracing
import OTLPExporter
import Bytes
import Synchronization

@Suite("OTLPTracer buffering")
struct BufferingTests {
    private func makeTracer() -> OTLPTracer {
        let counter: Mutex<UInt64> = Mutex(0)
        return OTLPTracer(
            resource: OTLP.Resource(),
            scope: OTLP.InstrumentationScope(name: "test"),
            nextRandomUInt64: { counter.withLock { c in c += 1; return c } }
        )
    }

    @Test("startSpan returns OTLPSpan with the given operationName + kind")
    func startSpan() {
        let tracer = makeTracer()
        let span = tracer.startSpan(
            "op",
            context: .topLevel,
            ofKind: .server,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        #expect(span.operationName == "op")
        #expect(span.kind == .server)
        #expect(span.startTimeUnixNano == 1)
    }

    @Test("ended span ends up in the buffer")
    func endedSpanBuffered() {
        let tracer = makeTracer()
        let span = tracer.startSpan(
            "op",
            context: .topLevel,
            ofKind: .internal,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        span.end(at: TestInstant(nanosecondsSinceEpoch: 2))
        let buffered = tracer.takeBufferedSpans()
        #expect(buffered.count == 1)
        #expect(buffered[0].name == "op")
        #expect(buffered[0].startTimeUnixNano == 1)
        #expect(buffered[0].endTimeUnixNano == 2)
    }

    @Test("takeBufferedSpans drains the buffer")
    func drains() {
        let tracer = makeTracer()
        let s1 = tracer.startSpan(
            "a", context: .topLevel, ofKind: .internal,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        s1.end(at: TestInstant(nanosecondsSinceEpoch: 2))
        let first = tracer.takeBufferedSpans()
        #expect(first.count == 1)
        let second = tracer.takeBufferedSpans()
        #expect(second.isEmpty)
    }

    @Test("flushExport returns Bytes encoding the request")
    func flushExportReturnsBytes() {
        let tracer = makeTracer()
        let span = tracer.startSpan(
            "op",
            context: .topLevel, ofKind: .internal,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        span.end(at: TestInstant(nanosecondsSinceEpoch: 2))
        let payload = tracer.flushExport()
        #expect(!payload.isEmpty)
        // Span name "op" appears at field 5 (LEN, len 2)
        let nameField: [UInt8] = [0x2A, 0x02, 0x6F, 0x70]
        let bs = Array(payload.storage)
        var found = false
        if bs.count >= nameField.count {
            for start in 0...(bs.count - nameField.count) {
                if Array(bs[start..<start+nameField.count]) == nameField {
                    found = true; break
                }
            }
        }
        #expect(found)
        // Buffer is now empty
        #expect(tracer.takeBufferedSpans().isEmpty)
    }

    @Test("flushExport with empty buffer returns empty Bytes")
    func flushEmpty() {
        let tracer = makeTracer()
        let payload = tracer.flushExport()
        #expect(payload.isEmpty)
    }

    @Test("activeSpan returns nil (not implemented in v0.1)")
    func activeSpan() {
        let tracer = makeTracer()
        #expect(tracer.activeSpan(identifiedBy: .topLevel) == nil)
    }
}

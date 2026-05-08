// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import DistributedTracingBridge
import Tracing
import OTLPExporter
import Bytes
import Synchronization

@Suite("Span events and links → OTLP")
struct SpanEventLinkTests {
    private func makeTracer() -> OTLPTracer {
        let counter: Mutex<UInt64> = Mutex(0)
        return OTLPTracer(
            resource: OTLP.Resource(),
            scope: OTLP.InstrumentationScope(name: "t"),
            nextRandomUInt64: { counter.withLock { c in c += 1; return c } }
        )
    }

    @Test("addEvent appears as OTLP.Span.Event")
    func event() {
        let tracer = makeTracer()
        let span = tracer.startSpan(
            "op", context: .topLevel, ofKind: .internal,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        var attrs = SpanAttributes([:])
        attrs.set("checkpoint.id", value: .int64(7))
        span.addEvent(SpanEvent(name: "checkpoint", at: TestInstant(nanosecondsSinceEpoch: 100), attributes: attrs))
        span.end(at: TestInstant(nanosecondsSinceEpoch: 2))

        let otlp = tracer.takeBufferedSpans()[0]
        #expect(otlp.events.count == 1)
        #expect(otlp.events[0].name == "checkpoint")
        #expect(otlp.events[0].timeUnixNano == 100)
        #expect(otlp.events[0].attributes.contains { $0.key == "checkpoint.id" && $0.value == .int(7) })
    }

    @Test("addLink appears as OTLP.Span.Link")
    func link() {
        let tracer = makeTracer()
        var linkedCtx = ServiceContext.topLevel
        linkedCtx.otlpTraceIDs = OTLPTraceIDs(
            traceID: Bytes(repeating: 0xCC, count: 16),
            spanID: Bytes(repeating: 0xDD, count: 8)
        )
        let span = tracer.startSpan(
            "op", context: .topLevel, ofKind: .internal,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        span.addLink(SpanLink(context: linkedCtx, attributes: SpanAttributes([:])))
        span.end(at: TestInstant(nanosecondsSinceEpoch: 2))

        let otlp = tracer.takeBufferedSpans()[0]
        #expect(otlp.links.count == 1)
        #expect(otlp.links[0].traceID == Bytes(repeating: 0xCC, count: 16))
        #expect(otlp.links[0].spanID == Bytes(repeating: 0xDD, count: 8))
    }

    @Test("recordError adds an exception event with semantic-convention attributes")
    func recordError() {
        struct Boom: Error, CustomStringConvertible {
            var description: String { "kaboom" }
        }
        let tracer = makeTracer()
        let span = tracer.startSpan(
            "op", context: .topLevel, ofKind: .internal,
            at: TestInstant(nanosecondsSinceEpoch: 1),
            function: #function, file: #fileID, line: #line
        )
        span.recordError(Boom(), attributes: SpanAttributes([:]),
                         at: TestInstant(nanosecondsSinceEpoch: 50))
        span.end(at: TestInstant(nanosecondsSinceEpoch: 2))

        let otlp = tracer.takeBufferedSpans()[0]
        #expect(otlp.events.count == 1)
        #expect(otlp.events[0].name == "exception")
        #expect(otlp.events[0].timeUnixNano == 50)
        let attrs = otlp.events[0].attributes
        #expect(attrs.contains { $0.key == "exception.type" })
        #expect(attrs.contains { $0.key == "exception.message" && $0.value == .string("kaboom") })
        #expect(attrs.contains { $0.key == "exception.escaped" && $0.value == .bool(false) })
    }
}

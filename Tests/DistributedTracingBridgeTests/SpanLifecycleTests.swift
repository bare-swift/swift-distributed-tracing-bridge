// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import DistributedTracingBridge
import Tracing
import OTLPExporter
import Bytes

@Suite("OTLPSpan core lifecycle")
struct OTLPSpanCoreTests {
    @Test("Span starts with the operationName, kind, traceID, spanID it was given")
    func construction() {
        var ctx = ServiceContext.topLevel
        let traceID = Bytes(repeating: 0x11, count: 16)
        let spanID = Bytes(repeating: 0x22, count: 8)
        ctx.otlpTraceIDs = OTLPTraceIDs(traceID: traceID, spanID: spanID)
        let span = OTLPSpan(
            operationName: "op",
            kind: .server,
            traceID: traceID,
            spanID: spanID,
            parentSpanID: nil,
            startTimeUnixNano: 1,
            context: ctx,
            onEnd: { _ in }
        )
        #expect(span.operationName == "op")
        #expect(span.context.otlpTraceIDs?.traceID == traceID)
        #expect(span.isRecording)
    }

    @Test("operationName setter mutates")
    func mutateName() {
        let span = makeSpan()
        span.operationName = "new"
        #expect(span.operationName == "new")
    }

    @Test("attributes setter mutates")
    func mutateAttributes() {
        let span = makeSpan()
        var attrs = SpanAttributes([:])
        attrs.set("k", value: .string("v"))
        span.attributes = attrs
        #expect(span.attributes.get("k") == .string("v"))
    }

    @Test("setStatus stores status")
    func setStatus() {
        let span = makeSpan()
        span.setStatus(SpanStatus(code: .ok))
        #expect(span.snapshotStatus()?.code == .ok)
    }

    @Test("addEvent appends events")
    func addEvent() {
        let span = makeSpan()
        let e = SpanEvent(name: "checkpoint", at: TestInstant(nanosecondsSinceEpoch: 100), attributes: SpanAttributes([:]))
        span.addEvent(e)
        #expect(span.snapshotEvents().count == 1)
        #expect(span.snapshotEvents()[0].name == "checkpoint")
    }

    @Test("addLink appends links")
    func addLink() {
        let span = makeSpan()
        var ctx = ServiceContext.topLevel
        ctx.otlpTraceIDs = OTLPTraceIDs(
            traceID: Bytes(repeating: 0xAA, count: 16),
            spanID: Bytes(repeating: 0xBB, count: 8)
        )
        let link = SpanLink(context: ctx, attributes: SpanAttributes([:]))
        span.addLink(link)
        #expect(span.snapshotLinks().count == 1)
    }

    @Test("end marks span as not recording")
    func endStopsRecording() {
        let span = makeSpan()
        span.end(at: TestInstant(nanosecondsSinceEpoch: 1000))
        #expect(!span.isRecording)
    }

    @Test("operations after end are no-ops")
    func mutateAfterEnd() {
        let span = makeSpan()
        span.end(at: TestInstant(nanosecondsSinceEpoch: 1000))
        span.operationName = "should-not-stick"
        #expect(span.operationName != "should-not-stick")
    }

    @Test("recordError adds an exception event with semantic attributes")
    func recordError() {
        struct DBError: Error, CustomStringConvertible {
            var description: String { "connection refused" }
        }
        let span = makeSpan()
        span.recordError(DBError(), attributes: SpanAttributes([:]),
                         at: TestInstant(nanosecondsSinceEpoch: 500))
        let events = span.snapshotEvents()
        #expect(events.count == 1)
        #expect(events[0].name == "exception")
        let typeAttr = events[0].attributes.get("exception.type")
        let msgAttr = events[0].attributes.get("exception.message")
        #expect(typeAttr != nil)
        if case .string(let msg) = msgAttr {
            #expect(msg == "connection refused")
        } else {
            Issue.record("expected string for exception.message")
        }
    }

    private func makeSpan() -> OTLPSpan {
        OTLPSpan(
            operationName: "op",
            kind: .internal,
            traceID: Bytes(repeating: 0x11, count: 16),
            spanID: Bytes(repeating: 0x22, count: 8),
            parentSpanID: nil,
            startTimeUnixNano: 1,
            context: .topLevel,
            onEnd: { _ in }
        )
    }
}

/// Test-only TracerInstant. TracerInstant requires Comparable + Hashable + Sendable.
struct TestInstant: TracerInstant, Comparable, Hashable {
    let nanosecondsSinceEpoch: UInt64
    static func < (lhs: TestInstant, rhs: TestInstant) -> Bool {
        lhs.nanosecondsSinceEpoch < rhs.nanosecondsSinceEpoch
    }
}

// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Instrumentation
import OTLPExporter
import ServiceContextModule
import Testing
import Tracing
@testable import DistributedTracingBridge

/// `Extractor` over a `[String: String]` dict, for testing.
private struct DictExtractor: Extractor {
    let dict: [String: String]
    func extract(key: String, from carrier: [String: String]) -> String? {
        carrier[key]
    }
}

/// `Injector` over an inout `[String: String]` dict, for testing.
private struct DictInjector: Injector {
    func inject(_ value: String, forKey key: String, into carrier: inout [String: String]) {
        carrier[key] = value
    }
}

@Suite("W3C TraceContext extract/inject")
struct W3CTraceContextTests {
    private static let canonicalTraceparent =
        "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    private static let canonicalTraceID = Bytes([
        0x4b, 0xf9, 0x2f, 0x35, 0x77, 0xb3, 0x4d, 0xa6,
        0xa3, 0xce, 0x92, 0x9d, 0x0e, 0x0e, 0x47, 0x36
    ])
    private static let canonicalSpanID = Bytes([
        0x00, 0xf0, 0x67, 0xaa, 0x0b, 0xa9, 0x02, 0xb7
    ])

    private static func makeTracer() -> OTLPTracer {
        OTLPTracer(
            resource: OTLP.Resource(),
            scope: OTLP.InstrumentationScope(name: "test")
        )
    }

    @Test("extract with canonical W3C traceparent populates otlpTraceIDs")
    func extractCanonical() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        let carrier: [String: String] = ["traceparent": Self.canonicalTraceparent]
        tracer.extract(carrier, into: &context, using: DictExtractor(dict: carrier))
        #expect(context.otlpTraceIDs?.traceID == Self.canonicalTraceID)
        #expect(context.otlpTraceIDs?.spanID == Self.canonicalSpanID)
    }

    @Test("extract with no traceparent header leaves context unchanged")
    func extractMissingHeader() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        let carrier: [String: String] = [:]
        tracer.extract(carrier, into: &context, using: DictExtractor(dict: carrier))
        #expect(context.otlpTraceIDs == nil)
    }

    @Test("extract with wrong-length traceparent is rejected")
    func extractWrongLength() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        let carrier = ["traceparent": "00-abc-def-01"]
        tracer.extract(carrier, into: &context, using: DictExtractor(dict: carrier))
        #expect(context.otlpTraceIDs == nil)
    }

    @Test("extract with uppercase hex is rejected (W3C strict)")
    func extractUppercase() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        let upper = "00-4BF92F3577B34DA6A3CE929D0E0E4736-00f067aa0ba902b7-01"
        let carrier = ["traceparent": upper]
        tracer.extract(carrier, into: &context, using: DictExtractor(dict: carrier))
        #expect(context.otlpTraceIDs == nil)
    }

    @Test("extract with all-zero traceID is rejected")
    func extractZeroTraceID() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        let zero = "00-00000000000000000000000000000000-00f067aa0ba902b7-01"
        let carrier = ["traceparent": zero]
        tracer.extract(carrier, into: &context, using: DictExtractor(dict: carrier))
        #expect(context.otlpTraceIDs == nil)
    }

    @Test("extract with non-00 version is rejected")
    func extractWrongVersion() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        let v01 = "01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
        let carrier = ["traceparent": v01]
        tracer.extract(carrier, into: &context, using: DictExtractor(dict: carrier))
        #expect(context.otlpTraceIDs == nil)
    }

    @Test("inject with no active otlpTraceIDs writes nothing")
    func injectNoContext() {
        let tracer = Self.makeTracer()
        let context = ServiceContext.topLevel
        var carrier: [String: String] = [:]
        tracer.inject(context, into: &carrier, using: DictInjector())
        #expect(carrier["traceparent"] == nil)
    }

    @Test("inject with valid otlpTraceIDs writes well-formed traceparent")
    func injectValid() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        context.otlpTraceIDs = OTLPTraceIDs(
            traceID: Self.canonicalTraceID,
            spanID: Self.canonicalSpanID
        )
        var carrier: [String: String] = [:]
        tracer.inject(context, into: &carrier, using: DictInjector())
        let header = carrier["traceparent"]
        #expect(header != nil)
        #expect(header?.count == 55)
        let parts = header?.split(separator: "-").map(String.init)
        #expect(parts?.count == 4)
        #expect(parts?[0] == "00")
        #expect(parts?[1].count == 32)
        #expect(parts?[2].count == 16)
        #expect(parts?[3].count == 2)
    }

    @Test("inject + extract round-trips IDs through the carrier")
    func roundTrip() {
        let tracer = Self.makeTracer()
        var outbound = ServiceContext.topLevel
        outbound.otlpTraceIDs = OTLPTraceIDs(
            traceID: Self.canonicalTraceID,
            spanID: Self.canonicalSpanID
        )
        var carrier: [String: String] = [:]
        tracer.inject(outbound, into: &carrier, using: DictInjector())

        var inbound = ServiceContext.topLevel
        tracer.extract(carrier, into: &inbound, using: DictExtractor(dict: carrier))
        #expect(inbound.otlpTraceIDs?.traceID == Self.canonicalTraceID)
        #expect(inbound.otlpTraceIDs?.spanID == Self.canonicalSpanID)
    }

    @Test("extract → startSpan propagates parent traceID to child")
    func chainExtractStartSpan() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        let carrier = ["traceparent": Self.canonicalTraceparent]
        tracer.extract(carrier, into: &context, using: DictExtractor(dict: carrier))
        let span = tracer.startSpan(
            "child",
            context: context,
            ofKind: .internal,
            at: DefaultTracerClock.now,
            function: #function,
            file: #fileID,
            line: #line
        )
        defer { span.end(at: DefaultTracerClock.now) }
        #expect(span.context.otlpTraceIDs?.traceID == Self.canonicalTraceID)
    }

    @Test("inject after extract round-trips the entire traceparent")
    func roundTripFullHeader() {
        let tracer = Self.makeTracer()
        var context = ServiceContext.topLevel
        let inbound = ["traceparent": Self.canonicalTraceparent]
        tracer.extract(inbound, into: &context, using: DictExtractor(dict: inbound))
        var outbound: [String: String] = [:]
        tracer.inject(context, into: &outbound, using: DictInjector())
        #expect(outbound["traceparent"] == Self.canonicalTraceparent)
    }
}

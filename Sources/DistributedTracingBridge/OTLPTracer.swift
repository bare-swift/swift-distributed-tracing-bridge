// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Instrumentation
import OTLPExporter
import ServiceContextModule
import Synchronization
import Tracing
import TracingOTLP

/// Apple swift-distributed-tracing `Tracer` implementation that routes
/// to swift-tracing-otlp's encoder. Buffers ended spans in memory; the
/// caller drains via ``flushExport()`` (returns OTLP-encoded `Bytes`)
/// or ``takeBufferedSpans()`` (returns `[OTLP.Span]` for custom transport).
///
/// Bootstrap once at startup:
///
/// ```swift
/// let tracer = OTLPTracer(resource: ..., scope: ...)
/// InstrumentationSystem.bootstrap(tracer)
/// ```
public final class OTLPTracer: Tracer, @unchecked Sendable {
    public typealias Span = OTLPSpan

    let resource: OTLP.Resource
    let scope: OTLP.InstrumentationScope
    private let nextRandomUInt64: @Sendable () -> UInt64

    private let buffer: Mutex<[OTLP.Span]>

    public init(
        resource: OTLP.Resource = OTLP.Resource(),
        scope: OTLP.InstrumentationScope = OTLP.InstrumentationScope(),
        nextRandomUInt64: @escaping @Sendable () -> UInt64 = {
            var rng = SystemRandomNumberGenerator()
            return rng.next()
        }
    ) {
        self.resource = resource
        self.scope = scope
        self.nextRandomUInt64 = nextRandomUInt64
        self.buffer = Mutex([])
    }

    // MARK: - Tracer

    public func startSpan<Instant: TracerInstant>(
        _ operationName: String,
        context: @autoclosure () -> ServiceContext,
        ofKind kind: SpanKind,
        at instant: @autoclosure () -> Instant,
        function: String,
        file fileID: String,
        line: UInt
    ) -> OTLPSpan {
        let parentContext = context()
        let parentIDs = parentContext.otlpTraceIDs

        let traceID: Bytes = parentIDs?.traceID ?? IDGeneration.newTraceID(next: nextRandomUInt64)
        let spanID: Bytes = IDGeneration.newSpanID(next: nextRandomUInt64)
        let parentSpanID: Bytes? = parentIDs?.spanID

        var spanContext = parentContext
        spanContext.otlpTraceIDs = OTLPTraceIDs(traceID: traceID, spanID: spanID)

        let nano = instant().nanosecondsSinceEpoch
        let span = OTLPSpan(
            operationName: operationName,
            kind: kind,
            traceID: traceID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            startTimeUnixNano: nano,
            context: spanContext,
            onEnd: { [self] otlpSpan in
                self.buffer.withLock { $0.append(otlpSpan) }
            }
        )
        return span
    }

    public func activeSpan(identifiedBy context: ServiceContext) -> OTLPSpan? {
        // v0.1: not tracking active spans. Returning nil is permitted by
        // the protocol — the default extension implementation also returns nil.
        return nil
    }

    // MARK: - LegacyTracer

    public func forceFlush() {
        // No-op: bare-swift export is caller-driven via flushExport().
    }

    // MARK: - Instrument

    public func extract<Carrier, Extract: Extractor>(
        _ carrier: Carrier,
        into context: inout ServiceContext,
        using extractor: Extract
    ) where Extract.Carrier == Carrier {
        guard let header = extractor.extract(key: "traceparent", from: carrier) else { return }
        guard let traceContext = OTLP.TraceContext.parse(traceparent: header) else { return }
        context.otlpTraceIDs = OTLPTraceIDs(
            traceID: traceContext.traceID,
            spanID: traceContext.spanID
        )
    }

    public func inject<Carrier, Inject: Injector>(
        _ context: ServiceContext,
        into carrier: inout Carrier,
        using injector: Inject
    ) where Inject.Carrier == Carrier {
        guard let ids = context.otlpTraceIDs else { return }
        let tc = OTLP.TraceContext(
            traceID: ids.traceID,
            spanID: ids.spanID,
            traceFlags: 0x01
        )
        guard let header = tc.traceparent else { return }
        injector.inject(header, forKey: "traceparent", into: &carrier)
    }

    // MARK: - Bridge-specific

    /// Drain ended spans without encoding (for testing or custom transport).
    public func takeBufferedSpans() -> [OTLP.Span] {
        buffer.withLock { spans in
            let drained = spans
            spans.removeAll(keepingCapacity: true)
            return drained
        }
    }

    /// Drain buffered ended spans and produce an OTLP-encoded request body
    /// ready as the body of `HTTP POST /v1/traces` with
    /// `Content-Type: application/x-protobuf`.
    public func flushExport() -> Bytes {
        let spans = takeBufferedSpans()
        if spans.isEmpty { return Bytes() }
        let req = OTLP.ExportTraceServiceRequest(resourceSpans: [
            OTLP.ResourceSpans(
                resource: resource,
                scopeSpans: [
                    OTLP.ScopeSpans(scope: scope, spans: spans)
                ]
            )
        ])
        return OTLP.encodeTraces(req)
    }
}

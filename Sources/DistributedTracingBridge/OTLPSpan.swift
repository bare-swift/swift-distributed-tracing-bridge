// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import OTLPExporter
import ServiceContextModule
import Synchronization
import Tracing
import TracingOTLP

/// A `Tracing.Span` implementation that buffers state for OTLP export.
/// Reference semantics (per Span protocol contract); thread-safe mutation
/// via internal `Mutex`. On ``end(at:)`` the span calls back into the
/// owning `OTLPTracer` with its finalized `OTLP.Span` value.
public final class OTLPSpan: Tracing.Span, @unchecked Sendable {
    /// Mutable state held under a `Mutex`.
    fileprivate struct State: Sendable {
        var operationName: String
        var attributes: SpanAttributes = SpanAttributes([:])
        var status: SpanStatus? = nil
        var events: [SpanEvent] = []
        var links: [SpanLink] = []
        var isRecording: Bool = true
        var endTimeUnixNano: UInt64 = 0
    }

    /// Immutable identity.
    public let context: ServiceContext
    let kind: Tracing.SpanKind
    let traceID: Bytes
    let spanID: Bytes
    let parentSpanID: Bytes?
    let startTimeUnixNano: UInt64

    private let stateMutex: Mutex<State>

    /// Called from `end(at:)` with the finalized OTLP.Span. Wired by the tracer.
    private let onEnd: @Sendable (OTLP.Span) -> Void

    public init(
        operationName: String,
        kind: Tracing.SpanKind,
        traceID: Bytes,
        spanID: Bytes,
        parentSpanID: Bytes?,
        startTimeUnixNano: UInt64,
        context: ServiceContext,
        onEnd: @escaping @Sendable (OTLP.Span) -> Void
    ) {
        self.kind = kind
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
        self.startTimeUnixNano = startTimeUnixNano
        self.context = context
        self.stateMutex = Mutex(State(operationName: operationName))
        self.onEnd = onEnd
    }

    // MARK: - Tracing.Span

    public var operationName: String {
        get { stateMutex.withLock { $0.operationName } }
        set {
            stateMutex.withLock { state in
                if state.isRecording { state.operationName = newValue }
            }
        }
    }

    public var attributes: SpanAttributes {
        get { stateMutex.withLock { $0.attributes } }
        set {
            stateMutex.withLock { state in
                if state.isRecording { state.attributes = newValue }
            }
        }
    }

    public var isRecording: Bool {
        stateMutex.withLock { $0.isRecording }
    }

    public func setStatus(_ status: Tracing.SpanStatus) {
        stateMutex.withLock { state in
            if state.isRecording { state.status = status }
        }
    }

    public func addEvent(_ event: Tracing.SpanEvent) {
        stateMutex.withLock { state in
            if state.isRecording { state.events.append(event) }
        }
    }

    public func recordError<Instant: Tracing.TracerInstant>(
        _ error: Error,
        attributes: Tracing.SpanAttributes,
        at instant: @autoclosure () -> Instant
    ) {
        var eventAttrs = attributes
        eventAttrs.set("exception.type", value: .string(String(describing: type(of: error))))
        eventAttrs.set("exception.message", value: .string(String(describing: error)))
        eventAttrs.set("exception.escaped", value: .bool(false))
        let event = Tracing.SpanEvent(
            name: "exception",
            at: instant(),
            attributes: eventAttrs
        )
        addEvent(event)
    }

    public func addLink(_ link: Tracing.SpanLink) {
        stateMutex.withLock { state in
            if state.isRecording { state.links.append(link) }
        }
    }

    public func end<Instant: Tracing.TracerInstant>(at instant: @autoclosure () -> Instant) {
        let endTime = instant().nanosecondsSinceEpoch
        let finalized: OTLP.Span? = stateMutex.withLock { state -> OTLP.Span? in
            guard state.isRecording else { return nil }
            state.isRecording = false
            state.endTimeUnixNano = endTime
            return self.buildOTLPSpan(from: state, endTime: endTime)
        }
        if let finalized {
            onEnd(finalized)
        }
    }

    // MARK: - Test snapshots (internal)

    func snapshotStatus() -> Tracing.SpanStatus? {
        stateMutex.withLock { $0.status }
    }
    func snapshotEvents() -> [Tracing.SpanEvent] {
        stateMutex.withLock { $0.events }
    }
    func snapshotLinks() -> [Tracing.SpanLink] {
        stateMutex.withLock { $0.links }
    }

    // MARK: - OTLP conversion

    private func buildOTLPSpan(from state: State, endTime: UInt64) -> OTLP.Span {
        var s = OTLP.Span(
            traceID: traceID,
            spanID: spanID,
            parentSpanID: parentSpanID ?? Bytes(),
            name: state.operationName,
            kind: Self.toOTLPKind(kind),
            startTimeUnixNano: startTimeUnixNano,
            endTimeUnixNano: endTime
        )
        s.attributes = AttributeMapping.toKeyValues(state.attributes)
        s.events = state.events.map { e in
            OTLP.Span.Event(
                timeUnixNano: e.nanosecondsSinceEpoch,
                name: e.name,
                attributes: AttributeMapping.toKeyValues(e.attributes)
            )
        }
        s.links = state.links.map { link -> OTLP.Span.Link in
            let parentIDs = link.context.otlpTraceIDs
            return OTLP.Span.Link(
                traceID: parentIDs?.traceID ?? Bytes(),
                spanID: parentIDs?.spanID ?? Bytes(),
                attributes: AttributeMapping.toKeyValues(link.attributes)
            )
        }
        if let status = state.status {
            s.status = OTLP.Status(
                message: status.message ?? "",
                code: Self.toOTLPStatusCode(status.code)
            )
        }
        return s
    }

    private static func toOTLPKind(_ k: Tracing.SpanKind) -> OTLP.Span.Kind {
        switch k {
        case .internal: return .internal
        case .server:   return .server
        case .client:   return .client
        case .producer: return .producer
        case .consumer: return .consumer
        }
    }

    private static func toOTLPStatusCode(_ c: Tracing.SpanStatus.Code) -> OTLP.Status.Code {
        switch c {
        case .ok:    return .ok
        case .error: return .error
        }
    }
}

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-05-09

### Added
- `OTLPTracer` — Sendable `Tracer` (and `LegacyTracer`/`Instrument`) implementation that buffers ended spans and emits `Bytes` ready for `HTTP POST /v1/traces` via `flushExport()`.
- `OTLPSpan` — Sendable `Span` implementation with reference semantics (final class + `Mutex<State>`).
- `OTLPTraceIDs` and `OTLPTraceIDsKey` — bare-swift custom `ServiceContext` key for trace correlation in v0.1 (W3C TraceContext / B3 / Jaeger deferred to v0.2).
- All 9 `Tracing.Span` protocol methods: setStatus, addEvent, addLink, recordError (semantic-convention `exception.type/.message/.escaped`), attributes mutation, operationName mutation, end.
- All 11 `SpanAttribute` variants mapped to `OTLP.AnyValue` (incl. forward-compat sentinel).
- `flushExport()` returns OTLP-encoded `Bytes` ready for HTTP POST.
- `takeBufferedSpans()` returns `[OTLP.Span]` for testing or custom transport.
- `DistributedTracingBridgeError` typed-error enum (no cases in v0.1; reserved for v0.2 propagation errors).
- DocC documentation, full README example, NOTICE crediting Apple's swift-distributed-tracing.

### Dependencies
- `swift-tracing-otlp` 0.1.0.
- `swift-otlp-exporter` 0.1.0 (transitive but pinned).
- `swift-bytes` 0.1.0 (transitive).
- `apple/swift-distributed-tracing` 1.0.0+ — **second non-bare-swift dep in the ecosystem**. Has minimal transitive deps (only swift-service-context); preserves RFC-0001.

### Limitations (out of scope for v0.1)
- W3C TraceContext / B3 / Jaeger extract/inject. `Tracer.extract`/`inject` are no-ops in v0.1; use `context.otlpTraceIDs` directly.
- Sampling (head or tail). All spans are recorded.
- Periodic / background flusher. Caller-driven only.
- `activeSpan(identifiedBy:)` returns `nil` in v0.1.
- Cross-tracer span links.
- HTTP transport — caller wires URLSession / async-http-client / NIO.

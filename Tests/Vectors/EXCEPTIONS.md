# Test-parity exceptions

Per [RFC-0002](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0002-test-parity-policy.md) and its 2026-05-07 amendment per [RFC-0004](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0004-inline-test-vectors.md), this file documents how `swift-distributed-tracing-bridge` validates correctness.

## Source: swift-distributed-tracing protocols + OTLP traces.v1 schema

There is no upstream Rust crate to track parity against. The contracts:

1. **swift-distributed-tracing protocols** — Apple, at
   https://github.com/apple/swift-distributed-tracing.
   `Tracer.startSpan` produces a `Span`; `Span.end` finalizes it.
   We verify each method routes to the correct `OTLP.Span` mutation.

2. **OTLP traces wire format** — verified by swift-tracing-otlp; we re-use
   it as a black box. The bridge tests assert via `takeBufferedSpans()`
   (which returns the `OTLP.Span` values directly), so wire-format
   correctness is delegated to swift-tracing-otlp's tests.

Test layout:

- `IDGenerationTests.swift` — random-ID generation with deterministic seed.
- `AttributeMappingTests.swift` — all 11 SpanAttribute variants.
- `OTLPTraceIDsTests.swift` — ServiceContext key get/set + value semantics.
- `SpanLifecycleTests.swift` — start, mutate name/attributes/status, end, verify OTLP.Span.
- `SpanEventLinkTests.swift` — addEvent / addLink / recordError.
- `BufferingTests.swift` — multiple ended spans, flushExport, takeBufferedSpans.
- `ServiceContextPropagationTests.swift` — parent/child traceID + spanID continuity.
- `EndToEndTests.swift` — bootstrap-style flow (without polluting global MetricsSystem; we test factory directly per Phase 2 precedent).

## Out of scope for v0.1

- W3C TraceContext / B3 / Jaeger propagation — Apple's `Extractor`/`Injector` are no-ops in v0.1.
- Sampling.
- Periodic flusher.
- Apple's `forceFlush()` is a no-op (caller-driven via `flushExport()`).
- Cross-tracer span links.

## Refresh

When swift-distributed-tracing changes minor versions, re-read the protocol
shapes and update tests for any affected method.

- swift-distributed-tracing: tracked at this package's pinned major version.

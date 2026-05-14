# swift-distributed-tracing-bridge

Adapter from Apple's [`swift-distributed-tracing`](https://github.com/apple/swift-distributed-tracing) frontend to [`swift-tracing-otlp`](https://github.com/bare-swift/swift-tracing-otlp). Bootstrap once; instrumentation libraries call standard `withSpan` / `startSpan`; `flushExport()` returns `Bytes` ready for `HTTP POST /v1/traces`.

Mirrors [`swift-prometheus-metrics`](https://github.com/bare-swift/swift-prometheus-metrics)' shape: Apple-frontend → bare-swift backend, factory class with caller-driven flush.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem. Phase 3 Tranche 3B.

## Install

```swift
.package(url: "https://github.com/bare-swift/swift-distributed-tracing-bridge.git", from: "0.2.0")
```

```swift
.product(name: "DistributedTracingBridge", package: "swift-distributed-tracing-bridge")
```

## Usage

```swift
import Tracing                          // Apple's swift-distributed-tracing
import OTLPExporter                     // bare-swift OTLP types
import DistributedTracingBridge         // this adapter

let tracer = OTLPTracer(
    resource: OTLP.Resource(attributes: [
        OTLP.KeyValue(key: "service.name", value: .string("api"))
    ]),
    scope: OTLP.InstrumentationScope(name: "myapp", version: "1.0")
)
InstrumentationSystem.bootstrap(tracer)

// Anywhere in your code, the standard swift-distributed-tracing API:
withSpan("GET /api/users", ofKind: .server) { span in
    span.attributes["http.method"] = "GET"
    span.attributes["http.status_code"] = 200
    // ... handle the request ...
}

// Periodically (timer, request cycle, shutdown):
let payload: Bytes = tracer.flushExport()
// HTTP POST /v1/traces, Content-Type: application/x-protobuf, body = payload.storage
```

## Mapping

| swift-distributed-tracing | OTLP equivalent |
|---|---|
| `SpanKind.internal/.server/.client/.producer/.consumer` | `OTLP.Span.Kind.internal/.server/.client/.producer/.consumer` |
| `SpanStatus.Code.ok/.error` | `OTLP.Status.Code.ok/.error` |
| `SpanAttribute.string/.int32/.int64/.double/.bool` and arrays | `OTLP.AnyValue` cases |
| `SpanAttribute.stringConvertible(value)` | `.string(value.description)` |
| `SpanEvent` | `OTLP.Span.Event` |
| `SpanLink` | `OTLP.Span.Link` |
| `Span.recordError(_:)` | event named `"exception"` with semantic-convention attributes |

## Trace context propagation

**In-process (v0.1+):** Custom `ServiceContext` key `OTLPTraceIDsKey` carries trace+span ID. When `startSpan` is called with a context that has these IDs, the new span continues the trace.

**Cross-process (v0.2+):** The bridge implements W3C TraceContext (`traceparent` header) extract + inject via the Apple `Instrument` protocol. HTTP middleware that uses `InstrumentationSystem.instrument.extract` / `.inject` automatically propagates trace context across service boundaries.

```swift
// Inbound (server middleware): extract from HTTP headers into context.
var context = ServiceContext.topLevel
InstrumentationSystem.instrument.extract(headers, into: &context, using: HTTPExtractor())

// Outbound (HTTP client): inject context into outgoing headers.
var headers: [String: String] = [:]
InstrumentationSystem.instrument.inject(context, into: &headers, using: HTTPInjector())
```

Cascading benefit: log records emitted via [`swift-log-bridge`](https://github.com/bare-swift/swift-log-bridge) and metric exemplars emitted via [`swift-metrics-bridge`](https://github.com/bare-swift/swift-metrics-bridge) automatically carry the cross-process trace IDs from the extracted context — no code changes in those packages.

B3 and Jaeger header formats are deferred to v0.3+.

## flush, sampling, transport

- `flushExport()` is **caller-driven**. No background flusher in v0.1.
- **Sampling is not implemented.** Every span is recorded. For high-volume services, defer to v0.2.
- HTTP transport is the caller's job — pair with URLSession / async-http-client / NIO.

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-distributed-tracing-bridge/>

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).

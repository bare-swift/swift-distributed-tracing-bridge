# ``DistributedTracingBridge``

Apple swift-distributed-tracing backend that routes to swift-tracing-otlp.

## Overview

Bootstrap once at startup with an `OTLPTracer`, then use the standard
swift-distributed-tracing API (`withSpan`, `startSpan`) throughout your
code. Periodically call `flushExport()` to obtain `Bytes` ready for
`HTTP POST /v1/traces`.

```swift
import Tracing
import OTLPExporter
import DistributedTracingBridge

let tracer = OTLPTracer(
    resource: OTLP.Resource(...),
    scope: OTLP.InstrumentationScope(...)
)
InstrumentationSystem.bootstrap(tracer)

withSpan("operation") { span in
    // ... work ...
}

let payload = tracer.flushExport()  // Bytes ready for HTTP POST
```

The factory implements `Tracer` from swift-distributed-tracing. Each
trace becomes an `OTLP.Span` (the value type from swift-tracing-otlp);
ended spans are buffered and emitted as a single `ExportTraceServiceRequest`
on flush.

## Topics

### Top-level

- ``OTLPTracer``
- ``OTLPSpan``
- ``OTLPTraceIDs``

### Errors

- ``DistributedTracingBridgeError``

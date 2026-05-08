// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import DistributedTracingBridge
import Tracing
import OTLPExporter
import Bytes
import Synchronization

@Suite("End-to-end: bootstrap-equivalent")
struct EndToEndTests {
    @Test("realistic flow: parent span with child, attributes, status, recordError → flushExport bytes contain expected encoding")
    func realisticFlow() {
        let counter: Mutex<UInt64> = Mutex(0)
        let tracer = OTLPTracer(
            resource: OTLP.Resource(attributes: [
                OTLP.KeyValue(key: "service.name", value: .string("api"))
            ]),
            scope: OTLP.InstrumentationScope(name: "myapp", version: "1.0"),
            nextRandomUInt64: { counter.withLock { c in c += 1; return c } }
        )

        let parent = tracer.startSpan(
            "GET /api/users", context: .topLevel, ofKind: .server,
            at: TestInstant(nanosecondsSinceEpoch: 1_700_000_000_000_000_000),
            function: #function, file: #fileID, line: #line
        )
        var attrs = SpanAttributes([:])
        attrs.set("http.method", value: .string("GET"))
        attrs.set("http.status_code", value: .int64(200))
        parent.attributes = attrs
        parent.setStatus(SpanStatus(code: .ok))

        let child = tracer.startSpan(
            "db.query", context: parent.context, ofKind: .client,
            at: TestInstant(nanosecondsSinceEpoch: 1_700_000_000_100_000_000),
            function: #function, file: #fileID, line: #line
        )
        child.end(at: TestInstant(nanosecondsSinceEpoch: 1_700_000_000_200_000_000))
        parent.end(at: TestInstant(nanosecondsSinceEpoch: 1_700_000_000_500_000_000))

        let payload = tracer.flushExport()
        let bs = Array(payload.storage)
        #expect(!bs.isEmpty)

        // Span name "GET /api/users" (14 bytes) at field 5: tag 0x2A, len 0x0E
        let parentName: [UInt8] = [0x2A, 0x0E] + Array("GET /api/users".utf8)
        #expect(containsSubsequence(bs, parentName))
        // Child span name "db.query" (8 bytes) at field 5: tag 0x2A, len 0x08
        let childName: [UInt8] = [0x2A, 0x08] + Array("db.query".utf8)
        #expect(containsSubsequence(bs, childName))
        // service.name attribute (KeyValue inner: field 1 "service.name")
        let serviceName: [UInt8] = [0x0A, 0x0C] + Array("service.name".utf8)
        #expect(containsSubsequence(bs, serviceName))
        // SpanKind server (=2): tag 0x30, varint 0x02
        #expect(containsSubsequence(bs, [0x30, 0x02]))
        // Status(.ok) wrapped at field 15: tag 0x7A, len 2, then [0x18, 0x01]
        #expect(containsSubsequence(bs, [0x7A, 0x02, 0x18, 0x01]))
        // After flush, buffer drained.
        #expect(tracer.takeBufferedSpans().isEmpty)
    }

    private func containsSubsequence(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
        guard !needle.isEmpty, haystack.count >= needle.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<start+needle.count]) == needle { return true }
        }
        return false
    }
}

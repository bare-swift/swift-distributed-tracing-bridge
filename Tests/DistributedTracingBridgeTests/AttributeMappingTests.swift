// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import DistributedTracingBridge
import Tracing
import OTLPExporter

@Suite("AttributeMapping — SpanAttribute → OTLP.AnyValue")
struct AttributeMappingTests {
    @Test("string → .string")
    func string() {
        let v = AttributeMapping.toAnyValue(.string("hello"))
        #expect(v == .string("hello"))
    }

    @Test("int32 → .int")
    func int32() {
        let v = AttributeMapping.toAnyValue(.int32(42))
        #expect(v == .int(42))
    }

    @Test("int64 → .int")
    func int64() {
        let v = AttributeMapping.toAnyValue(.int64(Int64.max))
        #expect(v == .int(Int64.max))
    }

    @Test("double → .double")
    func double() {
        let v = AttributeMapping.toAnyValue(.double(1.5))
        #expect(v == .double(1.5))
    }

    @Test("bool → .bool")
    func bool() {
        let v = AttributeMapping.toAnyValue(.bool(true))
        #expect(v == .bool(true))
    }

    @Test("stringArray → .array of .string")
    func stringArray() {
        let v = AttributeMapping.toAnyValue(.stringArray(["a", "b"]))
        #expect(v == .array([.string("a"), .string("b")]))
    }

    @Test("int32Array → .array of .int")
    func int32Array() {
        let v = AttributeMapping.toAnyValue(.int32Array([1, 2]))
        #expect(v == .array([.int(1), .int(2)]))
    }

    @Test("int64Array → .array of .int")
    func int64Array() {
        let v = AttributeMapping.toAnyValue(.int64Array([1, 2]))
        #expect(v == .array([.int(1), .int(2)]))
    }

    @Test("doubleArray → .array of .double")
    func doubleArray() {
        let v = AttributeMapping.toAnyValue(.doubleArray([1.5, 2.5]))
        #expect(v == .array([.double(1.5), .double(2.5)]))
    }

    @Test("boolArray → .array of .bool")
    func boolArray() {
        let v = AttributeMapping.toAnyValue(.boolArray([true, false]))
        #expect(v == .array([.bool(true), .bool(false)]))
    }

    @Test("stringConvertible → .string via description")
    func stringConvertible() {
        let v = AttributeMapping.toAnyValue(.stringConvertible(123))
        #expect(v == .string("123"))
    }

    @Test("stringConvertibleArray → .array of .string")
    func stringConvertibleArray() {
        let v = AttributeMapping.toAnyValue(.stringConvertibleArray([1, 2]))
        #expect(v == .array([.string("1"), .string("2")]))
    }

    @Test("SpanAttributes → [OTLP.KeyValue]")
    func attributesToKeyValues() {
        var attrs = SpanAttributes([:])
        attrs.set("http.method", value: .string("GET"))
        attrs.set("http.status_code", value: .int64(200))
        let kvs = AttributeMapping.toKeyValues(attrs)
        #expect(kvs.count == 2)
        let keys = Set(kvs.map { $0.key })
        #expect(keys == ["http.method", "http.status_code"])
        let methodKV = kvs.first { $0.key == "http.method" }
        #expect(methodKV?.value == .string("GET"))
        let codeKV = kvs.first { $0.key == "http.status_code" }
        #expect(codeKV?.value == .int(200))
    }
}

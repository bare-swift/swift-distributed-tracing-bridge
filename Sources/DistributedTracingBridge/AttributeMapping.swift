// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Tracing
import OTLPExporter

/// Internal: convert swift-distributed-tracing's `SpanAttribute` and
/// `SpanAttributes` into OTLP common types. Lossy in exactly one place
/// (`stringConvertible` collapses to its description); documented in NOTICE.
enum AttributeMapping {
    /// Convert one `SpanAttribute` to `OTLP.AnyValue`. The forward-compat
    /// `__DO_NOT_SWITCH_EXHAUSTIVELY...` case is treated as an opaque string.
    static func toAnyValue(_ a: SpanAttribute) -> OTLP.AnyValue {
        switch a {
        case .string(let s):
            return .string(s)
        case .int32(let i):
            return .int(Int64(i))
        case .int64(let i):
            return .int(i)
        case .double(let d):
            return .double(d)
        case .bool(let b):
            return .bool(b)
        case .stringArray(let xs):
            return .array(xs.map { .string($0) })
        case .int32Array(let xs):
            return .array(xs.map { .int(Int64($0)) })
        case .int64Array(let xs):
            return .array(xs.map { .int($0) })
        case .doubleArray(let xs):
            return .array(xs.map { .double($0) })
        case .boolArray(let xs):
            return .array(xs.map { .bool($0) })
        case .stringConvertible(let v):
            return .string(String(describing: v))
        case .stringConvertibleArray(let vs):
            return .array(vs.map { .string(String(describing: $0)) })
        case .__DO_NOT_SWITCH_EXHAUSTIVELY_OVER_THIS_ENUM_USE_DEFAULT_INSTEAD:
            return .string("(unknown)")
        }
    }

    /// Convert `SpanAttributes` to an `[OTLP.KeyValue]` array.
    static func toKeyValues(_ attrs: SpanAttributes) -> [OTLP.KeyValue] {
        var out: [OTLP.KeyValue] = []
        attrs.forEach { (key, value) in
            out.append(OTLP.KeyValue(key: key, value: toAnyValue(value)))
        }
        return out
    }
}

// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes

/// Internal random-ID generation per OpenTelemetry / W3C TraceContext.
/// Trace ID is 16 bytes; Span ID is 8 bytes. The RNG is injected as a closure
/// for testability; production callers pass a closure backed by
/// `SystemRandomNumberGenerator`.
enum IDGeneration {
    static func newTraceID(next: () -> UInt64) -> Bytes {
        var storage = ContiguousArray<UInt8>(repeating: 0, count: 16)
        for chunk in 0..<2 {
            let v: UInt64 = next()
            for j in 0..<8 {
                storage[chunk * 8 + j] = UInt8(truncatingIfNeeded: v >> (j * 8))
            }
        }
        return Bytes(storage)
    }

    static func newSpanID(next: () -> UInt64) -> Bytes {
        var storage = ContiguousArray<UInt8>(repeating: 0, count: 8)
        let v: UInt64 = next()
        for j in 0..<8 {
            storage[j] = UInt8(truncatingIfNeeded: v >> (j * 8))
        }
        return Bytes(storage)
    }
}

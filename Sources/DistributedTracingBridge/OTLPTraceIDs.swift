// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import ServiceContextModule

/// Trace correlation identifiers stored in `ServiceContext` for parent/child
/// span lookup. v0.1 only supports the bare-swift custom encoding; W3C
/// TraceContext / B3 / Jaeger propagation are deferred to v0.2.
public struct OTLPTraceIDs: Sendable, Equatable {
    public let traceID: Bytes
    public let spanID: Bytes

    public init(traceID: Bytes, spanID: Bytes) {
        self.traceID = traceID
        self.spanID = spanID
    }
}

/// `ServiceContext` key that carries trace correlation IDs.
public enum OTLPTraceIDsKey: ServiceContextKey {
    public typealias Value = OTLPTraceIDs
    public static let nameOverride: String? = "otlp.trace_ids"
}

extension ServiceContext {
    /// Trace correlation IDs (v0.1: bare-swift custom encoding).
    public var otlpTraceIDs: OTLPTraceIDs? {
        get { self[OTLPTraceIDsKey.self] }
        set { self[OTLPTraceIDsKey.self] = newValue }
    }
}

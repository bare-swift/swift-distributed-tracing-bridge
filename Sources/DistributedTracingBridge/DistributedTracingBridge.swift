// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// Apple swift-distributed-tracing backend that routes to swift-tracing-otlp.
///
/// Bootstrap once with an `OTLPTracer`:
///
/// ```swift
/// import Tracing
/// import OTLPExporter
/// import DistributedTracingBridge
///
/// let tracer = OTLPTracer(resource: ..., scope: ...)
/// InstrumentationSystem.bootstrap(tracer)
/// ```
///
/// See ``OTLPTracer`` for the entry point.
public enum DistributedTracingBridge: Sendable {}

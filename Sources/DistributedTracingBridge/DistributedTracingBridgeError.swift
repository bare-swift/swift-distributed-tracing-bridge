// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// Errors thrown by ``OTLPTracer`` and related types.
///
/// **v0.1: this enum has no cases.** The bridge does not throw at runtime
/// today; the type exists as a forward-compatible extension point for
/// v0.2 propagation-format errors. Mirrors `OTLPError` and `TracingOTLPError`.
public enum DistributedTracingBridgeError: Error, Equatable, Sendable {}

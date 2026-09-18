# Testing strategy

The test suite separates five kinds of evidence:

1. Unit tests cover deterministic random streams, grammar validation, static
   analysis, tree operations, signatures, corpus limits, and codecs.
2. Property-style loops generate many seeds and assert depth, node, byte,
   cardinality, byte-domain, and balance invariants.
3. Campaign tests run fixed seeds and compare complete statistics and event
   traces for deterministic equality.
4. Three application examples prove defect discovery and replay for recursive
   text, arbitrary binary, and stateful operation inputs.
5. Multi-backend CI runs check/build/test on Wasm, Wasm-GC, JavaScript, and
   Native across Linux, macOS, and Windows.

Strict local gate:

```bash
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon fmt
git diff --exit-code
moon info
git diff --exit-code
moon publish --dry-run
```

Campaign tests use logical execution counts rather than wall-clock assertions.
This keeps results reproducible on shared CI runners. Performance evidence is
reported separately and must not weaken correctness assertions.


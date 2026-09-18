# Deterministic strategy comparison

Command:

```bash
moon run --target native examples/benchmark
```

Environment: MoonBit `0.1.20260827`, seed `20260918`, 2,000 target
executions per strategy. Recorded 2026-09-18.

| Strategy | Executions | Features | Signatures | Failures | Corpus |
| --- | ---: | ---: | ---: | ---: | ---: |
| single-byte-mutation | 2000 | 4 | 3 | 0 | 0 |
| structured-feedback | 2000 | 17 | 152 | 1 | 153 |

The target accepts a framed command document. The byte baseline mutates one byte
of a valid seed, so most changes damage framing and remain shallow. The
structured strategy mutates the command derivation tree, retains new feature
signatures, and reaches the embedded `ABCD` ordering defect.

These are deterministic logical-workload counts, not elapsed-time throughput.
The executable test recomputes the comparison and asserts only durable facts:
structured exploration reaches more features and signatures and finds the known
defect. Wall-clock numbers are deliberately excluded because shared CI runner
timings are not a stable correctness contract.


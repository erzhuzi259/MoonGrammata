# Release acceptance evidence

Snapshot date: 2026-09-18. This document separates locally reproduced evidence
from external publication evidence. Commands are run from the repository root.

## Identity and scope

- Module: `erzhuzi259/moongrammata`
- Version: `0.1.0`
- License: Apache-2.0
- Repository target: <https://github.com/erzhuzi259/MoonGrammata>
- Primary implementation language: MoonBit
- Product boundary: structure-aware text/byte derivation trees, persistent
  feedback corpus, structural mutation/crossover, failure-preserving reduction,
  and deterministic replay for controlled in-process targets.

The dated registry review in `docs/MOONCAKES_RESEARCH.md` found no published
module with this combined boundary. QuickCheck and model-based testing packages
are documented as complementary near-neighbours rather than claimed absent.

## Local source and history evidence

- MoonBit toolchain: `moon 0.1.20260827`, `moonc v0.10.11`,
  `moonrun 0.1.20260827`.
- Production MoonBit: 20 files, 5,112 physical lines, 4,460 nonblank lines that
  do not begin with `//`. Test files are excluded from this production count.
- Tests: 19 MoonBit test files, 982 physical lines, 869 nonblank/non-`//` lines.
- History before the final evidence update: 29 meaningful commits, all authored and
  committed by `erzhuzi259 <erzhuzi259@users.noreply.github.com>`.
- No `_build`, `target`, `.mooncakes`, or `.scratch` artifact is tracked.

The line-count method intentionally does not pretend to be a parser-based SLOC
metric. It is a conservative, reproducible project-scale check; functional
acceptance is established by the executable gates below.

## Local release gates

The following commands passed on 2026-09-18:

```text
moon fmt
moon info
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
git diff --check
```

Test results:

| Backend | Passed | Failed |
| --- | ---: | ---: |
| Wasm | 61 | 0 |
| Wasm-GC | 61 | 0 |
| JavaScript | 61 | 0 |
| Native | 63 | 0 |

All runnable demonstrations also passed:

```text
moon run --target native examples/expression
moon run --target native examples/tlv
moon run --target native examples/state_sequence
moon run --target native examples/benchmark
moon run --target native cmd/moongrammata -- sample 3 20260918
```

The expression, TLV, and state-sequence campaigns found their known defects and
emitted replay artifacts. The deterministic benchmark completed 2,000 target
executions per strategy: single-byte mutation reached 4 features/3 signatures
and no failure; structured feedback reached 17 features/147 signatures and the
known failure. A fixed-seed 100,000-execution Native campaign completed without
an error or budget violation (12.339 seconds on the audit machine; timing is
informational, not a portable performance promise).

The network-enabled `moon publish --dry-run` constructed
`erzhuzi259-moongrammata-0.1.0.zip`, extracted it, and successfully ran
`moon check` against the extracted package. Mooncakes returned `202 Accepted`
and stated that the dry run completed successfully without making changes. The
current CLI nevertheless returned exit code 1 after that accepted response.
Public CI cannot use this command because a clean runner has no private
Mooncakes credential. It instead runs `moon package --list`, which performs
`moon check`, generates the same publish ZIP, and prints its complete manifest
without requiring registry authentication. The authenticated server dry run is
kept as a separate local release gate.

## External gates

All external release gates passed on 2026-09-18:

- The [GitHub repository](https://github.com/erzhuzi259/MoonGrammata) is public,
  uses `main` as its default branch, and GitHub recognizes its Apache-2.0 license.
- [GitHub Actions run 35326353732](https://github.com/erzhuzi259/MoonGrammata/actions/runs/35326353732)
  passed on Ubuntu, macOS, and Windows for commit `a72b589`. Each job performed
  dependency resolution, all-target check/build/test, formatting and public API
  checks, all examples, the strategy benchmark, the CLI smoke test, and package
  manifest generation.
- `moon publish` returned `200 OK` for `erzhuzi259/moongrammata@0.1.0`.
  The [Mooncakes package](https://mooncakes.io/docs/erzhuzi259/moongrammata) API
  reports version `0.1.0`, `build_status: success`, Apache-2.0, and checksum
  `623833c165307584f49a3c164570799ee0a5db46fd6d5f000f69f38ffbe57b35`.
- A new, unrelated temporary MoonBit module installed the exact published
  version with `moon add erzhuzi259/moongrammata@0.1.0`, imported the root
  package, built a literal grammar through the public `GrammarBuilder` API, and
  generated/rendered `hello`. Its consumer test passed on Wasm, Wasm-GC,
  JavaScript, and Native.

The repository, CI, package registry, and clean-consumer evidence jointly prove
that release `0.1.0` is public, installable, buildable, testable, and runnable.

## 0.1.1 update — 2026-10-01

Release `0.1.1` bounds independent replay records by the configured failure
budget without stopping campaign execution. Its three-platform CI, Mooncakes
publication, and independent consumer verification are recorded in
[the 2026-10-01 release verification](LOCAL_VERIFICATION_2026-10-01.md).
The `0.1.0` evidence above remains the historical record for that release.

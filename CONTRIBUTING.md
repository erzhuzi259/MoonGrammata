# Contributing

## Before changing behavior

Open an issue describing the target input family, stable feature vocabulary,
resource limits, and expected replay behavior. Security-sensitive targets should
also explain whether they execute untrusted code; the core does not provide a
sandbox.

Use the repository labels `needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, and `wontfix` for issue state.

## Development gate

```bash
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon fmt
git diff --exit-code
moon info
git diff --exit-code
```

Every behavior change needs a focused test. Generative tests must use an explicit
seed and assert semantic invariants rather than snapshots of incidental random
choices. Performance changes need deterministic logical-workload evidence;
wall-clock assertions do not belong in CI.

## Compatibility rules

- Preserve replay schema decoding for records emitted by the current major
  version, or document a migration before changing it.
- Do not call user-defined features “coverage” unless they represent real code
  coverage.
- Keep generation, mutation, corpus, reduction, and artifact limits explicit.
- New grammar rule kinds must participate in validation, analysis, generation,
  mutation/reduction decisions, public API generation, and boundary tests.
- Fixtures copied from elsewhere require a provenance entry and compatible
  redistribution license before commit.

Commits should represent coherent engineering changes. Do not create empty,
duplicate, or mechanically split commits.


# Design

## Data path

1. The grammar builder seals a finite rule graph and validates references.
2. Static analysis proves that the reachable start graph has a productive path.
3. A seeded generator produces a budgeted derivation tree and exact bytes.
4. The target consumes those bytes and reports disposition plus stable features.
5. Corpus admission retains novel feedback or a new failure fingerprint.
6. The scheduler selects corpus parents; mutation or crossover produces children.
7. Failures become versioned replay records and may be structurally minimized.

## Determinism contract

Given the same MoonGrammata version, grammar construction order, target behavior,
seed, and configuration, generation and campaign decisions are deterministic.
Host time, filesystem order, process identifiers, and ambient randomness are not
read by the portable core. Target nondeterminism remains the caller's
responsibility and is exposed by replay divergence.

## Resource contract

Generation has depth, node, byte, and repeat limits. Corpus storage has entry,
aggregate-byte, failure, and per-input limits. Mutation, crossover, reduction,
events, executions, and replay input parsing each have independent bounds.
Limits are checked before growth where possible; no limit is advertised as a
security sandbox for an untrusted target function.

## Feedback contract

A feature is a stable domain observation, not necessarily a control-flow edge.
Signatures sort and deduplicate features before identity comparison. A failure
fingerprint contains the stable defect class chosen by the target. Volatile
details such as memory addresses and timestamps should not appear in either.

## Clean-room boundary

The implementation uses public algorithm descriptions: grammar derivation,
tree mutation, corpus novelty, weighted energy scheduling, delta debugging-like
reduction, and deterministic replay. It does not translate an existing fuzzer's
source layout, types, APIs, or algorithms line by line.


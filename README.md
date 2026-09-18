# MoonGrammata

MoonGrammata is a structure-aware, feedback-guided fuzzing toolkit written in
MoonBit. It generates derivation trees from composable grammars, mutates and
crosses those trees without immediately destroying their shape, retains inputs
that expose new user-defined features, minimizes failures by stable fingerprint,
and emits deterministic replay artifacts.

The toolkit targets a practical gap between independent property-test samples
and compiler-instrumented native fuzzers. A target reports domain features such
as parser stages, AST node kinds, protocol states, error classes, or application
branches. MoonGrammata evolves a persistent corpus from those observations. It
does not call those features “coverage” unless the target actually supplies code
coverage data.

## Why this exists

Random byte mutation often spends most of its time producing inputs rejected by
the first parser check. Property generators can produce valid values, but
independent samples do not automatically retain discoveries and evolve them.
MoonGrammata keeps the input structure and the exploration history together:

- a `Grammar` describes the structured input space;
- a `DerivationTree` records how one input was produced;
- a `Target` reports a disposition, stable features, an optional result digest,
  and a coarse cost class;
- a `Corpus` retains novel feedback signatures and unique failures;
- an energy scheduler gives rare and productive entries more mutation work;
- reducers preserve a `FailureFingerprint`, not merely an error string search;
- `ReplayRecord` stores the exact bytes and expected observations as versioned
  JSON.

## Installation

Install the current release from Mooncakes:

```bash
moon add erzhuzi259/moongrammata@0.1.0
```

Package page: <https://mooncakes.io/docs/erzhuzi259/moongrammata>

During local development, clone the repository and run:

```bash
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run --target native cmd/moongrammata -- sample 5 20260918
moon run --target native cmd/moongrammata -- campaign 1000 20260918
```

## Minimal library example

```moonbit nocheck
let builder = @grammata.GrammarBuilder::new()
let digit = builder.ascii_range('0', '9', name="digit")
let comma = builder.literal(",")
let item = builder.sequence([digit, comma])
let document = builder.repeat(item, minimum=1, maximum=20)
let grammar = builder.set_start(document).build().unwrap()

let target = @grammata.Target::new("csv-like", input => {
  let feature = @grammata.feature("length-band", (input.length() / 8).to_string())
  @grammata.accepted(features=[feature])
})

let config = {
  ..@grammata.CampaignConfig::default(seed=42L),
  executions: 10000,
}
let result = @grammata.run_campaign(grammar, target, config).unwrap()
println(result.markdown_report())
```

## Core capabilities

### Grammar and static analysis

The combinator API supports literals, byte sets, bounded integers,
dictionaries, sequences, weighted choices, bounded repetition, optional rules,
and named recursive references. `Grammar::analyze` computes reachability,
nullability, productivity, recursion, minimum byte cost, and minimum node cost.
Unproductive recursion is rejected before a campaign starts.

Generation enforces independent maximums for depth, nodes, rendered bytes, and
repeat cardinality. The deterministic random stream and every derived seed are
portable across supported MoonBit backends.

### Structural evolution

Built-in mutations include:

- subtree regeneration from the same grammar rule;
- repeat-child deletion and duplication within declared cardinality;
- optional-child toggling;
- integer boundary replacement;
- dictionary entry replacement;
- compatible-rule subtree crossover between corpus entries.

Every result is renumbered and checked against byte, node, and depth budgets.

### Feedback and corpus

Features are explicit `(domain, value)` pairs. Their signature is order
independent and duplicate free. Corpus admission distinguishes the first input,
new features, new signatures, and new failure fingerprints. Duplicate input,
entry capacity, aggregate byte capacity, failure capacity, and per-input size
are all bounded.

The scheduler uses feature rarity, signature rarity, prior discoveries, target
cost, failure status, and selection count. This is a deterministic heuristic,
not a claim of globally optimal search.

### Oracles, reduction, and replay

MoonGrammata includes single-target execution, differential comparison,
metamorphic relations, and multi-target agreement. The reducer tries structural
deletions, value simplification, and smaller regenerated subtrees, accepting a
candidate only if the target returns the same failure fingerprint.

Replay JSON records the schema version, target identity, seed, exact input
bytes, feedback signature, failure fingerprint, result digest, and generation
budget. Replaying compares all stable observations and reports divergence.

## Complete runnable examples

| Example | Input family | Demonstrated defect | Command |
| --- | --- | --- | --- |
| Expression | Recursive text grammar | Division by zero | `moon run examples/expression` |
| TLV | Arbitrary binary bytes | Reserved tail in a valid-length frame | `moon run examples/tlv` |
| State sequence | Stateful operation list | Use after free | `moon run examples/state_sequence` |
| Benchmark | Framed command language | Strategy comparison | `moon run --target native examples/benchmark` |

Each example has deterministic tests showing that a fixed campaign seed finds
the known defect and that its replay artifact still matches.

## Scope boundaries

Version 0.1 intentionally does not provide:

- compiler-level automatic coverage instrumentation;
- native process isolation, crash signal capture, ASan, or libFuzzer ABI;
- arbitrary EBNF parsing;
- distributed fuzzing or persistent network coordinators;
- a replacement for property-based testing;
- a claim that untrusted targets are safely sandboxed.

Targets are controlled in-process functions. Integrations may report real code
coverage as features, but the core remains independent of compiler changes.

## QuickCheck relationship

`moonbitlang/quickcheck` centers on generated typed values, properties, and
shrinking. MoonGrammata centers on structured text/byte derivation trees,
persistent corpus evolution, target-provided feedback, structural mutation and
crossover, failure-fingerprint reduction, and replay. The projects are
complementary: a QuickCheck generator can help construct target data, while a
MoonGrammata target can use ordinary assertions or differential implementations.

## Repository layout

- root `.mbt` files: portable library core and tests;
- `cmd/moongrammata`: native runnable smoke CLI;
- `examples/expression`: recursive text target;
- `examples/tlv`: binary target;
- `examples/state_sequence`: stateful operation target;
- `docs/`: design, research, roadmap, provenance, and acceptance evidence;
- `.github/workflows/`: multi-platform check/build/test automation.

## Verification

The release gate is:

```bash
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt
git diff --exit-code
moon info
git diff --exit-code
moon package --list
```

Maintainers additionally run the authenticated `moon publish --dry-run` before
release; clean public CI runners use `moon package --list` because the registry
dry run requires private Mooncakes credentials.

See `docs/ACCEPTANCE.md` for captured local evidence and
`docs/MOONCAKES_RESEARCH.md` for the dated non-duplication review.

## Open-source and provenance

MoonGrammata is an original clean-room MoonBit implementation licensed under
Apache-2.0. Algorithm ideas and terminology were informed by public fuzzing
literature and official documentation; no libFuzzer, AFL, or
libprotobuf-mutator implementation code is copied. See `THIRD_PARTY_NOTICES.md`
and `docs/PROVENANCE.md`.

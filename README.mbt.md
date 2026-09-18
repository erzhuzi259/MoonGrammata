# MoonGrammata

Structure-aware, feedback-guided fuzzing for MoonBit.

```moonbit nocheck
///|
let builder = @grammata.GrammarBuilder::new()

///|
let digit = builder.ascii_range('0', '9')

///|
let document = builder.repeat(digit, minimum=1, maximum=16)

///|
let grammar = builder.set_start(document).build().unwrap()

///|
let tree = grammar.generate(seed=42L).unwrap()
```

The core provides bounded grammar generation, derivation-tree mutation and
crossover, novelty corpus scheduling, failure-preserving reduction,
differential/metamorphic oracles, deterministic replay, and evidence reports.
See the repository README for the full contract and runnable examples.


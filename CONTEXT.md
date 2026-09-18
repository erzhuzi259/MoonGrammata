# MoonGrammata

MoonGrammata explores structured input spaces while preserving enough shape to reach behavior that unstructured random mutation rarely reaches.

## Language

**Grammar**:
A finite graph of composable rules that describes the valid or near-valid input space.
_Avoid_: Schema, format definition

**Derivation Tree**:
A concrete input together with the grammar choices and structure that produced it.
_Avoid_: AST, parse tree

**Target**:
A user-supplied function that consumes one generated input and returns observations about that execution.
_Avoid_: System under test, harness

**Oracle**:
The rule that classifies an execution outcome and decides whether two failures represent the same defect.
_Avoid_: Assertion, validator

**Feature**:
A stable, user-defined observation such as a parser stage, state, node kind, error class, or branch label.
_Avoid_: Coverage, unless actual code coverage is being measured

**Feedback Signature**:
The deterministic identity of the feature set observed during one execution.
_Avoid_: Coverage hash

**Corpus**:
The retained inputs whose feedback or failure value justifies future mutation.
_Avoid_: Dataset, fixtures

**Mutator**:
A strategy that transforms a derivation tree while respecting its structural constraints.
_Avoid_: Randomizer

**Reducer**:
A strategy that shrinks an input while preserving its failure fingerprint.
_Avoid_: Shrinker

**Failure Fingerprint**:
The stable identity used to decide whether a reduced or replayed input still exposes the same defect.
_Avoid_: Error message

**Replay Record**:
A versioned persistent description of the seed, configuration, input, and expected failure fingerprint needed for deterministic reproduction.
_Avoid_: Log, snapshot


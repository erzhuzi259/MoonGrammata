# Source and fixture provenance

- All `.mbt` implementation and test files: original project code.
- Example grammars and deliberately defective targets: original project fixtures.
- README diagrams and tables: original project documentation.
- No copied fuzzing corpus is committed.
- No generated MoonBit source is counted toward the effective line total.
- `_build/`, `.mooncakes/`, reports, and local replay artifacts are ignored.
- Public background sources are listed in `THIRD_PARTY_NOTICES.md`.

When external test vectors are added later, each vector must record its upstream
URL, version or commit, license, local modifications, and redistribution basis
before entering the repository.


# Release verification — 2026-10-01

This records the verification of `erzhuzi259/moongrammata@0.1.1`. It is not a
claim of final acceptance by the contest organizers.

- Toolchain: `moonc 0.10.14+7d59c7ec9`, `moon 0.1.20260920`.
- Change: Replay-record storage now honors max_failures without stopping the campaign.
- `moon fmt --check`, all-target strict check, and all-target strict build: passed.
- All-target tests: 62 (Native: 64) passed per listed backend; zero failed.
- Native runnable example: `moon run --target native examples/expression` passed.
- Effective local MoonBit lines: 5353, counting nonblank, non-`//` lines in
  checked-in `.mbt` files including tests and examples, excluding generated
  build artifacts and downloaded dependencies.
- License: Apache-2.0; existing README, CI workflow, examples, and tests remain
  part of the repository.
- Release commit: `6296040694c3009673cfa4bf58ac1943deedd86f`, pushed to
  the public GitHub repository's `main` branch.
- [GitHub Actions run 36818052410](https://github.com/erzhuzi259/MoonGrammata/actions/runs/36818052410)
  passed on Ubuntu, Windows, and macOS. It checked formatting, public API,
  all-backend check/build/test, runnable examples, CLI, benchmark, and package
  archive generation.
- The publish archive was `erzhuzi259-moongrammata-0.1.1.zip` (80,965 bytes;
  SHA-256 `2148e5a866a431a2e5f2c6837361e9e682b3b6257265f34b990c6e9f43f29a8b`).
  Its manifest contained no Git metadata, build directory, or credentials.
- `moon publish` returned `200 OK`; a subsequent `moon search moongrammata --json`
  reported `0.1.1` as the current version.
- An isolated consumer module updated the registry, installed exactly
  `erzhuzi259/moongrammata@0.1.1`, and passed a public-API regression test on
  Wasm, Wasm-GC, JavaScript, and Native. The test confirms that 20 executions
  complete while replay records stay within `max_failures: 1`.

For moonc 0.10.14, strict check/build/test use
`--deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package`. The warning list exempts only the compiler's
`implicit_impl_as_method` and `test_unqualified_package` migration warnings;
all other warnings remain fatal. Migrating those call sites and derived-method
exposure is future maintenance, not a completed fix.

Reproduction from the repository root:

```sh
moon fmt --check
moon check --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon build --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon test --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon run --target native examples/expression
```

The package release, public repository, remote CI, and independent consumer
have been verified. Final contest acceptance remains the organizers' decision.

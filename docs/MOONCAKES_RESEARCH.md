# Mooncakes non-duplication review

Snapshot date: 2026-09-18.

The official Mooncakes registry reported 2,522 modules and 23,035 packages. The
review used the complete module metadata endpoint and official full-text search
for `fuzzer`, `grammar based fuzzing`, `coverage guided fuzzing`, `structured
fuzzing`, `property based testing`, and related algorithm terms.

No published module with MoonGrammata's combined boundary was found: structured
text/byte derivation trees, persistent feedback corpus, structural mutation and
crossover, failure-fingerprint reduction, and deterministic replay.

The nearest relevant package is `moonbitlang/quickcheck`, which provides
property-based typed-value generation and shrinking. It does not make
MoonGrammata redundant; the boundary comparison is documented in the README.
Search results containing “fuzzer” also referred to unrelated protocol, UI, or
path-search documentation rather than a general fuzzing toolkit.

Primary registry/search sources:

- <https://mooncakes.io/api/v0/modules>
- <https://mooncakes.io/api/v0/modules/statistics>
- <https://mooncakes.io/api/v0/search?kw=fuzzer&limit=20>
- <https://mooncakes.io/api/v0/search?kw=grammar%20based%20fuzzing&limit=20>
- <https://mooncakes.io/api/v0/search?kw=coverage%20guided%20fuzzing&limit=20>
- <https://mooncakes.io/api/v0/search?kw=property%20based%20testing&limit=20>
- <https://github.com/moonbitlang/mooncakes.io/blob/main/src/page/home/server_search.mbt>

This is a dated evidence statement, not proof that a similar package can never
appear. The same queries and a manual review of new suspicious results must be
repeated immediately before `moon publish`.


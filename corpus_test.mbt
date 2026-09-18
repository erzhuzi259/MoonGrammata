///|
fn literal_tree(value : String, id : Int) -> DerivationTree {
  let payload : Array[Byte] = []
  for byte in @utf8.encode(value) { payload.push(byte) }
  DerivationTree::leaf(id, RuleId(0), LiteralLeaf, payload)
}

///|
test "corpus admits novelty and rejects duplicate inputs" {
  let corpus = Corpus::new()
  let parse = feature("stage", "parse")
  let first = corpus.consider(
    literal_tree("a", 0),
    accepted(features=[parse]),
    Seeded(1L),
  )
  assert_true(first is Admitted(0, FirstInput))
  assert_eq(
    corpus.consider(
      literal_tree("a", 9),
      accepted(features=[parse]),
      Generated(2L),
    ),
    Rejected(DuplicateInput),
  )
  let deeper = corpus.consider(
    literal_tree("b", 1),
    accepted(features=[parse, feature("stage", "evaluate")]),
    Generated(3L),
  )
  assert_true(deeper is Admitted(1, NovelFeature(1)))
}

///|
test "corpus retains one representative for each new failure" {
  let corpus = Corpus::new()
  ignore(corpus.consider(literal_tree("ok", 0), accepted(), Seeded(1L)))
  let crash = failed("panic", "bounds")
  assert_true(
    corpus.consider(literal_tree("long-crash", 1), crash, Generated(2L))
    is Admitted(_, NewFailure(_)),
  )
  let fingerprint = crash.failure_fingerprint().unwrap()
  assert_eq(corpus.failure_entry(fingerprint).unwrap().id, 1)
  assert_eq(corpus.smallest_failure(fingerprint).unwrap().id, 1)
}

///|
test "corpus enforces input and aggregate limits" {
  let limits : CorpusLimits = {
    max_entries: 2,
    max_total_bytes: 4,
    max_failures: 1,
    max_input_bytes: 3,
  }
  let corpus = Corpus::new(limits~)
  assert_true(
    corpus.consider(literal_tree("abcd", 0), accepted(), Seeded(1L))
    is Rejected(InputTooLarge(4)),
  )
  ignore(corpus.consider(literal_tree("ab", 0), accepted(), Seeded(1L)))
  assert_true(
    corpus.consider(
      literal_tree("cde", 1),
      accepted(features=[feature("new", "x")]),
      Generated(2L),
    ) is Rejected(ByteCapacity),
  )
}

///|
test "corpus statistics track retained evidence" {
  let corpus = Corpus::new()
  ignore(corpus.consider(
    literal_tree("a", 0),
    accepted(features=[feature("path", "one")]),
    Seeded(1L),
  ))
  ignore(corpus.consider(
    literal_tree("b", 1),
    failed("panic", "x", features=[feature("path", "two")]),
    Generated(2L),
  ))
  let stats = corpus.statistics()
  assert_eq(stats.entries, 2)
  assert_eq(stats.failures, 1)
  assert_eq(stats.total_bytes, 2)
  assert_eq(stats.unique_features, 2)
  assert_eq(stats.unique_failures, 1)
}


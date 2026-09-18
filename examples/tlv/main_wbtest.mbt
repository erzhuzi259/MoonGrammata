///|
test "TLV campaign reaches matching lengths and known decoder defect" {
  let result = run_tlv_demo(1000)
  assert_true(result.statistics.final_corpus.unique_features >= 5)
  assert_true(result.statistics.unique_failures >= 1)
  let replay = result.failures[0]
  assert_true(
    replay.failure_fingerprint.unwrap().value().contains("reserved-tail-byte"),
  )
  assert_true(tlv_target().replay(replay).unwrap().matches())
}

///|
test "TLV grammar remains within frame bounds" {
  let grammar = tlv_grammar()
  for seed = 1; seed <= 100; seed = seed + 1 {
    let input = grammar.generate(seed=Int64::from_int(seed)).unwrap().render()
    assert_true(input.length() >= 2)
    assert_true(input.length() <= 6)
    assert_true(input[0].to_int() >= 1 && input[0].to_int() <= 3)
    assert_true(input[1].to_int() <= 4)
  }
}

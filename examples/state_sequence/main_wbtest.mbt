///|
test "state sequence campaign finds use after free" {
  let result = run_state_sequence_demo(1000)
  assert_true(result.statistics.unique_failures >= 1)
  let replay = result.failures[0]
  assert_true(replay.failure_fingerprint.unwrap().value().contains("use-after-free"))
  assert_true(operation_target().replay(replay).unwrap().matches())
}

///|
test "operation grammar emits only declared commands" {
  let grammar = operation_grammar()
  for seed = 1; seed <= 100; seed = seed + 1 {
    let input = grammar.generate(seed=Int64::from_int(seed)).unwrap().render()
    assert_true(input.length() >= 1 && input.length() <= 20)
    for byte in input {
      let value = byte.to_int().unsafe_to_char()
      assert_true(value == 'A' || value == 'U' || value == 'F' || value == 'R')
    }
  }
}


///|
test "expression campaign finds the seeded arithmetic defect" {
  let result = run_expression_demo(1000)
  assert_true(result.statistics.unique_failures >= 1)
  let fingerprint = result.failures[0].failure_fingerprint.unwrap().value()
  assert_true(fingerprint.contains("division-by-zero"))
  assert_true(expression_target().replay(result.failures[0]).unwrap().matches())
}

///|
test "expression grammar emits balanced inputs" {
  let grammar = expression_grammar()
  for seed = 1; seed <= 100; seed = seed + 1 {
    let tree = grammar.generate(seed=Int64::from_int(seed)).unwrap()
    let text = tree.render_text().unwrap()
    let mut balance = 0
    for byte in @utf8.encode(text) {
      if byte.to_int() == '('.to_int() { balance += 1 }
      if byte.to_int() == ')'.to_int() { balance -= 1 }
      assert_true(balance >= 0)
    }
    assert_eq(balance, 0)
  }
}


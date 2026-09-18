///|
test "reducer removes irrelevant repeated structure while preserving failure" {
  let grammar = mutation_grammar()
  let mut failing : DerivationTree? = None
  for seed = 1; seed < 200; seed = seed + 1 {
    let tree = grammar.generate(seed=Int64::from_int(seed)).unwrap()
    if tree.byte_length() > 10 {
      failing = Some(tree)
      break
    }
  }
  let tree = failing.unwrap()
  let target = Target::new("contains-colon", input => {
    let text = @utf8.decode(input) catch { _ => "" }
    if text.contains(":") {
      failed("semantic", "colon-present")
    } else {
      accepted()
    }
  })
  let result = grammar.reduce_failure(tree, target).unwrap()
  assert_true(
    result.reduced.byte_length() < tree.byte_length() ||
    result.reduced.node_count() < tree.node_count(),
  )
  assert_eq(
    target.run(result.reduced.render()).failure_fingerprint(),
    Some(result.fingerprint),
  )
  assert_true(result.attempts > 0)
}

///|
test "reducer refuses non-failing inputs" {
  let grammar = mutation_grammar()
  let tree = grammar.generate(seed=1L).unwrap()
  let target = Target::new("always-ok", _ => accepted())
  assert_true(grammar.reduce_failure(tree, target) is Err(InputDoesNotFail))
}

///|
test "reducer validates requested failure identity" {
  let grammar = mutation_grammar()
  let tree = grammar.generate(seed=1L).unwrap()
  let target = Target::new("always-bad", _ => failed("panic", "actual"))
  assert_true(
    grammar.reduce_failure(
      tree,
      target,
      fingerprint=FailureFingerprint("different"),
    )
    is Err(FingerprintMismatch(_, _)),
  )
}

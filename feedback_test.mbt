///|
test "feedback signatures are order independent and duplicate free" {
  let a = feature("parser", "header")
  let b = feature("node", "object")
  assert_eq(feedback_signature([a, b, a]), feedback_signature([b, a]))
  assert_true(feedback_signature([a]) != feedback_signature([b]))
}

///|
test "failure fingerprints distinguish defect classes" {
  let first = failed("panic", "division-by-zero")
  let same = failed("panic", "division-by-zero", features=[feature("x", "1")])
  let other = failed("panic", "bounds")
  assert_eq(first.failure_fingerprint(), same.failure_fingerprint())
  assert_true(first.failure_fingerprint() != other.failure_fingerprint())
  assert_eq(accepted().failure_fingerprint(), None)
}

///|
test "feature registry reports novelty and frequencies" {
  let registry = FeatureRegistry::new()
  let parse = feature("stage", "parse")
  let evaluate = feature("stage", "evaluate")
  let first = registry.observe(accepted(features=[parse]))
  assert_eq(first.novel_features, [parse])
  let second = registry.observe(accepted(features=[evaluate, parse]))
  assert_eq(second.novel_features, [evaluate])
  assert_eq(registry.feature_frequency(parse), 2)
  assert_eq(registry.unique_feature_count(), 2)
  assert_eq(registry.observation_count(), 2)
}

///|
test "target wraps a pure controlled evaluator" {
  let target = Target::new("length", input => {
    accepted(
      features=[feature("length", input.length().to_string())],
      result_digest=input.length().to_string(),
    )
  })
  let result = target.run(b"abc")
  assert_eq(target.name(), "length")
  assert_eq(result.result_digest, Some("3"))
  assert_eq(result.feature_count(), 1)
}

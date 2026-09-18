///|
test "differential target reports semantic divergence" {
  let left = Target::new("left", input =>
    accepted(result_digest=input.length().to_string()))
  let right = Target::new("right", input =>
    accepted(result_digest=(input.length() + 1).to_string()))
  let oracle = differential_target("diff", left, right)
  let result = oracle.run(b"abc")
  assert_true(result.is_failure())
  assert_true(
    result.failure_fingerprint().unwrap().value().contains("differential-mismatch"),
  )
}

///|
test "metamorphic target validates declared relations" {
  let length = Target::new("length", input =>
    accepted(result_digest=input.length().to_string()))
  let identity = same_digest_transform("identity", input => input)
  let valid = metamorphic_target("valid", length, [identity])
  assert_false(valid.run(b"abc").is_failure())
  let append = same_digest_transform("append", input => {
    let values : Array[Byte] = []
    for byte in input { values.push(byte) }
    values.push(0)
    Bytes::from_array(values)
  })
  let invalid = metamorphic_target("invalid", length, [append])
  assert_true(invalid.run(b"abc").is_failure())
}

///|
test "agreement target accepts a quorum" {
  let one = Target::new("one", _ => accepted(result_digest="yes"))
  let two = Target::new("two", _ => accepted(result_digest="yes"))
  let three = Target::new("three", _ => accepted(result_digest="no"))
  let oracle = agreement_target("quorum", [one, two, three])
  let result = oracle.run(b"input")
  assert_false(result.is_failure())
  assert_eq(result.result_digest, Some("accepted|yes"))
}


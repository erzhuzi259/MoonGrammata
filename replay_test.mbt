///|
test "replay records round trip arbitrary binary input" {
  let observation = failed("panic", "binary", features=[
    feature("stage", "decode"),
  ])
  let record = ReplayRecord::new(
    target_name="decoder",
    seed=-88L,
    input=Bytes::from_array([0, 127, 255]),
    observation~,
  )
  let decoded = ReplayRecord::decode_json(record.encode_json()).unwrap()
  assert_eq(decoded, record)
}

///|
test "target replay checks all stable observations" {
  let target = Target::new("length", input => {
    accepted(
      features=[feature("length", input.length().to_string())],
      result_digest=input.length().to_string(),
    )
  })
  let observation = target.run(b"abc")
  let record = ReplayRecord::new(
    target_name="length",
    seed=1L,
    input=b"abc",
    observation~,
  )
  assert_true(target.replay(record).unwrap().matches())
}

///|
test "replay rejects malformed and oversized artifacts" {
  assert_true(ReplayRecord::decode_json("not json") is Err(InvalidJson))
  let observation = accepted()
  let record = ReplayRecord::new(
    target_name="x",
    seed=1L,
    input=b"four",
    observation~,
  )
  assert_true(
    ReplayRecord::decode_json(record.encode_json(), max_input_bytes=3)
    is Err(InputLimitExceeded(3)),
  )
  assert_true(
    ReplayRecord::decode_json(record.encode_json(), max_artifact_bytes=8)
    is Err(ArtifactLimitExceeded(8)),
  )
}

///|
test "replay rejects invalid embedded generation budgets" {
  let observation = accepted()
  let record = ReplayRecord::new(
    target_name="x",
    seed=1L,
    input=b"x",
    observation~,
  )
  let invalid = record
    .encode_json()
    .replace(old="\"max_depth\":32", new="\"max_depth\":0")
  assert_true(
    ReplayRecord::decode_json(invalid)
    is Err(InvalidField("generation_budget is invalid")),
  )
}

///|
test "replay refuses a different target identity" {
  let observation = accepted()
  let record = ReplayRecord::new(
    target_name="one",
    seed=1L,
    input=b"x",
    observation~,
  )
  let target = Target::new("two", _ => accepted())
  assert_true(target.replay(record) is Err(TargetNameMismatch("one", "two")))
}

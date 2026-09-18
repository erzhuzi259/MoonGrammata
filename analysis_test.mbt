///|
test "analysis finds nullable productive and unreachable rules" {
  let builder = GrammarBuilder::new()
  let empty = builder.literal("", name="empty")
  let atom = builder.literal("x", name="atom")
  let maybe = builder.optional(atom, name="maybe")
  let start = builder.sequence([empty, maybe], name="start")
  ignore(builder.literal("unused", name="unused"))
  let grammar = builder.set_start(start).build().unwrap()
  let analysis = grammar.analyze()
  assert_eq(analysis.reachable_count, 4)
  assert_eq(analysis.unreachable_count, 1)
  assert_true(analysis.properties(empty).unwrap().nullable)
  assert_true(analysis.properties(maybe).unwrap().nullable)
  assert_eq(analysis.properties(start).unwrap().minimum_bytes, Some(0))
  assert_eq(analysis.properties(atom).unwrap().minimum_bytes, Some(1))
}

///|
test "analysis recognizes productive recursion with a base case" {
  let builder = GrammarBuilder::new()
  let digit = builder.ascii_range('0', '9', name="digit")
  let recurse = builder.reference("number")
  let longer = builder.sequence([digit, recurse])
  let number = builder.choice(
    [alternative(digit, weight=2), alternative(longer)],
    name="number",
  )
  let grammar = builder.set_start(number).build().unwrap()
  let analysis = grammar.validate_productivity().unwrap()
  assert_true(analysis.properties(number).unwrap().recursive)
  assert_true(analysis.properties(recurse).unwrap().recursive)
  assert_eq(analysis.properties(number).unwrap().minimum_bytes, Some(1))
}

///|
test "analysis rejects recursion without a terminating path" {
  let builder = GrammarBuilder::new()
  let reference = builder.reference("loop")
  let cycle = builder.sequence([reference], name="loop")
  let grammar = builder.set_start(cycle).build().unwrap()
  assert_true(grammar.validate_productivity() is Err(UnproductiveStartRule(_)))
}

///|
test "integer width analysis accounts for zero and signs" {
  let builder = GrammarBuilder::new()
  let crossing = builder.integer(-200, 300)
  let positive = builder.integer(120, 999)
  let negative = builder.integer(-999, -10)
  let start = builder.sequence([crossing, positive, negative])
  let grammar = builder.set_start(start).build().unwrap()
  let analysis = grammar.analyze()
  assert_eq(analysis.properties(crossing).unwrap().minimum_bytes, Some(1))
  assert_eq(analysis.properties(positive).unwrap().minimum_bytes, Some(3))
  assert_eq(analysis.properties(negative).unwrap().minimum_bytes, Some(3))
}

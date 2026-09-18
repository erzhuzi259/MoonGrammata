///|
test "builder creates named recursive grammar" {
  let builder = GrammarBuilder::new()
  let number = builder.integer(0, 99, name="number")
  let plus = builder.literal("+")
  let expression_ref = builder.reference("expression")
  let nested = builder.sequence([expression_ref, plus, number])
  let expression = builder.choice(
    [alternative(number, weight=4), alternative(nested, weight=1)],
    name="expression",
  )
  let grammar = builder.set_start(expression).build().unwrap()
  assert_eq(grammar.rule_count(), 5)
  assert_eq(grammar.resolve("number"), Some(number))
  assert_eq(grammar.resolve("expression"), Some(expression))
  assert_eq(grammar.start(), expression)
}

///|
test "builder rejects invalid references and bounds" {
  let missing = GrammarBuilder::new()
  let reference = missing.reference("absent")
  assert_true(
    missing.set_start(reference).build() is Err(MissingNamedRule("absent")),
  )
  let bounds = GrammarBuilder::new()
  let bad = bounds.integer(10, 2)
  assert_true(
    bounds.set_start(bad).build() is Err(InvalidIntegerBounds(0, 10, 2)),
  )
}

///|
test "builder rejects duplicate names and invalid byte sets" {
  let duplicate = GrammarBuilder::new()
  ignore(duplicate.literal("a", name="same"))
  let last = duplicate.literal("b", name="same")
  assert_true(
    duplicate.set_start(last).build() is Err(DuplicateRuleName("same")),
  )
  let bytes = GrammarBuilder::new()
  let invalid = bytes.bytes([0, 256])
  assert_true(bytes.set_start(invalid).build() is Err(InvalidByteValue(0, 256)))
}

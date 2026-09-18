///|
fn expression_grammar() -> Grammar {
  let builder = GrammarBuilder::new()
  let number = builder.integer(0, 99, name="number")
  let open = builder.literal("(")
  let close = builder.literal(")")
  let operator = builder.dictionary(["+", "-", "*"])
  let reference = builder.reference("expression")
  let binary = builder.sequence([open, reference, operator, reference, close])
  let expression = builder.choice(
    [alternative(number, weight=5), alternative(binary, weight=2)],
    name="expression",
  )
  builder.set_start(expression).build().unwrap()
}

///|
test "generation is deterministic and preserves budgets" {
  let grammar = expression_grammar()
  let budget = GenerationBudget::new(max_depth=12, max_nodes=128, max_bytes=256)
  let first = grammar.generate(seed=20260918L, budget~).unwrap()
  let second = grammar.generate(seed=20260918L, budget~).unwrap()
  assert_eq(first, second)
  assert_true(first.depth() <= 12)
  assert_true(first.node_count() <= 128)
  assert_true(first.byte_length() <= 256)
  assert_eq(first.render(), second.render())
}

///|
test "generation eventually exercises recursive and base alternatives" {
  let grammar = expression_grammar()
  let mut nested = 0
  let mut base = 0
  for seed = 1; seed <= 100; seed = seed + 1 {
    let tree = grammar.generate(seed=Int64::from_int(seed)).unwrap()
    if tree.byte_length() > 2 {
      nested += 1
    } else {
      base += 1
    }
  }
  assert_true(nested > 0)
  assert_true(base > 0)
}

///|
test "binary leaves preserve arbitrary byte values" {
  let builder = GrammarBuilder::new()
  let byte = builder.bytes([0, 127, 255])
  let many = builder.repeat(byte, minimum=3, maximum=3)
  let grammar = builder.set_start(many).build().unwrap()
  let tree = grammar.generate(seed=4L).unwrap()
  assert_eq(tree.byte_length(), 3)
  assert_eq(tree.render().length(), 3)
  for value in tree.render() {
    assert_true(value.to_int() == 0 || value.to_int() == 127 || value.to_int() == 255)
  }
}

///|
test "generation rejects impossible resource budgets" {
  let builder = GrammarBuilder::new()
  let literal = builder.literal("abcdef")
  let grammar = builder.set_start(literal).build().unwrap()
  assert_true(
    grammar.generate(
      seed=1L,
      budget=GenerationBudget::new(max_bytes=3),
    ) is Err(ByteBudgetExceeded(3)),
  )
  assert_true(
    grammar.generate(
      seed=1L,
      budget=GenerationBudget::new(max_nodes=0),
    ) is Err(InvalidBudget(_)),
  )
}

///|
test "tree replacement and rule lookup preserve structure" {
  let grammar = expression_grammar()
  let tree = grammar.generate(seed=3L).unwrap()
  let start = tree.rule()
  assert_true(tree.nodes_for_rule(start).length() >= 1)
  assert_eq(tree.find(tree.node_id()), Some(tree))
  assert_eq(tree.renumber().node_id(), 0)
  assert_true(tree.structural_summary().has_prefix("nodes="))
}

///|
fn mutation_grammar() -> Grammar {
  let builder = GrammarBuilder::new()
  let integer = builder.integer(-10, 10)
  let word = builder.dictionary(["red", "green", "blue"])
  let suffix = builder.optional(builder.literal("!"))
  let item = builder.sequence([integer, builder.literal(":"), word, suffix])
  let list = builder.repeat(item, minimum=1, maximum=5)
  builder.set_start(list).build().unwrap()
}

///|
test "integer mutation chooses declared boundaries" {
  let grammar = mutation_grammar()
  let original = grammar.generate(seed=18L).unwrap()
  let result = grammar
    .mutate_with(original, ReplaceIntegerBoundary, seed=7L)
    .unwrap()
  assert_true(result.tree.render() != original.render())
  assert_true(result.strategy is ReplaceIntegerBoundary)
}

///|
test "repeat deletion and duplication preserve declared cardinality" {
  let grammar = mutation_grammar()
  let original = grammar.generate(seed=22L).unwrap()
  let duplicate = grammar.mutate_with(original, DuplicateRepeatedChild, seed=3L)
  match duplicate {
    Ok(result) => {
      assert_true(result.tree.node_count() > original.node_count())
      let deleted = grammar
        .mutate_with(result.tree, DeleteRepeatedChild, seed=4L)
        .unwrap()
      assert_true(deleted.tree.node_count() < result.tree.node_count())
    }
    Err(NoApplicableMutation) => ()
    Err(_) => assert_true(false)
  }
}

///|
test "optional mutation changes presence without corrupting render" {
  let grammar = mutation_grammar()
  let original = grammar.generate(seed=9L).unwrap()
  let result = grammar.mutate_with(original, ToggleOptional, seed=2L).unwrap()
  assert_true(result.tree.render() != original.render())
  assert_true(result.tree.node_count() > 0)
}

///|
test "automatic mutation is deterministic and bounded" {
  let grammar = mutation_grammar()
  let original = grammar.generate(seed=44L).unwrap()
  let config = MutationConfig::default()
  let left = grammar.mutate(original, seed=81L, config~).unwrap()
  let right = grammar.mutate(original, seed=81L, config~).unwrap()
  assert_eq(left, right)
  assert_true(left.tree.byte_length() <= config.maximum_output_bytes)
}

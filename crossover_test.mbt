///|
test "crossover exchanges compatible grammar subtrees" {
  let grammar = mutation_grammar()
  let left = grammar.generate(seed=13L).unwrap()
  let right = grammar.generate(seed=91L).unwrap()
  assert_true(crossover_compatible_rule_count(left, right) > 0)
  let result = crossover(left, right, seed=7L).unwrap()
  assert_true(result.tree.render() != left.render())
  assert_true(result.tree.node_count() <= 512)
  assert_true(result.tree.depth() <= 32)
}

///|
test "crossover rejects unrelated trees" {
  let left = DerivationTree::leaf(0, RuleId(1), LiteralLeaf, [1])
  let right = DerivationTree::leaf(0, RuleId(2), LiteralLeaf, [2])
  assert_eq(crossover_compatible_rule_count(left, right), 0)
  assert_true(crossover(left, right, seed=1L) is Err(NoCompatibleSubtree))
}

///|
test "crossover enforces output budgets" {
  let left = DerivationTree::branch(0, RuleId(0), SequenceNode, [
    DerivationTree::leaf(1, RuleId(1), LiteralLeaf, [1]),
  ])
  let right = DerivationTree::branch(0, RuleId(0), SequenceNode, [
    DerivationTree::leaf(1, RuleId(1), LiteralLeaf, [1, 2, 3, 4]),
  ])
  let config : CrossoverConfig = {
    ..CrossoverConfig::default(),
    maximum_output_bytes: 2,
  }
  assert_true(
    crossover(left, right, seed=1L, config~)
    is Err(CrossoverBudgetExceeded("bytes", 2)),
  )
}

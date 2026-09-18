///|
pub(all) enum MutationStrategy {
  RegenerateSubtree
  DeleteRepeatedChild
  ToggleOptional
  ReplaceIntegerBoundary
  ReplaceDictionaryEntry
  DuplicateRepeatedChild
} derive(Debug, Eq)

///|
pub(all) struct MutationResult {
  tree : DerivationTree
  strategy : MutationStrategy
  changed_node : Int
  detail : String
} derive(Debug, Eq)

///|
pub(all) struct MutationConfig {
  budget : GenerationBudget
  attempts : Int
  maximum_output_bytes : Int
} derive(Debug, Eq)

///|
pub fn MutationConfig::default() -> MutationConfig {
  {
    budget: GenerationBudget::default(),
    attempts: 32,
    maximum_output_bytes: 16384,
  }
}

///|
pub(all) enum MutationError {
  EmptyTree
  NoApplicableMutation
  GenerationFailed(GenerationError)
  OutputBudgetExceeded(Int)
} derive(Debug, Eq)

///|
fn filtered_nodes(
  tree : DerivationTree,
  predicate : (DerivationTree) -> Bool,
) -> Array[DerivationTree] {
  let result : Array[DerivationTree] = []
  for node in tree.descendants() {
    if predicate(node) { result.push(node) }
  }
  result
}

///|
fn choose_node(random : Random, nodes : Array[DerivationTree]) -> DerivationTree? {
  match random.choose_index(nodes.length()) {
    None => None
    Some(index) => Some(nodes[index])
  }
}

///|
fn finalize_mutation(
  original : DerivationTree,
  candidate : DerivationTree,
  strategy : MutationStrategy,
  node : Int,
  detail : String,
  maximum_output_bytes : Int,
) -> Result[MutationResult, MutationError] {
  let renumbered = candidate.renumber()
  if renumbered.byte_length() > maximum_output_bytes {
    Err(OutputBudgetExceeded(maximum_output_bytes))
  } else if renumbered.render() == original.render() &&
    renumbered.node_count() == original.node_count() {
    Err(NoApplicableMutation)
  } else {
    Ok({ tree: renumbered, strategy, changed_node: node, detail })
  }
}

///|
fn regenerate_subtree(
  grammar : Grammar,
  original : DerivationTree,
  random : Random,
  config : MutationConfig,
) -> Result[MutationResult, MutationError] {
  let nodes = original.descendants()
  let selected = choose_node(random, nodes).unwrap()
  let generated = match grammar.generate_from(
    selected.rule,
    seed=Int64::from_int(random.next_raw()),
    budget=config.budget,
  ) {
    Err(error) => return Err(GenerationFailed(error))
    Ok(value) => value
  }
  finalize_mutation(
    original,
    original.replace(selected.node_id, generated),
    RegenerateSubtree,
    selected.node_id,
    "regenerated rule " + selected.rule.value().to_string(),
    config.maximum_output_bytes,
  )
}

///|
fn deletable_repeat(grammar : Grammar, node : DerivationTree) -> Bool {
  match (node.kind, grammar.rule(node.rule).unwrap().kind) {
    (RepeatNode(count), Repeat(_, minimum, _)) => count > minimum
    _ => false
  }
}

///|
fn delete_repeated_child(
  grammar : Grammar,
  original : DerivationTree,
  random : Random,
  config : MutationConfig,
) -> Result[MutationResult, MutationError] {
  let nodes = filtered_nodes(original, node => deletable_repeat(grammar, node))
  let selected = match choose_node(random, nodes) {
    None => return Err(NoApplicableMutation)
    Some(value) => value
  }
  let removed = random.below(selected.children.length())
  let children : Array[DerivationTree] = []
  for index, child in selected.children {
    if index != removed { children.push(child) }
  }
  let replacement = {
    ..selected,
    kind: RepeatNode(children.length()),
    children,
  }
  finalize_mutation(
    original,
    original.replace(selected.node_id, replacement),
    DeleteRepeatedChild,
    selected.node_id,
    "removed repeat child " + removed.to_string(),
    config.maximum_output_bytes,
  )
}

///|
fn optional_nodes(tree : DerivationTree) -> Array[DerivationTree] {
  filtered_nodes(tree, node => node.kind is OptionalNode(_))
}

///|
fn toggle_optional(
  grammar : Grammar,
  original : DerivationTree,
  random : Random,
  config : MutationConfig,
) -> Result[MutationResult, MutationError] {
  let selected = match choose_node(random, optional_nodes(original)) {
    None => return Err(NoApplicableMutation)
    Some(value) => value
  }
  let replacement = match selected.kind {
    OptionalNode(true) => { ..selected, kind: OptionalNode(false), children: [] }
    OptionalNode(false) => {
      let child_rule = match grammar.rule(selected.rule).unwrap().kind {
        Optional(child, _) => child
        _ => return Err(NoApplicableMutation)
      }
      let child = match grammar.generate_from(
        child_rule,
        seed=Int64::from_int(random.next_raw()),
        budget=config.budget,
      ) {
        Err(error) => return Err(GenerationFailed(error))
        Ok(value) => value
      }
      { ..selected, kind: OptionalNode(true), children: [child] }
    }
    _ => return Err(NoApplicableMutation)
  }
  finalize_mutation(
    original,
    original.replace(selected.node_id, replacement),
    ToggleOptional,
    selected.node_id,
    "toggled optional presence",
    config.maximum_output_bytes,
  )
}

///|
fn integer_boundaries(minimum : Int, maximum : Int) -> Array[Int] {
  let candidates : Array[Int] = [minimum, maximum]
  for value in [-1, 0, 1] {
    if value >= minimum && value <= maximum && !candidates.contains(value) {
      candidates.push(value)
    }
  }
  if minimum < maximum {
    if minimum < 2147483647 && !candidates.contains(minimum + 1) {
      candidates.push(minimum + 1)
    }
    if maximum > -2147483648 && !candidates.contains(maximum - 1) {
      candidates.push(maximum - 1)
    }
  }
  candidates
}

///|
fn replace_integer_boundary(
  grammar : Grammar,
  original : DerivationTree,
  random : Random,
  config : MutationConfig,
) -> Result[MutationResult, MutationError] {
  let nodes = filtered_nodes(original, node => node.kind is IntegerLeaf(_))
  let selected = match choose_node(random, nodes) {
    None => return Err(NoApplicableMutation)
    Some(value) => value
  }
  let (minimum, maximum) = match grammar.rule(selected.rule).unwrap().kind {
    Integer(minimum, maximum) => (minimum, maximum)
    _ => return Err(NoApplicableMutation)
  }
  let old = match selected.kind { IntegerLeaf(value) => value; _ => 0 }
  let choices : Array[Int] = []
  for value in integer_boundaries(minimum, maximum) {
    if value != old { choices.push(value) }
  }
  if choices.is_empty() { return Err(NoApplicableMutation) }
  let value = choices[random.below(choices.length())]
  let replacement = DerivationTree::leaf(
    selected.node_id,
    selected.rule,
    IntegerLeaf(value),
    string_bytes(value.to_string()),
  )
  finalize_mutation(
    original,
    original.replace(selected.node_id, replacement),
    ReplaceIntegerBoundary,
    selected.node_id,
    old.to_string() + " -> " + value.to_string(),
    config.maximum_output_bytes,
  )
}

///|
fn replace_dictionary_entry(
  grammar : Grammar,
  original : DerivationTree,
  random : Random,
  config : MutationConfig,
) -> Result[MutationResult, MutationError] {
  let nodes = filtered_nodes(original, node => node.kind is DictionaryLeaf(_))
  let selected = match choose_node(random, nodes) {
    None => return Err(NoApplicableMutation)
    Some(value) => value
  }
  let values = match grammar.rule(selected.rule).unwrap().kind {
    Dictionary(values) => values
    _ => return Err(NoApplicableMutation)
  }
  let old = match selected.kind { DictionaryLeaf(value) => value; _ => 0 }
  if values.length() <= 1 { return Err(NoApplicableMutation) }
  let mut index = random.below(values.length() - 1)
  if index >= old { index += 1 }
  let replacement = DerivationTree::leaf(
    selected.node_id,
    selected.rule,
    DictionaryLeaf(index),
    string_bytes(values[index]),
  )
  finalize_mutation(
    original,
    original.replace(selected.node_id, replacement),
    ReplaceDictionaryEntry,
    selected.node_id,
    old.to_string() + " -> " + index.to_string(),
    config.maximum_output_bytes,
  )
}

///|
fn duplicable_repeat(grammar : Grammar, node : DerivationTree) -> Bool {
  match (node.kind, grammar.rule(node.rule).unwrap().kind) {
    (RepeatNode(count), Repeat(_, _, maximum)) =>
      count > 0 && count < maximum
    _ => false
  }
}

///|
fn duplicate_repeated_child(
  grammar : Grammar,
  original : DerivationTree,
  random : Random,
  config : MutationConfig,
) -> Result[MutationResult, MutationError] {
  let nodes = filtered_nodes(original, node => duplicable_repeat(grammar, node))
  let selected = match choose_node(random, nodes) {
    None => return Err(NoApplicableMutation)
    Some(value) => value
  }
  let index = random.below(selected.children.length())
  let children = selected.children.copy()
  children.insert(index, selected.children[index])
  let replacement = {
    ..selected,
    kind: RepeatNode(children.length()),
    children,
  }
  finalize_mutation(
    original,
    original.replace(selected.node_id, replacement),
    DuplicateRepeatedChild,
    selected.node_id,
    "duplicated repeat child " + index.to_string(),
    config.maximum_output_bytes,
  )
}

///|
pub fn Grammar::mutate_with(
  self : Grammar,
  tree : DerivationTree,
  strategy : MutationStrategy,
  seed~ : Int64,
  config? : MutationConfig = MutationConfig::default(),
) -> Result[MutationResult, MutationError] {
  let random = Random::new(seed)
  match strategy {
    RegenerateSubtree => regenerate_subtree(self, tree, random, config)
    DeleteRepeatedChild => delete_repeated_child(self, tree, random, config)
    ToggleOptional => toggle_optional(self, tree, random, config)
    ReplaceIntegerBoundary => replace_integer_boundary(self, tree, random, config)
    ReplaceDictionaryEntry => replace_dictionary_entry(self, tree, random, config)
    DuplicateRepeatedChild => duplicate_repeated_child(self, tree, random, config)
  }
}

///|
pub fn Grammar::mutate(
  self : Grammar,
  tree : DerivationTree,
  seed~ : Int64,
  config? : MutationConfig = MutationConfig::default(),
) -> Result[MutationResult, MutationError] {
  let strategies = [
    RegenerateSubtree,
    DeleteRepeatedChild,
    ToggleOptional,
    ReplaceIntegerBoundary,
    ReplaceDictionaryEntry,
    DuplicateRepeatedChild,
  ]
  let order = deterministic_permutation(seed, strategies.length())
  let limit = config.attempts.max(1).min(256)
  for attempt = 0; attempt < limit; attempt = attempt + 1 {
    let strategy = strategies[order[attempt % order.length()]]
    match self.mutate_with(
      tree,
      strategy,
      seed=seed + Int64::from_int(attempt * 104729),
      config~,
    ) {
      Ok(result) => return Ok(result)
      Err(NoApplicableMutation) => ()
      Err(_) => ()
    }
  }
  Err(NoApplicableMutation)
}


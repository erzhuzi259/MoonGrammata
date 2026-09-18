///|
pub(all) struct CrossoverConfig {
  maximum_output_bytes : Int
  maximum_nodes : Int
  maximum_depth : Int
  attempts : Int
} derive(Debug, Eq)

///|
pub fn CrossoverConfig::default() -> CrossoverConfig {
  {
    maximum_output_bytes: 16384,
    maximum_nodes: 512,
    maximum_depth: 32,
    attempts: 32,
  }
}

///|
pub(all) struct CrossoverResult {
  tree : DerivationTree
  recipient_node : Int
  donor_node : Int
  rule : RuleId
} derive(Debug, Eq)

///|
pub(all) enum CrossoverError {
  NoCompatibleSubtree
  CrossoverBudgetExceeded(String, Int)
  NoEffectiveCrossover
} derive(Debug, Eq)

///|
fn compatible_pairs(
  recipient : DerivationTree,
  donor : DerivationTree,
) -> Array[(DerivationTree, DerivationTree)] {
  let pairs : Array[(DerivationTree, DerivationTree)] = []
  let donor_nodes = donor.descendants()
  for left in recipient.descendants() {
    for right in donor_nodes {
      if left.rule == right.rule && left.node_id != recipient.node_id {
        pairs.push((left, right))
      }
    }
  }
  if pairs.is_empty() && recipient.rule == donor.rule {
    pairs.push((recipient, donor))
  }
  pairs
}

///|
fn within_crossover_budget(
  tree : DerivationTree,
  config : CrossoverConfig,
) -> Result[Unit, CrossoverError] {
  if tree.byte_length() > config.maximum_output_bytes {
    Err(CrossoverBudgetExceeded("bytes", config.maximum_output_bytes))
  } else if tree.node_count() > config.maximum_nodes {
    Err(CrossoverBudgetExceeded("nodes", config.maximum_nodes))
  } else if tree.depth() > config.maximum_depth {
    Err(CrossoverBudgetExceeded("depth", config.maximum_depth))
  } else {
    Ok(())
  }
}

///|
pub fn crossover(
  recipient : DerivationTree,
  donor : DerivationTree,
  seed~ : Int64,
  config? : CrossoverConfig = CrossoverConfig::default(),
) -> Result[CrossoverResult, CrossoverError] {
  let pairs = compatible_pairs(recipient, donor)
  if pairs.is_empty() {
    return Err(NoCompatibleSubtree)
  }
  let random = Random::new(seed)
  let order = random.sample_without_replacement(
    pairs.length(),
    config.attempts.max(1).min(pairs.length()),
  )
  let mut budget_error : CrossoverError? = None
  for pair_index in order {
    let (left, right) = pairs[pair_index]
    let candidate = recipient.replace(left.node_id, right).renumber()
    if candidate.render() == recipient.render() &&
      candidate.node_count() == recipient.node_count() {
      continue
    }
    match within_crossover_budget(candidate, config) {
      Err(error) => budget_error = Some(error)
      Ok(_) =>
        return Ok({
          tree: candidate,
          recipient_node: left.node_id,
          donor_node: right.node_id,
          rule: left.rule,
        })
    }
  }
  match budget_error {
    Some(error) => Err(error)
    None => Err(NoEffectiveCrossover)
  }
}

///|
pub fn crossover_compatible_rule_count(
  left : DerivationTree,
  right : DerivationTree,
) -> Int {
  let seen : @hashmap.HashMap[RuleId, Unit] = @hashmap.HashMap([])
  let right_rules : @hashmap.HashMap[RuleId, Unit] = @hashmap.HashMap([])
  for node in right.descendants() {
    right_rules.set(node.rule, ())
  }
  for node in left.descendants() {
    if right_rules.contains(node.rule) {
      seen.set(node.rule, ())
    }
  }
  seen.length()
}

///|
pub(all) enum ReductionKind {
  RemoveRepeatedChild
  RemoveOptionalChild
  ReplaceWithSmallerSubtree
  SimplifyInteger
  SimplifyDictionary
} derive(Debug, Eq)

///|
pub(all) struct ReductionStep {
  kind : ReductionKind
  node_id : Int
  before_bytes : Int
  after_bytes : Int
  before_nodes : Int
  after_nodes : Int
} derive(Debug, Eq)

///|
pub(all) struct ReductionConfig {
  max_attempts : Int
  generation_trials : Int
  generation_budget : GenerationBudget
} derive(Debug, Eq)

///|
pub fn ReductionConfig::default() -> ReductionConfig {
  {
    max_attempts: 2048,
    generation_trials: 8,
    generation_budget: GenerationBudget::new(
      max_depth=16,
      max_nodes=256,
      max_bytes=8192,
    ),
  }
}

///|
pub(all) struct ReductionResult {
  original : DerivationTree
  reduced : DerivationTree
  fingerprint : FailureFingerprint
  attempts : Int
  accepted_steps : Array[ReductionStep]
} derive(Debug, Eq)

///|
pub fn ReductionResult::bytes_removed(self : ReductionResult) -> Int {
  self.original.byte_length() - self.reduced.byte_length()
}

///|
pub fn ReductionResult::nodes_removed(self : ReductionResult) -> Int {
  self.original.node_count() - self.reduced.node_count()
}

///|
pub(all) enum ReductionError {
  InputDoesNotFail
  FingerprintMismatch(FailureFingerprint, FailureFingerprint)
  NoReductionPossible
} derive(Debug, Eq)

///|
priv struct ReductionCandidate {
  tree : DerivationTree
  kind : ReductionKind
  node_id : Int
}

///|
fn strictly_smaller(left : DerivationTree, right : DerivationTree) -> Bool {
  left.byte_length() < right.byte_length() ||
  (
    left.byte_length() == right.byte_length() &&
    left.node_count() < right.node_count()
  )
}

///|
fn insert_candidate(
  candidates : Array[ReductionCandidate],
  candidate : ReductionCandidate,
) -> Unit {
  for index = 0; index < candidates.length(); index = index + 1 {
    if strictly_smaller(candidate.tree, candidates[index].tree) {
      candidates.insert(index, candidate)
      return
    }
  }
  candidates.push(candidate)
}

///|
fn repeat_reductions(
  grammar : Grammar,
  root : DerivationTree,
  node : DerivationTree,
  output : Array[ReductionCandidate],
) -> Unit {
  let minimum = match grammar.rule(node.rule).unwrap().kind {
    Repeat(_, minimum, _) => minimum
    _ => return
  }
  if node.children.length() <= minimum {
    return
  }
  for removed = 0; removed < node.children.length(); removed = removed + 1 {
    let children : Array[DerivationTree] = []
    for index, child in node.children {
      if index != removed {
        children.push(child)
      }
    }
    let replacement = { ..node, kind: RepeatNode(children.length()), children, }
    insert_candidate(output, {
      tree: root.replace(node.node_id, replacement).renumber(),
      kind: RemoveRepeatedChild,
      node_id: node.node_id,
    })
  }
}

///|
fn optional_reduction(
  root : DerivationTree,
  node : DerivationTree,
  output : Array[ReductionCandidate],
) -> Unit {
  if node.kind is OptionalNode(true) {
    let replacement = { ..node, kind: OptionalNode(false), children: [], }
    insert_candidate(output, {
      tree: root.replace(node.node_id, replacement).renumber(),
      kind: RemoveOptionalChild,
      node_id: node.node_id,
    })
  }
}

///|
fn integer_reductions(
  grammar : Grammar,
  root : DerivationTree,
  node : DerivationTree,
  output : Array[ReductionCandidate],
) -> Unit {
  let current = match node.kind {
    IntegerLeaf(value) => value
    _ => return
  }
  let (minimum, maximum) = match grammar.rule(node.rule).unwrap().kind {
    Integer(minimum, maximum) => (minimum, maximum)
    _ => return
  }
  let candidates = integer_boundaries(minimum, maximum)
  for value in candidates {
    if value == current {
      continue
    }
    let replacement = DerivationTree::leaf(
      node.node_id,
      node.rule,
      IntegerLeaf(value),
      string_bytes(value.to_string()),
    )
    let candidate = root.replace(node.node_id, replacement).renumber()
    if strictly_smaller(candidate, root) {
      insert_candidate(output, {
        tree: candidate,
        kind: SimplifyInteger,
        node_id: node.node_id,
      })
    }
  }
}

///|
fn dictionary_reductions(
  grammar : Grammar,
  root : DerivationTree,
  node : DerivationTree,
  output : Array[ReductionCandidate],
) -> Unit {
  let current = match node.kind {
    DictionaryLeaf(value) => value
    _ => return
  }
  let values = match grammar.rule(node.rule).unwrap().kind {
    Dictionary(values) => values
    _ => return
  }
  for index, value in values {
    if index == current || value.length() >= node.payload.length() {
      continue
    }
    let replacement = DerivationTree::leaf(
      node.node_id,
      node.rule,
      DictionaryLeaf(index),
      string_bytes(value),
    )
    insert_candidate(output, {
      tree: root.replace(node.node_id, replacement).renumber(),
      kind: SimplifyDictionary,
      node_id: node.node_id,
    })
  }
}

///|
fn generated_reductions(
  grammar : Grammar,
  root : DerivationTree,
  node : DerivationTree,
  config : ReductionConfig,
  seed : Int64,
  output : Array[ReductionCandidate],
) -> Unit {
  for trial = 0; trial < config.generation_trials.max(0); trial = trial + 1 {
    let generated = grammar.generate_from(
      node.rule,
      seed=seed + Int64::from_int(trial * 8191 + node.node_id * 131),
      budget=config.generation_budget,
    )
    match generated {
      Err(_) => ()
      Ok(replacement) => {
        let candidate = root.replace(node.node_id, replacement).renumber()
        if strictly_smaller(candidate, root) {
          insert_candidate(output, {
            tree: candidate,
            kind: ReplaceWithSmallerSubtree,
            node_id: node.node_id,
          })
        }
      }
    }
  }
}

///|
fn reduction_candidates(
  grammar : Grammar,
  tree : DerivationTree,
  config : ReductionConfig,
  seed : Int64,
) -> Array[ReductionCandidate] {
  let result : Array[ReductionCandidate] = []
  for node in tree.descendants() {
    match node.kind {
      RepeatNode(_) => repeat_reductions(grammar, tree, node, result)
      OptionalNode(_) => optional_reduction(tree, node, result)
      IntegerLeaf(_) => integer_reductions(grammar, tree, node, result)
      DictionaryLeaf(_) => dictionary_reductions(grammar, tree, node, result)
      _ => ()
    }
    generated_reductions(grammar, tree, node, config, seed, result)
  }
  result
}

///|
pub fn Grammar::reduce_failure(
  self : Grammar,
  tree : DerivationTree,
  target : Target,
  fingerprint? : FailureFingerprint,
  seed? : Int64 = 1L,
  config? : ReductionConfig = ReductionConfig::default(),
) -> Result[ReductionResult, ReductionError] {
  let initial_observation = target.run(tree.render())
  let actual = match initial_observation.failure_fingerprint() {
    None => return Err(InputDoesNotFail)
    Some(value) => value
  }
  let expected = fingerprint.unwrap_or(actual)
  if expected != actual {
    return Err(FingerprintMismatch(expected, actual))
  }
  let original = tree
  let mut current = tree
  let mut attempts = 0
  let steps : Array[ReductionStep] = []
  let limit = config.max_attempts.max(0).min(100000)
  let mut changed = true
  while changed && attempts < limit {
    changed = false
    let candidates = reduction_candidates(
      self,
      current,
      config,
      seed + Int64::from_int(attempts),
    )
    for candidate in candidates {
      if attempts >= limit {
        break
      }
      attempts += 1
      let observation = target.run(candidate.tree.render())
      if observation.failure_fingerprint() == Some(expected) {
        steps.push({
          kind: candidate.kind,
          node_id: candidate.node_id,
          before_bytes: current.byte_length(),
          after_bytes: candidate.tree.byte_length(),
          before_nodes: current.node_count(),
          after_nodes: candidate.tree.node_count(),
        })
        current = candidate.tree
        changed = true
        break
      }
    }
  }
  if steps.is_empty() {
    Err(NoReductionPossible)
  } else {
    Ok({
      original,
      reduced: current,
      fingerprint: expected,
      attempts,
      accepted_steps: steps,
    })
  }
}

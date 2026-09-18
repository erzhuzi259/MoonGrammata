///|
pub(all) struct GenerationBudget {
  max_depth : Int
  max_nodes : Int
  max_bytes : Int
  max_repeat : Int
} derive(Debug, Eq)

///|
pub fn GenerationBudget::default() -> GenerationBudget {
  { max_depth: 32, max_nodes: 512, max_bytes: 16384, max_repeat: 64 }
}

///|
pub fn GenerationBudget::new(
  max_depth? : Int = 32,
  max_nodes? : Int = 512,
  max_bytes? : Int = 16384,
  max_repeat? : Int = 64,
) -> GenerationBudget {
  { max_depth, max_nodes, max_bytes, max_repeat }
}

///|
pub(all) enum GenerationError {
  InvalidBudget(String)
  UnproductiveGrammar(AnalysisError)
  DepthBudgetExceeded(Int)
  NodeBudgetExceeded(Int)
  ByteBudgetExceeded(Int)
  NoViableAlternative(Int)
  InvalidGeneratedInteger(Int, Int)
} derive(Debug, Eq)

///|
priv struct GenerationState {
  random : Random
  budget : GenerationBudget
  analysis : GrammarAnalysis
  mut nodes : Int
  mut bytes : Int
  mut next_node_id : Int
}

///|
fn GenerationBudget::validate(self : GenerationBudget) -> Result[Unit, GenerationError] {
  if self.max_depth <= 0 {
    Err(InvalidBudget("max_depth must be positive"))
  } else if self.max_nodes <= 0 {
    Err(InvalidBudget("max_nodes must be positive"))
  } else if self.max_bytes < 0 {
    Err(InvalidBudget("max_bytes must not be negative"))
  } else if self.max_repeat < 0 {
    Err(InvalidBudget("max_repeat must not be negative"))
  } else {
    Ok(())
  }
}

///|
fn GenerationState::reserve_node(
  self : GenerationState,
  depth : Int,
) -> Result[Int, GenerationError] {
  if depth > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  if self.nodes >= self.budget.max_nodes {
    return Err(NodeBudgetExceeded(self.budget.max_nodes))
  }
  let id = self.next_node_id
  self.next_node_id += 1
  self.nodes += 1
  Ok(id)
}

///|
fn GenerationState::reserve_bytes(
  self : GenerationState,
  count : Int,
) -> Result[Unit, GenerationError] {
  if count < 0 || self.bytes > self.budget.max_bytes - count {
    Err(ByteBudgetExceeded(self.budget.max_bytes))
  } else {
    self.bytes += count
    Ok(())
  }
}

///|
fn string_bytes(value : String) -> Array[Byte] {
  let result : Array[Byte] = []
  for byte in @utf8.encode(value) {
    result.push(byte)
  }
  result
}

///|
fn viable_child(
  state : GenerationState,
  rule : RuleId,
  depth : Int,
) -> Bool {
  let properties = state.analysis.properties(rule).unwrap()
  if !properties.productive {
    return false
  }
  if depth >= state.budget.max_depth && properties.recursive {
    return false
  }
  match properties.minimum_bytes {
    None => false
    Some(minimum) => minimum <= state.budget.max_bytes - state.bytes
  }
}

///|
fn generate_leaf(
  state : GenerationState,
  rule : RuleId,
  node_id : Int,
  kind : DerivationKind,
  payload : Array[Byte],
) -> Result[DerivationTree, GenerationError] {
  match state.reserve_bytes(payload.length()) {
    Err(error) => Err(error)
    Ok(_) => Ok(DerivationTree::leaf(node_id, rule, kind, payload))
  }
}

///|
fn generate_rule(
  grammar : Grammar,
  state : GenerationState,
  rule : RuleId,
  depth : Int,
) -> Result[DerivationTree, GenerationError] {
  let node_id = match state.reserve_node(depth) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let definition = grammar.rule(rule).unwrap()
  match definition.kind {
    Literal(value) =>
      generate_leaf(state, rule, node_id, LiteralLeaf, string_bytes(value))
    Bytes(values) => {
      let index = state.random.below(values.length())
      generate_leaf(state, rule, node_id, ByteLeaf, [values[index].to_byte()])
    }
    Integer(minimum, maximum) => {
      if maximum < minimum {
        return Err(InvalidGeneratedInteger(minimum, maximum))
      }
      let value = state.random.between(minimum, maximum)
      generate_leaf(
        state,
        rule,
        node_id,
        IntegerLeaf(value),
        string_bytes(value.to_string()),
      )
    }
    Dictionary(values) => {
      let index = state.random.below(values.length())
      generate_leaf(
        state,
        rule,
        node_id,
        DictionaryLeaf(index),
        string_bytes(values[index]),
      )
    }
    Sequence(child_rules) => {
      let children : Array[DerivationTree] = []
      for child_rule in child_rules {
        let child = match generate_rule(grammar, state, child_rule, depth + 1) {
          Err(error) => return Err(error)
          Ok(value) => value
        }
        children.push(child)
      }
      Ok(DerivationTree::branch(node_id, rule, SequenceNode, children))
    }
    Choice(alternatives) => {
      let candidates : Array[Alternative] = []
      let weights : Array[Int] = []
      for item in alternatives {
        if viable_child(state, item.rule, depth + 1) {
          candidates.push(item)
          weights.push(item.weight)
        }
      }
      let selected = match state.random.weighted_index(weights) {
        None => return Err(NoViableAlternative(rule.value()))
        Some(value) => value
      }
      let item = candidates[selected]
      let child = match generate_rule(grammar, state, item.rule, depth + 1) {
        Err(error) => return Err(error)
        Ok(value) => value
      }
      Ok(DerivationTree::branch(
        node_id,
        rule,
        ChoiceNode(selected, item.label),
        [child],
      ))
    }
    Repeat(child_rule, minimum, maximum) => {
      let cap = maximum.min(state.budget.max_repeat)
      if cap < minimum {
        return Err(NoViableAlternative(rule.value()))
      }
      let child_properties = state.analysis.properties(child_rule).unwrap()
      let child_bytes = child_properties.minimum_bytes.unwrap_or(0).max(1)
      let by_bytes = (state.budget.max_bytes - state.bytes) / child_bytes
      let by_nodes = (state.budget.max_nodes - state.nodes).max(0)
      let affordable = cap.min(by_bytes).min(by_nodes)
      if affordable < minimum {
        return Err(NoViableAlternative(rule.value()))
      }
      let count = if depth >= state.budget.max_depth - 1 {
        minimum
      } else {
        state.random.between(minimum, affordable)
      }
      let children : Array[DerivationTree] = []
      for index = 0; index < count; index = index + 1 {
        let child = match generate_rule(grammar, state, child_rule, depth + 1) {
          Err(error) => return Err(error)
          Ok(value) => value
        }
        children.push(child)
      }
      Ok(DerivationTree::branch(node_id, rule, RepeatNode(count), children))
    }
    Optional(child_rule, present_weight) => {
      let present = viable_child(state, child_rule, depth + 1) &&
        state.random.chance(present_weight, present_weight + 1)
      let children = if present {
        match generate_rule(grammar, state, child_rule, depth + 1) {
          Err(error) => return Err(error)
          Ok(value) => [value]
        }
      } else {
        []
      }
      Ok(DerivationTree::branch(
        node_id,
        rule,
        OptionalNode(present),
        children,
      ))
    }
    Reference(name) => {
      let target = grammar.resolve(name).unwrap()
      let child = match generate_rule(grammar, state, target, depth + 1) {
        Err(error) => return Err(error)
        Ok(value) => value
      }
      Ok(DerivationTree::branch(
        node_id,
        rule,
        ReferenceNode(name),
        [child],
      ))
    }
  }
}

///|
pub fn Grammar::generate(
  self : Grammar,
  seed~ : Int64,
  budget? : GenerationBudget = GenerationBudget::default(),
) -> Result[DerivationTree, GenerationError] {
  match budget.validate() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let analysis = match self.validate_productivity() {
    Err(error) => return Err(UnproductiveGrammar(error))
    Ok(value) => value
  }
  let state = {
    random: Random::new(seed),
    budget,
    analysis,
    nodes: 0,
    bytes: 0,
    next_node_id: 0,
  }
  generate_rule(self, state, self.start(), 1)
}

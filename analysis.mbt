///|
pub(all) enum AnalysisError {
  UnproductiveStartRule(Int)
  UnproductiveRule(Int)
  NoTerminatingAlternative(Int)
  MinimumCostOverflow(Int)
} derive(Debug, Eq)

///|
pub(all) struct RuleProperties {
  rule : RuleId
  reachable : Bool
  nullable : Bool
  productive : Bool
  recursive : Bool
  minimum_bytes : Int?
  minimum_nodes : Int?
} derive(Debug, Eq)

///|
pub(all) struct GrammarAnalysis {
  rules : Array[RuleProperties]
  reachable_count : Int
  unreachable_count : Int
  recursive_count : Int
  nullable_count : Int
  productive_count : Int
} derive(Debug, Eq)

///|
pub fn GrammarAnalysis::properties(
  self : GrammarAnalysis,
  id : RuleId,
) -> RuleProperties? {
  if id.value() < 0 || id.value() >= self.rules.length() {
    None
  } else {
    Some(self.rules[id.value()])
  }
}

///|
pub fn GrammarAnalysis::rules(self : GrammarAnalysis) -> Array[RuleProperties] {
  self.rules.copy()
}

///|
fn Grammar::resolved_reference(self : Grammar, name : String) -> RuleId {
  self.resolve(name).unwrap()
}

///|
fn Grammar::children_of(
  self : Grammar,
  definition : RuleDefinition,
) -> Array[RuleId] {
  match definition.kind {
    Literal(_) | Bytes(_) | Integer(_, _) | Dictionary(_) => []
    Sequence(children) => children.copy()
    Choice(alternatives) => {
      let children : Array[RuleId] = []
      for item in alternatives {
        children.push(item.rule)
      }
      children
    }
    Repeat(child, _, _) | Optional(child, _) => [child]
    Reference(name) => [self.resolved_reference(name)]
  }
}

///|
fn mark_reachable(
  grammar : Grammar,
  rule : RuleId,
  reachable : FixedArray[Bool],
) -> Unit {
  let index = rule.value()
  if reachable[index] {
    return
  }
  reachable[index] = true
  let definition = grammar.rule(rule).unwrap()
  for child in grammar.children_of(definition) {
    mark_reachable(grammar, child, reachable)
  }
}

///|
fn nullable_kind(
  grammar : Grammar,
  kind : RuleKind,
  nullable : FixedArray[Bool],
) -> Bool {
  match kind {
    Literal(value) => value.is_empty()
    Bytes(_) | Integer(_, _) | Dictionary(_) => false
    Sequence(children) => {
      for child in children {
        if !nullable[child.value()] {
          return false
        }
      }
      true
    }
    Choice(alternatives) => {
      for item in alternatives {
        if nullable[item.rule.value()] {
          return true
        }
      }
      false
    }
    Repeat(child, minimum, _) => minimum == 0 || nullable[child.value()]
    Optional(_, _) => true
    Reference(name) => nullable[grammar.resolved_reference(name).value()]
  }
}

///|
fn productive_kind(
  grammar : Grammar,
  kind : RuleKind,
  productive : FixedArray[Bool],
) -> Bool {
  match kind {
    Literal(_) | Bytes(_) | Integer(_, _) | Dictionary(_) => true
    Sequence(children) => {
      for child in children {
        if !productive[child.value()] {
          return false
        }
      }
      true
    }
    Choice(alternatives) => {
      for item in alternatives {
        if productive[item.rule.value()] {
          return true
        }
      }
      false
    }
    Repeat(child, minimum, _) => minimum == 0 || productive[child.value()]
    Optional(_, _) => true
    Reference(name) => productive[grammar.resolved_reference(name).value()]
  }
}

///|
fn minimum_string_bytes(value : String) -> Int {
  value.length()
}

///|
fn decimal_width(value : Int) -> Int {
  if value == 0 {
    return 1
  }
  let mut current = value
  let mut width = 0
  if current < 0 {
    width += 1
    if current == -2147483648 {
      return 11
    }
    current = -current
  }
  while current > 0 {
    current = current / 10
    width += 1
  }
  width
}

///|
fn minimum_integer_width(minimum : Int, maximum : Int) -> Int {
  if minimum <= 0 && maximum >= 0 {
    1
  } else {
    decimal_width(minimum).min(decimal_width(maximum))
  }
}

///|
fn checked_add_cost(left : Int, right : Int) -> Int? {
  if left > 1000000000 - right {
    None
  } else {
    Some(left + right)
  }
}

///|
fn checked_multiply_cost(value : Int, count : Int) -> Int? {
  if count == 0 || value == 0 {
    Some(0)
  } else if value > 1000000000 / count {
    None
  } else {
    Some(value * count)
  }
}

///|
fn min_optional(left : Int?, right : Int?) -> Int? {
  match (left, right) {
    (None, value) => value
    (value, None) => value
    (Some(a), Some(b)) => Some(a.min(b))
  }
}

///|
fn minimum_bytes_kind(
  grammar : Grammar,
  kind : RuleKind,
  costs : FixedArray[Int?],
) -> Int? {
  match kind {
    Literal(value) => Some(minimum_string_bytes(value))
    Bytes(_) => Some(1)
    Integer(minimum, maximum) => Some(minimum_integer_width(minimum, maximum))
    Dictionary(values) => {
      let mut result : Int? = None
      for value in values {
        result = min_optional(result, Some(value.length()))
      }
      result
    }
    Sequence(children) => {
      let mut total = 0
      for child in children {
        match costs[child.value()] {
          None => return None
          Some(value) =>
            match checked_add_cost(total, value) {
              None => return None
              Some(next) => total = next
            }
        }
      }
      Some(total)
    }
    Choice(alternatives) => {
      let mut result : Int? = None
      for item in alternatives {
        result = min_optional(result, costs[item.rule.value()])
      }
      result
    }
    Repeat(child, minimum, _) =>
      match costs[child.value()] {
        None => if minimum == 0 { Some(0) } else { None }
        Some(value) => checked_multiply_cost(value, minimum)
      }
    Optional(_, _) => Some(0)
    Reference(name) => costs[grammar.resolved_reference(name).value()]
  }
}

///|
fn minimum_nodes_kind(
  grammar : Grammar,
  kind : RuleKind,
  costs : FixedArray[Int?],
) -> Int? {
  match kind {
    Literal(_) | Bytes(_) | Integer(_, _) | Dictionary(_) => Some(1)
    Sequence(children) => {
      let mut total = 1
      for child in children {
        match costs[child.value()] {
          None => return None
          Some(value) =>
            match checked_add_cost(total, value) {
              None => return None
              Some(next) => total = next
            }
        }
      }
      Some(total)
    }
    Choice(alternatives) => {
      let mut child_cost : Int? = None
      for item in alternatives {
        child_cost = min_optional(child_cost, costs[item.rule.value()])
      }
      match child_cost {
        None => None
        Some(value) => checked_add_cost(1, value)
      }
    }
    Repeat(child, minimum, _) =>
      match costs[child.value()] {
        None => if minimum == 0 { Some(1) } else { None }
        Some(value) =>
          match checked_multiply_cost(value, minimum) {
            None => None
            Some(children) => checked_add_cost(1, children)
          }
      }
    Optional(_, _) => Some(1)
    Reference(name) =>
      match costs[grammar.resolved_reference(name).value()] {
        None => None
        Some(value) => checked_add_cost(1, value)
      }
  }
}

///|
fn reaches_rule(
  grammar : Grammar,
  current : RuleId,
  wanted : RuleId,
  visiting : FixedArray[Bool],
) -> Bool {
  if visiting[current.value()] {
    return false
  }
  visiting[current.value()] = true
  let definition = grammar.rule(current).unwrap()
  for child in grammar.children_of(definition) {
    if child == wanted || reaches_rule(grammar, child, wanted, visiting) {
      visiting[current.value()] = false
      return true
    }
  }
  visiting[current.value()] = false
  false
}

///|
fn compute_fixed_point(
  grammar : Grammar,
  values : FixedArray[Bool],
  evaluate : (Grammar, RuleKind, FixedArray[Bool]) -> Bool,
) -> Unit {
  let mut changed = true
  while changed {
    changed = false
    for definition in grammar.rules() {
      let index = definition.id.value()
      if !values[index] && evaluate(grammar, definition.kind, values) {
        values[index] = true
        changed = true
      }
    }
  }
}

///|
fn compute_cost_fixed_point(
  grammar : Grammar,
  values : FixedArray[Int?],
  evaluate : (Grammar, RuleKind, FixedArray[Int?]) -> Int?,
) -> Unit {
  let mut changed = true
  let mut rounds = 0
  while changed && rounds <= grammar.rule_count() * 2 + 1 {
    changed = false
    rounds += 1
    for definition in grammar.rules() {
      let index = definition.id.value()
      let candidate = evaluate(grammar, definition.kind, values)
      match (values[index], candidate) {
        (None, Some(value)) => {
          values[index] = Some(value)
          changed = true
        }
        (Some(old), Some(value)) if value < old => {
          values[index] = Some(value)
          changed = true
        }
        _ => ()
      }
    }
  }
}

///|
pub fn Grammar::analyze(self : Grammar) -> GrammarAnalysis {
  let count = self.rule_count()
  let reachable = FixedArray::make(count, false)
  let nullable = FixedArray::make(count, false)
  let productive = FixedArray::make(count, false)
  let minimum_bytes : FixedArray[Int?] = FixedArray::make(count, None)
  let minimum_nodes : FixedArray[Int?] = FixedArray::make(count, None)
  mark_reachable(self, self.start(), reachable)
  compute_fixed_point(self, nullable, nullable_kind)
  compute_fixed_point(self, productive, productive_kind)
  compute_cost_fixed_point(self, minimum_bytes, minimum_bytes_kind)
  compute_cost_fixed_point(self, minimum_nodes, minimum_nodes_kind)
  let properties : Array[RuleProperties] = []
  let mut reachable_count = 0
  let mut recursive_count = 0
  let mut nullable_count = 0
  let mut productive_count = 0
  for definition in self.rules() {
    let index = definition.id.value()
    let recursive = reaches_rule(
      self,
      definition.id,
      definition.id,
      FixedArray::make(count, false),
    )
    if reachable[index] {
      reachable_count += 1
    }
    if recursive {
      recursive_count += 1
    }
    if nullable[index] {
      nullable_count += 1
    }
    if productive[index] {
      productive_count += 1
    }
    properties.push({
      rule: definition.id,
      reachable: reachable[index],
      nullable: nullable[index],
      productive: productive[index],
      recursive,
      minimum_bytes: minimum_bytes[index],
      minimum_nodes: minimum_nodes[index],
    })
  }
  {
    rules: properties,
    reachable_count,
    unreachable_count: count - reachable_count,
    recursive_count,
    nullable_count,
    productive_count,
  }
}

///|
pub fn Grammar::validate_productivity(
  self : Grammar,
) -> Result[GrammarAnalysis, AnalysisError] {
  let analysis = self.analyze()
  let start = analysis.properties(self.start()).unwrap()
  if !start.productive {
    return Err(UnproductiveStartRule(self.start().value()))
  }
  for properties in analysis.rules() {
    if properties.reachable && !properties.productive {
      return Err(UnproductiveRule(properties.rule.value()))
    }
  }
  Ok(analysis)
}

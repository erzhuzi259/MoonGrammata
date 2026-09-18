///|
/// Stable integer identity of one grammar rule.
pub(all) struct RuleId(Int) derive(Debug, Eq, Hash)

///|
pub fn RuleId::value(self : RuleId) -> Int {
  self.0
}

///|
pub(all) struct Alternative {
  rule : RuleId
  weight : Int
  label : String
} derive(Debug, Eq)

///|
pub fn alternative(
  rule : RuleId,
  weight? : Int = 1,
  label? : String = "",
) -> Alternative {
  { rule, weight, label }
}

///|
/// Composable rule kinds. References are resolved by name when the grammar is
/// sealed, which allows explicit recursion without mutable placeholder nodes.
pub(all) enum RuleKind {
  Literal(String)
  Bytes(Array[Int])
  Integer(Int, Int)
  Dictionary(Array[String])
  Sequence(Array[RuleId])
  Choice(Array[Alternative])
  Repeat(RuleId, Int, Int)
  Optional(RuleId, Int)
  Reference(String)
} derive(Debug, Eq)

///|
pub(all) struct RuleDefinition {
  id : RuleId
  name : String?
  kind : RuleKind
} derive(Debug, Eq)

///|
pub(all) enum GrammarError {
  EmptyGrammar
  InvalidStartRule(Int)
  InvalidRuleReference(Int, Int)
  MissingNamedRule(String)
  DuplicateRuleName(String)
  EmptyByteSet(Int)
  InvalidByteValue(Int, Int)
  EmptyDictionary(Int)
  EmptyChoice(Int)
  NonPositiveWeight(Int, Int)
  InvalidRepeatBounds(Int, Int, Int)
  InvalidIntegerBounds(Int, Int, Int)
  InvalidOptionalWeight(Int, Int)
} derive(Debug, Eq)

///|
pub struct Grammar {
  rules : Array[RuleDefinition]
  start : RuleId
  names : @hashmap.HashMap[String, RuleId]
}

///|
pub fn Grammar::rule_count(self : Grammar) -> Int {
  self.rules.length()
}

///|
pub fn Grammar::start(self : Grammar) -> RuleId {
  self.start
}

///|
pub fn Grammar::rule(self : Grammar, id : RuleId) -> RuleDefinition? {
  if id.0 < 0 || id.0 >= self.rules.length() {
    None
  } else {
    Some(self.rules[id.0])
  }
}

///|
pub fn Grammar::resolve(self : Grammar, name : String) -> RuleId? {
  self.names.get(name)
}

///|
pub fn Grammar::rules(self : Grammar) -> Array[RuleDefinition] {
  self.rules.copy()
}

///|
pub fn Grammar::name_of(self : Grammar, id : RuleId) -> String? {
  match self.rule(id) {
    Some(definition) => definition.name
    None => None
  }
}

///|
pub struct GrammarBuilder {
  rules : Array[RuleDefinition]
  mut start_rule : RuleId?
}

///|
pub fn GrammarBuilder::new() -> GrammarBuilder {
  { rules: [], start_rule: None }
}

///|
fn GrammarBuilder::append(
  self : GrammarBuilder,
  kind : RuleKind,
  name : String?,
) -> RuleId {
  let id = RuleId(self.rules.length())
  self.rules.push({ id, name, kind })
  id
}

///|
pub fn GrammarBuilder::literal(
  self : GrammarBuilder,
  value : String,
  name? : String,
) -> RuleId {
  self.append(Literal(value), name)
}

///|
pub fn GrammarBuilder::bytes(
  self : GrammarBuilder,
  values : Array[Int],
  name? : String,
) -> RuleId {
  self.append(Bytes(values.copy()), name)
}

///|
pub fn GrammarBuilder::ascii_range(
  self : GrammarBuilder,
  first : Char,
  last : Char,
  name? : String,
) -> RuleId {
  let values : Array[Int] = []
  let low = first.to_int()
  let high = last.to_int()
  if low <= high {
    for value = low; value <= high; value = value + 1 {
      values.push(value)
    }
  }
  self.append(Bytes(values), name)
}

///|
pub fn GrammarBuilder::integer(
  self : GrammarBuilder,
  minimum : Int,
  maximum : Int,
  name? : String,
) -> RuleId {
  self.append(Integer(minimum, maximum), name)
}

///|
pub fn GrammarBuilder::dictionary(
  self : GrammarBuilder,
  values : Array[String],
  name? : String,
) -> RuleId {
  self.append(Dictionary(values.copy()), name)
}

///|
pub fn GrammarBuilder::sequence(
  self : GrammarBuilder,
  children : Array[RuleId],
  name? : String,
) -> RuleId {
  self.append(Sequence(children.copy()), name)
}

///|
pub fn GrammarBuilder::choice(
  self : GrammarBuilder,
  alternatives : Array[Alternative],
  name? : String,
) -> RuleId {
  self.append(Choice(alternatives.copy()), name)
}

///|
pub fn GrammarBuilder::repeat(
  self : GrammarBuilder,
  child : RuleId,
  minimum? : Int = 0,
  maximum? : Int = 8,
  name? : String,
) -> RuleId {
  self.append(Repeat(child, minimum, maximum), name)
}

///|
pub fn GrammarBuilder::optional(
  self : GrammarBuilder,
  child : RuleId,
  present_weight? : Int = 1,
  name? : String,
) -> RuleId {
  self.append(Optional(child, present_weight), name)
}

///|
pub fn GrammarBuilder::reference(
  self : GrammarBuilder,
  target_name : String,
  name? : String,
) -> RuleId {
  self.append(Reference(target_name), name)
}

///|
pub fn GrammarBuilder::set_start(
  self : GrammarBuilder,
  start : RuleId,
) -> GrammarBuilder {
  self.start_rule = Some(start)
  self
}

///|
fn validate_rule_id(
  id : RuleId,
  owner : Int,
  count : Int,
) -> Result[Unit, GrammarError] {
  if id.0 < 0 || id.0 >= count {
    Err(InvalidRuleReference(owner, id.0))
  } else {
    Ok(())
  }
}

///|
fn validate_kind(
  kind : RuleKind,
  owner : Int,
  count : Int,
  names : @hashmap.HashMap[String, RuleId],
) -> Result[Unit, GrammarError] {
  match kind {
    Literal(_) => Ok(())
    Bytes(values) => {
      if values.is_empty() {
        return Err(EmptyByteSet(owner))
      }
      for value in values {
        if value < 0 || value > 255 {
          return Err(InvalidByteValue(owner, value))
        }
      }
      Ok(())
    }
    Integer(minimum, maximum) =>
      if maximum < minimum {
        Err(InvalidIntegerBounds(owner, minimum, maximum))
      } else {
        Ok(())
      }
    Dictionary(values) =>
      if values.is_empty() { Err(EmptyDictionary(owner)) } else { Ok(()) }
    Sequence(children) => {
      for child in children {
        match validate_rule_id(child, owner, count) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      Ok(())
    }
    Choice(alternatives) => {
      if alternatives.is_empty() {
        return Err(EmptyChoice(owner))
      }
      for alternative in alternatives {
        match validate_rule_id(alternative.rule, owner, count) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        if alternative.weight <= 0 {
          return Err(NonPositiveWeight(owner, alternative.weight))
        }
      }
      Ok(())
    }
    Repeat(child, minimum, maximum) => {
      match validate_rule_id(child, owner, count) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      if minimum < 0 || maximum < minimum {
        Err(InvalidRepeatBounds(owner, minimum, maximum))
      } else {
        Ok(())
      }
    }
    Optional(child, weight) => {
      match validate_rule_id(child, owner, count) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
      if weight <= 0 {
        Err(InvalidOptionalWeight(owner, weight))
      } else {
        Ok(())
      }
    }
    Reference(name) =>
      if names.contains(name) { Ok(()) } else { Err(MissingNamedRule(name)) }
  }
}

///|
pub fn GrammarBuilder::build(self : GrammarBuilder) -> Result[Grammar, GrammarError] {
  if self.rules.is_empty() {
    return Err(EmptyGrammar)
  }
  let names : @hashmap.HashMap[String, RuleId] = @hashmap.HashMap([])
  for definition in self.rules {
    match definition.name {
      None => ()
      Some(name) => {
        if names.contains(name) {
          return Err(DuplicateRuleName(name))
        }
        names.set(name, definition.id)
      }
    }
  }
  let start = match self.start_rule {
    Some(value) => value
    None => RuleId(self.rules.length() - 1)
  }
  if start.0 < 0 || start.0 >= self.rules.length() {
    return Err(InvalidStartRule(start.0))
  }
  for definition in self.rules {
    match validate_kind(definition.kind, definition.id.0, self.rules.length(), names) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  Ok({ rules: self.rules.copy(), start, names })
}

///|
pub(all) enum DerivationKind {
  LiteralLeaf
  ByteLeaf
  IntegerLeaf(Int)
  DictionaryLeaf(Int)
  SequenceNode
  ChoiceNode(Int, String)
  RepeatNode(Int)
  OptionalNode(Bool)
  ReferenceNode(String)
} derive(Debug, Eq)

///|
pub(all) struct DerivationTree {
  node_id : Int
  rule : RuleId
  kind : DerivationKind
  payload : Array[Byte]
  children : Array[DerivationTree]
} derive(Debug, Eq)

///|
pub fn DerivationTree::leaf(
  node_id : Int,
  rule : RuleId,
  kind : DerivationKind,
  payload : Array[Byte],
) -> DerivationTree {
  { node_id, rule, kind, payload: payload.copy(), children: [] }
}

///|
pub fn DerivationTree::branch(
  node_id : Int,
  rule : RuleId,
  kind : DerivationKind,
  children : Array[DerivationTree],
) -> DerivationTree {
  { node_id, rule, kind, payload: [], children: children.copy() }
}

///|
pub fn DerivationTree::node_id(self : DerivationTree) -> Int {
  self.node_id
}

///|
pub fn DerivationTree::rule(self : DerivationTree) -> RuleId {
  self.rule
}

///|
pub fn DerivationTree::kind(self : DerivationTree) -> DerivationKind {
  self.kind
}

///|
pub fn DerivationTree::children(self : DerivationTree) -> Array[DerivationTree] {
  self.children.copy()
}

///|
pub fn DerivationTree::payload(self : DerivationTree) -> Array[Byte] {
  self.payload.copy()
}

///|
fn DerivationTree::append_bytes(
  self : DerivationTree,
  output : Array[Byte],
) -> Unit {
  for byte in self.payload {
    output.push(byte)
  }
  for child in self.children {
    child.append_bytes(output)
  }
}

///|
pub fn DerivationTree::render(self : DerivationTree) -> Bytes {
  let output : Array[Byte] = []
  self.append_bytes(output)
  Bytes::from_array(output)
}

///|
pub fn DerivationTree::render_text(
  self : DerivationTree,
) -> Result[String, String] {
  try Ok(@utf8.decode(self.render())) catch {
    _ => Err("derivation output is not valid UTF-8")
  }
}

///|
pub fn DerivationTree::byte_length(self : DerivationTree) -> Int {
  let mut total = self.payload.length()
  for child in self.children {
    total += child.byte_length()
  }
  total
}

///|
pub fn DerivationTree::node_count(self : DerivationTree) -> Int {
  let mut total = 1
  for child in self.children {
    total += child.node_count()
  }
  total
}

///|
pub fn DerivationTree::depth(self : DerivationTree) -> Int {
  let mut deepest = 0
  for child in self.children {
    deepest = deepest.max(child.depth())
  }
  deepest + 1
}

///|
pub fn DerivationTree::descendants(self : DerivationTree) -> Array[DerivationTree] {
  let result : Array[DerivationTree] = [self]
  for child in self.children {
    for descendant in child.descendants() {
      result.push(descendant)
    }
  }
  result
}

///|
pub fn DerivationTree::nodes_for_rule(
  self : DerivationTree,
  rule : RuleId,
) -> Array[DerivationTree] {
  let result : Array[DerivationTree] = []
  for node in self.descendants() {
    if node.rule == rule {
      result.push(node)
    }
  }
  result
}

///|
pub fn DerivationTree::find(self : DerivationTree, node_id : Int) -> DerivationTree? {
  if self.node_id == node_id {
    return Some(self)
  }
  for child in self.children {
    match child.find(node_id) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
pub fn DerivationTree::replace(
  self : DerivationTree,
  node_id : Int,
  replacement : DerivationTree,
) -> DerivationTree {
  if self.node_id == node_id {
    return replacement
  }
  let updated : Array[DerivationTree] = []
  for child in self.children {
    updated.push(child.replace(node_id, replacement))
  }
  { ..self, children: updated }
}

///|
pub fn DerivationTree::without_child(
  self : DerivationTree,
  child_index : Int,
) -> DerivationTree? {
  if child_index < 0 || child_index >= self.children.length() {
    return None
  }
  let updated : Array[DerivationTree] = []
  for index, child in self.children {
    if index != child_index {
      updated.push(child)
    }
  }
  Some({ ..self, children: updated })
}

///|
pub fn DerivationTree::renumber(self : DerivationTree) -> DerivationTree {
  let next = Ref(0)
  fn visit(node : DerivationTree, next : Ref[Int]) -> DerivationTree {
    let id = next.val
    next.val += 1
    let children : Array[DerivationTree] = []
    for child in node.children {
      children.push(visit(child, next))
    }
    { ..node, node_id: id, children }
  }
  visit(self, next)
}

///|
pub fn DerivationTree::structural_summary(self : DerivationTree) -> String {
  "nodes=" +
  self.node_count().to_string() +
  " bytes=" +
  self.byte_length().to_string() +
  " depth=" +
  self.depth().to_string()
}

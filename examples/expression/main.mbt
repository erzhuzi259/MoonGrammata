///|
fn expression_grammar() -> @grammata.Grammar {
  let builder = @grammata.GrammarBuilder::new()
  let digit = builder.ascii_range('0', '9', name="digit")
  let operator_rule = builder.dictionary(["+", "-", "*", "/"], name="operator")
  let open = builder.literal("(")
  let close = builder.literal(")")
  let expression_ref = builder.reference("expression")
  let binary = builder.sequence([
    open,
    expression_ref,
    operator_rule,
    expression_ref,
    close,
  ])
  let expression = builder.choice(
    [
      @grammata.alternative(digit, weight=5, label="digit"),
      @grammata.alternative(binary, weight=3, label="binary"),
    ],
    name="expression",
  )
  builder.set_start(expression).build().unwrap()
}

///|
fn contains_division_by_zero(text : String) -> Bool {
  let data = @utf8.encode(text)
  if data.length() < 2 { return false }
  for index = 0; index + 1 < data.length(); index = index + 1 {
    if data[index].to_int() == '/'.to_int() &&
      data[index + 1].to_int() == '0'.to_int() {
      return true
    }
  }
  false
}

///|
fn expression_features(text : String) -> Array[@grammata.Feature] {
  let data = @utf8.encode(text)
  let mut operators = 0
  let mut maximum_depth = 0
  let mut depth = 0
  for byte in data {
    let value = byte.to_int()
    if value == '('.to_int() {
      depth += 1
      maximum_depth = maximum_depth.max(depth)
    } else if value == ')'.to_int() {
      depth = (depth - 1).max(0)
    } else if value == '+'.to_int() ||
      value == '-'.to_int() ||
      value == '*'.to_int() ||
      value == '/'.to_int() {
      operators += 1
    }
  }
  [
    @grammata.feature("parser-stage", "complete"),
    @grammata.feature("operator-band", (operators / 2).to_string()),
    @grammata.feature("depth", maximum_depth.to_string()),
  ]
}

///|
fn expression_target() -> @grammata.Target {
  @grammata.Target::new("expression-demo", input => {
    let text = @utf8.decode(input) catch {
      _ => return @grammata.rejected("invalid-utf8")
    }
    let features = expression_features(text)
    if contains_division_by_zero(text) {
      @grammata.failed("arithmetic", "division-by-zero", features~)
    } else {
      @grammata.accepted(
        features~,
        result_digest=input.length().to_string(),
      )
    }
  })
}

///|
fn run_expression_demo(executions : Int) -> @grammata.CampaignResult {
  let config : @grammata.CampaignConfig = {
    ..@grammata.CampaignConfig::default(seed=20260918L),
    executions,
    initial_inputs: executions.min(12),
  }
  @grammata.run_campaign(expression_grammar(), expression_target(), config).unwrap()
}

///|
fn main {
  let result = run_expression_demo(1000)
  println(result.markdown_report(title="Expression Grammar Fuzzing Demo"))
  if !result.failures.is_empty() {
    println("First replay artifact:")
    println(result.failures[0].encode_json())
  }
}

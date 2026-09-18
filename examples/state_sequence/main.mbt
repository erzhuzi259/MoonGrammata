///|
fn operation_grammar() -> @grammata.Grammar {
  let builder = @grammata.GrammarBuilder::new()
  let operation = builder.dictionary(["A", "U", "F", "R"], name="operation")
  let sequence = builder.repeat(
    operation,
    minimum=1,
    maximum=20,
    name="operation-sequence",
  )
  builder.set_start(sequence).build().unwrap()
}

///|
enum ResourceState {
  Empty
  Live
  Freed
} derive(Debug, Eq)

///|
fn state_name(state : ResourceState) -> String {
  match state {
    Empty => "empty"
    Live => "live"
    Freed => "freed"
  }
}

///|
fn operation_target() -> @grammata.Target {
  @grammata.Target::new("state-sequence-demo", input => {
    let mut state = Empty
    let features : Array[@grammata.Feature] = [
      @grammata.feature("initial-state", "empty"),
    ]
    for index, byte in input {
      let operation = byte.to_int().unsafe_to_char()
      let before = state_name(state)
      match operation {
        'A' => {
          if state == Live {
            return @grammata.rejected("double-allocate", features~)
          }
          state = Live
        }
        'U' => {
          if state == Freed {
            features.push(@grammata.feature("transition", "freed->use"))
            return @grammata.failed(
              "lifecycle",
              "use-after-free@" + index.to_string(),
              features~,
            )
          }
          if state == Empty {
            return @grammata.rejected("use-before-allocate", features~)
          }
        }
        'F' => {
          if state != Live {
            return @grammata.rejected("free-non-live", features~)
          }
          state = Freed
        }
        'R' => state = Empty
        _ => return @grammata.rejected("unknown-operation", features~)
      }
      features.push(
        @grammata.feature(
          "transition",
          before + "-" + operation.to_string() + "->" + state_name(state),
        ),
      )
    }
    @grammata.accepted(
      features~,
      result_digest=state_name(state),
      cost_class=input.length() / 4,
    )
  })
}

///|
fn run_state_sequence_demo(executions : Int) -> @grammata.CampaignResult {
  let config : @grammata.CampaignConfig = {
    ..@grammata.CampaignConfig::default(seed=40404L),
    executions,
    initial_inputs: executions.min(16),
    crossover_percent: 25,
  }
  @grammata.run_campaign(operation_grammar(), operation_target(), config).unwrap()
}

///|
fn main {
  let result = run_state_sequence_demo(1000)
  println(result.markdown_report(title="State Operation Sequence Fuzzing Demo"))
  if !result.failures.is_empty() {
    println("First replay artifact:")
    println(result.failures[0].encode_json())
  }
}

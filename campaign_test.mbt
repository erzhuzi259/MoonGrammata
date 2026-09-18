///|
test "campaign evolves a replayable novelty corpus" {
  let grammar = mutation_grammar()
  let target = Target::new("campaign-target", input => {
    let text = @utf8.decode(input) catch { _ => "" }
    let features : Array[Feature] = [
      feature("length-band", (input.length() / 4).to_string()),
    ]
    if text.contains("blue") && text.contains("!") {
      failed("semantic", "excited-blue", features~)
    } else {
      accepted(features~)
    }
  })
  let config : CampaignConfig = {
    ..CampaignConfig::default(seed=20260918L),
    executions: 200,
    initial_inputs: 8,
    max_events: 1000,
  }
  let result = run_campaign(grammar, target, config).unwrap()
  assert_eq(result.statistics.completed_executions, 200)
  assert_true(result.statistics.admitted_inputs > 0)
  assert_true(result.statistics.mutated_inputs > 0)
  assert_eq(
    result.statistics.admitted_inputs + result.statistics.rejected_inputs,
    200,
  )
  for replay in result.failures {
    assert_true(target.replay(replay).unwrap().matches())
  }
}

///|
test "campaign is deterministic for the same configuration" {
  let grammar = mutation_grammar()
  let target = Target::new("stable", input => {
    accepted(features=[feature("size", input.length().to_string())])
  })
  let config : CampaignConfig = {
    ..CampaignConfig::default(seed=99L),
    executions: 80,
    initial_inputs: 5,
  }
  let left = run_campaign(grammar, target, config).unwrap()
  let right = run_campaign(grammar, target, config).unwrap()
  assert_eq(left.statistics, right.statistics)
  assert_eq(left.events, right.events)
}

///|
test "campaign validates limits before running" {
  let grammar = mutation_grammar()
  let target = Target::new("x", _ => accepted())
  let config : CampaignConfig = { ..CampaignConfig::default(), executions: 0, }
  assert_true(
    run_campaign(grammar, target, config) is Err(InvalidCampaignConfig(_)),
  )
}

///|
test "config smoke campaign finds bounded port defect" {
  let config : @grammata.CampaignConfig = {
    ..@grammata.CampaignConfig::default(seed=17L),
    executions: 300,
    initial_inputs: 12,
  }
  let result = @grammata.run_campaign(config_grammar(), config_target(), config).unwrap()
  assert_true(result.statistics.unique_failures >= 1)
  assert_true(
    result.failures[0].failure_fingerprint
    .unwrap()
    .value()
    .contains("port-out-of-range"),
  )
}

///|
test "CLI validates numeric arguments" {
  assert_true(parse_positive("COUNT", "0") is Err(_))
  assert_true(parse_positive("COUNT", "abc") is Err(_))
  assert_eq(parse_positive("COUNT", "9"), Ok(9))
  assert_eq(parse_seed("-42"), Ok(-42L))
}

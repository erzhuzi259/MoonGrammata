///|
test "campaign reports are deterministic valid artifacts" {
  let grammar = mutation_grammar()
  let target = Target::new("report", input => {
    accepted(features=[feature("size", input.length().to_string())])
  })
  let config : CampaignConfig = {
    ..CampaignConfig::default(seed=7L),
    executions: 20,
    initial_inputs: 3,
  }
  let result = run_campaign(grammar, target, config).unwrap()
  let markdown = result.markdown_report()
  assert_true(markdown.contains("# MoonGrammata Campaign Report"))
  assert_true(markdown.contains("| Executions | 20 |"))
  let json = result.json_report()
  ignore(@json.parse(json))
  assert_eq(json, result.json_report())
}

///|
test "strategy comparison renders evidence table" {
  let text = compare_strategies([
    {
      name: "random",
      executions: 100,
      unique_features: 4,
      unique_signatures: 3,
      unique_failures: 0,
      corpus_entries: 5,
    },
    {
      name: "structured",
      executions: 100,
      unique_features: 12,
      unique_signatures: 9,
      unique_failures: 2,
      corpus_entries: 16,
    },
  ])
  assert_true(text.contains("| structured | 100 | 12 | 9 | 2 | 16 |"))
}

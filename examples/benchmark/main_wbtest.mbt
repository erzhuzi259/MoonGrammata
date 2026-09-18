///|
test "structured feedback reaches deeper evidence than byte mutation" {
  let executions = 1000
  let baseline = byte_mutation_baseline(executions, 20260918L)
  let result = structured_campaign(executions, 20260918L)
  let structured = result.strategy_evidence("structured-feedback")
  assert_true(structured.unique_features > baseline.unique_features)
  assert_true(structured.unique_signatures > baseline.unique_signatures)
  assert_true(structured.unique_failures >= 1)
  assert_true(
    result.failures[0].failure_fingerprint.unwrap().value().contains("ABCD"),
  )
}

///|
test "benchmark table is deterministic" {
  assert_eq(benchmark_table(200), benchmark_table(200))
}

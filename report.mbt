///|
fn report_percent(numerator : Int, denominator : Int) -> String {
  if denominator <= 0 {
    "0.00%"
  } else {
    let basis_points = numerator * 10000 / denominator
    (basis_points / 100).to_string() +
    "." +
    (basis_points % 100 / 10).to_string() +
    (basis_points % 10).to_string() +
    "%"
  }
}

///|
fn markdown_escape(value : String) -> String {
  value
  .replace(old="\\", new="\\\\")
  .replace(old="|", new="\\|")
  .replace(old="\n", new=" ")
  .replace(old="\r", new=" ")
}

///|
fn event_name(kind : CampaignEventKind) -> String {
  match kind {
    Generated => "generated"
    Mutated(strategy) => "mutated:" + mutation_name(strategy)
    Crossed => "crossed"
    Admitted(_) => "admitted"
    RejectedInput(_) => "rejected"
    FailureFound(_) => "failure"
    MutationSkipped => "mutation-skipped"
  }
}

///|
fn mutation_name(strategy : MutationStrategy) -> String {
  match strategy {
    RegenerateSubtree => "regenerate-subtree"
    DeleteRepeatedChild => "delete-repeated-child"
    ToggleOptional => "toggle-optional"
    ReplaceIntegerBoundary => "replace-integer-boundary"
    ReplaceDictionaryEntry => "replace-dictionary-entry"
    DuplicateRepeatedChild => "duplicate-repeated-child"
  }
}

///|
fn origin_name(origin : CorpusOrigin) -> String {
  match origin {
    Seeded(_) => "seeded"
    Generated(_) => "generated"
    Mutated(_, _) => "mutated"
    Crossed(_, _) => "crossed"
    Reduced(_) => "reduced"
    Replayed => "replayed"
  }
}

///|
pub fn CampaignResult::markdown_report(
  self : CampaignResult,
  title? : String = "MoonGrammata Campaign Report",
) -> String {
  let stats = self.statistics
  let lines : Array[String] = [
    "# " + title,
    "",
    "## Summary",
    "",
    "| Metric | Value |",
    "| --- | ---: |",
    "| Executions | " + stats.completed_executions.to_string() + " |",
    "| Corpus entries | " + stats.final_corpus.entries.to_string() + " |",
    "| Unique feedback signatures | " +
    stats.final_corpus.unique_signatures.to_string() +
    " |",
    "| Unique features | " +
    stats.final_corpus.unique_features.to_string() +
    " |",
    "| Unique failures | " + stats.unique_failures.to_string() + " |",
    "| Admission rate | " +
    report_percent(stats.admitted_inputs, stats.completed_executions) +
    " |",
    "| Mutation inputs | " + stats.mutated_inputs.to_string() + " |",
    "| Crossover inputs | " + stats.crossed_inputs.to_string() + " |",
    "| Generated inputs | " + stats.generated_inputs.to_string() + " |",
    "| Corpus bytes | " + stats.final_corpus.total_bytes.to_string() + " |",
    "",
    "## Retained Corpus",
    "",
    "| ID | Origin | Bytes | Nodes | Features | Failure |",
    "| ---: | --- | ---: | ---: | ---: | --- |",
  ]
  for entry in self.corpus {
    let failure = match entry.failure {
      None => ""
      Some(value) => markdown_escape(value.value())
    }
    lines.push(
      "| " +
      entry.id.to_string() +
      " | " +
      origin_name(entry.origin) +
      " | " +
      entry.tree.byte_length().to_string() +
      " | " +
      entry.tree.node_count().to_string() +
      " | " +
      entry.observation.feature_count().to_string() +
      " | " +
      failure +
      " |",
    )
  }
  lines.push("")
  lines.push("## Failures")
  lines.push("")
  if self.failures.is_empty() {
    lines.push("No unique failures were observed.")
  } else {
    for index, replay in self.failures {
      let fingerprint = replay.failure_fingerprint.unwrap().value()
      lines.push(
        (index + 1).to_string() +
        ". `" +
        markdown_escape(fingerprint) +
        "` — " +
        replay.input.length().to_string() +
        " bytes, seed `" +
        replay.seed.to_string() +
        "`.",
      )
    }
  }
  lines.join("\n") + "\n"
}

///|
fn corpus_entry_json(entry : CorpusEntry) -> String {
  let failure = match entry.failure {
    None => "null"
    Some(value) => replay_json_quote(value.value())
  }
  "{" +
  "\"id\":" +
  entry.id.to_string() +
  ",\"origin\":" +
  replay_json_quote(origin_name(entry.origin)) +
  ",\"bytes\":" +
  entry.tree.byte_length().to_string() +
  ",\"nodes\":" +
  entry.tree.node_count().to_string() +
  ",\"depth\":" +
  entry.tree.depth().to_string() +
  ",\"feature_count\":" +
  entry.observation.feature_count().to_string() +
  ",\"feedback_signature\":" +
  replay_json_quote(entry.signature.value()) +
  ",\"failure_fingerprint\":" +
  failure +
  "}"
}

///|
fn campaign_stats_json(stats : CampaignStatistics) -> String {
  "{" +
  "\"requested_executions\":" +
  stats.requested_executions.to_string() +
  ",\"completed_executions\":" +
  stats.completed_executions.to_string() +
  ",\"generated_inputs\":" +
  stats.generated_inputs.to_string() +
  ",\"mutated_inputs\":" +
  stats.mutated_inputs.to_string() +
  ",\"crossed_inputs\":" +
  stats.crossed_inputs.to_string() +
  ",\"admitted_inputs\":" +
  stats.admitted_inputs.to_string() +
  ",\"rejected_inputs\":" +
  stats.rejected_inputs.to_string() +
  ",\"unique_failures\":" +
  stats.unique_failures.to_string() +
  ",\"mutation_failures\":" +
  stats.mutation_failures.to_string() +
  ",\"final_corpus\":{" +
  "\"entries\":" +
  stats.final_corpus.entries.to_string() +
  ",\"failures\":" +
  stats.final_corpus.failures.to_string() +
  ",\"total_bytes\":" +
  stats.final_corpus.total_bytes.to_string() +
  ",\"unique_features\":" +
  stats.final_corpus.unique_features.to_string() +
  ",\"unique_signatures\":" +
  stats.final_corpus.unique_signatures.to_string() +
  ",\"unique_failures\":" +
  stats.final_corpus.unique_failures.to_string() +
  "}}"
}

///|
fn event_json(event : CampaignEvent) -> String {
  "{" +
  "\"execution\":" +
  event.execution.to_string() +
  ",\"input_bytes\":" +
  event.input_bytes.to_string() +
  ",\"corpus_entries\":" +
  event.corpus_entries.to_string() +
  ",\"kind\":" +
  replay_json_quote(event_name(event.kind)) +
  "}"
}

///|
pub fn CampaignResult::json_report(self : CampaignResult) -> String {
  let corpus : Array[String] = []
  for entry in self.corpus {
    corpus.push(corpus_entry_json(entry))
  }
  let failures : Array[String] = []
  for replay in self.failures {
    failures.push(replay.encode_json())
  }
  let events : Array[String] = []
  for event in self.events {
    events.push(event_json(event))
  }
  "{" +
  "\"schema_version\":1," +
  "\"statistics\":" +
  campaign_stats_json(self.statistics) +
  ",\"corpus\":[" +
  corpus.join(",") +
  "],\"failures\":[" +
  failures.join(",") +
  "],\"events\":[" +
  events.join(",") +
  "]}"
}

///|
pub(all) struct StrategyEvidence {
  name : String
  executions : Int
  unique_features : Int
  unique_signatures : Int
  unique_failures : Int
  corpus_entries : Int
} derive(Debug, Eq)

///|
pub fn CampaignResult::strategy_evidence(
  self : CampaignResult,
  name : String,
) -> StrategyEvidence {
  {
    name,
    executions: self.statistics.completed_executions,
    unique_features: self.statistics.final_corpus.unique_features,
    unique_signatures: self.statistics.final_corpus.unique_signatures,
    unique_failures: self.statistics.unique_failures,
    corpus_entries: self.statistics.final_corpus.entries,
  }
}

///|
pub fn compare_strategies(values : Array[StrategyEvidence]) -> String {
  let lines : Array[String] = [
    "| Strategy | Executions | Features | Signatures | Failures | Corpus |", "| --- | ---: | ---: | ---: | ---: | ---: |",
  ]
  for value in values {
    lines.push(
      "| " +
      markdown_escape(value.name) +
      " | " +
      value.executions.to_string() +
      " | " +
      value.unique_features.to_string() +
      " | " +
      value.unique_signatures.to_string() +
      " | " +
      value.unique_failures.to_string() +
      " | " +
      value.corpus_entries.to_string() +
      " |",
    )
  }
  lines.join("\n") + "\n"
}

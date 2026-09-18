///|
fn benchmark_grammar() -> @grammata.Grammar {
  let builder = @grammata.GrammarBuilder::new()
  let prefix = builder.literal("BEGIN[")
  let command = builder.dictionary(["A", "B", "C", "D"])
  let commands = builder.repeat(command, minimum=1, maximum=12)
  let suffix = builder.literal("]END")
  let document = builder.sequence([prefix, commands, suffix])
  builder.set_start(document).build().unwrap()
}

///|
fn has_marker(input : Bytes, marker : Bytes) -> Bool {
  if marker.is_empty() || marker.length() > input.length() {
    return false
  }
  for start = 0; start + marker.length() <= input.length(); start = start + 1 {
    let mut equal = true
    for offset = 0; offset < marker.length(); offset = offset + 1 {
      if input[start + offset] != marker[offset] {
        equal = false
        break
      }
    }
    if equal {
      return true
    }
  }
  false
}

///|
fn benchmark_target() -> @grammata.Target {
  let prefix = @utf8.encode("BEGIN[")
  let suffix = @utf8.encode("]END")
  let defect = @utf8.encode("ABCD")
  @grammata.Target::new("benchmark-structured-document", input => {
    if input.length() < prefix.length() + suffix.length() + 1 {
      return @grammata.rejected("truncated", features=[
        @grammata.feature("stage", "framing"),
      ])
    }
    for index = 0; index < prefix.length(); index = index + 1 {
      if input[index] != prefix[index] {
        return @grammata.rejected("bad-prefix", features=[
          @grammata.feature("stage", "framing"),
        ])
      }
    }
    let suffix_start = input.length() - suffix.length()
    for index = 0; index < suffix.length(); index = index + 1 {
      if input[suffix_start + index] != suffix[index] {
        return @grammata.rejected("bad-suffix", features=[
          @grammata.feature("stage", "framing"),
        ])
      }
    }
    let features : Array[@grammata.Feature] = [
      @grammata.feature("stage", "commands"),
      @grammata.feature(
        "command-count",
        (suffix_start - prefix.length()).to_string(),
      ),
    ]
    let seen : @hashmap.HashMap[Int, Unit] = @hashmap.HashMap([])
    for index = prefix.length(); index < suffix_start; index = index + 1 {
      let value = input[index].to_int()
      if value < 'A'.to_int() || value > 'D'.to_int() {
        return @grammata.rejected("unknown-command", features~)
      }
      seen.set(value, ())
    }
    for value in seen.keys() {
      features.push(
        @grammata.feature("command-kind", value.unsafe_to_char().to_string()),
      )
    }
    if has_marker(input, defect) {
      @grammata.failed("semantic", "ABCD-ordering-defect", features~)
    } else {
      @grammata.accepted(features~, result_digest=seen.length().to_string())
    }
  })
}

///|
fn byte_mutation_baseline(
  executions : Int,
  seed : Int64,
) -> @grammata.StrategyEvidence {
  let random = @grammata.Random::new(seed)
  let target = benchmark_target()
  let registry = @grammata.FeatureRegistry::new()
  let base = @utf8.encode("BEGIN[A]END")
  let failures : @hashmap.HashMap[@grammata.FailureFingerprint, Unit] = @hashmap.HashMap([],
  )
  for index = 0; index < executions; index = index + 1 {
    let values : Array[Byte] = []
    for byte in base {
      values.push(byte)
    }
    let position = random.below(values.length())
    values[position] = random.below(256).to_byte()
    let observation = target.run(Bytes::from_array(values))
    ignore(registry.observe(observation))
    match observation.failure_fingerprint() {
      None => ()
      Some(value) => failures.set(value, ())
    }
  }
  {
    name: "single-byte-mutation",
    executions,
    unique_features: registry.unique_feature_count(),
    unique_signatures: registry.unique_signature_count(),
    unique_failures: failures.length(),
    corpus_entries: 0,
  }
}

///|
fn structured_campaign(
  executions : Int,
  seed : Int64,
) -> @grammata.CampaignResult {
  let config : @grammata.CampaignConfig = {
    ..@grammata.CampaignConfig::default(seed~),
    executions,
    initial_inputs: executions.min(16),
  }
  @grammata.run_campaign(benchmark_grammar(), benchmark_target(), config).unwrap()
}

///|
fn benchmark_table(executions : Int) -> String {
  let baseline = byte_mutation_baseline(executions, 20260918L)
  let structured = structured_campaign(executions, 20260918L).strategy_evidence(
    "structured-feedback",
  )
  @grammata.compare_strategies([baseline, structured])
}

///|
fn main {
  println("# Logical strategy comparison")
  println("")
  println(benchmark_table(2000))
  println(
    "Counts are deterministic logical observations; they are not wall-clock throughput.",
  )
}

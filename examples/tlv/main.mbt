///|
fn tlv_grammar() -> @grammata.Grammar {
  let builder = @grammata.GrammarBuilder::new()
  let tag = builder.bytes([1, 2, 3], name="tag")
  let length = builder.bytes([0, 1, 2, 3, 4], name="length")
  let octet = builder.bytes([0, 1, 2, 127, 128, 254, 255], name="octet")
  let payload = builder.repeat(octet, minimum=0, maximum=4, name="payload")
  let frame = builder.sequence([tag, length, payload], name="frame")
  builder.set_start(frame).build().unwrap()
}

///|
fn tlv_target() -> @grammata.Target {
  @grammata.Target::new("tlv-demo", input => {
    if input.length() < 2 {
      return @grammata.rejected("truncated-header", features=[
        @grammata.feature("decoder-stage", "header"),
      ])
    }
    let tag = input[0].to_int()
    let declared = input[1].to_int()
    let actual = input.length() - 2
    let relation = if declared == actual { "matching" } else { "mismatching" }
    let features = [
      @grammata.feature("decoder-stage", "payload"),
      @grammata.feature("tag", tag.to_string()),
      @grammata.feature("length-relation", relation),
      @grammata.feature("payload-band", (actual / 2).to_string()),
    ]
    if declared != actual {
      @grammata.rejected("length-mismatch", features~)
    } else if tag == 3 &&
      actual > 0 &&
      input[input.length() - 1].to_int() == 255 {
      @grammata.failed("decoder", "reserved-tail-byte", features~)
    } else {
      @grammata.accepted(
        features~,
        result_digest=tag.to_string() + ":" + actual.to_string(),
      )
    }
  })
}

///|
fn run_tlv_demo(executions : Int) -> @grammata.CampaignResult {
  let config : @grammata.CampaignConfig = {
    ..@grammata.CampaignConfig::default(seed=7252L),
    executions,
    initial_inputs: executions.min(16),
    crossover_percent: 20,
  }
  @grammata.run_campaign(tlv_grammar(), tlv_target(), config).unwrap()
}

///|
fn main {
  let result = run_tlv_demo(1000)
  println(result.markdown_report(title="Binary TLV Fuzzing Demo"))
  if !result.failures.is_empty() {
    println("First replay artifact:")
    println(result.failures[0].encode_json())
  }
}

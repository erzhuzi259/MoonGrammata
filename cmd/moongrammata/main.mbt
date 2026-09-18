///|
extern "C" fn process_exit(code : Int) = "exit"

///|
fn usage() -> String {
  (
    #|MoonGrammata 0.1.0
    #|
    #|Usage:
    #|  moongrammata sample   COUNT SEED
    #|  moongrammata campaign EXECUTIONS SEED
    #|  moongrammata replay   REPLAY_JSON
    #|
    #|The CLI uses a built-in structured configuration grammar as a runnable
    #|smoke target. Library users compose their own Grammar and Target values.
    #|
  )
}

///|
fn config_grammar() -> @grammata.Grammar {
  let builder = @grammata.GrammarBuilder::new()
  let key = builder.dictionary(["host", "port", "mode", "retries"])
  let equals = builder.literal("=")
  let value = builder.dictionary([
    "localhost", "production", "0", "1", "3", "443", "65535", "65536",
  ])
  let semicolon = builder.literal(";")
  let assignment = builder.sequence([key, equals, value, semicolon])
  let document = builder.repeat(assignment, minimum=1, maximum=12)
  builder.set_start(document).build().unwrap()
}

///|
fn count_byte(input : Bytes, wanted : Int) -> Int {
  let mut count = 0
  for byte in input {
    if byte.to_int() == wanted {
      count += 1
    }
  }
  count
}

///|
fn config_target() -> @grammata.Target {
  @grammata.Target::new("config-demo", input => {
    let text = @utf8.decode(input) catch {
      _ => return @grammata.rejected("invalid-utf8")
    }
    let assignments = count_byte(input, ';'.to_int())
    let features = [
      @grammata.feature("parser-stage", "document"),
      @grammata.feature("assignment-band", (assignments / 2).to_string()),
    ]
    if text.contains("port=65536;") {
      @grammata.failed("configuration", "port-out-of-range", features~)
    } else {
      @grammata.accepted(
        features~,
        result_digest=assignments.to_string(),
        cost_class=assignments / 4,
      )
    }
  })
}

///|
fn parse_positive(name : String, text : String) -> Result[Int, String] {
  let value = @string.parse_int(text) catch {
    _ => return Err(name + " must be an integer")
  }
  if value <= 0 {
    Err(name + " must be positive")
  } else {
    Ok(value)
  }
}

///|
fn parse_seed(text : String) -> Result[Int64, String] {
  let value = @string.parse_int64(text) catch {
    _ => return Err("SEED must be a signed 64-bit integer")
  }
  Ok(value)
}

///|
fn sample_command(
  count_text : String,
  seed_text : String,
) -> Result[Unit, String] {
  let count = match parse_positive("COUNT", count_text) {
    Err(error) => return Err(error)
    Ok(value) => value.min(10000)
  }
  let seed = match parse_seed(seed_text) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let grammar = config_grammar()
  for index = 0; index < count; index = index + 1 {
    let tree = grammar.generate(seed=seed + Int64::from_int(index)).unwrap()
    println(tree.render_text().unwrap())
  }
  Ok(())
}

///|
fn campaign_command(
  executions_text : String,
  seed_text : String,
) -> Result[Unit, String] {
  let executions = match parse_positive("EXECUTIONS", executions_text) {
    Err(error) => return Err(error)
    Ok(value) => value.min(1000000)
  }
  let seed = match parse_seed(seed_text) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let config : @grammata.CampaignConfig = {
    ..@grammata.CampaignConfig::default(seed~),
    executions,
    initial_inputs: executions.min(16),
  }
  let result = @grammata.run_campaign(config_grammar(), config_target(), config).unwrap()
  println(result.markdown_report(title="Configuration Grammar Campaign"))
  if !result.failures.is_empty() {
    println("Replay artifact:")
    println(result.failures[0].encode_json())
  }
  Ok(())
}

///|
fn replay_command(text : String) -> Result[Unit, String] {
  let record = match @grammata.ReplayRecord::decode_json(text) {
    Err(_) => return Err("REPLAY_JSON is not a valid MoonGrammata replay")
    Ok(value) => value
  }
  let outcome = match config_target().replay(record) {
    Err(_) => return Err("replay target identity does not match config-demo")
    Ok(value) => value
  }
  println(if outcome.matches() { "MATCH" } else { "DIVERGED" })
  if outcome.matches() {
    Ok(())
  } else {
    Err("replay observation diverged")
  }
}

///|
fn dispatch(args : Array[String]) -> Result[Unit, String] {
  if args.length() < 2 {
    return Err(usage())
  }
  match args[1] {
    "sample" if args.length() == 4 => sample_command(args[2], args[3])
    "campaign" if args.length() == 4 => campaign_command(args[2], args[3])
    "replay" if args.length() == 3 => replay_command(args[2])
    "help" | "--help" | "-h" => {
      println(usage())
      Ok(())
    }
    _ => Err(usage())
  }
}

///|
fn main {
  match dispatch(@env.args()) {
    Ok(_) => ()
    Err(error) => {
      println(error)
      process_exit(2)
    }
  }
}

///|
pub let replay_schema_version : Int = 1

///|
pub(all) struct ReplayRecord {
  schema_version : Int
  target_name : String
  seed : Int64
  input : Bytes
  feedback_signature : FeedbackSignature
  failure_fingerprint : FailureFingerprint?
  result_digest : String?
  generation_budget : GenerationBudget
} derive(Debug, Eq)

///|
pub fn ReplayRecord::new(
  target_name~ : String,
  seed~ : Int64,
  input~ : Bytes,
  observation~ : TargetObservation,
  generation_budget? : GenerationBudget = GenerationBudget::default(),
) -> ReplayRecord {
  {
    schema_version: replay_schema_version,
    target_name,
    seed,
    input,
    feedback_signature: observation.signature(),
    failure_fingerprint: observation.failure_fingerprint(),
    result_digest: observation.result_digest,
    generation_budget,
  }
}

///|
pub(all) enum ReplayError {
  InvalidJson
  MissingField(String)
  InvalidField(String)
  UnsupportedReplayVersion(Int)
  ArtifactLimitExceeded(Int)
  InputLimitExceeded(Int)
  InvalidHexInput(Int)
  TargetNameMismatch(String, String)
} derive(Debug, Eq)

///|
pub(all) struct ReplayOutcome {
  observation : TargetObservation
  feedback_matches : Bool
  failure_matches : Bool
  result_matches : Bool
} derive(Debug, Eq)

///|
pub fn ReplayOutcome::matches(self : ReplayOutcome) -> Bool {
  self.feedback_matches && self.failure_matches && self.result_matches
}

///|
fn replay_json_quote(value : String) -> String {
  Json::string(value).stringify()
}

///|
fn replay_hex(input : Bytes) -> String {
  let builder = StringBuilder(size_hint=input.length() * 2)
  for byte in input {
    let value = byte.to_int()
    builder.write_char(hex_digit(value / 16))
    builder.write_char(hex_digit(value % 16))
  }
  builder.to_string()
}

///|
fn optional_json_string(value : String?) -> String {
  match value {
    None => "null"
    Some(text) => replay_json_quote(text)
  }
}

///|
pub fn ReplayRecord::encode_json(self : ReplayRecord) -> String {
  let failure = match self.failure_fingerprint {
    None => None
    Some(value) => Some(value.value())
  }
  "{" +
  "\"schema_version\":" +
  self.schema_version.to_string() +
  ",\"target_name\":" +
  replay_json_quote(self.target_name) +
  ",\"seed\":" +
  replay_json_quote(self.seed.to_string()) +
  ",\"input_hex\":" +
  replay_json_quote(replay_hex(self.input)) +
  ",\"feedback_signature\":" +
  replay_json_quote(self.feedback_signature.value()) +
  ",\"failure_fingerprint\":" +
  optional_json_string(failure) +
  ",\"result_digest\":" +
  optional_json_string(self.result_digest) +
  ",\"generation_budget\":{" +
  "\"max_depth\":" +
  self.generation_budget.max_depth.to_string() +
  ",\"max_nodes\":" +
  self.generation_budget.max_nodes.to_string() +
  ",\"max_bytes\":" +
  self.generation_budget.max_bytes.to_string() +
  ",\"max_repeat\":" +
  self.generation_budget.max_repeat.to_string() +
  "}}"
}

///|
fn replay_object(
  value : Json,
  name : String,
) -> Result[Map[String, Json], ReplayError] {
  match value {
    Object(fields) => Ok(fields)
    _ => Err(InvalidField(name + " must be an object"))
  }
}

///|
fn replay_required(
  fields : Map[String, Json],
  name : String,
) -> Result[Json, ReplayError] {
  match fields.get(name) {
    None => Err(MissingField(name))
    Some(value) => Ok(value)
  }
}

///|
fn replay_int(
  fields : Map[String, Json],
  name : String,
) -> Result[Int, ReplayError] {
  let value = match replay_required(fields, name) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let decoded : Int = @json.from_json(value) catch {
    _ => return Err(InvalidField(name + " must be an integer"))
  }
  Ok(decoded)
}

///|
fn replay_string(
  fields : Map[String, Json],
  name : String,
) -> Result[String, ReplayError] {
  match replay_required(fields, name) {
    Err(error) => Err(error)
    Ok(String(value)) => Ok(value)
    Ok(_) => Err(InvalidField(name + " must be a string"))
  }
}

///|
fn replay_optional_string(
  fields : Map[String, Json],
  name : String,
) -> Result[String?, ReplayError] {
  match replay_required(fields, name) {
    Err(error) => Err(error)
    Ok(Null) => Ok(None)
    Ok(String(value)) => Ok(Some(value))
    Ok(_) => Err(InvalidField(name + " must be a string or null"))
  }
}

///|
fn hex_value(byte : Byte) -> Int? {
  let value = byte.to_int()
  if value >= '0'.to_int() && value <= '9'.to_int() {
    Some(value - '0'.to_int())
  } else if value >= 'a'.to_int() && value <= 'f'.to_int() {
    Some(value - 'a'.to_int() + 10)
  } else if value >= 'A'.to_int() && value <= 'F'.to_int() {
    Some(value - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn decode_replay_hex(
  value : String,
  maximum : Int,
) -> Result[Bytes, ReplayError] {
  let encoded = @utf8.encode(value)
  if encoded.length() % 2 != 0 {
    return Err(InvalidHexInput(encoded.length()))
  }
  if encoded.length() / 2 > maximum {
    return Err(InputLimitExceeded(maximum))
  }
  let output : Array[Byte] = []
  let mut index = 0
  while index < encoded.length() {
    let high = match hex_value(encoded[index]) {
      None => return Err(InvalidHexInput(index))
      Some(value) => value
    }
    let low = match hex_value(encoded[index + 1]) {
      None => return Err(InvalidHexInput(index + 1))
      Some(value) => value
    }
    output.push((high * 16 + low).to_byte())
    index += 2
  }
  Ok(Bytes::from_array(output))
}

///|
fn parse_seed(value : String) -> Result[Int64, ReplayError] {
  let parsed : Int64 = @string.parse_int64(value) catch {
    _ => return Err(InvalidField("seed must be a signed 64-bit integer"))
  }
  Ok(parsed)
}

///|
pub fn ReplayRecord::decode_json(
  text : String,
  max_input_bytes? : Int = 1024 * 1024,
  max_artifact_bytes? : Int = 4 * 1024 * 1024,
) -> Result[ReplayRecord, ReplayError] {
  if @utf8.encode(text).length() > max_artifact_bytes.max(0) {
    return Err(ArtifactLimitExceeded(max_artifact_bytes.max(0)))
  }
  let parsed = @json.parse(text) catch { _ => return Err(InvalidJson) }
  let fields = match replay_object(parsed, "replay root") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let version = match replay_int(fields, "schema_version") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  if version != replay_schema_version {
    return Err(UnsupportedReplayVersion(version))
  }
  let target_name = match replay_string(fields, "target_name") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let seed_text = match replay_string(fields, "seed") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let seed = match parse_seed(seed_text) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let input_hex = match replay_string(fields, "input_hex") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let input = match decode_replay_hex(input_hex, max_input_bytes.max(0)) {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let feedback = match replay_string(fields, "feedback_signature") {
    Err(error) => return Err(error)
    Ok(value) => FeedbackSignature(value)
  }
  let failure = match replay_optional_string(fields, "failure_fingerprint") {
    Err(error) => return Err(error)
    Ok(None) => None
    Ok(Some(value)) => Some(FailureFingerprint(value))
  }
  let result_digest = match replay_optional_string(fields, "result_digest") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let budget_json = match replay_required(fields, "generation_budget") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let budget_fields = match replay_object(budget_json, "generation_budget") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let max_depth = match replay_int(budget_fields, "max_depth") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let max_nodes = match replay_int(budget_fields, "max_nodes") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let max_bytes = match replay_int(budget_fields, "max_bytes") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let max_repeat = match replay_int(budget_fields, "max_repeat") {
    Err(error) => return Err(error)
    Ok(value) => value
  }
  let generation_budget = { max_depth, max_nodes, max_bytes, max_repeat, }
  match generation_budget.validate() {
    Err(_) => return Err(InvalidField("generation_budget is invalid"))
    Ok(_) => ()
  }
  Ok({
    schema_version: version,
    target_name,
    seed,
    input,
    feedback_signature: feedback,
    failure_fingerprint: failure,
    result_digest,
    generation_budget,
  })
}

///|
pub fn Target::replay(
  self : Target,
  record : ReplayRecord,
) -> Result[ReplayOutcome, ReplayError] {
  if self.name() != record.target_name {
    return Err(TargetNameMismatch(record.target_name, self.name()))
  }
  let observation = self.run(record.input)
  Ok({
    feedback_matches: observation.signature() == record.feedback_signature,
    failure_matches: observation.failure_fingerprint() ==
    record.failure_fingerprint,
    result_matches: observation.result_digest == record.result_digest,
    observation,
  })
}

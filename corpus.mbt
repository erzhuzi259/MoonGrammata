///|
pub(all) enum CorpusOrigin {
  Seeded(Int64)
  Generated(Int64)
  Mutated(Int, String)
  Crossed(Int, Int)
  Reduced(Int)
  Replayed
} derive(Debug, Eq)

///|
pub(all) struct CorpusEntry {
  id : Int
  tree : DerivationTree
  observation : TargetObservation
  signature : FeedbackSignature
  failure : FailureFingerprint?
  origin : CorpusOrigin
  input_key : String
  mut executions : Int
  mut selections : Int
  mut discoveries : Int
  mut energy : Int
} derive(Debug, Eq)

///|
pub fn CorpusEntry::tree(self : CorpusEntry) -> DerivationTree {
  self.tree
}

///|
pub fn CorpusEntry::observation(self : CorpusEntry) -> TargetObservation {
  self.observation
}

///|
pub fn CorpusEntry::is_failure(self : CorpusEntry) -> Bool {
  self.failure is Some(_)
}

///|
pub fn CorpusEntry::record_selection(self : CorpusEntry) -> Unit {
  self.selections += 1
}

///|
pub fn CorpusEntry::record_execution(self : CorpusEntry) -> Unit {
  self.executions += 1
}

///|
pub fn CorpusEntry::record_discovery(self : CorpusEntry) -> Unit {
  self.discoveries += 1
}

///|
pub fn CorpusEntry::set_energy(self : CorpusEntry, value : Int) -> Unit {
  self.energy = value.max(1)
}

///|
pub(all) struct CorpusLimits {
  max_entries : Int
  max_total_bytes : Int
  max_failures : Int
  max_input_bytes : Int
} derive(Debug, Eq)

///|
pub fn CorpusLimits::default() -> CorpusLimits {
  {
    max_entries: 4096,
    max_total_bytes: 64 * 1024 * 1024,
    max_failures: 1024,
    max_input_bytes: 1024 * 1024,
  }
}

///|
pub(all) enum AdmissionReason {
  FirstInput
  NovelFeature(Int)
  NovelSignature
  NewFailure(FailureFingerprint)
} derive(Debug, Eq)

///|
pub(all) enum RejectionReason {
  DuplicateInput
  NoNovelty
  EntryCapacity
  ByteCapacity
  FailureCapacity
  InputTooLarge(Int)
} derive(Debug, Eq)

///|
pub(all) enum AdmissionDecision {
  Admitted(Int, AdmissionReason)
  Rejected(RejectionReason)
} derive(Debug, Eq)

///|
pub(all) struct CorpusStatistics {
  entries : Int
  failures : Int
  total_bytes : Int
  unique_inputs : Int
  unique_features : Int
  unique_signatures : Int
  unique_failures : Int
} derive(Debug, Eq)

///|
pub struct Corpus {
  entries : Array[CorpusEntry]
  limits : CorpusLimits
  registry : FeatureRegistry
  input_ids : @hashmap.HashMap[String, Int]
  failure_ids : @hashmap.HashMap[FailureFingerprint, Int]
  mut total_bytes : Int
  mut failure_count : Int
}

///|
pub fn Corpus::new(limits? : CorpusLimits = CorpusLimits::default()) -> Corpus {
  {
    entries: [],
    limits,
    registry: FeatureRegistry::new(),
    input_ids: @hashmap.HashMap([]),
    failure_ids: @hashmap.HashMap([]),
    total_bytes: 0,
    failure_count: 0,
  }
}

///|
fn hex_digit(value : Int) -> Char {
  if value < 10 {
    ('0'.to_int() + value).unsafe_to_char()
  } else {
    ('a'.to_int() + value - 10).unsafe_to_char()
  }
}

///|
fn bytes_key(input : Bytes) -> String {
  let builder = StringBuilder(size_hint=input.length() * 2 + 16)
  builder.write_string(input.length().to_string())
  builder.write_char(':')
  for byte in input {
    let value = byte.to_int()
    builder.write_char(hex_digit(value / 16))
    builder.write_char(hex_digit(value % 16))
  }
  builder.to_string()
}

///|
pub fn Corpus::length(self : Corpus) -> Int {
  self.entries.length()
}

///|
pub fn Corpus::is_empty(self : Corpus) -> Bool {
  self.entries.is_empty()
}

///|
pub fn Corpus::entry(self : Corpus, id : Int) -> CorpusEntry? {
  if id < 0 || id >= self.entries.length() {
    None
  } else {
    Some(self.entries[id])
  }
}

///|
pub fn Corpus::entries(self : Corpus) -> Array[CorpusEntry] {
  self.entries.copy()
}

///|
pub fn Corpus::find_input(self : Corpus, input : Bytes) -> CorpusEntry? {
  match self.input_ids.get(bytes_key(input)) {
    None => None
    Some(id) => self.entry(id)
  }
}

///|
pub fn Corpus::failure_entry(
  self : Corpus,
  fingerprint : FailureFingerprint,
) -> CorpusEntry? {
  match self.failure_ids.get(fingerprint) {
    None => None
    Some(id) => self.entry(id)
  }
}

///|
fn Corpus::capacity_rejection(
  self : Corpus,
  input_bytes : Int,
  is_failure : Bool,
) -> RejectionReason? {
  if input_bytes > self.limits.max_input_bytes {
    Some(InputTooLarge(input_bytes))
  } else if self.entries.length() >= self.limits.max_entries {
    Some(EntryCapacity)
  } else if self.total_bytes > self.limits.max_total_bytes - input_bytes {
    Some(ByteCapacity)
  } else if is_failure && self.failure_count >= self.limits.max_failures {
    Some(FailureCapacity)
  } else {
    None
  }
}

///|
pub fn Corpus::consider(
  self : Corpus,
  tree : DerivationTree,
  observation : TargetObservation,
  origin : CorpusOrigin,
) -> AdmissionDecision {
  let input = tree.render()
  let key = bytes_key(input)
  if self.input_ids.contains(key) {
    return Rejected(DuplicateInput)
  }
  let fingerprint = observation.failure_fingerprint()
  match self.capacity_rejection(input.length(), fingerprint is Some(_)) {
    Some(reason) => return Rejected(reason)
    None => ()
  }
  let already_had_signature = self.registry.signature_frequency(
    observation.signature(),
  ) > 0
  let feature_delta = self.registry.observe(observation)
  let failure_is_novel = match fingerprint {
    None => false
    Some(value) => !self.failure_ids.contains(value)
  }
  let reason = if self.entries.is_empty() {
    FirstInput
  } else if failure_is_novel {
    NewFailure(fingerprint.unwrap())
  } else if !feature_delta.novel_features.is_empty() {
    NovelFeature(feature_delta.novel_features.length())
  } else if !already_had_signature {
    NovelSignature
  } else {
    return Rejected(NoNovelty)
  }
  let id = self.entries.length()
  let entry : CorpusEntry = {
    id,
    tree,
    observation,
    signature: feature_delta.signature,
    failure: fingerprint,
    origin,
    input_key: key,
    executions: 0,
    selections: 0,
    discoveries: 0,
    energy: 1,
  }
  self.entries.push(entry)
  self.input_ids.set(key, id)
  self.total_bytes += input.length()
  match fingerprint {
    None => ()
    Some(value) => {
      self.failure_count += 1
      if failure_is_novel {
        self.failure_ids.set(value, id)
      }
    }
  }
  Admitted(id, reason)
}

///|
pub fn Corpus::statistics(self : Corpus) -> CorpusStatistics {
  {
    entries: self.entries.length(),
    failures: self.failure_count,
    total_bytes: self.total_bytes,
    unique_inputs: self.input_ids.length(),
    unique_features: self.registry.unique_feature_count(),
    unique_signatures: self.registry.unique_signature_count(),
    unique_failures: self.failure_ids.length(),
  }
}

///|
pub fn Corpus::feature_frequency(self : Corpus, value : Feature) -> Int {
  self.registry.feature_frequency(value)
}

///|
pub fn Corpus::signature_frequency(
  self : Corpus,
  value : FeedbackSignature,
) -> Int {
  self.registry.signature_frequency(value)
}

///|
pub fn Corpus::smallest_failure(
  self : Corpus,
  fingerprint : FailureFingerprint,
) -> CorpusEntry? {
  let mut result : CorpusEntry? = None
  for entry in self.entries {
    if entry.failure == Some(fingerprint) {
      match result {
        None => result = Some(entry)
        Some(previous) =>
          if entry.tree.byte_length() < previous.tree.byte_length() {
            result = Some(entry)
          }
      }
    }
  }
  result
}

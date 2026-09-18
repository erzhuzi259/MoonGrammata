///|
pub(all) struct Feature {
  domain : String
  value : String
} derive(Debug, Eq, Hash)

///|
pub fn feature(domain : String, value : String) -> Feature {
  { domain, value, }
}

///|
pub fn Feature::canonical(self : Feature) -> String {
  self.domain.length().to_string() +
  ":" +
  self.domain +
  "=" +
  self.value.length().to_string() +
  ":" +
  self.value
}

///|
pub(all) enum ExecutionDisposition {
  Accepted
  Rejected(String)
  Failed(String, String)
} derive(Debug, Eq)

///|
pub(all) struct TargetObservation {
  disposition : ExecutionDisposition
  features : Array[Feature]
  result_digest : String?
  cost_class : Int
} derive(Debug, Eq)

///|
pub fn observation(
  disposition : ExecutionDisposition,
  features? : Array[Feature] = [],
  result_digest? : String,
  cost_class? : Int = 0,
) -> TargetObservation {
  {
    disposition,
    features: features.copy(),
    result_digest,
    cost_class: cost_class.max(0),
  }
}

///|
pub fn accepted(
  features? : Array[Feature] = [],
  result_digest? : String,
  cost_class? : Int = 0,
) -> TargetObservation {
  {
    disposition: Accepted,
    features: features.copy(),
    result_digest,
    cost_class: cost_class.max(0),
  }
}

///|
pub fn rejected(
  reason : String,
  features? : Array[Feature] = [],
) -> TargetObservation {
  {
    disposition: Rejected(reason),
    features: features.copy(),
    result_digest: None,
    cost_class: 0,
  }
}

///|
pub fn failed(
  kind : String,
  detail : String,
  features? : Array[Feature] = [],
) -> TargetObservation {
  {
    disposition: Failed(kind, detail),
    features: features.copy(),
    result_digest: None,
    cost_class: 0,
  }
}

///|
fn compare_string(left : String, right : String) -> Int {
  let left_bytes = @utf8.encode(left)
  let right_bytes = @utf8.encode(right)
  let common = left_bytes.length().min(right_bytes.length())
  for index = 0; index < common; index = index + 1 {
    let a = left_bytes[index].to_int()
    let b = right_bytes[index].to_int()
    if a < b {
      return -1
    }
    if a > b {
      return 1
    }
  }
  if left_bytes.length() < right_bytes.length() {
    -1
  } else if left_bytes.length() > right_bytes.length() {
    1
  } else {
    0
  }
}

///|
fn sorted_unique_features(values : Array[Feature]) -> Array[Feature] {
  let result : Array[Feature] = []
  for value in values {
    let key = value.canonical()
    let mut inserted = false
    let mut duplicate = false
    for index = 0; index < result.length(); index = index + 1 {
      let comparison = compare_string(key, result[index].canonical())
      if comparison == 0 {
        duplicate = true
        inserted = true
        break
      }
      if comparison < 0 {
        result.insert(index, value)
        inserted = true
        break
      }
    }
    if !inserted && !duplicate {
      result.push(value)
    }
  }
  result
}

///|
pub(all) struct FeedbackSignature(String) derive(Debug, Eq, Hash)

///|
pub fn FeedbackSignature::value(self : FeedbackSignature) -> String {
  self.0
}

///|
pub fn feedback_signature(features : Array[Feature]) -> FeedbackSignature {
  let parts : Array[String] = []
  for value in sorted_unique_features(features) {
    parts.push(value.canonical())
  }
  FeedbackSignature(parts.join("|"))
}

///|
pub fn TargetObservation::signature(
  self : TargetObservation,
) -> FeedbackSignature {
  feedback_signature(self.features)
}

///|
pub(all) struct FailureFingerprint(String) derive(Debug, Eq, Hash)

///|
pub fn FailureFingerprint::value(self : FailureFingerprint) -> String {
  self.0
}

///|
fn fingerprint_field(name : String, value : String) -> String {
  name + "=" + value.length().to_string() + ":" + value + ";"
}

///|
pub fn TargetObservation::failure_fingerprint(
  self : TargetObservation,
) -> FailureFingerprint? {
  match self.disposition {
    Accepted | Rejected(_) => None
    Failed(kind, detail) =>
      Some(
        FailureFingerprint(
          fingerprint_field("kind", kind) + fingerprint_field("detail", detail),
        ),
      )
  }
}

///|
pub fn TargetObservation::is_failure(self : TargetObservation) -> Bool {
  self.disposition is Failed(_, _)
}

///|
pub fn TargetObservation::feature_count(self : TargetObservation) -> Int {
  sorted_unique_features(self.features).length()
}

///|
pub fn TargetObservation::canonical_features(
  self : TargetObservation,
) -> Array[Feature] {
  sorted_unique_features(self.features)
}

///|
pub struct Target {
  name : String
  evaluate : (Bytes) -> TargetObservation
}

///|
pub fn Target::new(
  name : String,
  evaluate : (Bytes) -> TargetObservation,
) -> Target {
  { name, evaluate, }
}

///|
pub fn Target::name(self : Target) -> String {
  self.name
}

///|
pub fn Target::run(self : Target, input : Bytes) -> TargetObservation {
  (self.evaluate)(input)
}

///|
pub(all) struct FeatureDelta {
  signature : FeedbackSignature
  novel_features : Array[Feature]
  all_features : Array[Feature]
} derive(Debug, Eq)

///|
pub struct FeatureRegistry {
  seen : @hashmap.HashMap[Feature, Int]
  signatures : @hashmap.HashMap[FeedbackSignature, Int]
  mut observations : Int
}

///|
pub fn FeatureRegistry::new() -> FeatureRegistry {
  {
    seen: @hashmap.HashMap([]),
    signatures: @hashmap.HashMap([]),
    observations: 0,
  }
}

///|
pub fn FeatureRegistry::observe(
  self : FeatureRegistry,
  observation : TargetObservation,
) -> FeatureDelta {
  self.observations += 1
  let all = observation.canonical_features()
  let novel : Array[Feature] = []
  for item in all {
    match self.seen.get(item) {
      None => {
        self.seen.set(item, 1)
        novel.push(item)
      }
      Some(count) => self.seen.set(item, count + 1)
    }
  }
  let signature = feedback_signature(all)
  let signature_count = self.signatures.get(signature).unwrap_or(0)
  self.signatures.set(signature, signature_count + 1)
  { signature, novel_features: novel, all_features: all, }
}

///|
pub fn FeatureRegistry::feature_frequency(
  self : FeatureRegistry,
  value : Feature,
) -> Int {
  self.seen.get(value).unwrap_or(0)
}

///|
pub fn FeatureRegistry::signature_frequency(
  self : FeatureRegistry,
  value : FeedbackSignature,
) -> Int {
  self.signatures.get(value).unwrap_or(0)
}

///|
pub fn FeatureRegistry::unique_feature_count(self : FeatureRegistry) -> Int {
  self.seen.length()
}

///|
pub fn FeatureRegistry::unique_signature_count(self : FeatureRegistry) -> Int {
  self.signatures.length()
}

///|
pub fn FeatureRegistry::observation_count(self : FeatureRegistry) -> Int {
  self.observations
}

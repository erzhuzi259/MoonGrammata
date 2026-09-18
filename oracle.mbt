///|
pub(all) enum DifferentialPolicy {
  CompareDisposition
  CompareResultDigest
  CompareDispositionAndDigest
} derive(Debug, Eq)

///|
fn disposition_class(value : ExecutionDisposition) -> String {
  match value {
    Accepted => "accepted"
    Rejected(reason) => "rejected:" + reason
    Failed(kind, detail) => "failed:" + kind + ":" + detail
  }
}

///|
fn differential_mismatch(
  left : TargetObservation,
  right : TargetObservation,
  policy : DifferentialPolicy,
) -> String? {
  let disposition_differs = disposition_class(left.disposition) !=
    disposition_class(right.disposition)
  let digest_differs = left.result_digest != right.result_digest
  match policy {
    CompareDisposition =>
      if disposition_differs { Some("disposition") } else { None }
    CompareResultDigest =>
      if digest_differs { Some("result-digest") } else { None }
    CompareDispositionAndDigest =>
      if disposition_differs {
        Some("disposition")
      } else if digest_differs {
        Some("result-digest")
      } else {
        None
      }
  }
}

///|
fn merged_features(
  left : TargetObservation,
  right : TargetObservation,
) -> Array[Feature] {
  let result : Array[Feature] = []
  for item in left.canonical_features() {
    result.push(feature("left/" + item.domain, item.value))
  }
  for item in right.canonical_features() {
    result.push(feature("right/" + item.domain, item.value))
  }
  result
}

///|
pub fn differential_target(
  name : String,
  left : Target,
  right : Target,
  policy? : DifferentialPolicy = CompareDispositionAndDigest,
) -> Target {
  Target::new(name, input => {
    let left_result = left.run(input)
    let right_result = right.run(input)
    let features = merged_features(left_result, right_result)
    match differential_mismatch(left_result, right_result, policy) {
      None => accepted(
        features~,
        result_digest=left_result.result_digest.unwrap_or(""),
        cost_class=left_result.cost_class.max(right_result.cost_class),
      )
      Some(reason) => failed(
        "differential-mismatch",
        reason + " between " + left.name() + " and " + right.name(),
        features~,
      )
    }
  })
}

///|
pub struct MetamorphicTransform {
  name : String
  apply : (Bytes) -> Bytes
  relation : (TargetObservation, TargetObservation) -> Bool
}

///|
pub fn MetamorphicTransform::new(
  name : String,
  apply : (Bytes) -> Bytes,
  relation : (TargetObservation, TargetObservation) -> Bool,
) -> MetamorphicTransform {
  { name, apply, relation }
}

///|
pub fn MetamorphicTransform::name(self : MetamorphicTransform) -> String {
  self.name
}

///|
pub fn same_digest_transform(
  name : String,
  apply : (Bytes) -> Bytes,
) -> MetamorphicTransform {
  MetamorphicTransform::new(
    name,
    apply,
    (before, after) => before.result_digest == after.result_digest,
  )
}

///|
pub fn same_disposition_transform(
  name : String,
  apply : (Bytes) -> Bytes,
) -> MetamorphicTransform {
  MetamorphicTransform::new(
    name,
    apply,
    (before, after) =>
      disposition_class(before.disposition) == disposition_class(after.disposition),
  )
}

///|
pub fn metamorphic_target(
  name : String,
  base : Target,
  transforms : Array[MetamorphicTransform],
) -> Target {
  Target::new(name, input => {
    let baseline = base.run(input)
    let features : Array[Feature] = []
    for item in baseline.canonical_features() {
      features.push(feature("base/" + item.domain, item.value))
    }
    for transform in transforms {
      let transformed_input = (transform.apply)(input)
      let transformed = base.run(transformed_input)
      for item in transformed.canonical_features() {
        features.push(feature(
          "transform/" + transform.name + "/" + item.domain,
          item.value,
        ))
      }
      if !(transform.relation)(baseline, transformed) {
        return failed(
          "metamorphic-violation",
          transform.name,
          features~,
        )
      }
    }
    accepted(
      features~,
      result_digest=baseline.result_digest.unwrap_or(""),
      cost_class=baseline.cost_class,
    )
  })
}

///|
pub fn agreement_target(
  name : String,
  targets : Array[Target],
  minimum_agreement? : Int = 2,
) -> Target {
  Target::new(name, input => {
    if targets.is_empty() {
      return failed("agreement-configuration", "no targets")
    }
    let counts : @hashmap.HashMap[String, Int] = @hashmap.HashMap([])
    let features : Array[Feature] = []
    let mut best_key = ""
    let mut best_count = 0
    for target in targets {
      let result = target.run(input)
      let key = disposition_class(result.disposition) +
        "|" +
        result.result_digest.unwrap_or("")
      let count = counts.get(key).unwrap_or(0) + 1
      counts.set(key, count)
      if count > best_count {
        best_count = count
        best_key = key
      }
      features.push(feature("engine", target.name() + ":" + key))
    }
    if best_count < minimum_agreement.max(1) {
      failed(
        "agreement-failure",
        "best=" + best_count.to_string() + "/" + targets.length().to_string(),
        features~,
      )
    } else {
      accepted(features~, result_digest=best_key)
    }
  })
}


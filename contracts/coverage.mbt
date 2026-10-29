///|
pub struct OperationCoverage {
  operation : String
  positive_passes : Int32
  negative_passes : Int32
  failures : Int32
  priv uncovered_responses : Array[String]
}

///|
pub fn OperationCoverage::operation(self : OperationCoverage) -> String {
  self.operation
}

///|
pub fn OperationCoverage::positive_passes(self : OperationCoverage) -> Int32 {
  self.positive_passes
}

///|
pub fn OperationCoverage::negative_passes(self : OperationCoverage) -> Int32 {
  self.negative_passes
}

///|
pub fn OperationCoverage::failures(self : OperationCoverage) -> Int32 {
  self.failures
}

///|
pub fn OperationCoverage::uncovered_responses(
  self : OperationCoverage,
) -> Array[String] {
  self.uncovered_responses.copy()
}

///|
pub fn OperationCoverage::to_json(self : OperationCoverage) -> Json {
  {
    "operation": self.operation,
    "positive_passes": self.positive_passes,
    "negative_passes": self.negative_passes,
    "failures": self.failures,
    "uncovered_responses": Json::array(
      self.uncovered_responses.map(Json::string),
    ),
  }
}

///|
priv struct CoverageCounts {
  mut positive : Int32
  mut negative : Int32
  mut failed : Int32
  covered : Map[String, Bool]
}

///|
/// Evidence inventory across ALL operations, not an upgrade approval. Only a
/// passing positive case with an actual response covers its selected status
/// rule (exact > class > default). No request/response values enter the report.
pub fn Workspace::consumer_coverage(
  self : Workspace,
  cases : Array[ConsumerCase],
) -> Array[OperationCoverage] raise WorkspaceError {
  if cases.length() > self.limits.cases {
    raise Budget("cases")
  }
  for sample in cases {
    ignore(self.operation(sample.operation))
  }
  let results = self.replay(cases)
  let counts : Map[String, CoverageCounts] = Map([])
  for name in self.order {
    counts[name] = { positive: 0, negative: 0, failed: 0, covered: Map([]), }
  }
  for i, sample in cases {
    let count = counts[sample.operation]
    if !results[i].passed {
      count.failed += 1
      continue
    }
    if !sample.expect_valid {
      count.negative += 1
      continue
    }
    count.positive += 1
    if sample.response is Some(response) {
      let rules = self.operations[sample.operation].responses
      let exact = response.status.to_string()
      let category = "\{response.status/100}XX"
      let key = if rules.contains(exact) {
        exact
      } else if rules.contains(category) {
        category
      } else {
        "default"
      }
      count.covered[key] = true
    }
  }
  self.order.map(name => {
    let count = counts[name]
    let uncovered : Array[String] = []
    for key, _ in self.operations[name].responses {
      if !count.covered.contains(key) {
        uncovered.push(key)
      }
    }
    uncovered.sort_by((a, b) => a.lexical_compare(b))
    {
      operation: name,
      positive_passes: count.positive,
      negative_passes: count.negative,
      failures: count.failed,
      uncovered_responses: uncovered,
    }
  })
}

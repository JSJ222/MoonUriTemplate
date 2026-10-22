///|
/// Machine-readable release evidence; no request bodies or parameter values.
/// A review approval is a host policy decision, not a compatibility proof.
pub fn UpgradeDecision::to_json(self : UpgradeDecision) -> Json {
  let blockers : Array[Json] = []
  for item in self.blockers {
    blockers.push({ "operation": item.operation, "code": item.code })
  }
  let changes : Array[Json] = []
  for change in self.changes {
    let severity = match change.severity {
      Breaking => "breaking"
      Review => "review"
      Additive => "additive"
    }
    changes.push({
      "operation": change.operation,
      "severity": severity,
      "code": change.code,
    })
  }
  let results : Array[Json] = []
  for result in self.results {
    let issues : Array[Json] = []
    for issue in result.violations {
      issues.push({
        "location": issue.location,
        "instancePath": issue.instance_path,
        "schemaPath": issue.schema_path,
        "code": issue.code,
      })
    }
    results.push({
      "name": result.name,
      "operation": result.operation,
      "expectedValid": result.expected_valid,
      "actualValid": result.actual_valid,
      "passed": result.passed,
      "violations": Json::array(issues),
    })
  }
  {
    "accepted": self.accepted,
    "blockers": Json::array(blockers),
    "candidateRevision": self.candidate.revision,
    "candidateReplayedCases": self.replayed,
    "changes": Json::array(changes),
    "results": Json::array(results),
  }
}

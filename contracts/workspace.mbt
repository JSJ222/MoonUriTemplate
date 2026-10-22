///|
/// Return a detached reproducible offline lock, not credentials or call data.
pub fn Workspace::manifest(self : Workspace) -> Json raise WorkspaceError {
  let value : Json = {
    "documents": Json::object(self.documents),
    "operations": Json::array(self.definitions),
  }
  detached(value, self.limits)
}

///|
pub fn Workspace::resolved_operation(
  self : Workspace,
  name : String,
) -> Json raise WorkspaceError {
  detached(self.operation(name).resolved, self.limits)
}

///|
/// Atomic document replacement/removal. Rebuild exactly operations in the old
/// reverse-dependency graph of changed documents. Transitive dependencies are
/// recorded during resolution; rebuilt operations produce the NEW graph.
/// Failed resolution never mutates this snapshot. Operation additions/removals
/// are supplied by cold-compiling a new manifest and reviewed with compare().
pub fn Workspace::update_documents(
  self : Workspace,
  changes : Array[DocumentChange],
) -> WorkspaceUpdate raise WorkspaceError {
  if changes.length() > self.limits.documents {
    raise Budget("document_changes")
  }
  let documents = self.documents.copy()
  let seen : Map[String, Bool] = Map([])
  let changed = []
  let affected : Map[String, Bool] = Map([])
  for patch in changes {
    need(!seen.contains(patch.name), "changes", "duplicate document change")
    need(
      patch.name != "" && !patch.name.contains("#"),
      "changes",
      "invalid document name",
    )
    seen[patch.name] = true
    let document = match patch.document {
      Some(value) => Some(detached(value, self.limits))
      None => None
    }
    if document is None {
      need(
        documents.contains(patch.name),
        "changes",
        "cannot remove missing document",
      )
    }
    if documents.get(patch.name) == document {
      continue
    }
    match document {
      Some(value) => documents[patch.name] = value
      None => {
        need(
          documents.contains(patch.name),
          "changes",
          "cannot remove missing document",
        )
        documents.remove(patch.name) |> ignore
      }
    }
    changed.push(patch.name)
    for user in self.operations_using(patch.name) {
      affected[user] = true
    }
  }
  if documents.length() > self.limits.documents {
    raise Budget("documents")
  }
  // Check aggregate size as well as each patch, so repeated revisions cannot
  // accumulate an unbounded lock. This still scans/copies the complete lock.
  let all : Json = {
    "documents": Json::object(documents),
    "operations": Json::array(self.definitions),
  }
  let _ = detached(all, self.limits)
  let operations = self.operations.copy()
  let rebuilt = []
  for definition in self.definitions {
    let fields = object(definition, "operation")
    let name = string(field(fields, "operationId", "operation"), "operationId")
    if affected.contains(name) {
      operations[name] = compile_operation(definition, documents, self.limits)
      rebuilt.push(name)
    }
  }
  need(self.revision < 2147483647, "revision", "revision overflow")
  let next = {
    ..self,
    documents,
    operations,
    reverse: reverse_index(self.order, operations),
    revision: if changed.is_empty() {
      self.revision
    } else {
      self.revision + 1
    },
  }
  { next, changed, rebuilt, }
}

///|
pub(all) enum ChangeSeverity {
  Breaking
  Review
  Additive
} derive(Eq)

///|
pub extend ChangeSeverity with Eq::{equal, not_equal}

///|
pub(all) struct ContractChange {
  operation : String
  severity : ChangeSeverity
  code : String
}

///|
/// Conservative structural review. Different resolved constraints are REVIEW,
/// never silently classified compatible by examples or serialized string hashes.
/// Removed operations/method/path changes and new required parameters are known
/// breaks. This is NOT arbitrary JSON Schema language inclusion.
pub fn Workspace::compare(
  self : Workspace,
  next : Workspace,
) -> Array[ContractChange] {
  let changes = []
  for name in self.order {
    let old = self.operations[name]
    match next.operations.get(name) {
      None =>
        changes.push({
          operation: name,
          severity: Breaking,
          code: "operation_removed",
        })
      Some(current) => {
        if old.verb != current.verb || old.path != current.path {
          changes.push({
            operation: name,
            severity: Breaking,
            code: "method_or_path_changed",
          })
        }
        for rule in current.parameters {
          let prior = old.parameters.filter(fn(item) {
            item.location == rule.location && item.name == rule.name
          })
          if rule.required && (prior.is_empty() || !prior[0].required) {
            changes.push({
              operation: name,
              severity: Breaking,
              code: "required_parameter_added",
            })
          }
        }
        if !old.request.required && current.request.required {
          changes.push({
            operation: name,
            severity: Breaking,
            code: "request_body_now_required",
          })
        }
        if old.resolved != current.resolved {
          changes.push({
            operation: name,
            severity: Review,
            code: "resolved_contract_changed",
          })
        }
      }
    }
  }
  for name in next.order {
    if !self.operations.contains(name) {
      changes.push({
        operation: name,
        severity: Additive,
        code: "operation_added",
      })
    }
  }
  changes
}

///|
pub struct UpgradeDecision {
  priv candidate : Workspace
  priv accepted : Bool
  priv changes : Array[ContractChange]
  priv baseline : Array[CaseResult]
  priv results : Array[CaseResult]
  priv replayed : Int32
  priv blockers : Array[UpgradeBlocker]
}

///|
pub(all) struct UpgradeBlocker {
  operation : String
  code : String
}

///|
pub fn UpgradeDecision::blockers(
  self : UpgradeDecision,
) -> Array[UpgradeBlocker] {
  self.blockers.copy()
}

///|
pub fn UpgradeDecision::accepted(self : UpgradeDecision) -> Bool {
  self.accepted
}

///|
pub fn UpgradeDecision::changes(
  self : UpgradeDecision,
) -> Array[ContractChange] {
  self.changes.copy()
}

///|
pub fn UpgradeDecision::replayed_cases(self : UpgradeDecision) -> Int32 {
  self.replayed
}

///|
fn case_results_copy(values : Array[CaseResult]) -> Array[CaseResult] {
  values.map(fn(value) { { ..value, violations: value.violations.copy(), } })
}

///|
pub fn UpgradeDecision::results(self : UpgradeDecision) -> Array[CaseResult] {
  case_results_copy(self.results)
}

///|
pub fn UpgradeDecision::baseline_results(
  self : UpgradeDecision,
) -> Array[CaseResult] {
  case_results_copy(self.baseline)
}

///|
/// Only approved decisions expose an installable candidate. The host controls
/// durable publication/rollback and must explicitly opt into reviewed changes.
pub fn UpgradeDecision::approved_workspace(
  self : UpgradeDecision,
) -> Workspace? {
  if self.accepted {
    Some(self.candidate)
  } else {
    None
  }
}

///|
/// Baseline ALL cases first; replay affected cases on the candidate and reuse
/// only baseline results whose resolved operation is identical. Any failed old
/// expectation rejects the gate. Uncovered changed/added/removed operations also
/// reject it. Evidence cannot silently approve a REVIEW classification.
pub fn Workspace::gate_upgrade(
  self : Workspace,
  candidate : Workspace,
  cases : Array[ConsumerCase],
  approve_review~ : Bool = false,
) -> UpgradeDecision raise WorkspaceError {
  need(
    self.limits == candidate.limits,
    "gate",
    "candidate must use the same validation limits",
  )
  if cases.length() > candidate.limits.cases {
    raise Budget("cases")
  }
  let baseline = self.replay(cases)
  let changes = self.compare(candidate)
  let affected : Map[String, Bool] = Map([])
  let covered : Map[String, Bool] = Map([])
  let blockers = []
  for index, sample in cases {
    need(
      self.operations.contains(sample.operation) ||
      candidate.operations.contains(sample.operation),
      "cases",
      "case references an operation absent from both snapshots",
    )
    // A newly added operation has no old baseline. Its new positive coverage
    // and candidate expectations are still mandatory.
    if self.operations.contains(sample.operation) && !baseline[index].passed {
      blockers.push({ operation: sample.operation, code: "baseline_failed", })
    }
  }
  for change in changes {
    affected[change.operation] = true
    if change.severity == Breaking {
      blockers.push({ operation: change.operation, code: change.code, })
    }
    if change.severity == Review && !approve_review {
      blockers.push({ operation: change.operation, code: "review_required", })
    }
  }
  let results = []
  let mut replayed = 0
  for index, sample in cases {
    if affected.contains(sample.operation) {
      let single = candidate.replay([sample])
      results.push(single[0])
      replayed += 1
    } else {
      results.push(baseline[index])
    }
    if sample.expect_valid && results[index].actual_valid {
      covered[sample.operation] = true
    }
  }
  for operation, _ in affected {
    if !covered.contains(operation) {
      blockers.push({ operation, code: "positive_coverage_required", })
    }
  }
  for result in results {
    if !result.passed {
      blockers.push({
        operation: result.operation,
        code: "candidate_expectation_failed",
      })
    }
  }
  {
    candidate,
    accepted: blockers.is_empty(),
    changes,
    baseline,
    results,
    replayed,
    blockers,
  }
}

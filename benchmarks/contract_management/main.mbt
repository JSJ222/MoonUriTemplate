///|
fn percentile(values : Array[UInt64], percent : Int32) -> UInt64 {
  let ordered = values.copy()
  ordered.sort_by(fn(a, b) { a.compare(b) })
  ordered[(ordered.length() * percent + 99) / 100 - 1]
}

///|
fn workload(count : Int32, changed : Int32) -> Unit raise {
  let documents : Map[String, Json] = Map([])
  let operations : Array[Json] = []
  let cases : Array[@contracts.ConsumerCase] = []
  for i in 0..<count {
    let name = "op\{i}"
    let document = "schema\{i}"
    documents[document] = { "type": "string", "minLength": 1 }
    operations.push({
      "operationId": name,
      "method": "POST",
      "path": "/\{name}",
      "requestBody": {
        "required": true,
        "content": { "application/json": { "schema": { "$ref": document } } },
      },
      "responses": { "204": {} },
    })
    cases.push({
      name,
      operation: name,
      request: {
        parameters: [],
        body: Some("abc"),
        media_type: Some("application/json"),
      },
      response: None,
      expect_valid: true,
    })
  }
  let limits = { ..@contracts.WorkspaceLimits::default(), documents: 1024, }
  let mut current = @contracts.compile_workspace(
    {
      "documents": Json::object(documents),
      "operations": Json::array(operations),
    },
    limits~,
  )
  let cold_ms = []
  let incremental_ms = []
  let gate_ms = []
  for step in 0..<12 {
    let patches : Array[@contracts.DocumentChange] = []
    for i in 0..<changed {
      patches.push({
        name: "schema\{i}",
        document: Some({
          "type": "string",
          "minLength": if step % 2 == 0 {
            0
          } else {
            1
          },
        }),
      })
    }
    let start = @env.now()
    let update = current.update_documents(patches)
    incremental_ms.push(@env.now() - start)
    let candidate = update.workspace()
    assert_eq(update.rebuilt_operations().length(), changed)
    let manifest = candidate.manifest()
    let start = @env.now()
    let cold = @contracts.compile_workspace(manifest, limits~)
    cold_ms.push(@env.now() - start)
    let start = @env.now()
    let decision = current.gate_upgrade(candidate, cases, approve_review=true)
    gate_ms.push(@env.now() - start)
    assert_true(decision.accepted())
    assert_eq(decision.replayed_cases(), changed)
    let all = cold.replay(cases)
    let targeted = decision.results()
    for i in 0..<count {
      assert_true(all[i].violations == targeted[i].violations)
      assert_eq(all[i].passed, targeted[i].passed)
      assert_eq(
        candidate.resolved_operation("op\{i}"),
        cold.resolved_operation("op\{i}"),
      )
    }
    current = candidate
  }
  let report : Json = {
    "operations": count,
    "changed": changed,
    "rounds": 12,
    "coldCompileP50ms": percentile(cold_ms, 50).to_double(),
    "coldCompileP95ms": percentile(cold_ms, 95).to_double(),
    "updateP50ms": percentile(incremental_ms, 50).to_double(),
    "updateP95ms": percentile(incremental_ms, 95).to_double(),
    "gateP50ms": percentile(gate_ms, 50).to_double(),
    "gateP95ms": percentile(gate_ms, 95).to_double(),
    "rebuiltPerRound": changed,
    "candidateReplayPerRound": changed,
    "baselineReplayPerRound": count,
    "coldEquivalent": true,
  }
  println(report.stringify())
}

///|
fn main raise {
  workload(200, 1)
  workload(1000, 10)
  workload(1000, 1000)
}

///|
test "operation projection retains transitive locks and remains independently compilable" {
  let workspace = @contracts.compile_workspace(fixture())
  let selected = workspace.project_operations(["getUser"])
  assert_eq(selected.operation_names(), ["getUser"])
  assert_true(selected.validate_request("getUser", request()).is_empty())
  let manifest = selected.manifest()
  match manifest {
    Object(root) =>
      match root["documents"] {
        Object(docs) => {
          assert_true(docs.contains("id"))
          assert_true(docs.contains("user"))
          assert_false(docs.contains("unused"))
        }
        _ => fail("documents absent")
      }
    _ => fail("manifest absent")
  }
  let independent = @contracts.compile_workspace(manifest)
  assert_true(independent.validate_response("getUser", response()).is_empty())
  assert_eq(workspace.project_operations([]).operation_names().length(), 0)
  for names in [["missing"], ["ping", "ping"]] {
    let invalid = try {
      ignore(workspace.project_operations(names))
      false
    } catch {
      _ => true
    }
    assert_true(invalid)
  }
  assert_eq(workspace.operation_names().length(), 2)
}

///|
test "coverage identifies response-rule gaps without mistaking request-only checks for response coverage" {
  let workspace = @contracts.compile_workspace(fixture())
  let suite = cases()
  let rows = workspace.consumer_coverage(suite)
  assert_eq(rows[0].operation(), "getUser")
  assert_eq(rows[0].positive_passes(), 1)
  assert_eq(rows[0].negative_passes(), 1)
  assert_eq(rows[0].uncovered_responses(), ["2XX", "default"])
  assert_eq(rows[1].uncovered_responses(), ["204"])
  let extra : @contracts.ConsumerCase = {
    name: "health-response",
    operation: "ping",
    request: empty_request(),
    response: Some({ status: 204, headers: [], body: None, media_type: None, }),
    expect_valid: true,
  }
  suite.push(extra)
  assert_eq(
    workspace.consumer_coverage(suite)[1].uncovered_responses().length(),
    0,
  )
  let json = rows[0].to_json().stringify()
  assert_false(json.contains("team"))
  let detached = rows[0].uncovered_responses()
  detached.clear()
  assert_eq(rows[0].uncovered_responses().length(), 2)
}

///|
test "failing expectations do not count as positive response coverage" {
  let workspace = @contracts.compile_workspace(fixture())
  let bad : @contracts.ConsumerCase = {
    name: "bad",
    operation: "ping",
    request: empty_request(),
    response: Some({
      status: 204,
      headers: [],
      body: Some("forbidden"),
      media_type: Some("application/json"),
    }),
    expect_valid: true,
  }
  let rows = workspace.consumer_coverage([bad])
  assert_eq(rows[1].failures(), 1)
  assert_eq(rows[1].positive_passes(), 0)
  assert_eq(rows[1].uncovered_responses(), ["204"])
}

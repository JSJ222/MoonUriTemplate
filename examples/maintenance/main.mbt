///|
fn main raise {
  let before = @uri_template.compile_catalog([("user", "/v1/{id}")]).unwrap()
  let after = @uri_template.compile_catalog([
    ("user", "/v2/{id}{?fields*}"),
    ("health", "/health"),
  ]).unwrap()
  let delta = before.diff_catalog(after)
  assert_eq(delta.added(), ["health"])
  assert_eq(delta.changed()[0].contract().added_variables(), ["fields"])
  let requests : Array[@uri_template.CatalogRequest] = [
    { name: "user", bindings: [("id", @uri_template.Scalar("team/a"))], },
    { name: "retired", bindings: [], },
  ]
  let audit = after.inspect_requests(requests).unwrap()
  assert_true(audit[1].unknown_template())
  assert_eq(audit[0].issues().length(), 1)
  let valid = [requests[0]]
  let measured = after.measure_requests(valid).unwrap()
  let expanded = after.expand_requests(valid).unwrap()
  assert_eq(measured, expanded[0].length())
  println("Catalog migration, request audit and preflight expansion: ok")
}

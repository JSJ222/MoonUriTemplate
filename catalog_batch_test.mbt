///|
test "catalog batch renders mixed link relations in request order" {
  let catalog = match
    @moonuritemplate.compile_catalog([
      ("self", "/users/{id}"),
      ("orders", "/users/{id}/orders{?status}"),
    ]) {
    Ok(value) => value
    Err(_) => fail("catalog")
  }
  let requests : Array[@moonuritemplate.CatalogRequest] = [
    { name: "self", bindings: [("id", Scalar("42"))], },
    {
      name: "orders",
      bindings: [("id", Scalar("42")), ("status", Scalar("open"))],
    },
    { name: "self", bindings: [("id", Scalar("a/b"))], },
  ]
  let outputs = match catalog.expand_requests(requests) {
    Ok(value) => value
    Err(_) => fail("batch")
  }
  assert_eq(outputs.length(), 3)
  assert_eq(outputs[0], "/users/42")
  assert_eq(outputs[1], "/users/42/orders?status=open")
  assert_eq(outputs[2], "/users/a%2Fb")
}

///|
test "catalog batch reports missing relation by row" {
  let catalog = match @moonuritemplate.compile_catalog([("one", "{x}")]) {
    Ok(value) => value
    Err(_) => fail("catalog")
  }
  let requests : Array[@moonuritemplate.CatalogRequest] = [
    { name: "one", bindings: [("x", Scalar("a"))], },
    { name: "missing", bindings: [], },
  ]
  let error = match catalog.expand_requests(requests) {
    Err(value) => value
    Ok(_) => fail("unknown relation")
  }
  assert_eq(error.code(), "invalid_request")
  assert_true(error is InvalidRequest(1, UnknownTemplate("missing")))
}

///|
test "catalog batch enforces aggregate and per-request limits" {
  let catalog = match @moonuritemplate.compile_catalog([("one", "{x}")]) {
    Ok(value) => value
    Err(_) => fail("catalog")
  }
  let requests : Array[@moonuritemplate.CatalogRequest] = [
    { name: "one", bindings: [("x", Scalar("ab"))], },
    { name: "one", bindings: [("x", Scalar("cd"))], },
  ]
  assert_true(
    catalog.expand_requests(requests, max_requests=1) is Err(TooManyRequests),
  )
  assert_true(
    catalog.expand_requests(requests, max_total_output=3)
    is Err(TotalOutputTooLong),
  )
  assert_true(
    catalog.expand_requests(requests, max_each_output=1)
    is Err(InvalidRequest(0, InvalidBinding("one", OutputTooLong))),
  )
}

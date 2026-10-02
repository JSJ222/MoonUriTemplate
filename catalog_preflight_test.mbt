///|
test "catalog batch measurement equals rendered lengths" {
  let catalog = @moonuritemplate.compile_catalog([
    ("user", "/users/{id}{?fields*}"),
    ("order", "/orders/{order}"),
  ]).unwrap()
  let requests : Array[@moonuritemplate.CatalogRequest] = [
    {
      name: "user",
      bindings: [
        ("id", @moonuritemplate.Scalar("team/a")),
        ("fields", @moonuritemplate.List(["name", "status"])),
      ],
    },
    { name: "order", bindings: [("order", @moonuritemplate.Scalar("A 1"))], },
  ]
  let expected = catalog.expand_requests(requests).unwrap()
  let total = catalog.measure_requests(requests).unwrap()
  assert_eq(total, expected[0].length() + expected[1].length())
  match catalog.measure_requests([], max_total_output=0) {
    Ok(value) => assert_eq(value, 0)
    Err(_) => fail("empty batch should measure zero")
  }
  match catalog.measure_requests(requests, max_total_output=total - 1) {
    Err(error) => assert_eq(error.code(), "total_output_too_long")
    Ok(_) => fail("expected aggregate limit failure")
  }
}

///|
test "catalog batch measurement identifies the failing request" {
  let catalog = @moonuritemplate.compile_catalog([("one", "/{id}")]).unwrap()
  let requests : Array[@moonuritemplate.CatalogRequest] = [
    { name: "one", bindings: [("id", @moonuritemplate.Scalar("1"))], },
    { name: "unknown", bindings: [], },
  ]
  let result = catalog.measure_requests(requests)
  match result {
    Err(error) => {
      assert_eq(error.code(), "invalid_request")
      assert_eq(error.index(), Some(1))
    }
    Ok(_) => fail("expected invalid request")
  }
}

///|
test "reverse lookup preserves catalog order and unique entry names" {
  let catalog = @moonuritemplate.compile_catalog([
    ("user", "/users/{id}/{id}"),
    ("search", "/search{?query}"),
    ("order", "/orders/{id}"),
  ]).unwrap()
  assert_eq(catalog.templates_using("id"), ["user", "order"])
  assert_eq(catalog.templates_using("query"), ["search"])
  assert_eq(catalog.templates_using("missing"), [])
}

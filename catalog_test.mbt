///|
test "catalog expands named API and link templates" {
  let entries = [
    ("user", "/users/{id}{?fields*}"),
    ("order", "/orders/{order}"),
  ]
  let catalog = match @moonuritemplate.compile_catalog(entries) {
    Ok(value) => value
    Err(_) => fail("compile")
  }
  assert_eq(catalog.names(), ["user", "order"])
  assert_true(catalog.contains("user"))
  assert_true(!catalog.contains("unknown"))
  let bindings : Array[(String, @moonuritemplate.Value)] = [
    ("id", Scalar("a/b")),
    ("fields", List(["name", "email"])),
  ]
  let output = match catalog.expand("user", bindings) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(output, "/users/a%2Fb?fields=name&fields=email")
  let measured = match catalog.measure("user", bindings) {
    Ok(value) => value
    Err(_) => fail("measure catalog entry")
  }
  assert_eq(measured, output.length())
  assert_true(catalog.get("order") is Some(_))
}

///|
test "catalog rejects duplicate names and retains first error" {
  let entries = [("item", "/{id}"), ("item", "{")]
  assert_true(
    @moonuritemplate.compile_catalog(entries) is Err(DuplicateName("item")),
  )
  let invalid = [("ok", "/{id}"), ("bad", "{")]
  assert_true(
    @moonuritemplate.compile_catalog(invalid) is Err(InvalidTemplate("bad", _)),
  )
}

///|
test "catalog rejects oversized sets, empty names, and bad limits" {
  assert_true(
    @moonuritemplate.compile_catalog([("x", "x")], max_templates=0)
    is Err(TooManyTemplates),
  )
  assert_true(
    @moonuritemplate.compile_catalog([], max_templates=-1)
    is Err(TooManyTemplates),
  )
  assert_true(@moonuritemplate.compile_catalog([("", "x")]) is Err(EmptyName))
  assert_true(
    @moonuritemplate.compile_catalog([("x", "123")], max_template_length=2)
    is Err(InvalidTemplate("x", InputTooLong)),
  )
}

///|
test "catalog distinguishes unknown entry from expansion error" {
  let catalog = match @moonuritemplate.compile_catalog([("one", "{x}")]) {
    Ok(value) => value
    Err(_) => fail("compile")
  }
  let empty : Array[(String, @moonuritemplate.Value)] = []
  assert_true(catalog.expand("two", empty) is Err(UnknownTemplate("two")))
  let values : Array[(String, @moonuritemplate.Value)] = [("x", Scalar("long"))]
  assert_true(
    catalog.expand("one", values, max_output=2)
    is Err(InvalidBinding("one", OutputTooLong)),
  )
  assert_true(
    catalog.measure("one", values, max_output=2)
    is Err(InvalidBinding("one", OutputTooLong)),
  )
}

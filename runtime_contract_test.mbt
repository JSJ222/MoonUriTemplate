///|
fn contract_template(source : String) -> @moonuritemplate.Template raise {
  match @moonuritemplate.parse(source) {
    Ok(t) => t
    Err(_) => fail("template")
  }
}

///|
test "runtime contract validates SDK required scalar and optional list" {
  let rules : Array[@moonuritemplate.BindingRule] = [
    { name: "id", kind: TextValue, required: true, },
    { name: "fields", kind: ListValue, required: false, },
  ]
  let contract = match
    contract_template("/users/{id}{?fields*}").with_contract(rules) {
    Ok(c) => c
    Err(_) => fail("contract")
  }
  assert_true(contract.expand([]) is Err(MissingRequired("id")))
  assert_true(
    contract.expand([("id", List(["1"]))]) is Err(WrongKind("id", TextValue)),
  )
  match
    contract.expand([
      ("id", Scalar("a/b")),
      ("fields", SparseList([None, Some("name")])),
    ]) {
    Ok(uri) => assert_eq(uri, "/users/a%2Fb?fields=name")
    Err(_) => fail("valid contract")
  }
  assert_true(contract.expand([("id", Scalar(""))]) is Ok("/users/"))
  assert_true(
    contract.expand([("id", Scalar("a")), ("typo", Scalar("x"))])
    is Err(InvalidBindings(UnusedVariable("typo"))),
  )
}

///|
test "required composites use RFC defined-value semantics" {
  let contract = match
    contract_template("{?items*}").with_contract([
      { name: "items", kind: ListValue, required: true, },
    ]) {
    Ok(c) => c
    Err(_) => fail("contract")
  }
  assert_true(
    contract.validate([("items", List([]))]) is Err(MissingRequired("items")),
  )
  assert_true(
    contract.validate([("items", SparseList([None, None]))])
    is Err(MissingRequired("items")),
  )
  assert_true(
    contract.expand([("items", SparseList([Some("")]))]) is Ok("?items="),
  )
  let assoc = match
    contract_template("{?a*}").with_contract([
      { name: "a", kind: AssociationValue, required: true, },
    ]) {
    Ok(c) => c
    Err(_) => fail("association contract")
  }
  assert_true(
    assoc.validate([("a", SparseAssoc([("x", None)]))])
    is Err(MissingRequired("a")),
  )
  assert_true(assoc.expand([("a", Assoc([("x", "")]))]) is Ok("?x="))
}

///|
test "contract compilation rejects unknown duplicate and prefix-conflicting rules" {
  let t = contract_template("{id:2}{?q}")
  assert_true(
    t.with_contract([{ name: "x", kind: TextValue, required: false, }])
    is Err(UnknownRule("x")),
  )
  assert_true(
    t.with_contract([{ name: "id", kind: ListValue, required: false, }])
    is Err(IncompatibleRule("id")),
  )
  let rule : @moonuritemplate.BindingRule = {
    name: "q",
    kind: TextValue,
    required: false,
  }
  assert_true(t.with_contract([rule, rule]) is Err(DuplicateRule("q")))
}

///|
test "contract captures rules and preserves opt-in semantics" {
  let rules : Array[@moonuritemplate.BindingRule] = [
    { name: "id", kind: TextValue, required: true, },
  ]
  let t = contract_template("/{id}{?q}")
  let c = match t.with_contract(rules, reject_unused=false) {
    Ok(c) => c
    Err(_) => fail("contract")
  }
  rules[0] = { name: "id", kind: ListValue, required: false, }
  assert_true(
    c.expand([("id", Scalar("a")), ("other", Scalar("b"))]) is Ok("/a"),
  )
  assert_true(c.expand([]) is Err(MissingRequired("id")))
  assert_true(t.expand([]) is Ok("/"))
}

///|
test "contract forwards limits duplicate checks and unruled prefix constraints" {
  let c = match contract_template("{id:2}").with_contract([]) {
    Ok(c) => c
    Err(_) => fail("contract")
  }
  assert_true(
    c.validate([("id", Scalar("a")), ("id", Scalar("b"))])
    is Err(InvalidBindings(DuplicateVariable("id"))),
  )
  assert_true(
    c.validate([("id", List(["a"]))])
    is Err(InvalidBindings(InvalidValue("id"))),
  )
  assert_true(
    c.validate([], max_items=-1)
    is Err(InvalidBindings(InvalidLimit("max_items"))),
  )
  assert_true(
    c.validate([], max_value_length=-1)
    is Err(InvalidBindings(InvalidLimit("max_value_length"))),
  )
  assert_true(
    c.expand([("id", Scalar("abc"))], max_output=1)
    is Err(InvalidBindings(OutputTooLong)),
  )
  assert_true(
    c.validate([("id", Scalar("abc"))], max_value_length=2)
    is Err(InvalidBindings(ValueTooLong("id"))),
  )
  assert_true(
    c.validate([("id", Scalar("a"))], max_bindings=0)
    is Err(InvalidBindings(TooManyBindings)),
  )
}

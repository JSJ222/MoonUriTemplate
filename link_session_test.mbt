///|
fn session_catalog(
  entries : Array[(String, String)],
) -> @moonuritemplate.TemplateCatalog raise {
  match @moonuritemplate.compile_catalog(entries) {
    Ok(c) => c
    Err(_) => fail("catalog")
  }
}

///|
fn test_session(
  c : @moonuritemplate.TemplateCatalog,
  values : Array[(String, @moonuritemplate.Value)],
) -> @moonuritemplate.LinkSession raise {
  match c.start_session(values) {
    Ok(s) => s
    Err(_) => fail("session")
  }
}

///|
fn test_update(
  s : @moonuritemplate.LinkSession,
  patch : Array[@moonuritemplate.BindingChange],
) -> @moonuritemplate.LinkUpdate raise {
  match s.update(patch) {
    Ok(u) => u
    Err(_) => fail("update")
  }
}

///|
test "incremental links recompute dependencies once and retain catalog order" {
  let c = session_catalog([
    ("user", "/u/{id}"),
    ("search", "/search{?id,q}"),
    ("health", "/health"),
  ])
  let s = test_session(c, [("id", Scalar("1")), ("q", Scalar("old"))])
  let u = test_update(s, [
    SetBinding("q", Scalar("new")),
    SetBinding("id", Scalar("2")),
  ])
  assert_eq(u.recomputed(), 2)
  assert_eq(u.changes().map(fn(c) { c.name }), ["user", "search"])
  assert_eq(u.session().links(), [
    ("user", "/u/2"),
    ("search", "/search?id=2&q=new"),
    ("health", "/health"),
  ])
  assert_eq(s.links()[0].1, "/u/1")
  assert_eq(
    u.session().total_length(),
    u.session().links().fold(init=0, fn(n, link) { n + link.1.length() }),
  )
}

///|
test "identical bindings avoid recomputation and prefix-equivalent results suppress changes" {
  let s = test_session(session_catalog([("short", "/{id:1}")]), [
    ("id", Scalar("ab")),
  ])
  let same = test_update(s, [SetBinding("id", Scalar("ab"))])
  assert_eq(same.recomputed(), 0)
  assert_eq(same.changes().length(), 0)
  let equivalent = test_update(s, [SetBinding("id", Scalar("ac"))])
  assert_eq(equivalent.recomputed(), 1)
  assert_eq(equivalent.changes().length(), 0)
  assert_eq(test_update(s, []).recomputed(), 0)
}

///|
test "remove binding restores omission and absent remove does no work" {
  let s = test_session(session_catalog([("search", "/s{?q,page}")]), [
    ("q", Scalar("hello")),
  ])
  let removed = test_update(s, [RemoveBinding("q")])
  assert_eq(removed.session().links()[0].1, "/s")
  assert_eq(
    test_update(removed.session(), [RemoveBinding("q")]).recomputed(),
    0,
  )
  assert_eq(
    test_update(removed.session(), [SetBinding("page", Scalar("2"))])
    .session()
    .links()[0].1,
    "/s?page=2",
  )
}

///|
test "captured composites and returned arrays cannot mutate session state" {
  let items = ["a"]
  let s = test_session(session_catalog([("list", "{?items*}")]), [
    ("items", List(items)),
  ])
  items[0] = "changed"
  assert_eq(test_update(s, [SetBinding("items", List(["a"]))]).recomputed(), 0)
  let next_items = ["b"]
  let update = test_update(s, [SetBinding("items", List(next_items))])
  next_items[0] = "changed"
  assert_eq(
    test_update(update.session(), [SetBinding("items", List(["b"]))]).recomputed(),
    0,
  )
  let links = update.session().links()
  links[0] = ("bad", "bad")
  let changes = update.changes()
  changes.clear()
  assert_eq(update.changes().length(), 1)
  assert_eq(update.session().links()[0].1, "?items=b")
}

///|
test "failed update is atomic for invalid shapes and total budget" {
  let c = session_catalog([("a", "{a}"), ("b", "{b:2}")])
  let s = match
    c.start_session(
      [("a", Scalar("x")), ("b", Scalar("y"))],
      max_total_output=3,
    ) {
    Ok(s) => s
    Err(_) => fail("session")
  }
  assert_true(
    s.update([SetBinding("a", Scalar("z")), SetBinding("b", List(["bad"]))])
    is Err(InvalidEndpoint("b", _)),
  )
  assert_eq(s.links(), [("a", "x"), ("b", "y")])
  assert_true(
    s.update([SetBinding("a", Scalar("toolong"))]) is Err(TotalOutputTooLong),
  )
  assert_eq(s.total_length(), 2)
  assert_eq(
    test_update(s, [SetBinding("a", Scalar("xx"))]).session().total_length(),
    3,
  )
}

///|
test "aggregate budget subtracts every old affected value before adding new ones" {
  let c = session_catalog([("first", "{a}"), ("second", "{b}")])
  let s = match
    c.start_session(
      [("a", Scalar("x")), ("b", Scalar("yyyy"))],
      max_total_output=5,
    ) {
    Ok(s) => s
    Err(_) => fail("session")
  }
  let next = test_update(s, [
    SetBinding("a", Scalar("xxxx")),
    SetBinding("b", Scalar("y")),
  ]).session()
  assert_eq(next.total_length(), 5)
  assert_eq(next.links()[0].1, "xxxx")
}

///|
test "session rejects duplicates unknown names and bounded patch requests" {
  let c = session_catalog([("a", "{a}")])
  assert_true(
    c.start_session([("unknown", Scalar("x"))])
    is Err(InvalidBindings(UnusedVariable("unknown"))),
  )
  assert_true(
    c.start_session([("a", Scalar("x")), ("a", Scalar("y"))])
    is Err(InvalidBindings(DuplicateVariable("a"))),
  )
  let s = test_session(c, [])
  assert_true(
    s.update([SetBinding("a", Scalar("x")), RemoveBinding("a")])
    is Err(DuplicateChange("a")),
  )
  assert_true(
    s.update([RemoveBinding("unknown")])
    is Err(InvalidBindings(UnusedVariable("unknown"))),
  )
  assert_true(
    s.update(Array::make(4097, RemoveBinding("a"))) is Err(TooManyChanges),
  )
}

///|
test "session enforces binding value item and output limits" {
  let c = session_catalog([("a", "{a}{b}")])
  assert_true(c.start_session([], max_each_output=-1) is Err(InvalidBudget))
  assert_true(c.start_session([], max_total_output=-1) is Err(InvalidBudget))
  let s = match
    c.start_session(
      [("a", Scalar("x"))],
      max_bindings=1,
      max_value_length=2,
      max_items=1,
      max_each_output=2,
    ) {
    Ok(s) => s
    Err(_) => fail("session")
  }
  assert_true(
    s.update([SetBinding("b", Scalar("y"))])
    is Err(InvalidBindings(TooManyBindings)),
  )
  assert_true(
    s.update([SetBinding("a", Scalar("xxx"))])
    is Err(InvalidBindings(ValueTooLong("a"))),
  )
  assert_true(
    s.update([SetBinding("a", List(["x", "y"]))])
    is Err(InvalidBindings(TooManyItems("a"))),
  )
  assert_true(
    s.update([SetBinding("a", Scalar("中"))])
    is Err(InvalidEndpoint("a", OutputTooLong)),
  )
  assert_eq(
    test_update(s, [SetBinding("b", Scalar("y")), RemoveBinding("a")])
    .session()
    .links()[0].1,
    "y",
  )
}

///|
test "incremental result agrees with full expansion through sparse and Unicode changes" {
  let c = session_catalog([("query", "{?a*}"), ("fragment", "{#q}")])
  let s = test_session(c, [])
  let bindings : Array[(String, @moonuritemplate.Value)] = [
    ("a", SparseAssoc([("空", None), ("x", Some("🙂"))])),
    ("q", Scalar("中/文")),
  ]
  let u = test_update(s, [
    SetBinding("a", bindings[0].1),
    SetBinding("q", bindings[1].1),
  ])
  for link in u.session().links() {
    match c.expand(link.0, bindings) {
      Ok(uri) => assert_eq(uri, link.1)
      Err(_) => fail("full expansion")
    }
  }
}

///|
test "large catalog selects one dependent endpoint without re-expanding all links" {
  let entries = Array::makei(200, fn(i) { ("e\{i}", "/\{i}/{v\{i}}") })
  let c = session_catalog(entries)
  let s = test_session(c, [])
  let u = test_update(s, [SetBinding("v137", Scalar("x"))])
  assert_eq(u.recomputed(), 1)
  assert_eq(u.changes().length(), 1)
  assert_eq(u.changes()[0].name, "e137")
  assert_eq(u.session().links()[137].1, "/137/x")
  let empty = test_session(session_catalog([]), [])
  assert_eq(empty.total_length(), 0)
  assert_eq(test_update(empty, []).changes().length(), 0)
}

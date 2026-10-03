///|
test "catalog migration detects removals additions and literal changes" {
  let old = @moonuritemplate.compile_catalog([
    ("user", "/v1/{id}"),
    ("gone", "/gone"),
    ("same", "/same"),
  ]).unwrap()
  let next = @moonuritemplate.compile_catalog([
    ("new", "/new"),
    ("user", "/v2/{id}"),
    ("same", "/same"),
  ]).unwrap()
  let diff = old.diff_catalog(next)
  assert_eq(diff.added(), ["new"])
  assert_eq(diff.removed(), ["gone"])
  assert_eq(diff.changed().length(), 1)
  assert_eq(diff.changed()[0].name(), "user")
  assert_false(diff.changed()[0].contract().has_flagged_changes())
  assert_false(diff.is_empty())
  assert_true(old.diff_catalog(old).is_empty())
  let copy = diff.added()
  copy.clear()
  assert_eq(diff.added(), ["new"])
}

///|
test "catalog migration retains operator and binding contract changes" {
  let old = @moonuritemplate.compile_catalog([("x", "/{id}{?tags*}")]).unwrap()
  let next = @moonuritemplate.compile_catalog([("x", "/{+id}{?query}{tags:3}")]).unwrap()
  let contract = old.diff_catalog(next).changed()[0].contract()
  assert_eq(contract.added_variables(), ["query"])
  assert_eq(contract.became_scalar_only(), ["tags"])
  assert_true(contract.reserved_added())
}

///|
test "request audit aggregates diagnostics without bound values" {
  let catalog = @moonuritemplate.compile_catalog([("user", "/{id}{tags:2}")]).unwrap()
  let rows = catalog
    .inspect_requests([
      {
        name: "user",
        bindings: [
          ("tags", @moonuritemplate.List(["private"])),
          ("extra", @moonuritemplate.Scalar("secret")),
        ],
      },
      { name: "unknown", bindings: [], },
    ])
    .unwrap()
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].index(), 0)
  assert_eq(rows[0].issues().map(issue => issue.code()), [
    "unused", "missing", "composite_prefix",
  ])
  assert_true(rows[1].unknown_template())
  assert_eq(rows[1].index(), 1)
}

///|
test "request audit rejects complete input or result over budget" {
  let catalog = @moonuritemplate.compile_catalog([("x", "{a,b}")]).unwrap()
  let requests : Array[@moonuritemplate.CatalogRequest] = [
    {
      name: "x",
      bindings: [
        ("a", @moonuritemplate.Scalar("1")),
        ("a", @moonuritemplate.Scalar("2")),
      ],
    },
  ]
  assert_true(
    catalog.inspect_requests(requests, max_requests=0)
    is Err(@moonuritemplate.RequestLimit),
  )
  assert_true(
    catalog.inspect_requests(requests, max_bindings=1)
    is Err(@moonuritemplate.BindingLimit),
  )
  assert_true(
    catalog.inspect_requests(requests, max_findings=1)
    is Err(@moonuritemplate.FindingLimit),
  )
  assert_eq(catalog.inspect_requests([], max_findings=0).unwrap().length(), 0)
}

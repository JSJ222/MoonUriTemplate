///|
fn main {
  let catalog = match
    @uri_template.compile_catalog([
      ("resource", "mcp://workspace/{tenant}/files/{file}"),
      ("search", "/tenants/{tenant}/search{?q}"),
      ("health", "/health"),
    ]) {
    Ok(value) => value
    Err(_) => abort("invalid catalog")
  }
  let original = match
    catalog.start_session(
      [
        ("tenant", Scalar("demo")),
        ("file", Scalar("notes.md")),
        ("q", Scalar("old")),
      ],
      max_total_output=256,
    ) {
    Ok(value) => value
    Err(_) => abort("invalid initial bindings")
  }
  let changed = match original.update([SetBinding("q", Scalar("MoonBit"))]) {
    Ok(value) => value
    Err(_) => abort("valid patch rejected")
  }
  if changed.recomputed() != 1 || changed.changes().length() != 1 {
    abort("unrelated links recomputed")
  }
  if changed.changes()[0].after != "/tenants/demo/search?q=MoonBit" {
    abort("wrong updated link")
  }
  if original.links()[1].1 != "/tenants/demo/search?q=old" {
    abort("original snapshot mutated")
  }
  if !(changed.session().update([SetBinding("q", Scalar("x".repeat(300)))])
    is Err(TotalOutputTooLong)) {
    abort("aggregate budget was not enforced")
  }
  println(changed.changes()[0].after)
  println(
    "Incremental links: one of three endpoints recomputed; old snapshot and budget preserved",
  )
}

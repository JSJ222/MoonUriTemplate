///|
fn main {
  let template = match @uri_template.parse("/users/{id}{?fields*}") {
    Ok(value) => value
    Err(_) => abort("invalid template")
  }
  let contract = match
    template.with_contract([
      { name: "id", kind: TextValue, required: true, },
      { name: "fields", kind: ListValue, required: false, },
    ]) {
    Ok(value) => value
    Err(_) => abort("invalid contract")
  }
  if !(contract.expand([]) is Err(MissingRequired("id"))) {
    abort("required id must be checked before rendering")
  }
  if !(contract.expand([("id", List(["wrong shape"]))])
    is Err(WrongKind("id", TextValue))) {
    abort("list cannot replace a scalar id")
  }
  match
    contract.expand([
      ("id", Scalar("team/a")),
      ("fields", List(["name", "email"])),
    ]) {
    Ok(uri) => {
      if uri != "/users/team%2Fa?fields=name&fields=email" {
        abort("incorrect encoding")
      }
      println(uri)
    }
    Err(_) => abort("valid SDK arguments rejected")
  }
  println("Parameter contract: required, shape and encoding checks passed")
}

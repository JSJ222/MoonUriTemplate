///|
/// An MCP client can instantiate an advertised resource URI template.
fn main {
  let template = match @uri_template.parse("repo://{org}/{project}{/path*}") {
    Ok(value) => value
    Err(error) => { println(error.message()); return }
  }
  let values : Array[(String, @uri_template.Value)] = [
    ("org", Scalar("moonbit")),
    ("project", Scalar("docs")),
    ("path", List(["guides", "getting started.mbt.md"])),
  ]
  match template.expand(values) {
    Ok(uri) => println(uri)
    Err(error) => println(error.message())
  }
}

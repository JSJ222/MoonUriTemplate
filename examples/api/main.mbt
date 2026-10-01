///|
/// An API client expands path and optional query parameters at call time.
fn main {
  let template = match
    @uri_template.parse("https://api.example.test/users/{id}{?fields*,limit}") {
    Ok(value) => value
    Err(error) => {
      println(error.message())
      return
    }
  }
  let values : Array[(String, @uri_template.Value)] = [
    ("id", Scalar("team/a")),
    ("fields", List(["name", "email"])),
    ("limit", Scalar("20")),
  ]
  match template.expand(values) {
    Ok(uri) => println(uri)
    Err(error) => println(error.message())
  }
}

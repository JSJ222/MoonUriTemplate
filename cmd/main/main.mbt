///|
/// Entry point for a minimal executable example.
fn main {
  match
    @uri_template.expand("https://example.test/search{?q,page}", [
      ("q", Scalar("MoonBit URI Templates")),
      ("page", Scalar("1")),
    ]) {
    Ok(uri) => println(uri)
    Err(_) => println("template expansion failed")
  }
}

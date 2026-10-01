///|
/// A service can compile a link template once and reuse it for many records.
fn main {
  let template = match @uri_template.parse("https://shop.example.test/orders/{order}{?locale}") {
    Ok(value) => value
    Err(error) => { println(error.message()); return }
  }
  for order in ["2026-001", "2026/002"] {
    let values : Array[(String, @uri_template.Value)] = [
      ("order", Scalar(order)),
      ("locale", Scalar("zh-CN")),
    ]
    match template.expand(values) {
      Ok(uri) => println(uri)
      Err(error) => println(error.message())
    }
  }
}

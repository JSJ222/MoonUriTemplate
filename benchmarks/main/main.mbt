///|
/// Fixed-workload benchmark. Measure wall time around `moon run` with a warm
/// build; printing the checksum prevents the result from being discarded.
fn main {
  let template = match @uri_template.parse("/users/{id}{?fields*,lang,limit}") {
    Ok(value) => value
    Err(_) => {
      println("parse failed")
      return
    }
  }
  let mut checksum = 0
  for i in 0..<20000 {
    let values : Array[(String, @uri_template.Value)] = [
      ("id", Scalar("team/" + i.to_string())),
      ("fields", List(["name", "email", "profile"])),
      ("lang", Scalar("zh-CN")),
      ("limit", Scalar("50")),
    ]
    match template.expand(values) {
      Ok(uri) => checksum += uri.length()
      Err(_) => {
        println("expand failed")
        return
      }
    }
  }
  println(checksum)
}

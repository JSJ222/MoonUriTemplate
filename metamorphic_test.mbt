///|
test "measure and render agree for operators and value shapes" {
  let operators = ["", "+", "#", ".", "/", ";", "?", "&"]
  let values : Array[@moonuritemplate.Value] = [
    Scalar(""),
    Scalar("a/b % é"),
    Scalar("%E4%B8%89/😀"),
    List([]),
    List(["", "a/b", "é"]),
    Assoc([]),
    Assoc([("a/b", ""), ("é", "x y")]),
    SparseList([None, Some("a/b"), Some("")]),
    SparseAssoc([("skip", None), ("é", Some("a/b"))]),
  ]
  for op in operators {
    for explode in ["", "*"] {
      let source = "x{" + op + "v" + explode + "}y"
      let template = match @moonuritemplate.parse(source) {
        Ok(value) => value
        Err(_) => fail("generated template syntax")
      }
      for value in values {
        let bindings : Array[(String, @moonuritemplate.Value)] = [("v", value)]
        let output = match template.expand(bindings) {
          Ok(result) => result
          Err(_) => fail("render matrix")
        }
        let length = match template.measure(bindings) {
          Ok(result) => result
          Err(_) => fail("measure matrix")
        }
        assert_eq(length, output.length())
        for budget in [0, 1, 2, 4, 8, 16] {
          let measured = template.measure(bindings, max_output=budget)
          let rendered = template.expand(bindings, max_output=budget)
          match (measured, rendered) {
            (Ok(size), Ok(text)) => assert_eq(size, text.length())
            (Err(left), Err(right)) => assert_eq(left.code(), right.code())
            _ => fail("budget paths disagree: " + source)
          }
        }
      }
    }
  }
}

///|
test "prefix measurement agrees with Unicode and percent triplets" {
  let samples = [
    "école", "😀/x", "%E4%B8%89x", "%F0%9F%98%80x", "%ED%A0%80x", "%x", "hello world",
  ]
  for length in 1..<=6 {
    let source = "{+v:" + length.to_string() + "}"
    let template = match @moonuritemplate.parse(source) {
      Ok(value) => value
      Err(_) => fail("prefix syntax")
    }
    for sample in samples {
      let bindings : Array[(String, @moonuritemplate.Value)] = [
        ("v", Scalar(sample)),
      ]
      let output = match template.expand(bindings) {
        Ok(value) => value
        Err(_) => fail("prefix render")
      }
      let measured = match template.measure(bindings) {
        Ok(value) => value
        Err(_) => fail("prefix measure")
      }
      assert_eq(measured, output.length())
    }
  }
}

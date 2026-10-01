///|
/// A value supplied to an RFC 6570 variable. Associative entries retain order.
pub(all) enum Value {
  Scalar(String)
  List(Array[String])
  Assoc(Array[(String, String)])
  SparseList(Array[String?])
  SparseAssoc(Array[(String, String?)])
}

///|
/// A parse failure with a UTF-16 code-unit offset into the template.
pub(all) enum ParseError {
  InputTooLong
  InvalidUnicode(Int)
  InvalidLiteral(Int)
  UnclosedExpression(Int)
  NestedExpression(Int)
  EmptyExpression(Int)
  InvalidOperator(Int)
  InvalidVariable(Int)
  InvalidModifier(Int)
  TooManyExpressions
  TooManyVariables
}

///|
/// An expansion failure. The requested output limit is enforced before return.
pub(all) enum ExpandError {
  DuplicateVariable(String)
  InvalidValue(String)
  TooManyBindings
  ValueTooLong(String)
  TooManyItems(String)
  OutputTooLong
}

///|
/// A single-use expansion failed while parsing or while applying values.
pub(all) enum TemplateError {
  Parse(ParseError)
  Expand(ExpandError)
}

///|
pub enum Segment {
  Literal(String)
  Expression(Operator, Array[VarSpec])
}

///|
pub enum Operator {
  Simple
  Reserved
  Fragment
  Label
  Path
  PathParameter
  Query
  QueryContinuation
}

///|
pub struct VarSpec {
  name : String
  prefix : Int?
  explode : Bool
}

///|
/// A compiled template. Reuse it for many value sets.
pub struct Template {
  source : String
  segments : Array[Segment]
  variables : Array[String]
}

///|
/// Return the original template text.
pub fn Template::source(self : Template) -> String {
  self.source
}

///|
/// Return unique variable names in first-appearance order.
pub fn Template::variables(self : Template) -> Array[String] {
  self.variables.copy()
}

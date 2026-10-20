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
  InvalidUnicode(Int32)
  InvalidLiteral(Int32)
  UnclosedExpression(Int32)
  NestedExpression(Int32)
  EmptyExpression(Int32)
  InvalidOperator(Int32)
  InvalidVariable(Int32)
  InvalidModifier(Int32)
  TooManyExpressions
  TooManyVariables
}

///|
/// An expansion failure. The requested output limit is enforced before return.
pub(all) enum ExpandError {
  DuplicateVariable(String)
  MissingVariable(String)
  UnusedVariable(String)
  InvalidValue(String)
  TooManyBindings
  ValueTooLong(String)
  TooManyItems(String)
  InvalidLimit(String)
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
  Expression(Operator, Array[VarSpec], Int32, Int32)
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
  prefix : Int32?
  explode : Bool
  start : Int32
  end : Int32
}

///|
/// A compiled template. Reuse it for many value sets.
pub struct Template {
  priv source : String
  priv segments : Array[Segment]
  priv variables : Array[String]
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

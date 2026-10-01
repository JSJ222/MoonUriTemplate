///|
/// Return the UTF-16 code-unit offset of a parse error, if applicable.
pub fn ParseError::offset(self : ParseError) -> Int? {
  match self {
    InvalidUnicode(at)
    | InvalidLiteral(at)
    | UnclosedExpression(at)
    | NestedExpression(at)
    | EmptyExpression(at)
    | InvalidOperator(at)
    | InvalidVariable(at)
    | InvalidModifier(at) => Some(at)
    InputTooLong | TooManyExpressions | TooManyVariables => None
  }
}

///|
/// Stable machine-readable code for a parse error.
pub fn ParseError::code(self : ParseError) -> String {
  match self {
    InputTooLong => "input_too_long"
    InvalidUnicode(_) => "invalid_unicode"
    InvalidLiteral(_) => "invalid_literal"
    UnclosedExpression(_) => "unclosed_expression"
    NestedExpression(_) => "nested_expression"
    EmptyExpression(_) => "empty_expression"
    InvalidOperator(_) => "invalid_operator"
    InvalidVariable(_) => "invalid_variable"
    InvalidModifier(_) => "invalid_modifier"
    TooManyExpressions => "too_many_expressions"
    TooManyVariables => "too_many_variables"
  }
}

///|
/// Human-readable explanation without embedding the source text.
pub fn ParseError::message(self : ParseError) -> String {
  match self {
    InputTooLong => "template exceeds the configured length limit"
    InvalidUnicode(_) => "template contains an unpaired UTF-16 surrogate"
    InvalidLiteral(_) =>
      "literal contains a forbidden character or malformed percent triplet"
    UnclosedExpression(_) => "expression has no closing brace"
    NestedExpression(_) => "expression contains an opening brace"
    EmptyExpression(_) => "expression has no variable specification"
    InvalidOperator(_) => "operator is reserved or unsupported"
    InvalidVariable(_) => "variable name violates RFC 6570 syntax"
    InvalidModifier(_) => "variable modifier is invalid"
    TooManyExpressions => "template exceeds the expression limit"
    TooManyVariables => "template exceeds the variable specification limit"
  }
}

///|
/// Stable machine-readable code for an expansion error.
pub fn ExpandError::code(self : ExpandError) -> String {
  match self {
    DuplicateVariable(_) => "duplicate_variable"
    InvalidValue(_) => "invalid_value"
    TooManyBindings => "too_many_bindings"
    ValueTooLong(_) => "value_too_long"
    TooManyItems(_) => "too_many_items"
    OutputTooLong => "output_too_long"
  }
}

///|
/// Human-readable explanation without embedding variable values.
pub fn ExpandError::message(self : ExpandError) -> String {
  match self {
    DuplicateVariable(name) => "duplicate binding for variable " + name
    InvalidValue(name) => "invalid value for variable " + name
    TooManyBindings => "too many variable bindings"
    ValueTooLong(name) => "value exceeds the length limit for variable " + name
    TooManyItems(name) =>
      "composite value has too many items for variable " + name
    OutputTooLong => "expansion exceeds the configured output limit"
  }
}

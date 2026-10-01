///|
/// One brace expression in the source template. Offsets are UTF-16 code units.
pub(all) struct ExpressionInfo {
  start : Int
  end : Int
  operator : String
  level : Int
  variable_count : Int
  permits_reserved : Bool
}

///|
/// One occurrence of a variable specification, including its modifier.
pub(all) struct VariableUse {
  name : String
  start : Int
  end : Int
  expression_index : Int
  operator : String
  prefix : Int?
  explode : Bool
}

///|
/// Static summary of a compiled template. It does not inspect bound values.
pub struct TemplateAnalysis {
  expressions : Array[ExpressionInfo]
  uses : Array[VariableUse]
  max_level : Int
  has_reserved_expansion : Bool
}

///|
pub fn TemplateAnalysis::expressions(
  self : TemplateAnalysis,
) -> Array[ExpressionInfo] {
  self.expressions.copy()
}

///|
pub fn TemplateAnalysis::uses(self : TemplateAnalysis) -> Array[VariableUse] {
  self.uses.copy()
}

///|
/// Highest RFC 6570 feature level required by the template (1–4).
pub fn TemplateAnalysis::max_level(self : TemplateAnalysis) -> Int {
  self.max_level
}

///|
/// True if '+' or '#' allows reserved characters from a value into the URI.
pub fn TemplateAnalysis::has_reserved_expansion(
  self : TemplateAnalysis,
) -> Bool {
  self.has_reserved_expansion
}

///|
fn Operator::symbol(self : Operator) -> String {
  match self {
    Simple => ""
    Reserved => "+"
    Fragment => "#"
    Label => "."
    Path => "/"
    PathParameter => ";"
    Query => "?"
    QueryContinuation => "&"
  }
}

///|
fn Operator::level(self : Operator) -> Int {
  match self {
    Simple => 1
    Reserved | Fragment => 2
    Label | Path | PathParameter | Query | QueryContinuation => 3
  }
}

///|
pub fn Template::analyze(self : Template) -> TemplateAnalysis {
  let expressions : Array[ExpressionInfo] = []
  let uses : Array[VariableUse] = []
  let mut max_level = 1
  let mut has_reserved = false
  for segment in self.segments {
    match segment {
      Literal(_) => ()
      Expression(op, specs, start, end) => {
        let mut level = op.level()
        let permits_reserved = operator_allows_reserved(op)
        if permits_reserved {
          has_reserved = true
        }
        let expression_index = expressions.length()
        for spec in specs {
          if spec.explode || spec.prefix is Some(_) {
            level = 4
          }
          uses.push({
            name: spec.name,
            start: spec.start,
            end: spec.end,
            expression_index,
            operator: op.symbol(),
            prefix: spec.prefix,
            explode: spec.explode,
          })
        }
        if level > max_level {
          max_level = level
        }
        expressions.push({
          start,
          end,
          operator: op.symbol(),
          level,
          variable_count: specs.length(),
          permits_reserved,
        })
      }
    }
  }
  { expressions, uses, max_level, has_reserved_expansion: has_reserved, }
}

///|
/// Count how often a variable occurs in this template.
pub fn Template::reference_count(self : Template, name : String) -> Int {
  let mut count = 0
  for segment in self.segments {
    match segment {
      Literal(_) => ()
      Expression(_, specs, _, _) =>
        for spec in specs {
          if spec.name == name {
            count += 1
          }
        }
    }
  }
  count
}

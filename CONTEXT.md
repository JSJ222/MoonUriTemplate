# URI Template Expansion

This context describes reusable URI references with variable expressions and the values supplied to expand them.

## Language

**Template**:
A sequence of literal text and expressions that can be expanded into a URI reference.
_Avoid_: URL pattern, route

**Expression**:
A brace-delimited part of a template containing an operator and one or more variable specifications.
_Avoid_: placeholder

**Variable specification**:
A variable name and optional prefix or explode modifier within an expression.
_Avoid_: parameter definition

**Expansion value**:
A scalar, list, or associative value supplied for a variable at expansion time.
_Avoid_: route parameter

**Undefined variable**:
A variable absent from the supplied value set; it contributes no text to its expression.
_Avoid_: empty variable

**Empty value**:
A supplied value with zero content; its rendering depends on its type and the expression operator.
_Avoid_: undefined variable

# API Contracts and URI Expansion

This context describes reusable API operation contracts, their shared schema documents and the URI references used to construct requests.

## Contract language

**Contract workspace**:
A named collection of operation contracts and explicitly locked schema documents at one revision.
_Avoid_: server, API platform

**Operation contract**:
The declared request and response expectations for an operation identified independently of its URI.
_Avoid_: template contract, route

**Schema lock**:
The complete set of named schema documents available to resolve contract references offline.
_Avoid_: downloaded cache, registry

**Consumer case**:
A named request and optional response together with the consumer's expected validation outcome.
_Avoid_: compatibility proof, production traffic

**Upgrade gate**:
The decision combining change classification, explicit review and consumer evidence before adopting a candidate contract workspace.
_Avoid_: guaranteed backward compatibility

**Affected operation**:
An operation whose resolved expectations change or whose locked schema dependencies are updated.
_Avoid_: changed URL

## URI language

**Runtime contract**:
Opt-in required variables and value shapes for URI expansion.
_Avoid_: operation contract

**Link session**:
A catalog snapshot with captured shared bindings and expanded links.
_Avoid_: contract workspace

**Binding change**:
A set or removal of an expansion value within a link-session update.
_Avoid_: schema update

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

**Binding**:
An association between one template variable name and one expansion value.
_Avoid_: argument

**Undefined variable**:
A variable absent from the supplied value set; it contributes no text to its expression.
_Avoid_: empty variable

**Empty value**:
A supplied value with zero content; its rendering depends on its type and the expression operator.
_Avoid_: undefined variable

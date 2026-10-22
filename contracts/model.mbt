///|
pub(all) suberror WorkspaceError {
  Invalid(path~ : String, reason~ : String)
  Unsupported(path~ : String, feature~ : String)
  Budget(String)
}

///|
pub(all) struct WorkspaceLimits {
  documents : Int32
  operations : Int32
  depth : Int32
  nodes : Int32
  text_units : Int32
  resolved_nodes : Int32
  cases : Int32
  findings : Int32
} derive(Eq)

///|
pub extend WorkspaceLimits with Eq::{equal, not_equal}

///|
pub fn WorkspaceLimits::default() -> WorkspaceLimits {
  {
    documents: 128,
    operations: 1024,
    depth: 64,
    nodes: 200000,
    text_units: 4194304,
    resolved_nodes: 100000,
    cases: 4096,
    findings: 256,
  }
}

///|
pub(all) enum ParameterLocation {
  Path
  Query
  Header
  Cookie
} derive(Eq)

///|
pub extend ParameterLocation with Eq::{equal, not_equal}

///|
pub(all) struct ParameterValue {
  location : ParameterLocation
  name : String
  value : Json
}

///|
/// Inputs are already decoded and typed by the host HTTP adapter. None means
/// absent body; Some(Null) means an explicitly supplied JSON null.
pub(all) struct Request {
  parameters : Array[ParameterValue]
  body : Json?
  media_type : String?
}

///|
pub(all) struct Response {
  status : Int32
  headers : Array[(String, Json)]
  body : Json?
  media_type : String?
}

///|
pub(all) struct Violation {
  operation : String
  location : String
  instance_path : String
  schema_path : String
  code : String
} derive(Eq)

///|
pub extend Violation with Eq::{equal, not_equal}

///|
pub(all) struct ConsumerCase {
  name : String
  operation : String
  request : Request
  response : Response?
  expect_valid : Bool
}

///|
pub(all) struct CaseResult {
  name : String
  operation : String
  expected_valid : Bool
  actual_valid : Bool
  passed : Bool
  violations : Array[Violation]
}

///|
priv struct Parameter {
  location : ParameterLocation
  name : String
  required : Bool
  schema : @schema.Schema
}

///|
priv struct Content {
  media : Map[String, @schema.Schema]
  required : Bool
}

///|
priv struct ResponseRule {
  content : Content
  headers : Array[Parameter]
}

///|
priv struct Operation {
  name : String
  verb : String
  path : String
  parameters : Array[Parameter]
  request : Content
  responses : Map[String, ResponseRule]
  dependencies : Array[String]
  resolved : Json
}

///|
/// Immutable definitions and operation indexes. Validation calls must be
/// serialized: the reused upstream interpreter is not concurrently reentrant.
pub struct Workspace {
  priv documents : Map[String, Json]
  priv definitions : Array[Json]
  priv operations : Map[String, Operation]
  priv order : Array[String]
  priv reverse : Map[String, Array[String]]
  priv limits : WorkspaceLimits
  priv revision : Int32
}

///|
pub(all) struct DocumentChange {
  name : String
  document : Json?
}

///|
pub struct WorkspaceUpdate {
  priv next : Workspace
  priv changed : Array[String]
  priv rebuilt : Array[String]
}

///|
pub fn Workspace::revision(self : Workspace) -> Int32 {
  self.revision
}

///|
pub fn Workspace::operation_names(self : Workspace) -> Array[String] {
  self.order.copy()
}

///|
pub fn WorkspaceUpdate::workspace(self : WorkspaceUpdate) -> Workspace {
  self.next
}

///|
pub fn WorkspaceUpdate::changed_documents(
  self : WorkspaceUpdate,
) -> Array[String] {
  self.changed.copy()
}

///|
pub fn WorkspaceUpdate::rebuilt_operations(
  self : WorkspaceUpdate,
) -> Array[String] {
  self.rebuilt.copy()
}

///|
pub fn Workspace::operations_using(
  self : Workspace,
  document : String,
) -> Array[String] {
  self.reverse.get(document).unwrap_or([]).copy()
}

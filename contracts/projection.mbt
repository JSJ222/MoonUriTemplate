///|
/// Independently compilable operation subset with only its transitive resource
/// lock. Source order is retained; duplicates/unknown names are errors. This is
/// contract minimization, not an authorization or sensitive-field scrubber.
pub fn Workspace::project_operations(
  self : Workspace,
  selected : Array[String],
) -> Workspace raise WorkspaceError {
  if selected.length() > self.limits.operations {
    raise Budget("projection operations")
  }
  let wanted : Map[String, Bool] = Map([])
  let dependencies : Map[String, Bool] = Map([])
  for name in selected {
    need(!wanted.contains(name), "projection", "duplicate operation")
    let operation = self.operation(name)
    wanted[name] = true
    for resource in operation.dependencies {
      dependencies[resource] = true
    }
  }
  let definitions : Array[Json] = []
  for i, name in self.order {
    if wanted.contains(name) {
      definitions.push(self.definitions[i])
    }
  }
  let documents : Map[String, Json] = Map([])
  for name, _ in dependencies {
    documents[name] = self.documents[name]
  }
  compile_workspace(
    {
      "documents": Json::object(documents),
      "operations": Json::array(definitions),
    },
    limits=self.limits,
  )
}

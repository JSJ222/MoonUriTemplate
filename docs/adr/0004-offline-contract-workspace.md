# Separate API contract governance from URI expansion

RFC 6570 expansion already has mature ecosystem implementations; adding shallow presence rules is not an independent contract management offering. We retain the root URI API and add a `contracts` package owning offline schema locks, transitive operation dependencies, immutable atomic schema updates and conservative consumer upgrade gates; JSON Schema interpretation is deliberately reused from moonschema rather than copied or reinvented.

ADR 0001 and ADR 0003 still govern the URI package, not this new operation-contract model. The new importer supports a documented OpenAPI 3.1 JSON profile, projects component schemas into a separate lock, and requires reimport for operation declaration changes. Rejecting recursive/dynamic references and scope rebasing trades coverage for explicit offline ownership; arbitrary schema inclusion remains review rather than a false compatibility verdict. Shared interpreters require serial access.

# Contributor/Agent Guidelines

## Change discipline
- Keep changes minimal and coherent.
- Avoid breaking changes unless explicitly required.
- If an API changes, update docs, examples, and changelog notes accordingly.

## Referencing and rationale
- Include a short rationale for every non-trivial change in the PR/commit message.
- Reference the relevant issue/ticket when available.
- Link to upstream docs/specs when behavior is based on external standards.

## Tests policy
- Add or update tests for every behavior change.
- Remove tests only when the covered behavior is removed; explain why.
- Keep tests deterministic and fast.
- Use the appropriate test type (unit vs integration) and keep coverage close to the changed code.

## Build and verification requirements
- Run formatting and static analysis when applicable.
- Always run `dart test` before considering the work done.
- If multiple packages exist, run tests for the correct package(s).

## Definition of done checklist
- [ ] Code compiles.
- [ ] Public API reviewed.
- [ ] Docs updated (if needed).
- [ ] Tests added/updated/removed appropriately.
- [ ] `dart test` executed successfully (`dart test`).
- [ ] No unrelated diffs.

---
name: vendor-api-spec-sync
description: Update a library or SDK when its vendor API spec changes. Use when Codex needs to sync a repo to a newer upstream API tag, commit, submodule, protobuf/OpenAPI/GraphQL schema, or other vendored spec, regenerate derived code, adapt handwritten wrappers, update recorded upstream version metadata, and verify the result with builds or tests.
---

# Vendor API Spec Sync

Update a library from an upstream vendor spec revision without treating generated output as the whole task. Sync the spec input first, regenerate deterministically, reconcile compatibility drift, then verify the handwritten layer, docs, and tests still match the new API surface.

## Workflow

1. Inspect the current integration point.
   Look for vendored inputs such as git submodules, `vendor/`, `proto/`, `openapi/`, `schema/`, `Package.resolved`, generator configs, `Makefile`, and scripts that regenerate checked-in outputs.

2. Identify the exact upstream revision to adopt.
   Prefer a concrete tag or commit over “latest” if the repo already records upstream metadata. If the user asks for the latest revision, verify the actual tag or head first.

3. Diff the vendor spec before changing local code.
   Read the spec diff to understand whether the change is:
   - purely additive
   - a rename or shape change
   - a breaking removal
   - a generator/runtime compatibility change

4. Update the vendored source of truth.
   If the repo uses a submodule, move the submodule to the target revision and stage the gitlink.
   If it vendors copied files, replace only the authoritative inputs, not the generated outputs first.

5. Regenerate derived code using the repo’s own workflow.
   Prefer existing commands such as `make generate`, `buf generate`, `openapi-generator`, repo scripts, or package plugins. Do not hand-edit generated files unless the repository already requires a small compatibility patch after generation.

6. Reconcile handwritten code with the new surface.
   Search for wrappers, adapters, convenience APIs, tests, docs, and changelog/version metadata that mention the old API. Fix compile errors, renamed types, and newly required fields. If the repo exposes a public client, ensure the new upstream operation is reachable from that public surface.

7. Verify generator/runtime compatibility explicitly.
   Generated code can drift ahead of pinned runtime dependencies. If regeneration introduces incompatible output, decide whether to:
   - regenerate with the repo-pinned generator version
   - patch the generated output in the minimal compatible way
   - or upgrade the runtime dependency if the repo is prepared for that wider change

8. Verify the result.
   Run the narrowest reliable verification first, then broader verification:
   - targeted codegen/build command
   - package or library build
   - focused tests
   - full test suite if practical

9. Record the upstream change.
   Update README, `CHANGELOG.md`, `UPSTREAM.md`, release notes, or method lists when the repo keeps those documents. Mention the concrete upstream tag or commit in commit messages or metadata when useful.

10. Update `CHANGELOG.md` deliberately when the repo maintains one.
   Add a concise entry that describes the vendor spec bump and the user-visible API effect, such as a new RPC, endpoint, field, or breaking rename. If the changelog format is versioned, place the note under the correct unreleased or target version heading instead of appending free-form text.

## What To Inspect

- Submodule declarations in `.gitmodules`
- Vendor directories such as `vendor/`, `third_party/`, or `api/`
- Generator configs like `buf.gen.yaml`, `buf.yaml`, `openapi-generator-config.*`, `Makefile`, and repo scripts
- Checked-in generated targets
- Public wrapper layers on top of generated code
- Existing docs that enumerate supported endpoints or methods

## Decision Points

### Additive upstream change

Regenerate, expose the new type or method, and update any public API inventory docs. Usually this should not require broader refactors unless the repo intentionally wraps every endpoint manually.

### Breaking upstream change

Find all references to removed or reshaped fields and update the handwritten layer first. Do not assume generated compile success means the package behavior is still correct.

### Generator mismatch

If the generated code no longer compiles against pinned runtime packages, inspect both the generator output and the runtime API. Prefer the smallest change that preserves the intended upstream sync:

- use the generator version implied by the repo lockfile or checked-out dependency
- keep post-generation compatibility patches tiny and explicit
- avoid silent manual edits that obscure the true source-of-truth spec change

## Output Expectations

When using this skill, aim to leave the repo with:

- the vendor spec source updated to the intended upstream revision
- regenerated derived code checked in if the repo tracks it
- handwritten code adapted to the new or changed API
- changelog or release notes updated when the repo expects them
- verification completed or clearly reported
- upstream version/tag information documented where the repo expects it

## Practical Heuristics

- Prefer local upstream clones, submodules, or official vendor repos over secondary summaries.
- Read the repo’s existing generation path before inventing one.
- Treat generated files as derived artifacts, not primary design surfaces.
- Keep manual edits to generated files rare, minimal, and justified by compatibility constraints.
- If an unrelated dirty worktree exists, avoid touching it.
- If the repo expects commits for meaningful changes, commit the sync once the update and verification are complete.

# Non-Goals

Transom's value comes from a narrow role: making OCaml a first-class backend/application-logic language for desktop WebView apps.

## Boundaries

Transom is not:

- a native GUI toolkit;
- a custom renderer;
- a WebView implementation;
- a Tauri replacement;
- a complete Tauri API wrapper;
- a frontend framework;
- a project to make users write UI in OCaml;
- ReasonML/Melange/js_of_ocaml-first;
- npm-first;
- TypeScript-only;
- a package manager;
- a way to hide all non-OCaml tooling;
- a project to support every WebView host before the first host works.

## Why Not OCaml Frontend First?

OCaml-authored frontends may be useful later, but the immediate ecosystem gap is different: allowing developers to use mature web UI stacks while writing backend/application logic in OCaml.

Making OCaml frontend authoring the default would reintroduce the same UI-library limitations that Transom is meant to avoid. Transom should let the UI use web tools while giving OCaml a clear role where it is strong.

## Tauri Boundary

Tauri is the first host because it is a practical desktop WebView shell with a sidecar packaging path. Transom should support that workflow deeply enough for OCaml sidecars to be ergonomic.

That does not mean Transom should wrap every Tauri API, replace the Tauri CLI, own Tauri permissions, replace Tauri plugins, or abstract every host feature.

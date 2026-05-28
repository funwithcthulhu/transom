# Non-Goals

Transom has a narrow role: using OCaml for backend/application logic in desktop WebView apps.

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

OCaml-authored frontends may be useful later, but the immediate ecosystem gap is different: allowing developers to use existing web UI tools while writing backend/application logic in OCaml.

Making OCaml frontend authoring the default would reintroduce the same UI-library limitations that Transom is meant to avoid. Transom should keep OCaml on backend/application logic unless a project explicitly chooses otherwise.

## Tauri Boundary

Tauri is the first host because it has a desktop WebView shell and a sidecar packaging path. Transom should support that workflow enough for the OCaml sidecar path to be usable.

That does not mean Transom should wrap every Tauri API, replace the Tauri CLI, own Tauri permissions, replace Tauri plugins, or abstract every host feature.

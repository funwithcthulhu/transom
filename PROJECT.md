# Project Notes

Transom is scoped to the OCaml sidecar boundary in desktop WebView apps. The
first host target is Tauri. The frontend remains ordinary TypeScript or
JavaScript; the native sidecar is OCaml.

## Current Direction

- newline-delimited JSON protocol;
- manifest-driven command definitions;
- generated OCaml dispatch code;
- generated TypeScript client calls;
- minimal Tauri development template;
- small CLI checks and generation commands.

## Boundaries

Transom should own:

- OCaml sidecar runtime;
- typed IPC protocol;
- manifest validation;
- generated OCaml server glue;
- generated TypeScript client glue;
- template sanity checks.

Transom should not own:

- UI rendering;
- frontend framework design;
- full Tauri API coverage;
- package management;
- WebView implementation;
- alternate transports before the Tauri path is stable.

## Near-Term Work

- keep protocol and manifest parsing well tested;
- compile-check generated OCaml output;
- keep the minimal sidecar template buildable;
- document packaging limits once the development proof is stable.

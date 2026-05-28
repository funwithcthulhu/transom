# Roadmap

This roadmap describes direction, not a compatibility promise. Keep v0.x small, testable, and honest about what works.

## v0.1: Protocol/Codegen/Template Foundation

Status: current initial release.

Purpose: establish the basic package shape and code-generation foundation.

Scope:

- runtime protocol;
- structured errors;
- stdio server loop;
- manifest validation;
- generated OCaml server glue;
- generated TypeScript client glue;
- CLI commands;
- one minimal project template.

Excluded:

- complete Tauri sidecar bridge;
- production packaging;
- full typed streaming semantics;
- OCaml frontend/UI support;
- full Tauri API wrapper.

## v0.2: Real Tauri + TypeScript UI + OCaml Sidecar Proof

Status: in progress on the features branch.

Purpose: prove that a desktop WebView app can call native OCaml backend/application logic end-to-end.

Scope:

- Tauri command or bridge code that calls the OCaml sidecar;
- frontend request reaches OCaml sidecar;
- OCaml response reaches frontend;
- minimal TypeScript UI;
- sidecar launch/configuration guidance;
- clear smoke test or manual test instructions.

Excluded:

- complete Tauri API bindings;
- React/Svelte/Vue templates;
- production release packaging;
- Electron/Neutralino adapters;
- OCaml frontend/UI support.

## v0.3: Typed IPC Hardening

Purpose: make the frontend/OCaml boundary typed, generated, and easier to inspect.

Scope:

- manifest format refinements;
- generated OCaml server stubs;
- generated TypeScript client;
- structured errors;
- request/response calls;
- protocol tests;
- generated code readability;
- check command improvements.

Optional:

- streaming events;
- cancellation protocol.

Excluded:

- custom binary protocol;
- large schema language;
- complete host API bindings;
- npm package;
- Tauri plugin.

## v0.4: Streaming, Cancellation, and Long-Running Work

Purpose: support real desktop app backend workloads.

Scope:

- long-running OCaml tasks;
- frontend progress events;
- cancellation messages;
- structured task errors;
- sidecar lifecycle handling;
- test fixture for streaming protocol.

Excluded:

- forced Eio/Lwt/Async dependency;
- custom scheduler;
- binary IPC.

## v0.5: Non-Trivial Desktop App Template

Purpose: move beyond toy examples.

Scope: build one representative example app:

- file indexer;
- log viewer;
- compiler playground;
- static-analysis GUI;
- local-first search app.

The example must use:

- WebView UI;
- OCaml sidecar logic;
- typed IPC;
- long-running operation;
- progress events;
- visible structured errors.

Excluded:

- toy-only counter flagship;
- overbroad template collection.

## v0.6: Packaging and Developer Workflow Hardening

Purpose: make the Tauri-first workflow reliable enough for early users.

Scope:

- sidecar naming helper;
- release sanity checks;
- better doctor command;
- target-specific packaging notes;
- CI smoke tests where practical;
- clearer host-adapter boundaries.

Excluded:

- claiming full cross-platform support without tests;
- full Tauri CLI replacement;
- full Tauri plugin system.

## v1.0: Stable Tauri-First OCaml Backend Workflow

Purpose: provide a stable foundation for building desktop WebView apps with OCaml backend/application logic.

Scope:

- opam package;
- stable CLI basics;
- tested Tauri-first template;
- typed IPC/codegen;
- structured errors;
- streaming/cancellation if mature;
- at least one maintained example app with documented build/run steps;
- documented upgrade policy;
- clear non-goals;
- clear host adapter architecture.

## Post-v1 Possibilities

- React/Svelte/Vue templates;
- npm frontend runtime package;
- Tauri plugin;
- Electron adapter;
- Neutralino adapter;
- direct WebView adapter;
- Melange/js_of_ocaml optional frontend path;
- additional host API helpers.

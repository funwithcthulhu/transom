# Project Direction

## Problem

OCaml is strong for backend/application logic: parsers, compilers, analyzers, static-analysis tools, local data processing, typed domain models, and complex local workflows.

Modern desktop UI is usually better served by WebView and web frontend ecosystems than by current OCaml-native GUI libraries. The web ecosystem has more mature layout, styling, accessibility, and component options.

Tauri's normal model gives users a WebView frontend and Rust-side shell/backend logic. That works well for many apps, but it leaves OCaml developers without an ergonomic path for using native OCaml as the backend/application-logic layer inside desktop WebView apps.

## Solution

Transom lets the UI use the best available web frontend stack while backend/application logic is written in OCaml.

The frontend and OCaml sidecar communicate through generated typed IPC. Transom starts with Tauri because Tauri provides a practical WebView desktop shell and sidecar packaging path.

Transom should avoid becoming a full Tauri API wrapper. Its job is the OCaml sidecar workflow and the typed boundary around it.

## Three-Layer Model

Host/shell:

- Tauri first.
- Future host adapters are possible after the first host works.

Frontend/UI:

- TypeScript, JavaScript, React, Svelte, Vue, Solid, plain HTML/CSS/JS, or any suitable web frontend stack.

Backend/application logic:

- Native OCaml sidecar.

Bridge:

- typed IPC;
- generated frontend client;
- generated OCaml server glue.

## What Transom Should Own

Transom should own:

- project templates;
- OCaml sidecar runtime;
- typed IPC protocol;
- manifest/schema for commands;
- generated OCaml server glue;
- generated frontend client glue;
- structured errors;
- streaming progress/events eventually;
- cancellation protocol eventually;
- sidecar packaging conventions;
- dev/check/doctor commands;
- real example apps.

## What Transom Should Not Own

Transom should not own:

- UI rendering;
- native widgets;
- frontend framework design;
- complete Tauri API surface;
- OS API abstraction layer;
- WebView implementation;
- package management;
- npm ecosystem;
- Rust/Tauri internals.

## Complete Tauri Integration?

The goal is not "complete Tauri integration."

The goal is "complete enough Tauri integration to make OCaml sidecar backends ergonomic in Tauri desktop apps."

This means Transom should support:

- sidecar setup;
- generated bridge code;
- frontend-to-OCaml calls;
- OCaml-to-frontend events eventually;
- structured errors;
- streaming progress eventually;
- cancellation eventually;
- dev workflow;
- packaging sanity checks.

But Transom should not attempt to:

- wrap every Tauri API;
- replace the Tauri CLI;
- replace Tauri plugins;
- own Tauri permissions beyond templates and checks;
- abstract every host feature.

## Frontend Stance

TypeScript and plain web UI should be the first default path. React, Svelte, Vue, and Solid templates may be added later.

Transom should not require users to write frontend code in OCaml. OCaml-authored frontend support through Melange or js_of_ocaml can be a future optional path, but it is not a current v0.x priority.

## Long-Term Identity

Transom's durable value is making OCaml a first-class backend/application-logic language for desktop WebView apps.

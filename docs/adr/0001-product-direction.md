# ADR 0001: Product direction

Status: Accepted

## Context

Desktop WebView apps separate shell, frontend, and backend/application logic. The shell owns windows and packaging. The frontend owns UI. Backend/application logic owns local work, domain rules, parsing, analysis, and data processing.

Tauri's usual model uses a WebView frontend and Rust-side shell/backend logic. That is a practical default, but it is not the only useful split.

OCaml is strong for backend/application logic, compilers, analyzers, parsers, local tools, and type-heavy domains. Current OCaml-native desktop UI libraries are not the foundation Transom wants to build on. Web frontend ecosystems are better for UI breadth and component availability.

The missing piece is an ergonomic OCaml backend/application-logic path inside desktop WebView apps.

## Decision

Transom will focus on making OCaml a first-class backend/application-logic language for desktop WebView apps.

The first supported host will be Tauri. The first frontend path will be TypeScript/plain web UI.

Transom will connect frontend code to a native OCaml sidecar through typed IPC and generated glue.

OCaml-authored frontend support may be explored later, but it is not the initial focus.

## Consequences

Positive:

- avoids building a native GUI toolkit;
- avoids forcing users into weak OCaml UI libraries;
- lets users use mature web frontend stacks;
- gives OCaml a clear role where it is strong;
- makes serious local desktop tools easier to build in OCaml;
- keeps future host adapters possible.

Negative:

- generated apps require non-OCaml tooling such as npm and Tauri;
- Rust remains present in the Tauri shell;
- sidecar packaging must be handled carefully;
- frontend developers may still need TypeScript/JavaScript knowledge;
- Transom must maintain generated bridge code and protocol compatibility.

## Non-Decisions

- exact manifest/schema format;
- whether to use ATD long-term;
- whether to publish an npm package;
- whether to build a Tauri plugin;
- whether to support Electron, Neutralino, or direct WebView hosts;
- whether to support OCaml-authored frontend code later;
- how broad Tauri host helpers should become.

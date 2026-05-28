# Transom

Transom is a toolkit for building desktop WebView apps with OCaml backend/application logic, typed IPC, and modern web frontends.

The project is early. The current `v0.1.0` release establishes protocol, code generation, CLI, and template foundations. It does not yet provide production-ready Tauri sidecar integration or a complete end-to-end desktop app workflow.

## Who It Is For

Transom is for developers who want a desktop app with a normal web UI, but want serious backend/application logic in native OCaml instead of Rust, Node, Python, or shell scripts.

Good fits include compiler playgrounds, static-analysis GUIs, file indexers, log viewers, local-first search tools, database/admin tools, research tools, and apps with parsers, analyzers, typed domain models, or complex local workflows.

## What It Solves

Modern WebView apps have a useful split: a web frontend for UI, a desktop shell for windows and packaging, and backend/application logic for local work. Tauri normally puts much of that local logic in Rust.

Transom keeps the web frontend path open while making OCaml the backend/application-logic layer. The boundary is generated typed IPC between frontend code and a native OCaml sidecar.

## v0.1.0 Scope

The initial release provides:

- runtime protocol types;
- structured errors;
- a newline-delimited JSON stdio loop;
- a JSON manifest parser;
- generated OCaml server glue;
- generated TypeScript client glue;
- CLI commands;
- one minimal project template.

The template is intentionally plain. Users bring their own ATD files and ATD-generated JSON codecs.

## Install From Source

```sh
opam install . --deps-only
dune build @all
dune install
```

During development, run the CLI without installing it:

```sh
dune exec transom -- version
```

## v0.1.0 Quickstart

Create a project from the minimal template:

```sh
transom new hello
cd hello/backend
```

Generate ATD codecs and Transom glue:

```sh
opam install atdgen
atdgen -t -o bin/api api.atd
atdgen -j -o bin/api api.atd
transom gen --manifest transom.json --out bin
dune build
```

The current CLI does not run npm, Cargo, opam, or Dune for you.

## Intended Future Flow

This is the direction, not the current `v0.1.0` CLI:

```sh
opam install transom
transom new myapp --host tauri --ui typescript --backend ocaml
cd myapp
npm install
npm run tauri dev
```

## Manifest

Transom uses JSON for v0.x:

```json
{
  "service_module": "Api_server",
  "types_module": "Api_t",
  "json_module": "Api_j",
  "typescript_types_module": "./api_types",
  "commands": [
    {
      "name": "ping",
      "request": "ping_req",
      "response": "ping_res",
      "ts_request": "PingReq",
      "ts_response": "PingRes"
    }
  ]
}
```

The generator writes:

```sh
transom gen --manifest transom.json --out generated
```

This creates `api_server.mli`, `api_server.ml`, and `api_client.ts`. Names in the manifest are generated directly into OCaml and TypeScript, so `transom check` rejects names that are not valid identifiers for the generated code.

## CLI

```sh
transom version
transom paths
transom doctor
transom check --manifest transom.json
transom gen --manifest transom.json --out generated
transom new NAME --template minimal
```

## What Transom Is Not

Transom is not an OCaml frontend/UI framework, a native GUI toolkit, a custom renderer, a WebView implementation, a full Tauri wrapper, or a Tauri replacement. It is not trying to replace Rust inside Tauri. It is not npm-first, TypeScript-only, or an attempt to hide every non-OCaml tool.

See [PROJECT.md](PROJECT.md), [ROADMAP.md](ROADMAP.md), and [NON_GOALS.md](NON_GOALS.md) for the project direction.

# Transom

Transom is a toolkit for building desktop WebView apps with OCaml backend/application logic, typed IPC, and modern web frontends.

The project is early. The `v0.1.0` release established the protocol, code generation, CLI, and template foundation. This branch is the v0.2 work-in-progress: a plain TypeScript Tauri UI calling a native OCaml sidecar over newline-delimited JSON.

The v0.2 template is a development proof, not production packaging.

## Who It Is For

Transom is for developers who want a desktop app with a web UI, but want backend/application logic in native OCaml instead of Rust, Node, Python, or shell scripts.

Good fits include compiler playgrounds, static-analysis GUIs, file indexers, log viewers, local-first search tools, database/admin tools, research tools, and apps with parsers, analyzers, typed domain models, or complex local workflows.

## What It Solves

A WebView desktop app usually separates frontend/UI, host/shell, and local application logic. Tauri normally puts much of that local logic in Rust.

Transom keeps the web frontend path open while making OCaml the backend/application-logic layer. The boundary is generated typed IPC between frontend code and a native OCaml sidecar.

## Current v0.1/v0.2 Status

The codebase currently provides:

- runtime protocol types;
- structured errors;
- a newline-delimited JSON stdio loop;
- a JSON manifest parser;
- generated OCaml server glue;
- generated TypeScript client glue;
- CLI commands;
- one minimal project template;
- a basic Tauri command that keeps one OCaml sidecar process and calls it for request/response IPC.

The template is intentionally plain. Users bring their own ATD files and ATD-generated JSON codecs. Streaming, cancellation, and production sidecar packaging are still future work.

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

## Intended v0.2 Smoke Test

On the feature branch, the minimal template includes a basic Tauri command that talks to a persistent OCaml sidecar process. Generate the app and backend first:

```sh
transom new hello-transom
cd hello-transom/backend
opam install atdgen
atdgen -t -o bin/api api.atd
atdgen -j -o bin/api api.atd
transom gen --manifest transom.json --out bin
dune build
```

You can test the sidecar directly:

```sh
printf '%s\n' '{"kind":"call","id":1,"method":"ping","params":{"message":"hello"}}' | ./_build/default/bin/main
```

Expected output is one JSON response frame:

```json
{"kind":"ok","id":1,"result":{"message":"pong: hello"}}
```

Then copy the generated TypeScript client and run the Tauri app:

```sh
cd ..
cp backend/bin/api_client.ts frontend/src/api_client.ts
TRANSOM_SIDECAR="$PWD/backend/_build/default/bin/main" npm install --prefix frontend
TRANSOM_SIDECAR="$PWD/backend/_build/default/bin/main" npm --prefix frontend run dev
```

In PowerShell, use `main.exe`:

```powershell
Copy-Item backend\bin\api_client.ts frontend\src\api_client.ts
$env:TRANSOM_SIDECAR = "$PWD\backend\_build\default\bin\main.exe"
npm install --prefix frontend
npm --prefix frontend run dev
```

The frontend has a Ping button. A successful click should show the response from the OCaml handler. The Rust bridge is request/response only. `TRANSOM_SIDECAR` is a development path to the built backend executable. Cross-platform sidecar naming, production bundling, streaming, and cancellation are not complete yet.
The current CLI does not run npm, Cargo, opam, or Dune for you.

## Manifest

Transom uses JSON for v0.x. A minimal manifest looks like this:

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

`transom gen --manifest transom.json --out generated` creates `api_server.mli`, `api_server.ml`, and `api_client.ts`. Names in the manifest are generated directly into OCaml and TypeScript, so `transom check` rejects names that are not valid identifiers for the generated code.

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

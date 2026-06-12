# Transom

[![CI](https://github.com/funwithcthulhu/transom/actions/workflows/ci.yml/badge.svg)](https://github.com/funwithcthulhu/transom/actions/workflows/ci.yml)
[![opam](https://badgen.net/opam/v/transom)](https://opam.ocaml.org/packages/transom/)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Transom is a small OCaml runtime and code generator for newline-delimited JSON
IPC between a TypeScript desktop UI and a native OCaml sidecar. The current
0.2 branch focuses on a minimal Tauri development proof, generated OCaml
dispatch, and generated TypeScript client calls.

The project is early. The Tauri template is for development smoke tests, not
production sidecar packaging.

## Scope

Current pieces:

- runtime protocol types and structured errors;
- stdio loop for newline-delimited JSON frames;
- JSON manifest validation;
- generated OCaml server glue;
- generated TypeScript client glue;
- CLI commands;
- one minimal Tauri-oriented template.

Not in scope:

- full Tauri API wrapper;
- general desktop framework;
- OCaml frontend toolkit;
- production packaging;
- alternate transports.

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

## Development

```sh
dune build @all
dune runtest
dune fmt
```

## Minimal Example

The checked-in OCaml example builds a stdio sidecar from an ATD file and a
Transom manifest:

```sh
dune build examples/minimal/main.exe
printf '%s\n' '{"kind":"call","id":1,"method":"echo","params":{"message":"hi"}}' | ./_build/default/examples/minimal/main.exe
```

Expected output:

```json
{"kind":"ok","id":1,"result":{"reply":"echo: hi"}}
```

## Template Smoke Test

The minimal template includes a small Tauri command that calls one OCaml sidecar
process. Generate the project and backend first:

```sh
transom new hello-transom
cd hello-transom/backend
opam install atdgen
atdgen -t -o bin/api api.atd
atdgen -j -o bin/api api.atd
transom gen --manifest transom.json --out bin
dune build
```

The sidecar can be tested directly:

```sh
printf '%s\n' '{"kind":"call","id":1,"method":"ping","params":{"message":"hello"}}' | ./_build/default/bin/main
```

Expected output:

```json
{"kind":"ok","id":1,"result":{"message":"pong: hello"}}
```

Then copy the generated TypeScript client and run the frontend:

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

The Rust bridge is request/response only. OS-specific sidecar naming,
production bundling, streaming, and cancellation are not complete yet. The CLI
does not run npm, Cargo, opam, or Dune for you.

For the longer local smoke check:

```powershell
powershell -File scripts/smoke-minimal-template.ps1
```

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

`transom gen --manifest transom.json --out generated` creates
`api_server.mli`, `api_server.ml`, and `api_client.ts`. Names in the manifest
are generated directly into OCaml and TypeScript, so `transom check` rejects
names that are not valid identifiers for the generated code.

## CLI

```sh
transom version
transom paths
transom doctor
transom check --manifest transom.json
transom gen --manifest transom.json --out generated
transom new NAME --template minimal
```

See [PROJECT.md](PROJECT.md) for the short project notes and near-term scope.

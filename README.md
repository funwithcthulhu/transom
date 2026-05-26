# Transom

Transom helps connect a Tauri/webview frontend to an OCaml native sidecar over newline-delimited JSON.

The v0.1 scope is small: a runtime protocol library, a manifest-driven code generator, a CLI, and one minimal project template. Users bring their own ATD files and ATD-generated JSON codecs.

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

## Quickstart

Create a project from the minimal template:

```sh
transom new hello
cd hello/backend
```

Generate ATD codecs and Transom glue:

```sh
atdgen -t -o bin/api api.atd
atdgen -j -o bin/api api.atd
transom gen --manifest transom.json --out bin
dune build
```

The template is intentionally plain. It does not run npm, Cargo, opam, or Dune for you.

## Manifest

Transom uses JSON for v0.1:

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

This creates `api_server.mli`, `api_server.ml`, and `api_client.ts`.

## CLI

```sh
transom version
transom paths
transom doctor
transom check --manifest transom.json
transom gen --manifest transom.json --out generated
transom new NAME --template minimal
```

`transom paths` prints template search paths in order:

1. `TRANSOM_TEMPLATE_DIR`
2. `./templates`
3. `$OPAM_SWITCH_PREFIX/share/transom/templates`

## Not In v0.1

Transom v0.1 does not implement a Tauri replacement, native GUI toolkit, schema language, webview host, async runtime integration, plugin system, npm package, or Cargo crate. It also does not parse `.atd` files. ATD codecs are supplied by the user.

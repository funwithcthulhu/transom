# Minimal Example

This example builds an OCaml stdio sidecar from an ATD file and a Transom manifest.

From the repository root:

```sh
dune build examples/minimal/main.exe
printf '%s\n' '{"kind":"call","id":1,"method":"echo","params":{"message":"hi"}}' | ./_build/default/examples/minimal/main.exe
```

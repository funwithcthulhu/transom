(lang dune 3.11)

(name transom)
(version 0.1.0)

(generate_opam_files false)

(package
 (name transom)
 (synopsis "OCaml sidecar glue for Tauri-style desktop apps")
 (description "Transom connects a Tauri/webview frontend to an OCaml sidecar over newline-delimited JSON.")
 (depends
  (ocaml (>= 5.1))
  (dune (>= 3.11))
  cmdliner
  yojson))

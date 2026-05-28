(lang dune 3.11)

(name transom)
(version 0.1.0)

(generate_opam_files false)

(package
 (name transom)
 (synopsis "OCaml backend/application logic for desktop WebView apps")
 (description "Transom helps desktop WebView frontends call native OCaml backend/application logic through typed IPC and generated glue.")
 (depends
  (ocaml (>= 5.1))
  (dune (>= 3.11))
  cmdliner
  yojson))

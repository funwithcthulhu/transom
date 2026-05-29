module Manifest = Manifest
module Gen_ocaml_server = Gen_ocaml_server
module Gen_ts_client = Gen_ts_client

let rec mkdir_p dir =
  if dir = "" || dir = Filename.dirname dir then Ok ()
  else if Sys.file_exists dir then
    if Sys.is_directory dir then Ok ()
    else Error (dir ^ " exists and is not a directory")
  else
    match mkdir_p (Filename.dirname dir) with
    | Error message -> Error message
    | Ok () -> (
        try Ok (Unix.mkdir dir 0o755)
        with Unix.Unix_error (err, _, _) ->
          Error (dir ^ ": " ^ Unix.error_message err))

let write_file path content =
  match mkdir_p (Filename.dirname path) with
  | Error message -> Error message
  | Ok () -> (
      try
        let output = open_out_bin path in
        Fun.protect
          ~finally:(fun () -> close_out_noerr output)
          (fun () -> output_string output content);
        Ok ()
      with Sys_error message -> Error message)

let generated_files manifest =
  let server =
    Gen_ocaml_server.lower_module_filename manifest.Manifest.service_module
  in
  [
    (server ^ ".mli", Gen_ocaml_server.interface manifest);
    (server ^ ".ml", Gen_ocaml_server.implementation manifest);
    ("api_client.ts", Gen_ts_client.implementation manifest);
  ]

let generate ~manifest_file ~out_dir =
  match Manifest.load_file manifest_file with
  | Error message -> Error message
  | Ok manifest ->
      let rec write acc = function
        | [] -> Ok (List.rev acc)
        | (name, content) :: rest -> (
            let path = Filename.concat out_dir name in
            match write_file path content with
            | Ok () -> write (path :: acc) rest
            | Error message -> Error message)
      in
      write [] (generated_files manifest)

let template_dirs ?cwd ?opam_switch_prefix ?env_template_dir () =
  let cwd = Option.value cwd ~default:(Sys.getcwd ()) in
  let add value acc =
    match value with None | Some "" -> acc | Some value -> value :: acc
  in
  []
  |> add
       (Option.map
          (fun prefix ->
            Filename.concat (Filename.concat prefix "share") "transom")
          opam_switch_prefix
       |> Option.map (fun share -> Filename.concat share "templates"))
  |> add (Some (Filename.concat cwd "templates"))
  |> add env_template_dir

let template_dirs_from_env ?cwd () =
  template_dirs ?cwd
    ?env_template_dir:(Sys.getenv_opt "TRANSOM_TEMPLATE_DIR")
    ?opam_switch_prefix:(Sys.getenv_opt "OPAM_SWITCH_PREFIX")
    ()

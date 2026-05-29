open Cmdliner

let version = "transom 0.1.0"
let print_lines lines = List.iter print_endline lines
let result_error message = Error (`Msg message)

let command_exists name =
  let command =
    if Sys.win32 then "where " ^ name ^ " >NUL 2>NUL"
    else "command -v " ^ name ^ " >/dev/null 2>&1"
  in
  Sys.command command = 0

let run_version () =
  print_endline version;
  Ok ()

let run_paths () =
  Transom_codegen.template_dirs_from_env () |> print_lines;
  Ok ()

let run_doctor () =
  let tools =
    [
      ("opam", true);
      ("dune", true);
      ("node", false);
      ("npm", false);
      ("cargo", false);
      ("rustc", false);
    ]
  in
  let statuses =
    List.map
      (fun (name, required) -> (name, required, command_exists name))
      tools
  in
  List.iter
    (fun (name, _, ok) ->
      Printf.printf "%-5s %s\n" name (if ok then "ok" else "missing"))
    statuses;
  match
    List.filter_map
      (fun (name, required, ok) ->
        if required && not ok then Some name else None)
      statuses
  with
  | [] -> Ok ()
  | missing ->
      result_error
        ("missing required OCaml tools: " ^ String.concat ", " missing)

let run_check manifest_file =
  match Transom_codegen.Manifest.load_file manifest_file with
  | Ok _ ->
      print_endline "ok";
      Ok ()
  | Error message -> result_error message

let run_gen manifest_file out_dir =
  match Transom_codegen.generate ~manifest_file ~out_dir with
  | Ok files ->
      print_lines files;
      Ok ()
  | Error message -> result_error message

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

let read_file path =
  let input = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr input)
    (fun () ->
      let length = in_channel_length input in
      really_input_string input length)

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

let replace_all text ~pattern ~replacement =
  let pattern_len = String.length pattern in
  let text_len = String.length text in
  let buffer = Buffer.create text_len in
  let rec loop index =
    if index > text_len - pattern_len then
      Buffer.add_substring buffer text index (text_len - index)
    else if String.sub text index pattern_len = pattern then (
      Buffer.add_string buffer replacement;
      loop (index + pattern_len))
    else (
      Buffer.add_char buffer text.[index];
      loop (index + 1))
  in
  if pattern_len = 0 then text
  else (
    loop 0;
    Buffer.contents buffer)

let replace_placeholders text replacements =
  List.fold_left
    (fun text (pattern, replacement) -> replace_all text ~pattern ~replacement)
    text replacements

let extension path =
  match String.rindex_opt path '.' with
  | None -> ""
  | Some index -> String.sub path index (String.length path - index)

let is_text_file path =
  match Filename.basename path with
  | "dune" | "dune-project" | "package.json" | "Cargo.toml" | "tauri.conf.json"
    ->
      true
  | _ ->
      List.mem (extension path)
        [ ".atd"; ".html"; ".json"; ".ml"; ".mli"; ".rs"; ".toml"; ".ts" ]

let copy_file ~replacements ~src ~dst =
  try
    let content = read_file src in
    let content =
      if is_text_file src then replace_placeholders content replacements
      else content
    in
    write_file dst content
  with Sys_error message -> Error message

let rec copy_dir ~replacements ~src ~dst =
  match mkdir_p dst with
  | Error message -> Error message
  | Ok () ->
      Sys.readdir src |> Array.to_list |> List.sort String.compare
      |> copy_entries ~replacements ~src ~dst

and copy_entries ~replacements ~src ~dst = function
  | [] -> Ok ()
  | name :: rest -> (
      let src_path = Filename.concat src name in
      let dst_path = Filename.concat dst name in
      let result =
        if Sys.is_directory src_path then
          copy_dir ~replacements ~src:src_path ~dst:dst_path
        else copy_file ~replacements ~src:src_path ~dst:dst_path
      in
      match result with
      | Ok () -> copy_entries ~replacements ~src ~dst rest
      | Error message -> Error message)

let split_words name =
  let flush current acc =
    if Buffer.length current = 0 then acc
    else
      let value = Buffer.contents current in
      Buffer.clear current;
      value :: acc
  in
  let current = Buffer.create (String.length name) in
  let acc = ref [] in
  String.iter
    (fun char ->
      if
        (char >= 'a' && char <= 'z')
        || (char >= 'A' && char <= 'Z')
        || (char >= '0' && char <= '9')
      then Buffer.add_char current char
      else acc := flush current !acc)
    name;
  List.rev (flush current !acc)

let capitalize_ascii word =
  match String.lowercase_ascii word with
  | "" -> ""
  | word ->
      String.mapi
        (fun index char ->
          if index = 0 then Char.uppercase_ascii char else char)
        word

let module_name name =
  let name =
    match split_words name with
    | [] -> "App"
    | words -> String.concat "" (List.map capitalize_ascii words)
  in
  match name.[0] with 'A' .. 'Z' -> name | _ -> "App" ^ name

let package_name name =
  match split_words name with
  | [] -> "app"
  | words -> String.concat "-" (List.map String.lowercase_ascii words)

let target_is_available ~force target =
  if not (Sys.file_exists target) then Ok ()
  else if not (Sys.is_directory target) then
    result_error (target ^ " exists and is not a directory")
  else if force then Ok ()
  else if Sys.readdir target = [||] then Ok ()
  else result_error (target ^ " already exists; use --force to overwrite files")

let find_template template =
  let rec loop = function
    | [] -> None
    | dir :: rest ->
        let path = Filename.concat dir template in
        if Sys.file_exists path && Sys.is_directory path then Some path
        else loop rest
  in
  loop (Transom_codegen.template_dirs_from_env ())

let run_new name template dir force =
  let target = Filename.concat dir name in
  match target_is_available ~force target with
  | Error _ as error -> error
  | Ok () -> (
      match find_template template with
      | None ->
          result_error
            ("template not found: " ^ template ^ "\nsearched:\n"
            ^ String.concat "\n" (Transom_codegen.template_dirs_from_env ()))
      | Some src -> (
          let replacements =
            [
              ("{{project_name}}", name);
              ("{{module_name}}", module_name name);
              ("Transom_template_module", module_name name);
              ("{{package_name}}", package_name name);
            ]
          in
          match copy_dir ~replacements ~src ~dst:target with
          | Ok () ->
              Printf.printf "created %s\n" target;
              Ok ()
          | Error message -> result_error message))

let manifest_arg =
  let doc = "Manifest file." in
  Arg.(required & opt (some file) None & info [ "manifest" ] ~docv:"FILE" ~doc)

let out_arg =
  let doc = "Output directory." in
  Arg.(required & opt (some string) None & info [ "out" ] ~docv:"DIR" ~doc)

let name_arg =
  let doc = "Project name." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"NAME" ~doc)

let template_arg =
  let doc = "Template name." in
  Arg.(value & opt string "minimal" & info [ "template" ] ~docv:"NAME" ~doc)

let dir_arg =
  let doc = "Parent directory for the new project." in
  Arg.(value & opt dir "." & info [ "dir" ] ~docv:"DIR" ~doc)

let force_arg =
  let doc = "Overwrite files in an existing target directory." in
  Arg.(value & flag & info [ "force" ] ~doc)

let term_result term = Term.term_result term
let cmd name doc term = Cmd.v (Cmd.info name ~doc) (term_result term)

let version_cmd =
  cmd "version" "Print the Transom version." Term.(const run_version $ const ())

let paths_cmd =
  cmd "paths" "Print template search paths." Term.(const run_paths $ const ())

let doctor_cmd =
  cmd "doctor" "Check for common local tools."
    Term.(const run_doctor $ const ())

let check_cmd =
  cmd "check" "Validate a Transom manifest."
    Term.(const run_check $ manifest_arg)

let gen_cmd =
  cmd "gen" "Generate OCaml server and TypeScript client glue."
    Term.(const run_gen $ manifest_arg $ out_arg)

let new_cmd =
  cmd "new" "Create a project from a template."
    Term.(const run_new $ name_arg $ template_arg $ dir_arg $ force_arg)

let main_cmd =
  Cmd.group
    (Cmd.info "transom" ~version:"0.1.0" ~doc:"Generate OCaml sidecar glue.")
    [ version_cmd; paths_cmd; doctor_cmd; check_cmd; gen_cmd; new_cmd ]

let () = exit (Cmd.eval main_cmd)

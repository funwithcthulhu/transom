let lower_module_filename name = String.lowercase_ascii name
let command_name command = Manifest.command_name_to_string command.Manifest.name
let ocaml_type value = Manifest.ocaml_type_to_string value
let ocaml_module value = Manifest.ocaml_module_to_string value

let handler_lines types_module command =
  let types_module = ocaml_module types_module in
  let name = command_name command in
  let request = ocaml_type command.Manifest.request in
  let response = ocaml_type command.Manifest.response in
  match command.Manifest.event with
  | None ->
      [
        Printf.sprintf "  val %s :" name;
        Printf.sprintf "    %s.%s ->" types_module request;
        Printf.sprintf "    (%s.%s, Transom_runtime.Error.t) result"
          types_module response;
      ]
  | Some event ->
      let event = ocaml_type event in
      [
        Printf.sprintf "  val %s :" name;
        Printf.sprintf "    %s.%s ->" types_module request;
        Printf.sprintf "    emit:(%s.%s -> unit) ->" types_module event;
        Printf.sprintf "    (%s.%s, Transom_runtime.Error.t) result"
          types_module response;
      ]

let handlers_module_type manifest =
  [ "module type HANDLERS = sig" ]
  @ List.concat_map
      (handler_lines manifest.Manifest.types_module)
      manifest.commands
  @ [ "end" ]

let dispatch_signature =
  [
    "  val dispatch :";
    "    method_:string ->";
    "    params:Yojson.Safe.t ->";
    "    emit:(Yojson.Safe.t -> unit) ->";
    "    (Yojson.Safe.t, Transom_runtime.Error.t) result";
    "";
    "  val run_stdio : unit -> unit";
  ]

let interface manifest =
  String.concat "\n"
    (handlers_module_type manifest
    @ [ ""; "module Make (_ : HANDLERS) : sig" ]
    @ dispatch_signature @ [ "end"; "" ])

let response_encode json_module command =
  let response = ocaml_type command.Manifest.response in
  Printf.sprintf "Yojson.Safe.from_string (%s.string_of_%s res)" json_module
    response

let request_decode json_module command =
  let request = ocaml_type command.Manifest.request in
  Printf.sprintf "%s.%s_of_string (Yojson.Safe.to_string params)" json_module
    request

let event_emit json_module event =
  let event = ocaml_type event in
  Printf.sprintf "emit (Yojson.Safe.from_string (%s.string_of_%s ev))"
    json_module event

let branch manifest command =
  let json_module = ocaml_module manifest.Manifest.json_module in
  let name = command_name command in
  let decode = request_decode json_module command in
  let encode = response_encode json_module command in
  let handler_lines =
    match command.Manifest.event with
    | None -> [ Printf.sprintf "         match H.%s req with" name ]
    | Some event ->
        [
          Printf.sprintf "         let emit_event ev = %s in"
            (event_emit json_module event);
          Printf.sprintf "         match H.%s req ~emit:emit_event with" name;
        ]
  in
  [
    Printf.sprintf "    | %S ->" name;
    "      (match";
    "         (try Ok";
    Printf.sprintf "                (%s)" decode;
    "          with exn -> Error (bad_request method_ exn))";
    "       with";
    "       | Error err -> Error err";
    "       | Ok req ->";
  ]
  @ handler_lines
  @ [
      Printf.sprintf "         | Ok res -> Ok (%s)" encode;
      "         | Error err -> Error err)";
    ]

let dispatch_prelude manifest =
  let uses_params = manifest.Manifest.commands <> [] in
  let uses_emit =
    List.exists
      (fun command -> Option.is_some command.Manifest.event)
      manifest.Manifest.commands
  in
  [ "  let dispatch ~method_ ~params ~emit =" ]
  @ (if uses_params then [] else [ "    let _ = params in" ])
  @ (if uses_emit then [] else [ "    let _ = emit in" ])
  @ [ "    match method_ with" ]

let implementation manifest =
  let branches = List.concat_map (branch manifest) manifest.Manifest.commands in
  String.concat "\n"
    (handlers_module_type manifest
    @ [
        "";
        "module Make (H : HANDLERS) = struct";
        "  let bad_request method_ exn =";
        "    Transom_runtime.Error.bad_request";
        "      (\"Invalid params for \" ^ method_ ^ \": \" ^ \
         Printexc.to_string exn)";
        "";
      ]
    @ dispatch_prelude manifest @ branches
    @ [
        "    | _ -> Error (Transom_runtime.Error.unknown_method method_)";
        "";
        "  let run_stdio () = Transom_runtime.run ~dispatch";
        "end";
        "";
      ])

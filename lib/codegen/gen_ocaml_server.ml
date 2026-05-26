let lower_module_filename name = String.lowercase_ascii name

let handler_lines types_module command =
  match command.Manifest.event with
  | None ->
    [ Printf.sprintf "  val %s :" command.name
    ; Printf.sprintf "    %s.%s ->" types_module command.request
    ; Printf.sprintf "    (%s.%s, Transom_runtime.Error.t) result" types_module command.response
    ]
  | Some event ->
    [ Printf.sprintf "  val %s :" command.name
    ; Printf.sprintf "    %s.%s ->" types_module command.request
    ; Printf.sprintf "    emit:(%s.%s -> unit) ->" types_module event
    ; Printf.sprintf "    (%s.%s, Transom_runtime.Error.t) result" types_module command.response
    ]

let handlers_module_type manifest =
  [ "module type HANDLERS = sig" ]
  @ List.concat_map (handler_lines manifest.Manifest.types_module) manifest.commands
  @ [ "end" ]

let dispatch_signature =
  [ "  val dispatch :"
  ; "    method_:string ->"
  ; "    params:Yojson.Safe.t ->"
  ; "    emit:(Yojson.Safe.t -> unit) ->"
  ; "    (Yojson.Safe.t, Transom_runtime.Error.t) result"
  ; ""
  ; "  val run_stdio : unit -> unit"
  ]

let interface manifest =
  String.concat
    "\n"
    (handlers_module_type manifest
     @ [ ""
       ; "module Make (H : HANDLERS) : sig"
       ]
     @ dispatch_signature
     @ [ "end"; "" ])

let response_encode json_module command =
  Printf.sprintf
    "Yojson.Safe.from_string (%s.string_of_%s res)"
    json_module
    command.Manifest.response

let request_decode json_module command =
  Printf.sprintf
    "%s.%s_of_string (Yojson.Safe.to_string params)"
    json_module
    command.Manifest.request

let event_emit json_module event =
  Printf.sprintf
    "emit (Yojson.Safe.from_string (%s.string_of_%s ev))"
    json_module
    event

let branch manifest command =
  let json_module = manifest.Manifest.json_module in
  let decode = request_decode json_module command in
  let encode = response_encode json_module command in
  let handler_lines =
    match command.Manifest.event with
    | None -> [ Printf.sprintf "         match H.%s req with" command.name ]
    | Some event ->
      [ Printf.sprintf "         let emit_event ev = %s in" (event_emit json_module event)
      ; Printf.sprintf "         match H.%s req ~emit:emit_event with" command.name
      ]
  in
  [ Printf.sprintf "    | %S ->" command.name
  ; "      (match"
  ; "         (try Ok"
  ; Printf.sprintf "                (%s)" decode
  ; "          with exn -> Error (bad_request method_ exn))"
  ; "       with"
  ; "       | Error err -> Error err"
  ; "       | Ok req ->"
  ]
  @ handler_lines
  @
  [ Printf.sprintf "         | Ok res -> Ok (%s)" encode
  ; "         | Error err -> Error err)"
  ]

let implementation manifest =
  let branches = List.concat_map (branch manifest) manifest.Manifest.commands in
  String.concat
    "\n"
    (handlers_module_type manifest
     @ [ ""
       ; "module Make (H : HANDLERS) = struct"
       ; "  let bad_request method_ exn ="
       ; "    Transom_runtime.Error.bad_request"
       ; "      (\"Invalid params for \" ^ method_ ^ \": \" ^ Printexc.to_string exn)"
       ; ""
       ; "  let dispatch ~method_ ~params ~emit ="
       ; "    match method_ with"
       ]
     @ branches
     @ [ "    | _ -> Error (Transom_runtime.Error.unknown_method method_)"
       ; ""
       ; "  let run_stdio () = Transom_runtime.run ~dispatch"
       ; "end"
       ; ""
       ])

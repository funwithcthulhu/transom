type command =
  { name : string
  ; request : string
  ; response : string
  ; event : string option
  ; ts_request : string
  ; ts_response : string
  ; ts_event : string option
  }

type t =
  { service_module : string
  ; types_module : string
  ; json_module : string
  ; typescript_types_module : string
  ; commands : command list
  }

let error message = Error message

let assoc path = function
  | `Assoc fields -> Ok fields
  | _ -> error (path ^ " must be an object")

let field path name fields =
  match List.assoc_opt name fields with
  | Some value -> Ok value
  | None -> error (path ^ "." ^ name ^ " is required")

let non_empty_string path = function
  | `String value when String.length value > 0 -> Ok value
  | `String _ -> error (path ^ " must be non-empty")
  | _ -> error (path ^ " must be a string")

let string_field path name fields =
  match field path name fields with
  | Error message -> error message
  | Ok value -> non_empty_string (path ^ "." ^ name) value

let optional_string_field path name fields =
  match List.assoc_opt name fields with
  | None -> Ok None
  | Some value ->
    (match non_empty_string (path ^ "." ^ name) value with
     | Ok value -> Ok (Some value)
     | Error message -> error message)

let command_of_yojson index json =
  let path = Printf.sprintf "commands[%d]" index in
  match assoc path json with
  | Error message -> error message
  | Ok fields ->
    let required name = string_field path name fields in
    let optional name = optional_string_field path name fields in
    (match
       required "name",
       required "request",
       required "response",
       optional "event",
       optional "ts_request",
       optional "ts_response",
       optional "ts_event"
     with
     | Ok name, Ok request, Ok response, Ok event, Ok ts_request, Ok ts_response, Ok ts_event ->
       Ok
         { name
         ; request
         ; response
         ; event
         ; ts_request = Option.value ts_request ~default:request
         ; ts_response = Option.value ts_response ~default:response
         ; ts_event = (match ts_event with Some _ -> ts_event | None -> event)
         }
     | Error message, _, _, _, _, _, _
     | _, Error message, _, _, _, _, _
     | _, _, Error message, _, _, _, _
     | _, _, _, Error message, _, _, _
     | _, _, _, _, Error message, _, _
     | _, _, _, _, _, Error message, _
     | _, _, _, _, _, _, Error message -> error message)

module Names = Set.Make (String)

let check_unique_names commands =
  let rec loop seen = function
    | [] -> Ok ()
    | command :: rest ->
      if Names.mem command.name seen then
        error ("duplicate command name: " ^ command.name)
      else
        loop (Names.add command.name seen) rest
  in
  loop Names.empty commands

let commands_of_yojson = function
  | `List commands ->
    let rec loop index acc = function
      | [] ->
        let commands = List.rev acc in
        (match check_unique_names commands with
         | Ok () -> Ok commands
         | Error message -> error message)
      | json :: rest ->
        (match command_of_yojson index json with
         | Ok command -> loop (index + 1) (command :: acc) rest
         | Error message -> error message)
    in
    loop 0 [] commands
  | _ -> error "commands must be an array"

let of_yojson json =
  match assoc "manifest" json with
  | Error message -> error message
  | Ok fields ->
    let required name = string_field "manifest" name fields in
    let typescript_types_module =
      match optional_string_field "manifest" "typescript_types_module" fields with
      | Ok (Some value) -> Ok value
      | Ok None -> Ok "./api_types"
      | Error message -> error message
    in
    (match
       required "service_module",
       required "types_module",
       required "json_module",
       typescript_types_module,
       field "manifest" "commands" fields
     with
     | Ok service_module, Ok types_module, Ok json_module, Ok typescript_types_module, Ok commands_json ->
       (match commands_of_yojson commands_json with
        | Ok commands ->
          Ok { service_module; types_module; json_module; typescript_types_module; commands }
        | Error message -> error message)
     | Error message, _, _, _, _
     | _, Error message, _, _, _
     | _, _, Error message, _, _
     | _, _, _, Error message, _
     | _, _, _, _, Error message -> error message)

let read_file path =
  let input = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr input)
    (fun () ->
       let length = in_channel_length input in
       really_input_string input length)

let load_file path =
  match read_file path with
  | exception Sys_error message -> error message
  | text ->
    (match Yojson.Safe.from_string text with
     | json -> of_yojson json
     | exception Yojson.Json_error message -> error ("invalid JSON: " ^ message))

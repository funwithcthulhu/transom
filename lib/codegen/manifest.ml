type command = {
  name : string;
  request : string;
  response : string;
  event : string option;
  ts_request : string;
  ts_response : string;
  ts_event : string option;
}

type t = {
  service_module : string;
  types_module : string;
  json_module : string;
  typescript_types_module : string;
  commands : command list;
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

let is_lower_start = function 'a' .. 'z' | '_' -> true | _ -> false
let is_upper_start = function 'A' .. 'Z' -> true | _ -> false

let is_identifier_start = function
  | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
  | _ -> false

let is_identifier_char = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
  | _ -> false

let words text = String.split_on_char ' ' text

let ocaml_keywords =
  words
    (String.concat " "
       [
         "and as assert begin class constraint do done downto else end";
         "exception external false for fun function functor if in include";
         "inherit initializer lazy let match method module mutable new nonrec";
         "object of open or private rec sig struct then to true try type";
         "val virtual when while with";
       ])

let ts_keywords =
  words
    (String.concat " "
       [
         "as async await break case catch class const continue debugger";
         "default delete do else enum export extends false finally for from";
         "function if import in instanceof let new null of return super switch";
         "this throw true try type typeof var void while with";
       ])

let valid_identifier ~start value =
  String.length value > 0
  && value <> "_"
  && start value.[0]
  && String.for_all is_identifier_char value

let valid_ocaml_value_name value =
  valid_identifier ~start:is_lower_start value
  && not (List.mem value ocaml_keywords)

let valid_ocaml_type_name = valid_ocaml_value_name

let valid_ts_identifier value =
  valid_identifier ~start:is_identifier_start value
  && not (List.mem value ts_keywords)

let valid_command_name value =
  valid_ocaml_value_name value && valid_ts_identifier value

let valid_ocaml_module_name value = valid_identifier ~start:is_upper_start value

let valid_ocaml_module_path value =
  match String.split_on_char '.' value with
  | [] -> false
  | segments -> List.for_all valid_ocaml_module_name segments

let validate_name path expected valid value =
  if valid value then Ok () else error (path ^ " must be " ^ expected)

let string_field path name fields =
  match field path name fields with
  | Error message -> error message
  | Ok value -> non_empty_string (path ^ "." ^ name) value

let optional_string_field path name fields =
  match List.assoc_opt name fields with
  | None -> Ok None
  | Some value -> (
      match non_empty_string (path ^ "." ^ name) value with
      | Ok value -> Ok (Some value)
      | Error message -> error message)

let validate_optional path expected valid = function
  | None -> Ok ()
  | Some value -> validate_name path expected valid value

let generated_helper_names = [ "bad_request"; "dispatch"; "run_stdio" ]

let validate_command_helper_name path command =
  if List.mem command.name generated_helper_names then
    error (path ^ ".name collides with generated helper: " ^ command.name)
  else Ok ()

let validate_command path command =
  match
    ( validate_name (path ^ ".name") "a lowercase OCaml/TypeScript identifier"
        valid_command_name command.name,
      validate_command_helper_name path command,
      validate_name (path ^ ".request") "an OCaml type identifier"
        valid_ocaml_type_name command.request,
      validate_name (path ^ ".response") "an OCaml type identifier"
        valid_ocaml_type_name command.response,
      validate_optional (path ^ ".event") "an OCaml type identifier"
        valid_ocaml_type_name command.event,
      validate_name (path ^ ".ts_request") "a TypeScript type identifier"
        valid_ts_identifier command.ts_request,
      validate_name (path ^ ".ts_response") "a TypeScript type identifier"
        valid_ts_identifier command.ts_response,
      validate_optional (path ^ ".ts_event") "a TypeScript type identifier"
        valid_ts_identifier command.ts_event )
  with
  | Ok (), Ok (), Ok (), Ok (), Ok (), Ok (), Ok (), Ok () -> Ok command
  | Error message, _, _, _, _, _, _, _
  | _, Error message, _, _, _, _, _, _
  | _, _, Error message, _, _, _, _, _
  | _, _, _, Error message, _, _, _, _
  | _, _, _, _, Error message, _, _, _
  | _, _, _, _, _, Error message, _, _
  | _, _, _, _, _, _, Error message, _
  | _, _, _, _, _, _, _, Error message ->
      error message

let command_of_yojson index json =
  let path = Printf.sprintf "commands[%d]" index in
  match assoc path json with
  | Error message -> error message
  | Ok fields -> (
      let required name = string_field path name fields in
      let optional name = optional_string_field path name fields in
      match
        ( required "name",
          required "request",
          required "response",
          optional "event",
          optional "ts_request",
          required "ts_response",
          optional "ts_event" )
      with
      | ( Ok name,
          Ok request,
          Ok response,
          Ok event,
          Ok ts_request,
          Ok ts_response,
          Ok ts_event ) ->
          let command =
            {
              name;
              request;
              response;
              event;
              ts_request = Option.value ts_request ~default:request;
              ts_response;
              ts_event =
                (match ts_event with Some _ -> ts_event | None -> event);
            }
          in
          validate_command path command
      | Error message, _, _, _, _, _, _
      | _, Error message, _, _, _, _, _
      | _, _, Error message, _, _, _, _
      | _, _, _, Error message, _, _, _
      | _, _, _, _, Error message, _, _
      | _, _, _, _, _, Error message, _
      | _, _, _, _, _, _, Error message ->
          error message)

module Names = Set.Make (String)

let check_unique_names commands =
  let rec loop seen = function
    | [] -> Ok ()
    | command :: rest ->
        if Names.mem command.name seen then
          error ("duplicate command name: " ^ command.name)
        else loop (Names.add command.name seen) rest
  in
  loop Names.empty commands

let commands_of_yojson = function
  | `List commands ->
      let rec loop index acc = function
        | [] -> (
            let commands = List.rev acc in
            match check_unique_names commands with
            | Ok () -> Ok commands
            | Error message -> error message)
        | json :: rest -> (
            match command_of_yojson index json with
            | Ok command -> loop (index + 1) (command :: acc) rest
            | Error message -> error message)
      in
      loop 0 [] commands
  | _ -> error "commands must be an array"

let of_yojson json =
  match assoc "manifest" json with
  | Error message -> error message
  | Ok fields -> (
      let required name = string_field "manifest" name fields in
      let typescript_types_module =
        match
          optional_string_field "manifest" "typescript_types_module" fields
        with
        | Ok (Some value) -> Ok value
        | Ok None -> Ok "./api_types"
        | Error message -> error message
      in
      match
        ( required "service_module",
          required "types_module",
          required "json_module",
          typescript_types_module,
          field "manifest" "commands" fields )
      with
      | ( Ok service_module,
          Ok types_module,
          Ok json_module,
          Ok typescript_types_module,
          Ok commands_json ) -> (
          match commands_of_yojson commands_json with
          | Ok commands -> (
              match
                ( validate_name "manifest.service_module" "an OCaml module path"
                    valid_ocaml_module_path service_module,
                  validate_name "manifest.types_module" "an OCaml module path"
                    valid_ocaml_module_path types_module,
                  validate_name "manifest.json_module" "an OCaml module path"
                    valid_ocaml_module_path json_module )
              with
              | Ok (), Ok (), Ok () ->
                  Ok
                    {
                      service_module;
                      types_module;
                      json_module;
                      typescript_types_module;
                      commands;
                    }
              | Error message, _, _ | _, Error message, _ | _, _, Error message
                ->
                  error message)
          | Error message -> error message)
      | Error message, _, _, _, _
      | _, Error message, _, _, _
      | _, _, Error message, _, _
      | _, _, _, Error message, _
      | _, _, _, _, Error message ->
          error message)

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
  | text -> (
      match Yojson.Safe.from_string text with
      | json -> of_yojson json
      | exception Yojson.Json_error message -> error ("invalid JSON: " ^ message)
      )

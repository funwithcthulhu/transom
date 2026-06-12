type id = int
type call = { id : id; method_ : string; params : Yojson.Safe.t }
type cancel = { id : id }
type incoming = Call of call | Cancel of cancel
type ok = { id : id; result : Yojson.Safe.t }
type err = { id : id option; error : Error.t }
type event = { id : id; event : Yojson.Safe.t }
type outgoing = Out_ok of ok | Out_err of err | Out_event of event
type ndjson_parser = { mutable pending : string }

let assoc = function
  | `Assoc fields -> Ok fields
  | _ -> Error "frame must be an object"

let int_of_yojson name = function
  | `Int value -> Ok value
  | `Intlit value -> (
      try Ok (int_of_string value)
      with Failure _ -> Error (name ^ " must be an integer"))
  | _ -> Error (name ^ " must be an integer")

let id_of_yojson value = int_of_yojson "id" value

let id_opt_of_yojson = function
  | `Null -> Ok None
  | value -> (
      match id_of_yojson value with
      | Ok id -> Ok (Some id)
      | Error message -> Error message)

let string_of_yojson name = function
  | `String value -> Ok value
  | _ -> Error (name ^ " must be a string")

let field name fields =
  match List.assoc_opt name fields with
  | Some value -> Ok value
  | None -> Error ("missing field: " ^ name)

let optional_id json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "id" fields with
      | None | Some `Null -> None
      | Some value -> Result.to_option (id_of_yojson value))
  | _ -> None

let incoming_to_yojson = function
  | Call { id; method_; params } ->
      `Assoc
        [
          ("kind", `String "call");
          ("id", `Int id);
          ("method", `String method_);
          ("params", params);
        ]
  | Cancel { id } -> `Assoc [ ("kind", `String "cancel"); ("id", `Int id) ]

let incoming_of_yojson json =
  match assoc json with
  | Error message -> Error message
  | Ok fields -> (
      match field "kind" fields with
      | Error message -> Error message
      | Ok (`String "call") -> (
          match
            (field "id" fields, field "method" fields, field "params" fields)
          with
          | Ok id_json, Ok method_json, Ok params -> (
              match
                (id_of_yojson id_json, string_of_yojson "method" method_json)
              with
              | Ok id, Ok method_ -> Ok (Call { id; method_; params })
              | Error message, _ | _, Error message -> Error message)
          | Error message, _, _ | _, Error message, _ | _, _, Error message ->
              Error message)
      | Ok (`String "cancel") -> (
          match field "id" fields with
          | Error message -> Error message
          | Ok id_json -> (
              match id_of_yojson id_json with
              | Ok id -> Ok (Cancel { id })
              | Error message -> Error message))
      | Ok (`String kind) -> Error ("unknown incoming frame kind: " ^ kind)
      | Ok _ -> Error "kind must be a string")

let outgoing_to_yojson = function
  | Out_ok { id; result } ->
      `Assoc [ ("kind", `String "ok"); ("id", `Int id); ("result", result) ]
  | Out_err { id; error } ->
      `Assoc
        [
          ("kind", `String "err");
          ("id", match id with Some id -> `Int id | None -> `Null);
          ("error", Error.to_yojson error);
        ]
  | Out_event { id; event } ->
      `Assoc [ ("kind", `String "event"); ("id", `Int id); ("event", event) ]

let outgoing_of_yojson json =
  match assoc json with
  | Error message -> Error message
  | Ok fields -> (
      match field "kind" fields with
      | Error message -> Error message
      | Ok (`String "ok") -> (
          match (field "id" fields, field "result" fields) with
          | Ok id_json, Ok result -> (
              match id_of_yojson id_json with
              | Ok id -> Ok (Out_ok { id; result })
              | Error message -> Error message)
          | Error message, _ | _, Error message -> Error message)
      | Ok (`String "err") -> (
          match (field "id" fields, field "error" fields) with
          | Ok id_json, Ok error_json -> (
              match (id_opt_of_yojson id_json, Error.of_yojson error_json) with
              | Ok id, Ok error -> Ok (Out_err { id; error })
              | Error message, _ | _, Error message -> Error message)
          | Error message, _ | _, Error message -> Error message)
      | Ok (`String "event") -> (
          match (field "id" fields, field "event" fields) with
          | Ok id_json, Ok event -> (
              match id_of_yojson id_json with
              | Ok id -> Ok (Out_event { id; event })
              | Error message -> Error message)
          | Error message, _ | _, Error message -> Error message)
      | Ok (`String kind) -> Error ("unknown outgoing frame kind: " ^ kind)
      | Ok _ -> Error "kind must be a string")

let create_ndjson_parser () = { pending = "" }

let drop_trailing_cr line =
  let length = String.length line in
  if length > 0 && line.[length - 1] = '\r' then String.sub line 0 (length - 1)
  else line

let drop_leading_utf8_bom line =
  let length = String.length line in
  if length >= 3 && line.[0] = '\239' && line.[1] = '\187' && line.[2] = '\191'
  then String.sub line 3 (length - 3)
  else line

let take_lines parser chunk =
  let text = parser.pending ^ chunk in
  let length = String.length text in
  let rec loop start index acc =
    if index = length then (
      parser.pending <- String.sub text start (length - start);
      List.rev acc)
    else if text.[index] = '\n' then
      let line =
        String.sub text start (index - start)
        |> drop_trailing_cr |> drop_leading_utf8_bom
      in
      loop (index + 1) (index + 1) (line :: acc)
    else loop start (index + 1) acc
  in
  loop 0 0 []

let frames_of_ndjson parser parse_frame chunk =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | line :: rest when String.trim line = "" -> loop acc rest
    | line :: rest -> (
        match Yojson.Safe.from_string line with
        | exception Yojson.Json_error message ->
            Error ("invalid JSON frame: " ^ message)
        | json -> (
            match parse_frame json with
            | Ok frame -> loop (frame :: acc) rest
            | Error message -> Error message))
  in
  loop [] (take_lines parser chunk)

let incoming_frames_of_ndjson parser chunk =
  frames_of_ndjson parser incoming_of_yojson chunk

let outgoing_frames_of_ndjson parser chunk =
  frames_of_ndjson parser outgoing_of_yojson chunk

let outgoing_id = function
  | Out_ok { id; _ } | Out_event { id; _ } -> Some id
  | Out_err { id; _ } -> id

let expect_outgoing_id ~id frame =
  match outgoing_id frame with
  | Some actual when actual = id -> Ok ()
  | Some actual ->
      Error
        (Printf.sprintf "response id mismatch: expected %d, got %d" id actual)
  | None ->
      Error (Printf.sprintf "response id mismatch: expected %d, got null" id)

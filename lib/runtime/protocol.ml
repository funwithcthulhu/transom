type id = int

type call =
  { id : id
  ; method_ : string
  ; params : Yojson.Safe.t
  }

type cancel = { id : id }

type incoming =
  | Call of call
  | Cancel of cancel

type ok =
  { id : id
  ; result : Yojson.Safe.t
  }

type err =
  { id : id option
  ; error : Error.t
  }

type event =
  { id : id
  ; event : Yojson.Safe.t
  }

type outgoing =
  | Out_ok of ok
  | Out_err of err
  | Out_event of event

let assoc = function
  | `Assoc fields -> Ok fields
  | _ -> Error "frame must be an object"

let int_of_yojson name = function
  | `Int value -> Ok value
  | `Intlit value ->
    (try Ok (int_of_string value) with Failure _ -> Error (name ^ " must be an integer"))
  | _ -> Error (name ^ " must be an integer")

let id_of_yojson value = int_of_yojson "id" value

let id_opt_of_yojson = function
  | `Null -> Ok None
  | value ->
    (match id_of_yojson value with
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
  | `Assoc fields ->
    (match List.assoc_opt "id" fields with
     | None | Some `Null -> None
     | Some value -> Result.to_option (id_of_yojson value))
  | _ -> None

let incoming_to_yojson = function
  | Call { id; method_; params } ->
    `Assoc
      [ "kind", `String "call"
      ; "id", `Int id
      ; "method", `String method_
      ; "params", params
      ]
  | Cancel { id } ->
    `Assoc [ "kind", `String "cancel"; "id", `Int id ]

let incoming_of_yojson json =
  match assoc json with
  | Error message -> Error message
  | Ok fields ->
    (match field "kind" fields with
     | Error message -> Error message
     | Ok (`String "call") ->
       (match field "id" fields, field "method" fields, field "params" fields with
        | Ok id_json, Ok method_json, Ok params ->
          (match id_of_yojson id_json, string_of_yojson "method" method_json with
           | Ok id, Ok method_ -> Ok (Call { id; method_; params })
           | Error message, _ | _, Error message -> Error message)
        | Error message, _, _ | _, Error message, _ | _, _, Error message -> Error message)
     | Ok (`String "cancel") ->
       (match field "id" fields with
        | Error message -> Error message
        | Ok id_json ->
          (match id_of_yojson id_json with
           | Ok id -> Ok (Cancel { id })
           | Error message -> Error message))
     | Ok (`String kind) -> Error ("unknown incoming frame kind: " ^ kind)
     | Ok _ -> Error "kind must be a string")

let outgoing_to_yojson = function
  | Out_ok { id; result } ->
    `Assoc [ "kind", `String "ok"; "id", `Int id; "result", result ]
  | Out_err { id; error } ->
    `Assoc
      [ "kind", `String "err"
      ; "id", (match id with Some id -> `Int id | None -> `Null)
      ; "error", Error.to_yojson error
      ]
  | Out_event { id; event } ->
    `Assoc [ "kind", `String "event"; "id", `Int id; "event", event ]

let outgoing_of_yojson json =
  match assoc json with
  | Error message -> Error message
  | Ok fields ->
    (match field "kind" fields with
     | Error message -> Error message
     | Ok (`String "ok") ->
       (match field "id" fields, field "result" fields with
        | Ok id_json, Ok result ->
          (match id_of_yojson id_json with
           | Ok id -> Ok (Out_ok { id; result })
           | Error message -> Error message)
        | Error message, _ | _, Error message -> Error message)
     | Ok (`String "err") ->
       (match field "id" fields, field "error" fields with
        | Ok id_json, Ok error_json ->
          (match id_opt_of_yojson id_json, Error.of_yojson error_json with
           | Ok id, Ok error -> Ok (Out_err { id; error })
           | Error message, _ | _, Error message -> Error message)
        | Error message, _ | _, Error message -> Error message)
     | Ok (`String "event") ->
       (match field "id" fields, field "event" fields with
        | Ok id_json, Ok event ->
          (match id_of_yojson id_json with
           | Ok id -> Ok (Out_event { id; event })
           | Error message -> Error message)
        | Error message, _ | _, Error message -> Error message)
     | Ok (`String kind) -> Error ("unknown outgoing frame kind: " ^ kind)
     | Ok _ -> Error "kind must be a string")

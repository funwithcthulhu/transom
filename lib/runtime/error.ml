type t =
  { code : string
  ; message : string
  ; data : Yojson.Safe.t option
  }

let make ?data code message = { code; message; data }

let unknown_method method_ =
  make "unknown_method" ("Unknown method: " ^ method_)

let bad_request message = make "bad_request" message
let invalid_json message = make "invalid_json" message
let protocol_error message = make "protocol_error" message
let internal_error message = make "internal_error" message

let to_yojson { code; message; data } =
  let fields = [ "code", `String code; "message", `String message ] in
  let fields =
    match data with
    | None -> fields
    | Some value -> fields @ [ "data", value ]
  in
  `Assoc fields

let of_yojson = function
  | `Assoc fields ->
    let string_field name =
      match List.assoc_opt name fields with
      | Some (`String value) -> Ok value
      | Some _ -> Error (name ^ " must be a string")
      | None -> Error ("missing field: " ^ name)
    in
    (match string_field "code", string_field "message" with
     | Ok code, Ok message ->
       Ok { code; message; data = List.assoc_opt "data" fields }
     | Error message, _ | _, Error message -> Error message)
  | _ -> Error "error must be an object"

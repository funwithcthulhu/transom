let write_frame frame =
  Yojson.Safe.to_string (Protocol.outgoing_to_yojson frame) |> print_endline;
  flush stdout

let write_error id error = write_frame (Protocol.Out_err { id; error })

let dispatch_call dispatch ({ Protocol.id; method_; params } as _call) =
  let emit event = write_frame (Protocol.Out_event { id; event }) in
  try
    match dispatch ~method_ ~params ~emit with
    | Ok result -> write_frame (Protocol.Out_ok { id; result })
    | Error error -> write_error (Some id) error
  with exn ->
    let message = Printexc.to_string exn in
    write_error (Some id) (Error.internal_error message)

let handle_line dispatch line =
  let line = Protocol.drop_leading_utf8_bom line in
  match Yojson.Safe.from_string line with
  | exception Yojson.Json_error message ->
      write_error None (Error.invalid_json message)
  | json -> (
      let id = Protocol.optional_id json in
      match Protocol.incoming_of_yojson json with
      | Error message -> write_error id (Error.protocol_error message)
      | Ok (Protocol.Call call) -> dispatch_call dispatch call
      | Ok (Protocol.Cancel _) ->
          (* v0.1 parses cancel frames, but does not interrupt running handlers. *)
          ())

let run ~dispatch =
  let rec loop () =
    match input_line stdin with
    | line ->
        handle_line dispatch line;
        loop ()
    | exception End_of_file -> ()
  in
  loop ()

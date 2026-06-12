module type HANDLERS = sig
  val echo :
    Api_t.echo_req ->
    (Api_t.echo_res, Transom_runtime.Error.t) result
end

module Make (H : HANDLERS) = struct
  let bad_request method_ exn =
    Transom_runtime.Error.bad_request
      ("Invalid params for " ^ method_ ^ ": " ^ Printexc.to_string exn)

  let dispatch ~method_ ~params ~emit =
    let _ = emit in
    match method_ with
    | "echo" ->
      (match
         (try Ok
                (Api_j.echo_req_of_string (Yojson.Safe.to_string params))
          with exn -> Error (bad_request method_ exn))
       with
       | Error err -> Error err
       | Ok req ->
         match H.echo req with
         | Ok res -> Ok (Yojson.Safe.from_string (Api_j.string_of_echo_res res))
         | Error err -> Error err)
    | _ -> Error (Transom_runtime.Error.unknown_method method_)

  let run_stdio () = Transom_runtime.run ~dispatch
end

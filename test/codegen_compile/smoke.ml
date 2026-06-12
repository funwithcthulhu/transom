module Server = Api_server.Make (struct
  let echo (req : Api_t.echo_req) =
    Ok ({ Api_t.reply = "echo: " ^ req.Api_t.message } : Api_t.echo_res)
end)

let () =
  let params = `Assoc [ ("message", `String "hi") ] in
  match Server.dispatch ~method_:"echo" ~params ~emit:ignore with
  | Ok (`Assoc fields) ->
      assert (List.assoc "reply" fields = `String "echo: hi")
  | Ok json -> failwith ("unexpected response: " ^ Yojson.Safe.to_string json)
  | Error error -> failwith error.Transom_runtime.Error.message

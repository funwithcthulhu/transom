module Server = Api_server.Make (struct
  let echo (req : Api_t.echo_req) =
    Ok ({ Api_t.reply = "echo: " ^ req.Api_t.message } : Api_t.echo_res)
end)

let () = Server.run_stdio ()

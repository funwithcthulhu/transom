module {{module_name}} =
  Api_server.Make
    (struct
      let ping req =
        Ok { Api_t.message = "pong: " ^ req.Api_t.message }

      let count req ~emit =
        let rec loop value total =
          if value > req.Api_t.upto then
            total
          else (
            emit { Api_t.value };
            loop (value + 1) (total + value))
        in
        Ok { Api_t.total = loop 1 0 }
    end)

let () = {{module_name}}.run_stdio ()

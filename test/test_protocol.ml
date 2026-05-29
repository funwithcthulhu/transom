let roundtrip_incoming frame =
  let json = Transom_runtime.Protocol.incoming_to_yojson frame in
  match Transom_runtime.Protocol.incoming_of_yojson json with
  | Ok parsed -> assert (parsed = frame)
  | Error message -> failwith message

let roundtrip_outgoing frame =
  let json = Transom_runtime.Protocol.outgoing_to_yojson frame in
  match Transom_runtime.Protocol.outgoing_of_yojson json with
  | Ok parsed -> assert (parsed = frame)
  | Error message -> failwith message

let () =
  roundtrip_incoming
    (Transom_runtime.Protocol.Call
       {
         id = 1;
         method_ = "ping";
         params = `Assoc [ ("message", `String "hi") ];
       });
  roundtrip_incoming (Transom_runtime.Protocol.Cancel { id = 1 });
  roundtrip_outgoing
    (Transom_runtime.Protocol.Out_ok
       { id = 1; result = `Assoc [ ("message", `String "pong") ] });
  roundtrip_outgoing
    (Transom_runtime.Protocol.Out_err
       {
         id = Some 1;
         error =
           {
             Transom_runtime.Error.code = "unknown_method";
             message = "Unknown method: foo";
             data = None;
           };
       });
  roundtrip_outgoing
    (Transom_runtime.Protocol.Out_event
       {
         id = 1;
         event = `Assoc [ ("kind", `String "Progress"); ("value", `Int 50) ];
       })

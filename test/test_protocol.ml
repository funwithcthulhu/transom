let contains text needle =
  let text_len = String.length text in
  let needle_len = String.length needle in
  let rec loop index =
    index + needle_len <= text_len
    && (String.sub text index needle_len = needle || loop (index + 1))
  in
  needle_len = 0 || loop 0

let expect_incoming_error needle json =
  match Transom_runtime.Protocol.incoming_of_yojson json with
  | Ok _ -> failwith ("expected incoming protocol error containing: " ^ needle)
  | Error message -> assert (contains message needle)

let expect_outgoing_error needle json =
  match Transom_runtime.Protocol.outgoing_of_yojson json with
  | Ok _ -> failwith ("expected outgoing protocol error containing: " ^ needle)
  | Error message -> assert (contains message needle)

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

let parsed_incoming json =
  match Transom_runtime.Protocol.incoming_of_yojson json with
  | Ok frame -> frame
  | Error message -> failwith message

let parsed_outgoing json =
  match Transom_runtime.Protocol.outgoing_of_yojson json with
  | Ok frame -> frame
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
       });
  (match
     parsed_incoming
       (`Assoc
          [
            ("kind", `String "call");
            ("id", `Int 7);
            ("method", `String "ping");
            ("params", `Assoc []);
          ])
   with
  | Transom_runtime.Protocol.Call { id = 7; method_ = "ping"; _ } -> ()
  | _ -> failwith "call frame parsed as a different incoming variant");
  (match
     parsed_incoming (`Assoc [ ("kind", `String "cancel"); ("id", `Int 7) ])
   with
  | Transom_runtime.Protocol.Cancel { id = 7 } -> ()
  | _ -> failwith "cancel frame parsed as a different incoming variant");
  (match
     parsed_outgoing
       (`Assoc
          [
            ("kind", `String "ok");
            ("id", `Int 7);
            ("result", `Assoc [ ("ok", `Bool true) ]);
          ])
   with
  | Transom_runtime.Protocol.Out_ok { id = 7; _ } -> ()
  | _ -> failwith "ok frame parsed as a different outgoing variant");
  (match
     parsed_outgoing
       (`Assoc
          [
            ("kind", `String "err");
            ("id", `Int 7);
            ( "error",
              `Assoc
                [
                  ("code", `String "bad_request");
                  ("message", `String "bad request");
                ] );
          ])
   with
  | Transom_runtime.Protocol.Out_err { id = Some 7; _ } -> ()
  | _ -> failwith "err frame parsed as a different outgoing variant");
  (match
     parsed_outgoing
       (`Assoc
          [
            ("kind", `String "event");
            ("id", `Int 7);
            ("event", `Assoc [ ("value", `Int 1) ]);
          ])
   with
  | Transom_runtime.Protocol.Out_event { id = 7; _ } -> ()
  | _ -> failwith "event frame parsed as a different outgoing variant");
  expect_incoming_error "unknown incoming frame kind"
    (`Assoc [ ("kind", `String "wat"); ("id", `Int 1) ]);
  expect_outgoing_error "unknown outgoing frame kind"
    (`Assoc [ ("kind", `String "wat"); ("id", `Int 1) ]);
  expect_incoming_error "kind must be a string" (`Assoc [ ("kind", `Int 1) ]);
  expect_incoming_error "missing field: id"
    (`Assoc
       [
         ("kind", `String "call");
         ("method", `String "ping");
         ("params", `Assoc []);
       ]);
  expect_incoming_error "id must be an integer"
    (`Assoc
       [
         ("kind", `String "call");
         ("id", `Intlit "not-an-int");
         ("method", `String "ping");
         ("params", `Assoc []);
       ]);
  (match
     Transom_runtime.Protocol.outgoing_of_yojson
       (`Assoc
          [
            ("kind", `String "err");
            ("id", `Null);
            ( "error",
              `Assoc
                [
                  ("code", `String "bad_request");
                  ("message", `String "bad request");
                ] );
          ])
   with
  | Ok (Transom_runtime.Protocol.Out_err { id = None; error }) ->
      assert (error.code = "bad_request")
  | Ok _ -> failwith "expected err frame with null id"
  | Error message -> failwith message);
  expect_outgoing_error "missing field: code"
    (`Assoc
       [
         ("kind", `String "err");
         ("id", `Null);
         ("error", `Assoc [ ("message", `String "bad request") ]);
       ]);
  expect_outgoing_error "missing field: message"
    (`Assoc
       [
         ("kind", `String "err");
         ("id", `Null);
         ("error", `Assoc [ ("code", `String "bad_request") ]);
       ])

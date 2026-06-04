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

let expect_incoming_ndjson_error needle chunk =
  let parser = Transom_runtime.Protocol.create_ndjson_parser () in
  match Transom_runtime.Protocol.incoming_frames_of_ndjson parser chunk with
  | Ok _ -> failwith ("expected NDJSON protocol error containing: " ^ needle)
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

let expect_incoming_frames parser chunk =
  match Transom_runtime.Protocol.incoming_frames_of_ndjson parser chunk with
  | Ok frames -> frames
  | Error message -> failwith message

let expect_outgoing_id_error expected frame =
  match Transom_runtime.Protocol.expect_outgoing_id ~id:expected frame with
  | Ok () -> failwith "expected outgoing id mismatch"
  | Error message -> message

let () =
  let call_params =
    `Assoc
      [
        ("items", `List [ `Int 1; `String "two" ]);
        ("nested", `Assoc [ ("ok", `Bool true) ]);
      ]
  in
  let ok_result =
    `Assoc
      [ ("value", `Float 1.5); ("tags", `List [ `String "a"; `String "b" ]) ]
  in
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
            ("id", `Int 9);
            ("method", `String "echo");
            ("params", call_params);
          ])
   with
  | Transom_runtime.Protocol.Call { id = 9; method_ = "echo"; params } ->
      assert (params = call_params)
  | _ -> failwith "call frame did not preserve params");
  (match
     parsed_outgoing
       (`Assoc [ ("kind", `String "ok"); ("id", `Int 9); ("result", ok_result) ])
   with
  | Transom_runtime.Protocol.Out_ok { id = 9; result } ->
      assert (result = ok_result)
  | _ -> failwith "ok frame did not preserve result");
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
  expect_incoming_error "missing field: kind" (`Assoc [ ("id", `Int 1) ]);
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
         ("id", `String "7");
         ("method", `String "ping");
         ("params", `Assoc []);
       ]);
  expect_incoming_error "id must be an integer"
    (`Assoc
       [
         ("kind", `String "call");
         ("id", `Float 1.0);
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
  expect_incoming_error "unknown incoming frame kind: notification"
    (`Assoc
       [
         ("kind", `String "notification");
         ("method", `String "ping");
         ("params", `Assoc []);
       ]);
  expect_incoming_error "unknown incoming frame kind: notification"
    (`Assoc
       [
         ("kind", `String "notification");
         ("id", `Int 7);
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
  (match
     Transom_runtime.Protocol.outgoing_of_yojson
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
  | Ok (Transom_runtime.Protocol.Out_err { id = Some 7; error }) ->
      assert (error.message = "bad request")
  | Ok _ -> failwith "expected err frame with integer id"
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
       ]);
  expect_outgoing_error "code must be a string"
    (`Assoc
       [
         ("kind", `String "err");
         ("id", `Null);
         ( "error",
           `Assoc [ ("code", `Int 1); ("message", `String "bad request") ] );
       ]);
  expect_outgoing_error "message must be a string"
    (`Assoc
       [
         ("kind", `String "err");
         ("id", `Null);
         ( "error",
           `Assoc [ ("code", `String "bad_request"); ("message", `List []) ] );
       ]);
  let incoming_parser = Transom_runtime.Protocol.create_ndjson_parser () in
  (match
     expect_incoming_frames incoming_parser
       (String.concat "\n"
          [
            {|{"kind":"call","id":1,"method":"ping","params":{"n":1}}|};
            {|{"kind":"cancel","id":1}|};
            "";
          ])
   with
  | [
   Transom_runtime.Protocol.Call
     { id = 1; method_ = "ping"; params = `Assoc [ ("n", `Int 1) ] };
   Transom_runtime.Protocol.Cancel { id = 1 };
  ] ->
      ()
  | _ -> failwith "expected two incoming frames from one buffer");
  let split_parser = Transom_runtime.Protocol.create_ndjson_parser () in
  assert (
    expect_incoming_frames split_parser
      {|{"kind":"call","id":2,"method":"ping","params":|}
    = []);
  (match expect_incoming_frames split_parser "{\"ok\":true}}\n" with
  | [
   Transom_runtime.Protocol.Call
     { id = 2; method_ = "ping"; params = `Assoc [ ("ok", `Bool true) ] };
  ] ->
      ()
  | _ -> failwith "expected split incoming frame");
  let blank_parser = Transom_runtime.Protocol.create_ndjson_parser () in
  assert (expect_incoming_frames blank_parser "\n\r\n" = []);
  expect_incoming_ndjson_error "invalid JSON frame" "{\n";
  assert (
    Transom_runtime.Protocol.expect_outgoing_id ~id:7
      (Transom_runtime.Protocol.Out_ok { id = 7; result = `Null })
    = Ok ());
  assert (
    expect_outgoing_id_error 7
      (Transom_runtime.Protocol.Out_ok { id = 8; result = `Null })
    = "response id mismatch: expected 7, got 8")

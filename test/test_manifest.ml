let fixture = "fixtures/transom.json"

let duplicate_manifest =
  `Assoc
    [
      ("service_module", `String "Api_server");
      ("types_module", `String "Api_t");
      ("json_module", `String "Api_j");
      ( "commands",
        `List
          [
            `Assoc
              [
                ("name", `String "ping");
                ("request", `String "ping_req");
                ("response", `String "ping_res");
              ];
            `Assoc
              [
                ("name", `String "ping");
                ("request", `String "other_req");
                ("response", `String "other_res");
              ];
          ] );
    ]

let () =
  (match Transom_codegen.Manifest.load_file fixture with
  | Ok manifest ->
      assert (manifest.service_module = "Api_server");
      assert (List.length manifest.commands = 2)
  | Error message -> failwith message);
  match Transom_codegen.Manifest.of_yojson duplicate_manifest with
  | Ok _ -> failwith "duplicate command names should be rejected"
  | Error message -> assert (String.contains message 'd')

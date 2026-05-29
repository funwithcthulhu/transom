let fixture = "fixtures/transom.json"

let manifest commands =
  `Assoc
    [
      ("service_module", `String "Api_server");
      ("types_module", `String "Api_t");
      ("json_module", `String "Api_j");
      ("commands", `List commands);
    ]

let command fields = `Assoc fields

let duplicate_manifest =
  manifest
    [
      command
        [
          ("name", `String "ping");
          ("request", `String "ping_req");
          ("response", `String "ping_res");
        ];
      command
        [
          ("name", `String "ping");
          ("request", `String "other_req");
          ("response", `String "other_res");
        ];
    ]

let invalid_command_name =
  manifest
    [
      command
        [
          ("name", `String "ping-now");
          ("request", `String "ping_req");
          ("response", `String "ping_res");
        ];
    ]

let invalid_module_name =
  `Assoc
    [
      ("service_module", `String "api_server");
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
          ] );
    ]

let keyword_command_name =
  manifest
    [
      command
        [
          ("name", `String "type");
          ("request", `String "ping_req");
          ("response", `String "ping_res");
        ];
    ]

let ts_keyword_command_name =
  manifest
    [
      command
        [
          ("name", `String "return");
          ("request", `String "ping_req");
          ("response", `String "ping_res");
        ];
    ]

let missing_request =
  manifest
    [ command [ ("name", `String "ping"); ("response", `String "ping_res") ] ]

let missing_name =
  manifest
    [
      command
        [ ("request", `String "ping_req"); ("response", `String "ping_res") ];
    ]

let missing_response =
  manifest
    [ command [ ("name", `String "ping"); ("request", `String "ping_req") ] ]

let non_string_name =
  manifest
    [
      command
        [
          ("name", `Int 1);
          ("request", `String "ping_req");
          ("response", `String "ping_res");
        ];
    ]

let non_string_request =
  manifest
    [
      command
        [
          ("name", `String "ping");
          ("request", `Int 1);
          ("response", `String "ping_res");
        ];
    ]

let non_string_response =
  manifest
    [
      command
        [
          ("name", `String "ping");
          ("request", `String "ping_req");
          ("response", `Bool true);
        ];
    ]

let manifest_with_unknown_field =
  `Assoc
    [
      ("service_module", `String "Api_server");
      ("types_module", `String "Api_t");
      ("json_module", `String "Api_j");
      ("commands", `List []);
      ("unused", `String "ignored");
    ]

let command_with_unknown_field =
  manifest
    [
      command
        [
          ("name", `String "ping");
          ("request", `String "ping_req");
          ("response", `String "ping_res");
          ("unused", `String "ignored");
        ];
    ]

let manifest_without_optional_fields =
  `Assoc
    [
      ("service_module", `String "Api_server");
      ("types_module", `String "Api_t");
      ("json_module", `String "Api_j");
      ( "commands",
        `List
          [
            command
              [
                ("name", `String "watch");
                ("request", `String "watch_req");
                ("response", `String "watch_res");
                ("event", `String "watch_event");
              ];
          ] );
    ]

let manifest_with_module_paths =
  `Assoc
    [
      ("service_module", `String "App.Server");
      ("types_module", `String "Domain.Types");
      ("json_module", `String "Domain.Json");
      ("typescript_types_module", `String "../types/api");
      ( "commands",
        `List
          [
            command
              [
                ("name", `String "ping");
                ("request", `String "ping_req");
                ("response", `String "ping_res");
              ];
          ] );
    ]

let contains text needle =
  let text_len = String.length text in
  let needle_len = String.length needle in
  let rec loop index =
    index + needle_len <= text_len
    && (String.sub text index needle_len = needle || loop (index + 1))
  in
  needle_len = 0 || loop 0

let expect_manifest_error needle json =
  match Transom_codegen.Manifest.of_yojson json with
  | Ok _ -> failwith ("expected manifest error containing: " ^ needle)
  | Error message -> assert (contains message needle)

let expect_manifest_ok json =
  match Transom_codegen.Manifest.of_yojson json with
  | Ok manifest -> manifest
  | Error message -> failwith message

let write_file path content =
  let output = open_out_bin path in
  Fun.protect
    ~finally:(fun () -> close_out_noerr output)
    (fun () -> output_string output content)

let expect_load_error needle content =
  let path = Filename.temp_file "transom-manifest" ".json" in
  Fun.protect
    ~finally:(fun () -> Sys.remove path)
    (fun () ->
      write_file path content;
      match Transom_codegen.Manifest.load_file path with
      | Ok _ -> failwith ("expected manifest load error containing: " ^ needle)
      | Error message -> assert (contains message needle))

let () =
  (match Transom_codegen.Manifest.load_file fixture with
  | Ok manifest -> (
      assert (manifest.service_module = "Api_server");
      assert (manifest.types_module = "Api_t");
      assert (manifest.json_module = "Api_j");
      assert (manifest.typescript_types_module = "./api_types");
      match manifest.commands with
      | [ ping; count ] ->
          assert (ping.name = "ping");
          assert (ping.request = "ping_req");
          assert (ping.response = "ping_res");
          assert (ping.event = None);
          assert (ping.ts_request = "PingReq");
          assert (ping.ts_response = "PingRes");
          assert (count.name = "count");
          assert (count.event = Some "count_event");
          assert (count.ts_event = Some "CountEvent")
      | _ -> failwith "fixture should contain ping and count commands")
  | Error message -> failwith message);
  expect_manifest_error "duplicate command name" duplicate_manifest;
  expect_manifest_error "commands[0].name" invalid_command_name;
  expect_manifest_error "commands[0].name" keyword_command_name;
  expect_manifest_error "commands[0].name" ts_keyword_command_name;
  expect_manifest_error "manifest.service_module" invalid_module_name;
  expect_manifest_error "commands[0].name is required" missing_name;
  expect_manifest_error "commands[0].request is required" missing_request;
  expect_manifest_error "commands[0].response is required" missing_response;
  expect_manifest_error "commands[0].name must be a string" non_string_name;
  expect_manifest_error "commands[0].request must be a string"
    non_string_request;
  expect_manifest_error "commands[0].response must be a string"
    non_string_response;
  expect_manifest_error "manifest must be an object" (`List []);
  expect_manifest_error "manifest.service_module is required"
    (`Assoc
       [
         ("types_module", `String "Api_t");
         ("json_module", `String "Api_j");
         ("commands", `List []);
       ]);
  expect_manifest_error "manifest.types_module is required"
    (`Assoc
       [
         ("service_module", `String "Api_server");
         ("json_module", `String "Api_j");
         ("commands", `List []);
       ]);
  expect_manifest_error "manifest.json_module is required"
    (`Assoc
       [
         ("service_module", `String "Api_server");
         ("types_module", `String "Api_t");
         ("commands", `List []);
       ]);
  expect_manifest_error "manifest.commands is required"
    (`Assoc
       [
         ("service_module", `String "Api_server");
         ("types_module", `String "Api_t");
         ("json_module", `String "Api_j");
       ]);
  assert ((expect_manifest_ok (manifest [])).commands = []);
  assert ((expect_manifest_ok manifest_with_unknown_field).commands = []);
  assert ((expect_manifest_ok command_with_unknown_field).commands <> []);
  (match expect_manifest_ok manifest_without_optional_fields with
  | { typescript_types_module = "./api_types"; commands = [ command ]; _ } ->
      assert (command.ts_request = "watch_req");
      assert (command.ts_response = "watch_res");
      assert (command.ts_event = Some "watch_event")
  | _ -> failwith "optional manifest fields did not use defaults");
  (match expect_manifest_ok manifest_with_module_paths with
  | { service_module; types_module; json_module; typescript_types_module; _ } ->
      assert (service_module = "App.Server");
      assert (types_module = "Domain.Types");
      assert (json_module = "Domain.Json");
      assert (typescript_types_module = "../types/api"));
  expect_load_error "invalid JSON" "{"

let fixture = "fixtures/transom.json"

let manifest_error_fixture name =
  Filename.concat (Filename.concat "fixtures" "manifest_errors") name

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
          ("ts_response", `String "PingRes");
        ];
      command
        [
          ("name", `String "ping");
          ("request", `String "other_req");
          ("response", `String "other_res");
          ("ts_response", `String "OtherRes");
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
          ("ts_response", `String "PingRes");
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
                ("ts_response", `String "PingRes");
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
          ("ts_response", `String "PingRes");
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
          ("ts_response", `String "PingRes");
        ];
    ]

let missing_request =
  manifest
    [
      command
        [
          ("name", `String "ping");
          ("response", `String "ping_res");
          ("ts_response", `String "PingRes");
        ];
    ]

let missing_name =
  manifest
    [
      command
        [
          ("request", `String "ping_req");
          ("response", `String "ping_res");
          ("ts_response", `String "PingRes");
        ];
    ]

let missing_response =
  manifest
    [
      command
        [
          ("name", `String "ping");
          ("request", `String "ping_req");
          ("ts_response", `String "PingRes");
        ];
    ]

let missing_ts_response =
  manifest
    [
      command
        [
          ("name", `String "ping");
          ("request", `String "ping_req");
          ("response", `String "ping_res");
        ];
    ]

let non_string_name =
  manifest
    [
      command
        [
          ("name", `Int 1);
          ("request", `String "ping_req");
          ("response", `String "ping_res");
          ("ts_response", `String "PingRes");
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
          ("ts_response", `String "PingRes");
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
          ("ts_response", `String "PingRes");
        ];
    ]

let invalid_ts_response =
  manifest
    [
      command
        [
          ("name", `String "ping");
          ("request", `String "ping_req");
          ("response", `String "ping_res");
          ("ts_response", `String "1PingRes");
        ];
    ]

let helper_name_collision =
  manifest
    [
      command
        [
          ("name", `String "dispatch");
          ("request", `String "dispatch_req");
          ("response", `String "dispatch_res");
          ("ts_response", `String "DispatchRes");
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
          ("ts_response", `String "PingRes");
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
                ("ts_response", `String "WatchRes");
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
                ("ts_response", `String "PingRes");
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

let command_name = Transom_codegen.Manifest.command_name_to_string
let ocaml_module = Transom_codegen.Manifest.ocaml_module_to_string
let ocaml_type = Transom_codegen.Manifest.ocaml_type_to_string
let ts_type = Transom_codegen.Manifest.ts_type_to_string
let typescript_module = Transom_codegen.Manifest.typescript_module_to_string
let option_string to_string = Option.map to_string

let expect_manifest_error needle json =
  match Transom_codegen.Manifest.of_yojson json with
  | Ok _ -> failwith ("expected manifest error containing: " ^ needle)
  | Error message -> assert (contains message needle)

let expect_manifest_error_exact expected json =
  match Transom_codegen.Manifest.of_yojson json with
  | Ok _ -> failwith ("expected manifest error: " ^ expected)
  | Error message -> assert (message = expected)

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

let read_all channel =
  let buffer = Buffer.create 128 in
  let chunk = Bytes.create 4096 in
  let rec loop () =
    match input channel chunk 0 (Bytes.length chunk) with
    | 0 -> Buffer.contents buffer
    | count ->
        Buffer.add_subbytes buffer chunk 0 count;
        loop ()
  in
  loop ()

let transom_exe = Filename.concat (Filename.concat ".." "bin") "main.exe"

let exit_code = function
  | Unix.WEXITED code -> code
  | Unix.WSIGNALED code | Unix.WSTOPPED code -> 128 + code

let run_manifest_check path =
  let command =
    String.concat " " [ transom_exe; "check"; "--manifest"; path ]
  in
  let stdout, stdin, stderr =
    Unix.open_process_full command (Unix.environment ())
  in
  close_out stdin;
  let stdout_text = read_all stdout in
  let stderr_text = read_all stderr in
  let status = Unix.close_process_full (stdout, stdin, stderr) in
  (exit_code status, stdout_text, stderr_text)

let expect_cli_manifest_error fixture expected =
  let code, stdout, stderr =
    run_manifest_check (manifest_error_fixture fixture)
  in
  let newline = if Sys.win32 then "\r\n" else "\n" in
  assert (code <> 0);
  assert (stdout = "");
  assert (stderr = "transom: " ^ expected ^ newline)

let () =
  (match Transom_codegen.Manifest.load_file fixture with
  | Ok manifest -> (
      assert (ocaml_module manifest.service_module = "Api_server");
      assert (ocaml_module manifest.types_module = "Api_t");
      assert (ocaml_module manifest.json_module = "Api_j");
      assert (typescript_module manifest.typescript_types_module = "./api_types");
      match manifest.commands with
      | [ ping; count ] ->
          assert (command_name ping.name = "ping");
          assert (ocaml_type ping.request = "ping_req");
          assert (ocaml_type ping.response = "ping_res");
          assert (ping.event = None);
          assert (ts_type ping.ts_request = "PingReq");
          assert (ts_type ping.ts_response = "PingRes");
          assert (command_name count.name = "count");
          assert (option_string ocaml_type count.event = Some "count_event");
          assert (option_string ts_type count.ts_event = Some "CountEvent")
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
  expect_manifest_error_exact "commands[0].ts_response is required"
    missing_ts_response;
  expect_manifest_error "commands[0].name must be a string" non_string_name;
  expect_manifest_error "commands[0].request must be a string"
    non_string_request;
  expect_manifest_error "commands[0].response must be a string"
    non_string_response;
  expect_manifest_error_exact
    "commands[0].ts_response must be a TypeScript type identifier"
    invalid_ts_response;
  expect_manifest_error_exact
    "commands[0].name collides with generated helper: dispatch"
    helper_name_collision;
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
  | { typescript_types_module; commands = [ command ]; _ } ->
      assert (typescript_module typescript_types_module = "./api_types");
      assert (ts_type command.ts_request = "watch_req");
      assert (ts_type command.ts_response = "WatchRes");
      assert (option_string ts_type command.ts_event = Some "watch_event")
  | _ -> failwith "optional manifest fields did not use defaults");
  (match expect_manifest_ok manifest_with_module_paths with
  | { service_module; types_module; json_module; typescript_types_module; _ } ->
      assert (ocaml_module service_module = "App.Server");
      assert (ocaml_module types_module = "Domain.Types");
      assert (ocaml_module json_module = "Domain.Json");
      assert (typescript_module typescript_types_module = "../types/api"));
  expect_load_error "invalid JSON" "{";
  expect_cli_manifest_error "missing_ts_response.json"
    "commands[0].ts_response is required";
  expect_cli_manifest_error "duplicate_command_name.json"
    "duplicate command name: ping";
  expect_cli_manifest_error "invalid_ocaml_module_name.json"
    "manifest.service_module must be an OCaml module path";
  expect_cli_manifest_error "invalid_ts_type_name.json"
    "commands[0].ts_response must be a TypeScript type identifier";
  expect_cli_manifest_error "helper_name_collision.json"
    "commands[0].name collides with generated helper: dispatch"

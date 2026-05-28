let fixture = "fixtures/transom.json"

let duplicate_manifest =
  `Assoc
    [ "service_module", `String "Api_server"
    ; "types_module", `String "Api_t"
    ; "json_module", `String "Api_j"
    ; "commands",
      `List
        [ `Assoc
            [ "name", `String "ping"
            ; "request", `String "ping_req"
            ; "response", `String "ping_res"
            ]
        ; `Assoc
            [ "name", `String "ping"
            ; "request", `String "other_req"
            ; "response", `String "other_res"
            ]
        ]
    ]

let invalid_command_name =
  `Assoc
    [ "service_module", `String "Api_server"
    ; "types_module", `String "Api_t"
    ; "json_module", `String "Api_j"
    ; "commands",
      `List
        [ `Assoc
            [ "name", `String "ping-now"
            ; "request", `String "ping_req"
            ; "response", `String "ping_res"
            ]
        ]
    ]

let invalid_module_name =
  `Assoc
    [ "service_module", `String "api_server"
    ; "types_module", `String "Api_t"
    ; "json_module", `String "Api_j"
    ; "commands",
      `List
        [ `Assoc
            [ "name", `String "ping"
            ; "request", `String "ping_req"
            ; "response", `String "ping_res"
            ]
        ]
    ]

let keyword_command_name =
  `Assoc
    [ "service_module", `String "Api_server"
    ; "types_module", `String "Api_t"
    ; "json_module", `String "Api_j"
    ; "commands",
      `List
        [ `Assoc
            [ "name", `String "type"
            ; "request", `String "ping_req"
            ; "response", `String "ping_res"
            ]
        ]
    ]

let ts_keyword_command_name =
  `Assoc
    [ "service_module", `String "Api_server"
    ; "types_module", `String "Api_t"
    ; "json_module", `String "Api_j"
    ; "commands",
      `List
        [ `Assoc
            [ "name", `String "return"
            ; "request", `String "ping_req"
            ; "response", `String "ping_res"
            ]
        ]
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

let () =
  (match Transom_codegen.Manifest.load_file fixture with
   | Ok manifest ->
     assert (manifest.service_module = "Api_server");
     assert (List.length manifest.commands = 2)
   | Error message -> failwith message);
  expect_manifest_error "duplicate command name" duplicate_manifest;
  expect_manifest_error "commands[0].name" invalid_command_name;
  expect_manifest_error "commands[0].name" keyword_command_name;
  expect_manifest_error "commands[0].name" ts_keyword_command_name;
  expect_manifest_error "manifest.service_module" invalid_module_name

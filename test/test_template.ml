let read_file path =
  let input = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr input)
    (fun () ->
      let length = in_channel_length input in
      really_input_string input length)

let contains text needle =
  let text_len = String.length text in
  let needle_len = String.length needle in
  let rec loop index =
    index + needle_len <= text_len
    && (String.sub text index needle_len = needle || loop (index + 1))
  in
  needle_len = 0 || loop 0

let assert_contains path needle =
  let text = read_file path in
  if not (contains text needle) then
    failwith (Printf.sprintf "%s does not contain %S" path needle)

let () =
  assert_contains "../templates/minimal/frontend/package.json"
    "tauri dev --config ../src-tauri/tauri.conf.json";
  assert_contains "../templates/minimal/frontend/index.html" "./dist/main.js";
  assert_contains "../templates/minimal/frontend/tsconfig.json"
    "\"outDir\": \"dist\"";
  assert_contains "../templates/minimal/frontend/src/main.ts" "./api_client.js";
  assert_contains "../templates/minimal/frontend/src/main.ts"
    "invoke(\"transom_call\"";
  assert_contains "../templates/minimal/frontend/src/main.ts" "ping(transport";
  assert_contains "../templates/minimal/frontend/src/api_types.ts"
    "export type PingReq";
  assert_contains "../templates/minimal/backend/bin/main.ml"
    "Transom_template_module";
  assert_contains "../bin/main.ml"
    "(\"Transom_template_module\", module_name name)";
  assert_contains "../templates/minimal/src-tauri/Cargo.toml" "serde_json";
  assert_contains "../templates/minimal/src-tauri/Cargo.toml" "tauri-build";
  assert_contains "../templates/minimal/src-tauri/build.rs" "tauri_build::build";
  assert (Sys.file_exists "../templates/minimal/src-tauri/icons/icon.ico");
  assert_contains "../templates/minimal/src-tauri/tauri.conf.json"
    "\"withGlobalTauri\": true";
  assert_contains "../templates/minimal/src-tauri/src/main.rs"
    "#[tauri::command]";
  assert_contains "../templates/minimal/src-tauri/src/main.rs" "fn transom_call";
  assert_contains "../templates/minimal/src-tauri/src/main.rs" "Mutex<Sidecar>";
  assert_contains "../templates/minimal/src-tauri/src/main.rs" "TRANSOM_SIDECAR";
  assert_contains "../templates/minimal/src-tauri/src/main.rs"
    "stderr(Stdio::inherit())";
  assert_contains "../templates/minimal/src-tauri/src/main.rs"
    "\"kind\": \"call\"";
  assert_contains "../templates/minimal/src-tauri/src/main.rs" "read_line";
  assert_contains "../templates/minimal/src-tauri/src/main.rs" "Some(\"ok\")";
  assert_contains "../templates/minimal/src-tauri/src/main.rs" "Some(\"err\")";
  assert_contains "../templates/minimal/src-tauri/src/main.rs" "Some(\"event\")";
  assert_contains "../templates/minimal/src-tauri/src/main.rs"
    ".manage(Mutex::new(Sidecar::new()))";
  assert_contains "../dune" "templates/minimal/frontend/tsconfig.json";
  assert_contains "../dune" "templates/minimal/frontend/src/api_types.ts"

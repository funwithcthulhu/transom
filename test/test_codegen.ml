let fixture = "fixtures/transom.json"

let contains text needle =
  let text_len = String.length text in
  let needle_len = String.length needle in
  let rec loop index =
    index + needle_len <= text_len
    && (String.sub text index needle_len = needle || loop (index + 1))
  in
  needle_len = 0 || loop 0

let manifest () =
  match Transom_codegen.Manifest.load_file fixture with
  | Ok manifest -> manifest
  | Error message -> failwith message

let custom_manifest : Transom_codegen.Manifest.t =
  {
    service_module = "Custom_server";
    types_module = "Domain_types";
    json_module = "Domain_json";
    typescript_types_module = "./domain_types";
    commands =
      [
        {
          name = "echo";
          request = "echo_req";
          response = "echo_res";
          event = None;
          ts_request = "EchoReq";
          ts_response = "EchoRes";
          ts_event = None;
        };
      ];
  }

let duplicate_manifest_json =
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

let empty_manifest : Transom_codegen.Manifest.t =
  { custom_manifest with commands = [] }

let expected_custom_ts =
  String.concat "\n"
    [
      "import type * as Api from \"./domain_types\";";
      "";
      "export interface TransomTransport {";
      "  call(method: string, params: unknown): Promise<unknown>;";
      "  stream?(";
      "    method: string,";
      "    params: unknown,";
      "    onEvent: (event: unknown) => void";
      "  ): Promise<unknown>;";
      "}";
      "";
      "export async function echo(";
      "  transport: TransomTransport,";
      "  req: Api.EchoReq";
      "): Promise<Api.EchoRes> {";
      "  return (await transport.call(\"echo\", req)) as Api.EchoRes;";
      "}";
      "";
    ]

let temp_dir prefix =
  let path = Filename.temp_file prefix "" in
  Sys.remove path;
  Unix.mkdir path 0o755;
  path

let expect_generate_error_without_files () =
  let dir = temp_dir "transom-codegen" in
  let manifest_file = Filename.concat dir "transom.json" in
  let out_dir = Filename.concat dir "out" in
  Unix.mkdir out_dir 0o755;
  Yojson.Safe.to_file manifest_file duplicate_manifest_json;
  (match Transom_codegen.generate ~manifest_file ~out_dir with
  | Ok files ->
      failwith
        ("expected duplicate command error, generated: "
       ^ String.concat ", " files)
  | Error message -> assert (contains message "duplicate command name"));
  assert (Sys.readdir out_dir = [||])

let () =
  let manifest = manifest () in
  let mli = Transom_codegen.Gen_ocaml_server.interface manifest in
  let ml = Transom_codegen.Gen_ocaml_server.implementation manifest in
  let ts = Transom_codegen.Gen_ts_client.implementation manifest in
  assert (contains mli "val ping :");
  assert (contains mli "Api_t.ping_req ->");
  assert (contains mli "emit:(Api_t.count_event -> unit) ->");
  assert (contains ml "| \"ping\" ->");
  assert (contains ml "| \"count\" ->");
  assert (contains ml "Transom_runtime.Error.unknown_method");
  assert (contains ts "export async function ping(");
  assert (contains ts "export async function count(");
  let custom_mli = Transom_codegen.Gen_ocaml_server.interface custom_manifest in
  let custom_ml =
    Transom_codegen.Gen_ocaml_server.implementation custom_manifest
  in
  let custom_ts =
    Transom_codegen.Gen_ts_client.implementation custom_manifest
  in
  assert (contains custom_mli "Domain_types.echo_req ->");
  assert (contains custom_ml "Domain_json.echo_req_of_string");
  assert (contains custom_ml "Domain_json.string_of_echo_res");
  assert (contains custom_ml "let _ = emit in");
  assert (custom_ts = expected_custom_ts);
  assert (
    List.exists
      (fun (name, _) -> name = "custom_server.ml")
      (Transom_codegen.generated_files custom_manifest));
  let empty_ml =
    Transom_codegen.Gen_ocaml_server.implementation empty_manifest
  in
  assert (contains empty_ml "let _ = params in");
  assert (contains empty_ml "let _ = emit in");
  expect_generate_error_without_files ();
  let dirs =
    Transom_codegen.template_dirs ~cwd:"C:/work/transom"
      ~env_template_dir:"C:/templates" ~opam_switch_prefix:"C:/opam" ()
  in
  assert (List.hd dirs = "C:/templates")

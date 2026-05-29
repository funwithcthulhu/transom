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

let () =
  let manifest = manifest () in
  let mli = Transom_codegen.Gen_ocaml_server.interface manifest in
  let ml = Transom_codegen.Gen_ocaml_server.implementation manifest in
  let ts = Transom_codegen.Gen_ts_client.implementation manifest in
  assert (contains mli "val ping :");
  assert (contains mli "Api_t.ping_req ->");
  assert (contains mli "emit:(Api_t.count_event -> unit) ->");
  assert (contains ml "Transom_runtime.Error.unknown_method");
  assert (contains ts "export async function ping");
  assert (contains ts "export async function count");
  let dirs =
    Transom_codegen.template_dirs ~cwd:"C:/work/transom"
      ~env_template_dir:"C:/templates" ~opam_switch_prefix:"C:/opam" ()
  in
  assert (List.hd dirs = "C:/templates")

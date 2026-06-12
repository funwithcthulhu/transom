type command_name = private string
type ocaml_module = private string
type ocaml_type = private string
type ts_type = private string
type typescript_module = private string

type command = private {
  name : command_name;
  request : ocaml_type;
  response : ocaml_type;
  event : ocaml_type option;
  ts_request : ts_type;
  ts_response : ts_type;
  ts_event : ts_type option;
}

type t = private {
  service_module : ocaml_module;
  types_module : ocaml_module;
  json_module : ocaml_module;
  typescript_types_module : typescript_module;
  commands : command list;
}

val command_name_to_string : command_name -> string
val ocaml_module_to_string : ocaml_module -> string
val ocaml_type_to_string : ocaml_type -> string
val ts_type_to_string : ts_type -> string
val typescript_module_to_string : typescript_module -> string
val of_yojson : Yojson.Safe.t -> (t, string) result
val load_file : string -> (t, string) result

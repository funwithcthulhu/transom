let interface_lines =
  [
    "export interface TransomTransport {";
    "  call(method: string, params: unknown): Promise<unknown>;";
    "  stream?(";
    "    method: string,";
    "    params: unknown,";
    "    onEvent: (event: unknown) => void";
    "  ): Promise<unknown>;";
    "}";
  ]

let command_name command = Manifest.command_name_to_string command.Manifest.name
let ts_type value = Manifest.ts_type_to_string value

let command_lines command =
  let name = command_name command in
  let ts_request = ts_type command.Manifest.ts_request in
  let ts_response = ts_type command.Manifest.ts_response in
  match command.Manifest.event with
  | None ->
      [
        Printf.sprintf "export async function %s(" name;
        "  transport: TransomTransport,";
        Printf.sprintf "  req: Api.%s" ts_request;
        Printf.sprintf "): Promise<Api.%s> {" ts_response;
        Printf.sprintf "  return (await transport.call(%S, req)) as Api.%s;"
          name ts_response;
        "}";
      ]
  | Some _ ->
      let ts_event =
        command.Manifest.ts_event
        |> Option.map Manifest.ts_type_to_string
        |> Option.value ~default:"unknown"
      in
      [
        Printf.sprintf "export async function %s(" name;
        "  transport: TransomTransport,";
        Printf.sprintf "  req: Api.%s," ts_request;
        Printf.sprintf "  onEvent: (event: Api.%s) => void" ts_event;
        Printf.sprintf "): Promise<Api.%s> {" ts_response;
        "  if (!transport.stream) {";
        "    throw new Error(\"Transom transport does not support streaming\");";
        "  }";
        Printf.sprintf
          "  return (await transport.stream(%S, req, event => onEvent(event as \
           Api.%s))) as Api.%s;"
          name ts_event ts_response;
        "}";
      ]

let implementation manifest =
  String.concat "\n"
    ([
       Printf.sprintf "import type * as Api from %S;"
         (Manifest.typescript_module_to_string
            manifest.Manifest.typescript_types_module);
       "";
     ]
    @ interface_lines @ [ "" ]
    @ List.concat_map
        (fun command -> command_lines command @ [ "" ])
        manifest.Manifest.commands)

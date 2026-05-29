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

let command_lines command =
  match command.Manifest.event with
  | None ->
      [
        Printf.sprintf "export async function %s(" command.name;
        "  transport: TransomTransport,";
        Printf.sprintf "  req: Api.%s" command.ts_request;
        Printf.sprintf "): Promise<Api.%s> {" command.ts_response;
        Printf.sprintf "  return (await transport.call(%S, req)) as Api.%s;"
          command.name command.ts_response;
        "}";
      ]
  | Some _ ->
      let ts_event = Option.value command.ts_event ~default:"unknown" in
      [
        Printf.sprintf "export async function %s(" command.name;
        "  transport: TransomTransport,";
        Printf.sprintf "  req: Api.%s," command.ts_request;
        Printf.sprintf "  onEvent: (event: Api.%s) => void" ts_event;
        Printf.sprintf "): Promise<Api.%s> {" command.ts_response;
        "  if (!transport.stream) {";
        "    throw new Error(\"Transom transport does not support streaming\");";
        "  }";
        Printf.sprintf
          "  return (await transport.stream(%S, req, event => onEvent(event as \
           Api.%s))) as Api.%s;"
          command.name ts_event command.ts_response;
        "}";
      ]

let implementation manifest =
  String.concat "\n"
    ([
       Printf.sprintf "import type * as Api from %S;"
         manifest.Manifest.typescript_types_module;
       "";
     ]
    @ interface_lines @ [ "" ]
    @ List.concat_map
        (fun command -> command_lines command @ [ "" ])
        manifest.Manifest.commands)

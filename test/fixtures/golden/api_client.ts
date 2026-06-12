import type * as Api from "./api_types";

export interface TransomTransport {
  call(method: string, params: unknown): Promise<unknown>;
  stream?(
    method: string,
    params: unknown,
    onEvent: (event: unknown) => void
  ): Promise<unknown>;
}

export async function echo(
  transport: TransomTransport,
  req: Api.EchoReq
): Promise<Api.EchoRes> {
  return (await transport.call("echo", req)) as Api.EchoRes;
}

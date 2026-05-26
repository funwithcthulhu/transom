type TransomTransport = {
  call(method: string, params: unknown): Promise<unknown>;
};

const output = document.querySelector<HTMLPreElement>("#output");
const button = document.querySelector<HTMLButtonElement>("#ping");

const transport: TransomTransport = {
  async call(method, params) {
    console.log("call", method, params);
    return { message: "wire this to the sidecar" };
  }
};

button?.addEventListener("click", async () => {
  const result = await transport.call("ping", { message: "hi" });
  if (output) {
    output.textContent = JSON.stringify(result, null, 2);
  }
});

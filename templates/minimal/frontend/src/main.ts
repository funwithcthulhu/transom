import { ping, type TransomTransport } from "./api_client.js";

declare global {
  interface Window {
    __TAURI__?: {
      core?: {
        invoke<T>(command: string, args?: Record<string, unknown>): Promise<T>;
      };
    };
  }
}

const output = document.querySelector<HTMLPreElement>("#output");
const button = document.querySelector<HTMLButtonElement>("#ping");

const transport: TransomTransport = {
  async call(method, params) {
    const invoke = window.__TAURI__?.core?.invoke;
    if (!invoke) {
      throw new Error("Tauri invoke API is not available");
    }
    return await invoke("transom_call", { method, params });
  }
};

button?.addEventListener("click", async () => {
  if (output) {
    output.textContent = "Calling OCaml sidecar...";
  }

  try {
    const result = await ping(transport, { message: "hi" });
    if (output) {
      output.textContent = JSON.stringify(result, null, 2);
    }
  } catch (error) {
    if (output) {
      output.textContent = error instanceof Error ? error.message : String(error);
    }
  }
});

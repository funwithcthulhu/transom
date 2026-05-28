use serde_json::{json, Value};
use std::env;
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::Mutex;
use tauri::State;

struct SidecarProcess {
    child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

struct Sidecar {
    process: Option<SidecarProcess>,
    next_id: u64,
}

struct BridgeError {
    message: String,
    reset_process: bool,
}

impl BridgeError {
    fn keep(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            reset_process: false,
        }
    }

    fn reset(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            reset_process: true,
        }
    }
}

impl Sidecar {
    fn new() -> Self {
        Self {
            process: None,
            next_id: 1,
        }
    }

    fn call(&mut self, method: String, params: Value) -> Result<Value, String> {
        let id = self.next_id;
        self.next_id += 1;

        let frame = json!({
            "kind": "call",
            "id": id,
            "method": method,
            "params": params
        });

        let result = match self.ensure_process() {
            Ok(process) => send_request(process, &frame).and_then(|_| read_response(process, id)),
            Err(err) => Err(BridgeError::keep(err)),
        };

        match result {
            Ok(value) => Ok(value),
            Err(err) => {
                if err.reset_process {
                    self.process = None;
                }
                Err(err.message)
            }
        }
    }

    fn ensure_process(&mut self) -> Result<&mut SidecarProcess, String> {
        let stopped = match self.process.as_mut() {
            Some(process) => match process.child.try_wait() {
                Ok(Some(status)) => {
                    Some(format!("OCaml sidecar exited before request: {}", status))
                }
                Ok(None) => None,
                Err(err) => Some(format!("failed to inspect OCaml sidecar: {}", err)),
            },
            None => None,
        };

        if let Some(message) = stopped {
            self.process = None;
            return Err(message);
        }

        if self.process.is_none() {
            self.process = Some(spawn_sidecar()?);
        }

        Ok(self.process.as_mut().expect("sidecar was just started"))
    }
}

fn sidecar_candidates() -> Vec<PathBuf> {
    let exe_name = if cfg!(windows) { "main.exe" } else { "main" };
    let mut candidates = Vec::new();

    if let Ok(path) = env::var("TRANSOM_SIDECAR") {
        candidates.push(PathBuf::from(path));
    }

    if let Ok(cwd) = env::current_dir() {
        for base in ["../backend", "backend", "../../backend"] {
            candidates.push(cwd.join(base).join("_build/default/bin").join(exe_name));
        }
    }

    candidates
}

fn sidecar_path() -> Result<PathBuf, String> {
    let candidates = sidecar_candidates();
    candidates
        .iter()
        .find(|path| path.is_file())
        .cloned()
        .ok_or_else(|| {
            let searched = candidates
                .iter()
                .map(|path| path.display().to_string())
                .collect::<Vec<_>>()
                .join("\n");
            format!("OCaml sidecar not found. Searched:\n{}", searched)
        })
}

fn spawn_sidecar() -> Result<SidecarProcess, String> {
    let path = sidecar_path()?;
    let mut child = Command::new(&path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|err| format!("failed to start OCaml sidecar: {}", err))?;

    let stdin = child
        .stdin
        .take()
        .ok_or_else(|| "failed to open sidecar stdin".to_string())?;
    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| "failed to open sidecar stdout".to_string())?;

    Ok(SidecarProcess {
        child,
        stdin,
        stdout: BufReader::new(stdout),
    })
}

fn send_request(process: &mut SidecarProcess, frame: &Value) -> Result<(), BridgeError> {
    writeln!(process.stdin, "{}", frame)
        .and_then(|_| process.stdin.flush())
        .map_err(|err| BridgeError::reset(format!("failed to write sidecar request: {}", err)))
}

fn read_response(process: &mut SidecarProcess, request_id: u64) -> Result<Value, BridgeError> {
    loop {
        let mut line = String::new();
        let bytes = process.stdout.read_line(&mut line).map_err(|err| {
            BridgeError::reset(format!("failed to read sidecar response: {}", err))
        })?;

        if bytes == 0 {
            let status = match process.child.try_wait() {
                Ok(Some(status)) => format!(": {}", status),
                Ok(None) => String::new(),
                Err(err) => format!("; failed to inspect exit status: {}", err),
            };
            return Err(BridgeError::reset(format!(
                "OCaml sidecar closed stdout before responding{}",
                status
            )));
        }

        let frame: Value = serde_json::from_str(line.trim_end())
            .map_err(|err| BridgeError::reset(format!("invalid sidecar JSON: {}", err)))?;

        match frame.get("kind").and_then(Value::as_str) {
            Some("ok") => {
                check_response_id(&frame, request_id)?;
                return Ok(frame.get("result").cloned().unwrap_or(Value::Null));
            }
            Some("err") => {
                check_response_id(&frame, request_id)?;
                return Err(BridgeError::keep(frame_error(&frame)));
            }
            Some("event") => {}
            Some(kind) => {
                return Err(BridgeError::reset(format!(
                    "unexpected sidecar frame: {}",
                    kind
                )))
            }
            None => return Err(BridgeError::reset("sidecar frame is missing kind")),
        }
    }
}

fn check_response_id(frame: &Value, request_id: u64) -> Result<(), BridgeError> {
    match frame.get("id").and_then(Value::as_u64) {
        Some(id) if id == request_id => Ok(()),
        Some(id) => Err(BridgeError::reset(format!(
            "sidecar response id {} did not match request id {}",
            id, request_id
        ))),
        None => Err(BridgeError::reset("sidecar response is missing id")),
    }
}

fn frame_error(frame: &Value) -> String {
    let Some(error) = frame.get("error") else {
        return "OCaml sidecar returned an error".to_string();
    };

    let code = error.get("code").and_then(Value::as_str);
    let message = error
        .get("message")
        .and_then(Value::as_str)
        .unwrap_or("OCaml sidecar returned an error");
    let data = error.get("data").filter(|value| !value.is_null());

    match (code, data) {
        (Some(code), Some(data)) => format!("{}: {} ({})", code, message, data),
        (Some(code), None) => format!("{}: {}", code, message),
        (None, Some(data)) => format!("{} ({})", message, data),
        (None, None) => message.to_string(),
    }
}

#[tauri::command]
fn transom_call(
    sidecar: State<'_, Mutex<Sidecar>>,
    method: String,
    params: Value,
) -> Result<Value, String> {
    let mut sidecar = sidecar
        .lock()
        .map_err(|_| "sidecar state lock is poisoned".to_string())?;
    sidecar.call(method, params)
}

fn main() {
    tauri::Builder::default()
        .manage(Mutex::new(Sidecar::new()))
        .invoke_handler(tauri::generate_handler![transom_call])
        .run(tauri::generate_context!())
        .expect("failed to run Tauri app");
}

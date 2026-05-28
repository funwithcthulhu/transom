use serde_json::{json, Value};
use std::env;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Stdio};

fn sidecar_candidates() -> Vec<PathBuf> {
    let exe_name = if cfg!(windows) { "main.exe" } else { "main" };
    let mut candidates = Vec::new();

    if let Ok(path) = env::var("TRANSOM_BACKEND") {
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

fn frame_error(frame: &Value) -> String {
    frame
        .get("error")
        .and_then(|error| error.get("message"))
        .and_then(Value::as_str)
        .unwrap_or("OCaml sidecar returned an error")
        .to_owned()
}

#[tauri::command]
fn transom_call(method: String, params: Value) -> Result<Value, String> {
    let path = sidecar_path()?;
    let mut child = Command::new(&path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|err| format!("failed to start OCaml sidecar: {}", err))?;

    let frame = json!({
        "kind": "call",
        "id": 1,
        "method": method,
        "params": params
    });

    let mut stdin = child
        .stdin
        .take()
        .ok_or_else(|| "failed to open sidecar stdin".to_string())?;
    writeln!(stdin, "{}", frame).map_err(|err| format!("failed to write request: {}", err))?;
    drop(stdin);

    let output = child
        .wait_with_output()
        .map_err(|err| format!("failed to read sidecar response: {}", err))?;
    let stdout = String::from_utf8_lossy(&output.stdout);

    for line in stdout.lines() {
        let frame: Value =
            serde_json::from_str(line).map_err(|err| format!("invalid sidecar JSON: {}", err))?;
        match frame.get("kind").and_then(Value::as_str) {
            Some("ok") => return Ok(frame.get("result").cloned().unwrap_or(Value::Null)),
            Some("err") => return Err(frame_error(&frame)),
            Some("event") => continue,
            Some(kind) => return Err(format!("unexpected sidecar frame: {}", kind)),
            None => return Err("sidecar frame is missing kind".to_string()),
        }
    }

    if output.status.success() {
        Err("OCaml sidecar returned no response".to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!("OCaml sidecar exited without a response: {}", stderr.trim()))
    }
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![transom_call])
        .run(tauri::generate_context!())
        .expect("failed to run Tauri app");
}

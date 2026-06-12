param(
  [string]$ProjectName = "hello-transom",
  [string]$WorkDir = "",
  [switch]$Keep
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "missing required command: $Name"
  }
}

function Run {
  param(
    [string]$File,
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  Push-Location $WorkingDirectory
  try {
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "$File $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
  }
  finally {
    Pop-Location
  }
}

function Invoke-Sidecar {
  param(
    [string]$File,
    [string]$Line
  )

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $requestFile = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllBytes(
    $requestFile,
    [System.Text.Encoding]::UTF8.GetBytes($Line + "`n")
  )

  if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
    $startInfo.FileName = "cmd.exe"
    $startInfo.Arguments = ('/c type "{0}" | "{1}"' -f $requestFile, $File)
  }
  else {
    $escapedRequest = $requestFile.Replace("'", "'\''")
    $escapedFile = $File.Replace("'", "'\''")
    $startInfo.FileName = "/bin/sh"
    $startInfo.Arguments = "-c `"cat '$escapedRequest' | '$escapedFile'`""
  }

  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  try {
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd().Trim()
    $stderr = $process.StandardError.ReadToEnd().Trim()
    $process.WaitForExit()
  }
  finally {
    Remove-Item -LiteralPath $requestFile -Force
  }

  if ($process.ExitCode -ne 0) {
    throw "$File failed with exit code $($process.ExitCode): $stderr"
  }

  return $stdout
}

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")

foreach ($tool in @("dune", "atdgen", "npm", "cargo")) {
  Require-Command $tool
}

$createdTemp = $false
if ($WorkDir -eq "") {
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("transom-template-smoke-" + [Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $root | Out-Null
  $createdTemp = $true
}
else {
  $root = $WorkDir
  New-Item -ItemType Directory -Force -Path $root | Out-Null
}

try {
  Run "dune" @("exec", "--", "transom", "new", $ProjectName, "--dir", $root) $repo

  $project = Join-Path $root $ProjectName
  $backend = Join-Path $project "backend"
  $frontend = Join-Path $project "frontend"
  $tauriManifest = Join-Path $project "src-tauri/Cargo.toml"
  $backendBin = Join-Path $backend "bin"

  Run "atdgen" @("-t", "-o", "bin/api", "api.atd") $backend
  Run "atdgen" @("-j", "-o", "bin/api", "api.atd") $backend
  Run "dune" @(
    "exec",
    "--",
    "transom",
    "gen",
    "--manifest",
    (Join-Path $backend "transom.json"),
    "--out",
    $backendBin
  ) $repo
  Run "dune" @("build") $backend

  $exeName = if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
    "main.exe"
  }
  else {
    "main"
  }
  $sidecar = Join-Path $backend "_build/default/bin/$exeName"
  $request = '{"kind":"call","id":1,"method":"ping","params":{"message":"hello"}}'
  $response = Invoke-Sidecar $sidecar $request
  if ($response -ne '{"kind":"ok","id":1,"result":{"message":"pong: hello"}}') {
    throw "unexpected sidecar response: $response"
  }

  Copy-Item (Join-Path $backendBin "api_client.ts") (Join-Path $frontend "src/api_client.ts")
  Run "npm" @("install", "--prefix", $frontend) $project
  Run "npm" @("--prefix", $frontend, "run", "build") $project
  Run "cargo" @("check", "--manifest-path", $tauriManifest) $project

  Write-Host "minimal template smoke passed: $project"
}
finally {
  if ($createdTemp -and -not $Keep) {
    Remove-Item -LiteralPath $root -Recurse -Force
  }
}

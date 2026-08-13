param(
    [string]$GodotPath = "D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ExportPath = Join-Path $ProjectRoot "docs\index.html"
$ExportDirectory = Split-Path -Parent $ExportPath
$ProjectAppData = Join-Path $ProjectRoot ".validation-appdata"
$TemplateDirectory = Join-Path $ProjectAppData "Godot\export_templates\4.6.2.stable"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "找不到 Godot console executable：$GodotPath"
}

if (-not (Test-Path -LiteralPath (Join-Path $TemplateDirectory "web_release.zip") -PathType Leaf)) {
    throw "找不到 Godot 4.6.2 Web export template：$TemplateDirectory"
}

New-Item -ItemType Directory -Force -Path $ExportDirectory | Out-Null

$PreviousAppData = $env:APPDATA
try {
    $env:APPDATA = $ProjectAppData
    & $GodotPath --headless --path $ProjectRoot --export-release Web $ExportPath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot Web 匯出失敗，exit code：$LASTEXITCODE"
    }
}
finally {
    $env:APPDATA = $PreviousAppData
}

Set-Content -LiteralPath (Join-Path $ExportDirectory ".nojekyll") -Value "" -NoNewline
Write-Host "Web export ready: $ExportPath"


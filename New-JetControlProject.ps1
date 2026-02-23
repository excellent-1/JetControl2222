param(
  [string]$Root = "JetControl2222Hz"
)

$ErrorActionPreference = "Stop"

# Shared helper used by the other scripts (they are dot-sourced into this scope).
function WriteFile([string]$Path, [string]$Content) {
  $dir = Split-Path $Path -Parent
  if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

# Create repo folder and expose paths for dot-sourced scripts
$RootDir = (Resolve-Path ".").Path
$RepoDir = Join-Path $RootDir $Root

Write-Host "Creating solution in: $RepoDir"

if (!(Test-Path $RepoDir)) { New-Item -ItemType Directory -Path $RepoDir | Out-Null }
Set-Location $RepoDir

# Ensure scripts folder exists (you will place the 3 scripts below into it)
if (!(Test-Path (Join-Path $RepoDir "scripts"))) {
  New-Item -ItemType Directory -Path (Join-Path $RepoDir "scripts") | Out-Null
}

# Dot-source the smaller scripts (run in same scope so they can use WriteFile / variables)
. (Join-Path $RepoDir "scripts/01-CreateSolution.ps1")
. (Join-Path $RepoDir "scripts/02-WriteCode.ps1")
. (Join-Path $RepoDir "scripts/03-WriteVSCode.ps1")

Write-Host ""
Write-Host "Done."
Write-Host "Next:"
Write-Host "  code $RepoDir"
Write-Host "  dotnet test"
Write-Host "  dotnet run --project src/JetControl.Runner/JetControl.Runner.csproj"
<#
Creates:
- ./Makefile                    (local build/test/run commands)
- ./.github/workflows/deployment.yml  (GitHub Actions CI "deployment" workflow)

Run from the repo root (where JetControl.sln is):
  pwsh .\New-BuildAndDeployFiles.ps1
#>

param(
  [string]$Solution = "JetControl.sln",
  [string]$RunnerProject = "src/JetControl.Runner/JetControl.Runner.csproj"
)

$ErrorActionPreference = "Stop"

function WriteFile([string]$Path, [string]$Content) {
  $dir = Split-Path $Path -Parent
  if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

if (!(Test-Path $Solution)) {
  throw "Can't find $Solution. Run this from the repo root."
}

# --------------------------
# Makefile (local)
# --------------------------
WriteFile "Makefile" @"
# Makefile for local developer workflow (requires: dotnet SDK, and 'make' installed)
#
# Notes:
# - This project is .NET, so 'dotnet' is the primary build tool.
# - 'make' is just a convenience wrapper for repeatable commands.
#
# Windows:
# - You can install make via Chocolatey: choco install make
# - Or use WSL / Git Bash / MSYS2
#
# Usage examples:
#   make restore
#   make build
#   make test
#   make run
#   make test-timing

SOLUTION := $Solution
RUNNER_PROJECT := $RunnerProject
CONFIG := Debug

.PHONY: help restore build test run clean publish test-timing

help:
	@echo "Targets:"
	@echo "  restore       - dotnet restore"
	@echo "  build         - dotnet build"
	@echo "  test          - dotnet test"
	@echo "  test-timing   - dotnet test with timing smoke tests enabled"
	@echo "  run           - run the console demo"
	@echo "  clean         - dotnet clean"
	@echo "  publish       - dotnet publish runner to ./artifacts/publish"

restore:
	dotnet restore $(SOLUTION)

build:
	dotnet build $(SOLUTION) -c $(CONFIG) --no-restore

test:
	dotnet test $(SOLUTION) -c $(CONFIG) --no-build

# Timing smoke tests are opt-in because they can be flaky on shared machines/CI
test-timing:
	RUN_TIMING_TESTS=true dotnet test $(SOLUTION) -c $(CONFIG) --no-build

run:
	dotnet run --project $(RUNNER_PROJECT) -c $(CONFIG)

clean:
	dotnet clean $(SOLUTION) -c $(CONFIG)

publish:
	dotnet publish $(RUNNER_PROJECT) -c Release -o artifacts/publish
"@

# --------------------------
# GitHub Actions workflow
# --------------------------
WriteFile ".github/workflows/deployment.yml" @"
name: deployment

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build_test:
    name: Build + Test (.NET)
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.0.x"

      - name: Restore
        run: dotnet restore $Solution

      - name: Build
        run: dotnet build $Solution -c Release --no-restore

      - name: Test (unit tests)
        run: dotnet test $Solution -c Release --no-build

      # Timing tests are intentionally NOT run by default (can be flaky).
      # If you want them, uncomment the step below.
      # - name: Test (timing smoke tests)
      #   env:
      #     RUN_TIMING_TESTS: "true"
      #   run: dotnet test $Solution -c Release --no-build

  publish_artifact:
    name: Publish Runner Artifact
    runs-on: ubuntu-latest
    needs: build_test
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.0.x"

      - name: Publish (self-contained = false)
        run: dotnet publish $RunnerProject -c Release -o artifacts/publish

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: JetControl.Runner-publish
          path: artifacts/publish
"@

Write-Host "Created Makefile"
Write-Host "Created .github/workflows/deployment.yml"
Write-Host "Done."
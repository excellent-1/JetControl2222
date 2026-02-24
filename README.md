# JetControl2222Hz (Illustrative Mission Computer + Flight Control Tick Loop)

This repository is a **safe, illustrative** .NET project that implements a **high-rate “tick loop”** (targeting **2222 Hz**) .

It models (at a high level and with placeholder logic) a fighter-jet style software loop that runs:

- **Airworthiness / Pre-Flight checks (Built-In Tests / BIT)**
  - Hydraulic pressure
  - Engine health + fuel status
  - Navigation readiness (GPS/INS quality)
  - Flight control surface command sanity checks
  - Structural / sensor checks (placeholder)

- **Weapon readiness / Pre-shot checks**
  - Master Arm switch
  - Station selection
  - Weapon power and seeker communication
  - Target in firing envelope
  - Weapon bay doors open / clearance

# Important: This is **not** real aircraft/F-35 software. All thresholds/logic are placeholders to demonstrate software design, testing, and timing instrumentation patterns.


## Repository Layout
src/
JetControl/ # Core library: loop, tasks, models, budget enforcement
JetControl.Runner/ # Console demo runner
tests/
JetControl.Tests/ # xUnit unit tests + timing smoke tests (opt-in)
.github/workflows/
deployment.yml # GitHub Actions CI (build/test/publish artifact)
Makefile # Local developer commands (make build/test/run)
global.json # Pinned .NET SDK version (net10 preview)

## Quick Start (Windows PowerShell)
From repo root:

1) Restore dependencies
make restore

2) Build everything (runner + tests)
make build-all

3) Run unit tests
make test

4) Run the console demo
make run
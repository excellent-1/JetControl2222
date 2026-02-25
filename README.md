## ﻿JetControl2222Hz (Illustrative Mission Computer + Flight Control Tick Loop)
This repository is a safe, illustrative .NET project that implements a high-rate “tick loop” (targeting 2222 Hz).
It models (at a high level and with placeholder logic) a fighter-jet style software loop that runs:

- Airworthiness / Pre-Flight checks (Built-In Tests / BIT)
  - Hydraulic pressure
  - Engine health + fuel status
  - Navigation readiness (GPS/INS quality)
  - Flight control surface command sanity checks
  - Structural / sensor checks (placeholder)

- Weapon readiness / Pre-shot checks
  - Master Arm switch
  - Station selection
  - Weapon power and seeker communication
  - Target in firing envelope
  - Weapon bay doors open / clearance

This is not real aircraft software. All thresholds/logic are placeholders to demonstrate software design, testing, and timing instrumentation patterns.


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


## Quick Start
From repo root:

1) Restore dependencies
make restore

2) Build everything (runner + tests)
make build-all

3) Run unit tests
make test

4) Run the console demo
make run


## Core Concept: A “Tick Loop” Composed of Tasks
    
    FlightControlLoop
        The heart of the system is a loop that runs a list of tasks every tick:
            
            FlightControlLoop.OnTick(ref JetState state, ref JetCommands commands)
            The loop:
                does not contain domain logic
                only orchestrates tasks
                is open for extension by adding tasks
    
            IPerTickTask
                Each unit of work implements:
                    public interface IPerTickTask
                    {
                        string Name { get; }
                        TimeSpan Budget { get; }
                        void Execute(ref JetState state, ref JetCommands commands);
                    }
                    This enables:
                        pluggable tasks (polymorphism)
                        deterministic sequencing
                        per-task time budgets

    Implemented Tasks (Business Rules)
        
        Airworthiness / BIT tasks (illustrative)
            RateDividerTask
                Runs first, sets commands.IsLogTick every N ticks (default 1000)
                Prevents expensive console logging from occurring every tick
            BuiltInTestSummaryTask
                Aggregates core “LRU health” indicators into a commands.BitOk flag
            FlightControlSurfaceBitTask
                Validates/clamps surface commands into safe normalized bounds
            EngineAndFuelMonitoringTask
                Applies basic gating rules (e.g., degraded engine health caps throttle)
                Low fuel can force BIT false (airworthiness issue)
            NavigationAvionicsBitTask
                Degrades BIT if GPS/INS quality is poor
            StructuralSensorsBitTask
                Placeholder representing structural/sensor checks
    
    Weapon readiness tasks (illustrative)
        WeaponReadinessTask
            Computes commands.WeaponReady based on:
                Master Arm ON
                Station selected
                Weapon powered
                Seeker communicating
                Target in envelope
                Bay doors open / clearance

    Logging policy
        
        To keep the tick loop lightweight:
            tasks still compute every tick
            human-readable Information logs print only when commands.IsLogTick is true (default every 1000 ticks)

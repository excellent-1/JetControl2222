function New-JetControl2222HzProject {
  param(
    [string]$Root = "JetControl2222Hz"
  )

  $ErrorActionPreference = "Stop"

  function WriteFile([string]$Path, [string]$Content) {
    $dir = Split-Path $Path -Parent
    if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Set-Content -Path $Path -Value $Content -Encoding UTF8
  }

  # Resolve output directory (allow relative or absolute)
  $RepoDir = if ([System.IO.Path]::IsPathRooted($Root)) {
    $Root
  } else {
    Join-Path (Get-Location).Path $Root
  }

  Write-Host "Creating solution in: $RepoDir"

  if (!(Test-Path $RepoDir)) { New-Item -ItemType Directory -Path $RepoDir | Out-Null }

  Push-Location $RepoDir
  try {
    # --- Create solution + projects ---
    dotnet new sln -n JetControl | Out-Host

    dotnet new classlib -n JetControl -o src/JetControl | Out-Host
    dotnet new console  -n JetControl.Runner -o src/JetControl.Runner | Out-Host
    dotnet new xunit    -n JetControl.Tests -o tests/JetControl.Tests | Out-Host

    # --- Add to solution ---
    dotnet sln add src/JetControl/JetControl.csproj | Out-Host
    dotnet sln add src/JetControl.Runner/JetControl.Runner.csproj | Out-Host
    dotnet sln add tests/JetControl.Tests/JetControl.Tests.csproj | Out-Host

    # --- References ---
    dotnet add src/JetControl.Runner/JetControl.Runner.csproj reference src/JetControl/JetControl.csproj | Out-Host
    dotnet add tests/JetControl.Tests/JetControl.Tests.csproj reference src/JetControl/JetControl.csproj | Out-Host

    # --- Packages (logging) ---
    dotnet add src/JetControl/JetControl.csproj package Serilog --version 3.* | Out-Host
    dotnet add src/JetControl/JetControl.csproj package Serilog.Sinks.Console --version 6.* | Out-Host

    dotnet add src/JetControl.Runner/JetControl.Runner.csproj package Serilog --version 3.* | Out-Host
    dotnet add src/JetControl.Runner/JetControl.Runner.csproj package Serilog.Sinks.Console --version 6.* | Out-Host

    # Remove placeholder
    Remove-Item src/JetControl/Class1.cs -ErrorAction SilentlyContinue

    # ======================
    # Write library code
    # ======================

    WriteFile "src/JetControl/Abstractions.cs" @'
using System;

namespace JetControl;

/*
OOP + SOLID mapping:
- Abstraction: interfaces define contracts (what) without implementation (how).
- DIP: high-level loop depends on abstractions (interfaces) rather than concrete classes.
- ISP: separate responsibilities into small interfaces (tick source vs per-tick task).
*/

/// <summary>Interrupt/timer-like tick source (simulated or hardware-backed).</summary>
public interface IHighRateTickSource
{
    event Action Tick;
}

/// <summary>Polymorphic unit of work executed each tick.</summary>
public interface IPerTickTask
{
    string Name { get; }

    /// <summary>
    /// Business rule: each tick has a fixed period (2222 Hz => ~450 µs).
    /// Each task declares a time budget to enforce/test.
    /// </summary>
    TimeSpan Budget { get; }

    void Execute(ref JetState state, ref JetCommands commands);
}
'@

    WriteFile "src/JetControl/Models.cs" @'
namespace JetControl;

/*
Simple models passed through tasks.

Encapsulation:
- Tasks may keep private internal state (filters, counters, thresholds).
- The loop only sees Execute(...), not internal details.
*/

public struct JetState
{
    // Airworthiness/system health placeholders (NOT real aircraft logic)
    public double HydraulicPressure;
    public double EngineHealthIndex;
    public double FuelRemainingKg;
    public double GpsLockQuality;
    public double InsAlignmentQuality;

    // Flight dynamics placeholders
    public double Pitch, Roll, Yaw;
    public double P, Q, R;

    // Weapon readiness placeholders
    public bool MasterArmOn;
    public int SelectedStation;
    public bool WeaponPowered;
    public bool SeekerCommunicating;
    public bool TargetInEnvelope;
    public bool WeaponBayDoorsOpen;
}

public struct JetCommands
{
    // Actuator command placeholders
    public double Aileron, Elevator, Rudder, Throttle;

    // Status flags
    public bool BitOk;
    public bool WeaponReady;
}
'@

    WriteFile "src/JetControl/FlightControlLoop.cs" @'
using System;
using System.Collections.Generic;

namespace JetControl;

/*
SOLID:
- SRP: this type orchestrates per-tick execution only.
- OCP: add/replace tasks without changing the loop.
- DIP: depends on IPerTickTask abstraction.
- Composition: loop "has-a" list of tasks and delegates work to them.
*/

public sealed class FlightControlLoop
{
    public const int RateHz = 2222;
    public static readonly TimeSpan Period = TimeSpan.FromSeconds(1.0 / RateHz);

    private readonly IReadOnlyList<IPerTickTask> _tasks;

    public FlightControlLoop(IReadOnlyList<IPerTickTask> tasks) => _tasks = tasks;

    public void OnTick(ref JetState state, ref JetCommands commands)
    {
        foreach (var task in _tasks)
            task.Execute(ref state, ref commands);
    }
}
'@

    WriteFile "src/JetControl/BudgetEnforcingTask.cs" @'
using System;
using System.Diagnostics;
using Serilog;

namespace JetControl;

/*
Decorator (composition) that adds timing enforcement + logging without modifying tasks:
- OCP: extend behavior by wrapping.
- DIP: wrapper depends on IPerTickTask abstraction.
*/

public sealed class BudgetEnforcingTask : IPerTickTask
{
    private readonly IPerTickTask _inner;
    private readonly ILogger _log;

    public BudgetEnforcingTask(IPerTickTask inner, ILogger log)
    {
        _inner = inner;
        _log = log;
    }

    public string Name => _inner.Name;
    public TimeSpan Budget => _inner.Budget;

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        var sw = Stopwatch.StartNew();
        _inner.Execute(ref state, ref commands);
        sw.Stop();

        if (sw.Elapsed > Budget)
        {
            _log.Error("Task {Task} exceeded budget. Elapsed={Elapsed} Budget={Budget}",
                Name, sw.Elapsed, Budget);

            throw new TimeoutException($"{Name} exceeded budget. Elapsed={sw.Elapsed} Budget={Budget}");
        }
    }
}
'@

    WriteFile "src/JetControl/Tasks.BitAndReadiness.cs" @'
using System;
using Serilog;

namespace JetControl;

/*
Requested task list (modeled as safe, illustrative checks):

Pre-Flight Software Checks (Airworthiness & Systems)
- BIT Summary (LRU operational status)
- Flight Control System surface command sanity (aileron/elevator/rudder bounds)
- Engine & Fuel monitoring (health + fuel gating)
- Navigation & Avionics (GPS/INS gating)
- Structural Integrity & Sensors (placeholder)

Pre-Shot Software Checks (Weapon Readiness & Targeting)
- Master Arm ON
- Station selected
- Weapon power & communication (seeker comm)
- Target within firing envelope
- Weapon bay doors open / clearance

Note: Real systems typically run different checks at different rates; here everything runs per tick to demonstrate SOLID/OOP.
*/

public sealed class BuiltInTestSummaryTask : IPerTickTask
{
    private readonly ILogger _log;

    // Encapsulation: thresholds are private implementation details.
    private const double MinHydraulic = 1.0;
    private const double MinEngineHealth = 0.5;
    private const double MinFuelKg = 100.0;
    private const double MinGpsQuality = 0.6;
    private const double MinInsQuality = 0.6;

    public BuiltInTestSummaryTask(ILogger log) => _log = log;

    public string Name => "BIT Summary (LRU Health)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(60);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // SRP: this task only evaluates BIT status.
        var ok =
            state.HydraulicPressure >= MinHydraulic &&
            state.EngineHealthIndex >= MinEngineHealth &&
            state.FuelRemainingKg >= MinFuelKg &&
            state.GpsLockQuality >= MinGpsQuality &&
            state.InsAlignmentQuality >= MinInsQuality;

        commands.BitOk = ok;
        _log.Information("BIT={BitOk}", ok);
    }
}

public sealed class FlightControlSurfaceBitTask : IPerTickTask
{
    private readonly ILogger _log;
    public FlightControlSurfaceBitTask(ILogger log) => _log = log;

    public string Name => "FCS Surface Check";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(50);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // Business rule: ensure normalized actuator commands remain in safe bounds [-1..1].
        commands.Aileron  = Clamp(commands.Aileron,  -1, 1);
        commands.Elevator = Clamp(commands.Elevator, -1, 1);
        commands.Rudder   = Clamp(commands.Rudder,   -1, 1);

        _log.Debug("FCS normalized.");
    }

    private static double Clamp(double v, double min, double max)
        => v < min ? min : (v > max ? max : v);
}

public sealed class EngineAndFuelMonitoringTask : IPerTickTask
{
    private readonly ILogger _log;
    public EngineAndFuelMonitoringTask(ILogger log) => _log = log;

    public string Name => "Engine & Fuel Monitoring";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(40);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // Illustrative gating: if engine health is degraded, cap throttle.
        if (state.EngineHealthIndex < 0.6)
            commands.Throttle = Math.Min(commands.Throttle, 0.7);

        // Illustrative: low fuel => not airworthy => BIT false.
        if (state.FuelRemainingKg < 80)
            commands.BitOk = false;

        _log.Debug("Engine/Fuel checked.");
    }
}

public sealed class NavigationAvionicsBitTask : IPerTickTask
{
    private readonly ILogger _log;
    public NavigationAvionicsBitTask(ILogger log) => _log = log;

    public string Name => "Navigation & Avionics (GPS/INS)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(40);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // Business rule: nav readiness requires adequate GPS and INS quality.
        if (state.GpsLockQuality < 0.6 || state.InsAlignmentQuality < 0.6)
            commands.BitOk = false;

        _log.Debug("Nav checked.");
    }
}

public sealed class StructuralSensorsBitTask : IPerTickTask
{
    private readonly ILogger _log;
    public StructuralSensorsBitTask(ILogger log) => _log = log;

    public string Name => "Structural/Sensors BIT (Placeholder)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(30);

    public void Execute(ref JetState state, ref JetCommands commands)
        => _log.Debug("Structural/sensors checked.");
}

public sealed class WeaponReadinessTask : IPerTickTask
{
    private readonly ILogger _log;
    public WeaponReadinessTask(ILogger log) => _log = log;

    public string Name => "Weapon Readiness (Pre-Shot)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(60);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // Business rule: "ready" only if all gates pass.
        var ready =
            state.MasterArmOn &&
            state.SelectedStation > 0 &&
            state.WeaponPowered &&
            state.SeekerCommunicating &&
            state.TargetInEnvelope &&
            state.WeaponBayDoorsOpen;

        commands.WeaponReady = ready;
        _log.Information("WeaponReady={Ready}", ready);
    }
}
'@

    WriteFile "src/JetControl/TaskFactory.cs" @'
using System.Collections.Generic;
using Serilog;

namespace JetControl;

/*
SRP: this class only wires tasks together.
Composition: builds the pipeline list.
*/

public static class TaskFactory
{
    public static IReadOnlyList<IPerTickTask> CreatePerTickTasks(ILogger log, bool enforceBudgets)
    {
        var tasks = new List<IPerTickTask>
        {
            // Pre-flight BIT checks
            new BuiltInTestSummaryTask(log),
            new FlightControlSurfaceBitTask(log),
            new EngineAndFuelMonitoringTask(log),
            new NavigationAvionicsBitTask(log),
            new StructuralSensorsBitTask(log),

            // Pre-shot weapon readiness
            new WeaponReadinessTask(log),
        };

        if (!enforceBudgets)
            return tasks;

        // OCP via decorator: add timing enforcement without editing each task.
        var wrapped = new List<IPerTickTask>(tasks.Count);
        foreach (var t in tasks)
            wrapped.Add(new BudgetEnforcingTask(t, log));

        return wrapped;
    }
}
'@

    # ======================
    # Runner
    # ======================

    WriteFile "src/JetControl.Runner/Program.cs" @'
using System.Threading;
using JetControl;
using Serilog;

/*
Runner demonstrates:
- Composition: building the loop from tasks
- Logging: Serilog to console
- NOT real interrupt scheduling; just a demo driver
*/

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .CreateLogger();

var log = Log.Logger;

log.Information("Starting demo at {Rate} Hz (Period ~ {Period} us)",
    FlightControlLoop.RateHz, FlightControlLoop.Period.TotalMicroseconds);

var tasks = TaskFactory.CreatePerTickTasks(log, enforceBudgets: true);
var loop = new FlightControlLoop(tasks);

var state = new JetState
{
    HydraulicPressure = 1.2,
    EngineHealthIndex = 0.9,
    FuelRemainingKg = 500,
    GpsLockQuality = 0.9,
    InsAlignmentQuality = 0.9,

    MasterArmOn = true,
    SelectedStation = 1,
    WeaponPowered = true,
    SeekerCommunicating = true,
    TargetInEnvelope = true,
    WeaponBayDoorsOpen = true
};

var commands = new JetCommands { Aileron = 0.1, Elevator = -0.1, Throttle = 0.8 };

for (int i = 0; i < 20; i++)
{
    loop.OnTick(ref state, ref commands);
    state.FuelRemainingKg -= 0.5;

    Thread.Sleep(50); // readability (not real-time)
}

log.Information("Done.");
'@

    # ======================
    # Tests
    # ======================

    WriteFile "tests/JetControl.Tests/BudgetContractTests.cs" @'
using System;
using System.Linq;
using JetControl;
using Serilog;
using Xunit;

/*
Deterministic unit test:
- Enforces the design rule that declared budgets fit within the 2222 Hz tick period.
*/

public class BudgetContractTests
{
    [Fact]
    public void DeclaredTaskBudgets_MustFitWithinTickPeriod()
    {
        var log = new LoggerConfiguration().CreateLogger();
        var tasks = TaskFactory.CreatePerTickTasks(log, enforceBudgets: false);

        var period = FlightControlLoop.Period;

        foreach (var t in tasks)
            Assert.True(t.Budget <= period, $"{t.Name} budget {t.Budget} exceeds tick period {period}");

        var total = tasks.Aggregate(TimeSpan.Zero, (acc, t) => acc + t.Budget);
        Assert.True(total <= period, $"Sum of budgets {total} exceeds tick period {period}");
    }
}
'@

    WriteFile "tests/JetControl.Tests/BudgetEnforcerTests.cs" @'
using System;
using System.Threading;
using JetControl;
using Serilog;
using Xunit;

public class BudgetEnforcerTests
{
    private sealed class SlowTask : IPerTickTask
    {
        public string Name => "Slow Task";
        public TimeSpan Budget => TimeSpan.FromMicroseconds(20);

        public void Execute(ref JetState state, ref JetCommands commands) => Thread.Sleep(1);
    }

    [Fact]
    public void BudgetEnforcingTask_Throws_WhenBudgetExceeded()
    {
        var log = new LoggerConfiguration().CreateLogger();
        var wrapped = new BudgetEnforcingTask(new SlowTask(), log);

        var state = new JetState();
        var commands = new JetCommands();

        Assert.Throws<TimeoutException>(() => wrapped.Execute(ref state, ref commands));
    }
}
'@

    WriteFile "tests/JetControl.Tests/TimingSmokeTests.cs" @'
using System;
using System.Diagnostics;
using JetControl;
using Serilog;
using Xunit;

/*
Timing smoke test (opt-in via RUN_TIMING_TESTS=true):
- Desktop/CI timing is noisy; enable explicitly.
- Checks per-task elapsed time <= tick period (~450 µs).
*/

public class TimingSmokeTests
{
    [Fact]
    public void PerTask_Elapsed_ShouldBeUnder_2222Hz_Period_WhenEnabled()
    {
        if (!string.Equals(Environment.GetEnvironmentVariable("RUN_TIMING_TESTS"), "true", StringComparison.OrdinalIgnoreCase))
            return;

        var log = new LoggerConfiguration().CreateLogger();
        var tasks = TaskFactory.CreatePerTickTasks(log, enforceBudgets: false);
        var period = FlightControlLoop.Period;

        var state = new JetState
        {
            HydraulicPressure = 1.2,
            EngineHealthIndex = 0.9,
            FuelRemainingKg = 500,
            GpsLockQuality = 0.9,
            InsAlignmentQuality = 0.9,
            MasterArmOn = true,
            SelectedStation = 1,
            WeaponPowered = true,
            SeekerCommunicating = true,
            TargetInEnvelope = true,
            WeaponBayDoorsOpen = true
        };

        var commands = new JetCommands { Aileron = 0.1, Elevator = -0.1, Throttle = 0.8 };

        // Warm-up (reduce JIT impact)
        for (int i = 0; i < 2000; i++)
            foreach (var t in tasks) t.Execute(ref state, ref commands);

        foreach (var t in tasks)
        {
            var sw = Stopwatch.StartNew();
            t.Execute(ref state, ref commands);
            sw.Stop();

            Assert.True(sw.Elapsed <= period,
                $"{t.Name} took {sw.Elapsed.TotalMicroseconds:F1}us > period {period.TotalMicroseconds:F1}us");
        }
    }
}
'@

    # ======================
    # VS Code + README
    # ======================

    WriteFile ".vscode/tasks.json" @'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build",
      "command": "dotnet",
      "type": "process",
      "args": ["build", "JetControl.sln", "-c", "Debug"],
      "problemMatcher": "$msCompile"
    },
    {
      "label": "test",
      "command": "dotnet",
      "type": "process",
      "args": ["test", "JetControl.sln", "-c", "Debug"],
      "problemMatcher": "$msCompile"
    },
    {
      "label": "run",
      "command": "dotnet",
      "type": "process",
      "args": ["run", "--project", "src/JetControl.Runner/JetControl.Runner.csproj"],
      "problemMatcher": "$msCompile"
    }
  ]
}
'@

    WriteFile ".vscode/launch.json" @'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": ".NET Run Runner",
      "type": "coreclr",
      "request": "launch",
      "preLaunchTask": "build",
      "program": "${workspaceFolder}/src/JetControl.Runner/bin/Debug/net8.0/JetControl.Runner.dll",
      "args": [],
      "cwd": "${workspaceFolder}",
      "console": "integratedTerminal",
      "stopAtEntry": false
    }
  ]
}
'@

    WriteFile "README.md" @'
# JetControl2222Hz (Illustrative)

Build/test/run:

dotnet build
dotnet test
dotnet run --project src/JetControl.Runner
'@

  }
  finally {
    Pop-Location
  }
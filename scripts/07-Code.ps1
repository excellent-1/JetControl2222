# ===== Block 7/7 =====
$ErrorActionPreference = "Stop"

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
Timing smoke test (opt-in):
- Desktop/CI timing is noisy; enable explicitly via RUN_TIMING_TESTS=true
- Checks each task's elapsed time <= tick period (~450 µs).
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

        // Warm-up to reduce JIT impact
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
```bash
dotnet build
dotnet test
dotnet run --project src/JetControl.Runner
'@
# ===== Block 3/7 =====
$ErrorActionPreference = "Stop"

WriteFile "src/JetControl/FlightControlLoop.cs" @'
using System;
using System.Collections.Generic;

namespace JetControl;

/*
SOLID:
- SRP: orchestrates task execution only.
- OCP: add new tasks without modifying this loop.
- DIP: depends on IPerTickTask abstraction.
- Composition: the loop has-a list of tasks.
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
Decorator via composition:
- OCP: add timing enforcement without editing each task.
- DIP: depends on IPerTickTask abstraction.
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

Write-Host "Block 3 complete."
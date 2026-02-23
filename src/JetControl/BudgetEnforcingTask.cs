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

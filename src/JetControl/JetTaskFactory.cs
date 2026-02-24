using System.Collections.Generic;
using Serilog;
using Serilog.Events;

namespace JetControl;

/*
SRP: builds the task pipeline; loop execution is elsewhere.
Composition: returns a list of tasks.
*/

public static class JetTaskFactory
{
    public static IReadOnlyList<IPerTickTask> CreatePerTickTasks(ILogger log, bool enforceBudgets)
    {
        var tasks = new List<IPerTickTask>
        {
            // Must run first so the rest of the tasks can decide whether to print logs this tick.
            new RateDividerTask(everyNthTick: 1000),
            
            // Pre-flight / BIT
            new BuiltInTestSummaryTask(log),
            new FlightControlSurfaceBitTask(log),
            new EngineAndFuelMonitoringTask(log),
            new NavigationAvionicsBitTask(log),
            new StructuralSensorsBitTask(log),

            // Pre-shot
            new WeaponReadinessTask(log),
        };

        // If Debug logging is enabled, do NOT enforce budgets (logging overhead can break microsecond budgets).
        if (!enforceBudgets || log.IsEnabled(LogEventLevel.Debug))
            return tasks;

        // OCP via decorator: add budget enforcement without changing task implementations.
        var wrapped = new List<IPerTickTask>(tasks.Count);
        foreach (var t in tasks)
            wrapped.Add(new BudgetEnforcingTask(t, log));

        return wrapped;
    }
}

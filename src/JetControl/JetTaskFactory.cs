using System.Collections.Generic;
using Serilog;

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
            // Pre-flight / BIT
            new BuiltInTestSummaryTask(log),
            new FlightControlSurfaceBitTask(log),
            new EngineAndFuelMonitoringTask(log),
            new NavigationAvionicsBitTask(log),
            new StructuralSensorsBitTask(log),

            // Pre-shot
            new WeaponReadinessTask(log),
        };

        if (!enforceBudgets)
            return tasks;

        // OCP via decorator: add budget enforcement without changing task implementations.
        var wrapped = new List<IPerTickTask>(tasks.Count);
        foreach (var t in tasks)
            wrapped.Add(new BudgetEnforcingTask(t, log));

        return wrapped;
    }
}

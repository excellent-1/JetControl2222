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
        var tasks = JetTaskFactory.CreatePerTickTasks(log, enforceBudgets: false);

        var period = FlightControlLoop.Period;

        foreach (var t in tasks)
            Assert.True(t.Budget <= period, $"{t.Name} budget {t.Budget} exceeds tick period {period}");

        var total = tasks.Aggregate(TimeSpan.Zero, (acc, t) => acc + t.Budget);
        Assert.True(total <= period, $"Sum of budgets {total} exceeds tick period {period}");
    }
}

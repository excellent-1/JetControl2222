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
        var log = /* new LoggerConfiguration().CreateLogger();
        Log.Logger */ new LoggerConfiguration()
            .MinimumLevel.Warning()
            .WriteTo.Console()
            .CreateLogger();
        var wrapped = new BudgetEnforcingTask(new SlowTask(), log);

        var state = new JetState();
        var commands = new JetCommands();

        Assert.Throws<TimeoutException>(() => wrapped.Execute(ref state, ref commands));
    }
}

using System;

namespace JetControl;

/// <summary>
/// Per-tick task that sets a flag indicating whether this tick should produce human-visible logs.
/// Business rule: keep the high-rate loop free of heavy I/O (console logging).
/// </summary>
public sealed class RateDividerTask : IPerTickTask
{
    private readonly int _everyNthTick;
    private int _tick;

/// I want the BIT/Weapon logs to appear during the short 20-tick demo run, so I will either: 
/// increase the runner loop iterations to > 1000, or temporarily set everyNthTick: 10 
/// in TaskFactory while demoing.
    public RateDividerTask(int everyNthTick = 10) // 1000)
    {
        if (everyNthTick <= 0) throw new ArgumentOutOfRangeException(nameof(everyNthTick));
        _everyNthTick = everyNthTick;
    }

    public string Name => $"Rate Divider (Log every {_everyNthTick} ticks)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(5);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        _tick++;
        commands.IsLogTick = (_tick % _everyNthTick) == 0;
    }
}
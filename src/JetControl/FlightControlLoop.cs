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

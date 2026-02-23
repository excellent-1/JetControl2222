using System;

namespace JetControl;

/*
OOP + SOLID mapping:
- Abstraction: interfaces define contracts (what) without implementation (how).
- DIP: high-level loop depends on abstractions rather than concrete task classes.
- ISP: small, focused interfaces (tick source vs per-tick task).
*/

public interface IHighRateTickSource
{
    event Action Tick;
}

public interface IPerTickTask
{
    string Name { get; }

    // Business rule: at 2222 Hz, tick period is ~450 microseconds.
    TimeSpan Budget { get; }

    void Execute(ref JetState state, ref JetCommands commands);
}

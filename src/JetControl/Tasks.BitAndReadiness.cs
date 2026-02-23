using System;
using Serilog;

namespace JetControl;

/*
Requested task list (safe illustrative model):

Pre-Flight (Airworthiness & Systems)
- Built-In Tests (BIT): hydraulic pressure, engine health, fuel, GPS/INS quality
- Flight Control System (FCS): surface command sanity checks
- Engine & Fuel monitoring
- Navigation & Avionics checks
- Structural/sensor checks (placeholder)

Pre-Shot (Weapon Readiness & Targeting)
- Master Arm switch
- Station selected
- Weapon power & communication (missile seeker)
- Firing envelope
- Clearance/safety (weapon bay doors open)

Note: Real systems often run these at different rates; here all tasks run per tick to demonstrate SOLID/OOP design.
*/

public sealed class BuiltInTestSummaryTask : IPerTickTask
{
    private readonly ILogger _log;

    // Encapsulation: thresholds are private implementation details.
    private const double MinHydraulic = 1.0;
    private const double MinEngineHealth = 0.5;
    private const double MinFuelKg = 100.0;
    private const double MinGpsQuality = 0.6;
    private const double MinInsQuality = 0.6;

    public BuiltInTestSummaryTask(ILogger log) => _log = log;

    public string Name => "BIT Summary (LRU Health)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(60);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // SRP: evaluates BIT status only.
        var ok =
            state.HydraulicPressure >= MinHydraulic &&
            state.EngineHealthIndex >= MinEngineHealth &&
            state.FuelRemainingKg >= MinFuelKg &&
            state.GpsLockQuality >= MinGpsQuality &&
            state.InsAlignmentQuality >= MinInsQuality;

        commands.BitOk = ok;

        _log.Information("BIT={BitOk}", ok);
    }
}

public sealed class FlightControlSurfaceBitTask : IPerTickTask
{
    private readonly ILogger _log;
    public FlightControlSurfaceBitTask(ILogger log) => _log = log;

    public string Name => "FCS Surface Check";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(50);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // Business rule: keep commands in normalized safe bounds [-1..1].
        commands.Aileron  = Clamp(commands.Aileron,  -1, 1);
        commands.Elevator = Clamp(commands.Elevator, -1, 1);
        commands.Rudder   = Clamp(commands.Rudder,   -1, 1);

        _log.Debug("FCS normalized.");
    }

    private static double Clamp(double v, double min, double max)
        => v < min ? min : (v > max ? max : v);
}

public sealed class EngineAndFuelMonitoringTask : IPerTickTask
{
    private readonly ILogger _log;
    public EngineAndFuelMonitoringTask(ILogger log) => _log = log;

    public string Name => "Engine & Fuel Monitoring";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(40);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // Illustrative gating: degraded engine health caps throttle.
        if (state.EngineHealthIndex < 0.6)
            commands.Throttle = Math.Min(commands.Throttle, 0.7);

        // Illustrative: low fuel => airworthiness issue => BIT false.
        if (state.FuelRemainingKg < 80)
            commands.BitOk = false;

        _log.Debug("Engine/Fuel checked.");
    }
}

public sealed class NavigationAvionicsBitTask : IPerTickTask
{
    private readonly ILogger _log;
    public NavigationAvionicsBitTask(ILogger log) => _log = log;

    public string Name => "Navigation & Avionics (GPS/INS)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(40);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // Business rule: if GPS or INS quality is low, BIT is false.
        if (state.GpsLockQuality < 0.6 || state.InsAlignmentQuality < 0.6)
            commands.BitOk = false;

        _log.Debug("Nav checked.");
    }
}

public sealed class StructuralSensorsBitTask : IPerTickTask
{
    private readonly ILogger _log;
    public StructuralSensorsBitTask(ILogger log) => _log = log;

    public string Name => "Structural/Sensors BIT (Placeholder)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(30);

    public void Execute(ref JetState state, ref JetCommands commands)
        => _log.Debug("Structural/sensors checked.");
}

public sealed class WeaponReadinessTask : IPerTickTask
{
    private readonly ILogger _log;
    public WeaponReadinessTask(ILogger log) => _log = log;

    public string Name => "Weapon Readiness (Pre-Shot)";
    public TimeSpan Budget => TimeSpan.FromMicroseconds(60);

    public void Execute(ref JetState state, ref JetCommands commands)
    {
        // Business rule: weapon ready only if all gating checks pass.
        var ready =
            state.MasterArmOn &&
            state.SelectedStation > 0 &&
            state.WeaponPowered &&
            state.SeekerCommunicating &&
            state.TargetInEnvelope &&
            state.WeaponBayDoorsOpen;

        commands.WeaponReady = ready;

        _log.Information("WeaponReady={Ready}", ready);
    }
}

# ===== Block 2/7 =====
$ErrorActionPreference = "Stop"

WriteFile "src/JetControl/Abstractions.cs" @'
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
'@

WriteFile "src/JetControl/Models.cs" @'
namespace JetControl;

/*
Data passed through the system each tick.

Encapsulation:
- Tasks can keep private internal state, but the loop only interacts via Execute().
*/

public struct JetState
{
    // Airworthiness / systems (illustrative placeholders; not real aircraft limits)
    public double HydraulicPressure;
    public double EngineHealthIndex;
    public double FuelRemainingKg;
    public double GpsLockQuality;
    public double InsAlignmentQuality;

    // Flight dynamics placeholders
    public double Pitch, Roll, Yaw;
    public double P, Q, R;

    // Weapon readiness placeholders
    public bool MasterArmOn;
    public int SelectedStation;
    public bool WeaponPowered;
    public bool SeekerCommunicating;
    public bool TargetInEnvelope;
    public bool WeaponBayDoorsOpen;
}

public struct JetCommands
{
    // Actuator commands (placeholders)
    public double Aileron, Elevator, Rudder, Throttle;

    // Summary flags
    public bool BitOk;
    public bool WeaponReady;
}
'@

Write-Host "Block 2 complete."
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

using System.Threading;
using JetControl;
using Serilog;

/*
Runner demonstrates wiring + logging.
This is NOT a real interrupt at 2222 Hz; it's a readable demo loop.
*/

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console()
    .CreateLogger();

var log = Log.Logger;

log.Information("Starting demo at {Rate} Hz (Period ~ {Period} us)",
    FlightControlLoop.RateHz, FlightControlLoop.Period.TotalMicroseconds);

var tasks = JetControl.JetTaskFactory.CreatePerTickTasks(log, enforceBudgets: true);
var loop = new FlightControlLoop(tasks);

var state = new JetState
{
    HydraulicPressure = 1.2,
    EngineHealthIndex = 0.9,
    FuelRemainingKg = 500,
    GpsLockQuality = 0.9,
    InsAlignmentQuality = 0.9,

    MasterArmOn = true,
    SelectedStation = 1,
    WeaponPowered = true,
    SeekerCommunicating = true,
    TargetInEnvelope = true,
    WeaponBayDoorsOpen = true
};

var commands = new JetCommands { Aileron = 0.1, Elevator = -0.1, Throttle = 0.8 };

for (int i = 0; i < 20; i++)
{
    loop.OnTick(ref state, ref commands);

    // Simulated fuel burn
    state.FuelRemainingKg -= 0.5;

    Thread.Sleep(50);
}

log.Information("Done.");

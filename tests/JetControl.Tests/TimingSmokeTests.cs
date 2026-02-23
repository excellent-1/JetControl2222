using System;
using System.Diagnostics;
using JetControl;
using Serilog;
using Xunit;

/*
Timing smoke test (opt-in):
- Desktop/CI timing is noisy; enable explicitly via RUN_TIMING_TESTS=true
- Checks each task's elapsed time <= tick period (~450 µs).
*/

public class TimingSmokeTests
{
    [Fact]
    public void PerTask_Elapsed_ShouldBeUnder_2222Hz_Period_WhenEnabled()
    {
        if (!string.Equals(Environment.GetEnvironmentVariable("RUN_TIMING_TESTS"), "true", StringComparison.OrdinalIgnoreCase))
            return;

        var log = new LoggerConfiguration().CreateLogger();
        var tasks = JetTaskFactory.CreatePerTickTasks(log, enforceBudgets: false);
        var period = FlightControlLoop.Period;

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

        // Warm-up to reduce JIT impact
        for (int i = 0; i < 2000; i++)
            foreach (var t in tasks) t.Execute(ref state, ref commands);

        foreach (var t in tasks)
        {
            var sw = Stopwatch.StartNew();
            t.Execute(ref state, ref commands);
            sw.Stop();

            Assert.True(sw.Elapsed <= period,
                $"{t.Name} took {sw.Elapsed.TotalMicroseconds:F1}us > period {period.TotalMicroseconds:F1}us");
        }
    }
}

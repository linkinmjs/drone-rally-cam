## Signals between systems that have no natural owner in common. Anything with a clear owner
## (a drone arming, an interactable being used) is connected directly instead.
extends Node


@warning_ignore_start("unused_signal")

# Player and drone handling
signal control_state_changed(state: int)
signal drone_deployed(drone: Drone)
signal drone_recovered(drone: Drone)
signal drone_crashed(drone: Drone, speed: float)
signal flight_mode_changed(flight_mode: FlightMode)

# Battery
signal battery_changed(fraction: float, seconds_left: float)
signal battery_low
signal battery_depleted

# Filming
signal recording_started
signal recording_stopped(report: ShotReport)
signal recording_aborted(reason: String)
signal shot_score_updated(score: float)

# Rally cars
signal car_started(car: Node3D)
signal car_finished(car: Node3D)

@warning_ignore_restore("unused_signal")

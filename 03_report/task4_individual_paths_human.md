# Task 4.2 Individual Vessel Paths Summary

## MMSI 2579999

MMSI 2579999 should be treated with caution. Online vessel-tracking sources list it as a navigation aid or base station rather than a normal ship, and an AIS base-station manual mentions 2579999 as a default MMSI that should be changed after setup. The generated map shows geographically inconsistent positions and implausible jumps across continents. Therefore, repeated positions for this identifier likely reflect a station, navigation aid, default configuration, or test/setup artefact instead of a single moving vessel.

## MMSI 563040400

The AIS observations of MMSI 563040400 form a coherent and geographically plausible vessel track near the port area of Constanța in the Black Sea. The vessel follows a connected route with denser observations and lower speeds near the harbour area, suggesting manoeuvring or waiting behaviour. Movement further offshore appears more continuous and faster, which is consistent with normal vessel navigation.

## MMSI 211430830 and ship-lock detection

In AIS data, a ship lock typically appears as a local cluster of observations at nearly the same coordinates with very low speed. The vessel may spend several minutes or longer in the same area while waiting, entering, being raised or lowered, and leaving the lock. Compared with normal cruising segments, the observation density per location is higher and the trajectory shows a pause or bottleneck-like compression around the lock position.

### Detection thresholds

- Speed threshold: below 1 knot. This marks points where the vessel is effectively stationary or manoeuvring very slowly.
- Maximum time gap inside one event: 30 minutes. Longer gaps are separated because they may represent missing data or different waiting phases.
- Maximum spatial step inside one event: 600 metres. This keeps one lock event spatially compact while allowing AIS/GPS noise and movement through the lock chamber.
- Minimum duration: 8 minutes and at least 3 observations. This removes short noise bursts that are unlikely to represent a complete lock passage.

### Ordered detection logic

1. Sort all AIS observations by msg_timestamp.
2. Mark an observation as a potential lock point if speed is below 1 knot.
3. Start a new lock group if the previous low-speed point is more than 30 minutes away or more than 600 metres away.
4. Summarise each consecutive low-speed group by start time, end time, duration, mean latitude/longitude and number of observations.
5. Keep only groups with at least 3 observations and at least 8 minutes duration.
6. Interpret the remaining groups as potential ship-lock passages.

### Limitations and improvement ideas

The rule-based detector is transparent but imperfect. It may confuse anchoring, waiting, congestion, port stops or missing GPS movement with lock passages. It may miss locks if AIS messages are sparse, if the vessel moves slowly for less than the minimum duration, or if position noise spreads points beyond the distance threshold. Improvements could use known lock coordinates, river network constraints, heading changes, acceleration/deceleration patterns, or clustering methods such as DBSCAN on latitude, longitude, speed and time.

### Optional unsupervised idea

An unsupervised alternative could cluster low-speed AIS points in space and time without labelled training data. For example, DBSCAN or HDBSCAN could identify dense clusters of stationary points, and clusters located along the route with plausible duration could be interpreted as candidate lock events.

## Outputs

- `01_data/task4_mmsi_2579999.csv`
- `01_data/task4_mmsi_563040400.csv`
- `01_data/task4_mmsi_211430830.csv`
- `01_data/task4_detected_lock_events_211430830.csv`
- `03_report/graphs/task4_mmsi_2579999.html`
- `03_report/graphs/task4_mmsi_563040400.html`
- `03_report/graphs/task4_mmsi_211430830_locks.html`

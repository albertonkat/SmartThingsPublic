---
tags: [resource, zwave, protocol]
---

# Z-Wave Protocol

## Overview
Z-Wave is a low-power mesh network protocol operating at 908.42 MHz (US). Used for home automation and healthcare IoT sensors.

## Key Concepts

### Fingerprints
```groovy
fingerprint mfr: "0086", prod: "0103", model: "0060", deviceJoinName: "Device Name"
// mfr = manufacturer ID (hex), prod = product type, model = product ID
```

### Command Classes
- `COMMAND_CLASS_BASIC` (0x20) — basic on/off
- `COMMAND_CLASS_SWITCH_BINARY` (0x25) — binary switches
- `COMMAND_CLASS_SENSOR_MULTILEVEL` (0x31) — temp, humidity, lux
- `COMMAND_CLASS_BATTERY` (0x80) — battery level
- `COMMAND_CLASS_CONFIGURATION` (0x70) — device config params
- `COMMAND_CLASS_WAKE_UP` (0x84) — battery device wake-up
- `COMMAND_CLASS_SECURITY` (0x98) — S0 secure inclusion

### Secure Inclusion (S0)
```groovy
private secure(physicalgraph.zwave.Command cmd) {
    zwave.securityV1.securityMessageEncapsulation().encapsulate(cmd).format()
}
```

### Common zwaveEvent Patterns
```groovy
def zwaveEvent(physicalgraph.zwave.commands.batteryv1.BatteryReport cmd) {
    def level = cmd.batteryLevel == 255 ? 1 : cmd.batteryLevel
    createEvent(name: "battery", value: level, unit: "%")
}
```

## Healthcare Relevance
Z-Wave is used in fall detectors, motion sensors, and door/window sensors relevant to ambient assisted living.

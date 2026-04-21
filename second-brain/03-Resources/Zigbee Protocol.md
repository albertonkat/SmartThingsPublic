---
tags: [resource, zigbee, protocol]
---

# Zigbee Protocol

## Overview
Zigbee is a low-power mesh protocol based on IEEE 802.15.4, operating at 2.4 GHz. Used for sensors, switches, and healthcare devices.

## Key Concepts

### Fingerprints
```groovy
fingerprint profileId: "0104", inClusters: "0000,0001,0003,0402",
            manufacturer: "ACME", model: "TH01", deviceJoinName: "ACME Sensor"
// profileId 0104 = Home Automation profile
```

### Common Cluster IDs
| Cluster | ID | Purpose |
|---|---|---|
| Basic | 0x0000 | Device info |
| Power Config | 0x0001 | Battery |
| On/Off | 0x0006 | Switch control |
| Level Control | 0x0008 | Dimming |
| Temperature | 0x0402 | Temperature measurement |
| Humidity | 0x0405 | Relative humidity |
| IAS Zone | 0x0500 | Security/alarm sensors |

### Helper Methods
```groovy
import physicalgraph.zigbee.zcl.DataType

def refresh() {
    zigbee.readAttribute(0x0402, 0x0000) +  // temperature
    zigbee.readAttribute(0x0001, 0x0020)     // battery
}

def configure() {
    zigbee.configureReporting(0x0402, 0x0000, DataType.INT16, 30, 3600, 50)
}
```

## Healthcare Relevance
Zigbee is common in medical-grade sensors: pulse oximeters, thermometers, and environmental monitors.

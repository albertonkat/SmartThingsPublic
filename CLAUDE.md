# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the official SmartThings Public GitHub repository containing SmartApps and Device Type Handlers written in the SmartThings Groovy DSL. SmartApps define automation logic (e.g. "turn off lights when I leave"), while Device Type Handlers define how physical devices (Z-Wave, Zigbee) communicate with the SmartThings hub.

## Build Commands

The build requires Artifactory credentials passed as project properties:

```bash
# Resolve dependencies
./gradlew dependencies -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"

# Compile SmartApps only
./gradlew compileSmartappsGroovy -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"

# Compile Device Types only
./gradlew compileDevicetypesGroovy -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"

# Compile both
./gradlew compileSmartappsGroovy compileDevicetypesGroovy -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"
```

**There are no automated tests** — CI explicitly echoes `"We don't have any tests :-("`. Validation is done entirely through compilation and manual testing in the SmartThings IDE at `ide.smartthings.com`.

## Repository Structure

```
smartapps/
└── <namespace>/
    └── <app-name>.src/
        ├── <app-name>.groovy
        └── i18n/              # Optional: localization strings

devicetypes/
├── <namespace>/
│   └── <device-name>.src/
│       └── <device-name>.groovy
└── capabilities/              # Capability reference implementations
    └── <capability-name>.src/
        └── <capability-name>.groovy
```

Namespaces are typically `smartthings` for official code, a vendor name (e.g. `fibargroup`, `leaksmart`), or a community author handle.

## Groovy DSL Conventions

### SmartApp structure

```groovy
/**
 *  Copyright 20XX SmartThings
 *  Licensed under the Apache License, Version 2.0
 */
definition(
    name: "App Name",
    namespace: "smartthings",
    author: "SmartThings",
    description: "...",
    category: "Convenience",
    iconUrl: "https://s3.amazonaws.com/smartapp-icons/...",
    iconX2Url: "https://s3.amazonaws.com/smartapp-icons/...@2x.png"
)

preferences {
    section("Section Title") {
        input "switches", "capability.switch", multiple: true
    }
}

def installed() {
    subscribe(app, appTouch)
}

def updated() {
    unsubscribe()
    subscribe(app, appTouch)
}
```

### Device Type Handler structure

```groovy
metadata {
    definition(
        name: "Device Name",
        namespace: "smartthings",
        author: "SmartThings",
        ocfDeviceType: "oic.d.switch",
        runLocally: true,
        minHubCoreVersion: '000.017.0012'
    ) {
        capability "Switch"
        command "customCommand"
        fingerprint mfr: "0086", prod: "0003", model: "0012"
    }

    tiles(scale: 2) { /* ... */ }
}

def installed() { /* ... */ }
def updated() { /* ... */ }
def parse(String description) { /* decode incoming device messages */ }
```

### Key conventions

- Every file begins with the Apache 2.0 license header
- `updated()` always calls `unsubscribe()` before re-subscribing to avoid duplicate subscriptions
- Device Type Handlers for Z-Wave use the `zwave.*` builder API; Zigbee handlers use `zigbee.*` helpers
- `fingerprint` declarations in Device Types match hardware identifiers to associate the handler with physical devices
- The `capabilities/` directory under `devicetypes/` contains reference implementations of standard SmartThings capabilities (switch, lock, thermostat, etc.) — these are the canonical patterns to follow when implementing a capability in a new device handler

## Deployment Pipeline

CI runs on CircleCI (Java 8). The deployment branches map to environments:

| Branch | Environment | S3 Bucket Var |
|--------|-------------|---------------|
| `master` | Dev | `$S3_BUCKETS_DEV` |
| `staging` | Staging | `$S3_BUCKETS_STAGE` |
| `production` | Production | `$S3_BUCKETS_PROD` |

Deployment uses `./gradlew deployArchives` and notifies a Slack channel via `./gradlew slackSendMessage`.

# CLAUDE.md — SmartThingsPublic Codebase Guide

This file provides context for AI assistants working in this repository.

## Repository Overview

SmartThingsPublic is the official open-source repository of SmartThings **Device Handlers** (Device Types) and **SmartApps** written in Groovy. It contains 417 Groovy source files (~98,000 lines) organized by two top-level source categories and supports 26+ locales via `.properties` files.

## Directory Structure

```
SmartThingsPublic/
├── CLAUDE.md               # This file
├── README.md               # Project overview and links
├── build.gradle            # Gradle build config (Groovy plugin + SmartThings plugins)
├── settings.gradle         # Root project name
├── circle.yml              # CircleCI CI/CD configuration
├── gradlew / gradlew.bat   # Gradle wrapper scripts
├── gradle/                 # Gradle wrapper binaries
├── devicetypes/            # Device Handlers (233 Groovy files)
│   ├── capabilities/       # Reusable capability definitions (16 subdirs)
│   ├── smartthings/        # Official SmartThings device handlers (154 subdirs)
│   ├── fibargroup/         # Third-party: Fibaro devices
│   ├── erocm123/           # Third-party: Community devices
│   └── <vendor>/           # Other third-party vendors
└── smartapps/              # SmartApps / Automations (184 Groovy files)
    ├── smartthings/        # Official SmartThings apps (107 subdirs)
    ├── imbrianj/           # Third-party: Community apps
    ├── dianoga/            # Third-party: Community apps
    └── <author>/           # Other third-party authors
```

### File/Directory Naming Convention

Every device handler or smartapp lives in a directory named `{name}.src/` containing a single Groovy file of the same base name:

```
devicetypes/smartthings/aeon-key-fob.src/aeon-key-fob.groovy
smartapps/smartthings/big-turn-on.src/big-turn-on.groovy
```

- **Directory and file names**: kebab-case
- **Namespace**: matches the parent vendor/author directory (e.g., `"smartthings"`, `"fibargroup"`)
- **i18n**: Localization files live alongside the `.groovy` file as `{name}_{locale}.properties`

## Code Conventions

### Device Handler Structure

Every device handler is a single Groovy file with this structure:

```groovy
/**
 *  Copyright {year} SmartThings
 *  Apache License 2.0 header
 */
import groovy.json.JsonOutput  // if needed

metadata {
    definition (name: "Device Name", namespace: "vendor", author: "Author",
                runLocally: true, minHubCoreVersion: '000.017.0012',
                executeCommandsLocally: false) {
        capability "Actuator"
        capability "Switch"
        // ... other capabilities

        fingerprint mfr: "0086", prod: "0101", model: "0058", deviceJoinName: "Device Name"
        fingerprint deviceId: "0x0101", inClusters: "0x86,0x72"
    }

    simulator {
        // Test input/output definitions for the IDE simulator
        status "on": "command: 2003, payload: FF"
    }

    tiles {
        // UI tile definitions for the SmartThings mobile app
        standardTile("switch", "device.switch", width: 2, height: 2, canChangeIcon: true) {
            state "on",  label: '${name}', action: "switch.off", icon: "st.switches.switch.on"
            state "off", label: '${name}', action: "switch.on",  icon: "st.switches.switch.off"
        }
        main "switch"
        details(["switch"])
    }
}

// Event parsing
def parse(String description) { ... }

// Z-Wave event handlers
def zwaveEvent(physicalgraph.zwave.commands.XxxCmd cmd) { ... }

// ZigBee event handlers
def zigbeeEvent(Map event) { ... }

// Capability command implementations
def on() { ... }
def off() { ... }
```

### SmartApp Structure

```groovy
/**
 *  Copyright header (Apache 2.0)
 */
definition(
    name: "App Name",
    namespace: "smartthings",
    author: "SmartThings",
    description: "Description of what the app does.",
    category: "Convenience",
    iconUrl:   "https://s3.amazonaws.com/smartapp-icons/...",
    iconX2Url: "https://s3.amazonaws.com/smartapp-icons/...@2x.png"
)

preferences {
    section("Section Label") {
        input "switches", "capability.switch", multiple: true
    }
}

// Required lifecycle methods
def installed() {
    // subscribe to events, initialize state
}

def updated() {
    unsubscribe()
    // re-subscribe after settings change
}

// Event handler methods
def someEventHandler(evt) {
    log.debug "someEventHandler: $evt"
}
```

### Key Patterns

- **Tabs for indentation** (not spaces) inside `metadata {}` blocks; spaces used in `definition()` calls
- **`log.debug`** used liberally for debugging; often commented out in production (`// log.debug(...)`)
- **Null-safe operator** (`?.`) used throughout: `switches?.on()`
- **Event subscriptions**: `subscribe(device, "attribute", handlerMethod)`
- **State management**: `state.someKey = value` for persistent app state
- **Device commands**: Always return a list of Z-Wave/ZigBee commands or events
- **`createEvent()`**: Used to create SmartThings events from parsed data
- **`response()`**: Wraps command strings for Z-Wave/ZigBee responses

### Capabilities Reference

Common SmartThings capabilities used in this repo:

| Capability | Description |
|---|---|
| `Actuator` | Device that can be controlled |
| `Sensor` | Device that reports state |
| `Switch` | On/off control |
| `Button` | Push button |
| `Lock` | Door lock |
| `Thermostat` | Temperature control |
| `Battery` | Battery level reporting |
| `Health Check` | Device connectivity monitoring |
| `Configuration` | Device configuration commands |
| `Refresh` | Manual state refresh |

## Build System

**Gradle** with custom SmartThings plugins. Requires Artifactory credentials.

### Build Commands

```bash
# Download dependencies
./gradlew dependencies \
  -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" \
  -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"

# Compile both source sets
./gradlew compileSmartappsGroovy compileDevicetypesGroovy \
  -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" \
  -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"

# Deploy archives (CI only)
./gradlew deployArchives -Ps3Buckets="$S3_BUCKETS_DEV" ...
```

### Source Sets

- **`devicetypes`**: Groovy 2.4.7 + Z-Wave (`appengine-z-wave:0.1.3`) + ZigBee (`appengine-zigbee:0.1.12`) libraries
- **`smartapps`**: Groovy 2.4.7 + `appengine-common:0.1.9` + HTTP-builder + Grails web + JSON

### Dependencies

- **Private**: SmartThings Artifactory at `smartthings.jfrog.io` (requires credentials)
- **Public**: `jcenter()`, `mavenLocal()`

## CI/CD (CircleCI)

Configuration: `circle.yml`

| Branch | Environment | S3 Bucket Variable |
|--------|-------------|-------------------|
| `master` | Dev | `$S3_BUCKETS_DEV` |
| `staging` | Staging | `$S3_BUCKETS_STAGE` |
| `production` | Production | (manual deploy) |

**There are no automated tests.** The test stage in `circle.yml` explicitly echoes `"We don't have any tests :-("`.

Post-deployment Slack notifications are sent via `./gradlew slackSendMessage`.

## Required Environment Variables

For local builds/CI:

| Variable | Purpose |
|---|---|
| `ARTIFACTORY_USERNAME` | SmartThings Artifactory access |
| `ARTIFACTORY_PASSWORD` | SmartThings Artifactory access |
| `S3_BUCKETS_DEV` | Dev deployment target |
| `S3_BUCKETS_STAGE` | Staging deployment target |
| `SLACK_TOKEN` | Slack API token for notifications |
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications |
| `SLACK_CHANNEL` | Slack channel for notifications |

## Adding New Device Handlers or SmartApps

1. **Create directory**: `devicetypes/{vendor}/{device-name}.src/` or `smartapps/{author}/{app-name}.src/`
2. **Create Groovy file**: Same name as directory without `.src` suffix
3. **Add Apache 2.0 license header** at the top of the file
4. **Follow the structural template** for device handlers or smartapps (see above)
5. **(Optional) Add i18n**: Create `{name}_{locale}.properties` files alongside the Groovy file
6. **(Optional) Add README**: Create `README.md` inside the `.src/` directory

### Namespace Conventions

- Official SmartThings code: `namespace: "smartthings"`
- Third-party: use the parent directory name (e.g., `"fibargroup"`, `"erocm123"`)
- Some apps use dotted namespaces: `"smartthings/tile-ux"`

## Localization

Properties files follow Java ResourceBundle conventions:

```
{device-name}.properties          # Default (English)
{device-name}_de.properties       # German
{device-name}_es.properties       # Spanish
{device-name}_ko.properties       # Korean
```

26+ languages are supported across the repository.

## Key Files for Reference

When understanding or modifying code, these are good reference files:

- **Simple SmartApp**: `smartapps/smartthings/big-turn-on.src/big-turn-on.groovy`
- **Z-Wave device handler**: `devicetypes/smartthings/aeon-key-fob.src/aeon-key-fob.groovy`
- **Build config**: `build.gradle`
- **CI config**: `circle.yml`

## What AI Assistants Should Know

1. **No test suite** — changes cannot be verified by running tests locally. Validate by reviewing code logic and ensuring the Groovy compiles.
2. **Groovy 2.4.7** — use language features compatible with this version (no newer Groovy syntax).
3. **Platform APIs** — SmartThings-specific APIs (`zwave.*`, `zigbee.*`, `createEvent()`, `subscribe()`, `state`, `device`, `location`) are provided by the platform runtime, not importable libraries. Do not add import statements for these.
4. **Single-file modules** — each device or app is entirely self-contained in one `.groovy` file. No multi-file splitting.
5. **No dependency management per file** — dependencies are declared globally in `build.gradle`, not per-file.
6. **`physicalgraph.*` namespace** — Z-Wave command classes use the `physicalgraph.zwave.commands.*` package.
7. **Build requires private Artifactory** — the build cannot run without SmartThings internal credentials. Compilation verification requires CI or internal access.

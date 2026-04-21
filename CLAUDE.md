# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This project uses Gradle with a wrapper. Credentials for the private SmartThings Artifactory repo are required for most tasks.

```bash
# Compile all device types
./gradlew compileDevicetypesGroovy -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"

# Compile all SmartApps
./gradlew compileSmartappsGroovy -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"

# Compile both
./gradlew compileSmartappsGroovy compileDevicetypesGroovy -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"

# Resolve dependencies
./gradlew dependencies -PsmartThingsArtifactoryUserName="$ARTIFACTORY_USERNAME" -PsmartThingsArtifactoryPassword="$ARTIFACTORY_PASSWORD"
```

There are no automated tests — `circle.yml` confirms this explicitly. Validation is compilation-only.

## Architecture Overview

### Repository Layout

Each component lives in its own `.src` subdirectory under a namespace (typically the author's handle or company name):

```
devicetypes/<namespace>/<device-name>.src/<device-name>.groovy
smartapps/<namespace>/<app-name>.src/<app-name>.groovy
```

The `devicetypes/capabilities/` namespace contains generic capability-only reference implementations (switch, lock, motion sensor, etc.).

### Device Type Handlers

Device handlers bridge physical hardware to the SmartThings platform. Every handler has the same top-level structure:

1. **`metadata {}`** block — declares capabilities, attributes, fingerprints, UI tiles, and simulator stubs
2. **`installed()` / `updated()`** — lifecycle callbacks; `updated()` typically calls `unsubscribe()` then re-subscribes
3. **`parse(String description)`** — entry point for all inbound messages; dispatches to protocol-specific event handlers
4. **`zwaveEvent(...)` / Zigbee handlers** — overloaded methods, one per Z-Wave command class or Zigbee cluster
5. **Command methods** — outbound commands (`lock()`, `refresh()`, `configure()`, etc.)

**Z-Wave handlers** use `physicalgraph.zwave.Zwave()` and import specific command classes from `physicalgraph.zwave.commands.*`. Secure inclusion wraps commands in `SecurityMessageEncapsulation`.

**Zigbee handlers** import `physicalgraph.zigbee.zcl.DataType` and use the `zigbee.*` helper (e.g. `zigbee.readAttribute(...)`, `zigbee.command(...)`).

**Fingerprints** in `metadata.definition` determine which handler claims a newly paired device. Z-Wave fingerprints use `mfr`/`prod`/`model` or `deviceId`/`inClusters`. Zigbee fingerprints use `profileId`/`inClusters`/`outClusters`/`manufacturer`/`model`.

**Local execution** is opt-in: `runLocally: true` and `executeCommandsLocally: true` in the definition block, plus `minHubCoreVersion` specifying the minimum hub firmware required.

### SmartApps

SmartApps are event-driven automations. Their structure:

1. **`definition()`** — app metadata (name, namespace, description, category, icon URLs)
2. **`preferences {}`** — declarative UI sections with `input` directives for device/capability selection
3. **`installed()` / `updated()`** — `updated()` always calls `unsubscribe()` then re-subscribes
4. **`subscribe(device, attribute, handler)`** — registers event listeners
5. **Handler methods** — respond to subscribed events

SmartApps do not have a `parse()` method. They interact with devices through capability methods (e.g. `device.on()`, `device.setLevel(50)`) and platform APIs (`sendNotification`, `runIn`, `location.mode`).

### Dependencies

- **`smartthings:appengine-z-wave:0.1.3`** — Z-Wave command classes and helpers
- **`smartthings:appengine-zigbee:0.1.12`** — Zigbee cluster helpers
- **`smartthings:appengine-common:0.1.9`** — Shared platform APIs for SmartApps
- Groovy 2.4.7, Java 8

### Deployment Pipeline

CI runs on CircleCI. Merging to `master` deploys to dev, `staging` deploys to staging. Production deployments use a separate `production` branch. Each deployment packages archives and sends a Slack notification via the `smartthings-slack` Gradle plugin.

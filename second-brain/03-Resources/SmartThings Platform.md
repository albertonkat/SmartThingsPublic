---
tags: [resource, smartthings, platform]
---

# SmartThings Platform

## Key APIs

### Device Handler
| Method | Purpose |
|---|---|
| `sendEvent(name:, value:)` | Update device state |
| `createEvent(name:, value:)` | Create event map (return from parse) |
| `device.currentValue("attr")` | Read current attribute value |
| `state.key = value` | Persist data across calls |

### SmartApp
| Method | Purpose |
|---|---|
| `subscribe(device, attr, handler)` | Listen to events |
| `unsubscribe()` | Clear all subscriptions |
| `runIn(secs, method)` | Schedule future execution |
| `sendNotification(msg)` | Push notification |
| `location.mode` | Current home mode |

## Capability Reference
Full list: http://docs.smartthings.com/en/latest/capabilities-reference.html

## Local Execution
Enabled with `runLocally: true` + `executeCommandsLocally: true` in `definition()`.  
Requires `minHubCoreVersion` and the handler to be whitelisted.

## Deployment Branches
| Branch | Environment |
|---|---|
| `master` | Dev |
| `staging` | Staging |
| `production` | Production |

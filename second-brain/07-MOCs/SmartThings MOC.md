---
tags: [moc, smartthings]
---

# SmartThings MOC

## Projects
- [[01-Projects/gclimb - Healthcare IoT Hub]]

## Resources
- [[03-Resources/SmartThings Platform]]
- [[03-Resources/Z-Wave Protocol]]
- [[03-Resources/Zigbee Protocol]]

## Device Handler Structure
```
metadata {}       → capabilities, fingerprints, tiles
installed()       → one-time setup
updated()         → unsubscribe() + re-subscribe
parse()           → dispatch inbound messages
zwaveEvent()      → overloaded per command class
Command methods   → lock(), refresh(), configure()
```

## SmartApp Structure
```
definition()      → app metadata
preferences {}    → input directives
installed()       → subscribe events
updated()         → unsubscribe + resubscribe
Handler methods   → respond to events
```

## Useful Links
- [SmartThings Docs](http://docs.smartthings.com)
- [IDE & Simulator](http://ide.smartthings.com)
- [Community Forums](http://community.smartthings.com)

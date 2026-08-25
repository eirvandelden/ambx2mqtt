---
created: 2026-08-25T09:55:06Z
branch: main
trigger: manual
restored: false
topic: ambx2mqtt-daemon
---

# Handoff: Design the `ambx2mqtt` Home Assistant daemon

## Goal

Prepare a design and implementation plan for a separate, developer-oriented `ambx2mqtt` application. It will run on the computer physically connected to Philips amBX USB sets and expose their lights to Home Assistant over MQTT.

This handoff was written in the `ambx` repository before this one existed, and moved here when it was created.

## Current State

- No `ambx2mqtt` repository, code, specification, or implementation plan exists yet.
- The intended runtime is the USB-attached host: currently the user's Mac. macOS LaunchDaemon support is sufficient for v1; Linux/systemd support should be included where cheap.
- The user already runs MQTT for Home Assistant through Zigbee2MQTT.
- The application cannot begin until `libambx` exposes individual USB sets and releases that capability.
- A local visual companion was attempted but its background server was reaped by the Codex execution environment. Continue text-only unless a live visual endpoint is verified first.

## Key Decisions

- The name is `ambx2mqtt`.
- The repository is separate from `libambx`; the application consumes the released driver gem.
- V1 installation is developer-oriented: source checkout/Bundler and service installation. Homebrew and other distributable packages are deferred.
- Use MQTT device discovery: one Home Assistant device per physical USB set, with one retained discovery manifest containing five light components.
- Each set exposes exactly five separate RGB light entities: left, right, wallwasher left, wallwasher centre, and wallwasher right. Do not create daemon-owned group entities in v1; Home Assistant may group them.
- V1 supports RGB, brightness, on/off, and state restoration. `off` sends black and preserves the chosen color for the next `on`.
- V2 should add fan support quickly; rumbler and rotary wheels are later scope.
- Auto-discover all attached sets without mandatory configuration. Optional YAML maps stable USB identity to friendly names; MQTT credentials may live in that config file.
- Persist the last requested state. There is no confirmed hardware state-read protocol, so do not represent it as actual lamp state.
- On USB loss, Mac sleep, or MQTT loss, mark entities unavailable. Keep known disconnected sets and their entities for 48 hours.
- After 48 hours unseen, clear the retained MQTT discovery payload and delete stored state so Home Assistant removes the five entities.

## Modified Files

- `docs/handoffs/2026-08-25-ambx2mqtt-daemon.md` — this temporary daemon handoff.
- `docs/handoffs/2026-08-25-libambx-multi-device.md` — linked driver handoff.
- Pre-existing untracked files not created or modified by this work: `bin/`, `screenshot.png`.

## Failed Approaches

- A custom Home Assistant integration — rejected because a separate USB-host service would still be needed and MQTT Discovery already offers native device/entity presentation.
- One discovery payload per light — workable but creates more discovery and cleanup coordination than one device discovery manifest with five components.
- Immediate removal on disconnect — rejected in favor of a 48-hour unavailable grace period and stable entity recovery.

## Files to Read

- `docs/handoffs/2026-08-25-libambx-multi-device.md` — dependency, current driver evidence, and driver-plan work remaining.
- `libcombustd/communication/ambx.rb` — current driver limitation that blocks the daemon.
- Home Assistant MQTT documentation — device discovery, retained configs, availability, and removal behavior.

## Next Steps

1. Resume the brainstorming process by confirming the proposed identity/lifecycle design: serial first/port-path fallback, restore requested colors on reconnect, unavailable for 48 hours, then discovery/state cleanup.
2. Define and obtain approval for the daemon configuration schema, MQTT topic schema, command/state payloads, retained availability behavior, logging, and corrupt/missing-state recovery.
3. Define macOS LaunchDaemon and Linux/systemd installation/configuration conventions for the developer-oriented v1.
4. Define daemon tests: discovery manifest, command translation, state persistence, 48-hour expiration, reconnect behavior, MQTT reconnect, and a real USB/MQTT/Home Assistant smoke test.
5. Create the `ambx2mqtt` repository after the user authorizes it; move this handoff there.
6. After the `libambx` release dependency and approved daemon design exist, write/commit the daemon design specification, have the user review it, then create its implementation plan.

## Open Questions

- Does the identity/lifecycle section match the user's intent in full?
- What friendly names should the currently connected sets receive once identities are observed?
- What configuration path, state-file path, and service account should the macOS LaunchDaemon use? An explicit `--config` argument in the plist is a sensible default.
- What Ruby executable/version and developer bootstrap should service installation target?
- Does real hardware expose a unique stable serial? If not, are USB topology-based identities acceptable for this host?


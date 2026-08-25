---
created: 2026-08-25
topic: ambx2mqtt-what-remains
restored: false
---

# Handoff: what is left of `ambx2mqtt`

Everything that does not touch USB is built and merged. What remains needs the `libambx` driver,
which is being written separately against
`ambx/docs/superpowers/specs/2026-08-25-libambx-multi-device-design.md`.

## What works today

A daemon that, given something answering "which sets are attached":

- Shows each set in Home Assistant as **one device with five lamps** — left, right, wallwasher
  left, wallwasher centre, wallwasher right.
- Takes colour, brightness and on/off per lamp. The hardware has no brightness of its own, so a
  dimmed lamp is a darker colour on the wire. Off sends black and keeps the colour, so on brings
  it back.
- Remembers what each lamp was last asked for and puts it back after a restart. A memory that
  cannot be read is set aside as `.unreadable` rather than crashing or being overwritten.
- Marks a set unavailable when it goes, and forgets it after two days unseen — clearing the
  retained announcement so Home Assistant removes the five lamps on its own.
- Leaves word with the broker before connecting, so a daemon that dies is seen to have gone. A
  lamp is reachable only while both the daemon and its own set are here.
- Reads its broker password from 1Password through an `op://` reference. The password is never in
  the repository, and a secret never shows itself when printed.
- Does its rounds while running, so an unplug is noticed.

Fifty tests, no hardware and no broker needed. They assert the bytes we send and the payloads we
publish, not what anyone else's tool does with them.

## What the daemon needs from the driver

`AmbxDriver` will be the only class in this repository that mentions `libambx`. Everything else is
already written against this shape, so nothing but that one class should have to change:

| The daemon asks | It expects back |
| --- | --- |
| `attached_sets` | one object per physical amBX box attached right now |
| each of those: `identity` | a name that is the same after a replug — the USB serial, or the port path when there is no serial — safe to put in an MQTT topic |
| each of those: `write(bytes)` | those six bytes reaching **that box and no other** |

Two further needs:

- A `write` to a box that has just been unplugged must fail without taking the process down and
  without disturbing the other boxes. The daemon notices the loss on its next round.
- Nothing is ever read back from the hardware. The daemon only ever reports what it asked for.

## What remains, in order

1. **`AmbxDriver`** — the adapter above, once `libambx` exposes individual sets. Its own test
   asserts only the messages the daemon sends it.
2. **`bin/ambx2mqtt --config <path>`** — reads the configuration, resolves the broker password,
   builds the client, the broker, the memory and the driver, and runs the daemon. Set names come
   from `Configuration#name_for(identity)` into `Set.new(name:)`.
3. **Logging** — plain text to standard output; the service files decide where it lands.
4. **`service/nl.eirvandelden.ambx2mqtt.plist`** — a macOS LaunchAgent rather than a LaunchDaemon,
   because it needs the logged-in user's 1Password session and USB access. Explicit `--config`
   path, the `rv`-managed Ruby, `KeepAlive`, logs to `~/Library/Logs/ambx2mqtt.log`.
5. **`service/ambx2mqtt.service`** — the systemd user unit, for the day this moves to Linux.
6. **`docs/installing.md`** — checkout, `rv`, `bundle install`, write the configuration, load the
   service.
7. **The hardware walkthrough** — with two sets plugged in, by hand:
   - both discovered, each with its own identity; record whether real serials exist
   - two devices in Home Assistant, ten lamps, all controllable
   - colour, brightness and on/off each do the right thing on the right lamp
   - commanding one set leaves the other alone
   - unplug one: it goes unavailable, the other keeps working; replug: it returns with its colours
   - restart the daemon: colours return
   - sleep and wake the Mac: sets come back
8. **Friendly names** — fill in the real identities once they have been observed.

## Open questions for the hardware walkthrough

- Does each box expose a non-empty, unique, replug-stable serial? If not, the port-path identity
  changes whenever the box moves to a different socket, and the friendly-name map has to be
  rewritten when it does.
- How long can the rounds be? Thirty seconds is a guess; a longer round means a slower unplug is
  noticed, a shorter one means more USB polling.

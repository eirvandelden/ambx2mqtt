# ambx2mqtt

## What this is

A daemon that makes Philips amBX light sets available to Home Assistant over MQTT. It runs on
the computer the amBX sets are plugged into, finds every attached set, announces it to an MQTT
broker via Home Assistant's MQTT discovery, and turns Home Assistant's colour/brightness/speed
commands into USB writes through the `libambx` gem.

## Domain

- **Set**: one physical amBX box. Identity is `port_<usb-path>` (no serial) or
  `serial_<serial>`. Moving a set to a different USB socket changes its `port_` identity.
- **Lamp**: 5 per set — `left`, `right`, `wallwasher left`, `wallwasher centre`,
  `wallwasher right`. Takes colour, brightness, on/off; remembers what it was last asked for.
- **Fan**: 0 or 2 per set — `left fan`, `right fan`. Optional accessory, cannot be detected by
  the hardware; only exists in Home Assistant when the set's config says `fans: true`. Takes
  on/off and a speed (1–255), remembers its last speed, starts at its slowest if never given
  one.
- **Wiring**: `sides_swapped` and `fans_swapped` correct for the left/right speaker and fan
  cables ending up in each other's socket — cosmetic naming only, no protocol difference.
- **Daemon**: polls attached sets every round via `AmbxDriver`, announces arrivals, marks
  departures unavailable, and forgets a set unseen for `GRACE_PERIOD` (48h).
- **Broker**: the MQTT connection; publishes announcements/state and listens for commands.
- **RememberedState**: what each lamp/fan was last told, survives daemon restarts, does not
  survive a set changing identity.
- Invariant: hardware cannot be read back. Everything Home Assistant shows is "last asked for",
  never an actual reading.

## Commands

```
rv install && bundle install                          # setup (needs network + compiler for libambx)
bin/ambx2mqtt --config ~/.config/ambx2mqtt/config.yml  # run
bundle exec rake test                                  # test (no hardware/broker needed)
bundle exec rubocop                                     # lint
bundle exec bundler-audit check --update                # dependency audit
```

## Gotchas

- `libambx` is fetched from `github.com/eirvandelden/libamBX`, not RubyGems, and compiles a USB
  library — `bundle install` needs network access and a compiler.
- Fans can never be inferred from the hardware. Adding fan support to a set is purely a config
  change (`fans: true`); do not try to detect them.
- The broker password is never in the config file — it's a 1Password reference
  (`op://...`) resolved at startup via the `op` command. 1Password must be unlocked first.
  Never print or log the resolved password.
- `libambx`'s `Ambx.devices` leaks a USB context per scan (upstream bug, fix lives in
  `eirvandelden/libamBX`, not here). This makes discovery go blind for hours at a time and
  recover on its own via GC — a real symptom of a known upstream issue, not necessarily a bug in
  this repo. See `docs/handoffs/2026-08-31-libambx-usb-context-leak.md`.
- Tests use stand-ins for USB and MQTT (`test/support/stand_in_*.rb`) — never touch real
  hardware or a real broker. Keep it that way.
- Work happens in a worktree under `.worktrees/`, never the main checkout.

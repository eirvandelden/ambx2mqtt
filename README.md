# ambx2mqtt

Makes Philips amBX light sets available to Home Assistant over MQTT.

Run it on the computer the amBX sets are plugged into. It finds every attached set, announces
each one to your MQTT broker, and turns Home Assistant's colour and brightness commands into USB
writes.

## What you get

Every physical amBX **set** shows up in Home Assistant as one device with five **lamps**:

| Lamp | Where it sits |
| --- | --- |
| left | beside the screen, on the left |
| right | beside the screen, on the right |
| wallwasher left | behind the screen, on the left |
| wallwasher centre | behind the screen, in the middle |
| wallwasher right | behind the screen, on the right |

Each lamp takes a colour, a brightness and on/off, and remembers what it was last asked for.

The hardware cannot be read back, so what Home Assistant shows is always *what was last asked
for*, never a reading from the lamp itself.

## Running it

```
rv install
bundle install
cp config/ambx2mqtt.example.yml ~/.config/ambx2mqtt/config.yml
$EDITOR ~/.config/ambx2mqtt/config.yml
bin/ambx2mqtt --config ~/.config/ambx2mqtt/config.yml
```

Installing it as a background service is described in `docs/installing.md`.

## Secrets

The configuration file never holds your broker password — it holds a 1Password reference like
`op://Familie/MqttBroker/password`, which the daemon resolves at startup with the `op` command.
Unlock 1Password before the daemon starts.

## Working on it

```
bundle exec rake test        # the whole suite; no hardware and no broker needed
bundle exec rubocop
bundle exec bundler-audit check --update
```

Tests never touch real hardware and never talk to a real broker. They assert the bytes we send to
a set and the payloads we publish to a broker, using stand-ins for both.

Two departures from the usual personal-project setup, both on purpose:

- **No Brakeman.** It scans Rails applications; this is a headless daemon with no web surface.
- **No locale files.** There is no user interface to translate. The only names anyone reads are
  the friendly names they write in their own configuration, and Home Assistant translates its own
  interface.

Work happens in a worktree under `.worktrees/`, never in the main checkout.

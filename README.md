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

## Installing

Installation is for developers: a checkout and Bundler, not a package.

### 1. The driver

ambx2mqtt reaches the sets through the `libambx` gem, which is not on RubyGems. Add it to the
`Gemfile` from where it lives:

```ruby
gem "libambx", github: "eirvandelden/libamBX"
```

Without it `bin/ambx2mqtt` stops at `cannot load such file -- libambx`. Nothing else in the
project needs it — the test suite runs without it.

### 2. The checkout

```
git clone git@github.com:eirvandelden/ambx2mqtt.git
cd ambx2mqtt
rv install          # installs the Ruby named in .ruby-version
bundle install
```

### 3. The configuration

```
mkdir -p ~/.config/ambx2mqtt
cp config/ambx2mqtt.example.yml ~/.config/ambx2mqtt/config.yml
$EDITOR ~/.config/ambx2mqtt/config.yml
```

Fill in your broker. **The password is never written in the file** — put a 1Password reference
like `op://Familie/MqttBroker/password` and the daemon reads it at startup with the `op` command.
Unlock 1Password before the daemon starts.

Leave the `sets:` section alone for now. You cannot know what your sets are called until the
daemon has seen them.

### 4. Run it once by hand

```
bin/ambx2mqtt --config ~/.config/ambx2mqtt/config.yml
```

It says what it found:

```
found the set port_1_2_2, calling it "amBX"
found the set port_1_2_3, calling it "amBX 2"
```

A set nobody has named is called after what it is, numbered from the second onwards. The first
word on each line is the set's identity. Put those in the `sets:` section with names you would
recognise, and restart:

```yaml
sets:
  port_1_2_2: Living room
  port_1_2_3: Study
```

Home Assistant should now show one device per set, each with five lamps.

### 5. Check which speaker is which

Turn on the lamp called **left** and look at it. The two side speakers are separate units on
cables, so they can end up in each other's socket. If the lamp on your right lights up, say so and
the names follow the room rather than the wiring:

```yaml
sets:
  port_1_2_2: Living room
  port_1_2_3:
    name: Study
    sides_swapped: true
```

A set that only needs a name can stay written as just that name. The wallwasher is a single bar,
so its three zones cannot be re-cabled and need no setting.

The plain `amBX` names are handed out in order of identity, so unplugging one set can renumber
another. Naming a set in the configuration pins it.

A set with a serial number is called `serial_` and its serial. A set without one — which is what
the amBX boxes turn out to be — is called `port_` and where it is plugged in. That means moving a
set to a different USB socket gives it a new identity: the old one goes unavailable and is dropped
after two days, a new unnamed set appears, and the colours do not follow. Keep them in the same
sockets, or expect to rename after a move.

### 6. Keep it running

**macOS**

```
cp service/nl.eirvandelden.ambx2mqtt.plist ~/Library/LaunchAgents/
$EDITOR ~/Library/LaunchAgents/nl.eirvandelden.ambx2mqtt.plist   # replace CHECKOUT and USERNAME
launchctl load ~/Library/LaunchAgents/nl.eirvandelden.ambx2mqtt.plist
```

It is a LaunchAgent rather than a LaunchDaemon on purpose: it needs your 1Password session to read
the broker password, and your USB access to reach the sets. Logs go to
`~/Library/Logs/ambx2mqtt.log`.

To stop it:

```
launchctl unload ~/Library/LaunchAgents/nl.eirvandelden.ambx2mqtt.plist
```

**Linux**

```
cp service/ambx2mqtt.service ~/.config/systemd/user/
$EDITOR ~/.config/systemd/user/ambx2mqtt.service   # replace CHECKOUT
systemctl --user daemon-reload
systemctl --user enable --now ambx2mqtt
journalctl --user -u ambx2mqtt -f
```

## When something is wrong

| What you see | What it means |
| --- | --- |
| `cannot load such file -- libambx` | the driver is not installed; see step 1 |
| `the configuration does not say where the broker is` | the `broker:` block has no `host:`; see step 3 |
| `1Password would not give up op://...` | 1Password is locked, or the reference is wrong. The message names the reference, never the password |
| `the set ... would not open` | another program is holding the USB device, or it needs replugging. The daemon tries again next round |
| lamps greyed out in Home Assistant | the set was unplugged, or the daemon stopped. Both report offline |
| lamps gone from Home Assistant | the set has been unseen for two days and was forgotten. Plug it back in and it returns |

Turn `log_level` up to `debug` in the configuration for more.

## Working on it

```
bundle exec rake test        # the whole suite; no hardware and no broker needed
bundle exec rubocop
bundle exec bundler-audit check --update
```

Tests never touch real hardware and never talk to a real broker. They assert the bytes we send to
a set and the payloads we publish to a broker, using stand-ins for both.

Work happens in a worktree under `.worktrees/`, never in the main checkout.

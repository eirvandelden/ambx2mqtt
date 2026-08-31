---
created: 2026-08-31
topic: libambx-usb-context-leak
for: eirvandelden/libamBX
restored: false
---

# Handoff: `Ambx.devices` leaks a USB context on every call

This describes a fault in the **`libambx` driver**, found by the `ambx2mqtt` daemon that depends
on it. The work belongs in `eirvandelden/libamBX`, checked out locally at `~/Developer/ambx`.
Nothing in `ambx2mqtt` needs to change.

## What goes wrong

`Ambx.devices` builds a fresh USB context every time it is called and never lets it go:

```ruby
# libcombustd/communication/ambx.rb:19-23
def self.devices
  LIBUSB::Context.new.devices.filter_map do |dev|
    Device.new(dev) if dev.idVendor == ProtocolDefinitions::USB_VENDOR_ID && ...
  end
end
```

Any program that scans repeatedly leaks two file descriptors per scan and eventually stops being
able to see the hardware at all. `ambx2mqtt` scans every thirty seconds, so it hits this within
hours of starting.

## What it looks like from outside

Two different failures, in this order.

**First, discovery dies quietly.** Every scan starts failing and never recovers:

```
E, [2026-08-31T14:34:22] ERROR -- : this round went wrong, carrying on: LIBUSB::ERROR_OTHER in libusb_init
E, [2026-08-31T14:34:52] ERROR -- : this round went wrong, carrying on: LIBUSB::ERROR_OTHER in libusb_init
```

43 of those in the daemon's log, one per scan, from about 78 minutes after it started until it was
restarted. The daemon stayed up the whole time — it survives a failed scan on purpose — but it
could no longer find a single set. Anything already plugged in stayed working; nothing new was ever
noticed. Only a restart put it right.

**Then the process aborts.** Left running long enough it does not raise, it dies:

```
Assertion failed: (pthread_key_create(key, ((void*)0)) == 0), function usbi_tls_key_create,
  file threads_posix.h, line 87.
libusb-0.8.0/lib/libusb/context.rb:108: [BUG] Aborted
```

This is a native abort, not a Ruby exception. No `rescue` anywhere can catch it. A service set to
restart will simply loop.

## Reproducing it

From a checkout with the gem available:

```ruby
require "libambx"

2000.times do |n|
  Ambx.devices
  puts "#{n + 1} calls, #{Dir.children("/dev/fd").size} file descriptors open" if ((n + 1) % 100).zero?
end
```

Observed on macOS 26.6.2, Ruby 4.0.6, libusb gem 0.8.0, with **no amBX hardware attached** — the
leak does not need a device:

```
100 calls, 207 file descriptors open
200 calls, 407 file descriptors open
300 calls, 607 file descriptors open
400 calls, 807 file descriptors open
500 calls,  75 file descriptors open     <- garbage collection reclaims some, not enough
...
900 calls -> Assertion failed ... [BUG] Aborted
```

Two descriptors per call, linear. The occasional drop is the garbage collector finalising some
contexts; it does not keep up, and it does not release the thread-local keys that cause the abort.

## Two fixes, both measured

Both were run for 2000 scans against the same machine. Either one holds.

**Hold one context for the life of the process** — 2000 scans, **9 descriptors open**:

```ruby
context = LIBUSB::Context.new
2000.times { context.devices }
```

**Or close each context after use** — 2000 scans, **7 descriptors open**:

```ruby
2000.times do
  context = LIBUSB::Context.new
  context.devices
  context.exit
end
```

Compare against 807 descriptors after only 400 scans today.

The first is the better shape for a driver: a USB context is a handle on the subsystem, not a
per-query object, and the `Device` instances handed out reference it. **Closing a context while a
caller still holds an open `Device` from it is the risk to think through** — `ambx2mqtt` keeps its
device objects for as long as the box stays plugged in, across many later scans. That alone
probably decides it: with the second fix, the context a device was discovered through is gone by
the time the device is written to. Confirm that before choosing.

## Suggested steps

1. **Write the failing test first.** The existing specs stand in for `LIBUSB` at the top of
   `spec/ambx_spec.rb`, so the fake `LIBUSB::Context` can count how many times it is constructed.
   A test along the lines of *scanning for controllers many times does not build a new USB context
   each time* fails today and passes after the fix. `Rakefile` builds one task per spec file.
2. **Make `Ambx.devices` stop leaking**, preferring the shared context unless step 4 says
   otherwise.
3. **Check the other places that touch a context.** `git grep "Context.new"` currently shows only
   this one outside the specs, but confirm after the change.
4. **Decide the lifetime question**: can a `Device` outlive the context it came from? If a shared
   context is used this cannot happen, which is the argument for it. Write the answer down in the
   code or the design doc, because the next person will ask.
5. **Verify on real hardware** with two sets attached: scan a few hundred times, watch
   `Dir.children("/dev/fd").size` stay flat, then open a device and write to it to prove the shared
   context is still usable.
6. **Release a new version** and say in the changelog that long-running callers were affected, so
   anyone pinned to `0.4.0` knows to move.

## Verifying it is fixed

```
cd ~/Developer/ambx
bundle exec rake test
bundle exec rubocop
```

Then the reproduction above: 2000 calls should leave file descriptors flat and the process alive.

## Out of scope

- Anything in `ambx2mqtt`. It pins `libambx` by commit and will pick this up when it moves.
- The unplug signal. Separately, `Device#transfer` and `close_handle` rescue only `Errno::ENXIO`,
  while a real unplug on macOS raises `LIBUSB::ERROR_NO_DEVICE`; the driver's own contract says
  expected unplugs answer `false`, and on this hardware they never do. Recorded in
  `docs/handoffs/2026-08-25-ambx2mqtt-what-remains.md`. Worth its own change, not this one.
- Anything about how often callers scan. Thirty seconds is `ambx2mqtt`'s choice and a driver should
  not care.

## Where the numbers came from

Every figure above was measured on 31 August 2026 against `libambx` at commit `cceb007` (version
`0.4.0`) as bundled into `ambx2mqtt`, on macOS 26.6.2 with Ruby 4.0.6 and libusb gem 0.8.0. The
daemon log quoted is `~/Library/Logs/ambx2mqtt.log`.

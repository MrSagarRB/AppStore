# MacPulse — System Monitor for the menu bar

Live CPU, memory, temperature, battery and network stats right in the macOS menu bar.

- **Menu bar:** `CPU 26%  RAM 79%  53°C  🔋64%  ↓2.6M ↑20.9K` — switch any item on/off in Settings
- **Click for details:** per-core CPU load + history, memory breakdown (app / wired / compressed /
  cached / swap) with **memory pressure**, CPU / SSD / battery temperature + thermal state,
  battery (time remaining, power draw, adapter watts, health, cycles), network speed graph
- **Right-click** the menu bar item → Open Activity Monitor / Quit
- Update interval 1/2/5 s, °C/°F, launch at login

## Build & install
    ./build.sh            # → build/MacPulse.app and build/MacPulse.dmg (drag-to-Applications installer)
    ./build.sh --install  # also copies the app straight into /Applications

Requires macOS 14+. Debug: `MacPulse.app/Contents/MacOS/MacPulse --show-popover` opens the panel on launch.

## Notes
- Temperatures on Apple Silicon come from IOKit's private HID sensor interface, so the app is not
  sandboxed and isn't suitable for the Mac App Store as-is. On Macs where no sensors are exposed
  (e.g. some Intel models) the panel falls back to the system thermal state.
- Network speed counts physical interfaces (Wi-Fi/Ethernet) only, so VPN traffic isn't double counted.

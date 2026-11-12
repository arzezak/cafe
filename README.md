# cafe

A menu bar toggle that keeps a Mac awake, like `caffeinate -s`.

Click the cup and choose Keep Awake to turn it on: the icon fills in and the system won't sleep while on AC power (the display can still sleep). Choose it again to turn it off. Right-click the cup to toggle it without opening the menu. It always starts off.

## Install

```sh
make install
```

This builds `~/Applications/Cafe.app` with `swiftc` and loads a LaunchAgent so it starts at login. Both use the bundle identifier `com.arzezak.cafe`; set your own with `make install BUNDLE_ID=com.example.cafe`, and pass the same value to `make uninstall` and `make restart`.

Remove the app and LaunchAgent:

```sh
make uninstall
```

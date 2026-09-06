# Mouse Locator

A native macOS menu bar app that makes the pointer easier to find with a
configurable fading mouse trail and a sonar pulse when movement resumes after
inactivity.

## Requirements

- macOS 14 or later
- Swift 6 toolchain

## Build

```sh
make test
make app
open .build/MouseLocator.app
```

Mouse Locator is available from the menu bar. Its two effects can be enabled
together and configured from Settings. Trail and circle thickness are adjusted
independently and both default to 8 pt.

## Install

```sh
make install
```

This installs Mouse Locator in `~/Applications`, registers it to launch at
login, and starts it. Running the same command again upgrades and re-registers
the application. If macOS requires approval, System Settings opens to Login
Items.

## Uninstall

```sh
make uninstall
```

This stops the application, unregisters it from Login Items, and removes it.
Saved settings are kept.

## License

[Mozilla Public License 2.0](LICENSE)

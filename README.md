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
together and configured from either the menu-bar Settings window or the Mouse
Locator pane in System Settings. Trail and circle thickness are adjusted
independently and both default to 8 pt.

Preferences are stored in `$XDG_CONFIG_HOME/mouse-locator/settings.json`, or
`~/.config/mouse-locator/settings.json` when `XDG_CONFIG_HOME` is unset. Existing
preferences are migrated automatically the first time this version starts.

## Install

```sh
make install
```

This installs Mouse Locator in `~/Applications`, installs its System Settings
pane in `~/Library/PreferencePanes`, registers it to launch at login, and starts
it. Running the same command again upgrades and re-registers the application.
If macOS requires approval, System Settings opens to Login Items.

## Uninstall

```sh
make uninstall
```

This stops the application, unregisters it from Login Items, and removes the
application and System Settings pane. Saved settings are kept.

## License

[Mozilla Public License 2.0](LICENSE)

# Mouse Locator

**Tired of shaking your mouse or trackpad just to find the pointer?**

Mouse Locator brings to macOS the mouse-finder effects that Linux desktops have
offered for years.

This native app makes the pointer easier to spot with two configurable cues:

- a fading Mouse Tail
- an Idle Pulse when movement resumes after inactivity

## Showcase

From left to right:

1. Mouse Tail.
2. Idle Pulse.
3. Mouse Tail and Idle Pulse together.
4. Rainbow Mouse Tail.

> [!NOTE]
> Idle Pulse appears when pointer movement resumes after the configured
> inactivity delay.

<p align="center">
  <picture><source media="(prefers-color-scheme: dark)" srcset=".github/docs/images/trail-dark.png"><source media="(prefers-color-scheme: light)" srcset=".github/docs/images/trail-light.png"><img alt="A blue mouse trail following the pointer" src=".github/docs/images/trail-light.png" width="205"></picture>
  <picture><source media="(prefers-color-scheme: dark)" srcset=".github/docs/images/idle-pulse-dark.png"><source media="(prefers-color-scheme: light)" srcset=".github/docs/images/idle-pulse-light.png"><img alt="An expanding circle locating the pointer after inactivity" src=".github/docs/images/idle-pulse-light.png" width="205"></picture>
  <picture><source media="(prefers-color-scheme: dark)" srcset=".github/docs/images/both-dark.png"><source media="(prefers-color-scheme: light)" srcset=".github/docs/images/both-light.png"><img alt="A mouse trail and idle pulse enabled together" src=".github/docs/images/both-light.png" width="205"></picture>
  <picture><source media="(prefers-color-scheme: dark)" srcset=".github/docs/images/rainbow-trail-dark.png"><source media="(prefers-color-scheme: light)" srcset=".github/docs/images/rainbow-trail-light.png"><img alt="A rainbow mouse trail following the pointer" src=".github/docs/images/rainbow-trail-light.png" width="205"></picture>
</p>

## Features

Mouse Locator is available from the menu bar. Its two effects can be enabled
together and configured in the Mouse Locator pane in System Settings, which can
also be opened from the menu-bar menu. Tail and circle thickness are adjusted
independently and both default to 3 pt. After inactivity, the pulse follows the
pointer for three seconds and can use a chosen color or rainbow colors. The
tail also supports a chosen color or a smooth rainbow gradient. Its configurable
cursor gap defaults to 16 pt.

## Install

```sh
make install
```

Mouse Locator requires macOS 14 or later.

This installs Mouse Locator in `~/Applications`, installs its System Settings
pane in `~/Library/PreferencePanes`, registers it to launch at login, and starts
it. Running the same command later upgrades and re-registers the application.
If macOS requires approval, System Settings opens to Login Items.

## Uninstall

```sh
make uninstall
```

This stops the application, unregisters it from Login Items, and removes the
application and System Settings pane. Saved settings are kept.

## Configuration

Preferences are stored in `$XDG_CONFIG_HOME/mouse-locator/settings.json`, or
`~/.config/mouse-locator/settings.json` when `XDG_CONFIG_HOME` is unset. Existing
preferences are migrated automatically on first launch.

Settings intended for manual editing only:

- `tailDotsEnabled`: defaults to `false`; set it to `true` to restore rounded
  sample-point caps.
- `tailSmoothing`: defaults to `"bezier"`; set it to `"none"` for straight
  segments.

Restart Mouse Locator after editing the JSON file manually.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for build, test, and showcase-image
instructions.

## License

[Mozilla Public License 2.0](LICENSE)

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
together and configured from Settings.

## Install

```sh
make install
```

This installs Mouse Locator in `~/Applications`. Running the same command again
replaces the installed application and restarts it.

## License

[Mozilla Public License 2.0](LICENSE)

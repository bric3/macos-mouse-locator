# Contributing

## Requirements

- macOS 14 or later
- Swift 6 toolchain

## Build and test

```sh
make test
make run
```

Keep each change focused on a dedicated branch and use a conventional commit
prefix such as `feat:`, `fix:`, `docs:`, or `test:`.

## Showcase images

Regenerate all showcase images over an isolated blank panel with:

```sh
make screenshots
```

The command temporarily stops and restores an installed Mouse Locator process.
It uses isolated temporary settings and does not modify the user configuration.

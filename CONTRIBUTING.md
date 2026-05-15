# Contributing

Thanks for helping improve Room Light Sensor.

## Development Setup

Install Xcode or the Xcode command line tools, then verify the project:

```sh
swift build
swift test
```

Run the app locally:

```sh
swift run RoomLightSensor
```

## Pull Requests

- Keep pull requests focused on one change.
- Include tests for behavior changes.
- Update the README when a change affects installation, usage, packaging, or compatibility.
- Run `swift test` before opening a pull request.

## Sensor Compatibility

Ambient light sensor availability varies by Mac model and macOS version. When changing sensor behavior, include a short note about the hardware and macOS version used for manual verification.

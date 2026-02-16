# Brightness Control for macOS

A lightweight menu bar app to control the brightness of your internal and external displays.

## Features
- **Internal Display Support**: Uses macOS private APIs to control built-in screens.
- **External Display Support**: Uses DDC/CI (I2C) to control external monitors.
- **Menu Bar Only**: Stays out of your dock for a clean workflow.
- **Autostart**: Option to launch automatically at login.

## How to Build a Proper .app
I've provided a script to handle the packaging for you. This creates the correct macOS folder structure, compiles the asset catalog (for your new icon), and signs the bundle.

1.  **Generate the App**:
    ```bash
    ./package_app.sh
    ```
2.  **Run it**:
    Open the generated `BrightnessControl.app` in Finder, or run:
    ```bash
    open BrightnessControl.app
    ```

## Structure
- **BrightnessControl.app**: The standalone application bundle.
- [Sources/BrightnessControl/BrightnessControlApp.swift](Sources/BrightnessControl/BrightnessControlApp.swift): Main entry point and UI.
- [Sources/BrightnessControl/BrightnessManager.swift](Sources/BrightnessControl/BrightnessManager.swift): Business logic for display management and autostart.
- [Sources/BrightnessControl/DDCManager.swift](Sources/BrightnessControl/DDCManager.swift): Low-level DDC/CI implementation for external displays.
- [Sources/BrightnessControl/Info.plist](Sources/BrightnessControl/Info.plist): Application metadata (embedded in the binary).
- [package_app.sh](package_app.sh): Automates the packaging process.

## Permissions
Accessing external display brightness via I2C may require accessibility or screen recording permissions on some versions of macOS, though standard I2C usually doesn't.

## build an run
```
./package_app.sh && open BrightnessControl.app
```
## Disclaimer & Legal
- **As-Is**: This software is provided "as-is" without any warranty. By using this app, you acknowledge that you do so at your own risk.
- **Hardware**: DDC/CI (External Display Control) communicates directly with your monitor firmware. While rare, the author is not responsible for any potential hardware malfunctions.
- **Private APIs**: This app utilizes undocumented `DisplayServices` for internal screen control.
- **Liability**: The author shall not be held liable for any damages arising from the use or inability to use this software.

## Privacy
This app **does not collect, store, or transmit any data**. No telemetry, no crashes are reported, and no network requests are made. All preferences are stored locally in your system's `UserDefaults`.

## License
Personal and Non-Commercial use only. See [LICENSE](LICENSE) for details.
- Commercial use in any form requires explicit permission.

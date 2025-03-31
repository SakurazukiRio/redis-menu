# RedisMenu

![RedisMenu](screenshots/screenshot1.png)

A macOS menu bar application that makes managing local Redis instances simple and convenient.

## Overview

RedisMenu sits in your macOS menu bar, providing easy access to start, stop, and configure Redis instances. It's designed for developers who need to work with Redis locally and want a straightforward way to manage the database without terminal commands.

## Features

- **Menu Bar Controls**: Start and stop Redis with a single click directly from your menu bar
- **Visual Status Indicator**: Instantly see if Redis is running in your menu bar
- **Custom Configuration**: Configure Redis's data directory, log path, and port
- **Auto-start Options**: Choose to start Redis automatically when the app launches
- **Launch at Login**: Set RedisMenu to start when your Mac boots up
- **Lightweight Footprint**: Minimal resource usage while running in the background

## Screenshots

![Preferences Window](screenshots/screenshot2.png)
![RedisMenu About](screenshots/screenshot3.png)

## Requirements

- macOS 15.0 (Sequoia) or later
- Admin privileges (for first-time setup)

## Installation

To build RedisMenu from source:

1. Clone this repository:

   ```bash
   git clone https://github.com/maquina-app/redis-menu.git
   cd redis-menu
   ```

2. Run the build script:

   ```bash
   ./build.sh
   ```

   The build script will:
   - Download and compile Redis if needed
   - Build the application
   - Place the built app in `build/Release/RedisMenu.app`

3. Move the built app to your Applications folder

## Building Requirements

- Xcode 16.0 or later
- Command Line Tools for Xcode
- macOS 15.0 (Sequoia) or later

## Usage

1. Click the Redis icon in the menu bar to see the status and control options
2. Use "Start Redis" or "Stop Redis" to control the service
3. Click "Preferences" to configure settings:
   - Data directory location
   - Log file path
   - Redis port (default: 6379)
   - Auto-start options
   - Launch at login option

## Technical Details

RedisMenu downloads, compiles, and bundles Redis binaries (latest stable version) for your Mac, so you don't need to install Redis separately. The app handles downloading and compiling the appropriate Redis source code for your system.

By default, RedisMenu stores:

- Redis data in `~/.local/share/redis/data`
- Redis logs in `~/.local/state/redis/logs/redis.log`

Both of these locations can be customized in the app preferences.

## Troubleshooting

### Redis Won't Start

- Check if the port is already in use by another application
- Ensure you have write permissions to the data directory and log path
- Check the log file for specific error messages

### App Won't Launch

- Make sure you have macOS Sequoia (15.0) or later installed
- Try rebuilding from source using the build script

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Created By

This application was created by Mario Alberto Chávez.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Copyright

© 2025 Maquina App. All rights reserved.

## Disclaimer

Redis and the Redis logo are registered trademarks of Redis Ltd. This application is not affiliated with or endorsed by Redis Ltd.

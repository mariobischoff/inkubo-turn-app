# Inkubo Turn 📸🔄

**Inkubo Turn** is a Flutter-based mobile application designed for 360-degree product photography automation. It interfaces seamlessly with an ESP8266/NodeMCU custom hardware via REST API to control a motorized rotating base, capturing synchronized photo sequences and generating high-quality MP4 timelapses natively on the device.

## 🚀 Key Features

* **Hardware Synchronization**: Real-time communication with NodeMCU over local Wi-Fi to orchestrate motor movements and camera shutters.
* **Dynamic Motor Control**: 
  * Adjustable motor speed (1-10 levels) applied to all rotation modes.
  * Continuous rotation control for manual adjustments.
  * Absolute angle positioning with automatic step calculation (`steps = (angle * 2048) / 360`).
* **Automated 360° Sequences**: Select the desired number of frames (8, 12, 24, 36, or 72) and let the app automatically rotate the base and capture the product from all angles.
* **Native Video Encoding**: Compiles the captured image sequences into a `.mp4` video (10 FPS) directly on the device using native hardware encoders (`MediaCodec` / `AVFoundation`), offloading image processing to background isolates to guarantee a buttery-smooth UI.
* **Gallery Integration**: Automatically saves generated videos directly to the device's native gallery.
* **Dark Mode UI**: Sleek, immersive Dark Theme featuring Cyan/Neon accents, optimized for studio environments.

## 🛠️ Technology Stack

* **Framework**: Flutter / Dart
* **Hardware Communication**: `http` (REST API over Local Network)
* **Camera Access**: `camera`
* **Video Generation**: `flutter_quick_video_encoder` (Hardware-accelerated)
* **Image Processing**: `image` (Isolated pixel manipulation)
* **Gallery Management**: `gal`

## 📡 API Protocol (NodeMCU)

The application expects the hardware base to be accessible at `http://inkuboturn.local` (or configured IP) and respond to the following endpoints:

* `GET /status` - Returns `{ "status": "idle" }` or `{ "status": "moving" }`
* `POST /move?steps={x}&speed={y}` - Rotates the stepper motor by `x` steps at `y` speed.
* `POST /continuous?speed={y}` - Starts continuous rotation.
* `POST /stop` - Immediately halts the motor.

## 🔧 Hardware Setup (ESP8266)

The C++ firmware for the motorized base is located in the `firmware/` directory.

1. Open `firmware/inkubo_turn.ino` in the Arduino IDE.
2. Install the **ESP8266** board support via Boards Manager.
3. Update the Wi-Fi credentials on line 93: `WiFi.begin("YOUR_WIFI_SSID", "YOUR_WIFI_PASSWORD");`
4. Connect your ESP8266/NodeMCU to your PC and flash the firmware.
5. The device will host an mDNS service and be accessible at `http://inkuboturn.local` on your local network.
## 📸 Screenshots & UI

*(Add your app screenshots here!)*

## 🧠 Architectural Highlights

* **Isolate Processing**: The application avoids main-thread UI freezing by utilizing Dart's `compute()` to offload heavy `image.decodeImage()` and resizing calculations to a background thread during video generation.
* **Cleartext HTTP**: Uses localized Cleartext HTTP requests (`android:usesCleartextTraffic="true"`, `NSAppTransportSecurity`) to enable direct, routerless AP connections with IoT microcontrollers.

## 👨‍💻 Developed By

**Mário** (for Inkubo3D) - Portfolio piece demonstrating Hardware-to-Mobile IoT integration, advanced asynchronous processing, and native plugin management in Flutter.

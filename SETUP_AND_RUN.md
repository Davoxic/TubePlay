# TubePlay - Setup & Running Guide

This guide explains how to build, install, and run **TubePlay** on your iOS device or iOS Simulator, as well as how to test the interactive preview on your computer right away.

---

## 1. Quick Interactive Preview (Test Immediately on Any Computer)

You can test the TubePlay UI, YouTube search, and player controls directly in your web browser:

1. Navigate to the `preview/` folder in this repository.
2. Open `index.html` in your browser (Safari, Chrome, Edge, or Brave).
   - Alternatively, serve it locally with Python:
     ```bash
     python -m http.server 8080 --directory preview
     ```
   - Then open `http://localhost:8080` in your browser.
3. You will see an interactive iPhone frame with:
   - Real YouTube search and autocomplete suggestions.
   - Featured background stations (Lofi, Focus, Ambient).
   - Full player controls (15s skip, scrub slider, speed control, loop).
   - "Browser Mode" tab with background audio and ad-blocking simulation.

---

## 2. Building & Running in Xcode (Mac)

### Prerequisites:
- A Mac running macOS 13 (Ventura), 14 (Sonoma), or 15 (Sequoia).
- **Xcode 15 or 16** (available for free on the Mac App Store).
- An iPhone running **iOS 16.0 or later** (or Xcode's built-in iOS Simulator).
- An Apple ID (a free personal Apple ID works; no paid developer account required).

### Steps:

#### Step 1: Open the Project in Xcode
1. Copy the `TubePlay` folder to your Mac (via AirDrop, Git, USB, or cloud drive).
2. Double-click `TubePlay.xcodeproj` inside the `TubePlay` directory.

#### Step 2: Configure Free Code Signing
1. In Xcode's left sidebar (Project Navigator), click on the top-level **TubePlay** project.
2. Under **Targets**, select **TubePlay**.
3. Click the **Signing & Capabilities** tab.
4. Check **Automatically manage signing**.
5. Under **Team**, select your Apple ID (if none is listed, click *Add Account...* and sign in with your free Apple ID).
6. In **Bundle Identifier**, if Xcode asks for uniqueness, adjust it slightly (e.g., `com.yourname.tubeplay`).

#### Step 3: Select Run Destination
- In the top toolbar device selector:
  - Choose your connected **iPhone** (e.g., `David's iPhone`).
  - Or choose any **iOS Simulator** (e.g., `iPhone 15 Pro`).

#### Step 4: Build & Run (`Cmd + R`)
1. Click the **Play** button (or press `Cmd + R`).
2. Xcode compiles the Swift code and launches TubePlay on your iPhone or Simulator.
3. *Note for Physical Devices:* If running on a physical iPhone for the first time, go to your iPhone's **Settings > General > VPN & Device Management**, tap your Apple ID under Developer App, and tap **Trust**.

---

## 3. How to Test Screen-Off Playback

1. In TubePlay, go to the **Search** tab and tap any video (e.g., *Lofi Hip Hop Radio*).
2. Tap the video to start playback.
3. **Turn off the screen:** Press the side/power button on your iPhone.
4. **Result:** The audio continues playing smoothly!
5. **Lock Screen Controls:**
   - Tap your iPhone screen to wake the lock screen.
   - You will see the **Now Playing widget** displaying the video thumbnail, title, channel name, elapsed time, and scrubber.
   - Tap **Pause**, **Play**, **Forward 15s**, or **Backward 15s** directly from the lock screen.
   - Use your AirPods, Apple Watch, or car stereo controls—they all work natively!

---

## 4. Alternate Sideloading (AltStore / Sideloadly)

If you prefer building an `.ipa` file to install via **AltStore**, **Sideloadly**, or **TrollStore**:

1. In Xcode, select **Product > Archive**.
2. When the Organizer window opens, click **Distribute App**.
3. Select **Development** or **Ad Hoc** and export the `.ipa` package.
4. Drag and drop the `.ipa` into **Sideloadly** or install via **AltStore** on your iPhone.

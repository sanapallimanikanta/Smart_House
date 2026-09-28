<div align="center">

# 🏠 Lumina Smart Home (PCB Relay Controller)

**An end-to-end IoT ecosystem for smart home automation, featuring custom PCB hardware, ESP32 firmware, and an AI-powered control dashboard.**

[![Live App](https://img.shields.io/badge/🌐_Live_App-led--on--off--8ef7b.web.app-blue?style=for-the-badge)](https://led-on-off-8ef7b.web.app/)
[![Firebase](https://img.shields.io/badge/Firebase-Hosted-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://led-on-off-8ef7b.web.app/)
[![ESP32](https://img.shields.io/badge/ESP32-Firmware-E7352C?style=for-the-badge&logo=espressif&logoColor=white)](#2-esp32_code-microcontroller-firmware)

<br/>

<a href="https://led-on-off-8ef7b.web.app/">
  <img src="assets/lumina_dashboard_ui.png" alt="Lumina Smart Home Dashboard" width="100%"/>
</a>

</div>

---

## 📖 Project Overview

This repository contains the complete stack for the **Lumina Smart Home** automation system. The project allows users to control physical devices (like LEDs and relays) remotely via a web/mobile application. It features real-time telemetry, automated scene protocols, intelligent WiFi connectivity, and is designed to interface with custom PCB hardware.

### 🔗 Live Application
> **Live Web App:** [https://led-on-off-8ef7b.web.app/](https://led-on-off-8ef7b.web.app/)

---

## 🖥️ Application UI & Features

### 1. Main Dashboard View
The web dashboard provides real-time monitoring and intuitive controls for all connected smart appliances:

<p align="center">
  <img src="assets/lumina_dashboard_ui.png" alt="Lumina Web Dashboard" width="100%"/>
</p>

* **Live Telemetry Bar:** Displays real-time Temperature (°C), Humidity (%), and Power consumption (kW).
* **Multi-Room Navigation:** Filter devices across *All*, *Living Room*, *Kitchen*, *Bedroom*, *Office*, and *Garage*.
* **Automated Scenarios:** Quick execution of presets such as **Morning Protocol** and **Sleep Cycle**.
* **Lumina AI Voice Assistant:** Multilingual voice command recognition for hands-free control.
* **Device Control Cards:** Interactive toggles for relays and lighting circuits.

---

### 2. Built-in ESP32 Source Code Generator & Viewer
The application includes a built-in firmware manager that generates and displays the ready-to-flash C++ code tailored for the board configuration:

<p align="center">
  <img src="assets/lumina_esp32_code_modal.png" alt="ESP32 Source Code Viewer Modal" width="100%"/>
</p>

* **Pre-configured Pin Mappings:**
  * **Onboard Relays (R1–R8):** GPIO 32, 33, 25, 26, 27, 14, 12, 23
  * **External Extension Relays (R9–R14):** GPIO 22, 21, 19, 18, 5, 17
* **One-Click Copy:** Easily copy firmware code directly into Arduino IDE or PlatformIO.
* **Firebase Cloud RTDB Integration:** Pre-fills database URLs and credentials for immediate deployment.

---

## 📂 Repository Structure

The project is organized into three main components:

### 1. `hardware/` (PCB & Circuits)
This directory contains the physical hardware designs for the smart home system.
* Contains Gerber fabrication files ready for manufacturing bare boards at JLCPCB or PCBWay.
* Integrates ESP32 with ULN2003A Darlington drivers, 8 high-power relays, flyback diode protection, and a 12V DC power circuit.

<p align="center">
  <img src="assets/pcb_3d.png" alt="PCB 3D View" width="48%"/>
  <img src="assets/pcb_layout.png" alt="PCB Routing Layout" width="48%"/>
</p>

**Key Hardware Components:**
- **NodeMCU ESP-WROOM-32** — WiFi-enabled microcontroller
- **2× ULN2003A (DIP16)** — Darlington transistor relay drivers
- **8× Electromechanical Relays** — Switching high-voltage AC/DC loads
- **8× Flyback Diodes (D1-D8)** — Inductive transient voltage protection
- **8× Status LEDs (LED1-LED8)** — Real-time visual feedback per relay channel
- **12V DC Power Terminal** — Dual decoupling/smoothing capacitors (1000µF + 10µF)

### 2. `esp32_code/` (Microcontroller Firmware)
Contains the C++ firmware (`led_controller.ino`) that runs on the ESP32 microcontroller.
* **Intelligent Connect:** Automatically scans and connects to prioritized home WiFi networks or falls back to the strongest open network.
* **Hardware Interface:** Directly controls the GPIO pins connected to the relays/LEDs based on commands received from the software.
* **Real-time Synchronization:** Listens for Firebase RTDB state changes and immediately drives the corresponding relay channels.

### 3. `software/` (Application Dashboard)
The user-facing application built to control the smart home ecosystem.
* **Tech Stack:** Modern web application (React/Vite/TypeScript) with Flutter integration.
* **Features:** A sleek, responsive UI dashboard to toggle devices, monitor statuses, and manage the home network. 
* **AI Powered:** Gemini AI integration for voice commands and smart conversations.
* **Backend:** Powered by Firebase (Hosting, Database) for real-time state synchronization across all connected devices.
* **Multi-platform:** Web, Android, iOS, Windows, macOS, and Linux support via Flutter.

---

## 🚀 Getting Started

### Software (Web Dashboard)
To run the web application locally:
1. Navigate to the `software/` directory.
2. Run `npm install` to install dependencies.
3. Add your Gemini API key in `.env.local`.
4. Run `npm run dev` to start the local development server.

### Firmware (ESP32)
To flash the ESP32:
1. Open `esp32_code/led_controller.ino` in the Arduino IDE.
2. Select your ESP32 board and COM port.
3. Install the required libraries (`Firebase_ESP_Client`, `WiFi.h`).
4. Compile and upload to the board.

### Hardware
To fabricate the PCB:
1. Download the Gerber files from `hardware/`.
2. Upload the zip directly to a PCB manufacturer like [JLCPCB](https://jlcpcb.com) or [PCBWay](https://pcbway.com).

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Hardware** | Custom PCB, ESP-WROOM-32, 2× ULN2003A, 8-Channel Relays |
| **Firmware** | Arduino (C++), WiFi, Firebase RTDB Client |
| **Frontend** | React, TypeScript, Vite, Tailwind CSS, Flutter |
| **AI** | Google Gemini 2.5 Flash |
| **Backend** | Firebase Hosting, Firebase Realtime Database |
| **Voice** | Web Speech API, Text-to-Speech |

---

*Built with ❤️ for Home Automation*

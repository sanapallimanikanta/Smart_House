<div align="center">

# 🏠 Lumina Smart Home (PCB Relay Controller)

**An end-to-end IoT ecosystem for smart home automation, featuring custom PCB hardware, ESP32 firmware, and an AI-powered control dashboard.**

</div>

---

## 📖 Project Overview

This repository contains the complete stack for the Lumina Smart Home automation system. The project allows users to control physical devices (like LEDs and relays) remotely via a web/mobile application. It features real-time control, an intelligent connection system, and is designed to work with custom PCB hardware.

## 📂 Repository Structure

The project is organized into three main components:

### 1. `hardware/` (PCB & Circuits)
This directory contains the physical hardware designs for the smart home system.
* Contains the Gerber files (`Gerber_Smart-house_PCB.zip`) ready for PCB manufacturing.
* Designed to integrate the ESP32 microcontroller with relays and power management circuits for safe home automation.

### 2. `esp32_code/` (Microcontroller Firmware)
Contains the C++ firmware (`led_controller.ino`) that runs on the ESP32 microcontroller.
* **Intelligent Connect:** Automatically scans and connects to prioritized home WiFi networks or falls back to the strongest open network.
* **Hardware Interface:** Directly controls the GPIO pins connected to the relays/LEDs based on commands received from the software.
* **Real-time Synchronization:** Listens for state changes and securely updates the hardware states.

### 3. `software/` (Application Dashboard)
The user-facing application built to control the smart home ecosystem.
* **Tech Stack:** Modern web application (React/Vite/TypeScript) with Flutter integration.
* **Features:** A sleek, responsive UI dashboard to toggle devices, monitor statuses, and manage the home network. 
* **Backend:** Powered by Firebase (Hosting, Database) for real-time state synchronization across all connected devices and AI Studio integration for smart features.

---

## 🚀 Getting Started

### Software
To run the web application locally:
1. Navigate to the `software/` directory.
2. Run `npm install` to install dependencies.
3. Add your environment variables in `.env.local`.
4. Run `npm run dev` to start the local development server.

### Firmware
To flash the ESP32:
1. Open `esp32_code/led_controller.ino` in the Arduino IDE.
2. Select your ESP32 board and COM port.
3. Install any required libraries mentioned in the code.
4. Compile and upload to the board.

---
*Built with ❤️ for Home Automation*

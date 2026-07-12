# 🛠️ Hardware: Smart Home 8-Channel Relay Board

This directory contains the hardware design files for the Lumina Smart Home automation system. The custom PCB is designed to securely and reliably control up to 8 high-power loads using an ESP32 microcontroller.

## 🖼️ Board Renders

*(Please add `pcb_layout.png` and `pcb_3d.png` to this folder to view the renders here)*


## 🧩 Key Components

Based on the PCB design, the board integrates the following components:

1. **Microcontroller**: 
   - **NodeMCU ESP-WROOM-32**: The brain of the system, providing WiFi connectivity for remote control and GPIOs for triggering the relays.
2. **Relay Drivers**: 
   - **2x ULN2003A (DIP16)**: Darlington transistor arrays used to safely drive the relay coils from the 3.3V ESP32 logic signals, preventing damage to the microcontroller.
3. **Relays**: 
   - **8x Electromechanical Relays**: Configured to switch high-power loads (e.g., lights, fans, appliances). Each is routed to robust screw terminal blocks (O1-O8).
4. **Protection & Status**:
   - **8x Flyback Diodes (D1-D8)**: Prevents voltage spikes from the relay coils from damaging the driver ICs.
   - **8x Status LEDs (LED1-LED8)**: Provides visual feedback for the state of each relay (ON/OFF).
   - **Current Limiting Resistors (R1-R8)**: In-line with the status LEDs.
5. **Power Management**:
   - **12V DC Input Terminal**: Main power entry for the board.
   - **Filtering Capacitors**: Includes a large 1000uF 25V capacitor and a 10uF 16V capacitor to stabilize power delivery during relay switching events.

## 📁 Files included
- `Gerber_Smart-house_PCB.zip`: The Gerber files required for PCB fabrication. You can upload this zip file directly to manufacturers like JLCPCB or PCBWay to order the bare boards.

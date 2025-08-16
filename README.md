# 🟨 CANtastic! 🟩

**Version 2.0.1 just released! Now with the following new features:**
- Full SystemD support
- Multiple newer configuration setups including Esoterical
- Broken CAN configuration detection
- Built in file viewer
- Script update tool
- Error codes for easier debugging

---
## About

CANtastic! is a feature-rich shell script designed to make managing and troubleshooting **CAN Bus** configurations for [Klipper](https://www.klipper3d.org/) on Linux systems easier than ever.  
It wraps common CAN Bus tasks into an interactive, user-friendly interface so you can set up, configure, and test your CAN Bus network without memorizing long terminal commands.

---

## ✨ Features

- **CAN Bus Interface Setup**
  - Create or update CAN0 network configuration
  - Choose bitrates and transmission queue lengths with clear explanations
  - Automatically restart the interface after configuration changes

- **CAN Bus Utilities Management**
  - Install and uninstall `can-utils` and other dependencies safely
  - Check for missing dependencies before running actions
  - Safe removal of configuration files with confirmation prompts

- **CAN Bus Troubleshooting**
  - Search for connected Klipper MCU UUIDs on the CAN network
  - View and verify current CAN0 settings
  - Test interface connectivity
---

## ⚠️ Disclaimers

- **CANtastic! has only been tested on Linux based operating systems with Klipper**  
- CANtastic! can **modify network configuration files** and restart network interfaces.  
- **USE AT YOUR OWN RISK** — I am **not responsible** for any damage, loss of connectivity, or hardware issues that may occur from using CANtastic!
- Always back up your system before making major configuration changes with CANtastic!
- Running CANtastic! during an active print may cause said print to fail!

---

## 📦 Installing CANtastic!

To install CANtastic!, simply copy & paste the following commands into the Linux terminal:

```shell
# Step 1. Install Git
sudo apt-get update && sudo apt-get install git -y

# Step 2. Clone the CANtastic repository into your home directory
git clone https://github.com/JMallick1997/CANtastic.git ~/cantastic

# Step 3. Make the shell script executable
chmod +x ~/cantastic/Cantastic.sh
```

## 🔁 Starting CANtastic!

To run CANtastic!, run the following line in the terminal:

```shell
~/cantastic/Cantastic.sh
```

## 🗑️ Uninstalling CANtastic!

To uninstall CANtastic!, run the following line in the terminal:

```shell
rm -rf ~/cantastic
```
 ## 💲 Support CANtastic!

 If you like what I do and want to show your support, feel free to donate:

 - Cash App: $JohnMallick1997
 - Coinbase: john.r.mallick@gmail.com
 - Venmo: @John-Mallick-1

Every little bit helps keep CANtastic! alive and growing!
Happy Printing! 👋

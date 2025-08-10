#!/bin/bash

# CANtastic was written by John Mallick for the love of 3D printing
# This program is inspired by the easy-to-use GUI of KIAUH.
# CANtastic is open source but please give credit for any derivative work!
# 8-10-2025

########################################
# Variables
########################################

CONFIG_FILE="/etc/network/interfaces.d/can0"
SCRIPT_NAME="Cantastic.sh"
SCRIPT_VERSION="1.0.1"
SCRIPT_URL="https://raw.githubusercontent.com/YourUsername/YourRepo/main/Cantastic.sh"
VERSION_URL="https://raw.githubusercontent.com/YourUsername/YourRepo/main/version.txt"

########################################
# CAN0 Functions
########################################

# Function to check if can0 is up
check_can0() {
    ip link show can0 &>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ can0 is detected."
    else
        echo "❌ can0 not detected. Make sure your CAN adapter is connected."
    fi
}

# Function to display current bitrate and txqueuelen
show_current_settings() {
    if ip link show can0 &>/dev/null; then
        ip -details link show can0 | grep -E 'bitrate|txqueuelen'
    else
        echo "❌ can0 interface not found or not activated."
    fi
}

# Function to restart CAN Bus
restart_canbus() {
    clear
    echo ""
    echo "🔄 Restarting CAN interface..."
    sudo ifdown can0 2>/dev/null
    sudo ifup can0
    echo "✅ Interface restarted."
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Configuration menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_configuration
}

# Function to search for Klipper UUIDs
uuid_search() {
    clear
    echo ""
    echo "====== 🔍 UUID Search 🔍 ======"
    echo ""

    # Run Klipper's CANbus query to find MCU UUIDs
    UUIDS=$(python3 ~/klipper/scripts/canbus_query.py can0 2>/dev/null | \
        grep -Eo '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b' | \
        sort -u)

    # If loop to decide what to do if UUIDs are found or not found
    if [ -z "$UUIDS" ]; then
        echo "❌ No Klipper MCU UUIDs found on CAN0."
        echo "Ensure your CAN adapter is connected and MCUs are powered on."
    else
        COUNT=$(echo "$UUIDS" | wc -l)
        echo "✅ $COUNT MCU UUID(s) found on CAN0:"
        echo ""
        echo "$UUIDS" | nl -w2 -s". "
    fi

    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Configuration menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_configuration
}

########################################
# CAN-Utils
########################################

# Function to install can-utils
install_canutils() {
    if dpkg -s can-utils &>/dev/null; then
        echo "❌ CAN Bus Utilites are already installed!"
    else
        echo "📦 Installing can-utils..."
        sudo apt-get update
        if sudo apt-get install -y can-utils; then
            echo "✅ CAN Bus Utilities installed successfully!"
        else
            echo "❌ Failed to install CAN Bus Utilities!"
            echo "Check your network settings or system permissions."
        fi
    fi
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Utilities menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_utilities
}

# Function to uninstall can-utils
remove_canutils() {
    clear
    if ! dpkg -s can-utils &>/dev/null; then
        echo "❌ CAN Bus Utilites are not installed!"
    else
        echo "🗑 Removing can-utils..."
        if sudo apt-get remove -y can-utils; then
            echo "✅ CAN Bus Utilities removed successfully!"
        else
            echo "❌ Failed to remove CAN Bus Utilities!"
            echo "Check your system permissions."
        fi
    fi
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Utilities menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_utilities
}

# Function to view CAN0 traffic
candump_interface() {
    clear
    if ! dpkg -s can-utils &>/dev/null; then
        echo "❌ CAN Bus Utilites are not installed!"
    else
        echo ""
        echo "====== 📡 Listening on CAN Interface 📡 ======"
        echo ""
        echo "Press Ctrl+C to stop capturing CAN traffic."
        echo ""
        read -p "Enter the CAN interface (default: can0): " INTERFACE
        echo "Press Ctrl+C to stop."
        INTERFACE=${INTERFACE:-can0}
        sleep 1
        candump "$INTERFACE"
    fi
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Utilities menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_utilities
}

# Function to view CAN0 interface
check_can_status() {
    clear
    if ! dpkg -s can-utils &>/dev/null; then
        echo "❌ CAN Bus Utilites are not installed!"
    else
        echo ""
        echo "====== 🔍 CAN Interface Status 🔍 ======"
        echo ""
        read -p "Enter the CAN interface to inspect (default: can0): " INTERFACE
        INTERFACE=${INTERFACE:-can0}
        echo ""
        ip -details link show "$INTERFACE"
    fi
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Utilities menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_utilities
}

# Function to verify CAN-Utils installation
verify_canutils_installed() {
    if command -v cansend >/dev/null 2>&1; then
        echo "✅ CAN Bus Utilities are installed!"
    else
        echo "❌ CAN Bus Utilites are not installed!"
    fi
}

# Function to send a test frame
send_test_frame() {
    clear
    if ! dpkg -s can-utils &>/dev/null; then
        echo "❌ CAN Bus Utilites are not installed!"
    else
        echo ""
        echo "====== 📤 Send Test CAN Frame 📤 ======"
        echo ""
        read -p "Enter CAN interface (default: can0): " INTERFACE
        INTERFACE=${INTERFACE:-can0}
        read -p "Enter CAN ID and data (e.g., 123#DEADBEEF): " FRAME
        echo ""
        echo "Sending frame to $INTERFACE..."
        cansend "$INTERFACE" "$FRAME"
        echo "✅ Frame sent."
    fi
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Utilities menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_utilities
}

########################################
# CAN0 Configuration Functions
########################################

# Function to configure CAN interface
configure_canbus() {
    clear
    echo ""
    echo "🛠️ Starting CAN0 Configuration"

    # Select Bitrate
    while true; do
        echo ""
        echo "====== 🚙 Bitrate Configuration 🚙 ======"
        echo ""
        echo "Select the bitrate you want CAN0 to use. Option 3 is recommended by Klipper."
        echo "A slower bitrate will improve connection reliability but will cause issues with accelerometers!"
        echo "IMPORTANT: the selected bitrate MUST match the bitrate flashed to your mcu!!!"
        echo ""
        echo "1. 250K   (250000)"
        echo "2. 500K   (500000)"
        echo "3. 1M     (1000000)"
        echo ""
        echo "=========================================="
        echo ""
        read -p "Choose an option [1-3]: " CHOICE

        case "$CHOICE" in
            1) BITRATE=250000; break ;;
            2) BITRATE=500000; break ;;
            3) BITRATE=1000000; break ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done

    # Select Transmission Queue Length
    while true; do
        echo ""
        echo "====== 🚙 Transmission Queue Length Configuration 🚙 ======"
        echo ""
        echo "Select the transmission queue length you want CAN0 to use. Option 1 is recommended by Klipper"
        echo "A larger transmission queue length can run more mcus but may cause more communication crashes!"
        echo ""
        echo "1. 128"
        echo "2. 256"
        echo "3. 512"
        echo "4. 1024"
        echo ""
        echo "============================================================"
        echo ""
        read -p "Choose an option [1-4]: " CHOICE

        case "$CHOICE" in
            1) TXQ=128; break ;;
            2) TXQ=256; break ;;
            3) TXQ=512; break ;;
            4) TXQ=1024; break ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done

    # Create or update CAN interface file
    if [ -f "$CONFIG_FILE" ]; then
        sudo sed -i "s/^ *bitrate .*/    bitrate $BITRATE/" "$CONFIG_FILE"
        sudo sed -i "s|^ *up ip link set.*txqueuelen.*|    up ip link set \$IFACE txqueuelen $TXQ|" "$CONFIG_FILE"
        echo "🔄 Updated existing config at $CONFIG_FILE"
    else
        sudo tee "$CONFIG_FILE" > /dev/null <<EOF
allow-hotplug can0
iface can0 can static
    bitrate $BITRATE
    up ip link set \$IFACE txqueuelen $TXQ
EOF
        echo "🆕 Created new config at $CONFIG_FILE"
    fi

    # Validate Config values
    BITRATE_SET=$(grep -E "^[[:space:]]*bitrate" "$CONFIG_FILE" | awk '{print $2}')
    TXQ_SET=$(grep -E "txqueuelen" "$CONFIG_FILE" | awk '{print $NF}')
    if [[ "$BITRATE_SET" == "$BITRATE" && "$TXQ_SET" == "$TXQ" ]]; then
        echo "✅ Validation successful: bitrate=$BITRATE_SET, txqueuelen=$TXQ_SET"
    else
        echo "❌ Validation failed!"
        echo "   Expected: bitrate=$BITRATE, txqueuelen=$TXQ"
        echo "   Found:    bitrate=$BITRATE_SET, txqueuelen=$TXQ_SET"
        echo "   Please check $CONFIG_FILE manually."
    fi

    # Restart the interface
    echo "🔄 Restarting CAN interface..."
    sudo ifdown can0 2>/dev/null
    sudo ifup can0
    echo "✅ Interface restarted."

    # Finishing touches
    echo ""
    check_can0
    show_current_settings
    echo "HINT: if the CAN Bus network fails to show up make sure that your CAN adapter is connected!"
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Configuration menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_configuration
}

# Function to delete the config
delete_canbus() {
    clear
    echo ""
    echo "🗑️ Deleting CAN Bus Configuration"
    echo ""

    # If the can0 config file is found
    if [ -f "$CONFIG_FILE" ]; then
        read -p "Are you sure you want to delete the CAN config file? (Y/N): " CONFIRM
        if [ -f "$CONFIG_FILE" ]; then
            sudo rm -- "$CONFIG_FILE"
            echo "✅ Deleted $CONFIG_FILE"
        else
            echo "❌ No config file found at $CONFIG_FILE"
        fi
    else
        echo "⚠️ No config file found to delete."
    fi
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the CAN Bus Configuration menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    canbus_configuration
}

# Function to check GitHub for updates
check_for_updates() {

    # If not able to check for update
    LATEST_VERSION=$(curl -s "$VERSION_URL")
    if [ -z "$LATEST_VERSION" ]; then
        echo "⚠️ Could not check for updates."
        return
    fi

    # If a new version is available to update to
    if [ "$SCRIPT_VERSION" != "$LATEST_VERSION" ]; then
        echo "🆕 A new version ($LATEST_VERSION) is available! You have $SCRIPT_VERSION."
        read -p "Do you want to update now? (Y/N): " choice
        case "$choice" in
            y|Y)

                # Download latest version from GitHub
                echo "⬇️ Downloading latest version..."
                curl -s -o "$SCRIPT_NAME.tmp" "$SCRIPT_URL"

                # If latest version is successfully downloaded
                if [ $? -eq 0 ] && [ -s "$SCRIPT_NAME.tmp" ]; then
                    mv "$SCRIPT_NAME.tmp" "$SCRIPT_NAME"
                    chmod +x "$SCRIPT_NAME"
                    echo "✅ CANtastic successfully updated to version $LATEST_VERSION!"
                    echo "Restarting CANtastic..."
                    exec bash "$SCRIPT_NAME"
                else
                    echo "❌ Update failed. Keeping current version."
                    rm -f "$SCRIPT_NAME.tmp"
                fi
                ;;
            *)
                # If new version is skipped
                echo "ℹ️ Update skipped."
                ;;
        esac
    else
        echo "✅ You are running the latest version ($SCRIPT_VERSION)."
    fi
}

########################################
# Program Menus
########################################

# Main menu
main_menu() {
    while true; do
        clear
        echo ""
        echo "====== 🚙 CANtastic! Main Menu 🚙 ======"
        echo ""
        check_for_updates
        echo ""
        echo "1. CAN Bus Configuration"
        echo "2. CAN Bus Utilities"
        echo "3. Troubleshooting"
        echo "4. Exit CANtastic!"
        echo ""
        echo "========================================="
        echo ""
        read -p "Choose an option [1-4]: " CHOICE

        case "$CHOICE" in
            1) canbus_configuration ;;
            2) canbus_utilities ;;
            3) help_menu ;;
            4) exit_cantastic ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done
}

# CAN Bus Configuration menu
canbus_configuration() {
    while true; do
        clear
        echo ""
        echo "====== 🔧 CAN Bus Configuration 🔧 ======"
        echo ""
        check_can0
        show_current_settings
        echo ""
        echo "1. Configure CAN Bus Configuration"
        echo "2. Delete CAN Bus Configuration"
        echo "3. Restart CAN Bus"
        echo "4. UUID Search"
        echo "5. Back"
        echo ""
        echo "=========================================="
        echo ""
        read -p "Choose an option [1-5]: " CHOICE

        case "$CHOICE" in
            1) configure_canbus ;;
            2) delete_canbus ;;
            3) restart_canbus ;;
            4) uuid_search ;;
            5) main_menu ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done
}

# CAN Bus Utilities menu
canbus_utilities() {
    while true; do
        clear
        echo ""
        echo "====== 🛠️ CAN Bus Utilities 🛠️ ======"
        echo ""
        verify_canutils_installed
        echo ""
        echo "1. Install CAN Bus Utilities"
        echo "2. Uninstall CAN Bus Utilities"
        echo "3. View CAN Bus Traffic"
        echo "4. View Interface Status"
        echo "5. Send a Test Frame"
        echo "6. Back"
        echo ""
        echo "======================================"
        echo ""
        read -p "Choose an option [1-6]: " CHOICE

        case "$CHOICE" in
            1) install_canutils ;;
            2) remove_canutils ;;
            3) candump_interface ;;
            4) check_can_status ;;
            5) send_test_frame ;;
            6) main_menu ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done
}

# Help menu
help_menu() {
    while true; do
        clear
        echo ""
        echo "====== 🧩 Troubleshooting 🧩 ======"
        echo ""
        echo "1. CAN Bus Explained"
        echo "2. CAN Bus Wiring Explained"
        echo "3. Setting up CAN Bus with Klipper"
        echo "4. Troubleshooting Common CAN Bus Issues"
        echo "5. About CANtastic!"
        echo "6. Main Menu"
        echo ""
        echo "===================================="
        echo ""
        read -p "Choose an option [1-6]: " CHOICE

        case "$CHOICE" in
            1) canbus_explained ;;
            2) canbus_wiring ;;
            3) klipper_canbus ;;
            4) troubleshooting_canbus ;;
            5) about_cantastic ;;
            6) main_menu ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done
}

# CAN Bus Explained menu
canbus_explained() {
    clear
    echo ""
    echo "====== 📖 CAN Bus Explained 📖 ======"
    echo ""
    echo "CAN (Controller Area Network) is a communication system"
    echo "originally developed for vehicles, allowing microcontrollers"
    echo "and devices to communicate with each other over a simple"
    echo "two-wire twisted pair network. In 3D printing, CAN is used"
    echo "to connect boards like toolheads and sensors using fewer wires"
    echo "and enabling high-speed, reliable data transfer."
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the Troubleshooting menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    help_menu
}

# CAN Bus Wiring menu
canbus_wiring() {
    clear
    echo ""
    echo "====== 🟨 CAN Bus Wiring Explained 🟩 ======"
    echo ""
    echo "CAN Bus uses a two-wire system: CAN High (CANH) and CAN Low (CANL)."
    echo "These wires must be twisted together to reduce interference."
    echo "Devices are connected in a straight line (not a star topology)."
    echo "The two ends of the CAN bus must be terminated with 120Ω resistors."
    echo ""
    echo "Example wiring:"
    echo "  Pi/U2C ---> Toolhead board ---> Optional second device"
    echo "  [120Ω]----CANH/CANL----[120Ω]"
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the Troubleshooting menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    help_menu
}

# Klipper CAN Bus menu
klipper_canbus() {
    clear
    echo ""
    echo "====== 🏗️ Setting up CAN Bus with Klipper 🏗️ ======"
    echo ""
    echo "To use CAN Bus in Klipper, please connect a CAN-enabled board"
    echo "like an EBB36 or SB2040 to your host (e.g., Raspberry Pi) using"
    echo "a CAN adapter or a mainboard with built-in CAN support."
    echo ""
    echo "Steps overview:"
    echo "1. Flash the toolhead board with Klipper firmware configured for CAN."
    echo "2. Set up the host CAN interface (usually can0) with correct bitrate."
    echo "3. Use Klipper's canbus_query.py script to find the board's UUID."
    echo "4. Add a new [mcu] section in printer.cfg using that UUID."
    echo ""
    echo "This enables reliable two-wire communication between Klipper"
    echo "and your toolhead or other CAN-connected devices."
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the Troubleshooting menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    help_menu
}

# Troubleshooting CAN Bus menu
troubleshooting_canbus() {
    clear
    echo ""
    echo "====== 🚑 Troubleshooting Common CAN Bus Issues 🚑 ======"
    echo ""
    echo "Having issues getting Klipper to recognize your CAN-connected board?"
    echo "Here are common problems and how to fix them:"
    echo ""
    echo "🔌 Power Issues:"
    echo "  - Ensure the toolhead board is powered (some need external 24V)."
    echo ""
    echo "🔧 Bad or Missing Termination:"
    echo "  - Make sure 120Ω resistors are placed at both ends of the CAN line."
    echo ""
    echo "🛠️ Incorrect Bitrate:"
    echo "  - Host and device must use the same CAN bitrate (e.g., 1000000)."
    echo ""
    echo "🧾 UUID Not Found:"
    echo "  - Run: ~/klipper/scripts/canbus_query.py can0"
    echo "  - If nothing appears, check wiring and power again."
    echo ""
    echo "🧩 Kernel Modules Missing:"
    echo "  - Run: lsmod | grep can_raw"
    echo "  - If missing, install can-utils: sudo apt install can-utils"
    echo ""
    echo "📄 Klipper Config Errors:"
    echo "  - Check printer.cfg for correct [mcu] section with 'canbus_uuid:'."
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the Troubleshooting menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    help_menu
}

# About CANtastic! menu
about_cantastic() {
    clear
    echo ""
    echo "====== 🤷‍♂️ About CANtastic! 🤷‍♀️ ======"
    echo ""
    echo "CANtastic! is a simple shell script toolkit designed to help"
    echo "you install, configure, and troubleshoot Klipper CAN Bus setups"
    echo "with ease. From can-utils to Klipper integration, it's all here!"
    echo ""
    echo "Developed by John Mallick with ❤️ for the 3D printing community."
    echo ""
    echo "💸 Want to show support?"
    echo "   • Cash App: \$JohnMallick1997"
    echo "   • Coinbase (Crypto): john.r.mallick@gmail.com"
    echo "   • Venmo: @John-Mallick-1"
    echo ""
    echo "Every little bit helps keep CANtastic! alive and growing!"
    echo ""
    read -n 1 -s -r -p "Press any key to go back to the Troubleshooting menu..."
    # Flush any buffered keystrokes
    while read -t 0; do read -r; done
    help_menu
}

# Exit CANtastic!
exit_cantastic() {
    clear
    echo "Exiting CANtastic! Happy Printing! 👋"
    exit 0
}

# Run it
main_menu
#!/usr/bin/env bash
set -e
set -o pipefail

# CANtastic was written by John Mallick for the love of 3D printing
# This program is inspired by the easy-to-use GUI of KIAUH.
# CANtastic is open source but please give credit for any derivative work!
# 8-12-2025

########################################
# Global Variables
########################################

ESOTERICAL_CONFIG_FILE="/etc/systemd/network/25-can.network"
ESOTERICAL_SERVICE_FILE="/etc/udev/rules.d/10-can.rules"
GEMINI_CONFIG_FILE="/etc/systemd/network/80-can.network"
GEMINI_SERVICE_FILE="/etc/systemd/system/can-up.service"
LEGACY_CONFIG_FILE="/etc/network/interfaces.d/can0"
RESTART_LEGACY_CAN_BLOCK="No"
SCRIPT_NAME="Cantastic.sh"
SCRIPT_VERSION="2.0.1"
SCRIPT_URL="https://raw.githubusercontent.com/JMallick1997/CANtastic/main/Cantastic.sh"
VERSION_URL="https://raw.githubusercontent.com/JMallick1997/CANtastic/main/version.txt"

########################################
# Detect CAN Bus Method
########################################
detect_can_method() {
    # 1. Create a "matrix" variable representing the presence of each method.
    local method_bits=""

    # 2. Search for CAN Bus files and assign the correct bit to each.

    # Legacy config found
    if [ -f "$LEGACY_CONFIG_FILE" ]; then
        method_bits+="1"
    else
        method_bits+="0"
    fi

    # Esoterical config found
    if [ -f "$ESOTERICAL_CONFIG_FILE" ] || [ -f "$ESOTERICAL_SERVICE_FILE" ]; then
        method_bits+="1"
    else
        method_bits+="0"
    fi

    # Gemini config found
    if [ -f "$GEMINI_CONFIG_FILE" ] || [ -f "$GEMINI_SERVICE_FILE" ]; then
        method_bits+="1"
    else
        method_bits+="0"
    fi

    # 3. Use a case statement to determine the CAN_METHOD based on the bitmask.
    case "$method_bits" in
        "000")
            # No configuration files found.
            CAN_METHOD="Unknown"
            ;;
        "100")
            # Only Legacy files are present.
            CAN_METHOD="Legacy"
            ;;
        "010")
            # Only Esoterical files are present. Check if the method is complete or broken.
            if [ -f "$ESOTERICAL_CONFIG_FILE" ] && [ -f "$ESOTERICAL_SERVICE_FILE" ]; then
                CAN_METHOD="Esoterical"
            else
                CAN_METHOD="Esoterical-Broken"
            fi
            ;;
        "001")
            # Only Gemini files are present. Check if the method is complete or broken.
            if [ -f "$GEMINI_CONFIG_FILE" ] && [ -f "$GEMINI_SERVICE_FILE" ]; then
                CAN_METHOD="Gemini"
            else
                CAN_METHOD="Gemini-Broken"
            fi
            ;;
        *)
            # Any other combination (e.g., "110", "101", "111") means multiple methods exist.
            CAN_METHOD="Multiple"
            ;;
    esac
}

########################################
# CAN Bus Status
########################################
status_can0() {

    # Detect CAN0 method
    detect_can_method

    # Check if can0 exists at all
    if ip link show can0 &>/dev/null; then

        # Check if CAN0 is up
        if ip link show can0 | grep -q "state UP"; then
            echo "✅ CAN0 is up"
            echo "Method: $CAN_METHOD"

        # CAN adapter connected but no CAN setup
        else
            echo "⚠️ Adapter detected but CAN0 is not configured"
            return 1
        fi

    # No CAN adapter detected
    else
        echo "❌ No CAN adapter detected"
        return 1
    fi

    # Determine bitrate and txqueuelen for the chosen method
    case "$CAN_METHOD" in

        # Legacy method
        "Legacy")
            DISPLAY_BITRATE=$(ip -details link show can0 | grep -oP '(?<=bitrate )\d+' || true)
            DISPLAY_TXQ=$(ip link show can0 | awk '/qlen/ {print $NF}' || true)
            echo "Bitrate: $DISPLAY_BITRATE"
            echo "TX Queue Length: $DISPLAY_TXQ"
            ;;

        # Gemini method
        "Gemini")
            DISPLAY_BITRATE=$(grep -oP '(?<=BitRate=)\d+' "$GEMINI_CONFIG_FILE" 2>/dev/null || true)
            DISPLAY_TXQ=$(grep -E "txqueuelen " "$GEMINI_SERVICE_FILE" 2>/dev/null | awk '{print $NF}' || true)
            echo "Bitrate: $DISPLAY_BITRATE"
            echo "TX Queue Length: $DISPLAY_TXQ"
            ;;

        # Esoterical method
        "Esoterical")
            DISPLAY_BITRATE=$(grep -oP '(?<=BitRate=)\d+' "$ESOTERICAL_CONFIG_FILE" 2>/dev/null || true)
            DISPLAY_TXQ=$(grep -E "ATTR{tx_queue_len}=" "$ESOTERICAL_SERVICE_FILE" 2>/dev/null | awk '{print $NF}' || true)
            echo "Bitrate: $DISPLAY_BITRATE"
            echo "TX Queue Length: $DISPLAY_TXQ"
            ;;

        # Esoterical or Gemini is broken
        "Esoterical-Broken"|"Gemini-Broken")
            echo "⚠️ Your SystemD based CAN configuration appears to be broken."
            echo "This is usually caused by a missing .network or .rules/.system file."
            echo "For best results please redo your CAN Bus configuration."
            echo "Unable to grab Bitrate or TX Queue Length."
            ;;

        # Multiple methods detected
        "Multiple")
            echo "⚠️ Multiple CAN methods found — skipping bitrate/txqueuelen detection"
            echo "Multiple CAN Bus methods at the same time will cause communication issues."
            echo "For best results please redo your CAN Bus configuration."
            ;;

        # Multiple or unsupported method
        *)
            echo "⚠️ Unknown CAN method — skipping bitrate/txqueuelen detection"
            echo "Multiple CAN Bus methods at the same time will cause communication issues."
            echo "If no CAN adapter is present you might not have plugged in your adapter yet"
            echo "or your CAN Bus configuration is probably missing."
            ;;
    esac
}

########################################
# Restart CAN Bus
########################################
restart_canbus() {

    # Intro blurbs
    clear
    echo ""
    echo "🔄 Restarting CAN interface..."
    echo ""

    # Use the helper function to determine which method to restart
    detect_can_method

    # Which CAN Bus method gets restarted
    case "$CAN_METHOD" in

        # Restart Legacy
        "Legacy")

            # Legacy config creation block
            if ( $RESTART_LEGACY_CAN_BLOCK = "Yes" ); then
                echo "❌ You cannot restart CAN Bus after making a new Legacy config."
                echo "Doing so may cause your system to crash."
                echo "Restart aborted."
                sleep 3
                return 1
            fi

            # Bring down the interface if it's already up
            sudo ifdown can0 2>/dev/null || true
            sleep 3

            # Bring it up
            if ! ( sudo ifup can0 ); then
                echo "❌ Failed to bring up can0. Device might be busy."
                echo "   Try unplugging/replugging your CAN adapter."
                sleep 3
                return 1
            fi

            # Confirmation blurbs
            echo "✅ Legacy CAN Bus successfully restarted!"
            ;;

        # Restart Esoterical & Gemini
        "Esoterical"|"Gemini")

            # Restart SystemD
            if ! sudo systemctl restart systemd-networkd; then
                echo "❌ Failed to restart systemd-networkd."
                echo "   Please check your systemd configuration."
                sleep 3
                return 1
            fi

            # Confirmation blurbs
            echo "✅ Esoteric/Gemini CAN Bus successfully restarted!"
            ;;

        # Restart multiple at same time
        "Multiple")
            echo "⚠️ Restart attempted, but your configuration is conflicting."
            echo "Multiple methods detected. Please resolve this for stable operation."

            # Bring down the interface if it's already up
            sudo ifdown can0 2>/dev/null || true
            sleep 3

            # Bring it up
            if ! ( sudo ifup can0 ); then
                echo "❌ Failed to bring up can0. Device might be busy."
                echo "   Try unplugging/replugging your CAN adapter."
                sleep 3
                return 1
            fi

            # Restart SystemD
            if ! sudo systemctl restart systemd-networkd; then
                echo "❌ Failed to restart systemd-networkd."
                echo "   Please check your systemd configuration."
                sleep 3
                return 1
            fi
            ;;

        # Restart broken Esoterical & Gemini
        "Esoterical-Broken"|"Gemini-Broken")
            echo "⚠️ Your CAN Bus interface restarted, but your configuration appears to be broken."
            echo "It is highly advised to redo your CAN Bus configuration."

            # Restart SystemD
            if ! sudo systemctl restart systemd-networkd; then
                echo "❌ Failed to restart systemd-networkd."
                echo "   Please check your systemd configuration."
                sleep 3
                return 1
            fi
            ;;

        # Restart unknown
        "Unknown")
            if ip link show can0 &>/dev/null; then
                echo "❌ CAN Bus restart failed. Your current CAN Bus method is not supported."
                echo "CANtastic! supports Esoterical, Gemini, & Legacy methods."
            else
                echo "❌ CAN Bus is not detected or configured properly."
            fi
            ;;

        # Error catch
        *)
            clear
            echo ""
            echo "☠️ If you're reading this something is broken & you need to open a support ticket. ☠️"
            echo ""
            echo "GitHub: https://github.com/JMallick1997/CANtastic/tree/main"
            echo ""
            echo "Error code: CANBUS_RESTART_FAILURE"
            sleep 3
            finishing_blurbs
            canbus_configuration_menu
            break
            ;;
    esac

    # Finishing blurbs
    finishing_blurbs
    canbus_configuration_menu
}

########################################
# UUID Search
########################################
uuid_search() {

    # Intro blurbs
    clear
    echo ""
    echo "======================== 🔍 UUID Search 🔍 ========================"
    echo ""

    # Klipper UUID script local variable
    local KLIPPER_UUID_SCRIPT=~/klipper/scripts/canbus_query.py

    # Klipper not installed
    if [ ! -f "$KLIPPER_UUID_SCRIPT" ]; then
        echo "❌ Klipper canbus_query.py script not found at $KLIPPER_UUID_SCRIPT"
        echo "Please ensure Klipper is installed in the default location."
        finishing_blurbs
        canbus_configuration_menu
        return
    fi

    # Run Klipper's CANbus query (ignore errors, collect output safely)
    local RAW_OUTPUT
    RAW_OUTPUT=$(python3 "$KLIPPER_UUID_SCRIPT" can0 2>/dev/null || true)

    # Extract UUIDs safely; suppress grep failure under set -e
    UUIDS=$(echo "$RAW_OUTPUT" | grep -Eo '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b' || true)
    UUIDS=$(echo "$UUIDS" | sort -u)

    # No UUIDs found
    if [ -z "$UUIDS" ]; then
        echo "❌ No Klipper MCU UUIDs found on CAN0."
        echo "Ensure your CAN adapter is connected and MCUs are powered on."

    # UUIDs found
    else
        COUNT=$(echo "$UUIDS" | wc -l)
        echo "✅ $COUNT MCU UUID(s) found on CAN0:"
        echo ""
        echo "$UUIDS" | nl -w2 -s". "
    fi

    # Finishing blurbs
    finishing_blurbs
    canbus_configuration_menu
}

########################################
# View CAN Bus Files
########################################
canbus_file_viewer() {

    # CAN Bus file viewer menu
    while true ; do
        clear
        detect_can_method
        echo ""
        echo "======================== 📄 CAN Bus File Viewer 📄 ========================"
        echo ""
        echo "Here you can view and modify the files associated with your CAN Bus setup."
        echo "Altering these files may result in communication errors if done improperly!"
        echo "Only alter these files if you know what you're doing."
        echo ""
        echo "1. Legacy Files"
        echo "2. Esoterical Files"
        echo "3. Gemini Files"
        echo "4. Back"
        echo ""
        read -p "Choose an option [1-4]: " FILE_CHOICE
        case "$FILE_CHOICE" in
            1) view_legacy_files ;;
            2) view_esoterical_files ;;
            3) view_gemini_files ;;
            4) canbus_configuration_menu ;;
            *) echo "❌ Invalid option. Try again." 
               sleep 3 ;;
        esac
    done
}

# Function to view Legacy files
view_legacy_files() {

    # If Legacy file exists
    if [ -f "$LEGACY_CONFIG_FILE" ]; then

        # Legacy file viewer menu
        while true; do
            clear
            echo ""
            echo "======================== 📄 Legacy File Viewer 📄 ========================"
            echo ""
            read -p "Do you want to view the Legacy configuration file? (Y/N): " view_choice
            view_choice=${view_choice,,}
            case "$view_choice" in
                y)
                    sudo nano "$LEGACY_CONFIG_FILE"
                    while read -t 0; do read -r; done
                    view_legacy_files
                    break
                    ;;
                n)
                    while read -t 0; do read -r; done
                    canbus_file_viewer
                    break
                    ;;
                *) echo "❌ Invalid option. Try again."
                   sleep 3
                   while read -t 0; do read -r; done ;;
            esac
        done

    # No Legacy file exists
    else
        echo "❌ No Legacy file found."
        sleep 3
        canbus_file_viewer
    fi
}

# Function to view Esoterical files
view_esoterical_files() {

    # View Esoterical files menu
    while true; do
        clear
        echo ""
        echo "======================== 📄 Esoterical File Viewer 📄 ========================"
        echo ""
        read -p "Which file do you want to view? (Config, Service, or Back): " view_choice
        view_choice=${view_choice,,}
        case "$view_choice" in
            config|c)
                if [ -f "$ESOTERICAL_CONFIG_FILE" ]; then
                    sudo nano "$ESOTERICAL_CONFIG_FILE"
                else
                    echo "❌ No configuration file to view."
                    sleep 3
                fi
                while read -t 0; do read -r; done
                view_esoterical_files
                break
                ;;
            service|s)
                if [ -f "$ESOTERICAL_SERVICE_FILE" ]; then
                    sudo nano "$ESOTERICAL_SERVICE_FILE"
                else
                    echo "❌ No service file to view."
                    sleep 3
                fi
                while read -t 0; do read -r; done
                view_esoterical_files
                break
                ;;
            back|b)
                while read -t 0; do read -r; done
                canbus_file_viewer
                break
                ;;
            *) echo "❌ Invalid option. Try again."
                sleep 3 ;;
        esac
    done
}

# Function to view Gemini files
view_gemini_files() {

    # View Gemini files menu
    while true; do
        clear
        echo ""
        echo "======================== 📄 Gemini File Viewer 📄 ========================"
        echo ""
        read -p "Which file do you want to view? (Config, Service, or Back): " view_choice
        view_choice=${view_choice,,}
        case "$view_choice" in
            config|c)
                if [ -f "$GEMINI_CONFIG_FILE" ]; then
                    sudo nano "$GEMINI_CONFIG_FILE"
                else
                    echo "❌ No configuration file to view."
                    sleep 3
                fi
                while read -t 0; do read -r; done
                view_gemini_files
                break
                ;;
            service|s)
                if [ -f "$GEMINI_SERVICE_FILE" ]; then
                    sudo nano "$GEMINI_SERVICE_FILE"
                else
                    echo "❌ No service file to view."
                    sleep 3
                fi
                while read -t 0; do read -r; done
                view_gemini_files
                break
                ;;
            back|b)
                while read -t 0; do read -r; done
                canbus_file_viewer
                break
                ;;
            *) echo "❌ Invalid option. Try again."
               sleep 3 ;;
        esac
    done
}

########################################
# Install CAN Bus Utilities
########################################
install_canutils() {
    clear

    # Can-utils already installed
    if dpkg -s can-utils &>/dev/null; then
        echo "❌ CAN Bus Utilites are already installed!"

    # Install can-utils
    else
        echo "📦 Installing CAN Bus Utilities..."
        sudo apt-get update

        # Install successful
        if sudo apt-get install -y can-utils; then
            echo "✅ CAN Bus Utilities installed successfully!"

        # Install failed
        else
            echo "❌ Failed to install CAN Bus Utilities!"
            echo "Check your network settings or system permissions."
        fi
    fi

    # Finishing blurbs
    finishing_blurbs
    canbus_utilities
}

########################################
# Uninstall CAN Bus Utilities
########################################
remove_canutils() {
    clear

    # Can-utils not installed
    if ! dpkg -s can-utils &>/dev/null; then
        echo "❌ CAN Bus Utilites are not installed!"

    # Uninstall can-utils
    else
        echo "🗑 Removing CAN Bus Utilities..."

        # Uninstall successful
        if sudo apt-get remove -y can-utils; then
            echo "✅ CAN Bus Utilities removed successfully!"

        # Uninstall failed
        else
            echo "❌ Failed to remove CAN Bus Utilities!"
            echo "Check your system permissions."
        fi
    fi

    # Finishing blurbs
    finishing_blurbs
    canbus_utilities
}

########################################
# View CAN Bus Traffic
########################################
candump_interface() {
    clear

    # View CAN0 traffic
    if command -v cansend >/dev/null 2>&1; then
        echo ""
        echo "======================== 📡 Listening on CAN Interface 📡 ========================"
        echo ""
        echo "Press Ctrl+C to stop capturing CAN traffic."
        echo ""
        read -p "Enter the CAN interface (default: can0): " INTERFACE
        echo "Press Ctrl+C to stop."
        INTERFACE=${INTERFACE:-can0}
        sleep 1
        candump "$INTERFACE"

    # Can-utils not installed
    else
        echo "❌ CAN Bus Utilites are not installed!"
    fi

    # Finishing blurbs
    finishing_blurbs
    canbus_utilities
}

########################################
# CAN Interface Status
########################################
check_can_status() {
    clear

    # CAN interface status
    if command -v cansend >/dev/null 2>&1; then
        echo ""
        echo "======================== 🔍 CAN Interface Status 🔍 ========================"
        echo ""
        read -p "Enter the CAN interface to inspect (default: can0): " INTERFACE
        INTERFACE=${INTERFACE:-can0}
        echo ""
        ip -details link show "$INTERFACE"

    # Can-utils not installed
    else
        echo "❌ CAN Bus Utilites are not installed!"
    fi

    # Finishing blurbs
    finishing_blurbs
    canbus_utilities
}

########################################
# Verify CAN Bus Utilities
########################################
verify_canutils_installed() {

    # Can-utils installed
    if command -v cansend >/dev/null 2>&1; then
        echo "✅ CAN Bus Utilities are installed!"

    # Can-utils not installed
    else
        echo "❌ CAN Bus Utilites are not installed!"
    fi
}

########################################
# Test Frame
########################################
send_test_frame() {
    clear

    # Check if can-utils are installed
    if ! dpkg -s can-utils &>/dev/null; then
        echo "❌ CAN Bus Utilites are not installed!"

    # Send test frame
    else
        echo ""
        echo "======================== 📤 Send Test CAN Frame 📤 ========================"
        echo ""
        read -p "Enter CAN interface (default: can0): " INTERFACE
        INTERFACE=${INTERFACE:-can0}
        read -p "Enter CAN ID and data (e.g., 123#DEADBEEF): " FRAME
        echo ""
        echo "Sending frame to $INTERFACE..."
        cansend "$INTERFACE" "$FRAME"
        echo "✅ Frame sent."
    fi

    # Finishing blurbs
    finishing_blurbs
    canbus_utilities
}

########################################
# CAN Bus Configuration
########################################
configure_canbus() {

    # Intro blurbs
    clear
    echo ""
    echo "🛠️ Starting CAN Bus Configuration..."
    sleep 3

    # Configuration selection menu
    while true; do
        clear
        echo ""
        echo "======================== 🌐 CAN Configuration Method 🌐 ========================"
        echo ""
        echo "There are multiple different ways of setting up CAN Bus with Klipper:"
        echo ""
        echo "Esoterical uses systemd and is the modern method for newer Debian versions."
        echo "Gemini is similar to Esoterical but has different configuration and service files."
        echo "Legacy uses ifupdown (/etc/network/interfaces.d)."
        echo ""
        echo "Choose which CAN Bus configuration method you want to use."
        echo ""
        echo "1. Esoterical"
        echo "2. Gemini"
        echo "3. Legacy"
        echo ""
        read -p "Choose an option [1-3]: " METHOD_CHOICE
        case "$METHOD_CHOICE" in
            1)
                METHOD_NAME="Esoterical"
                DEPENDENCIES="systemd"
                break
                ;;
            2)
                METHOD_NAME="Gemini"
                DEPENDENCIES="systemd"
                break
                ;;
            3)
                METHOD_NAME="Legacy"
                DEPENDENCIES="ifupdown net-tools"
                break
                ;;
            *)
                echo "❌ Invalid option. Try again."
                sleep 3
                ;;
        esac
    done

    # Bitrate selection menu
    while true; do
        clear
        echo ""
        echo "======================== 🚙 Bitrate Configuration 🚙 ========================"
        echo ""
        echo "Select the bitrate for the CAN Bus. Option 8 is recommended by Klipper."
        echo "A slower bitrate improves reliability but breaks accelerometers."
        echo "The bitrate selected must match the bitrate flashed to your MCU!"
        echo ""
        echo "1. 125K   (125000)"
        echo "2. 250K   (250000)"
        echo "3. 375K   (375000)"
        echo "4. 500K   (500000)"
        echo "5. 625K   (625000)"
        echo "6. 750K   (750000)"
        echo "7. 875K   (875000)"
        echo "8. 1M     (1000000)"
        echo ""
        read -p "Choose an option [1-8]: " BITRATE_CHOICE
        case "$BITRATE_CHOICE" in
            1) BITRATE=125000; break ;;
            2) BITRATE=250000; break ;;
            3) BITRATE=375000; break ;;
            4) BITRATE=500000; break ;;
            5) BITRATE=625000; break ;;
            6) BITRATE=750000; break ;;
            7) BITRATE=875000; break ;;
            8) BITRATE=1000000; break ;;
            *) echo "❌ Invalid option. Try again."
               sleep 3
               ;;
        esac
    done

    # Transmission queue length selection menu
    while true; do
        clear
        echo ""
        echo "======================== 🚙 Transmission Queue Length Configuration 🚙 ========================"
        echo ""
        echo "Select the transmission queue length you want CAN Bus to use. Option 1 is recommended by Klipper"
        echo "A larger transmission queue length can run more MCUs but may cause more communication crashes!"
        echo ""
        echo "1. 128"
        echo "2. 256"
        echo "3. 384"
        echo "4. 512"
        echo "5. 640"
        echo "6. 768"
        echo "7. 896"
        echo "8. 1024"
        echo ""
        read -p "Choose an option [1-8]: " TXQ_CHOICE
        case "$TXQ_CHOICE" in
            1) TXQ=128; break ;;
            2) TXQ=256; break ;;
            3) TXQ=384; break ;;
            4) TXQ=512; break ;;
            5) TXQ=640; break ;;
            6) TXQ=768; break ;;
            7) TXQ=896; break ;;
            8) TXQ=1024; break ;;
            *) echo "❌ Invalid option. Try again."
               sleep 3
               ;;
        esac
    done

    # Confirmation menu
    while true; do
        clear
        echo ""
        echo "========================== ⚠️ Alert! ⚠️ =========================="
        echo ""
        echo "You are preparing to set up CAN Bus using the following parameters:"
        echo ""
        echo "Method = $METHOD_NAME"
        echo "Bitrate = $BITRATE"
        echo "Transmision Queue Length = $TXQ"
        echo ""
        echo "This will create the following files on your machine:"
        echo ""
        case "$METHOD_NAME" in

            # Legacy selected
            "Legacy")
                echo "$LEGACY_CONFIG_FILE"
                ;;

            # Esoterical selected
            "Esoterical")
                echo "$ESOTERICAL_CONFIG_FILE"
                echo "$ESOTERICAL_SERVICE_FILE"
                ;;

            # Gemini selected
            "Gemini")
                echo "$GEMINI_CONFIG_FILE"
                echo "$GEMINI_SERVICE_FILE"
                ;;

            # Error catch
            *)
                clear
                echo ""
                echo "☠️ If you're reading this something is broken & you need to open a support ticket. ☠️"
                echo ""
                echo "GitHub: https://github.com/JMallick1997/CANtastic/tree/main"
                echo ""
                echo "Error code: CONFIGURE_CANBUS_CONFIRMATION_FAILURE"
                sleep 3
                finishing_blurbs
                canbus_configuration_menu
                break
                ;;
        esac

        # Confirmation menu continued
        echo ""
        echo "The following dependencies will be installed by default:"
        echo ""
        echo "$DEPENDENCIES"
        echo ""
        echo "CAN Bus Utilities will also be installed by default."
        echo ""
        echo "Any current CAN Bus parameters currently utilized by your system will be erased!"
        echo "If you are switching from one method to another your old method's files will also be erased!"
        echo "Make sure that your CAN Bus parameters set here match your parameters that you flashed to your Klipper MCUs!"
        echo ""
        echo "WARNING: Creating a new CAN Bus configuration during an active print job will cause Klipper to shutdown!"
        echo ""
        read -p "Do you wish to proceed? (Y/N): " PROCEED_CHOICE
        PROCEED_CHOICE=${PROCEED_CHOICE,,}
        case "$PROCEED_CHOICE" in

            # Proceed with configuration
            y)
                echo ""
                echo "Creating CAN Bus configuration:"
                break
                ;;

            # Cancel configuration
            n)
                echo ""
                echo "CAN Bus Configuration Aborted."
                echo ""
                sleep 3
                finishing_blurbs
                canbus_configuration_menu
                break
                ;;

            # Invalid option
            *)
                echo "❌ Invalid option. Try again."
                sleep 3
                ;;
        esac
    done

    # Install dependencies
    clear
    echo ""
    echo "📦 Installing dependencies for $METHOD_NAME method..."
    sudo apt update && sudo apt install -y can-utils ${DEPENDENCIES:-}

    # Delete previous config files if found
    for FILE in "$ESOTERICAL_CONFIG_FILE" "$ESOTERICAL_SERVICE_FILE" "$LEGACY_CONFIG_FILE" "$GEMINI_CONFIG_FILE" "$GEMINI_SERVICE_FILE"; do
        if [ -f "$FILE" ]; then
            printf "🗑️ Removing: %s\n" "$FILE"
            sudo rm "$FILE"
        fi
    done

    # Create correct CAN Bus method files
    case $METHOD_NAME in

        # Legacy --------------------------------------------------------------------------------------------------------------------------------------------------------
        "Legacy")

            # Create Legacy config file
            sudo tee "$LEGACY_CONFIG_FILE" > /dev/null <<EOF
allow-hotplug can0
iface can0 can static
    bitrate $BITRATE
    up ip link set \$IFACE txqueuelen $TXQ
EOF

            # Validate Legacy config values
            BITRATE_SET=$(grep -E "^[[:space:]]*bitrate" "$LEGACY_CONFIG_FILE" | awk '{print $2}')
            TXQ_SET=$(grep -E "txqueuelen" "$LEGACY_CONFIG_FILE" | awk '{print $NF}')

            # Legacy validation successful
            if [[ "$BITRATE_SET" == "$BITRATE" && "$TXQ_SET" == "$TXQ" ]]; then
                echo "✅ Legacy validation successful: bitrate=$BITRATE_SET, txqueuelen=$TXQ_SET"

            # Legacy validation failure
            else
                echo "❌ Legacy Validation Failed!"
                echo ""
                echo "   Expected: bitrate=$BITRATE, txqueuelen=$TXQ"
                echo "   Found:    bitrate=$BITRATE_SET, txqueuelen=$TXQ_SET"
                echo ""
                echo "Please check $LEGACY_CONFIG_FILE manually or open a support ticket."
                echo ""
                echo "GitHub: https://github.com/JMallick1997/CANtastic/tree/main"
                echo ""
                echo "Error code: VALIDATE_LEGACY_CONFIG_FAILURE"
                sleep 3
                finishing_blurbs
                canbus_configuration_menu
                break
            fi
            RESTART_LEGACY_CAN_BLOCK="Yes"
            ;;

        # Esoterical ----------------------------------------------------------------------------------------------------------------------------------------------------
        "Esoterical")

            # SystemD setup
            sudo systemctl enable systemd-networkd
            sudo systemctl unmask systemd-networkd
            sudo systemctl disable systemd-networkd-wait-online.service
            sudo systemctl start systemd-networkd

            # Create CAN service file
            sudo tee $ESOTERICAL_SERVICE_FILE > /dev/null <<EOF
SUBSYSTEM=="net", ACTION=="change|add", KERNEL=="can*", ATTR{tx_queue_len}=$TXQ
EOF

            # Create CAN config file
            sudo tee $ESOTERICAL_CONFIG_FILE > /dev/null <<EOF
[Match]
Name=can*

[CAN]
BitRate=$BITRATE
RestartSec=0.1s

[Link]
RequiredForOnline=no
EOF

            # Restart SystemD
            if ! sudo systemctl restart systemd-networkd; then
                echo "❌ Failed to restart systemd-networkd."
                echo "   Please check your systemd configuration."
                sleep 3
                return 1
            fi

            # Configuration confirmation
            echo "✅ Esoterical CAN Bus configuration applied."
            sleep 3

            # Esoterical method validation
            BITRATE_SET="$(grep -oP '(?<=BitRate=)\d+' "$ESOTERICAL_CONFIG_FILE" 2>/dev/null || true)"
            TXQ_SET="$(grep -oP '(?<=ATTR{tx_queue_len}=)\d+' "$ESOTERICAL_SERVICE_FILE" 2>/dev/null || true)"

            # Esoterical validation successful
            if [[ "$BITRATE_SET" == "$BITRATE" && "$TXQ_SET" == "$TXQ" ]]; then
                echo "✅ Esoterical CAN Bus validation successful: bitrate=$BITRATE_SET, txqueuelen=$TXQ_SET"

            # Esoterical validation failure
            else
                echo "❌ Esoterical Validation Failed!"
                echo ""
                echo "   Expected: bitrate=$BITRATE, txqueuelen=$TXQ"
                echo "   Found:    bitrate=$BITRATE_SET, txqueuelen=$TXQ_SET"
                echo ""
                echo "Please check $ESOTERICAL_CONFIG_FILE & $ESOTERICAL_SERVICE_FILE manually or open a support ticket."
                echo ""
                echo "GitHub: https://github.com/JMallick1997/CANtastic/tree/main"
                echo ""
                echo "Error code: VALIDATE_ESOTERICAL_CONFIG_FAILURE"
                sleep 3
                finishing_blurbs
                canbus_configuration_menu
                break
            fi
            ;;

    # Gemini Method -------------------------------------------------------------------------------------------------------------------------------------------------
        "Gemini")

            # SystemD setup
            sudo systemctl enable systemd-networkd
            sudo systemctl unmask systemd-networkd
            sudo systemctl disable systemd-networkd-wait-online.service
            sudo systemctl start systemd-networkd

            # Create CAN service file
            sudo tee $GEMINI_SERVICE_FILE > /dev/null <<EOF
[Service]
Type=oneshot
ExecStart=/usr/sbin/ifconfig can0 txqueuelen $TXQ

[Install]
WantedBy=sys-subsystem-net-devices-can0.device
EOF

            # Create CAN config file
            sudo tee $GEMINI_CONFIG_FILE > /dev/null <<EOF
[Match]
Name=can*

[CAN]
BitRate=$BITRATE
EOF

            # Restart SystemD
            if ! sudo systemctl restart systemd-networkd; then
                echo "❌ Failed to restart systemd-networkd."
                echo "   Please check your systemd configuration."
                sleep 3
                return 1
            fi

            # Configuration confirmation
            echo "✅ Gemini CAN Bus configuration applied."
            sleep 3

            # Gemini method validation
            BITRATE_SET=$(grep -oP '(?<=BitRate=)\d+' "$GEMINI_CONFIG_FILE" 2>/dev/null || true)
            TXQ_SET=$(grep -E "txqueuelen " "$GEMINI_SERVICE_FILE" 2>/dev/null | awk '{print $NF}' || true)

            # Gemini validation successful
            if [[ "$BITRATE_SET" == "$BITRATE" && "$TXQ_SET" == "$TXQ" ]]; then
                echo "✅ Gemini CAN Bus validation successful: bitrate=$BITRATE_SET, txqueuelen=$TXQ_SET"

            # Gemini validation failure
            else
                echo "❌ Gemini Validation Failed!"
                echo ""
                echo "   Expected: bitrate=$BITRATE, txqueuelen=$TXQ"
                echo "   Found:    bitrate=$BITRATE_SET, txqueuelen=$TXQ_SET"
                echo ""
                echo "Please check $GEMINI_CONFIG_FILE & $GEMINI_SERVICE_FILE manually or open a support ticket."
                echo ""
                echo "GitHub: https://github.com/JMallick1997/CANtastic/tree/main"
                echo ""
                echo "Error code: VALIDATE_GEMINI_CONFIG_FAILURE"
                sleep 3
                finishing_blurbs
                canbus_configuration_menu
                break
            fi
            ;;

        # Error catch ---------------------------------------------------------------------------------------------------------------------------------------------------
        *)
            echo ""
            echo "☠️ If you're reading this something is broken & you need to open a support ticket. ☠️"
            echo ""
            echo "GitHub: https://github.com/JMallick1997/CANtastic/tree/main"
            echo ""
            echo "Error code: CONFIGURE_CANBUS_GENERATION_FAILURE"
            sleep 3
            finishing_blurbs
            canbus_configuration_menu
            break
            ;;
    esac
    # End Methods ---------------------------------------------------------------------------------------------------------------------------------------------------

    # Finishing blurbs
    while true; do
        echo ""
        case $METHOD_NAME in
            "Legacy")
                echo "Due to the way Legacy CAN Bus is setup you will need to restart your system for any changes to be effective."
                ;;
            *)
                echo "You may need to restart your system before changes to your system are effective."
                ;;
        esac

        # Restart choice
        read -p "Do you want to restart your system now? (Y/N): " RESTART_CHOICE
        RESTART_CHOICE=${RESTART_CHOICE,,}
        case $RESTART_CHOICE in

            # Restart selected
            y)
                echo ""
                echo "Restarting your system..."
                sleep 3
                sudo reboot now
                break  # Not strictly needed since reboot exits, but safe
                ;;

            # Go back to CAN Bus Configuration menu
            n)
                while read -t 0; do read -r; done
                echo ""
                echo "CAN Bus configurations saved but will not take effect until your system is rebooted."
                echo "Returning to CAN Bus Configuration menu..."
                sleep 3
                canbus_configuration_menu
                break
                ;;

            # Invalid option
            *)
                echo "❌ Invalid option. Try again."
                ;;
        esac
    done
}

########################################
# CAN Bus Deletion
########################################
delete_canbus() {

    # Deletion confirmation menu
    while true; do
        clear
        echo ""
        echo "======================== 🗑️ Deleting CAN Bus Configuration 🗑️ ========================"
        echo ""
        echo "You are preparing to delete your system's CAN Bus configuration."
        echo "This action is irreversible. Proceed with caution."
        echo ""
        read -p "Do you want to proceed: " DELETE_CHOICE
        DELETE_CHOICE=${DELETE_CHOICE,,}
        case $DELETE_CHOICE in

            # Restart selected
            y)
                echo ""
                echo "🗑️ Deleting CAN Bus Configuration..."
                echo ""
                sleep 3
                break
                ;;

            # Go back to CAN Bus Configuration menu
            n)
                while read -t 0; do read -r; done
                echo ""
                echo "CAN Bus Deletion cancelled! Returning to the CAN Bus Configuration menu..."
                sleep 3
                canbus_configuration_menu
                break
                ;;

            # Invalid option
            *)
                echo "❌ Invalid option. Try again."
                sleep 3
                ;;
        esac
    done

    # Delete config files if found
    for FILE in "$ESOTERICAL_CONFIG_FILE" "$ESOTERICAL_SERVICE_FILE" "$LEGACY_CONFIG_FILE" "$GEMINI_CONFIG_FILE" "$GEMINI_SERVICE_FILE"; do
        if [ -f "$FILE" ]; then
            printf "🗑️ Removing: %s\n" "$FILE"
            sudo rm "$FILE"
        fi
    done

    # Finishing blurbs
    while true; do
        echo ""
        echo "You may need to restart your system before changes to your system are effective."
        read -p "Do you want to restart your system now? (Y/N): " RESTART_CHOICE
        RESTART_CHOICE=${RESTART_CHOICE,,}
        case $RESTART_CHOICE in

            # Restart selected
            y)
                echo ""
                echo "Restarting your system..."
                sleep 3
                sudo reboot now
                break  # Not strictly needed since reboot exits, but safe
                ;;

            # Go back to CAN Bus Configuration menu
            n)
                while read -t 0; do read -r; done
                echo ""
                echo "Returning to CAN Bus Configuration menu..."
                sleep 3
                canbus_configuration_menu
                break
                ;;

            # Invalid option
            *)
                echo "❌ Invalid option. Try again."
                ;;
        esac
    done
}

########################################
# Check for Updates
########################################
check_for_updates() {
    clear

    # Check for updates (ignore curl error, handle manually)
    LATEST_VERSION=$(curl -s "$VERSION_URL" || true)

    # If update check fails
    if [ -z "$LATEST_VERSION" ]; then
        echo "⚠️ Could not check for updates. Please check your network connection."
        sleep 3
        return 0
    fi

    # If a newer script is found
    if [ "$SCRIPT_VERSION" != "$LATEST_VERSION" ]; then
        echo "🆕 A new version ($LATEST_VERSION) is available! You have $SCRIPT_VERSION."
        read -p "Do you want to update now? (Y/N): " UPDATE_CHOICE
        UPDATE_CHOICE=${UPDATE_CHOICE,,}
        case "$UPDATE_CHOICE" in
            y)
                echo "⬇️ Downloading latest version..."
                if curl -s -o "$SCRIPT_NAME.tmp" "$SCRIPT_URL"; then
                    if [ -s "$SCRIPT_NAME.tmp" ]; then
                        mv -f "$SCRIPT_NAME.tmp" "$SCRIPT_NAME" || {
                            echo "❌ Failed to replace script file."
                            rm -f "$SCRIPT_NAME.tmp"
                            sleep 3
                            return 1
                        }
                        chmod +x "$SCRIPT_NAME"
                        echo "✅ CANtastic successfully updated to version $LATEST_VERSION!"
                        echo "Restarting CANtastic..."
                        sleep 3
                        exec bash "$SCRIPT_NAME"
                    else
                        echo "❌ Update failed. Empty download."
                        rm -f "$SCRIPT_NAME.tmp"
                        sleep 3
                    fi
                else
                    echo "❌ Update failed. Could not download."
                    sleep 3
                fi
                ;;
            *)
                echo "⚠️ Update skipped. Retaining current version $SCRIPT_VERSION."
                sleep 3
                ;;
        esac

    # Latest version is running
    else
        echo "✅ You are running the latest version ($SCRIPT_VERSION)."
        sleep 3
    fi
}

########################################
# Main Menu
########################################
main_menu() {
    while true; do
        clear
        # This banner is now corrected with escaped backslashes (\\)
        echo " ____________________________________________________________________________________________________________________________________ "
        echo "|                                                                                                                                    |"
        echo "|  ________  ________  ________   _________  ________  ________  _________  ___  ________  ___            ___      ___  _______      |"
        echo "| |\\   ____\\|\\   __  \\|\\   ___  \\|\\___   ___\\\\   __  \\|\\   ____\\|\\___   ___\\\\  \\|\\   ____\\|\\  \\          |\\  \\    /  /|/  ___  \\     |"
        echo "| \\ \\  \\___|\\ \\  \\|\\  \\ \\  \\\\ \\  \\|___ \\  \\_\\ \\  \\|\\  \\ \\  \\___|\\|___ \\  \\_\\ \\  \\ \\  \\___|\\ \\  \\         \\ \\  \\  /  / /__/|_/  /|    |"
        echo "|  \\ \\  \\    \\ \\   __  \\ \\  \\\\ \\  \\   \\ \\  \\ \\ \\   __  \\ \\_____  \\   \\ \\  \\ \\ \\  \\ \\  \\    \\ \\  \\         \\ \\  \\/  / /|__|//  / /    |"
        echo "|   \\ \\  \\____\\ \\  \\ \\  \\ \\  \\\\ \\  \\   \\ \\  \\ \\ \\  \\ \\  \\|____|\\  \\   \\ \\  \\ \\ \\  \\ \\  \\____\\ \\__\\         \\ \\    / /     /  /_/__   |"
        echo "|    \\ \\_______\\ \\__\\ \\__\\ \\__\\\\ \\__\\   \\ \\__\\ \\ \\__\\ \\__\\____\\_\\  \\   \\ \\__\\ \\ \\__\\ \\_______\\|__|          \\ \\__/ /     |\\________\\ |"
        echo "|     \\|_______|\\|__|\\|__|\\|__| \\|__|    \\|__|  \\|__|\\|__|\\_________\\   \\|__|  \\|__|\\|_______|  ___          \\|__|/       \\|_______| |"
        echo "|                                                       \\|__________|                          |\\__\\                                 |"
        echo "|                                                                                              \\|__|                                 |"
        echo "|   NOW WITH SYSTEMD SUPPORT!                                                                                                        |"
        echo "|____________________________________________________________________________________________________________________________________|"
        echo "|                                                                                                                                    |"
        echo "| 1. CAN Bus Configuration                                                                                                           |"
        echo "| 2. CAN Bus Utilities                                                                                                               |"
        echo "| 3. Troubleshooting                                                                                                                 |"
        echo "| 4. Exit CANtastic!                                                                                                                 |"
        echo "|____________________________________________________________________________________________________________________________________|"
        echo ""
        read -p "Choose an option [1-4]: " MAIN_MENU_CHOICE

        case "$MAIN_MENU_CHOICE" in
            1) canbus_configuration_menu ;;
            2) canbus_utilities ;;
            3) help_menu ;;
            4) exit_cantastic ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done
}

########################################
# CAN Bus Configuration Menu
########################################
canbus_configuration_menu() {
    while true; do
        clear
        echo ""
        echo "====== 🔧 CAN Bus Configuration 🔧 ======"
        echo ""
        status_can0
        echo ""
        echo "1. Configure CAN Bus Configuration"
        echo "2. Delete CAN Bus Configuration"
        echo "3. Restart CAN Bus"
        echo "4. UUID Search"
        echo "5. CAN Bus File Viewer"
        echo "6. Back"
        echo ""
        echo "=========================================="
        echo ""
        read -p "Choose an option [1-6]: " CONFIG_MENU_CHOICE

        case "$CONFIG_MENU_CHOICE" in
            1) configure_canbus ;;
            2) delete_canbus ;;
            3) restart_canbus ;;
            4) uuid_search ;;
            5) canbus_file_viewer ;;
            6) main_menu ;;
            *) echo "❌ Invalid option. Try again." ;;
        esac
    done
}

########################################
# CAN Bus Utilities Menu
########################################
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

########################################
# Troubleshooting Menu
########################################
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

########################################
# CAN Bus Explained Menu
########################################
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
    finishing_blurbs
    help_menu
}

########################################
# CAN Bus Wiring Menu
########################################
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
    finishing_blurbs
    help_menu
}

########################################
# CAN Bus Klipper Menu
########################################
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
    finishing_blurbs
    help_menu
}

########################################
# CAN Bus Troubleshooting Menu
########################################
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
    finishing_blurbs
    help_menu
}

########################################
# About CANtastic! Menu
########################################
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
    finishing_blurbs
    help_menu
}

########################################
# Finishing Blurbs
########################################
finishing_blurbs() {
    echo ""
    read -n 1 -s -r -p "Press any key to go back to previous menu..."
    while read -t 0; do read -r; done
}

########################################
# Exit CANtastic!
########################################
exit_cantastic() {
    clear
    echo "Exiting CANtastic! Happy Printing! 👋"
    exit 0
}

########################################
# Run Program
########################################
check_for_updates
main_menu
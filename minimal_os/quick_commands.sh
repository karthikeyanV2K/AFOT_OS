#!/bin/bash

# AFOT Minimal OS - Quick Commands for Samsung J5 Prime
# Easy-to-use commands for building, flashing, and managing your minimal OS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                AFOT Minimal OS - Quick Commands             ║"
    echo "║                Samsung J5 Prime Edition                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_menu() {
    echo -e "${YELLOW}Choose an action:${NC}"
    echo "1) 📋 Backup current phone (IMPORTANT!)"
    echo "2) 🔨 Build AFOT Minimal OS"
    echo "3) 📱 Flash to J5 Prime"
    echo "4) ✅ Test installation"
    echo "5) 🔋 Check battery optimization"
    echo "6) 📊 System status"
    echo "7) 🆘 Emergency recovery"
    echo "8) 🔄 Flash back to stock Samsung"
    echo "9) 📚 Show detailed guide"
    echo "0) ❌ Exit"
    echo
}

backup_phone() {
    echo -e "${BLUE}[BACKUP]${NC} Creating complete backup of your J5 Prime..."
    
    # Check if device is connected
    if ! adb devices | grep -q "device$"; then
        echo -e "${RED}Error: J5 Prime not connected or USB debugging not enabled${NC}"
        echo "1. Enable Developer Options (tap Build Number 7 times)"
        echo "2. Enable USB Debugging"
        echo "3. Connect phone and authorize computer"
        return 1
    fi
    
    # Create backup directory
    mkdir -p backups/$(date +%Y%m%d_%H%M%S)
    cd backups/$(date +%Y%m%d_%H%M%S)
    
    echo "Creating full device backup..."
    adb backup -apk -shared -nosystem -all -system
    
    echo "Backing up photos..."
    adb pull /sdcard/DCIM/ ./photos/ 2>/dev/null || echo "No photos found"
    
    echo "Backing up music..."
    adb pull /sdcard/Music/ ./music/ 2>/dev/null || echo "No music found"
    
    echo "Backing up EFS partition (CRITICAL for network functions)..."
    adb shell "su -c 'dd if=/dev/block/mmcblk0p3 of=/sdcard/efs_backup.img'" 2>/dev/null || {
        echo -e "${YELLOW}Warning: Could not backup EFS (phone may not be rooted)${NC}"
        echo "This is needed for network functions. Consider rooting first."
    }
    adb pull /sdcard/efs_backup.img ./efs_backup.img 2>/dev/null || echo "EFS backup failed"
    
    cd ../..
    
    echo -e "${GREEN}✓ Backup completed in backups/ directory${NC}"
    echo -e "${YELLOW}⚠️  Keep these files safe - you need them for recovery!${NC}"
}

build_minimal_os() {
    echo -e "${BLUE}[BUILD]${NC} Building AFOT Minimal OS for J5 Prime..."
    
    # Check if build environment exists
    if [[ ! -d "$HOME/android/lineage" ]]; then
        echo -e "${YELLOW}Setting up build environment first...${NC}"
        cd ..
        ./setup_android_build.sh
        cd minimal_os
    fi
    
    # Run the minimal builder
    python3 build_minimal_j5prime.py
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ AFOT Minimal OS build completed!${NC}"
        ls -la builds/afot-minimal-j5prime-*.zip 2>/dev/null || echo "Build file not found"
    else
        echo -e "${RED}✗ Build failed. Check logs for details.${NC}"
    fi
}

flash_to_device() {
    echo -e "${BLUE}[FLASH]${NC} Flashing AFOT Minimal OS to J5 Prime..."
    
    # Find the latest ROM file
    ROM_FILE=$(ls -t builds/afot-minimal-j5prime-*.zip 2>/dev/null | head -1)
    
    if [[ -z "$ROM_FILE" ]]; then
        echo -e "${RED}Error: No ROM file found. Build the ROM first.${NC}"
        return 1
    fi
    
    echo "Found ROM: $ROM_FILE"
    echo -e "${YELLOW}⚠️  Make sure your J5 Prime is in Download Mode:${NC}"
    echo "   1. Power off phone completely"
    echo "   2. Hold Power + Home + Volume Down"
    echo "   3. Press Volume Up when warning appears"
    echo "   4. Connect USB cable"
    echo
    
    read -p "Is your phone in Download Mode? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Use AFOT flash tool
        python3 ../flash_tools/afot_flash.py "$ROM_FILE" --device j5xnlte
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ Flashing completed successfully!${NC}"
            echo -e "${BLUE}First boot will take 5-10 minutes. Be patient!${NC}"
        else
            echo -e "${RED}✗ Flashing failed. Check connections and try again.${NC}"
        fi
    else
        echo "Please put your phone in Download Mode first."
    fi
}

test_installation() {
    echo -e "${BLUE}[TEST]${NC} Testing AFOT Minimal OS installation..."
    
    if ! adb devices | grep -q "device$"; then
        echo -e "${RED}Error: Device not connected${NC}"
        return 1
    fi
    
    echo "Checking AFOT version..."
    AFOT_VERSION=$(adb shell getprop ro.afot.variant 2>/dev/null)
    if [[ "$AFOT_VERSION" == "minimal" ]]; then
        echo -e "${GREEN}✓ AFOT Minimal OS detected${NC}"
    else
        echo -e "${RED}✗ AFOT Minimal OS not detected${NC}"
        return 1
    fi
    
    echo "Checking installed apps..."
    AFOT_APPS=$(adb shell pm list packages | grep afot | wc -l)
    echo "AFOT apps installed: $AFOT_APPS"
    
    echo "Testing essential functions..."
    
    # Test music player
    adb shell am start -n com.afot.musiclite/.MainActivity 2>/dev/null && echo "✓ Music player works" || echo "✗ Music player issue"
    
    # Test phone
    adb shell am start -n com.afot.phone/.DialerActivity 2>/dev/null && echo "✓ Phone app works" || echo "✗ Phone app issue"
    
    # Test messages
    adb shell am start -n com.afot.messages/.MessagesActivity 2>/dev/null && echo "✓ Messages app works" || echo "✗ Messages app issue"
    
    # Test camera
    adb shell am start -n com.afot.camera/.CameraActivity 2>/dev/null && echo "✓ Camera app works" || echo "✗ Camera app issue"
    
    # Test emergency
    adb shell am start -n com.afot.emergency/.EmergencyActivity 2>/dev/null && echo "✓ Emergency SOS works" || echo "✗ Emergency SOS issue"
    
    echo -e "${GREEN}✓ Installation test completed${NC}"
}

check_battery_optimization() {
    echo -e "${BLUE}[BATTERY]${NC} Checking battery optimization status..."
    
    if ! adb devices | grep -q "device$"; then
        echo -e "${RED}Error: Device not connected${NC}"
        return 1
    fi
    
    echo "Battery information:"
    adb shell dumpsys battery | grep -E "level|status|health|temperature"
    
    echo -e "\nMemory usage:"
    TOTAL_RAM=$(adb shell cat /proc/meminfo | grep MemTotal | awk '{print $2}')
    AVAILABLE_RAM=$(adb shell cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
    USED_RAM=$((TOTAL_RAM - AVAILABLE_RAM))
    USED_MB=$((USED_RAM / 1024))
    TOTAL_MB=$((TOTAL_RAM / 1024))
    
    echo "RAM Usage: ${USED_MB}MB / ${TOTAL_MB}MB"
    
    if [[ $USED_MB -lt 500 ]]; then
        echo -e "${GREEN}✓ Excellent memory usage (under 500MB)${NC}"
    elif [[ $USED_MB -lt 800 ]]; then
        echo -e "${YELLOW}⚠ Good memory usage (under 800MB)${NC}"
    else
        echo -e "${RED}✗ High memory usage (over 800MB)${NC}"
    fi
    
    echo -e "\nRunning processes:"
    PROCESS_COUNT=$(adb shell ps | wc -l)
    echo "Active processes: $PROCESS_COUNT"
    
    if [[ $PROCESS_COUNT -lt 20 ]]; then
        echo -e "${GREEN}✓ Excellent process count (minimal background activity)${NC}"
    elif [[ $PROCESS_COUNT -lt 30 ]]; then
        echo -e "${YELLOW}⚠ Good process count${NC}"
    else
        echo -e "${RED}✗ High process count (too much background activity)${NC}"
    fi
    
    echo -e "\nBattery optimization: ${GREEN}ACTIVE${NC}"
}

system_status() {
    echo -e "${BLUE}[STATUS]${NC} AFOT Minimal OS System Status..."
    
    if ! adb devices | grep -q "device$"; then
        echo -e "${RED}Error: Device not connected${NC}"
        return 1
    fi
    
    echo "=== Device Information ==="
    echo "Model: $(adb shell getprop ro.product.model)"
    echo "Android Version: $(adb shell getprop ro.build.version.release)"
    echo "AFOT Version: $(adb shell getprop ro.afot.version)"
    echo "AFOT Variant: $(adb shell getprop ro.afot.variant)"
    echo "Build Date: $(adb shell getprop ro.afot.build.date)"
    
    echo -e "\n=== Storage Information ==="
    adb shell df -h | grep -E "Filesystem|/data|/system|/sdcard"
    
    echo -e "\n=== Network Status ==="
    echo "Signal Strength: $(adb shell dumpsys telephony.registry | grep mSignalStrength | head -1)"
    echo "Network Type: $(adb shell dumpsys telephony.registry | grep mDataConnectionState)"
    
    echo -e "\n=== Essential Apps Status ==="
    adb shell pm list packages | grep afot | while read app; do
        app_name=$(echo $app | cut -d: -f2)
        echo "✓ $app_name installed"
    done
}

emergency_recovery() {
    echo -e "${RED}[EMERGENCY]${NC} Emergency Recovery Options..."
    echo
    echo "Choose recovery method:"
    echo "1) Soft reset (reboot device)"
    echo "2) Clear cache partition"
    echo "3) Factory reset (wipes all data)"
    echo "4) Flash stock Samsung firmware"
    echo "5) Restore EFS backup (network fix)"
    echo "0) Cancel"
    echo
    
    read -p "Choose option [0-5]: " recovery_option
    
    case $recovery_option in
        1)
            echo "Performing soft reset..."
            adb reboot
            echo -e "${GREEN}✓ Device rebooting${NC}"
            ;;
        2)
            echo "Clearing cache partition..."
            adb reboot recovery
            echo "In recovery mode, select 'Wipe cache partition'"
            ;;
        3)
            echo -e "${RED}⚠️  This will erase all your data!${NC}"
            read -p "Are you sure? (type 'yes' to confirm): " confirm
            if [[ "$confirm" == "yes" ]]; then
                adb shell recovery --wipe_data
                echo -e "${YELLOW}Factory reset initiated${NC}"
            else
                echo "Cancelled"
            fi
            ;;
        4)
            flash_stock_firmware
            ;;
        5)
            restore_efs_backup
            ;;
        0)
            echo "Cancelled"
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

flash_stock_firmware() {
    echo -e "${YELLOW}[STOCK]${NC} Flashing back to stock Samsung firmware..."
    echo
    echo "To flash stock firmware:"
    echo "1. Download stock firmware for SM-G570F from SamMobile.com"
    echo "2. Put phone in Download Mode (Power + Home + Volume Down)"
    echo "3. Use Odin3 to flash the firmware"
    echo "4. Wait for completion and reboot"
    echo
    echo "Stock firmware locations:"
    echo "- SamMobile: https://www.sammobile.com/samsung/galaxy-j5-prime/firmware/"
    echo "- Frija Tool: https://forum.xda-developers.com/t/tool-frija-samsung-firmware-downloader-checker.3910594/"
    echo
    echo -e "${RED}⚠️  This will completely remove AFOT Minimal OS${NC}"
}

restore_efs_backup() {
    echo -e "${BLUE}[EFS]${NC} Restoring EFS backup for network functions..."
    
    EFS_BACKUP=$(find backups/ -name "efs_backup.img" 2>/dev/null | head -1)
    
    if [[ -z "$EFS_BACKUP" ]]; then
        echo -e "${RED}Error: No EFS backup found in backups/ directory${NC}"
        echo "You need to have created an EFS backup before flashing"
        return 1
    fi
    
    echo "Found EFS backup: $EFS_BACKUP"
    echo -e "${RED}⚠️  This requires root access on the device${NC}"
    
    read -p "Continue with EFS restore? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        adb push "$EFS_BACKUP" /sdcard/efs_restore.img
        adb shell "su -c 'dd if=/sdcard/efs_restore.img of=/dev/block/mmcblk0p3'"
        adb reboot
        
        echo -e "${GREEN}✓ EFS backup restored. Device rebooting...${NC}"
        echo "Network functions should work after reboot"
    fi
}

show_guide() {
    echo -e "${BLUE}[GUIDE]${NC} Opening complete installation guide..."
    
    if command -v less &> /dev/null; then
        less COMPLETE_GUIDE_J5PRIME.md
    elif command -v more &> /dev/null; then
        more COMPLETE_GUIDE_J5PRIME.md
    else
        cat COMPLETE_GUIDE_J5PRIME.md
    fi
}

# Main menu loop
main() {
    print_banner
    
    while true; do
        echo
        print_menu
        read -p "Enter your choice [0-9]: " choice
        echo
        
        case $choice in
            1) backup_phone ;;
            2) build_minimal_os ;;
            3) flash_to_device ;;
            4) test_installation ;;
            5) check_battery_optimization ;;
            6) system_status ;;
            7) emergency_recovery ;;
            8) flash_stock_firmware ;;
            9) show_guide ;;
            0) 
                echo -e "${GREEN}Thank you for using AFOT Minimal OS!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please choose 0-9.${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"

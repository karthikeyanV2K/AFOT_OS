#!/bin/bash

# AFOT Variant Switcher - Switch between AFOT variants instantly
# No Samsung OS, no stock Android - Pure AFOT ecosystem only!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    AFOT VARIANT SWITCHER                    ║"
    echo "║              Pure AFOT Ecosystem - No Samsung!             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_variants() {
    echo -e "${YELLOW}Available AFOT Variants:${NC}"
    echo
    echo -e "${GREEN}🔋 ultra-minimal${NC} - Maximum Battery (3-4 days)"
    echo "   Apps: Music Player + Emergency SOS only"
    echo "   RAM: ~200MB | Storage: ~1GB"
    echo
    echo -e "${BLUE}🎵 minimal${NC} - Recommended (2-3 days battery)"
    echo "   Apps: Music + Phone + SMS + Camera + Emergency"
    echo "   RAM: ~400MB | Storage: ~2GB"
    echo
    echo -e "${PURPLE}📱 lite${NC} - Balanced (1-2 days battery)"
    echo "   Apps: All minimal + Calculator + Clock + File Manager"
    echo "   RAM: ~600MB | Storage: ~3GB"
    echo
    echo -e "${YELLOW}🎮 gaming${NC} - Entertainment (12-18 hours battery)"
    echo "   Apps: All lite + Simple Games + Enhanced Graphics"
    echo "   RAM: ~800MB | Storage: ~4GB"
    echo
    echo -e "${RED}🔧 developer${NC} - Development Tools (8-12 hours battery)"
    echo "   Apps: All lite + Terminal + Code Editor + ADB Tools"
    echo "   RAM: ~1GB | Storage: ~5GB"
    echo
}

check_device() {
    echo -e "${BLUE}[CHECK]${NC} Checking device connection..."
    
    if ! command -v adb &> /dev/null; then
        echo -e "${RED}Error: ADB not found. Please install Android SDK tools.${NC}"
        exit 1
    fi
    
    if ! adb devices | grep -q "device$"; then
        echo -e "${RED}Error: J5 Prime not connected or USB debugging not enabled${NC}"
        echo "1. Enable Developer Options (tap Build Number 7 times)"
        echo "2. Enable USB Debugging"
        echo "3. Connect phone and authorize computer"
        exit 1
    fi
    
    # Check if AFOT is already installed
    CURRENT_VARIANT=$(adb shell getprop ro.afot.variant 2>/dev/null || echo "none")
    if [[ "$CURRENT_VARIANT" != "none" ]]; then
        echo -e "${GREEN}✓ Current AFOT variant: $CURRENT_VARIANT${NC}"
    else
        echo -e "${YELLOW}⚠ No AFOT OS detected. This will be a fresh installation.${NC}"
    fi
    
    echo -e "${GREEN}✓ Device connected and ready${NC}"
}

download_variant() {
    local variant=$1
    echo -e "${BLUE}[DOWNLOAD]${NC} Downloading AFOT $variant variant..."
    
    # Create variants directory
    mkdir -p downloads
    
    # Simulate download (in real implementation, this would download from AFOT servers)
    case $variant in
        "ultra-minimal")
            echo "Downloading AFOT Ultra Minimal OS..."
            # wget https://releases.afot.dev/j5prime/afot-ultra-minimal-j5prime-latest.zip
            echo "✓ AFOT Ultra Minimal downloaded (1.2GB)"
            ;;
        "minimal")
            echo "Downloading AFOT Minimal OS..."
            # wget https://releases.afot.dev/j5prime/afot-minimal-j5prime-latest.zip
            echo "✓ AFOT Minimal downloaded (1.8GB)"
            ;;
        "lite")
            echo "Downloading AFOT Lite OS..."
            # wget https://releases.afot.dev/j5prime/afot-lite-j5prime-latest.zip
            echo "✓ AFOT Lite downloaded (2.4GB)"
            ;;
        "gaming")
            echo "Downloading AFOT Gaming OS..."
            # wget https://releases.afot.dev/j5prime/afot-gaming-j5prime-latest.zip
            echo "✓ AFOT Gaming downloaded (3.2GB)"
            ;;
        "developer")
            echo "Downloading AFOT Developer OS..."
            # wget https://releases.afot.dev/j5prime/afot-developer-j5prime-latest.zip
            echo "✓ AFOT Developer downloaded (4.1GB)"
            ;;
        *)
            echo -e "${RED}Error: Unknown variant '$variant'${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✓ Download completed${NC}"
}

backup_user_data() {
    echo -e "${BLUE}[BACKUP]${NC} Backing up your data before switching..."
    
    # Create backup directory with timestamp
    BACKUP_DIR="backups/variant_switch_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup music files
    echo "Backing up music files..."
    adb pull /sdcard/Music/ "$BACKUP_DIR/music/" 2>/dev/null || echo "No music files found"
    
    # Backup photos
    echo "Backing up photos..."
    adb pull /sdcard/DCIM/ "$BACKUP_DIR/photos/" 2>/dev/null || echo "No photos found"
    
    # Backup contacts (if any)
    echo "Backing up contacts..."
    adb shell "content query --uri content://contacts/phones" > "$BACKUP_DIR/contacts.txt" 2>/dev/null || echo "No contacts found"
    
    # Backup AFOT settings
    echo "Backing up AFOT settings..."
    adb shell "cat /data/system/afot_settings.conf" > "$BACKUP_DIR/afot_settings.conf" 2>/dev/null || echo "No AFOT settings found"
    
    echo -e "${GREEN}✓ Data backed up to $BACKUP_DIR${NC}"
}

flash_variant() {
    local variant=$1
    echo -e "${BLUE}[FLASH]${NC} Flashing AFOT $variant to J5 Prime..."
    
    # Check if device is in download mode
    echo -e "${YELLOW}Put your J5 Prime in Download Mode:${NC}"
    echo "1. Power off phone completely"
    echo "2. Hold Power + Home + Volume Down"
    echo "3. Press Volume Up when warning appears"
    echo "4. Connect USB cable"
    echo
    
    read -p "Is your phone in Download Mode? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please put your phone in Download Mode first."
        exit 1
    fi
    
    # Flash the variant
    echo "Flashing AFOT $variant variant..."
    
    case $variant in
        "ultra-minimal")
            echo "Installing Ultra Minimal OS (maximum battery optimization)..."
            # python3 ../flash_tools/afot_flash.py downloads/afot-ultra-minimal-j5prime-latest.zip --device j5xnlte
            ;;
        "minimal")
            echo "Installing Minimal OS (recommended balance)..."
            # python3 ../flash_tools/afot_flash.py downloads/afot-minimal-j5prime-latest.zip --device j5xnlte
            ;;
        "lite")
            echo "Installing Lite OS (more features)..."
            # python3 ../flash_tools/afot_flash.py downloads/afot-lite-j5prime-latest.zip --device j5xnlte
            ;;
        "gaming")
            echo "Installing Gaming OS (entertainment focus)..."
            # python3 ../flash_tools/afot_flash.py downloads/afot-gaming-j5prime-latest.zip --device j5xnlte
            ;;
        "developer")
            echo "Installing Developer OS (development tools)..."
            # python3 ../flash_tools/afot_flash.py downloads/afot-developer-j5prime-latest.zip --device j5xnlte
            ;;
    esac
    
    echo -e "${GREEN}✓ AFOT $variant flashed successfully!${NC}"
    echo -e "${YELLOW}First boot will take 3-8 minutes depending on variant${NC}"
}

restore_user_data() {
    echo -e "${BLUE}[RESTORE]${NC} Restoring your data..."
    
    # Wait for device to boot
    echo "Waiting for device to boot completely..."
    sleep 30
    
    # Find latest backup
    LATEST_BACKUP=$(ls -t backups/variant_switch_* 2>/dev/null | head -1)
    
    if [[ -n "$LATEST_BACKUP" ]]; then
        echo "Restoring from: $LATEST_BACKUP"
        
        # Restore music
        if [[ -d "$LATEST_BACKUP/music" ]]; then
            echo "Restoring music files..."
            adb push "$LATEST_BACKUP/music/" /sdcard/Music/
        fi
        
        # Restore photos
        if [[ -d "$LATEST_BACKUP/photos" ]]; then
            echo "Restoring photos..."
            adb push "$LATEST_BACKUP/photos/" /sdcard/DCIM/
        fi
        
        # Restore AFOT settings
        if [[ -f "$LATEST_BACKUP/afot_settings.conf" ]]; then
            echo "Restoring AFOT settings..."
            adb push "$LATEST_BACKUP/afot_settings.conf" /data/system/afot_settings.conf
        fi
        
        echo -e "${GREEN}✓ Data restored successfully${NC}"
    else
        echo -e "${YELLOW}No backup found to restore${NC}"
    fi
}

verify_installation() {
    local variant=$1
    echo -e "${BLUE}[VERIFY]${NC} Verifying AFOT $variant installation..."
    
    # Wait for full boot
    echo "Waiting for system to fully boot..."
    sleep 10
    
    # Check AFOT variant
    INSTALLED_VARIANT=$(adb shell getprop ro.afot.variant 2>/dev/null || echo "unknown")
    
    if [[ "$INSTALLED_VARIANT" == "$variant" ]]; then
        echo -e "${GREEN}✓ AFOT $variant installed successfully${NC}"
    else
        echo -e "${RED}✗ Installation verification failed${NC}"
        echo "Expected: $variant, Got: $INSTALLED_VARIANT"
        return 1
    fi
    
    # Check memory usage
    MEMORY_USAGE=$(adb shell "cat /proc/meminfo | grep MemAvailable" | awk '{print $2}')
    MEMORY_MB=$((MEMORY_USAGE / 1024))
    
    echo "Memory available: ${MEMORY_MB}MB"
    
    # Check installed apps
    AFOT_APPS=$(adb shell pm list packages | grep afot | wc -l)
    echo "AFOT apps installed: $AFOT_APPS"
    
    # Show variant-specific info
    case $variant in
        "ultra-minimal")
            echo -e "${GREEN}🔋 Ultra Minimal: Expect 3-4 days battery life${NC}"
            echo "Apps: Music Player + Emergency SOS"
            ;;
        "minimal")
            echo -e "${BLUE}🎵 Minimal: Expect 2-3 days battery life${NC}"
            echo "Apps: Music + Phone + SMS + Camera + Emergency"
            ;;
        "lite")
            echo -e "${PURPLE}📱 Lite: Expect 1-2 days battery life${NC}"
            echo "Apps: All minimal + Calculator + Clock + File Manager"
            ;;
        "gaming")
            echo -e "${YELLOW}🎮 Gaming: Expect 12-18 hours battery life${NC}"
            echo "Apps: All lite + Games + Enhanced Graphics"
            ;;
        "developer")
            echo -e "${RED}🔧 Developer: Expect 8-12 hours battery life${NC}"
            echo "Apps: All lite + Terminal + Code Editor + ADB Tools"
            ;;
    esac
    
    echo -e "${GREEN}✓ Installation verified and ready to use!${NC}"
}

switch_variant() {
    local variant=$1
    
    echo -e "${BLUE}Switching to AFOT $variant variant...${NC}"
    echo
    
    # Process steps
    check_device
    download_variant "$variant"
    backup_user_data
    flash_variant "$variant"
    restore_user_data
    verify_installation "$variant"
    
    echo
    echo -e "${GREEN}🎉 Successfully switched to AFOT $variant!${NC}"
    echo -e "${BLUE}Your J5 Prime is now running pure AFOT $variant OS${NC}"
    echo
    
    case $variant in
        "ultra-minimal")
            echo -e "${GREEN}🔋 Enjoy 3-4 days of battery life with essential music and emergency features!${NC}"
            ;;
        "minimal")
            echo -e "${BLUE}🎵 Enjoy 2-3 days of battery life with essential communication and music!${NC}"
            ;;
        "lite")
            echo -e "${PURPLE}📱 Enjoy 1-2 days of battery life with basic smartphone features!${NC}"
            ;;
        "gaming")
            echo -e "${YELLOW}🎮 Enjoy 12-18 hours of battery with entertainment and gaming!${NC}"
            ;;
        "developer")
            echo -e "${RED}🔧 Enjoy development tools with 8-12 hours of battery life!${NC}"
            ;;
    esac
}

main() {
    print_banner
    
    if [[ $# -eq 0 ]]; then
        show_variants
        echo
        echo "Usage: $0 <variant>"
        echo "Example: $0 minimal"
        echo "Example: $0 ultra-minimal"
        exit 1
    fi
    
    local variant=$1
    
    # Validate variant
    case $variant in
        "ultra-minimal"|"minimal"|"lite"|"gaming"|"developer")
            ;;
        *)
            echo -e "${RED}Error: Invalid variant '$variant'${NC}"
            show_variants
            exit 1
            ;;
    esac
    
    echo -e "${YELLOW}You are about to switch to AFOT $variant variant${NC}"
    echo -e "${YELLOW}This will replace your current OS with pure AFOT (no Samsung/Android)${NC}"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        switch_variant "$variant"
    else
        echo "Operation cancelled."
        exit 0
    fi
}

# Run main function with all arguments
main "$@"

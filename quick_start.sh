#!/bin/bash

# AFOT Custom Android OS - Quick Start Script
# This script provides an interactive setup and build process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Banner
print_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║     █████╗ ███████╗ ██████╗ ████████╗    ██████╗  ██████╗    ║
    ║    ██╔══██╗██╔════╝██╔═══██╗╚══██╔══╝    ██╔══██╗██╔═══██╗   ║
    ║    ███████║█████╗  ██║   ██║   ██║       ██████╔╝██║   ██║   ║
    ║    ██╔══██║██╔══╝  ██║   ██║   ██║       ██╔══██╗██║   ██║   ║
    ║    ██║  ██║██║     ╚██████╔╝   ██║       ██║  ██║╚██████╔╝   ║
    ║    ╚═╝  ╚═╝╚═╝      ╚═════╝    ╚═╝       ╚═╝  ╚═╝ ╚═════╝    ║
    ║                                                               ║
    ║              Advanced Features of Tomorrow                    ║
    ║           Custom Android OS with Enhanced Audio              ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root!"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    print_step "Checking system requirements..."
    
    # Check OS
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "This script requires Linux. For Windows, use WSL2 with Ubuntu 20.04+"
        exit 1
    fi
    
    # Check available disk space (200GB minimum)
    available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt 200 ]]; then
        print_warning "Low disk space: ${available_space}GB available. 200GB+ recommended."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check RAM
    total_ram=$(free -g | awk 'NR==2{print $2}')
    if [[ $total_ram -lt 8 ]]; then
        print_warning "Low RAM: ${total_ram}GB detected. 8GB+ recommended."
    fi
    
    print_success "System requirements check completed"
}

# Interactive menu
show_menu() {
    echo
    echo -e "${CYAN}What would you like to do?${NC}"
    echo "1) Complete setup (environment + sources)"
    echo "2) Build GSI (Generic System Image)"
    echo "3) Build device-specific ROM"
    echo "4) Flash ROM to device"
    echo "5) Run test suite"
    echo "6) Show supported devices"
    echo "7) Clean build environment"
    echo "8) Exit"
    echo
}

# Setup environment
setup_environment() {
    print_step "Setting up AFOT build environment..."
    
    if [[ ! -f "./setup_android_build.sh" ]]; then
        print_error "setup_android_build.sh not found. Are you in the AFOT directory?"
        exit 1
    fi
    
    chmod +x ./setup_android_build.sh
    ./setup_android_build.sh
    
    print_success "Environment setup completed!"
}

# Build GSI
build_gsi() {
    print_step "Building AFOT GSI (Generic System Image)..."
    
    # Check if environment is set up
    if [[ ! -d "$HOME/android/aosp" ]]; then
        print_error "AOSP source not found. Please run setup first."
        return 1
    fi
    
    # Get build parameters
    echo "GSI Build Configuration:"
    read -p "Number of parallel jobs [$(nproc)]: " jobs
    jobs=${jobs:-$(nproc)}
    
    read -p "Clean build? (y/N): " -n 1 -r clean_build
    echo
    
    # Build command
    build_cmd="python3 $HOME/android/afot/build_scripts/build_afot_rom.py --device gsi --jobs $jobs"
    
    if [[ $clean_build =~ ^[Yy]$ ]]; then
        build_cmd="$build_cmd --clean"
    fi
    
    print_info "Starting GSI build..."
    print_info "This will take 2-4 hours depending on your hardware"
    
    eval $build_cmd
    
    if [[ $? -eq 0 ]]; then
        print_success "GSI build completed successfully!"
        print_info "Images available in: $HOME/android/afot/builds/"
    else
        print_error "GSI build failed!"
        return 1
    fi
}

# Build device ROM
build_device_rom() {
    print_step "Building device-specific AFOT ROM..."
    
    # Check if environment is set up
    if [[ ! -d "$HOME/android/lineage" ]]; then
        print_error "LineageOS source not found. Please run setup first."
        return 1
    fi
    
    # Show supported devices
    echo "Supported devices:"
    echo "  j5xnlte  - Samsung Galaxy J5 Prime"
    echo "  j5nlte   - Samsung Galaxy J5 2015"
    echo "  sailfish - Google Pixel"
    echo
    
    read -p "Enter device codename: " device_codename
    
    if [[ -z "$device_codename" ]]; then
        print_error "Device codename is required"
        return 1
    fi
    
    # Get build parameters
    echo "Device ROM Build Configuration:"
    read -p "Build type [userdebug]: " build_type
    build_type=${build_type:-userdebug}
    
    read -p "Number of parallel jobs [$(nproc)]: " jobs
    jobs=${jobs:-$(nproc)}
    
    read -p "Clean build? (y/N): " -n 1 -r clean_build
    echo
    
    read -p "Sign build? (y/N): " -n 1 -r sign_build
    echo
    
    read -p "Create OTA package? (y/N): " -n 1 -r create_ota
    echo
    
    # Build command
    build_cmd="python3 $HOME/android/afot/build_scripts/build_afot_rom.py --device $device_codename --build-type $build_type --jobs $jobs"
    
    if [[ $clean_build =~ ^[Yy]$ ]]; then
        build_cmd="$build_cmd --clean"
    fi
    
    if [[ $sign_build =~ ^[Yy]$ ]]; then
        build_cmd="$build_cmd --sign"
    fi
    
    if [[ $create_ota =~ ^[Yy]$ ]]; then
        build_cmd="$build_cmd --ota"
    fi
    
    print_info "Starting device ROM build for $device_codename..."
    print_info "This will take 3-6 hours depending on your hardware"
    
    eval $build_cmd
    
    if [[ $? -eq 0 ]]; then
        print_success "Device ROM build completed successfully!"
        print_info "ROM package available in: $HOME/android/afot/builds/"
    else
        print_error "Device ROM build failed!"
        return 1
    fi
}

# Flash ROM
flash_rom() {
    print_step "Flashing AFOT ROM to device..."
    
    # Check if flash tool exists
    if [[ ! -f "$HOME/android/afot/flash_tools/afot_flash.py" ]]; then
        print_error "Flash tool not found. Please ensure AFOT is properly set up."
        return 1
    fi
    
    # List available ROM files
    rom_dir="$HOME/android/afot/builds"
    if [[ -d "$rom_dir" ]]; then
        echo "Available ROM files:"
        ls -la "$rom_dir"/*.{zip,img,tar} 2>/dev/null || echo "No ROM files found"
        echo
    fi
    
    read -p "Enter path to ROM file: " rom_file
    
    if [[ ! -f "$rom_file" ]]; then
        print_error "ROM file not found: $rom_file"
        return 1
    fi
    
    # Flash options
    read -p "Device codename (leave empty for auto-detect): " device_codename
    read -p "Wipe user data? (y/N): " -n 1 -r wipe_data
    echo
    
    # Build flash command
    flash_cmd="python3 $HOME/android/afot/flash_tools/afot_flash.py"
    
    if [[ -n "$device_codename" ]]; then
        flash_cmd="$flash_cmd --device $device_codename"
    fi
    
    if [[ $wipe_data =~ ^[Yy]$ ]]; then
        flash_cmd="$flash_cmd --wipe-data"
    fi
    
    flash_cmd="$flash_cmd $rom_file"
    
    print_warning "IMPORTANT: Make sure your device is in the correct mode:"
    print_warning "  - Samsung: Download mode (Power + Home + Volume Down)"
    print_warning "  - Google/OnePlus: Fastboot mode (Power + Volume Down)"
    print_warning "  - Ensure USB debugging is enabled and device is authorized"
    echo
    
    read -p "Device ready? Press Enter to continue or Ctrl+C to cancel..."
    
    print_info "Starting flash process..."
    eval $flash_cmd
    
    if [[ $? -eq 0 ]]; then
        print_success "ROM flashed successfully!"
        print_info "Device should reboot automatically"
        print_info "First boot may take 5-10 minutes"
    else
        print_error "Flash failed!"
        return 1
    fi
}

# Run test suite
run_tests() {
    print_step "Running AFOT test suite..."
    
    if [[ ! -f "$HOME/android/afot/testing/afot_test_suite.py" ]]; then
        print_error "Test suite not found. Please ensure AFOT is properly set up."
        return 1
    fi
    
    echo "Test Configuration:"
    echo "Available categories: system, audio, security, performance, ui, network, storage, sensors, afot"
    read -p "Test categories (space-separated, or 'all'): " categories
    
    echo "Available priorities: high, medium, low"
    read -p "Test priorities (space-separated, or 'all'): " priorities
    
    # Build test command
    test_cmd="python3 $HOME/android/afot/testing/afot_test_suite.py"
    
    if [[ "$categories" != "all" && -n "$categories" ]]; then
        test_cmd="$test_cmd --categories $categories"
    fi
    
    if [[ "$priorities" != "all" && -n "$priorities" ]]; then
        test_cmd="$test_cmd --priorities $priorities"
    fi
    
    print_info "Starting test suite..."
    eval $test_cmd
    
    print_info "Test results saved to afot_test_report_*.json"
}

# Show supported devices
show_devices() {
    print_step "AFOT Supported Devices"
    echo
    echo -e "${GREEN}Tier 1 (Full Support):${NC}"
    echo "  j5xnlte  - Samsung Galaxy J5 Prime (Heimdall)"
    echo "  j5nlte   - Samsung Galaxy J5 2015 (Heimdall)"
    echo "  sailfish - Google Pixel (Fastboot)"
    echo "  gsi      - Generic System Image (Treble devices)"
    echo
    echo -e "${YELLOW}Tier 2 (Community Support):${NC}"
    echo "  Additional devices can be added via device trees"
    echo "  Community contributions welcome"
    echo
    echo -e "${CYAN}Adding New Devices:${NC}"
    echo "  1. Create device tree in device_trees/"
    echo "  2. Add kernel source configuration"
    echo "  3. Extract vendor blobs"
    echo "  4. Update devices.json configuration"
    echo "  5. Test and submit PR"
}

# Clean build environment
clean_environment() {
    print_step "Cleaning AFOT build environment..."
    
    echo "What would you like to clean?"
    echo "1) Build outputs only"
    echo "2) ccache"
    echo "3) Everything (sources + outputs)"
    echo "4) Cancel"
    
    read -p "Choose option [1-4]: " clean_option
    
    case $clean_option in
        1)
            print_info "Cleaning build outputs..."
            rm -rf "$HOME/android/*/out" 2>/dev/null || true
            rm -rf "$HOME/android/afot/builds/*" 2>/dev/null || true
            print_success "Build outputs cleaned"
            ;;
        2)
            print_info "Cleaning ccache..."
            ccache -C 2>/dev/null || true
            print_success "ccache cleaned"
            ;;
        3)
            print_warning "This will delete ALL Android sources and builds!"
            read -p "Are you sure? (type 'yes' to confirm): " confirm
            if [[ "$confirm" == "yes" ]]; then
                print_info "Cleaning everything..."
                rm -rf "$HOME/android" 2>/dev/null || true
                rm -rf "$HOME/.ccache" 2>/dev/null || true
                print_success "Everything cleaned"
            else
                print_info "Cancelled"
            fi
            ;;
        4)
            print_info "Cancelled"
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Main function
main() {
    print_banner
    
    print_info "Welcome to AFOT Custom Android OS Quick Start!"
    print_info "This script will help you build and flash your custom ROM."
    echo
    
    check_root
    check_requirements
    
    while true; do
        show_menu
        read -p "Choose an option [1-8]: " choice
        
        case $choice in
            1)
                setup_environment
                ;;
            2)
                build_gsi
                ;;
            3)
                build_device_rom
                ;;
            4)
                flash_rom
                ;;
            5)
                run_tests
                ;;
            6)
                show_devices
                ;;
            7)
                clean_environment
                ;;
            8)
                print_info "Thank you for using AFOT!"
                print_info "Visit https://github.com/afot/afot-android-os for updates"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-8."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"

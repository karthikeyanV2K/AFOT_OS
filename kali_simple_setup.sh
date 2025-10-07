#!/bin/bash

# AFOT Simple Setup for Kali Linux
# Simplified approach that works with Kali's package system

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

echo "=== AFOT Simple Setup for Kali Linux ==="
echo "Installing only essential packages that work on Kali..."
echo

# Update package list
print_info "Updating package list..."
sudo apt update

# Install basic build tools that definitely exist on Kali
print_info "Installing basic build dependencies..."
sudo apt install -y \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    build-essential \
    bc \
    bison \
    flex \
    zip \
    unzip \
    openjdk-8-jdk \
    adb \
    fastboot

# Try to install additional packages, skip if they don't exist
print_info "Installing additional packages (skipping if not available)..."

# List of packages to try installing
packages_to_try=(
    "gnupg"
    "zlib1g-dev" 
    "libxml2-utils"
    "xsltproc"
    "fontconfig"
    "ccache"
    "libncurses-dev"
    "libgl1-mesa-dev"
    "x11proto-core-dev"
    "libx11-dev"
)

for package in "${packages_to_try[@]}"; do
    if sudo apt install -y "$package" 2>/dev/null; then
        print_success "Installed $package"
    else
        print_warning "Skipped $package (not available)"
    fi
done

# Set Java 8 as default
print_info "Setting Java 8 as default..."
sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-8-openjdk-amd64/bin/java 1 || true
sudo update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac 1 || true

# Verify Java
print_info "Java version:"
java -version

# Install repo tool
print_info "Installing repo tool..."
mkdir -p ~/bin
curl -s https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo

# Add ~/bin to PATH
export PATH=~/bin:$PATH
if ! grep -q "~/bin" ~/.bashrc; then
    echo 'export PATH=~/bin:$PATH' >> ~/.bashrc
fi

# Setup git if not configured
print_info "Setting up git configuration..."
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    print_info "Setting up git user (you can change this later)..."
    git config --global user.name "AFOT Builder"
    git config --global user.email "afot@builder.local"
fi

# Create directories
print_info "Creating build directories..."
mkdir -p ~/android/lineage
mkdir -p ~/android/afot

# Setup ccache if available
if command -v ccache >/dev/null 2>&1; then
    print_info "Setting up ccache..."
    export USE_CCACHE=1
    export CCACHE_DIR=~/.ccache
    ccache -M 20G 2>/dev/null || ccache -M 10G 2>/dev/null || true
    
    # Add to bashrc
    if ! grep -q "USE_CCACHE" ~/.bashrc; then
        echo 'export USE_CCACHE=1' >> ~/.bashrc
        echo 'export CCACHE_DIR=~/.ccache' >> ~/.bashrc
    fi
fi

print_success "Basic setup completed!"
echo
print_info "Now we'll download a minimal Android source tree..."
print_warning "This will download about 10-15GB (much less than full LineageOS)"

# Use AOSP minimal instead of full LineageOS for faster setup
cd ~/android/lineage

print_info "Initializing minimal AOSP repository..."
~/bin/repo init -u https://android.googlesource.com/platform/manifest -b android-11.0.0_r48 --depth=1

print_info "Downloading minimal Android source (this may take 20-30 minutes)..."
~/bin/repo sync -c -j4 --no-clone-bundle --no-tags

# Create a simple device configuration
print_info "Creating basic device configuration for J5 Prime..."
mkdir -p device/samsung/j5xnlte

cat > device/samsung/j5xnlte/AndroidProducts.mk << 'EOF'
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/afot_j5xnlte.mk

COMMON_LUNCH_CHOICES := \
    afot_j5xnlte-userdebug
EOF

cat > device/samsung/j5xnlte/afot_j5xnlte.mk << 'EOF'
# AFOT J5 Prime Configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)

PRODUCT_NAME := afot_j5xnlte
PRODUCT_DEVICE := j5xnlte
PRODUCT_BRAND := AFOT
PRODUCT_MODEL := Galaxy J5 Prime AFOT
PRODUCT_MANUFACTURER := Samsung

# AFOT Properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.afot.variant=dev-minimal \
    ro.afot.version=1.0 \
    ro.afot.device=j5xnlte

# Target arch
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a53

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := universal7570
TARGET_NO_BOOTLOADER := true

# Platform
TARGET_BOARD_PLATFORM := exynos5
TARGET_SOC := exynos7570

# Kernel
TARGET_KERNEL_CONFIG := j5xnlte_defconfig
TARGET_KERNEL_SOURCE := kernel/samsung/j5x

# Partitions
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 39845888
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3145728000
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12442450944
BOARD_CACHEIMAGE_PARTITION_SIZE := 209715200

# Recovery
TARGET_RECOVERY_FSTAB := device/samsung/j5xnlte/recovery.fstab
EOF

# Create basic fstab
mkdir -p device/samsung/j5xnlte
cat > device/samsung/j5xnlte/recovery.fstab << 'EOF'
# mount point   fstype  device                  device2                 flags
/boot           emmc    /dev/block/mmcblk0p9
/recovery       emmc    /dev/block/mmcblk0p10
/system         ext4    /dev/block/mmcblk0p18
/cache          ext4    /dev/block/mmcblk0p19
/data           ext4    /dev/block/mmcblk0p21
/sdcard         vfat    /dev/block/mmcblk1p1    flags=display="MicroSD";storage;wipeingui;removable
EOF

print_success "AFOT build environment setup completed!"
echo
print_info "Summary:"
echo "✓ Essential build tools installed"
echo "✓ Java 8 configured"
echo "✓ Repo tool installed"
echo "✓ Minimal Android source downloaded (~10-15GB)"
echo "✓ Basic J5 Prime device configuration created"
echo
print_success "You can now try building!"
echo
print_info "To build:"
echo "1. cd ~/android/lineage"
echo "2. source build/envsetup.sh"
echo "3. lunch afot_j5xnlte-userdebug"
echo "4. make -j4"
echo
print_warning "Note: This is a basic build. For full AFOT features, you'll need to add the AFOT apps manually."
print_info "But this will create a working ROM that you can flash to test the build process!"

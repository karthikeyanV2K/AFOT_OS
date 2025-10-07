#!/bin/bash

# AFOT Setup Fix for Kali Linux
# Fixes dependency issues and completes the setup

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

echo "=== AFOT Setup Fix for Kali Linux ==="
echo "Fixing dependency issues and completing setup..."
echo

# Fix missing dependencies for Kali Linux
print_info "Installing missing dependencies for Kali Linux..."

# Install bc (calculator) - was missing
sudo apt update
sudo apt install -y bc

# Install correct packages for Kali Linux
sudo apt install -y \
    git \
    gnupg \
    flex \
    bison \
    build-essential \
    zip \
    curl \
    zlib1g-dev \
    gcc-multilib \
    g++-multilib \
    libc6-dev-i386 \
    libncurses-dev \
    lib32ncurses6-dev \
    x11proto-core-dev \
    libx11-dev \
    lib32z1-dev \
    libgl1-mesa-dev \
    libxml2-utils \
    xsltproc \
    unzip \
    fontconfig \
    python3 \
    python3-pip \
    adb \
    fastboot

# Install Java 8 for Kali
print_info "Installing Java 8..."
sudo apt install -y openjdk-8-jdk openjdk-8-jre

# Set Java 8 as default
sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-8-openjdk-amd64/bin/java 1
sudo update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-8-openjdk-amd64/bin/javac 1

# Verify Java installation
print_info "Verifying Java installation..."
java -version
javac -version

# Install repo tool
print_info "Installing repo tool..."
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo

# Add ~/bin to PATH
if ! grep -q "~/bin" ~/.bashrc; then
    echo 'export PATH=~/bin:$PATH' >> ~/.bashrc
fi
export PATH=~/bin:$PATH

# Setup git configuration
print_info "Setting up git configuration..."
if [ -z "$(git config --global user.name)" ]; then
    echo "Please enter your name for git:"
    read -r git_name
    git config --global user.name "$git_name"
fi

if [ -z "$(git config --global user.email)" ]; then
    echo "Please enter your email for git:"
    read -r git_email
    git config --global user.email "$git_email"
fi

# Create Android directory structure
print_info "Creating Android build directories..."
mkdir -p ~/android/lineage
mkdir -p ~/android/afot

# Setup ccache
print_info "Setting up ccache for faster builds..."
sudo apt install -y ccache
export USE_CCACHE=1
export CCACHE_DIR=~/.ccache
ccache -M 50G

# Add ccache to bashrc
if ! grep -q "USE_CCACHE" ~/.bashrc; then
    echo 'export USE_CCACHE=1' >> ~/.bashrc
    echo 'export CCACHE_DIR=~/.ccache' >> ~/.bashrc
fi

# Initialize LineageOS repository
print_info "Initializing LineageOS repository (this will take time)..."
cd ~/android/lineage

# Initialize repo for LineageOS 18.1 (Android 11) - compatible with J5 Prime
repo init -u https://github.com/LineageOS/android.git -b lineage-18.1 --depth=1

print_info "Downloading LineageOS source code (this will take 30-60 minutes)..."
print_warning "This downloads ~50GB of data. Make sure you have good internet connection."

# Sync repository with multiple jobs for faster download
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags

# Download device tree for J5 Prime
print_info "Setting up device tree for Samsung J5 Prime..."
cd ~/android/lineage/.repo/local_manifests
cat > j5xnlte.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Samsung J5 Prime device tree -->
  <project name="LineageOS/android_device_samsung_j5xnlte" path="device/samsung/j5xnlte" remote="github" revision="lineage-18.1" />
  <project name="LineageOS/android_device_samsung_j5x-common" path="device/samsung/j5x-common" remote="github" revision="lineage-18.1" />
  <project name="LineageOS/android_kernel_samsung_j5x" path="kernel/samsung/j5x" remote="github" revision="lineage-18.1" />
  <project name="TheMuppets/proprietary_vendor_samsung" path="vendor/samsung" remote="github" revision="lineage-18.1" />
</manifest>
EOF

# Sync device-specific repositories
print_info "Downloading device-specific files for J5 Prime..."
cd ~/android/lineage
repo sync -c -j$(nproc) --force-sync

# Setup build environment
print_info "Setting up build environment..."
cd ~/android/lineage
source build/envsetup.sh

# Create AFOT device configuration
print_info "Creating AFOT device configuration..."
mkdir -p device/afot/j5xnlte-dev-minimal

# Copy AFOT configuration
cp ~/AFOT_OS/variants/afot_dev_minimal_config.mk device/afot/j5xnlte-dev-minimal/device.mk

# Create AndroidProducts.mk
cat > device/afot/j5xnlte-dev-minimal/AndroidProducts.mk << 'EOF'
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/device.mk

COMMON_LUNCH_CHOICES := \
    afot_j5xnlte_dev_minimal-userdebug
EOF

print_success "AFOT build environment setup completed!"
echo
print_info "Summary of what was installed:"
echo "✓ All build dependencies for Kali Linux"
echo "✓ Java 8 JDK"
echo "✓ Repo tool"
echo "✓ LineageOS 18.1 source code (~50GB)"
echo "✓ Samsung J5 Prime device tree"
echo "✓ AFOT device configuration"
echo "✓ ccache for faster builds"
echo
print_success "You can now build AFOT Developer + Minimal OS!"
echo
print_info "Next steps:"
echo "1. cd ~/android/lineage"
echo "2. source build/envsetup.sh"
echo "3. lunch afot_j5xnlte_dev_minimal-userdebug"
echo "4. mka bacon"
echo
print_warning "First build will take 2-4 hours. Subsequent builds will be faster."

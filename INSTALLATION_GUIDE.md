# AFOT Custom Android OS - Installation Guide

This comprehensive guide will walk you through building and installing AFOT Custom Android OS with enhanced music player and modern lock system.

## 📋 Prerequisites

### Hardware Requirements
- **Host System**: Linux PC (Ubuntu 20.04+ recommended)
- **RAM**: 16GB+ (8GB minimum, will be slower)
- **Storage**: 200GB+ free space
- **CPU**: Multi-core processor (8+ cores recommended)
- **Target Device**: Supported Android device (see device list)

### Software Requirements
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y git-core gnupg flex bison build-essential zip curl \
  zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
  libncurses5 libncurses5-dev x11proto-core-dev libx11-dev \
  openjdk-11-jdk python3 python3-pip ccache rsync unzip bc \
  bison flex make gcc g++ libssl-dev libxml2-utils xsltproc \
  imagemagick schedtool e2fsprogs util-linux

# Install Android tools
sudo apt install -y android-tools-adb android-tools-fastboot

# Install flashing tools
sudo apt install -y heimdall-flash-frontend
```

## 🚀 Quick Installation

### Option 1: Automated Setup (Recommended)
```bash
# Clone AFOT repository
git clone https://github.com/afot/afot-android-os.git
cd afot-android-os

# Make quick start script executable
chmod +x quick_start.sh

# Run interactive setup
./quick_start.sh
```

### Option 2: Manual Setup
Follow the detailed steps below for manual installation.

## 🔧 Manual Installation Steps

### Step 1: Environment Setup

```bash
# Create Android directory structure
mkdir -p ~/android/{lineage,aosp,afot}

# Clone AFOT repository
git clone https://github.com/afot/afot-android-os.git ~/android/afot
cd ~/android/afot

# Run environment setup
chmod +x setup_android_build.sh
./setup_android_build.sh
```

### Step 2: Source Code Download

#### For GSI (Generic System Image):
```bash
# Initialize AOSP repository
cd ~/android/aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r1 --git-lfs

# Sync sources (this takes 2-4 hours)
repo sync -j$(nproc)
```

#### For Device-Specific ROM:
```bash
# Initialize LineageOS repository
cd ~/android/lineage
repo init -u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs

# Sync sources (this takes 2-4 hours)
repo sync -j$(nproc)
```

### Step 3: Device Configuration

#### Add Device Trees (for device-specific builds):
```bash
# Create local manifests directory
mkdir -p ~/android/lineage/.repo/local_manifests

# Example: Samsung J5 Prime
cat > ~/android/lineage/.repo/local_manifests/j5xnlte.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <project name="LineageOS/android_device_samsung_j5xnlte" 
             path="device/samsung/j5xnlte" 
             remote="github" 
             revision="lineage-20.0" />
    
    <project name="LineageOS/android_kernel_samsung_exynos7570" 
             path="kernel/samsung/exynos7570" 
             remote="github" 
             revision="lineage-20.0" />
    
    <project name="TheMuppets/proprietary_vendor_samsung" 
             path="vendor/samsung" 
             remote="github" 
             revision="lineage-20.0" />
</manifest>
EOF

# Sync device-specific repos
repo sync
```

### Step 4: Build Process

#### Build GSI:
```bash
# Source environment
cd ~/android/aosp
source build/envsetup.sh

# Build ARM64 GSI
lunch aosp_arm64_ab-userdebug
make -j$(nproc) systemimage

# Build ARM32 GSI (optional)
lunch aosp_arm_ab-userdebug
make -j$(nproc) systemimage
```

#### Build Device-Specific ROM:
```bash
# Source environment
cd ~/android/lineage
source build/envsetup.sh

# Example: Build for Samsung J5 Prime
lunch lineage_j5xnlte-userdebug
mka bacon
```

### Step 5: Automated Build (Alternative)

```bash
# Use AFOT build script for GSI
python3 ~/android/afot/build_scripts/build_afot_rom.py \
  --device gsi \
  --jobs $(nproc) \
  --output ~/android/afot/builds

# Use AFOT build script for device ROM
python3 ~/android/afot/build_scripts/build_afot_rom.py \
  --device j5xnlte \
  --source lineage \
  --jobs $(nproc) \
  --sign \
  --ota \
  --output ~/android/afot/builds
```

## 📱 Device Preparation

### Samsung Devices (J5 Prime, J5 2015)

#### Enable Developer Options:
1. Go to **Settings → About phone**
2. Tap **Build number** 7 times
3. Go back to **Settings → Developer options**
4. Enable **USB debugging**
5. Enable **OEM unlocking**

#### Enter Download Mode:
1. Power off device
2. Hold **Power + Home + Volume Down**
3. Press **Volume Up** to confirm
4. Connect USB cable

### Google Pixel Devices

#### Enable Developer Options:
1. Go to **Settings → About phone**
2. Tap **Build number** 7 times
3. Go back to **Settings → System → Developer options**
4. Enable **USB debugging**
5. Enable **OEM unlocking**

#### Unlock Bootloader:
```bash
# Boot to fastboot mode (Power + Volume Down)
adb reboot bootloader

# Unlock bootloader (WIPES DATA!)
fastboot flashing unlock

# Reboot
fastboot reboot
```

## 🔥 Flashing Process

### Method 1: Universal Flash Tool (Recommended)
```bash
# Auto-detect device and flash
python3 ~/android/afot/flash_tools/afot_flash.py \
  ~/android/afot/builds/afot_*.zip

# Manual device specification
python3 ~/android/afot/flash_tools/afot_flash.py \
  --device j5xnlte \
  --wipe-data \
  ~/android/afot/builds/afot_j5xnlte_*.zip
```

### Method 2: Manual Flashing

#### Samsung Devices (Heimdall):
```bash
# Extract images from ROM zip
unzip afot_j5xnlte_*.zip

# Flash with Heimdall
heimdall flash \
  --BOOT boot.img \
  --RECOVERY recovery.img \
  --SYSTEM system.img \
  --USERDATA userdata.img \
  --CACHE cache.img \
  --reboot
```

#### Google Devices (Fastboot):
```bash
# Boot to fastboot mode
adb reboot bootloader

# Flash images
fastboot flash boot boot.img
fastboot flash system system.img
fastboot flash vendor vendor.img
fastboot flash userdata userdata.img

# Reboot
fastboot reboot
```

#### GSI Flashing:
```bash
# Boot to fastboot mode
adb reboot bootloader

# Flash GSI system image
fastboot flash system afot_gsi_*.img

# Reboot
fastboot reboot
```

## ✅ Post-Installation

### First Boot
- **Time**: First boot takes 5-10 minutes
- **Setup**: Follow AFOT setup wizard
- **Apps**: AFOT Music Player and Lock System will be pre-installed

### Verification
```bash
# Run AFOT test suite
python3 ~/android/afot/testing/afot_test_suite.py \
  --categories system audio security \
  --priorities high
```

### Enable AFOT Features
1. **Music Player**: 
   - Open AFOT Music Player
   - Grant storage permissions
   - Configure audio preferences

2. **Lock System**:
   - Go to Settings → Security → Screen lock
   - Select "AFOT Lock System"
   - Configure biometric authentication

## 🔧 Troubleshooting

### Build Issues

#### Out of Memory:
```bash
# Reduce parallel jobs
export JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx2G"
make -j4 bacon  # Use fewer jobs
```

#### Missing Dependencies:
```bash
# Install missing packages
sudo apt install -y <missing-package>

# Update repo tool
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
```

#### Sync Failures:
```bash
# Clean and retry
repo sync --force-sync -j$(nproc)

# If still failing, try single thread
repo sync -j1
```

### Flash Issues

#### Device Not Detected:
```bash
# Check USB connection
lsusb

# Restart ADB server
adb kill-server
adb start-server

# Check device status
adb devices
fastboot devices
```

#### Permission Denied:
```bash
# Add user to plugdev group
sudo usermod -a -G plugdev $USER

# Create udev rules
sudo tee /etc/udev/rules.d/51-android.rules << 'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

#### Samsung Download Mode Issues:
```bash
# Install Samsung USB drivers (if on Windows)
# Use different USB cable
# Try different USB port
# Ensure device is in proper download mode
```

### Runtime Issues

#### Boot Loop:
1. Boot to recovery mode
2. Wipe cache partition
3. If still failing, factory reset
4. Re-flash ROM

#### Missing Audio:
1. Check audio permissions in Settings
2. Restart AFOT Music Service
3. Clear app cache and data

#### Lock System Not Working:
1. Enable device admin for AFOT Lock System
2. Grant overlay permissions
3. Check biometric hardware compatibility

## 📊 Performance Optimization

### Build Performance
```bash
# Use ccache
export USE_CCACHE=1
export CCACHE_DIR=~/.ccache
ccache -M 50G

# Optimize make flags
export MAKEFLAGS="-j$(nproc)"

# Use prebuilt tools
export USE_PREBUILT_CACHE=1
```

### Runtime Performance
```bash
# Enable performance mode
adb shell setprop ro.afot.performance.mode performance

# Optimize Dalvik
adb shell setprop dalvik.vm.dex2oat-threads 4
adb shell setprop dalvik.vm.image-dex2oat-threads 4
```

## 🛡️ Security Considerations

### Before Flashing
- **Backup**: Create complete device backup
- **EFS**: Backup EFS partition (Samsung devices)
- **Stock ROM**: Download stock firmware for recovery

### After Installation
- **Root**: AFOT ROM is not rooted by default
- **Bootloader**: Keep bootloader unlocked for updates
- **Security**: Enable lockscreen security
- **Updates**: Check for AFOT updates regularly

## 📞 Support

### Community Support
- **XDA Forums**: Device-specific discussions
- **GitHub Issues**: Bug reports and feature requests
- **Telegram**: @afot_rom for real-time support
- **Discord**: https://discord.gg/afot

### Documentation
- **Build Guide**: [docs/building.md](docs/building.md)
- **API Reference**: [docs/api/](docs/api/)
- **Troubleshooting**: [docs/troubleshooting.md](docs/troubleshooting.md)

---

**⚠️ Important Disclaimers:**
- Installing custom ROM voids warranty
- Risk of device damage if done incorrectly
- Always backup important data
- Follow device-specific instructions exactly

**Made with ❤️ by the AFOT Team**

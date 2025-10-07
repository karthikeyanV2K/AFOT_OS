# How to Build AFOT Developer + Minimal OS

## 🚀 **Complete Build Process for Samsung J5 Prime**

### **Step 1: System Requirements**

#### **Hardware Requirements:**
- **CPU**: 4+ cores (8+ cores recommended)
- **RAM**: 16GB minimum (32GB recommended)
- **Storage**: 200GB+ free space (SSD recommended)
- **Internet**: Stable connection for downloading source code

#### **Operating System:**
- **Linux**: Ubuntu 20.04/22.04 (recommended)
- **Windows**: WSL2 with Ubuntu
- **macOS**: 10.15+ with Xcode Command Line Tools

### **Step 2: Install Dependencies**

#### **For Ubuntu/Debian:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build dependencies
sudo apt install -y git-core gnupg flex bison build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 libncurses5 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig python3 python3-pip

# Install Java 8 (required for Android builds)
sudo apt install -y openjdk-8-jdk

# Set Java 8 as default
sudo update-alternatives --config java
sudo update-alternatives --config javac
```

#### **For Windows (WSL2):**
```bash
# Install WSL2 Ubuntu first, then run Ubuntu commands above
# Also install Windows ADB drivers separately
```

### **Step 3: Setup Build Environment**

```bash
# Navigate to AFOT directory
cd AFOT_MP3

# Make setup script executable
chmod +x setup_android_build.sh

# Run the setup (this takes 1-2 hours)
./setup_android_build.sh
```

**What this does:**
- Downloads LineageOS source code (~50GB)
- Sets up repo tool
- Configures ccache for faster builds
- Downloads device trees for J5 Prime
- Sets up build environment

### **Step 4: Build Your Custom Variant**

#### **Option A: Quick Build (Recommended)**
```bash
# Navigate to variants directory
cd variants

# Build Developer + Minimal variant
python3 build_dev_minimal.py

# When prompted, type 'y' to start building
```

#### **Option B: Manual Build Process**
```bash
# Navigate to LineageOS source
cd ~/android/lineage

# Setup environment
source build/envsetup.sh

# Choose your device and build type
lunch lineage_j5xnlte-userdebug

# Set AFOT build flags
export AFOT_DEV_MINIMAL_BUILD=true
export AFOT_SECURITY_ENHANCED=true

# Start building (takes 2-4 hours)
mka bacon
```

### **Step 5: Monitor Build Progress**

#### **Build Time Estimates:**
- **First Build**: 3-5 hours (downloads + compilation)
- **Subsequent Builds**: 30-60 minutes (incremental)
- **Clean Builds**: 2-3 hours

#### **Monitor Commands:**
```bash
# Check build progress
tail -f ~/android/lineage/out/build.log

# Monitor system resources
htop

# Check disk space
df -h
```

### **Step 6: Build Output**

#### **Successful Build Location:**
```bash
# ROM file will be created at:
~/android/lineage/out/target/product/j5xnlte/lineage-*.zip

# Renamed to:
~/android/lineage/out/target/product/j5xnlte/afot-dev-minimal-j5prime-[timestamp].zip
```

#### **Build Artifacts:**
- **ROM ZIP**: Main flashable file (~800MB-1.2GB)
- **Boot Image**: boot.img
- **Recovery Image**: recovery.img
- **System Image**: system.img

### **Step 7: Flash to Device**

#### **Automatic Flashing:**
```bash
# Use AFOT flash tool
cd AFOT_MP3
python3 flash_tools/afot_flash.py variants/builds/afot-dev-minimal-j5prime-*.zip --device j5xnlte
```

#### **Manual Flashing (Odin/Heimdall):**
```bash
# Put J5 Prime in Download Mode:
# Power + Home + Volume Down, then Volume Up

# Flash with Heimdall (Linux)
heimdall flash --BOOT boot.img --RECOVERY recovery.img --SYSTEM system.img --reboot

# Or use Odin on Windows with the .tar file
```

## 🛠 **Detailed Build Commands**

### **Complete Build Script:**
```bash
#!/bin/bash
# Complete AFOT Developer + Minimal Build Script

echo "Starting AFOT Developer + Minimal build..."

# Step 1: Setup environment
cd ~/android/lineage
source build/envsetup.sh

# Step 2: Clean previous builds (optional)
make clean

# Step 3: Setup device
lunch lineage_j5xnlte-userdebug

# Step 4: Set AFOT configuration
export AFOT_VARIANT=dev-minimal
export AFOT_DEVICE=j5xnlte
export AFOT_SECURITY_ENHANCED=true
export AFOT_DEVELOPER_MODE=true

# Step 5: Start build
echo "Building AFOT Developer + Minimal OS..."
time mka bacon

# Step 6: Check build result
if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    ls -la out/target/product/j5xnlte/*.zip
else
    echo "❌ Build failed!"
    exit 1
fi
```

### **Save this as `build_afot.sh` and run:**
```bash
chmod +x build_afot.sh
./build_afot.sh
```

## 🔧 **Troubleshooting Common Issues**

### **Build Errors:**

#### **"Out of memory" Error:**
```bash
# Reduce parallel jobs
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4g"

# Or build with fewer jobs
mka bacon -j4
```

#### **"No space left on device":**
```bash
# Check disk space
df -h

# Clean ccache
ccache -C

# Clean build output
make clean
```

#### **"repo sync" Fails:**
```bash
# Resume interrupted sync
repo sync -c -j4 --force-sync --no-clone-bundle

# Reset and retry
repo forall -c 'git reset --hard'
repo sync -c -j4
```

### **Java Issues:**
```bash
# Check Java version (should be 8)
java -version

# Set correct Java version
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

### **Permission Issues:**
```bash
# Fix permissions
sudo chown -R $USER:$USER ~/android/

# Set correct permissions
find ~/android/ -type d -exec chmod 755 {} \;
find ~/android/ -type f -exec chmod 644 {} \;
```

## ⚡ **Build Optimization Tips**

### **Speed Up Builds:**
```bash
# Use ccache (already configured in setup)
export USE_CCACHE=1
export CCACHE_DIR=~/.ccache
ccache -M 50G

# Use more CPU cores
export ANDROID_COMPILE_WITH_JACK=true
export ANDROID_JACK_VM_ARGS="-Xmx8g"

# Build specific modules only
mka systemimage
mka bootimage
```

### **Reduce Build Size:**
```bash
# Minimal build flags
export AFOT_MINIMAL_BUILD=true
export TARGET_BUILD_VARIANT=user
export PRODUCT_MINIMIZE_JAVA_DEBUG_INFO=true
```

## 📊 **Build Status Verification**

### **Check Build Success:**
```bash
# Verify ROM file exists
ls -la ~/android/lineage/out/target/product/j5xnlte/lineage-*.zip

# Check ROM size (should be 800MB-1.2GB)
du -h ~/android/lineage/out/target/product/j5xnlte/lineage-*.zip

# Verify build properties
unzip -p lineage-*.zip system/build.prop | grep ro.afot
```

### **Test ROM Before Flashing:**
```bash
# Extract and check contents
unzip -l lineage-*.zip | grep -E "(boot.img|system.img|recovery.img)"

# Verify AFOT apps are included
unzip -l lineage-*.zip | grep -i afot
```

## 🎯 **Expected Results**

### **What You'll Get:**
- ✅ **ROM File**: afot-dev-minimal-j5prime-[timestamp].zip
- ✅ **Size**: ~1GB (much smaller than stock Samsung)
- ✅ **Apps**: 10 essential apps (vs 100+ stock)
- ✅ **Features**: Music + Phone + SMS + Camera + Emergency + Dev Tools + Security
- ✅ **Battery**: 1.5-2 days usage
- ✅ **Performance**: Smooth on 1.5GB RAM

### **Build Time Summary:**
- **Setup**: 1-2 hours (one time)
- **First Build**: 3-5 hours
- **Incremental Builds**: 30-60 minutes
- **Total Project Time**: 4-7 hours

---

**🚀 Ready to build your perfect J5 Prime OS? Just follow these steps and you'll have AFOT Developer + Minimal running in a few hours!**

*Essential apps + Developer tools + Security features + Amazing battery life = Perfect productivity phone* 🔧📱🔒

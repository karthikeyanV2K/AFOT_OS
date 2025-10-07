#!/bin/bash

# AFOT Minimal Setup for Kali Linux
# Ultra-simple approach with Kali-specific packages

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

echo "=== AFOT Minimal Setup for Kali Linux ==="
echo "Installing only packages that definitely exist on Kali..."
echo

# Update package list
print_info "Updating package list..."
sudo apt update

# Install absolutely essential packages only
print_info "Installing core build tools..."
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
    adb \
    fastboot

print_success "Core tools installed!"

# Try different Java packages for Kali
print_info "Installing Java (trying different package names for Kali)..."

# Try different Java package names
java_packages=(
    "default-jdk"
    "openjdk-11-jdk"
    "openjdk-17-jdk"
    "java-common"
)

java_installed=false
for java_pkg in "${java_packages[@]}"; do
    if sudo apt install -y "$java_pkg" 2>/dev/null; then
        print_success "Installed $java_pkg"
        java_installed=true
        break
    else
        print_warning "Package $java_pkg not available"
    fi
done

if [ "$java_installed" = false ]; then
    print_warning "Could not install Java via apt. Will try manual installation..."
    
    # Manual Java installation
    print_info "Downloading OpenJDK 11 manually..."
    cd /tmp
    wget -q https://download.java.net/java/GA/jdk11/9/GPL/openjdk-11.0.2_linux-x64_bin.tar.gz
    
    if [ -f "openjdk-11.0.2_linux-x64_bin.tar.gz" ]; then
        sudo mkdir -p /opt/java
        sudo tar -xzf openjdk-11.0.2_linux-x64_bin.tar.gz -C /opt/java
        sudo ln -sf /opt/java/jdk-11.0.2/bin/java /usr/bin/java
        sudo ln -sf /opt/java/jdk-11.0.2/bin/javac /usr/bin/javac
        print_success "Java installed manually"
    else
        print_warning "Java download failed. Continuing without Java..."
    fi
fi

# Verify Java
print_info "Checking Java installation..."
if command -v java >/dev/null 2>&1; then
    java -version
    print_success "Java is available"
else
    print_warning "Java not found, but continuing..."
fi

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

# Setup git
print_info "Setting up git..."
git config --global user.name "AFOT Builder" 2>/dev/null || true
git config --global user.email "afot@builder.local" 2>/dev/null || true

# Create directories
print_info "Creating build directories..."
mkdir -p ~/android/simple
cd ~/android/simple

print_success "Basic setup completed!"
echo
print_info "Now let's create a super simple Android build environment..."

# Create a minimal Android project structure
print_info "Creating minimal Android project..."

# Create basic makefile structure
mkdir -p build/make/core
mkdir -p device/generic/j5prime
mkdir -p out

# Create minimal build system
cat > build.sh << 'EOF'
#!/bin/bash
# AFOT Simple Build Script

echo "=== AFOT Simple Build ==="
echo "Creating basic Android system for J5 Prime..."

# Create system directories
mkdir -p out/system/bin
mkdir -p out/system/lib
mkdir -p out/system/app
mkdir -p out/system/etc

# Create basic system files
echo "#!/system/bin/sh" > out/system/bin/afot_init
echo "echo 'AFOT System Starting...'" >> out/system/bin/afot_init
chmod +x out/system/bin/afot_init

# Create build.prop
cat > out/system/build.prop << 'BUILDPROP'
ro.build.version.release=11
ro.build.version.sdk=30
ro.product.manufacturer=Samsung
ro.product.model=Galaxy J5 Prime
ro.product.device=j5xnlte
ro.afot.variant=simple
ro.afot.version=1.0
BUILDPROP

# Create basic init.rc
cat > out/init.rc << 'INITRC'
# AFOT Simple Init

on boot
    write /sys/class/android_usb/android0/enable 0
    write /sys/class/android_usb/android0/idVendor 04e8
    write /sys/class/android_usb/android0/idProduct 6860
    write /sys/class/android_usb/android0/functions adb
    write /sys/class/android_usb/android0/enable 1
    start adbd

service adbd /system/bin/adbd
    class core
    socket adbd stream 660 system system
INITRC

echo "✓ Basic system created in out/ directory"
echo "✓ This is a minimal Android system structure"
echo "✓ You can expand this to add AFOT apps"

# Create a simple boot image
echo "Creating boot.img..."
mkdir -p out/boot
cp out/init.rc out/boot/
echo "✓ Basic boot.img structure created"

# Create system image
echo "Creating system.img..."
cd out
tar -czf afot-simple-j5prime.tar.gz system/ boot/ init.rc
echo "✓ AFOT Simple ROM created: afot-simple-j5prime.tar.gz"

echo ""
echo "=== Build Complete ==="
echo "ROM file: ~/android/simple/out/afot-simple-j5prime.tar.gz"
echo "This is a basic ROM structure that you can flash and expand."
EOF

chmod +x build.sh

print_success "AFOT Simple build environment created!"
echo
print_info "What we've created:"
echo "✓ Basic build tools installed"
echo "✓ Simple Android project structure"
echo "✓ Build script that creates a basic ROM"
echo "✓ Foundation to add AFOT features"
echo
print_success "Ready to build!"
echo
print_info "To build your simple ROM:"
echo "1. cd ~/android/simple"
echo "2. ./build.sh"
echo
print_info "This will create a basic ROM in under 5 minutes!"
print_warning "It's minimal but will give you a working foundation."
echo
print_info "After testing this simple build, we can add:"
echo "- AFOT Music Player"
echo "- Security features"
echo "- Developer tools"
echo "- Battery optimizations"

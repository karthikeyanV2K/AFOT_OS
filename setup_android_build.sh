#!/bin/bash

# AFOT Custom Android OS Build Environment Setup
# Supports both GSI (Generic System Image) and device-specific builds
# Optimized for scalability across multiple devices

set -e

echo "=== AFOT Custom Android OS Build Environment Setup ==="
echo "Setting up comprehensive build environment for custom ROM development"

# Configuration
ANDROID_ROOT="$HOME/android"
LINEAGE_ROOT="$ANDROID_ROOT/lineage"
AOSP_ROOT="$ANDROID_ROOT/aosp"
AFOT_ROOT="$ANDROID_ROOT/afot"
CCACHE_SIZE="50G"
JAVA_VERSION="11"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
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

# Check if running on supported OS
check_os() {
    print_status "Checking operating system compatibility..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_success "Linux detected - proceeding with setup"
        
        # Check Ubuntu version
        if command -v lsb_release &> /dev/null; then
            UBUNTU_VERSION=$(lsb_release -rs)
            print_status "Ubuntu version: $UBUNTU_VERSION"
            
            if [[ $(echo "$UBUNTU_VERSION >= 20.04" | bc -l) -eq 1 ]]; then
                print_success "Ubuntu version is compatible"
            else
                print_warning "Ubuntu version may not be fully supported. Recommended: 20.04+"
            fi
        fi
    else
        print_error "This script requires Linux. For Windows, use WSL2 with Ubuntu 20.04+"
        exit 1
    fi
}

# Install required packages
install_dependencies() {
    print_status "Installing Android build dependencies..."
    
    # Update package lists
    sudo apt update
    
    # Essential build packages
    sudo apt install -y \
        git-core gnupg flex bison build-essential zip curl \
        zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
        libncurses5 libncurses5-dev x11proto-core-dev libx11-dev \
        openjdk-${JAVA_VERSION}-jdk python3 python3-pip ccache \
        rsync unzip bc bison flex make gcc g++ \
        libssl-dev libxml2-utils xsltproc \
        imagemagick schedtool e2fsprogs util-linux \
        android-tools-adb android-tools-fastboot \
        python-is-python3 git-lfs
    
    # Additional tools for device development
    sudo apt install -y \
        heimdall-flash-frontend \
        android-sdk-platform-tools \
        qemu-user-static \
        binfmt-support
    
    print_success "Dependencies installed successfully"
}

# Setup repo tool
setup_repo() {
    print_status "Setting up repo tool..."
    
    mkdir -p ~/bin
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
    chmod a+x ~/bin/repo
    
    # Add to PATH if not already there
    if ! echo $PATH | grep -q "$HOME/bin"; then
        echo 'export PATH=~/bin:$PATH' >> ~/.bashrc
        export PATH=~/bin:$PATH
    fi
    
    print_success "Repo tool installed"
}

# Configure git
configure_git() {
    print_status "Configuring git for Android development..."
    
    # Check if git is already configured
    if ! git config --global user.name &> /dev/null; then
        echo "Enter your name for git commits:"
        read -r GIT_NAME
        git config --global user.name "$GIT_NAME"
    fi
    
    if ! git config --global user.email &> /dev/null; then
        echo "Enter your email for git commits:"
        read -r GIT_EMAIL
        git config --global user.email "$GIT_EMAIL"
    fi
    
    # Optimize git for large repositories
    git config --global core.preloadindex true
    git config --global core.fscache true
    git config --global gc.auto 256
    
    print_success "Git configured"
}

# Setup ccache for faster builds
setup_ccache() {
    print_status "Configuring ccache for faster builds..."
    
    # Set ccache size
    ccache -M $CCACHE_SIZE
    
    # Add ccache to PATH
    if ! echo $PATH | grep -q "/usr/lib/ccache"; then
        echo 'export PATH="/usr/lib/ccache:$PATH"' >> ~/.bashrc
        export PATH="/usr/lib/ccache:$PATH"
    fi
    
    # Configure ccache
    echo 'export USE_CCACHE=1' >> ~/.bashrc
    echo "export CCACHE_DIR=$HOME/.ccache" >> ~/.bashrc
    export USE_CCACHE=1
    export CCACHE_DIR=$HOME/.ccache
    
    print_success "ccache configured with ${CCACHE_SIZE} cache"
}

# Create directory structure
create_directories() {
    print_status "Creating Android build directory structure..."
    
    mkdir -p "$ANDROID_ROOT"
    mkdir -p "$LINEAGE_ROOT"
    mkdir -p "$AOSP_ROOT"
    mkdir -p "$AFOT_ROOT"
    mkdir -p "$AFOT_ROOT/apps"
    mkdir -p "$AFOT_ROOT/device_trees"
    mkdir -p "$AFOT_ROOT/kernels"
    mkdir -p "$AFOT_ROOT/vendor_blobs"
    mkdir -p "$AFOT_ROOT/tools"
    mkdir -p "$AFOT_ROOT/builds"
    
    print_success "Directory structure created"
}

# Initialize LineageOS source
init_lineage() {
    print_status "Initializing LineageOS source tree..."
    
    cd "$LINEAGE_ROOT"
    
    # Initialize repo with LineageOS manifest
    repo init -u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs
    
    print_success "LineageOS repo initialized"
    print_warning "Run 'repo sync -j$(nproc)' to download sources (this will take time)"
}

# Initialize AOSP source for GSI builds
init_aosp() {
    print_status "Initializing AOSP source tree for GSI builds..."
    
    cd "$AOSP_ROOT"
    
    # Initialize repo with AOSP manifest
    repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r1 --git-lfs
    
    print_success "AOSP repo initialized"
    print_warning "Run 'repo sync -j$(nproc)' to download sources (this will take time)"
}

# Create build helper scripts
create_build_scripts() {
    print_status "Creating build helper scripts..."
    
    # GSI build script
    cat > "$AFOT_ROOT/build_gsi.sh" << 'EOF'
#!/bin/bash
# AFOT GSI Build Script

set -e

AOSP_ROOT="$HOME/android/aosp"
BUILD_TYPE="userdebug"

echo "=== Building AFOT GSI ==="

cd "$AOSP_ROOT"

# Setup environment
source build/envsetup.sh

# Build GSI targets
echo "Building ARM64 GSI..."
lunch aosp_arm64_ab-${BUILD_TYPE}
make -j$(nproc) systemimage

echo "Building ARM32 GSI..."
lunch aosp_arm_ab-${BUILD_TYPE}
make -j$(nproc) systemimage

echo "GSI builds completed!"
echo "Images available in: $AOSP_ROOT/out/target/product/"
EOF

    # Device-specific build script template
    cat > "$AFOT_ROOT/build_device.sh" << 'EOF'
#!/bin/bash
# AFOT Device-Specific Build Script

set -e

LINEAGE_ROOT="$HOME/android/lineage"
DEVICE_CODENAME="${1:-}"
BUILD_TYPE="${2:-userdebug}"

if [ -z "$DEVICE_CODENAME" ]; then
    echo "Usage: $0 <device_codename> [build_type]"
    echo "Example: $0 j5nlte userdebug"
    exit 1
fi

echo "=== Building AFOT ROM for $DEVICE_CODENAME ==="

cd "$LINEAGE_ROOT"

# Setup environment
source build/envsetup.sh

# Lunch target
lunch lineage_${DEVICE_CODENAME}-${BUILD_TYPE}

# Build
mka bacon

echo "Build completed for $DEVICE_CODENAME!"
echo "ROM package: $LINEAGE_ROOT/out/target/product/$DEVICE_CODENAME/"
EOF

    # Make scripts executable
    chmod +x "$AFOT_ROOT/build_gsi.sh"
    chmod +x "$AFOT_ROOT/build_device.sh"
    
    print_success "Build scripts created"
}

# Create environment setup script
create_env_script() {
    print_status "Creating environment setup script..."
    
    cat > "$AFOT_ROOT/setup_env.sh" << 'EOF'
#!/bin/bash
# AFOT Development Environment Setup

# Android build environment
export ANDROID_ROOT="$HOME/android"
export LINEAGE_ROOT="$ANDROID_ROOT/lineage"
export AOSP_ROOT="$ANDROID_ROOT/aosp"
export AFOT_ROOT="$ANDROID_ROOT/afot"

# Build optimization
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
export CCACHE_EXEC="/usr/bin/ccache"

# Java
export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"

# Add tools to PATH
export PATH="$HOME/bin:$PATH"
export PATH="/usr/lib/ccache:$PATH"

# Android SDK (if installed)
if [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
    export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
    export PATH="$ANDROID_SDK_ROOT/tools:$PATH"
fi

echo "AFOT development environment loaded"
echo "Android root: $ANDROID_ROOT"
echo "ccache status: $(ccache -s | head -1)"
EOF

    chmod +x "$AFOT_ROOT/setup_env.sh"
    
    # Add to bashrc
    echo "source $AFOT_ROOT/setup_env.sh" >> ~/.bashrc
    
    print_success "Environment setup script created"
}

# Main execution
main() {
    echo "Starting AFOT Android OS build environment setup..."
    echo "This will install dependencies and configure the build environment."
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    check_os
    install_dependencies
    setup_repo
    configure_git
    setup_ccache
    create_directories
    create_build_scripts
    create_env_script
    
    print_success "=== AFOT Build Environment Setup Complete ==="
    echo
    echo "Next steps:"
    echo "1. Source the environment: source ~/.bashrc"
    echo "2. Initialize sources:"
    echo "   - LineageOS: cd $LINEAGE_ROOT && repo sync -j\$(nproc)"
    echo "   - AOSP GSI: cd $AOSP_ROOT && repo sync -j\$(nproc)"
    echo "3. Add device trees to local_manifests/"
    echo "4. Build GSI: $AFOT_ROOT/build_gsi.sh"
    echo "5. Build device ROM: $AFOT_ROOT/build_device.sh <codename>"
    echo
    echo "Total disk space required: ~200GB for full setup"
    echo "Build time: 2-6 hours depending on hardware"
}

# Run main function
main "$@"

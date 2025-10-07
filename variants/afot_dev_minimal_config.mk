# AFOT Developer + Minimal Hybrid Configuration
# Combines essential apps with developer tools and security features
# Target: 1.5-2 days battery life with development capabilities

PRODUCT_NAME := afot_dev_minimal
PRODUCT_DEVICE := j5xnlte
PRODUCT_BRAND := AFOT
PRODUCT_MODEL := Galaxy J5 Prime Dev-Minimal
PRODUCT_MANUFACTURER := Samsung

# AFOT Variant Configuration
PRODUCT_PROPERTY_OVERRIDES += \
    ro.afot.variant=dev-minimal \
    ro.afot.version=1.0 \
    ro.afot.battery_optimized=true \
    ro.afot.developer_mode=true \
    ro.afot.security_enhanced=true \
    ro.afot.build.type=dev-minimal

# Essential Apps (Minimal Base)
PRODUCT_PACKAGES += \
    AFOTMusicPlayer \
    AFOTPhone \
    AFOTMessages \
    AFOTCamera \
    AFOTEmergency

# Developer Tools
PRODUCT_PACKAGES += \
    AFOTTerminal \
    AFOTCodeEditor \
    AFOTFileManager \
    AFOTLogViewer \
    AFOTSystemMonitor \
    AFOTADBTools

# Security Features
PRODUCT_PACKAGES += \
    AFOTLockSystem \
    AFOTBiometric \
    AFOTPatternLock \
    AFOTSecurityCenter

# System Utilities (Developer Essentials)
PRODUCT_PACKAGES += \
    Calculator \
    Clock \
    Settings \
    AFOTPackageManager

# Remove all bloatware and unnecessary services
PRODUCT_PACKAGES_REMOVE += \
    Browser \
    Email \
    Gallery \
    MusicFX \
    SoundRecorder \
    VideoPlayer \
    Calendar \
    Contacts \
    Downloads \
    DrmProvider \
    HTMLViewer \
    LiveWallpapers \
    MagicSmokeWallpapers \
    NoiseField \
    PhaseBeam \
    PhotoTable \
    PicoTts \
    PrintSpooler \
    Provision \
    QuickSearchBox \
    SpeechRecorder \
    VoiceDialer \
    WallpaperCropper

# Battery Optimization Properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.low_ram=true \
    ro.config.max_starting_bg=8 \
    ro.sys.fw.bg_apps_limit=16 \
    ro.config.avoid_gfx_accel=false \
    debug.sf.hw=1 \
    debug.egl.hw=1 \
    debug.composition.type=c2d \
    debug.enabletr=true \
    debug.overlayui.enable=1 \
    debug.qctwa.statusbar=1 \
    debug.qctwa.preservebuf=1 \
    persist.sys.ui.hw=1

# Developer Mode Properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.debuggable=1 \
    ro.adb.secure=0 \
    ro.secure=0 \
    ro.allow.mock.location=1 \
    persist.service.adb.enable=1 \
    persist.service.debuggable=1 \
    persist.sys.usb.config=mtp,adb

# Security Properties (Enhanced but Developer-Friendly)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.afot.security.biometric=true \
    ro.afot.security.pattern=true \
    ro.afot.security.pin=true \
    ro.afot.security.face=false \
    ro.afot.security.developer_unlock=true

# Memory and Performance Optimization
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.heapstartsize=8m \
    dalvik.vm.heapgrowthlimit=96m \
    dalvik.vm.heapsize=256m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=2m \
    dalvik.vm.heapmaxfree=8m

# Audio Optimization (for music player)
PRODUCT_PROPERTY_OVERRIDES += \
    audio.offload.disable=1 \
    ro.config.media_vol_steps=25 \
    ro.config.vc_call_vol_steps=7

# Developer Tools Configuration
PRODUCT_COPY_FILES += \
    device/afot/dev-minimal/configs/terminal_config.conf:system/etc/afot/terminal.conf \
    device/afot/dev-minimal/configs/editor_config.conf:system/etc/afot/editor.conf \
    device/afot/dev-minimal/configs/adb_config.conf:system/etc/afot/adb.conf

# Security Configuration Files
PRODUCT_COPY_FILES += \
    device/afot/dev-minimal/configs/biometric_config.xml:system/etc/afot/biometric.xml \
    device/afot/dev-minimal/configs/lock_patterns.xml:system/etc/afot/lock_patterns.xml

# SELinux Policies (Developer-friendly but secure)
BOARD_SEPOLICY_DIRS += \
    device/afot/dev-minimal/sepolicy

# Include AFOT common configuration
$(call inherit-product, device/afot/common/afot_common.mk)

# Include minimal device tree
$(call inherit-product, device/samsung/j5xnlte/device.mk)

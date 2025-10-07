# AFOT Custom ROM - Common Device Configuration
# This file contains common configurations for all AFOT-supported devices

# AFOT Version Info
AFOT_VERSION_MAJOR := 1
AFOT_VERSION_MINOR := 0
AFOT_VERSION_PATCH := 0
AFOT_VERSION_SUFFIX := ALPHA

AFOT_VERSION := $(AFOT_VERSION_MAJOR).$(AFOT_VERSION_MINOR).$(AFOT_VERSION_PATCH)
ifneq ($(AFOT_VERSION_SUFFIX),)
    AFOT_VERSION := $(AFOT_VERSION)-$(AFOT_VERSION_SUFFIX)
endif

AFOT_BUILD_DATE := $(shell date +%Y%m%d)
AFOT_BUILD_TIME := $(shell date +%H%M%S)
AFOT_BUILD_TIMESTAMP := $(AFOT_BUILD_DATE)_$(AFOT_BUILD_TIME)

# Product Properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.afot.version=$(AFOT_VERSION) \
    ro.afot.build.date=$(AFOT_BUILD_DATE) \
    ro.afot.build.timestamp=$(AFOT_BUILD_TIMESTAMP) \
    ro.afot.device=$(TARGET_DEVICE) \
    ro.afot.display.version=AFOT-$(AFOT_VERSION)-$(TARGET_DEVICE)-$(AFOT_BUILD_DATE)

# AFOT System Apps
PRODUCT_PACKAGES += \
    AFOTMusicPlayer \
    AFOTLockSystem \
    AFOTSettings \
    AFOTLauncher \
    AFOTFileManager \
    AFOTCamera

# AFOT Privileged Apps (system/priv-app)
PRODUCT_PACKAGES += \
    AFOTSystemUI \
    AFOTFramework \
    AFOTServices

# Audio Enhancements
PRODUCT_PACKAGES += \
    AudioFX \
    AFOTAudioService \
    libafotaudio

# Security Features
PRODUCT_PACKAGES += \
    AFOTSecurityProvider \
    AFOTBiometricService

# Performance Optimizations
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.max_starting_bg=8 \
    ro.sys.fw.bg_apps_limit=24 \
    ro.config.dha_cached_max=16 \
    ro.config.dha_empty_max=42 \
    ro.config.dha_lmk_scale=0.545 \
    ro.config.sdha_apps_bg_max=64 \
    ro.config.sdha_apps_bg_min=8

# Battery Optimizations
PRODUCT_PROPERTY_OVERRIDES += \
    ro.ril.disable.power.collapse=0 \
    power.saving.mode=1 \
    pm.sleep_mode=1 \
    ro.config.hw_power_saving=1

# Audio Configuration
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.media_vol_steps=25 \
    ro.config.vc_call_vol_steps=7 \
    audio.deep_buffer.media=true \
    audio.offload.video=true \
    audio.offload.pcm.16bit.enable=true \
    audio.offload.pcm.24bit.enable=true \
    audio.offload.track.enable=false \
    audio.deep_buffer.media=true \
    audio.playback.mch.downsample=true \
    audio.safx.pbe.enabled=true \
    audio.parser.ip.buffer.size=262144

# Bluetooth Audio
PRODUCT_PROPERTY_OVERRIDES += \
    bluetooth.hfp.client=1 \
    bluetooth.sap.enable=true \
    bluetooth.dun.enable=true \
    bluetooth.map.enable=true \
    bluetooth.pbap.enable=true \
    bluetooth.opp.enable=true \
    bluetooth.hsp.ag.enable=true \
    bluetooth.a2dp.sink.enable=true \
    bluetooth.avrcpct.enable=true

# Display & UI
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=320 \
    ro.opengles.version=196610 \
    debug.sf.hw=1 \
    debug.egl.hw=1 \
    debug.composition.type=c2d \
    debug.mdpcomp.logs=0 \
    dev.pm.dyn_samplingrate=1 \
    persist.demo.hdmirotationlock=false

# Memory Management
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.fha_enable=true \
    ro.sys.fw.bg_apps_limit=32 \
    ro.config.dha_cached_max=16 \
    ro.config.dha_empty_max=42 \
    ro.config.dha_lmk_scale=0.545 \
    ro.config.dha_th_rate=2.3 \
    ro.config.sdha_apps_bg_max=64 \
    ro.config.sdha_apps_bg_min=8

# Network Optimizations
PRODUCT_PROPERTY_OVERRIDES += \
    net.tcp.buffersize.default=4096,87380,110208,4096,16384,110208 \
    net.tcp.buffersize.wifi=524288,1048576,2097152,262144,524288,1048576 \
    net.tcp.buffersize.lte=524288,1048576,2097152,262144,524288,1048576 \
    net.tcp.buffersize.umts=4094,87380,110208,4096,16384,110208 \
    net.tcp.buffersize.hspa=4094,87380,1220608,4096,16384,1220608 \
    net.tcp.buffersize.hsupa=4094,87380,1220608,4096,16384,1220608 \
    net.tcp.buffersize.hsdpa=4094,87380,2441216,4096,16384,2441216 \
    net.tcp.buffersize.edge=4093,26280,35040,4096,16384,35040 \
    net.tcp.buffersize.gprs=4092,8760,11680,4096,8760,11680

# Dalvik VM Optimizations
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.heapstartsize=16m \
    dalvik.vm.heapgrowthlimit=256m \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=2m \
    dalvik.vm.heapmaxfree=8m

# AFOT Custom Features
PRODUCT_PROPERTY_OVERRIDES += \
    ro.afot.music.enhanced_audio=true \
    ro.afot.lock.biometric_support=true \
    ro.afot.ui.animation_scale=1.0 \
    ro.afot.performance.mode=balanced \
    ro.afot.security.level=high

# Permissions for AFOT Apps
PRODUCT_COPY_FILES += \
    device/afot/common/permissions/com.afot.musicplayer.xml:system/etc/permissions/com.afot.musicplayer.xml \
    device/afot/common/permissions/com.afot.locksystem.xml:system/etc/permissions/com.afot.locksystem.xml \
    device/afot/common/permissions/privapp-permissions-afot.xml:system/etc/permissions/privapp-permissions-afot.xml

# SELinux Policies for AFOT
BOARD_SEPOLICY_DIRS += \
    device/afot/common/sepolicy

# AFOT Audio Effects
PRODUCT_COPY_FILES += \
    device/afot/common/audio/audio_effects.conf:system/etc/audio_effects.conf \
    device/afot/common/audio/audio_policy.conf:system/etc/audio_policy.conf

# AFOT Boot Animation
PRODUCT_COPY_FILES += \
    device/afot/common/media/bootanimation.zip:system/media/bootanimation.zip

# AFOT Sounds
PRODUCT_COPY_FILES += \
    device/afot/common/audio/alarms:system/media/audio/alarms \
    device/afot/common/audio/notifications:system/media/audio/notifications \
    device/afot/common/audio/ringtones:system/media/audio/ringtones \
    device/afot/common/audio/ui:system/media/audio/ui

# Build Properties
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=afot \
    BUILD_FINGERPRINT=AFOT/$(TARGET_DEVICE)/$(TARGET_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(AFOT_BUILD_TIMESTAMP):user/release-keys \
    PRIVATE_BUILD_DESC="AFOT $(AFOT_VERSION) for $(TARGET_DEVICE)"

# OTA Configuration
PRODUCT_PROPERTY_OVERRIDES += \
    ro.afot.ota.server=https://ota.afot.dev \
    ro.afot.ota.channel=stable \
    ro.afot.updater.uri=https://updates.afot.dev/api/v1/

# Security Patches
PRODUCT_PROPERTY_OVERRIDES += \
    ro.build.version.security_patch=2024-01-01

# Vendor Security Patch (if applicable)
VENDOR_SECURITY_PATCH := 2024-01-01

# AFOT Specific Build Flags
TARGET_AFOT_BUILD := true
AFOT_ENHANCED_AUDIO := true
AFOT_BIOMETRIC_LOCK := true
AFOT_PERFORMANCE_MODE := true

# Include GApps (optional - can be disabled)
# AFOT_INCLUDE_GAPPS := true

# Include AFOT Apps source or prebuilt
AFOT_APPS_SOURCE := true

# Custom kernel configuration
TARGET_KERNEL_CONFIG := afot_defconfig

# Custom recovery
TARGET_RECOVERY_FSTAB := device/afot/common/recovery.fstab

# AFOT Minimal OS Configuration for Samsung J5 Prime
# Ultra-lightweight ROM focused on essential features only
# Optimized for maximum battery life and minimal resource usage

# AFOT Minimal Version Info
AFOT_MINIMAL_VERSION := 1.0.0-MINIMAL
AFOT_MINIMAL_CODENAME := "BatteryLife"

# Target Device
TARGET_DEVICE := j5xnlte
TARGET_ARCH := arm
TARGET_CPU_ABI := armeabi-v7a

# Minimal Android Base (Go Edition optimized)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.low_ram=true \
    ro.lmk.use_minfree_levels=true \
    ro.lmk.kill_heaviest_task=true \
    ro.config.avoid_gfx_accel=true

# AFOT Minimal Core Apps ONLY
PRODUCT_PACKAGES += \
    AFOTMusicPlayerLite \
    AFOTPhone \
    AFOTMessages \
    AFOTCamera \
    AFOTEmergency \
    AFOTSettings

# Remove ALL unnecessary system apps
PRODUCT_PACKAGES += \
    RemovePackages

# Essential system services only
PRODUCT_PACKAGES += \
    BasicSystemUI \
    MinimalLauncher \
    EssentialServices

# Battery Optimization (Aggressive)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.hw_power_saving=1 \
    power.saving.mode=1 \
    pm.sleep_mode=1 \
    ro.ril.disable.power.collapse=0 \
    ro.config.hw_quickpoweron=true \
    persist.vendor.radio.enable_voicecall=1 \
    persist.vendor.radio.calls.on.ims=0

# Memory Management (Ultra Conservative)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.fha_enable=true \
    ro.sys.fw.bg_apps_limit=8 \
    ro.config.dha_cached_max=4 \
    ro.config.dha_empty_max=8 \
    ro.config.dha_lmk_scale=0.8 \
    dalvik.vm.heapstartsize=8m \
    dalvik.vm.heapgrowthlimit=96m \
    dalvik.vm.heapsize=128m \
    dalvik.vm.heaptargetutilization=0.8 \
    dalvik.vm.heapminfree=1m \
    dalvik.vm.heapmaxfree=4m

# Disable unnecessary features
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.disable_bluetooth_a2dp=false \
    ro.config.disable_wifi_display=true \
    ro.config.disable_nfc=true \
    ro.config.disable_location=false \
    ro.config.disable_sync=true \
    ro.config.disable_backup=true

# Audio Optimization (Minimal but quality)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.media_vol_steps=15 \
    audio.deep_buffer.media=false \
    audio.offload.disable=true \
    ro.config.hw_music_lp=true

# Network Optimization
PRODUCT_PROPERTY_OVERRIDES += \
    ro.telephony.call_ring.multiple=false \
    ro.config.hw_fast_dormancy=1 \
    net.tcp.buffersize.default=4096,65536,131072,4096,16384,131072

# Display Power Saving
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=240 \
    debug.sf.hw=0 \
    debug.egl.hw=0 \
    ro.config.hw_sensorhub=false

# Remove Google Services (Battery Drain)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.nogapps=true \
    ro.setupwizard.mode=DISABLED

# Essential Permissions Only
PRODUCT_COPY_FILES += \
    device/afot/minimal/permissions/essential_permissions.xml:system/etc/permissions/essential_permissions.xml

# Minimal SELinux (Security with Performance)
BOARD_SEPOLICY_DIRS += \
    device/afot/minimal/sepolicy

# Build Flags for Minimal OS
TARGET_AFOT_MINIMAL := true
AFOT_REMOVE_BLOAT := true
AFOT_BATTERY_FIRST := true
AFOT_ESSENTIAL_ONLY := true

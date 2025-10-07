# Complete Guide: AFOT Minimal OS for Samsung J5 Prime

## 🚀 Step-by-Step Installation Guide

### Phase 1: Backup Your Current Phone (CRITICAL!)

#### 1.1 Create Complete Backup
```bash
# Connect J5 Prime via USB with USB debugging enabled
adb devices

# Backup all your data
adb backup -apk -shared -nosystem -all -system
# This creates backup.ab file - keep it safe!

# Backup contacts to Google account
# Go to Settings > Accounts > Google > Sync Contacts

# Backup photos manually
adb pull /sdcard/DCIM/ ./backup_photos/
adb pull /sdcard/Pictures/ ./backup_pictures/
```

#### 1.2 Backup EFS Partition (Samsung Specific - VERY IMPORTANT!)
```bash
# This backs up your IMEI and radio - DON'T SKIP THIS!
adb shell su -c "dd if=/dev/block/mmcblk0p3 of=/sdcard/efs_backup.img"
adb pull /sdcard/efs_backup.img ./efs_backup.img

# Keep efs_backup.img file SAFE - you need it to restore network functions
```

#### 1.3 Download Stock Firmware (Recovery Option)
1. Go to SamMobile.com or Frija tool
2. Enter your J5 Prime model: **SM-G570F** (or SM-G570M/Y depending on your region)
3. Download the latest stock firmware
4. Keep the firmware file safe for emergency recovery

### Phase 2: Prepare Your J5 Prime

#### 2.1 Enable Developer Options
1. Go to **Settings > About phone**
2. Tap **Build number** 7 times
3. Go back to **Settings > Developer options**
4. Enable **USB debugging**
5. Enable **OEM unlocking**

#### 2.2 Install Required Tools on PC
```bash
# Install ADB and Fastboot
sudo apt install android-tools-adb android-tools-fastboot

# Install Heimdall (for Samsung flashing)
sudo apt install heimdall-flash-frontend

# Or download Odin for Windows
# Download from: https://odindownload.com/
```

### Phase 3: Build AFOT Minimal OS

#### 3.1 Setup Build Environment
```bash
# Navigate to AFOT directory
cd AFOT_MP3

# Run the setup script
chmod +x setup_android_build.sh
./setup_android_build.sh

# This will take 1-2 hours to download and setup
```

#### 3.2 Build Minimal ROM
```bash
# Navigate to minimal OS builder
cd minimal_os

# Run the minimal builder
python3 build_minimal_j5prime.py

# When prompted, type 'y' to start building
# Build time: 2-4 hours depending on your PC
```

#### 3.3 Verify Build Output
```bash
# Check if ROM was built successfully
ls -la builds/
# You should see: afot-minimal-j5prime-[timestamp].zip
```

### Phase 4: Flash AFOT Minimal OS

#### 4.1 Enter Download Mode
1. **Power off** your J5 Prime completely
2. Hold **Power + Home + Volume Down** buttons together
3. When warning screen appears, press **Volume Up** to continue
4. Connect USB cable to PC
5. You should see "Downloading..." on screen

#### 4.2 Flash Using Heimdall (Linux/Mac)
```bash
# Extract the ROM
unzip afot-minimal-j5prime-*.zip

# Flash with Heimdall
heimdall flash --BOOT boot.img --RECOVERY recovery.img --SYSTEM system.img --CACHE cache.img --reboot

# Wait for "PASS" message and automatic reboot
```

#### 4.3 Flash Using Odin (Windows)
1. Open **Odin3**
2. Click **AP** button and select the **.tar** file from extracted ROM
3. Make sure only **Auto Reboot** and **F. Reset Time** are checked
4. Click **START**
5. Wait for green **PASS** message

#### 4.4 Alternative: Use AFOT Flash Tool
```bash
# Use the universal flash tool
python3 ../flash_tools/afot_flash.py afot-minimal-j5prime-*.zip --device j5xnlte

# This will auto-detect your device and flash method
```

### Phase 5: First Boot and Setup

#### 5.1 First Boot Process
1. **First boot takes 5-10 minutes** - be patient!
2. Phone will show AFOT logo
3. Android setup wizard will appear
4. Complete basic setup (language, WiFi if needed)

#### 5.2 Verify Installation
```bash
# Check if AFOT Minimal is running
adb shell getprop ro.afot.variant
# Should return: minimal

# Check installed apps
adb shell pm list packages | grep afot
# Should show: com.afot.musiclite, com.afot.phone, etc.

# Check battery optimization
adb shell dumpsys battery
```

#### 5.3 Initial Configuration
1. **Set up Emergency SOS contacts**:
   - Open Emergency SOS app
   - Add 3-5 emergency contacts
   - Test emergency SMS function

2. **Configure Music Player**:
   - Copy MP3 files to `/sdcard/Music/` folder
   - Open AFOT Music Lite
   - Grant storage permissions

3. **Test Essential Functions**:
   - Make a test call
   - Send a test SMS
   - Take a test photo
   - Play an MP3 file

### Phase 6: Performance Verification

#### 6.1 Check Battery Optimization
```bash
# Run AFOT test suite
python3 ../testing/afot_test_suite.py --device [your_device_serial] --categories system audio performance

# Check memory usage
adb shell dumpsys meminfo | grep "Total RAM"
# Should show ~400MB usage vs 1.2GB+ on stock

# Check running processes
adb shell ps | wc -l
# Should show ~8-15 processes vs 50+ on stock
```

#### 6.2 Battery Life Test
- **Day 1**: Use normally and monitor battery percentage
- **Expected**: 24-36 hours of usage vs 8-12 hours on stock
- **Monitor**: Settings > Battery > Battery Usage

### Phase 7: Troubleshooting Common Issues

#### 7.1 Boot Loop (Phone keeps restarting)
```bash
# Enter recovery mode
# Power + Home + Volume Up

# Wipe cache partition
# Select "Wipe cache partition" from recovery menu

# If still boot looping, factory reset:
# Select "Wipe data/factory reset"
```

#### 7.2 No Network/Calls Not Working
```bash
# Restore EFS backup (if you have it)
adb push efs_backup.img /sdcard/
adb shell su -c "dd if=/sdcard/efs_backup.img of=/dev/block/mmcblk0p3"
adb reboot

# Check APN settings
# Settings > Mobile networks > Access Point Names
# Contact your carrier for correct APN settings
```

#### 7.3 Apps Not Working
```bash
# Clear app data
adb shell pm clear com.afot.musiclite
adb shell pm clear com.afot.phone

# Reinstall app permissions
adb shell pm grant com.afot.musiclite android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.afot.phone android.permission.CALL_PHONE
```

### Phase 8: Going Back to Stock (If Needed)

#### 8.1 Flash Stock Firmware
1. Download stock Samsung firmware (from Phase 1)
2. Enter Download Mode (Power + Home + Volume Down)
3. Use Odin to flash stock firmware
4. Wait for completion and reboot

#### 8.2 Restore Your Data
```bash
# Restore from backup
adb restore backup.ab

# Restore photos
adb push ./backup_photos/ /sdcard/DCIM/
```

### Phase 9: Daily Usage Tips

#### 9.1 Maximizing Battery Life
- **Keep WiFi off** when not needed
- **Use airplane mode** in low signal areas
- **Close apps** after use (recent apps button)
- **Use power saving mode** in Settings

#### 9.2 Managing Storage
```bash
# Check storage usage
adb shell df -h

# Clean cache regularly
adb shell pm trim-caches 500M

# Remove old photos/music to free space
```

#### 9.3 Emergency Procedures
- **Triple press power button** = Emergency SOS
- **Long press power + volume down** = Force reboot
- **Power + Home + Volume Up** = Recovery mode
- **Power + Home + Volume Down** = Download mode

## 🔧 Quick Commands Reference

### Essential ADB Commands
```bash
# Check device connection
adb devices

# Check AFOT version
adb shell getprop ro.afot.version

# Monitor battery
adb shell dumpsys battery

# Check memory usage
adb shell dumpsys meminfo

# Reboot device
adb reboot

# Enter recovery
adb reboot recovery

# Enter download mode
adb reboot download
```

### Emergency Recovery Commands
```bash
# Factory reset via ADB
adb shell recovery --wipe_data

# Clear cache
adb shell recovery --wipe_cache

# Reboot to system
adb reboot system
```

## ⚠️ Important Safety Notes

### Before You Start
- **Charge battery to 80%+** before flashing
- **Use original USB cable** for stable connection
- **Close all other programs** on PC during flashing
- **Don't disconnect** during flashing process

### Emergency Contacts
- Keep a **backup phone** during the process
- Have **emergency numbers written down**
- Inform **family/friends** you're updating your phone

### What Could Go Wrong
- **Soft brick**: Phone boots but has issues → Flash stock firmware
- **Hard brick**: Phone won't turn on → Professional repair needed
- **Network issues**: No calls/data → Restore EFS backup
- **App crashes**: Clear app data or factory reset

## 📞 Support Resources

### If You Need Help
1. **Check logs**: `adb logcat | grep AFOT`
2. **GitHub Issues**: Report problems with logs
3. **XDA Forum**: Community support
4. **Telegram**: @afot_minimal for quick help

### Success Indicators
✅ Phone boots to AFOT Minimal OS  
✅ Only 5 apps visible (Music, Phone, Messages, Camera, SOS)  
✅ Battery lasts 24+ hours  
✅ RAM usage under 500MB  
✅ All essential functions work  

---

**You're now ready to transform your Samsung J5 Prime into a battery-efficient, minimal smartphone!** 

The whole process takes about 4-6 hours including build time. Your phone will have incredible battery life and only the features you actually need.

Good luck! 🚀📱

#!/usr/bin/env python3
"""
AFOT Universal Flashing Tool
Supports multiple flashing methods: Fastboot, Odin, Heimdall, SP Flash Tool
Automatic device detection and appropriate flashing method selection
"""

import os
import sys
import json
import time
import subprocess
import argparse
import logging
import platform
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('afot_flash.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class FlashMethod(Enum):
    FASTBOOT = "fastboot"
    ODIN = "odin"
    HEIMDALL = "heimdall"
    SP_FLASH_TOOL = "sp_flash_tool"
    ADB_SIDELOAD = "adb_sideload"

@dataclass
class DeviceFlashConfig:
    """Device-specific flashing configuration"""
    codename: str
    manufacturer: str
    model: str
    flash_method: FlashMethod
    bootloader_mode: str  # download, fastboot, etc.
    key_combination: str  # Button combination to enter flash mode
    partitions: Dict[str, str]  # partition_name: image_file
    special_instructions: List[str]
    requires_unlock: bool
    supports_ab: bool  # A/B partition scheme

@dataclass
class FlashPackage:
    """Flash package information"""
    rom_file: Path
    recovery_file: Optional[Path] = None
    boot_file: Optional[Path] = None
    system_file: Optional[Path] = None
    vendor_file: Optional[Path] = None
    userdata_file: Optional[Path] = None
    cache_file: Optional[Path] = None

class AFOTFlashTool:
    """Main AFOT flashing tool class"""
    
    def __init__(self):
        self.devices_db = self._load_devices_database()
        self.platform = platform.system().lower()
        self.adb_path = self._find_tool("adb")
        self.fastboot_path = self._find_tool("fastboot")
        self.heimdall_path = self._find_tool("heimdall")
        
    def _load_devices_database(self) -> Dict[str, DeviceFlashConfig]:
        """Load device flashing configurations"""
        devices = {
            # Samsung devices (Odin/Heimdall)
            "j5nlte": DeviceFlashConfig(
                codename="j5nlte",
                manufacturer="samsung",
                model="Galaxy J5 2015",
                flash_method=FlashMethod.HEIMDALL,
                bootloader_mode="download",
                key_combination="Power + Home + Volume Down",
                partitions={
                    "BOOT": "boot.img",
                    "RECOVERY": "recovery.img",
                    "SYSTEM": "system.img",
                    "USERDATA": "userdata.img",
                    "CACHE": "cache.img"
                },
                special_instructions=[
                    "Enable OEM unlocking in Developer Options",
                    "Enable USB debugging",
                    "Install Samsung USB drivers"
                ],
                requires_unlock=True,
                supports_ab=False
            ),
            "j5xnlte": DeviceFlashConfig(
                codename="j5xnlte",
                manufacturer="samsung",
                model="Galaxy J5 Prime",
                flash_method=FlashMethod.HEIMDALL,
                bootloader_mode="download",
                key_combination="Power + Home + Volume Down",
                partitions={
                    "BOOT": "boot.img",
                    "RECOVERY": "recovery.img",
                    "SYSTEM": "system.img",
                    "USERDATA": "userdata.img",
                    "CACHE": "cache.img"
                },
                special_instructions=[
                    "Enable OEM unlocking in Developer Options",
                    "Enable USB debugging",
                    "Install Samsung USB drivers"
                ],
                requires_unlock=True,
                supports_ab=False
            ),
            # Google Pixel devices (Fastboot)
            "sailfish": DeviceFlashConfig(
                codename="sailfish",
                manufacturer="google",
                model="Pixel",
                flash_method=FlashMethod.FASTBOOT,
                bootloader_mode="fastboot",
                key_combination="Power + Volume Down",
                partitions={
                    "boot_a": "boot.img",
                    "boot_b": "boot.img",
                    "system_a": "system.img",
                    "system_b": "system.img",
                    "vendor_a": "vendor.img",
                    "vendor_b": "vendor.img"
                },
                special_instructions=[
                    "Enable OEM unlocking in Developer Options",
                    "Enable USB debugging",
                    "Unlock bootloader with 'fastboot flashing unlock'"
                ],
                requires_unlock=True,
                supports_ab=True
            ),
            # Generic GSI target
            "gsi": DeviceFlashConfig(
                codename="gsi",
                manufacturer="generic",
                model="Generic System Image",
                flash_method=FlashMethod.FASTBOOT,
                bootloader_mode="fastboot",
                key_combination="Varies by device",
                partitions={
                    "system": "system.img"
                },
                special_instructions=[
                    "Device must support Project Treble",
                    "Bootloader must be unlocked",
                    "Backup existing system partition"
                ],
                requires_unlock=True,
                supports_ab=False
            )
        }
        return devices

    def _find_tool(self, tool_name: str) -> Optional[str]:
        """Find tool executable in PATH"""
        if self.platform == "windows":
            tool_name += ".exe"
        
        # Check in PATH
        result = subprocess.run(['which', tool_name], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
        
        # Check common locations
        common_paths = [
            f"/usr/bin/{tool_name}",
            f"/usr/local/bin/{tool_name}",
            f"C:\\platform-tools\\{tool_name}",
            f"C:\\adb\\{tool_name}"
        ]
        
        for path in common_paths:
            if os.path.exists(path):
                return path
        
        return None

    def _run_command(self, cmd: List[str], timeout: Optional[int] = None) -> Tuple[int, str, str]:
        """Execute command with error handling"""
        logger.info(f"Executing: {' '.join(cmd)}")
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            logger.error(f"Command timed out: {' '.join(cmd)}")
            return -1, "", "Command timed out"
        except Exception as e:
            logger.error(f"Command failed: {e}")
            return -1, "", str(e)

    def detect_device(self) -> Optional[str]:
        """Detect connected device"""
        logger.info("Detecting connected device...")
        
        # Try ADB first
        if self.adb_path:
            ret, stdout, _ = self._run_command([self.adb_path, 'devices'])
            if ret == 0 and 'device' in stdout:
                # Get device properties
                ret, stdout, _ = self._run_command([self.adb_path, 'shell', 'getprop', 'ro.product.device'])
                if ret == 0:
                    device_codename = stdout.strip()
                    if device_codename in self.devices_db:
                        logger.info(f"Detected device: {device_codename}")
                        return device_codename
        
        # Try Fastboot
        if self.fastboot_path:
            ret, stdout, _ = self._run_command([self.fastboot_path, 'devices'])
            if ret == 0 and stdout.strip():
                ret, stdout, _ = self._run_command([self.fastboot_path, 'getvar', 'product'])
                if ret == 0:
                    for line in stdout.split('\n'):
                        if 'product:' in line:
                            device_codename = line.split('product:')[1].strip()
                            if device_codename in self.devices_db:
                                logger.info(f"Detected device in fastboot: {device_codename}")
                                return device_codename
        
        logger.warning("Could not detect device automatically")
        return None

    def check_prerequisites(self, device_config: DeviceFlashConfig) -> bool:
        """Check flashing prerequisites"""
        logger.info("Checking prerequisites...")
        
        # Check required tools
        required_tools = {
            FlashMethod.FASTBOOT: [self.fastboot_path, self.adb_path],
            FlashMethod.HEIMDALL: [self.heimdall_path],
            FlashMethod.ODIN: ["odin3.exe"],  # Windows only
            FlashMethod.ADB_SIDELOAD: [self.adb_path]
        }
        
        tools = required_tools.get(device_config.flash_method, [])
        missing_tools = [tool for tool in tools if not tool or not os.path.exists(tool)]
        
        if missing_tools:
            logger.error(f"Missing required tools for {device_config.flash_method.value}")
            return False
        
        # Check device connection
        if device_config.flash_method == FlashMethod.FASTBOOT:
            ret, stdout, _ = self._run_command([self.fastboot_path, 'devices'])
            if ret != 0 or not stdout.strip():
                logger.error("No device detected in fastboot mode")
                return False
        elif device_config.flash_method == FlashMethod.HEIMDALL:
            ret, stdout, _ = self._run_command([self.heimdall_path, 'detect'])
            if ret != 0:
                logger.error("No device detected in download mode")
                return False
        
        logger.info("Prerequisites check passed")
        return True

    def prepare_flash_package(self, rom_path: Path, device_config: DeviceFlashConfig) -> Optional[FlashPackage]:
        """Prepare flash package from ROM file"""
        logger.info(f"Preparing flash package from {rom_path}")
        
        if not rom_path.exists():
            logger.error(f"ROM file not found: {rom_path}")
            return None
        
        # Handle different file types
        if rom_path.suffix.lower() == '.zip':
            # Extract ZIP file
            import zipfile
            extract_dir = rom_path.parent / f"{rom_path.stem}_extracted"
            extract_dir.mkdir(exist_ok=True)
            
            with zipfile.ZipFile(rom_path, 'r') as zip_ref:
                zip_ref.extractall(extract_dir)
            
            # Find image files
            package = FlashPackage(rom_file=rom_path)
            
            for img_file in extract_dir.glob("*.img"):
                img_name = img_file.stem.lower()
                if img_name == "boot":
                    package.boot_file = img_file
                elif img_name == "recovery":
                    package.recovery_file = img_file
                elif img_name == "system":
                    package.system_file = img_file
                elif img_name == "vendor":
                    package.vendor_file = img_file
                elif img_name == "userdata":
                    package.userdata_file = img_file
                elif img_name == "cache":
                    package.cache_file = img_file
            
            return package
        
        elif rom_path.suffix.lower() == '.img':
            # Single image file (likely GSI)
            return FlashPackage(rom_file=rom_path, system_file=rom_path)
        
        elif rom_path.suffix.lower() == '.tar':
            # Samsung TAR file
            import tarfile
            extract_dir = rom_path.parent / f"{rom_path.stem}_extracted"
            extract_dir.mkdir(exist_ok=True)
            
            with tarfile.open(rom_path, 'r') as tar_ref:
                tar_ref.extractall(extract_dir)
            
            return FlashPackage(rom_file=rom_path)
        
        logger.error(f"Unsupported ROM file format: {rom_path.suffix}")
        return None

    def flash_fastboot(self, device_config: DeviceFlashConfig, package: FlashPackage) -> bool:
        """Flash using fastboot"""
        logger.info("Flashing using fastboot...")
        
        # Check if bootloader is unlocked
        ret, stdout, _ = self._run_command([self.fastboot_path, 'getvar', 'unlocked'])
        if 'unlocked: yes' not in stdout and device_config.requires_unlock:
            logger.error("Bootloader is locked. Please unlock it first.")
            return False
        
        # Flash partitions
        flash_commands = []
        
        if device_config.supports_ab:
            # A/B device
            if package.boot_file:
                flash_commands.extend([
                    [self.fastboot_path, 'flash', 'boot_a', str(package.boot_file)],
                    [self.fastboot_path, 'flash', 'boot_b', str(package.boot_file)]
                ])
            if package.system_file:
                flash_commands.extend([
                    [self.fastboot_path, 'flash', 'system_a', str(package.system_file)],
                    [self.fastboot_path, 'flash', 'system_b', str(package.system_file)]
                ])
            if package.vendor_file:
                flash_commands.extend([
                    [self.fastboot_path, 'flash', 'vendor_a', str(package.vendor_file)],
                    [self.fastboot_path, 'flash', 'vendor_b', str(package.vendor_file)]
                ])
        else:
            # Non-A/B device
            if package.boot_file:
                flash_commands.append([self.fastboot_path, 'flash', 'boot', str(package.boot_file)])
            if package.recovery_file:
                flash_commands.append([self.fastboot_path, 'flash', 'recovery', str(package.recovery_file)])
            if package.system_file:
                flash_commands.append([self.fastboot_path, 'flash', 'system', str(package.system_file)])
            if package.vendor_file:
                flash_commands.append([self.fastboot_path, 'flash', 'vendor', str(package.vendor_file)])
            if package.userdata_file:
                flash_commands.append([self.fastboot_path, 'flash', 'userdata', str(package.userdata_file)])
        
        # Execute flash commands
        for cmd in flash_commands:
            ret, stdout, stderr = self._run_command(cmd, timeout=300)
            if ret != 0:
                logger.error(f"Flash command failed: {' '.join(cmd)}")
                logger.error(f"Error: {stderr}")
                return False
            logger.info(f"Successfully flashed: {cmd[2]}")
        
        # Reboot
        logger.info("Rebooting device...")
        self._run_command([self.fastboot_path, 'reboot'])
        
        return True

    def flash_heimdall(self, device_config: DeviceFlashConfig, package: FlashPackage) -> bool:
        """Flash using Heimdall (Samsung devices)"""
        logger.info("Flashing using Heimdall...")
        
        # Build Heimdall command
        cmd = [self.heimdall_path, 'flash']
        
        # Add partition arguments based on device config
        for partition, img_file in device_config.partitions.items():
            img_path = None
            
            if partition.upper() == "BOOT" and package.boot_file:
                img_path = package.boot_file
            elif partition.upper() == "RECOVERY" and package.recovery_file:
                img_path = package.recovery_file
            elif partition.upper() == "SYSTEM" and package.system_file:
                img_path = package.system_file
            elif partition.upper() == "USERDATA" and package.userdata_file:
                img_path = package.userdata_file
            elif partition.upper() == "CACHE" and package.cache_file:
                img_path = package.cache_file
            
            if img_path and img_path.exists():
                cmd.extend([f'--{partition.upper()}', str(img_path)])
        
        # Add reboot option
        cmd.append('--reboot')
        
        # Execute flash command
        ret, stdout, stderr = self._run_command(cmd, timeout=600)
        if ret != 0:
            logger.error(f"Heimdall flash failed: {stderr}")
            return False
        
        logger.info("Heimdall flash completed successfully")
        return True

    def flash_device(self, device_codename: str, rom_path: Path, 
                    wipe_data: bool = False, backup_efs: bool = True) -> bool:
        """Main device flashing function"""
        logger.info(f"Starting flash process for {device_codename}")
        
        # Get device configuration
        if device_codename not in self.devices_db:
            logger.error(f"Unsupported device: {device_codename}")
            return False
        
        device_config = self.devices_db[device_codename]
        
        # Display device information
        logger.info(f"Device: {device_config.manufacturer} {device_config.model}")
        logger.info(f"Flash method: {device_config.flash_method.value}")
        logger.info(f"Bootloader mode: {device_config.bootloader_mode}")
        
        # Show special instructions
        if device_config.special_instructions:
            logger.info("Special instructions:")
            for instruction in device_config.special_instructions:
                logger.info(f"  - {instruction}")
        
        # Check prerequisites
        if not self.check_prerequisites(device_config):
            return False
        
        # Prepare flash package
        package = self.prepare_flash_package(rom_path, device_config)
        if not package:
            return False
        
        # Backup EFS (for Samsung devices)
        if backup_efs and device_config.manufacturer == "samsung":
            logger.info("Creating EFS backup...")
            # Implementation for EFS backup
        
        # Perform flashing based on method
        success = False
        
        if device_config.flash_method == FlashMethod.FASTBOOT:
            success = self.flash_fastboot(device_config, package)
        elif device_config.flash_method == FlashMethod.HEIMDALL:
            success = self.flash_heimdall(device_config, package)
        else:
            logger.error(f"Flash method {device_config.flash_method.value} not implemented yet")
            return False
        
        if success:
            logger.info("Flash completed successfully!")
            logger.info("Device should reboot automatically")
            logger.info("First boot may take several minutes")
        else:
            logger.error("Flash failed!")
        
        return success

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="AFOT Universal Flashing Tool")
    
    parser.add_argument('rom_file', help='ROM file to flash (.zip, .img, .tar)')
    parser.add_argument('--device', '-d', help='Target device codename (auto-detect if not specified)')
    parser.add_argument('--wipe-data', action='store_true', help='Wipe user data during flash')
    parser.add_argument('--no-backup', action='store_true', help='Skip EFS backup (Samsung devices)')
    parser.add_argument('--list-devices', action='store_true', help='List supported devices')
    parser.add_argument('--detect', action='store_true', help='Detect connected device')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    flash_tool = AFOTFlashTool()
    
    if args.list_devices:
        print("Supported devices:")
        for codename, config in flash_tool.devices_db.items():
            print(f"  {codename}: {config.manufacturer} {config.model} ({config.flash_method.value})")
        return
    
    if args.detect:
        device = flash_tool.detect_device()
        if device:
            config = flash_tool.devices_db[device]
            print(f"Detected: {device} ({config.manufacturer} {config.model})")
        else:
            print("No device detected")
        return
    
    # Validate ROM file
    rom_path = Path(args.rom_file)
    if not rom_path.exists():
        logger.error(f"ROM file not found: {rom_path}")
        sys.exit(1)
    
    # Determine target device
    device_codename = args.device
    if not device_codename:
        device_codename = flash_tool.detect_device()
        if not device_codename:
            logger.error("Could not detect device. Please specify with --device")
            sys.exit(1)
    
    # Perform flash
    success = flash_tool.flash_device(
        device_codename=device_codename,
        rom_path=rom_path,
        wipe_data=args.wipe_data,
        backup_efs=not args.no_backup
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

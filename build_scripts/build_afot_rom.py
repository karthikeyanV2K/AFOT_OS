#!/usr/bin/env python3
"""
AFOT Custom ROM Build Script
Automated build system for AFOT Android OS with music player and lock system
Supports both GSI and device-specific builds with comprehensive error handling
"""

import os
import sys
import json
import time
import subprocess
import argparse
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('afot_build.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class BuildConfig:
    """Build configuration data class"""
    target_device: str
    build_type: str  # userdebug, user, eng
    build_variant: str  # gsi, device
    source_tree: str  # lineage, aosp
    output_dir: str
    ccache_size: str
    parallel_jobs: int
    clean_build: bool
    include_gapps: bool
    sign_build: bool
    create_ota: bool

@dataclass
class DeviceInfo:
    """Device information data class"""
    codename: str
    manufacturer: str
    model: str
    arch: str  # arm, arm64
    android_version: str
    kernel_source: Optional[str] = None
    device_tree: Optional[str] = None
    vendor_blobs: Optional[str] = None

class AFOTBuildSystem:
    """Main AFOT build system class"""
    
    def __init__(self, config: BuildConfig):
        self.config = config
        self.start_time = time.time()
        self.android_root = Path.home() / "android"
        self.afot_root = self.android_root / "afot"
        self.build_root = self.android_root / config.source_tree
        
        # Supported devices database
        self.supported_devices = self._load_device_database()
        
        # Environment setup
        self.env = os.environ.copy()
        self.env.update({
            'USE_CCACHE': '1',
            'CCACHE_DIR': str(Path.home() / '.ccache'),
            'ANDROID_JACK_VM_ARGS': '-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4G',
            'JACK_SERVER_VM_ARGUMENTS': '-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4G',
            'AFOT_BUILD': '1'
        })

    def _load_device_database(self) -> Dict[str, DeviceInfo]:
        """Load supported devices database"""
        devices_file = self.afot_root / "devices.json"
        if devices_file.exists():
            with open(devices_file, 'r') as f:
                data = json.load(f)
                return {
                    name: DeviceInfo(**info) 
                    for name, info in data.items()
                }
        return {}

    def _run_command(self, cmd: List[str], cwd: Optional[Path] = None, 
                    capture_output: bool = False, timeout: Optional[int] = None) -> Tuple[int, str, str]:
        """Execute shell command with proper error handling"""
        if cwd is None:
            cwd = self.build_root
            
        logger.info(f"Executing: {' '.join(cmd)} in {cwd}")
        
        try:
            result = subprocess.run(
                cmd,
                cwd=cwd,
                env=self.env,
                capture_output=capture_output,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout if capture_output else "", result.stderr if capture_output else ""
        except subprocess.TimeoutExpired:
            logger.error(f"Command timed out: {' '.join(cmd)}")
            return -1, "", "Command timed out"
        except Exception as e:
            logger.error(f"Command failed: {e}")
            return -1, "", str(e)

    def check_prerequisites(self) -> bool:
        """Check build prerequisites"""
        logger.info("Checking build prerequisites...")
        
        # Check required tools
        required_tools = ['repo', 'git', 'make', 'python3', 'java', 'ccache']
        missing_tools = []
        
        for tool in required_tools:
            if subprocess.run(['which', tool], capture_output=True).returncode != 0:
                missing_tools.append(tool)
        
        if missing_tools:
            logger.error(f"Missing required tools: {', '.join(missing_tools)}")
            return False
        
        # Check disk space (minimum 200GB)
        statvfs = os.statvfs(self.android_root)
        free_space_gb = (statvfs.f_frsize * statvfs.f_bavail) / (1024**3)
        
        if free_space_gb < 200:
            logger.error(f"Insufficient disk space: {free_space_gb:.1f}GB available, 200GB required")
            return False
        
        # Check RAM (minimum 8GB recommended)
        with open('/proc/meminfo', 'r') as f:
            meminfo = f.read()
            for line in meminfo.split('\n'):
                if line.startswith('MemTotal:'):
                    total_ram_kb = int(line.split()[1])
                    total_ram_gb = total_ram_kb / (1024**2)
                    if total_ram_gb < 8:
                        logger.warning(f"Low RAM: {total_ram_gb:.1f}GB available, 8GB+ recommended")
                    break
        
        # Check Java version
        ret, stdout, _ = self._run_command(['java', '-version'], capture_output=True)
        if ret != 0 or 'openjdk version "11' not in stdout and 'openjdk version "11' not in _:
            logger.error("Java 11 is required")
            return False
        
        logger.info("All prerequisites satisfied")
        return True

    def setup_ccache(self) -> bool:
        """Configure ccache for faster builds"""
        logger.info(f"Setting up ccache with {self.config.ccache_size} cache")
        
        ret, _, _ = self._run_command(['ccache', '-M', self.config.ccache_size])
        if ret != 0:
            logger.error("Failed to configure ccache")
            return False
        
        ret, _, _ = self._run_command(['ccache', '-z'])  # Zero stats
        return ret == 0

    def sync_sources(self) -> bool:
        """Sync Android sources"""
        logger.info(f"Syncing {self.config.source_tree} sources...")
        
        if not self.build_root.exists():
            logger.error(f"Source directory not found: {self.build_root}")
            return False
        
        os.chdir(self.build_root)
        
        # Sync with retry logic
        max_retries = 3
        for attempt in range(max_retries):
            logger.info(f"Sync attempt {attempt + 1}/{max_retries}")
            ret, _, _ = self._run_command([
                'repo', 'sync', '-c', '-j', str(self.config.parallel_jobs), 
                '--force-sync', '--no-clone-bundle'
            ], timeout=7200)  # 2 hour timeout
            
            if ret == 0:
                logger.info("Source sync completed successfully")
                return True
            
            logger.warning(f"Sync attempt {attempt + 1} failed, retrying...")
            time.sleep(30)
        
        logger.error("Failed to sync sources after all retries")
        return False

    def setup_device_tree(self, device: DeviceInfo) -> bool:
        """Setup device tree and dependencies"""
        logger.info(f"Setting up device tree for {device.codename}")
        
        local_manifests_dir = self.build_root / ".repo" / "local_manifests"
        local_manifests_dir.mkdir(exist_ok=True)
        
        # Create local manifest for device
        manifest_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <!-- Device tree -->
    <project name="device_{device.manufacturer}_{device.codename}" 
             path="device/{device.manufacturer}/{device.codename}" 
             remote="github" 
             revision="lineage-20.0" />
    
    <!-- Kernel -->
    <project name="kernel_{device.manufacturer}_{device.codename}" 
             path="kernel/{device.manufacturer}/{device.codename}" 
             remote="github" 
             revision="lineage-20.0" />
    
    <!-- Vendor blobs -->
    <project name="vendor_{device.manufacturer}_{device.codename}" 
             path="vendor/{device.manufacturer}/{device.codename}" 
             remote="github" 
             revision="lineage-20.0" />
    
    <!-- AFOT Apps -->
    <project name="AFOTMusicPlayer" 
             path="packages/apps/AFOTMusicPlayer" 
             remote="afot" 
             revision="main" />
    
    <project name="AFOTLockSystem" 
             path="packages/apps/AFOTLockSystem" 
             remote="afot" 
             revision="main" />
</manifest>"""
        
        manifest_file = local_manifests_dir / f"{device.codename}.xml"
        with open(manifest_file, 'w') as f:
            f.write(manifest_content)
        
        # Sync device-specific repos
        ret, _, _ = self._run_command(['repo', 'sync', '--force-sync'])
        return ret == 0

    def build_gsi(self) -> bool:
        """Build Generic System Image"""
        logger.info("Building AFOT GSI...")
        
        os.chdir(self.build_root)
        
        # Setup build environment
        ret, _, _ = self._run_command(['bash', '-c', 'source build/envsetup.sh'])
        if ret != 0:
            logger.error("Failed to setup build environment")
            return False
        
        # GSI targets
        gsi_targets = [
            'aosp_arm64_ab-userdebug',
            'aosp_arm_ab-userdebug'
        ]
        
        for target in gsi_targets:
            logger.info(f"Building GSI target: {target}")
            
            # Lunch target
            ret, _, _ = self._run_command(['bash', '-c', f'source build/envsetup.sh && lunch {target}'])
            if ret != 0:
                logger.error(f"Failed to lunch {target}")
                continue
            
            # Clean if requested
            if self.config.clean_build:
                ret, _, _ = self._run_command(['make', 'clean'])
            
            # Build
            build_cmd = ['make', '-j', str(self.config.parallel_jobs), 'systemimage']
            ret, _, _ = self._run_command(build_cmd, timeout=14400)  # 4 hour timeout
            
            if ret != 0:
                logger.error(f"Failed to build {target}")
                return False
            
            logger.info(f"Successfully built {target}")
        
        return True

    def build_device_rom(self, device: DeviceInfo) -> bool:
        """Build device-specific ROM"""
        logger.info(f"Building AFOT ROM for {device.codename}")
        
        os.chdir(self.build_root)
        
        # Setup build environment
        lunch_target = f"lineage_{device.codename}-{self.config.build_type}"
        
        # Source environment and lunch
        setup_cmd = f"source build/envsetup.sh && lunch {lunch_target}"
        ret, _, _ = self._run_command(['bash', '-c', setup_cmd])
        if ret != 0:
            logger.error(f"Failed to lunch {lunch_target}")
            return False
        
        # Clean if requested
        if self.config.clean_build:
            ret, _, _ = self._run_command(['make', 'clean'])
        
        # Build ROM
        build_cmd = ['bash', '-c', f'source build/envsetup.sh && lunch {lunch_target} && mka bacon']
        ret, _, _ = self._run_command(build_cmd, timeout=18000)  # 5 hour timeout
        
        if ret != 0:
            logger.error(f"Failed to build ROM for {device.codename}")
            return False
        
        logger.info(f"Successfully built ROM for {device.codename}")
        return True

    def sign_build(self, device: DeviceInfo) -> bool:
        """Sign the build with release keys"""
        if not self.config.sign_build:
            return True
        
        logger.info("Signing build with release keys...")
        
        # Implementation depends on your signing setup
        # This is a placeholder for the signing process
        
        return True

    def create_ota_package(self, device: DeviceInfo) -> bool:
        """Create OTA update package"""
        if not self.config.create_ota:
            return True
        
        logger.info("Creating OTA package...")
        
        # Implementation for OTA package creation
        # This would involve creating incremental updates
        
        return True

    def copy_build_artifacts(self, device: DeviceInfo) -> bool:
        """Copy build artifacts to output directory"""
        logger.info("Copying build artifacts...")
        
        output_dir = Path(self.config.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Find build artifacts
        if self.config.build_variant == "gsi":
            # GSI artifacts
            gsi_out_dirs = [
                self.build_root / "out" / "target" / "product" / "generic_arm64_ab",
                self.build_root / "out" / "target" / "product" / "generic_arm_ab"
            ]
            
            for gsi_dir in gsi_out_dirs:
                if gsi_dir.exists():
                    system_img = gsi_dir / "system.img"
                    if system_img.exists():
                        target_name = f"afot_gsi_{gsi_dir.name}_{int(time.time())}.img"
                        subprocess.run(['cp', str(system_img), str(output_dir / target_name)])
        else:
            # Device-specific artifacts
            device_out_dir = self.build_root / "out" / "target" / "product" / device.codename
            if device_out_dir.exists():
                # Copy ROM zip
                rom_files = list(device_out_dir.glob("lineage-*.zip"))
                if rom_files:
                    latest_rom = max(rom_files, key=os.path.getctime)
                    target_name = f"afot_{device.codename}_{int(time.time())}.zip"
                    subprocess.run(['cp', str(latest_rom), str(output_dir / target_name)])
                
                # Copy recovery image
                recovery_img = device_out_dir / "recovery.img"
                if recovery_img.exists():
                    target_name = f"afot_recovery_{device.codename}_{int(time.time())}.img"
                    subprocess.run(['cp', str(recovery_img), str(output_dir / target_name)])
        
        logger.info(f"Build artifacts copied to {output_dir}")
        return True

    def generate_build_report(self, success: bool, device: Optional[DeviceInfo] = None) -> None:
        """Generate build report"""
        build_time = time.time() - self.start_time
        
        report = {
            'build_config': {
                'target_device': self.config.target_device,
                'build_type': self.config.build_type,
                'build_variant': self.config.build_variant,
                'source_tree': self.config.source_tree
            },
            'build_result': {
                'success': success,
                'build_time_seconds': int(build_time),
                'build_time_formatted': f"{int(build_time // 3600)}h {int((build_time % 3600) // 60)}m {int(build_time % 60)}s"
            },
            'timestamp': int(time.time()),
            'output_directory': self.config.output_dir
        }
        
        if device:
            report['device_info'] = {
                'codename': device.codename,
                'manufacturer': device.manufacturer,
                'model': device.model,
                'arch': device.arch
            }
        
        # Save report
        report_file = Path(self.config.output_dir) / "build_report.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        logger.info("=" * 60)
        logger.info("AFOT BUILD SUMMARY")
        logger.info("=" * 60)
        logger.info(f"Target: {self.config.target_device}")
        logger.info(f"Variant: {self.config.build_variant}")
        logger.info(f"Result: {'SUCCESS' if success else 'FAILED'}")
        logger.info(f"Build Time: {report['build_result']['build_time_formatted']}")
        logger.info(f"Output: {self.config.output_dir}")
        logger.info("=" * 60)

    def build(self) -> bool:
        """Main build process"""
        logger.info("Starting AFOT ROM build process...")
        
        try:
            # Check prerequisites
            if not self.check_prerequisites():
                return False
            
            # Setup ccache
            if not self.setup_ccache():
                return False
            
            # Sync sources
            if not self.sync_sources():
                return False
            
            # Build based on variant
            if self.config.build_variant == "gsi":
                success = self.build_gsi()
                device = None
            else:
                # Get device info
                if self.config.target_device not in self.supported_devices:
                    logger.error(f"Unsupported device: {self.config.target_device}")
                    return False
                
                device = self.supported_devices[self.config.target_device]
                
                # Setup device tree
                if not self.setup_device_tree(device):
                    return False
                
                # Build device ROM
                success = self.build_device_rom(device)
                
                if success:
                    # Sign build
                    success = self.sign_build(device)
                    
                    # Create OTA package
                    if success:
                        success = self.create_ota_package(device)
            
            # Copy artifacts
            if success:
                if self.config.build_variant == "gsi":
                    self.copy_build_artifacts(None)
                else:
                    self.copy_build_artifacts(device)
            
            # Generate report
            self.generate_build_report(success, device)
            
            return success
            
        except Exception as e:
            logger.error(f"Build process failed with exception: {e}")
            self.generate_build_report(False)
            return False

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="AFOT Custom ROM Build System")
    
    parser.add_argument('--device', '-d', required=True, 
                       help='Target device codename or "gsi" for Generic System Image')
    parser.add_argument('--build-type', '-t', default='userdebug',
                       choices=['user', 'userdebug', 'eng'],
                       help='Build type (default: userdebug)')
    parser.add_argument('--source', '-s', default='lineage',
                       choices=['lineage', 'aosp'],
                       help='Source tree to use (default: lineage)')
    parser.add_argument('--output', '-o', default='./builds',
                       help='Output directory for build artifacts')
    parser.add_argument('--ccache-size', default='50G',
                       help='ccache size (default: 50G)')
    parser.add_argument('--jobs', '-j', type=int, default=os.cpu_count(),
                       help='Number of parallel jobs (default: CPU count)')
    parser.add_argument('--clean', action='store_true',
                       help='Clean build (make clean)')
    parser.add_argument('--no-gapps', action='store_true',
                       help='Build without Google Apps')
    parser.add_argument('--sign', action='store_true',
                       help='Sign build with release keys')
    parser.add_argument('--ota', action='store_true',
                       help='Create OTA package')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Determine build variant
    build_variant = "gsi" if args.device.lower() == "gsi" else "device"
    
    # Create build configuration
    config = BuildConfig(
        target_device=args.device,
        build_type=args.build_type,
        build_variant=build_variant,
        source_tree=args.source,
        output_dir=args.output,
        ccache_size=args.ccache_size,
        parallel_jobs=args.jobs,
        clean_build=args.clean,
        include_gapps=not args.no_gapps,
        sign_build=args.sign,
        create_ota=args.ota
    )
    
    # Create and run build system
    build_system = AFOTBuildSystem(config)
    success = build_system.build()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

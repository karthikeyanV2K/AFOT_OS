#!/usr/bin/env python3
"""
AFOT ROM Testing Suite
Comprehensive testing framework for AFOT custom ROM
Tests audio functionality, lock system, performance, and device compatibility
"""

import os
import sys
import json
import time
import subprocess
import argparse
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum
import threading
import queue

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('afot_test.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class TestResult(Enum):
    PASS = "PASS"
    FAIL = "FAIL"
    SKIP = "SKIP"
    ERROR = "ERROR"

@dataclass
class TestCase:
    """Individual test case"""
    name: str
    description: str
    category: str
    priority: str  # high, medium, low
    timeout: int
    setup_commands: List[str]
    test_commands: List[str]
    cleanup_commands: List[str]
    expected_output: Optional[str] = None
    success_criteria: Optional[str] = None

@dataclass
class TestReport:
    """Test execution report"""
    test_name: str
    result: TestResult
    duration: float
    output: str
    error_message: Optional[str] = None
    timestamp: float = 0

class AFOTTestSuite:
    """Main AFOT testing suite"""
    
    def __init__(self, device_serial: Optional[str] = None):
        self.device_serial = device_serial
        self.adb_path = self._find_adb()
        self.test_cases = self._load_test_cases()
        self.reports: List[TestReport] = []
        
        if not self.adb_path:
            raise RuntimeError("ADB not found in PATH")
    
    def _find_adb(self) -> Optional[str]:
        """Find ADB executable"""
        try:
            result = subprocess.run(['which', 'adb'], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        
        # Check common locations
        common_paths = [
            '/usr/bin/adb',
            '/usr/local/bin/adb',
            'C:\\platform-tools\\adb.exe',
            'C:\\adb\\adb.exe'
        ]
        
        for path in common_paths:
            if os.path.exists(path):
                return path
        
        return None
    
    def _run_adb_command(self, cmd: List[str], timeout: int = 30) -> Tuple[int, str, str]:
        """Execute ADB command"""
        full_cmd = [self.adb_path]
        if self.device_serial:
            full_cmd.extend(['-s', self.device_serial])
        full_cmd.extend(cmd)
        
        logger.debug(f"Executing: {' '.join(full_cmd)}")
        
        try:
            result = subprocess.run(
                full_cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Command timed out"
        except Exception as e:
            return -1, "", str(e)
    
    def _load_test_cases(self) -> List[TestCase]:
        """Load test cases configuration"""
        return [
            # Boot and System Tests
            TestCase(
                name="boot_test",
                description="Verify device boots successfully",
                category="system",
                priority="high",
                timeout=60,
                setup_commands=[],
                test_commands=[
                    "shell getprop sys.boot_completed",
                    "shell getprop ro.afot.version"
                ],
                cleanup_commands=[],
                success_criteria="boot_completed=1 and afot.version present"
            ),
            
            TestCase(
                name="afot_services_test",
                description="Verify AFOT services are running",
                category="system",
                priority="high",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell service list | grep afot",
                    "shell ps | grep com.afot"
                ],
                cleanup_commands=[],
                success_criteria="AFOT services found"
            ),
            
            # Audio System Tests
            TestCase(
                name="audio_system_test",
                description="Test audio system functionality",
                category="audio",
                priority="high",
                timeout=45,
                setup_commands=[
                    "shell settings put global audio_safe_volume_state 0"
                ],
                test_commands=[
                    "shell dumpsys audio",
                    "shell cat /proc/asound/cards",
                    "shell getprop ro.config.media_vol_steps"
                ],
                cleanup_commands=[],
                success_criteria="Audio devices detected"
            ),
            
            TestCase(
                name="music_player_test",
                description="Test AFOT Music Player functionality",
                category="audio",
                priority="high",
                timeout=60,
                setup_commands=[
                    "shell am force-stop com.afot.musicplayer"
                ],
                test_commands=[
                    "shell am start -n com.afot.musicplayer/.ui.activity.MainActivity",
                    "shell dumpsys activity activities | grep MusicPlayer",
                    "shell service list | grep MusicService"
                ],
                cleanup_commands=[
                    "shell am force-stop com.afot.musicplayer"
                ],
                success_criteria="Music player launches successfully"
            ),
            
            TestCase(
                name="bluetooth_audio_test",
                description="Test Bluetooth audio functionality",
                category="audio",
                priority="medium",
                timeout=60,
                setup_commands=[
                    "shell settings put global bluetooth_on 1"
                ],
                test_commands=[
                    "shell dumpsys bluetooth_manager",
                    "shell getprop bluetooth.a2dp.sink.enable",
                    "shell service list | grep bluetooth"
                ],
                cleanup_commands=[],
                success_criteria="Bluetooth services active"
            ),
            
            # Lock System Tests
            TestCase(
                name="lock_system_test",
                description="Test AFOT Lock System",
                category="security",
                priority="high",
                timeout=45,
                setup_commands=[],
                test_commands=[
                    "shell am start -n com.afot.locksystem/.service.LockScreenService",
                    "shell dumpsys window displays | grep LockScreen",
                    "shell getprop ro.afot.lock.biometric_support"
                ],
                cleanup_commands=[
                    "shell am force-stop com.afot.locksystem"
                ],
                success_criteria="Lock system components active"
            ),
            
            TestCase(
                name="biometric_test",
                description="Test biometric authentication",
                category="security",
                priority="medium",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell dumpsys fingerprint",
                    "shell dumpsys face",
                    "shell pm list features | grep fingerprint"
                ],
                cleanup_commands=[],
                success_criteria="Biometric hardware detected"
            ),
            
            # Performance Tests
            TestCase(
                name="memory_test",
                description="Test memory usage and management",
                category="performance",
                priority="medium",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell cat /proc/meminfo",
                    "shell dumpsys meminfo",
                    "shell getprop dalvik.vm.heapsize"
                ],
                cleanup_commands=[],
                success_criteria="Memory within acceptable limits"
            ),
            
            TestCase(
                name="cpu_test",
                description="Test CPU performance and scaling",
                category="performance",
                priority="medium",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell cat /proc/cpuinfo",
                    "shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor",
                    "shell top -n 1"
                ],
                cleanup_commands=[],
                success_criteria="CPU scaling active"
            ),
            
            TestCase(
                name="battery_test",
                description="Test battery optimization features",
                category="performance",
                priority="medium",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell dumpsys battery",
                    "shell dumpsys batterystats",
                    "shell getprop power.saving.mode"
                ],
                cleanup_commands=[],
                success_criteria="Battery optimization active"
            ),
            
            # UI and Graphics Tests
            TestCase(
                name="graphics_test",
                description="Test graphics and UI performance",
                category="ui",
                priority="medium",
                timeout=45,
                setup_commands=[],
                test_commands=[
                    "shell dumpsys SurfaceFlinger",
                    "shell getprop ro.opengles.version",
                    "shell service list | grep gpu"
                ],
                cleanup_commands=[],
                success_criteria="Graphics acceleration active"
            ),
            
            TestCase(
                name="display_test",
                description="Test display configuration",
                category="ui",
                priority="medium",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell dumpsys display",
                    "shell wm size",
                    "shell wm density"
                ],
                cleanup_commands=[],
                success_criteria="Display properly configured"
            ),
            
            # Network Tests
            TestCase(
                name="wifi_test",
                description="Test WiFi functionality",
                category="network",
                priority="medium",
                timeout=45,
                setup_commands=[
                    "shell settings put global wifi_on 1"
                ],
                test_commands=[
                    "shell dumpsys wifi",
                    "shell iw dev",
                    "shell getprop wifi.interface"
                ],
                cleanup_commands=[],
                success_criteria="WiFi interface available"
            ),
            
            TestCase(
                name="mobile_data_test",
                description="Test mobile data connectivity",
                category="network",
                priority="medium",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell dumpsys telephony.registry",
                    "shell getprop gsm.sim.state",
                    "shell service list | grep phone"
                ],
                cleanup_commands=[],
                success_criteria="Telephony services active"
            ),
            
            # Storage Tests
            TestCase(
                name="storage_test",
                description="Test storage and filesystem",
                category="storage",
                priority="medium",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell df -h",
                    "shell mount | grep /data",
                    "shell ls -la /sdcard/"
                ],
                cleanup_commands=[],
                success_criteria="Storage mounted correctly"
            ),
            
            # Sensor Tests
            TestCase(
                name="sensors_test",
                description="Test device sensors",
                category="sensors",
                priority="low",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell dumpsys sensorservice",
                    "shell service list | grep sensor"
                ],
                cleanup_commands=[],
                success_criteria="Sensors detected"
            ),
            
            # Security Tests
            TestCase(
                name="selinux_test",
                description="Test SELinux policy enforcement",
                category="security",
                priority="high",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell getenforce",
                    "shell cat /proc/version | grep selinux",
                    "shell ls -Z /system/bin/app_process"
                ],
                cleanup_commands=[],
                success_criteria="SELinux enforcing"
            ),
            
            # AFOT Specific Tests
            TestCase(
                name="afot_version_test",
                description="Verify AFOT version and build info",
                category="afot",
                priority="high",
                timeout=15,
                setup_commands=[],
                test_commands=[
                    "shell getprop ro.afot.version",
                    "shell getprop ro.afot.build.date",
                    "shell getprop ro.afot.display.version"
                ],
                cleanup_commands=[],
                success_criteria="AFOT version properties present"
            ),
            
            TestCase(
                name="afot_features_test",
                description="Test AFOT-specific features",
                category="afot",
                priority="high",
                timeout=30,
                setup_commands=[],
                test_commands=[
                    "shell getprop ro.afot.music.enhanced_audio",
                    "shell getprop ro.afot.lock.biometric_support",
                    "shell getprop ro.afot.performance.mode"
                ],
                cleanup_commands=[],
                success_criteria="AFOT features enabled"
            )
        ]
    
    def check_device_connection(self) -> bool:
        """Check if device is connected and accessible"""
        logger.info("Checking device connection...")
        
        ret, stdout, stderr = self._run_adb_command(['devices'])
        if ret != 0:
            logger.error(f"Failed to list devices: {stderr}")
            return False
        
        if 'device' not in stdout:
            logger.error("No device found or device not authorized")
            return False
        
        # Test basic connectivity
        ret, stdout, stderr = self._run_adb_command(['shell', 'echo', 'test'])
        if ret != 0 or 'test' not in stdout:
            logger.error("Device not responding to commands")
            return False
        
        logger.info("Device connection verified")
        return True
    
    def run_test_case(self, test_case: TestCase) -> TestReport:
        """Execute a single test case"""
        logger.info(f"Running test: {test_case.name}")
        start_time = time.time()
        
        try:
            # Setup
            for cmd in test_case.setup_commands:
                ret, _, stderr = self._run_adb_command(cmd.split(), test_case.timeout)
                if ret != 0:
                    return TestReport(
                        test_name=test_case.name,
                        result=TestResult.ERROR,
                        duration=time.time() - start_time,
                        output="",
                        error_message=f"Setup failed: {stderr}",
                        timestamp=time.time()
                    )
            
            # Execute test commands
            all_output = []
            for cmd in test_case.test_commands:
                ret, stdout, stderr = self._run_adb_command(cmd.split(), test_case.timeout)
                all_output.append(f"Command: {cmd}")
                all_output.append(f"Return code: {ret}")
                all_output.append(f"Output: {stdout}")
                if stderr:
                    all_output.append(f"Error: {stderr}")
                all_output.append("-" * 40)
            
            output_text = "\n".join(all_output)
            
            # Evaluate success criteria
            result = self._evaluate_test_result(test_case, output_text)
            
            # Cleanup
            for cmd in test_case.cleanup_commands:
                self._run_adb_command(cmd.split(), 10)  # Short timeout for cleanup
            
            return TestReport(
                test_name=test_case.name,
                result=result,
                duration=time.time() - start_time,
                output=output_text,
                timestamp=time.time()
            )
            
        except Exception as e:
            return TestReport(
                test_name=test_case.name,
                result=TestResult.ERROR,
                duration=time.time() - start_time,
                output="",
                error_message=str(e),
                timestamp=time.time()
            )
    
    def _evaluate_test_result(self, test_case: TestCase, output: str) -> TestResult:
        """Evaluate test result based on success criteria"""
        if not test_case.success_criteria:
            # If no criteria specified, assume pass if no errors
            if "Return code: 0" in output:
                return TestResult.PASS
            else:
                return TestResult.FAIL
        
        criteria = test_case.success_criteria.lower()
        output_lower = output.lower()
        
        # Simple criteria evaluation
        if "and" in criteria:
            conditions = [c.strip() for c in criteria.split("and")]
            for condition in conditions:
                if not self._check_condition(condition, output_lower):
                    return TestResult.FAIL
            return TestResult.PASS
        elif "or" in criteria:
            conditions = [c.strip() for c in criteria.split("or")]
            for condition in conditions:
                if self._check_condition(condition, output_lower):
                    return TestResult.PASS
            return TestResult.FAIL
        else:
            return TestResult.PASS if self._check_condition(criteria, output_lower) else TestResult.FAIL
    
    def _check_condition(self, condition: str, output: str) -> bool:
        """Check individual condition"""
        if "present" in condition:
            key = condition.replace("present", "").strip()
            return key in output
        elif "=" in condition:
            key, value = condition.split("=", 1)
            return f"{key.strip()}={value.strip()}" in output or f"{key.strip()}: {value.strip()}" in output
        elif "detected" in condition:
            key = condition.replace("detected", "").strip()
            return key in output and "not found" not in output
        elif "active" in condition:
            key = condition.replace("active", "").strip()
            return key in output and ("running" in output or "started" in output)
        else:
            return condition in output
    
    def run_test_suite(self, categories: Optional[List[str]] = None, 
                      priorities: Optional[List[str]] = None) -> Dict[str, Any]:
        """Run the complete test suite"""
        logger.info("Starting AFOT test suite...")
        
        # Check device connection
        if not self.check_device_connection():
            return {"error": "Device not connected or not accessible"}
        
        # Filter test cases
        filtered_tests = self.test_cases
        if categories:
            filtered_tests = [t for t in filtered_tests if t.category in categories]
        if priorities:
            filtered_tests = [t for t in filtered_tests if t.priority in priorities]
        
        logger.info(f"Running {len(filtered_tests)} test cases...")
        
        # Execute tests
        start_time = time.time()
        self.reports = []
        
        for test_case in filtered_tests:
            report = self.run_test_case(test_case)
            self.reports.append(report)
            
            # Log result
            status_color = {
                TestResult.PASS: "✓",
                TestResult.FAIL: "✗",
                TestResult.SKIP: "⊝",
                TestResult.ERROR: "⚠"
            }
            logger.info(f"{status_color[report.result]} {test_case.name}: {report.result.value} ({report.duration:.2f}s)")
        
        total_time = time.time() - start_time
        
        # Generate summary
        summary = self._generate_summary(total_time)
        
        # Save detailed report
        self._save_detailed_report(summary)
        
        return summary
    
    def _generate_summary(self, total_time: float) -> Dict[str, Any]:
        """Generate test summary"""
        results_count = {result: 0 for result in TestResult}
        for report in self.reports:
            results_count[report.result] += 1
        
        categories_summary = {}
        for report in self.reports:
            test_case = next(t for t in self.test_cases if t.name == report.test_name)
            if test_case.category not in categories_summary:
                categories_summary[test_case.category] = {result: 0 for result in TestResult}
            categories_summary[test_case.category][report.result] += 1
        
        return {
            "summary": {
                "total_tests": len(self.reports),
                "passed": results_count[TestResult.PASS],
                "failed": results_count[TestResult.FAIL],
                "errors": results_count[TestResult.ERROR],
                "skipped": results_count[TestResult.SKIP],
                "success_rate": (results_count[TestResult.PASS] / len(self.reports)) * 100 if self.reports else 0,
                "total_time": total_time
            },
            "categories": categories_summary,
            "failed_tests": [
                {
                    "name": r.test_name,
                    "error": r.error_message,
                    "duration": r.duration
                }
                for r in self.reports if r.result in [TestResult.FAIL, TestResult.ERROR]
            ],
            "timestamp": time.time()
        }
    
    def _save_detailed_report(self, summary: Dict[str, Any]) -> None:
        """Save detailed test report"""
        report_data = {
            "summary": summary,
            "detailed_results": [
                {
                    "test_name": r.test_name,
                    "result": r.result.value,
                    "duration": r.duration,
                    "output": r.output,
                    "error_message": r.error_message,
                    "timestamp": r.timestamp
                }
                for r in self.reports
            ]
        }
        
        report_file = Path(f"afot_test_report_{int(time.time())}.json")
        with open(report_file, 'w') as f:
            json.dump(report_data, f, indent=2)
        
        logger.info(f"Detailed report saved to: {report_file}")

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="AFOT ROM Testing Suite")
    
    parser.add_argument('--device', '-d', help='Device serial number')
    parser.add_argument('--categories', '-c', nargs='+', 
                       choices=['system', 'audio', 'security', 'performance', 'ui', 'network', 'storage', 'sensors', 'afot'],
                       help='Test categories to run')
    parser.add_argument('--priorities', '-p', nargs='+',
                       choices=['high', 'medium', 'low'],
                       help='Test priorities to run')
    parser.add_argument('--list-tests', action='store_true',
                       help='List available tests')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        test_suite = AFOTTestSuite(device_serial=args.device)
        
        if args.list_tests:
            print("Available test cases:")
            for test in test_suite.test_cases:
                print(f"  {test.name}: {test.description} ({test.category}, {test.priority})")
            return
        
        # Run tests
        results = test_suite.run_test_suite(
            categories=args.categories,
            priorities=args.priorities
        )
        
        if "error" in results:
            logger.error(results["error"])
            sys.exit(1)
        
        # Print summary
        summary = results["summary"]
        print("\n" + "="*60)
        print("AFOT TEST SUITE RESULTS")
        print("="*60)
        print(f"Total Tests: {summary['total_tests']}")
        print(f"Passed: {summary['passed']}")
        print(f"Failed: {summary['failed']}")
        print(f"Errors: {summary['errors']}")
        print(f"Success Rate: {summary['success_rate']:.1f}%")
        print(f"Total Time: {summary['total_time']:.2f}s")
        
        if results["failed_tests"]:
            print(f"\nFailed Tests ({len(results['failed_tests'])}):")
            for test in results["failed_tests"]:
                print(f"  - {test['name']}: {test['error'] or 'Test failed'}")
        
        print("="*60)
        
        # Exit with error code if tests failed
        sys.exit(0 if summary['failed'] == 0 and summary['errors'] == 0 else 1)
        
    except Exception as e:
        logger.error(f"Test suite failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

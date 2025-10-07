package com.afot.locksystem.service

import android.app.KeyguardManager
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.PixelFormat
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.annotation.RequiresApi
import androidx.biometric.BiometricConstants
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.afot.locksystem.data.model.LockScreenSettings
import com.afot.locksystem.ui.theme.AFOTLockSystemTheme
import com.afot.locksystem.utils.TimeFormatter
import com.afot.locksystem.utils.WeatherService
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import javax.inject.Inject

@AndroidEntryPoint
class LockScreenService : Service() {

    @Inject
    lateinit var weatherService: WeatherService

    private lateinit var windowManager: WindowManager
    private lateinit var keyguardManager: KeyguardManager
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var biometricManager: BiometricManager

    private var lockScreenView: View? = null
    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    // State management
    private val _isLocked = MutableStateFlow(true)
    val isLocked: StateFlow<Boolean> = _isLocked.asStateFlow()

    private val _currentTime = MutableStateFlow("")
    val currentTime: StateFlow<String> = _currentTime.asStateFlow()

    private val _currentDate = MutableStateFlow("")
    val currentDate: StateFlow<String> = _currentDate.asStateFlow()

    private val _batteryLevel = MutableStateFlow(100)
    val batteryLevel: StateFlow<Int> = _batteryLevel.asStateFlow()

    private val _notifications = MutableStateFlow<List<NotificationData>>(emptyList())
    val notifications: StateFlow<List<NotificationData>> = _notifications.asStateFlow()

    private val _weatherInfo = MutableStateFlow<WeatherInfo?>(null)
    val weatherInfo: StateFlow<WeatherInfo?> = _weatherInfo.asStateFlow()

    private val _lockScreenSettings = MutableStateFlow(LockScreenSettings.default())
    val lockScreenSettings: StateFlow<LockScreenSettings> = _lockScreenSettings.asStateFlow()

    // Broadcast receivers
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_ON -> {
                    if (keyguardManager.isKeyguardLocked) {
                        showLockScreen()
                    }
                }
                Intent.ACTION_SCREEN_OFF -> {
                    hideLockScreen()
                }
                Intent.ACTION_USER_PRESENT -> {
                    hideLockScreen()
                    _isLocked.value = false
                }
            }
        }
    }

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_BATTERY_CHANGED) {
                val level = intent.getIntExtra("level", 0)
                val scale = intent.getIntExtra("scale", 100)
                _batteryLevel.value = (level * 100) / scale
            }
        }
    }

    private val timeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            updateTimeAndDate()
        }
    }

    override fun onCreate() {
        super.onCreate()
        
        initializeServices()
        registerReceivers()
        startTimeUpdates()
        loadWeatherInfo()
    }

    private fun initializeServices() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        biometricManager = BiometricManager.from(this)
    }

    private fun registerReceivers() {
        // Screen state receiver
        val screenFilter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, screenFilter)

        // Battery receiver
        registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))

        // Time receiver
        val timeFilter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_TICK)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        registerReceiver(timeReceiver, timeFilter)
    }

    private fun startTimeUpdates() {
        serviceScope.launch {
            while (true) {
                updateTimeAndDate()
                kotlinx.coroutines.delay(1000) // Update every second
            }
        }
    }

    private fun updateTimeAndDate() {
        val now = Calendar.getInstance()
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        val dateFormat = SimpleDateFormat("EEEE, MMMM d", Locale.getDefault())
        
        _currentTime.value = timeFormat.format(now.time)
        _currentDate.value = dateFormat.format(now.time)
    }

    private fun loadWeatherInfo() {
        serviceScope.launch {
            try {
                val weather = weatherService.getCurrentWeather()
                _weatherInfo.value = weather
            } catch (e: Exception) {
                // Handle weather loading error
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(screenReceiver)
        unregisterReceiver(batteryReceiver)
        unregisterReceiver(timeReceiver)
        hideLockScreen()
    }

    private fun showLockScreen() {
        if (lockScreenView != null) return

        val composeView = ComposeView(this).apply {
            setContent {
                AFOTLockSystemTheme {
                    LockScreenContent(
                        currentTime = currentTime.collectAsStateWithLifecycle().value,
                        currentDate = currentDate.collectAsStateWithLifecycle().value,
                        batteryLevel = batteryLevel.collectAsStateWithLifecycle().value,
                        notifications = notifications.collectAsStateWithLifecycle().value,
                        weatherInfo = weatherInfo.collectAsStateWithLifecycle().value,
                        settings = lockScreenSettings.collectAsStateWithLifecycle().value,
                        onUnlock = { attemptUnlock() },
                        onEmergencyCall = { makeEmergencyCall() },
                        onCameraLaunch = { launchCamera() }
                    )
                }
            }
        }

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        try {
            windowManager.addView(composeView, layoutParams)
            lockScreenView = composeView
            _isLocked.value = true
        } catch (e: Exception) {
            // Handle permission error
        }
    }

    private fun hideLockScreen() {
        lockScreenView?.let { view ->
            try {
                windowManager.removeView(view)
            } catch (e: Exception) {
                // View might already be removed
            }
            lockScreenView = null
        }
    }

    private fun attemptUnlock() {
        when (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)) {
            BiometricManager.BIOMETRIC_SUCCESS -> {
                showBiometricPrompt()
            }
            else -> {
                // Fallback to PIN/Pattern/Password
                showSecurityPrompt()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun showBiometricPrompt() {
        val biometricPrompt = BiometricPrompt.Builder(this)
            .setTitle("Unlock AFOT Device")
            .setSubtitle("Use your fingerprint or face to unlock")
            .setNegativeButton("Cancel", mainExecutor) { _, _ ->
                // Handle cancellation
            }
            .build()

        val cancellationSignal = CancellationSignal()
        
        biometricPrompt.authenticate(
            cancellationSignal,
            mainExecutor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult?) {
                    super.onAuthenticationSucceeded(result)
                    unlockDevice()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
                    super.onAuthenticationError(errorCode, errString)
                    if (errorCode != BiometricConstants.ERROR_USER_CANCELED) {
                        showSecurityPrompt()
                    }
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    // Show error message
                }
            }
        )
    }

    private fun showSecurityPrompt() {
        // Launch system security prompt (PIN/Pattern/Password)
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun unlockDevice() {
        hideLockScreen()
        _isLocked.value = false
        
        // Launch home screen or last app
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun makeEmergencyCall() {
        val intent = Intent(Intent.ACTION_CALL_EMERGENCY)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun launchCamera() {
        val intent = Intent("android.media.action.STILL_IMAGE_CAMERA")
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    // Data classes
    data class NotificationData(
        val id: String,
        val title: String,
        val content: String,
        val timestamp: Long,
        val icon: String?,
        val appName: String
    )

    data class WeatherInfo(
        val temperature: Int,
        val condition: String,
        val icon: String,
        val location: String
    )
}

@Composable
private fun LockScreenContent(
    currentTime: String,
    currentDate: String,
    batteryLevel: Int,
    notifications: List<LockScreenService.NotificationData>,
    weatherInfo: LockScreenService.WeatherInfo?,
    settings: LockScreenSettings,
    onUnlock: () -> Unit,
    onEmergencyCall: () -> Unit,
    onCameraLaunch: () -> Unit
) {
    var swipeOffset by remember { mutableStateOf(0f) }
    val context = LocalContext.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                if (settings.wallpaperUri.isNotEmpty()) {
                    Color.Transparent
                } else {
                    Brush.verticalGradient(
                        colors = listOf(
                            Color(0xFF1A1A2E),
                            Color(0xFF16213E),
                            Color(0xFF0F3460)
                        )
                    )
                }
            )
    ) {
        // Wallpaper background
        if (settings.wallpaperUri.isNotEmpty()) {
            AsyncImage(
                model = settings.wallpaperUri,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxSize()
                    .blur(2.dp),
                contentScale = ContentScale.Crop
            )
            
            // Dark overlay for readability
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.3f))
            )
        }

        // Status bar
        StatusBar(
            batteryLevel = batteryLevel,
            weatherInfo = weatherInfo,
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        )

        // Main content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Time display
            TimeDisplay(
                time = currentTime,
                date = currentDate,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(48.dp))

            // Notifications preview
            if (notifications.isNotEmpty() && settings.showNotifications) {
                NotificationsPreview(
                    notifications = notifications.take(3),
                    modifier = Modifier.fillMaxWidth()
                )
                
                Spacer(modifier = Modifier.height(32.dp))
            }

            Spacer(modifier = Modifier.weight(1f))

            // Quick actions
            QuickActionsRow(
                onEmergencyCall = onEmergencyCall,
                onCameraLaunch = onCameraLaunch,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Unlock slider
            UnlockSlider(
                onUnlock = onUnlock,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun StatusBar(
    batteryLevel: Int,
    weatherInfo: LockScreenService.WeatherInfo?,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Weather info
        weatherInfo?.let { weather ->
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${weather.temperature}°",
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = weather.condition,
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 14.sp
                )
            }
        }

        // Battery indicator
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "$batteryLevel%",
                color = Color.White,
                fontSize = 14.sp
            )
            Spacer(modifier = Modifier.width(4.dp))
            Icon(
                imageVector = when {
                    batteryLevel > 75 -> Icons.Rounded.BatteryFull
                    batteryLevel > 50 -> Icons.Rounded.Battery6Bar
                    batteryLevel > 25 -> Icons.Rounded.Battery3Bar
                    else -> Icons.Rounded.Battery1Bar
                },
                contentDescription = "Battery",
                tint = when {
                    batteryLevel > 25 -> Color.White
                    else -> Color.Red
                },
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

@Composable
private fun TimeDisplay(
    time: String,
    date: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = time,
            color = Color.White,
            fontSize = 72.sp,
            fontWeight = FontWeight.Light,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = date,
            color = Color.White.copy(alpha = 0.8f),
            fontSize = 18.sp,
            fontWeight = FontWeight.Normal,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun NotificationsPreview(
    notifications: List<LockScreenService.NotificationData>,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
    ) {
        notifications.forEach { notification ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color.White.copy(alpha = 0.1f)
                ),
                shape = RoundedCornerShape(12.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Notifications,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                    
                    Spacer(modifier = Modifier.width(12.dp))
                    
                    Column(
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(
                            text = notification.title,
                            color = Color.White,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            maxLines = 1
                        )
                        Text(
                            text = notification.content,
                            color = Color.White.copy(alpha = 0.7f),
                            fontSize = 12.sp,
                            maxLines = 1
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun QuickActionsRow(
    onEmergencyCall: () -> Unit,
    onCameraLaunch: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        // Emergency call
        IconButton(
            onClick = onEmergencyCall,
            modifier = Modifier
                .size(56.dp)
                .background(
                    Color.Red.copy(alpha = 0.2f),
                    CircleShape
                )
        ) {
            Icon(
                imageVector = Icons.Rounded.Phone,
                contentDescription = "Emergency Call",
                tint = Color.Red,
                modifier = Modifier.size(24.dp)
            )
        }

        // Camera
        IconButton(
            onClick = onCameraLaunch,
            modifier = Modifier
                .size(56.dp)
                .background(
                    Color.White.copy(alpha = 0.2f),
                    CircleShape
                )
        ) {
            Icon(
                imageVector = Icons.Rounded.CameraAlt,
                contentDescription = "Camera",
                tint = Color.White,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

@Composable
private fun UnlockSlider(
    onUnlock: () -> Unit,
    modifier: Modifier = Modifier
) {
    var dragOffset by remember { mutableStateOf(0f) }
    val maxOffset = 200.dp.value

    Box(
        modifier = modifier
            .height(60.dp)
            .background(
                Color.White.copy(alpha = 0.1f),
                RoundedCornerShape(30.dp)
            )
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragEnd = {
                        if (dragOffset >= maxOffset * 0.8f) {
                            onUnlock()
                        } else {
                            dragOffset = 0f
                        }
                    }
                ) { _, dragAmount ->
                    dragOffset = (dragOffset + dragAmount.x).coerceIn(0f, maxOffset)
                }
            },
        contentAlignment = Alignment.CenterStart
    ) {
        // Slide to unlock text
        Text(
            text = "Slide to unlock",
            color = Color.White.copy(alpha = 0.6f),
            fontSize = 16.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )

        // Slider thumb
        Box(
            modifier = Modifier
                .offset(x = dragOffset.dp)
                .size(50.dp)
                .background(Color.White, CircleShape)
                .padding(12.dp),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Rounded.ArrowForward,
                contentDescription = "Unlock",
                tint = Color.Black,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

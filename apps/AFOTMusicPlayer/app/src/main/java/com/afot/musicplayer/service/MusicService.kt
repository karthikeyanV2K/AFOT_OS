package com.afot.musicplayer.service

import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaDescriptionCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.media3.common.AudioAttributes as Media3AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.afot.musicplayer.R
import com.afot.musicplayer.data.model.Song
import com.afot.musicplayer.data.repository.MusicRepository
import com.afot.musicplayer.ui.activity.MainActivity
import com.afot.musicplayer.utils.NotificationHelper
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MusicService : MediaSessionService() {

    @Inject
    lateinit var musicRepository: MusicRepository

    @Inject
    lateinit var notificationHelper: NotificationHelper

    private lateinit var player: ExoPlayer
    private lateinit var mediaSession: MediaSession
    private lateinit var audioManager: AudioManager
    private lateinit var audioFocusRequest: AudioFocusRequest

    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    // State management
    private val _currentSong = MutableStateFlow<Song?>(null)
    val currentSong: StateFlow<Song?> = _currentSong.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _playbackPosition = MutableStateFlow(0L)
    val playbackPosition: StateFlow<Long> = _playbackPosition.asStateFlow()

    // Audio focus management
    private var hasAudioFocus = false
    private var playbackDelayed = false
    private var resumeOnFocusGain = false

    // Bluetooth management
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var a2dpProfile: BluetoothProfile? = null

    // Broadcast receivers
    private val audioNoisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (AudioManager.ACTION_AUDIO_BECOMING_NOISY == intent?.action) {
                if (player.isPlaying) {
                    player.pause()
                }
            }
        }
    }

    private val headsetReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (Intent.ACTION_HEADSET_PLUG == intent?.action) {
                val state = intent.getIntExtra("state", -1)
                when (state) {
                    0 -> { // Unplugged
                        if (player.isPlaying) {
                            player.pause()
                        }
                    }
                    1 -> { // Plugged
                        // Optionally resume playback or show notification
                    }
                }
            }
        }
    }

    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                    handleBluetoothStateChange(state)
                }
                BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED -> {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_CONNECTION_STATE, BluetoothAdapter.ERROR)
                    handleBluetoothConnectionChange(state)
                }
            }
        }
    }

    // Audio focus listener
    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                hasAudioFocus = true
                if (playbackDelayed || resumeOnFocusGain) {
                    player.play()
                    resumeOnFocusGain = false
                    playbackDelayed = false
                } else {
                    player.volume = 1.0f
                }
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                hasAudioFocus = false
                resumeOnFocusGain = false
                playbackDelayed = false
                player.pause()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                hasAudioFocus = false
                resumeOnFocusGain = player.isPlaying
                player.pause()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                player.volume = 0.3f
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        
        initializeAudioManager()
        initializePlayer()
        initializeMediaSession()
        initializeBluetooth()
        registerReceivers()
        
        // Create notification channel
        notificationHelper.createNotificationChannel()
    }

    private fun initializeAudioManager() {
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
        }
    }

    private fun initializePlayer() {
        val audioAttributes = Media3AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()

        player = ExoPlayer.Builder(this)
            .setAudioAttributes(audioAttributes, true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_LOCAL)
            .build()

        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                _isPlaying.value = isPlaying
                updateNotification()
                
                if (isPlaying) {
                    startForeground(NOTIFICATION_ID, notificationHelper.buildNotification(
                        currentSong.value, isPlaying, mediaSession.sessionToken
                    ))
                } else {
                    stopForeground(false)
                }
            }

            override fun onPlaybackStateChanged(playbackState: Int) {
                when (playbackState) {
                    Player.STATE_READY -> {
                        if (player.playWhenReady) {
                            requestAudioFocus()
                        }
                    }
                    Player.STATE_ENDED -> {
                        // Handle track completion
                        playNext()
                    }
                }
            }

            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                _playbackPosition.value = newPosition.positionMs
            }
        })
    }

    private fun initializeMediaSession() {
        val sessionActivityPendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        mediaSession = MediaSession.Builder(this, player)
            .setSessionActivity(sessionActivityPendingIntent)
            .build()
    }

    private fun initializeBluetooth() {
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        bluetoothAdapter?.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                if (profile == BluetoothProfile.A2DP) {
                    a2dpProfile = proxy
                }
            }

            override fun onServiceDisconnected(profile: Int) {
                if (profile == BluetoothProfile.A2DP) {
                    a2dpProfile = null
                }
            }
        }, BluetoothProfile.A2DP)
    }

    private fun registerReceivers() {
        // Register audio noisy receiver
        registerReceiver(audioNoisyReceiver, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
        
        // Register headset receiver
        registerReceiver(headsetReceiver, IntentFilter(Intent.ACTION_HEADSET_PLUG))
        
        // Register Bluetooth receivers
        val bluetoothFilter = IntentFilter().apply {
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED)
        }
        registerReceiver(bluetoothReceiver, bluetoothFilter)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession {
        return mediaSession
    }

    override fun onDestroy() {
        super.onDestroy()
        
        // Unregister receivers
        unregisterReceiver(audioNoisyReceiver)
        unregisterReceiver(headsetReceiver)
        unregisterReceiver(bluetoothReceiver)
        
        // Release audio focus
        abandonAudioFocus()
        
        // Release Bluetooth profile
        bluetoothAdapter?.closeProfileProxy(BluetoothProfile.A2DP, a2dpProfile)
        
        // Release media session and player
        mediaSession.release()
        player.release()
    }

    // Public methods for controlling playback
    fun playSong(song: Song) {
        serviceScope.launch {
            _currentSong.value = song
            val mediaItem = MediaItem.Builder()
                .setUri(song.uri)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle(song.title)
                        .setArtist(song.artist)
                        .setAlbumTitle(song.album)
                        .setArtworkUri(song.albumArtUri)
                        .build()
                )
                .build()
            
            player.setMediaItem(mediaItem)
            player.prepare()
            player.play()
        }
    }

    fun playPause() {
        if (player.isPlaying) {
            player.pause()
        } else {
            if (requestAudioFocus()) {
                player.play()
            }
        }
    }

    fun playNext() {
        serviceScope.launch {
            val nextSong = musicRepository.getNextSong(_currentSong.value)
            nextSong?.let { playSong(it) }
        }
    }

    fun playPrevious() {
        serviceScope.launch {
            val previousSong = musicRepository.getPreviousSong(_currentSong.value)
            previousSong?.let { playSong(it) }
        }
    }

    fun seekTo(position: Long) {
        player.seekTo(position)
        _playbackPosition.value = position
    }

    fun setRepeatMode(repeatMode: Int) {
        player.repeatMode = repeatMode
    }

    fun setShuffleMode(shuffleMode: Boolean) {
        player.shuffleModeEnabled = shuffleMode
    }

    // Audio focus management
    private fun requestAudioFocus(): Boolean {
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.requestAudioFocus(audioFocusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }

        return when (result) {
            AudioManager.AUDIOFOCUS_REQUEST_GRANTED -> {
                hasAudioFocus = true
                true
            }
            AudioManager.AUDIOFOCUS_REQUEST_DELAYED -> {
                playbackDelayed = true
                false
            }
            else -> {
                false
            }
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.abandonAudioFocusRequest(audioFocusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusChangeListener)
        }
        hasAudioFocus = false
    }

    // Bluetooth handling
    private fun handleBluetoothStateChange(state: Int) {
        when (state) {
            BluetoothAdapter.STATE_OFF, BluetoothAdapter.STATE_TURNING_OFF -> {
                // Bluetooth turned off, might want to pause or continue with local audio
            }
            BluetoothAdapter.STATE_ON -> {
                // Bluetooth turned on, reconnect to A2DP if needed
            }
        }
    }

    private fun handleBluetoothConnectionChange(state: Int) {
        when (state) {
            BluetoothAdapter.STATE_CONNECTED -> {
                // A2DP device connected
            }
            BluetoothAdapter.STATE_DISCONNECTED -> {
                // A2DP device disconnected, might want to pause
                if (player.isPlaying) {
                    player.pause()
                }
            }
        }
    }

    private fun updateNotification() {
        if (_currentSong.value != null) {
            val notification = notificationHelper.buildNotification(
                _currentSong.value,
                _isPlaying.value,
                mediaSession.sessionToken
            )
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val NOTIFICATION_ID = 1001
    }
}

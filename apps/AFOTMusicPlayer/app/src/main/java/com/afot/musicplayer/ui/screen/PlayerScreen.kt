package com.afot.musicplayer.ui.screen

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.afot.musicplayer.data.model.Song
import com.afot.musicplayer.ui.viewmodel.PlayerViewModel
import com.afot.musicplayer.utils.formatDuration
import kotlin.math.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlayerScreen(
    viewModel: PlayerViewModel = hiltViewModel()
) {
    val currentSong by viewModel.currentSong.collectAsStateWithLifecycle()
    val isPlaying by viewModel.isPlaying.collectAsStateWithLifecycle()
    val playbackPosition by viewModel.playbackPosition.collectAsStateWithLifecycle()
    val duration by viewModel.duration.collectAsStateWithLifecycle()
    val repeatMode by viewModel.repeatMode.collectAsStateWithLifecycle()
    val shuffleMode by viewModel.shuffleMode.collectAsStateWithLifecycle()
    val isBuffering by viewModel.isBuffering.collectAsStateWithLifecycle()

    // Animation states
    val albumArtRotation by animateFloatAsState(
        targetValue = if (isPlaying) 360f else 0f,
        animationSpec = tween(durationMillis = 10000),
        label = "albumRotation"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.surface,
                        MaterialTheme.colorScheme.surfaceVariant
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Top bar with controls
            TopBar(
                onBackClick = { /* Handle back navigation */ },
                onMenuClick = { /* Handle menu */ }
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Album art with vinyl effect
            AlbumArtSection(
                song = currentSong,
                isPlaying = isPlaying,
                rotation = albumArtRotation,
                modifier = Modifier.weight(1f)
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Song info
            SongInfoSection(
                song = currentSong,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Progress bar with custom design
            ProgressSection(
                position = playbackPosition,
                duration = duration,
                onSeek = viewModel::seekTo,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Control buttons
            ControlSection(
                isPlaying = isPlaying,
                isBuffering = isBuffering,
                repeatMode = repeatMode,
                shuffleMode = shuffleMode,
                onPlayPause = viewModel::playPause,
                onPrevious = viewModel::playPrevious,
                onNext = viewModel::playNext,
                onRepeat = viewModel::toggleRepeat,
                onShuffle = viewModel::toggleShuffle,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Additional controls
            AdditionalControlsSection(
                onFavorite = { /* Handle favorite */ },
                onPlaylist = { /* Handle add to playlist */ },
                onShare = { /* Handle share */ },
                onEqualizer = { /* Handle equalizer */ }
            )
        }
    }
}

@Composable
private fun TopBar(
    onBackClick: () -> Unit,
    onMenuClick: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBackClick) {
            Icon(
                imageVector = Icons.Rounded.KeyboardArrowDown,
                contentDescription = "Back",
                tint = MaterialTheme.colorScheme.onSurface
            )
        }

        Text(
            text = "Now Playing",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Medium
        )

        IconButton(onClick = onMenuClick) {
            Icon(
                imageVector = Icons.Rounded.MoreVert,
                contentDescription = "Menu",
                tint = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun AlbumArtSection(
    song: Song?,
    isPlaying: Boolean,
    rotation: Float,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        // Vinyl record background
        Canvas(
            modifier = Modifier
                .size(320.dp)
                .rotate(if (isPlaying) rotation else 0f)
        ) {
            drawVinylRecord()
        }

        // Album art
        Card(
            modifier = Modifier
                .size(280.dp)
                .rotate(if (isPlaying) rotation else 0f),
            shape = CircleShape,
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
        ) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(song?.albumArtUri ?: "")
                    .crossfade(true)
                    .build(),
                contentDescription = "Album Art",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
                placeholder = {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.MusicNote,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            )
        }

        // Center dot
        Box(
            modifier = Modifier
                .size(16.dp)
                .background(
                    MaterialTheme.colorScheme.onSurface,
                    CircleShape
                )
        )
    }
}

private fun DrawScope.drawVinylRecord() {
    val center = Offset(size.width / 2, size.height / 2)
    val radius = size.minDimension / 2

    // Outer ring
    drawCircle(
        color = Color.Black,
        radius = radius,
        center = center,
        style = Stroke(width = 4.dp.toPx())
    )

    // Grooves
    for (i in 1..8) {
        val grooveRadius = radius * (0.9f - i * 0.08f)
        drawCircle(
            color = Color.Black.copy(alpha = 0.3f),
            radius = grooveRadius,
            center = center,
            style = Stroke(width = 1.dp.toPx())
        )
    }
}

@Composable
private fun SongInfoSection(
    song: Song?,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = song?.title ?: "Unknown Title",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = song?.artist ?: "Unknown Artist",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        if (!song?.album.isNullOrEmpty()) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = song?.album ?: "",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun ProgressSection(
    position: Long,
    duration: Long,
    onSeek: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    var isDragging by remember { mutableStateOf(false) }
    var dragPosition by remember { mutableStateOf(0f) }

    Column(modifier = modifier) {
        // Custom progress bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { offset ->
                            isDragging = true
                            dragPosition = (offset.x / size.width).coerceIn(0f, 1f)
                        },
                        onDragEnd = {
                            isDragging = false
                            onSeek((dragPosition * duration).toLong())
                        }
                    ) { _, _ ->
                        // Handle drag
                    }
                }
        ) {
            // Progress indicator
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(
                        if (isDragging) dragPosition
                        else if (duration > 0) (position.toFloat() / duration).coerceIn(0f, 1f)
                        else 0f
                    )
                    .background(
                        Brush.horizontalGradient(
                            colors = listOf(
                                MaterialTheme.colorScheme.primary,
                                MaterialTheme.colorScheme.secondary
                            )
                        ),
                        RoundedCornerShape(3.dp)
                    )
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Time labels
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = formatDuration(position),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Text(
                text = formatDuration(duration),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ControlSection(
    isPlaying: Boolean,
    isBuffering: Boolean,
    repeatMode: Int,
    shuffleMode: Boolean,
    onPlayPause: () -> Unit,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onRepeat: () -> Unit,
    onShuffle: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Shuffle
        IconButton(
            onClick = onShuffle,
            modifier = Modifier.size(48.dp)
        ) {
            Icon(
                imageVector = Icons.Rounded.Shuffle,
                contentDescription = "Shuffle",
                tint = if (shuffleMode) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(24.dp)
            )
        }

        // Previous
        IconButton(
            onClick = onPrevious,
            modifier = Modifier.size(56.dp)
        ) {
            Icon(
                imageVector = Icons.Rounded.SkipPrevious,
                contentDescription = "Previous",
                tint = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.size(32.dp)
            )
        }

        // Play/Pause
        Card(
            modifier = Modifier.size(72.dp),
            shape = CircleShape,
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primary
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
        ) {
            IconButton(
                onClick = onPlayPause,
                modifier = Modifier.fillMaxSize()
            ) {
                if (isBuffering) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(32.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 3.dp
                    )
                } else {
                    Icon(
                        imageVector = if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                        contentDescription = if (isPlaying) "Pause" else "Play",
                        tint = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.size(36.dp)
                    )
                }
            }
        }

        // Next
        IconButton(
            onClick = onNext,
            modifier = Modifier.size(56.dp)
        ) {
            Icon(
                imageVector = Icons.Rounded.SkipNext,
                contentDescription = "Next",
                tint = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.size(32.dp)
            )
        }

        // Repeat
        IconButton(
            onClick = onRepeat,
            modifier = Modifier.size(48.dp)
        ) {
            Icon(
                imageVector = when (repeatMode) {
                    1 -> Icons.Rounded.RepeatOne
                    else -> Icons.Rounded.Repeat
                },
                contentDescription = "Repeat",
                tint = if (repeatMode > 0) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

@Composable
private fun AdditionalControlsSection(
    onFavorite: () -> Unit,
    onPlaylist: () -> Unit,
    onShare: () -> Unit,
    onEqualizer: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        IconButton(onClick = onFavorite) {
            Icon(
                imageVector = Icons.Rounded.FavoriteBorder,
                contentDescription = "Favorite",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        IconButton(onClick = onPlaylist) {
            Icon(
                imageVector = Icons.Rounded.PlaylistAdd,
                contentDescription = "Add to Playlist",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        IconButton(onClick = onShare) {
            Icon(
                imageVector = Icons.Rounded.Share,
                contentDescription = "Share",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        IconButton(onClick = onEqualizer) {
            Icon(
                imageVector = Icons.Rounded.Equalizer,
                contentDescription = "Equalizer",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

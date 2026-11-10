/**
 * TubePlay Simulator - Interactive Web Demo
 */

const sampleVideos = [
    {
        id: "jfKfPfyJRdk",
        title: "lofi hip hop radio 📚 - beats to relax/study to",
        channel: "Lofi Girl",
        thumb: "https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg",
        duration: "LIVE",
        views: "55K watching"
    },
    {
        id: "5qap5aO4i9A",
        title: "Lofi Hip Hop Radio 💤 - beats to sleep/chill to",
        channel: "Lofi Girl",
        thumb: "https://i.ytimg.com/vi/5qap5aO4i9A/hqdefault.jpg",
        duration: "LIVE",
        views: "30K watching"
    },
    {
        id: "TURbeWK2wwg",
        title: "Deep Focus ⚡ Ambient Study Music To Concentrate",
        channel: "Quiet Quest - Study Music",
        thumb: "https://i.ytimg.com/vi/TURbeWK2wwg/hqdefault.jpg",
        duration: "3:04:12",
        views: "14M views"
    },
    {
        id: "kJQP7kiw5Fk",
        title: "Luis Fonsi - Despacito ft. Daddy Yankee",
        channel: "Luis Fonsi",
        thumb: "https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg",
        duration: "4:42",
        views: "8.4B views"
    },
    {
        id: "fJ9rUzIMcZQ",
        title: "Queen – Bohemian Rhapsody (Official Video Remastered)",
        channel: "Queen Official",
        thumb: "https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg",
        duration: "5:59",
        views: "1.7B views"
    }
];

let player = null;
let currentVideo = null;
let isPlaying = false;
let favorites = JSON.parse(localStorage.getItem('tubeplay_favs') || '[]');
let history = JSON.parse(localStorage.getItem('tubeplay_hist') || '[]');
let playbackRates = [0.75, 1.0, 1.25, 1.5, 2.0];
let currentRateIndex = 1;
let isLoopOne = false;

// Initialize Time
function updateClock() {
    const now = new Date();
    const hrs = now.getHours();
    const mins = String(now.getMinutes()).padStart(2, '0');
    document.getElementById('status-time').textContent = `${hrs}:${mins}`;
}
setInterval(updateClock, 1000);
updateClock();

// Tab switching
document.querySelectorAll('.tab-item').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-item').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
        btn.classList.add('active');
        const targetId = btn.getAttribute('data-tab');
        document.getElementById(targetId).classList.add('active');
        if (targetId === 'tab-library') renderLibrary();
    });
});

// Category pills
document.querySelectorAll('.pill').forEach(pill => {
    pill.addEventListener('click', () => {
        document.querySelectorAll('.pill').forEach(p => p.classList.remove('active'));
        pill.classList.add('active');
        const query = pill.getAttribute('data-query');
        document.getElementById('search-input').value = query;
        performSearch(query);
    });
});

// Search input & suggestions
const searchInput = document.getElementById('search-input');
const suggestionsBox = document.getElementById('suggestions-box');
const clearSearchBtn = document.getElementById('clear-search-btn');

searchInput.addEventListener('input', () => {
    const val = searchInput.value.trim();
    clearSearchBtn.style.display = val ? 'block' : 'none';
    if (!val) {
        suggestionsBox.style.display = 'none';
        return;
    }
    // Fetch suggestions via Google API with JSONP script tag
    fetchSuggestions(val);
});

searchInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
        suggestionsBox.style.display = 'none';
        performSearch(searchInput.value);
    }
});

clearSearchBtn.addEventListener('click', () => {
    searchInput.value = '';
    clearSearchBtn.style.display = 'none';
    suggestionsBox.style.display = 'none';
    renderVideoList(sampleVideos, 'Featured Stations');
});

function fetchSuggestions(query) {
    window.handleSuggestions = function(data) {
        if (data && data[1] && data[1].length > 0) {
            suggestionsBox.innerHTML = '';
            data[1].slice(0, 6).forEach(item => {
                const text = typeof item === 'string' ? item : item[0];
                const div = document.createElement('div');
                div.className = 'suggestion-item';
                div.innerHTML = `<i class="fa-solid fa-magnifying-glass text-secondary"></i><span>${text}</span>`;
                div.addEventListener('click', () => {
                    searchInput.value = text;
                    suggestionsBox.style.display = 'none';
                    performSearch(text);
                });
                suggestionsBox.appendChild(div);
            });
            suggestionsBox.style.display = 'block';
        }
    };
    const s = document.createElement('script');
    s.src = `https://suggestqueries.google.com/complete/search?client=youtube&ds=yt&jsonp=handleSuggestions&q=${encodeURIComponent(query)}`;
    document.body.appendChild(s);
}

function performSearch(query) {
    document.getElementById('results-title').textContent = `Results for "${query}"`;
    // Filter sample videos or direct match
    const qLower = query.toLowerCase();
    const filtered = sampleVideos.filter(v => v.title.toLowerCase().includes(qLower) || v.channel.toLowerCase().includes(qLower));
    renderVideoList(filtered.length ? filtered : sampleVideos, `Results for "${query}"`);
}

function renderVideoList(videos, titleText = 'Videos') {
    const container = document.getElementById('video-list');
    container.innerHTML = '';
    videos.forEach(v => {
        const card = document.createElement('div');
        card.className = 'video-card';
        card.innerHTML = `
            <div class="thumb-box">
                <img src="${v.thumb}" alt="thumb">
                <span class="duration-tag">${v.duration}</span>
            </div>
            <div class="video-info">
                <div class="video-title">${v.title}</div>
                <div class="video-channel">${v.channel}</div>
                <div class="video-meta">${v.views}</div>
            </div>
        `;
        card.addEventListener('click', () => loadAndPlay(v));
        container.appendChild(card);
    });
}

// Player initialization
function onYouTubeIframeAPIReady() {
    player = new YT.Player('yt-player-container', {
        height: '100%',
        width: '100%',
        videoId: sampleVideos[0].id,
        playerVars: {
            'playsinline': 1,
            'autoplay': 1,
            'controls': 1,
            'rel': 0
        },
        events: {
            'onStateChange': onPlayerStateChange
        }
    });
}

function onPlayerStateChange(event) {
    if (event.data === YT.PlayerState.PLAYING) {
        isPlaying = true;
        updatePlayButtons();
    } else if (event.data === YT.PlayerState.PAUSED) {
        isPlaying = false;
        updatePlayButtons();
    } else if (event.data === YT.PlayerState.ENDED) {
        isPlaying = false;
        if (isLoopOne) {
            player.seekTo(0);
            player.playVideo();
        } else {
            updatePlayButtons();
        }
    }
}

function loadAndPlay(video) {
    currentVideo = video;
    // Add to history
    history = history.filter(h => h.id !== video.id);
    history.unshift(video);
    localStorage.setItem('tubeplay_hist', JSON.stringify(history));

    if (player && player.loadVideoById) {
        player.loadVideoById(video.id);
    }

    // Update Mini Player
    document.getElementById('mini-player').style.display = 'block';
    document.getElementById('mini-thumb').src = video.thumb;
    document.getElementById('mini-title').textContent = video.title;
    document.getElementById('mini-channel').textContent = video.channel;

    // Update Full Player
    document.getElementById('full-title').textContent = video.title;
    document.getElementById('full-channel').textContent = video.channel;
    document.getElementById('full-channel-top').textContent = video.channel;
    updateFavButton();

    isPlaying = true;
    updatePlayButtons();

    // Setup MediaSession API (Lock screen preview on mobile/desktop browsers)
    if ('mediaSession' in navigator) {
        navigator.mediaSession.metadata = new MediaMetadata({
            title: video.title,
            artist: video.channel,
            album: 'TubePlay Background Audio',
            artwork: [{ src: video.thumb, sizes: '512x512', type: 'image/jpeg' }]
        });
        navigator.mediaSession.setActionHandler('play', () => { player.playVideo(); });
        navigator.mediaSession.setActionHandler('pause', () => { player.pauseVideo(); });
        navigator.mediaSession.setActionHandler('seekforward', () => { seekDelta(15); });
        navigator.mediaSession.setActionHandler('seekbackward', () => { seekDelta(-15); });
    }
}

function togglePlay() {
    if (!player) return;
    if (isPlaying) {
        player.pauseVideo();
    } else {
        player.playVideo();
    }
}

function updatePlayButtons() {
    const playIcon = '<i class="fa-solid fa-play"></i>';
    const pauseIcon = '<i class="fa-solid fa-pause"></i>';
    document.getElementById('mini-play-btn').innerHTML = isPlaying ? pauseIcon : playIcon;
    document.getElementById('play-pause-btn').innerHTML = isPlaying ? pauseIcon : playIcon;
}

function seekDelta(seconds) {
    if (!player || !player.getCurrentTime) return;
    const cur = player.getCurrentTime();
    player.seekTo(cur + seconds, true);
}

// Mini player click expands Full Player
document.getElementById('mini-player-clickable').addEventListener('click', (e) => {
    if (e.target.closest('button')) return;
    document.getElementById('full-player').classList.add('open');
});

document.getElementById('close-player-btn').addEventListener('click', () => {
    document.getElementById('full-player').classList.remove('open');
});

document.getElementById('mini-play-btn').addEventListener('click', togglePlay);
document.getElementById('mini-forward-btn').addEventListener('click', () => seekDelta(15));
document.getElementById('play-pause-btn').addEventListener('click', togglePlay);
document.getElementById('rewind-btn').addEventListener('click', () => seekDelta(-15));
document.getElementById('forward-btn').addEventListener('click', () => seekDelta(15));

// Playback Speed
document.getElementById('speed-btn').addEventListener('click', () => {
    currentRateIndex = (currentRateIndex + 1) % playbackRates.length;
    const rate = playbackRates[currentRateIndex];
    document.getElementById('speed-btn').textContent = `${rate}x`;
    if (player && player.setPlaybackRate) player.setPlaybackRate(rate);
});

// Loop button
document.getElementById('loop-btn').addEventListener('click', () => {
    isLoopOne = !isLoopOne;
    document.getElementById('loop-btn').style.color = isLoopOne ? '#ff3b30' : '#fff';
});

// Scrubber Slider
const seekSlider = document.getElementById('seek-slider');
seekSlider.addEventListener('input', () => {
    if (!player || !player.getDuration) return;
    const dur = player.getDuration();
    const target = (seekSlider.value / 100) * dur;
    player.seekTo(target, true);
});

// Sync time progress loop
setInterval(() => {
    if (player && player.getCurrentTime && player.getDuration) {
        const cur = player.getCurrentTime();
        const dur = player.getDuration();
        if (dur > 0) {
            const pct = (cur / dur) * 100;
            seekSlider.value = pct;
            document.getElementById('mini-progress-fill').style.width = `${pct}%`;
            document.getElementById('time-current').textContent = formatTime(cur);
            document.getElementById('time-duration').textContent = formatTime(dur);
        }
    }
}, 500);

function formatTime(sec) {
    if (isNaN(sec) || sec < 0) return "0:00";
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
}

// Favorite Button
document.getElementById('full-fav-btn').addEventListener('click', () => {
    if (!currentVideo) return;
    const idx = favorites.findIndex(f => f.id === currentVideo.id);
    if (idx >= 0) {
        favorites.splice(idx, 1);
    } else {
        favorites.unshift(currentVideo);
    }
    localStorage.setItem('tubeplay_favs', JSON.stringify(favorites));
    updateFavButton();
});

function updateFavButton() {
    if (!currentVideo) return;
    const isFav = favorites.some(f => f.id === currentVideo.id);
    document.getElementById('full-fav-btn').innerHTML = isFav 
        ? '<i class="fa-solid fa-heart" style="color:#ff3b30;"></i>' 
        : '<i class="fa-regular fa-heart"></i>';
}

// Library Tab
function renderLibrary() {
    document.getElementById('fav-count').textContent = favorites.length;
    document.getElementById('hist-count').textContent = history.length;
    const isFavTab = document.getElementById('btn-fav-tab').classList.contains('active');
    const items = isFavTab ? favorites : history;
    const container = document.getElementById('library-list');
    container.innerHTML = '';
    if (items.length === 0) {
        container.innerHTML = `<p style="text-align:center; color:#8e8e93; padding: 40px;">No items in ${isFavTab ? 'Favorites' : 'History'}.</p>`;
        return;
    }
    items.forEach(v => {
        const card = document.createElement('div');
        card.className = 'video-card';
        card.innerHTML = `
            <div class="thumb-box"><img src="${v.thumb}"></div>
            <div class="video-info">
                <div class="video-title">${v.title}</div>
                <div class="video-channel">${v.channel}</div>
            </div>
        `;
        card.addEventListener('click', () => loadAndPlay(v));
        container.appendChild(card);
    });
}

document.getElementById('btn-fav-tab').addEventListener('click', () => {
    document.getElementById('btn-fav-tab').classList.add('active');
    document.getElementById('btn-hist-tab').classList.remove('active');
    renderLibrary();
});

document.getElementById('btn-hist-tab').addEventListener('click', () => {
    document.getElementById('btn-hist-tab').classList.add('active');
    document.getElementById('btn-fav-tab').classList.remove('active');
    renderLibrary();
});

// Initial list render
renderVideoList(sampleVideos, 'Featured Stations');

/**
 * TubePlay - Background Playback & Ad-Skip Injection Script
 *
 * This script runs in WKWebView to ensure YouTube playback continues
 * seamlessly when the app is backgrounded or the iOS device screen is locked.
 */

(function () {
    'use strict';

    if (window.__tubePlayInjected) return;
    window.__tubePlayInjected = true;

    // 1. Override Page Visibility API
    // YouTube uses document.hidden & document.visibilityState to pause video when minimized/locked
    try {
        Object.defineProperty(document, 'hidden', {
            get: function () { return false; },
            configurable: true
        });

        Object.defineProperty(document, 'visibilityState', {
            get: function () { return 'visible'; },
            configurable: true
        });

        Object.defineProperty(document, 'webkitHidden', {
            get: function () { return false; },
            configurable: true
        });

        Object.defineProperty(document, 'webkitVisibilityState', {
            get: function () { return 'visible'; },
            configurable: true
        });
    } catch (e) {
        console.warn('TubePlay: Failed to define visibility properties', e);
    }

    // 2. Block visibility and blur events that trigger pauses
    const blockEvent = function (e) {
        if (e.type === 'visibilitychange' || e.type === 'webkitvisibilitychange' || e.type === 'blur' || e.type === 'pagehide') {
            e.stopImmediatePropagation();
        }
    };

    window.addEventListener('visibilitychange', blockEvent, true);
    document.addEventListener('visibilitychange', blockEvent, true);
    window.addEventListener('webkitvisibilitychange', blockEvent, true);
    document.addEventListener('webkitvisibilitychange', blockEvent, true);
    window.addEventListener('blur', blockEvent, true);
    window.addEventListener('pagehide', blockEvent, true);

    // 3. Inject Ad-blocking & Clean Player Styles
    const styleEl = document.createElement('style');
    styleEl.id = 'tubeplay-custom-style';
    styleEl.textContent = `
        /* Hide YouTube ads and promotional banners */
        .video-ads,
        .ytp-ad-module,
        .ytp-ad-overlay-container,
        ytd-ad-slot-renderer,
        ytd-banner-promo-renderer,
        #player-ads,
        .ad-container,
        .ytd-companion-slot-renderer,
        ytd-in-feed-ad-layout-renderer,
        ytm-promoted-sparkles-web-renderer {
            display: none !important;
        }

        /* Ensure video fills webview properly */
        video.html5-main-video {
            object-fit: contain !important;
        }
    `;
    (document.head || document.documentElement).appendChild(styleEl);

    // 4. Native Bridge Helper
    function notifyNative(message) {
        try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tubePlayBridge) {
                window.webkit.messageHandlers.tubePlayBridge.postMessage(message);
            }
        } catch (err) {
            // Bridge not ready or outside iOS webview
        }
    }

    // 5. Keep track of current media element and state
    let activeVideo = null;
    let isUserPaused = false;

    function getActiveVideo() {
        if (activeVideo && activeVideo.isConnected) return activeVideo;
        const videos = document.querySelectorAll('video');
        for (let i = 0; i < videos.length; i++) {
            if (videos[i].src || videos[i].srcObject || videos[i].currentSrc) {
                activeVideo = videos[i];
                return activeVideo;
            }
        }
        return document.querySelector('video') || null;
    }

    function extractMetadata() {
        let title = '';
        let channel = '';
        let duration = 0;

        // Try YouTube web DOM
        const titleEl = document.querySelector('h1.title ytd-inline-playback-renderer, h1.title.style-scope.ytd-watch-metadata, .slim-video-information-title .yt-core-attributed-string, #title h1, h1.ytm-slim-video-metadata-title');
        if (titleEl) title = titleEl.textContent.trim();

        const channelEl = document.querySelector('#owner #channel-name, .ytm-channel-thumbnail-and-metadata .yt-core-attributed-string, ytd-channel-name yt-formatted-string');
        if (channelEl) channel = channelEl.textContent.trim();

        // Try MediaSession API
        if (navigator.mediaSession && navigator.mediaSession.metadata) {
            if (!title && navigator.mediaSession.metadata.title) {
                title = navigator.mediaSession.metadata.title;
            }
            if (!channel && navigator.mediaSession.metadata.artist) {
                channel = navigator.mediaSession.metadata.artist;
            }
        }

        const v = getActiveVideo();
        if (v && !isNaN(v.duration) && isFinite(v.duration)) {
            duration = v.duration;
        }

        return { title, channel, duration };
    }

    function attachVideoListeners(video) {
        if (!video || video.__tubePlayAttached) return;
        video.__tubePlayAttached = true;
        activeVideo = video;

        // Force inline playback
        video.setAttribute('playsinline', '');
        video.setAttribute('webkit-playsinline', '');
        video.playsInline = true;

        video.addEventListener('play', () => {
            isUserPaused = false;
            const meta = extractMetadata();
            notifyNative({
                type: 'play',
                currentTime: video.currentTime,
                duration: video.duration || 0,
                title: meta.title,
                channel: meta.channel
            });
        });

        video.addEventListener('pause', () => {
            // Notify native
            notifyNative({
                type: 'pause',
                currentTime: video.currentTime,
                duration: video.duration || 0
            });
        });

        video.addEventListener('timeupdate', () => {
            notifyNative({
                type: 'timeUpdate',
                currentTime: video.currentTime,
                duration: video.duration || 0
            });
        });

        video.addEventListener('ended', () => {
            notifyNative({
                type: 'ended',
                currentTime: video.currentTime,
                duration: video.duration || 0
            });
        });

        video.addEventListener('loadedmetadata', () => {
            const meta = extractMetadata();
            notifyNative({
                type: 'loadedMetadata',
                currentTime: video.currentTime,
                duration: video.duration || 0,
                title: meta.title,
                channel: meta.channel
            });
        });
    }

    // Monitor for newly created video tags
    const observer = new MutationObserver(() => {
        const video = getActiveVideo();
        if (video) attachVideoListeners(video);

        // Auto-skip ads
        skipAdsIfNeeded();
        // Auto-dismiss "Are you still watching?"
        dismissStillWatchingDialog();
    });

    observer.observe(document.body || document.documentElement, {
        childList: true,
        subtree: true
    });

    // 6. Ad Skipper Logic
    function skipAdsIfNeeded() {
        // Find standard skip button
        const skipButtons = document.querySelectorAll('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, button.ytp-ad-skip-button-text');
        skipButtons.forEach(btn => {
            if (btn && typeof btn.click === 'function') {
                btn.click();
            }
        });

        // Fast forward unskippable ads if playing
        const adPlayer = document.querySelector('.ad-showing video, .ytp-ad-player-overlay video');
        if (adPlayer && !adPlayer.paused) {
            adPlayer.playbackRate = 16.0;
            adPlayer.muted = true;
        }
    }

    // 7. Auto-confirm "Are you still watching?"
    function dismissStillWatchingDialog() {
        const confirmBtn = document.querySelector('yt-confirm-dialog-renderer #confirm-button button, ytd-popup-container yt-button-renderer#confirm-button button');
        if (confirmBtn && typeof confirmBtn.click === 'function') {
            confirmBtn.click();
        }
    }

    // Interval backup for ad skipping & video hook
    setInterval(() => {
        const video = getActiveVideo();
        if (video) attachVideoListeners(video);
        skipAdsIfNeeded();
        dismissStillWatchingDialog();
    }, 1000);

    // 8. Public Interface exposed for Native App (Swift)
    window.__tubePlay_play = function () {
        const v = getActiveVideo();
        if (v) {
            isUserPaused = false;
            return v.play().catch(() => {});
        }
    };

    window.__tubePlay_pause = function () {
        const v = getActiveVideo();
        if (v) {
            isUserPaused = true;
            v.pause();
        }
    };

    window.__tubePlay_togglePlay = function () {
        const v = getActiveVideo();
        if (v) {
            if (v.paused) {
                window.__tubePlay_play();
            } else {
                window.__tubePlay_pause();
            }
        }
    };

    window.__tubePlay_seek = function (seconds) {
        const v = getActiveVideo();
        if (v && !isNaN(seconds)) {
            v.currentTime = Math.max(0, Math.min(seconds, v.duration || seconds));
        }
    };

    window.__tubePlay_seekRelative = function (deltaSeconds) {
        const v = getActiveVideo();
        if (v) {
            v.currentTime = Math.max(0, Math.min(v.currentTime + deltaSeconds, v.duration || (v.currentTime + deltaSeconds)));
        }
    };

    window.__tubePlay_setPlaybackRate = function (rate) {
        const v = getActiveVideo();
        if (v && !isNaN(rate)) {
            v.playbackRate = rate;
        }
    };

    window.__tubePlay_getPlaybackState = function () {
        const v = getActiveVideo();
        const meta = extractMetadata();
        return {
            currentTime: v ? v.currentTime : 0,
            duration: v ? v.duration : 0,
            paused: v ? v.paused : true,
            title: meta.title,
            channel: meta.channel
        };
    };

    console.log('TubePlay: Background script successfully initialized.');
})();

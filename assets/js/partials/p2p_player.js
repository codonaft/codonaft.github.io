import '/assets/js/vendor/hls.min.js';
import { HlsJsP2PEngine } from 'p2p-media-loader-hlsjs';
import '/assets/js/vendor/vidstack-player/vidstack.js';
import BrowserDetector from '/assets/js/vendor/browser-dtector.min.js';

//const ICE_SERVERS = ['stun:stun.framasoft.org', 'stun:stun.l.google.com:19302', 'stun:stun.tula.nu', 'stun:stun.nextcloud.com', 'stun:stun.imp.ch', 'stun:stunserver2024.stunprotocol.org', 'stun:stun.hot-chilli.net', 'stun:stun.axialys.net', 'stun:stun.vomessen.de', 'stun:stun.streamnow.ch', 'stun:stun.antisip.com', 'stun:stun.cloudflare.com:3478'];
//const ICE_SERVERS = ['stun:stun.axialys.net', 'stun:stun.hot-chilli.net'];
const ICE_SERVERS = ['stun:stun.framasoft.org', 'stun:stun.l.google.com:19302'];
const TRACKERS = [
 'wss://media.codonaft.com/announce',
 //'wss://tracker.openwebtorrent.com',
 //'wss://tracker.webtorrent.dev',
];

const isValidURI = url => {
 try {
  new URL(url);
  return true;
 } catch (_) {
  return false;
 }
};

const pageLog = text => {
 if (window.location.pathname !== '/ru/video-test/') return;
 const p = document.createElement('p');
 p.textContent = text;
 p.style.color = 'green'
 p.style.fontWeight = '800';
 document.body.appendChild(p);
};

const codecSupported = codec =>
 ("ManagedMediaSource" in window && ManagedMediaSource.isTypeSupported(codec)) || ("MediaSource" in window && MediaSource.isTypeSupported(codec));

const HlsWithP2P = HlsJsP2PEngine.injectMixin(window.Hls);

const initializePlayer = player => {
 console.log('initializePlayer', player);
 const videoLayout = player.querySelector('media-video-layout');
 videoLayout.smallWhen = ({ width, height }) => false;
 videoLayout.playbackRates = { min: 0.5, max: 2.5, step: 0.05 };
 //videoLayout.hideQualityBitrate = true;

 player.addEventListener('play-fail', (event) => {
  if (event.isOriginTrusted) {
   player.play();
  }
 });

 // 'time-change'
 /*player.addEventListener('time-update', (event) => {
  console.log('time', event.detail);
 });*/

 player.addEventListener('stalled', (event) => {
  pageLog('stalled');
 });

 player.addEventListener("provider-change", (event) => {
  const provider = event.detail;
  console.log('provider-change', provider);
  if (provider?.type === 'hls') {
   const browser = new BrowserDetector(window.navigator.userAgent).parseUserAgent().name;
   const maxTrackers = browser === 'Safari' ? 1 : Infinity;
   const announceTrackers = TRACKERS.slice(0, maxTrackers);
   pageLog('trackers: ' + announceTrackers);

   provider.library = HlsWithP2P;
   provider.config = {
    p2p: {
     core: {
      //swarmId: '', // TODO
      // isP2PDisabled: false,
      // simultaneousHttpDownloads: 2,
      // simultaneousP2PDownloads: 3,
      // highDemandTimeWindow: 15,
      // httpDownloadTimeWindow: 3e3,
      // p2pDownloadTimeWindow: 6e3,
      // webRtcMaxMessageSize: 64 * 1024 - 1,
      // p2pNotReceivingBytesTimeoutMs: 2e3,
      // p2pInactiveLoaderDestroyTimeoutMs: 30 * 1e3,
      // httpNotReceivingBytesTimeoutMs: 3e3,
      // httpErrorRetries: 3,
      // p2pErrorRetries: 3,
      p2pErrorRetries: Infinity,
      announceTrackers,
      rtcConfig: { iceServers: ICE_SERVERS.map(urls => { return { urls }; }) },
     },
     onHlsJsCreated: (hls) => {
      hls.p2pEngine.addEventListener('onPeerConnect', (params) => {
       pageLog('Peer connected:' + params.peerId);
      });
      hls.p2pEngine.addEventListener('onPeerError', (params) => {
       pageLog('Peer error:' + params.peerId);
      });
      hls.p2pEngine.addEventListener('onPeerClose', (params) => {
       pageLog('Peer disconnected:' + params.peerId);
      });
      hls.p2pEngine.addEventListener('onChunkDownloaded', (bytesLength, downloadSource, peerId) => {
       if (peerId) {
        pageLog('Peer download:' + bytesLength + ' ' + peerId + ' ' + downloadSource);
       }
      });
      hls.p2pEngine.addEventListener('onChunkUploaded', (bytesLength, peerId) => {
       pageLog('Peer UPdownload:' + bytesLength + ' ' + peerId);
      });
      hls.p2pEngine.addEventListener('onSegmentLoaded', (params) => {
       if (params.peerId) {
         pageLog('P2P Segment loaded:' + params.bytesLength);
       }
      });
      hls.p2pEngine.addEventListener('onSegmentError', (params) => {
       pageLog('ERROR loading segment:' + JSON.stringify(params));
      });

      hls.on(Hls.Events.MANIFEST_PARSED, function (event, data) {
       console.log(data);
       pageLog('manifest loaded, found ' + data.levels.length + ' quality level');
      });
      hls.on(Hls.Events.BUFFER_CREATED, function (event, data) {
       pageLog('codec: ' + data.tracks.audiovideo.codec);
      });
      // TODO: connectedPeerCount

      pageLog(codecSupported(`video/mp4;codecs="avc1.64002a,mp4a.40.2"`) + ' ' + codecSupported(`video/webm;codecs="av01.0.09M.08.0.110.01.01.01.0,opus"`));
     },
    },
   };
  }
 });
};

if (Hls?.isSupported()) {
 pageLog('hls is supported');
 document.querySelectorAll('media-player').forEach(initializePlayer);
} else {
 pageLog('hls is unsupported!');
}

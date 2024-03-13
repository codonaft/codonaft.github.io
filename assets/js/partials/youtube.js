function updateYoutubeSize() {
  document.querySelectorAll('.ytdefer').forEach(function(container) {
    const width = container.parentElement.offsetWidth;
    container.style.width = width + 'px';

    const child = container.querySelector('[id^="ytdefer_vid"]');
    if (child) {
      const height = child.offsetWidth * ytdefer_aspect_ratio_inverted(container);
      container.style.height = height + 'px';
      child.style.border = '0.1rem solid black';
    }
  });
  document.querySelectorAll('.video-container').forEach(function(container) {
    container.style.backgroundColor = null;
    container.style.paddingTop = null;

    const iframe = container.querySelector('iframe');
    if (iframe) {
      const iframeHeight = iframe.offsetWidth * ytdefer_aspect_ratio_inverted(container);
      iframe.height = iframeHeight + 'px';
    }
  });
}

// hack for browsers that ignore events in some cases
function loopYoutubeResize() {
  updateYoutubeSize();
  setTimeout(loopYoutubeResize, 300);
}

const currentOnLoad = window.onload;
window.onload = function() {
  if (currentOnLoad) {
    currentOnLoad();
  }
  ytdefer_setup();
  updateYoutubeSize();
  loopYoutubeResize();
};

for (const i of ['resize', 'orientationchange']) {
  window.addEventListener(i, updateYoutubeSize);
}

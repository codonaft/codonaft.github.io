document.addEventListener("DOMContentLoaded", function() {
  for (const i of document.querySelectorAll('a')) {
    if (!i.hasAttribute('href')) { continue; }
    const url = new URL(i.href);
    if (url.hostname !== window.location.hostname) {
      i.setAttribute('target', '_blank');
      if (url.hostname === 'www.youtube.com') {
        i.setAttribute('rel', 'noopener');
      } else {
        i.setAttribute('rel', 'noopener noreferrer');
      }
    }
  }
});

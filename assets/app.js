// Page side of the host contract (see src/protocol.odin).
// Host -> page: "html:" | "newdoc:" | "changed:<keys>" | "status:<text>". Page -> host: "ready" | "link:<href>".
(() => {
  const content = document.getElementById('content');
  const status = document.getElementById('status');
  const post = (msg) => window.chrome.webview.postMessage(msg);

  // GitHub-style heading ids, so "#some-heading" links work.
  const slug = (text) =>
    text.trim().toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, '').replace(/\s+/g, '-');

  const addHeadingIds = () => {
    const seen = new Map();
    content.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach((h) => {
      if (h.id) return;
      const base = slug(h.textContent);
      const n = seen.get(base) || 0;
      seen.set(base, n + 1);
      h.id = n ? `${base}-${n}` : base;
    });
  };

  const setHtml = (html, keepScroll) => {
    const y = window.scrollY;
    content.innerHTML = html;
    addHeadingIds();
    content.querySelectorAll('pre code').forEach((el) => hljs.highlightElement(el));
    window.scrollTo(0, keepScroll ? y : 0);
  };

  // Scroll to the first changed block, mark all of them for 2 s (keys = data-sourcepos values).
  let flashTimer;
  const flashChanged = (keys) => {
    const els = keys
      .filter((k) => /^\d+:\d+-\d+:\d+$/.test(k))
      .flatMap((k) => [...content.querySelectorAll(`[data-sourcepos="${k}"]`)]);
    if (!els.length) return;
    els.sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1));
    els.forEach((el) => el.classList.add('flash'));
    els[0].scrollIntoView({ block: 'center' });
    clearTimeout(flashTimer);
    flashTimer = setTimeout(
      () => content.querySelectorAll('.flash').forEach((el) => el.classList.remove('flash')),
      2000,
    );
  };

  const setStatus = (text) => {
    status.textContent = text;
    status.hidden = text === '';
  };

  window.chrome.webview.addEventListener('message', (e) => {
    const msg = e.data;
    if (typeof msg !== 'string') return;
    if (msg.startsWith('html:')) setHtml(msg.slice('html:'.length), true);
    else if (msg.startsWith('newdoc:')) setHtml(msg.slice('newdoc:'.length), false);
    else if (msg.startsWith('changed:')) flashChanged(msg.slice('changed:'.length).split('|'));
    else if (msg.startsWith('status:')) setStatus(msg.slice('status:'.length));
  });

  // Every link click is ours: #anchor scrolls, anything else goes to the host.
  // auxclick = middle click: its default opens a new window, so stop it too.
  const onLinkClick = (e) => {
    const a = e.target.closest('a[href]');
    if (!a) return;
    e.preventDefault();
    const href = a.getAttribute('href');
    if (href.startsWith('#')) {
      const id = decodeURIComponent(href.slice(1));
      const el = document.getElementById(id) || document.getElementsByName(id)[0];
      if (el) el.scrollIntoView();
    } else {
      post('link:' + href);
    }
  };
  document.addEventListener('click', onLinkClick);
  document.addEventListener('auxclick', onLinkClick);

  post('ready');
})();

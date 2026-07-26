// Shared plumbing for the runtime pages.
//
// Everything printed here goes two places: the on-page terminal (so the
// preview itself is useful) and console.log/error, which the app's script
// message handler mirrors into its console panel.

const CF = (function () {
  const params = new URLSearchParams(location.search);
  const out = () => document.getElementById('out');
  const statusBar = () => document.getElementById('status');

  function append(text, cls) {
    const node = document.createElement('span');
    node.className = 'line' + (cls ? ' ' + cls : '');
    node.textContent = text.endsWith('\n') ? text : text + '\n';
    out().appendChild(node);
    window.scrollTo(0, document.body.scrollHeight);
  }

  function status(text, state) {
    const bar = statusBar();
    bar.className = state || '';
    bar.querySelector('span.label').textContent = text;
  }

  // Mirror to the host app's console panel.
  const nativeLog = console.log.bind(console);
  const nativeError = console.error.bind(console);

  return {
    param: (name) => params.get(name),
    print: (text) => { append(text); nativeLog(text); },
    printError: (text) => { append(text, 'err'); nativeError(text); },
    printMeta: (text) => { append(text, 'meta'); },
    html: (node) => { out().appendChild(node); },
    status,
    async source() {
      const src = params.get('src');
      if (!src) throw new Error('no source given');
      const response = await fetch(src, { cache: 'no-store' });
      if (!response.ok) throw new Error('could not read the file (' + response.status + ')');
      return await response.text();
    },
    since(start) {
      return ((performance.now() - start) / 1000).toFixed(2) + 's';
    }
  };
})();

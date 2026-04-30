(function () {
  const rawBase = (window.BLOOM_API_BASE_URL || '').trim();
  const normalizedBase = rawBase ? rawBase.replace(/\/+$/, '') : '';

  window.BLOOM_API_BASE_URL = normalizedBase;
  window.apiUrl = function apiUrl(path) {
    const normalizedPath = path.startsWith('/') ? path : `/${path}`;
    return `${normalizedBase}${normalizedPath}`;
  };
})();

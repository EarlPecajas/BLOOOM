// Server-side proxy for the Tripo3D API (https://developers.tripo3d.ai/en/docs).
// Keeps TRIPO_API_KEY out of the browser: the frontend never talks to
// api.tripo3d.ai directly, only to this endpoint.
//
//   POST /api/tripo3d   { mode: 'image', imageUrl }     -> create an image_to_model task
//   POST /api/tripo3d   { mode: 'text',  prompt }        -> create a text_to_model task
//   GET  /api/tripo3d?task_id=...                        -> poll task status/result
//   GET  /api/tripo3d?model_url=<tripo glb url>           -> stream the generated model
//
// The model_url route exists so the browser downloads the generated .glb
// from our own origin instead of fetching a third-party Tripo URL directly,
// which would otherwise be at the mercy of Tripo's CORS configuration. The
// hostname is restricted to Tripo's own domains — this is a same-purpose
// download relay, not a general-purpose URL fetcher.
//
// Both JSON responses are passed through close to what Tripo returns, so the
// frontend can surface Tripo's own error message if the request shape
// ever needs adjusting for an API version change.

const TRIPO_API_BASE = 'https://api.tripo3d.ai/v2/openapi';
const TRIPO_DOWNLOAD_HOST_SUFFIXES = ['.tripo3d.com', '.tripo3d.ai', 'tripo3d.com', 'tripo3d.ai'];

function guessImageType(url) {
  const ext = (String(url).split('?')[0].split('.').pop() || '').toLowerCase();
  if (ext === 'jpg' || ext === 'jpeg') return 'jpg';
  if (ext === 'png') return 'png';
  if (ext === 'webp') return 'webp';
  return 'jpg';
}

function isAllowedTripoDownloadUrl(rawUrl) {
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    return false;
  }
  if (parsed.protocol !== 'https:') return false;
  return TRIPO_DOWNLOAD_HOST_SUFFIXES.some((suffix) => parsed.hostname === suffix || parsed.hostname.endsWith(suffix));
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  const apiKey = process.env.TRIPO_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'TRIPO_API_KEY is not configured on the server.' });
  }

  try {
    if (req.method === 'POST') {
      const { mode, imageUrl, prompt, negativePrompt } = req.body || {};

      let taskBody;
      if (mode === 'image') {
        if (!imageUrl) return res.status(400).json({ error: 'imageUrl is required for image mode.' });
        taskBody = { type: 'image_to_model', file: { type: guessImageType(imageUrl), url: imageUrl } };
      } else if (mode === 'text') {
        if (!prompt) return res.status(400).json({ error: 'prompt is required for text mode.' });
        taskBody = { type: 'text_to_model', prompt };
        if (negativePrompt) taskBody.negative_prompt = negativePrompt;
      } else {
        return res.status(400).json({ error: 'mode must be "image" or "text".' });
      }

      const tripoRes = await fetch(`${TRIPO_API_BASE}/task`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(taskBody),
      });
      const data = await tripoRes.json().catch(() => ({}));

      if (!tripoRes.ok || data.code) {
        return res.status(tripoRes.ok ? 502 : tripoRes.status).json({ error: 'Tripo3D task creation failed', details: data });
      }

      return res.status(200).json({ task_id: data.data && data.data.task_id });
    }

    if (req.method === 'GET') {
      const modelUrl = req.query && req.query.model_url;
      if (modelUrl) {
        if (!isAllowedTripoDownloadUrl(modelUrl)) {
          return res.status(400).json({ error: 'model_url must be an https URL on a tripo3d domain.' });
        }
        const modelRes = await fetch(modelUrl);
        if (!modelRes.ok) {
          return res.status(502).json({ error: 'Failed to download the generated model from Tripo3D.' });
        }
        const buffer = Buffer.from(await modelRes.arrayBuffer());
        res.setHeader('Content-Type', 'model/gltf-binary');
        return res.status(200).send(buffer);
      }

      const taskId = req.query && req.query.task_id;
      if (!taskId) return res.status(400).json({ error: 'task_id or model_url is required.' });

      const tripoRes = await fetch(`${TRIPO_API_BASE}/task/${encodeURIComponent(taskId)}`, {
        headers: { Authorization: `Bearer ${apiKey}` },
      });
      const data = await tripoRes.json().catch(() => ({}));

      if (!tripoRes.ok || data.code) {
        return res.status(tripoRes.ok ? 502 : tripoRes.status).json({ error: 'Tripo3D status check failed', details: data });
      }

      return res.status(200).json(data.data || {});
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (error) {
    console.error('Tripo3D proxy error:', error);
    return res.status(500).json({ error: 'Tripo3D request failed', details: error.message });
  }
};

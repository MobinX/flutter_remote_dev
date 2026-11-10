/**
 * Cloudflare Worker for Streaming Flutter OTA Patches from GitHub /lastpatch
 *
 * Designed specifically for low-memory environments (128MB worker ceiling).
 * Streams patch files chunk-by-chunk using Web Streams API (zero buffering in RAM).
 */

export default {
  async fetch(request, env, ctx) {
    // 1. Handle CORS Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: getCorsHeaders(),
      });
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', {
        status: 405,
        headers: getCorsHeaders(),
      });
    }

    const url = new URL(request.url);
    let pathname = decodeURIComponent(url.pathname);

    // Normalize path: support root '/', '/manifest.json', or '/lastpatch/manifest.json'
    if (pathname === '/' || pathname === '') {
      pathname = '/manifest.json';
    }

    // Strip leading slash
    let relativePath = pathname.replace(/^\/+/, '');

    // If client requested with /lastpatch/ prefix, strip it so it maps directly
    if (relativePath.startsWith('lastpatch/')) {
      relativePath = relativePath.replace(/^lastpatch\//, '');
    }

    // Prevent path traversal attacks
    if (relativePath.includes('..') || relativePath.startsWith('.')) {
      return new Response('Forbidden', { status: 403, headers: getCorsHeaders() });
    }

    // GitHub repository configuration from environment variables
    const owner = env.GITHUB_OWNER || 'YOUR_GITHUB_USERNAME_OR_ORG';
    const repo = env.GITHUB_REPO || 'flutter_remote_dev';
    const branch = env.GITHUB_BRANCH || 'main';
    const githubToken = env.GITHUB_TOKEN; // Optional: Required for private repos

    // Diagnostic endpoint: /status or /health
    if (relativePath === 'status' || relativePath === 'health') {
      return new Response(
        JSON.stringify(
          {
            service: 'Flutter Patcher OTA Streamer',
            status: 'operational',
            upstream: {
              owner,
              repo,
              branch,
              path: 'lastpatch/',
            },
            endpoints: {
              manifest: `${url.origin}/manifest.json`,
              patch_zip: `${url.origin}/patch.zip`,
            },
            timestamp: new Date().toISOString(),
          },
          null,
          2
        ),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            ...getCorsHeaders(),
          },
        }
      );
    }

    // Target file path inside GitHub repo
    const targetFilePath = `lastpatch/${relativePath}`;

    // GitHub source URL: Raw CDN or API endpoint (for private repos)
    const githubRawUrl = `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${targetFilePath}`;

    const fetchHeaders = new Headers({
      'User-Agent': 'Cloudflare-Worker-Flutter-Patcher',
    });

    if (githubToken) {
      fetchHeaders.set('Authorization', `Bearer ${githubToken}`);
    }

    try {
      // Fetch the requested asset from GitHub
      const githubRes = await fetch(githubRawUrl, {
        method: request.method,
        headers: fetchHeaders,
        cf: {
          cacheTtl: relativePath === 'manifest.json' ? 0 : 300,
          cacheEverything: relativePath !== 'manifest.json',
        },
      });

      if (!githubRes.ok) {
        if (githubRes.status === 404) {
          return new Response(
            JSON.stringify(
              {
                error: 'Not Found',
                message: `File '${targetFilePath}' does not exist in branch '${branch}'.`,
                repo: `${owner}/${repo}`,
                checked_url: githubRawUrl,
              },
              null,
              2
            ),
            {
              status: 404,
              headers: {
                'Content-Type': 'application/json',
                ...getCorsHeaders(),
              },
            }
          );
        }
        return new Response(`GitHub upstream returned HTTP ${githubRes.status}`, {
          status: githubRes.status,
          headers: getCorsHeaders(),
        });
      }

      // If manifest.json is requested, parse and inject absolute worker URL into `patch_url`
      if (relativePath === 'manifest.json' && request.method === 'GET') {
        const manifestText = await githubRes.text();
        let manifestData;
        try {
          manifestData = JSON.parse(manifestText);
        } catch {
          // If not valid JSON, fallback to direct text
          return new Response(manifestText, {
            status: 200,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              ...getCorsHeaders(),
            },
          });
        }

        // Dynamically resolve patch_url to this Worker instance so Flutter client downloads via worker
        if (manifestData.patch_url && !manifestData.patch_url.startsWith('http://') && !manifestData.patch_url.startsWith('https://')) {
          const cleanPatchPath = manifestData.patch_url.replace(/^\/+/, '');
          manifestData.patch_url = `${url.origin}/${cleanPatchPath}`;
        }

        return new Response(JSON.stringify(manifestData, null, 2), {
          status: 200,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            ...getCorsHeaders(),
          },
        });
      }

      // 2. Binary / Static Assets (e.g. patch.zip, .so binaries, images):
      // Must stream chunk-by-chunk to stay under worker low-memory ceiling!
      const contentType = getMimeType(relativePath, githubRes.headers.get('content-type'));
      const contentLength = githubRes.headers.get('content-length');
      const etag = githubRes.headers.get('etag');

      const responseHeaders = new Headers({
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=120, s-maxage=300',
        ...getCorsHeaders(),
      });

      if (contentLength) {
        responseHeaders.set('Content-Length', contentLength);
      }
      if (etag) {
        responseHeaders.set('ETag', etag);
      }

      if (request.method === 'HEAD') {
        return new Response(null, {
          status: 200,
          headers: responseHeaders,
        });
      }

      // Chunk read -> Chunk write TransformStream pipeline
      const { readable, writable } = new TransformStream({
        transform(chunk, controller) {
          // Stream chunks as they arrive directly to client without buffering
          controller.enqueue(chunk);
        },
      });

      // Stream data from GitHub response into the client writable stream asynchronously
      ctx.waitUntil(
        githubRes.body.pipeTo(writable).catch((err) => {
          console.error('Streaming pipeline error:', err);
        })
      );

      return new Response(readable, {
        status: 200,
        headers: responseHeaders,
      });
    } catch (err) {
      return new Response(
        JSON.stringify({ error: 'Internal Worker Gateway Error', details: err.message }),
        {
          status: 502,
          headers: {
            'Content-Type': 'application/json',
            ...getCorsHeaders(),
          },
        }
      );
    }
  },
};

function getCorsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, Range',
    'Access-Control-Max-Age': '86400',
  };
}

function getMimeType(filename, fallback) {
  if (filename.endsWith('.json')) return 'application/json; charset=utf-8';
  if (filename.endsWith('.zip')) return 'application/zip';
  if (filename.endsWith('.so')) return 'application/octet-stream';
  if (filename.endsWith('.png')) return 'image/png';
  if (filename.endsWith('.jpg') || filename.endsWith('.jpeg')) return 'image/jpeg';
  if (filename.endsWith('.txt')) return 'text/plain; charset=utf-8';
  return fallback || 'application/octet-stream';
}

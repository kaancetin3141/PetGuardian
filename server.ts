/**
 * PetGuardian — static web server for the Flutter web build.
 *
 * Zero dependencies: uses Bun's built-in `Bun.serve` + `Bun.file`.
 * Serves `build/web` (output of `flutter build web --release`) on port 3006.
 *
 * Usage: bun run dev   (hot reload)   |   bun server.ts
 */
import { join, normalize } from "node:path";

const PORT = 3006;
const HOST = "0.0.0.0";
const ROOT = join(import.meta.dir, "build", "web");

const MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".htm": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".webp": "image/webp",
  ".webmanifest": "application/manifest+json",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".txt": "text/plain; charset=utf-8",
  ".map": "application/json",
};

function headersFor(filePath: string): Record<string, string> {
  const ext = filePath.slice(filePath.lastIndexOf(".")).toLowerCase();
  return {
    "content-type": MIME[ext] ?? "application/octet-stream",
    // short-lived cache so redeploys are picked up quickly
    "cache-control": "public, max-age=300",
  };
}

Bun.serve({
  port: PORT,
  hostname: HOST,
  fetch: async (req): Promise<Response> => {
    const url = new URL(req.url);
    let pathname = decodeURIComponent(url.pathname);

    if (pathname.endsWith("/")) pathname += "index.html";

    // normalize + containment check (no path traversal)
    const filePath = normalize(join(ROOT, pathname));
    if (!filePath.startsWith(normalize(ROOT))) {
      return new Response("Forbidden", { status: 403 });
    }

    let file = Bun.file(filePath);
    if (await file.exists()) {
      return new Response(file, { headers: headersFor(filePath) });
    }

    // SPA fallback → index.html (client-side routing)
    const indexPath = join(ROOT, "index.html");
    file = Bun.file(indexPath);
    if (await file.exists()) {
      return new Response(file, { headers: headersFor(indexPath) });
    }

    return new Response(
      "PetGuardian web build not found. Run: flutter build web --release",
      { status: 503, headers: { "content-type": "text/plain; charset=utf-8" } },
    );
  },
});

console.log(`[petguardian] serving build/web on http://localhost:${PORT}`);

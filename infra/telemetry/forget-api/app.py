"""Sidecar HTTP server for per-install telemetry delete (TELEM-06).

Accepts: DELETE /api/forget?install_id_hash=<64-char-hex>
Runs:    DELETE FROM website_event WHERE event_name LIKE '%:<hash>'
Returns: {"deleted": <int>}

Dogfood-grade — no authentication. Add basic auth before non-founder installs.
"""
import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

import psycopg2

DATABASE_URL = os.environ["DATABASE_URL"]


class ForgetHandler(BaseHTTPRequestHandler):
    def do_DELETE(self):
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)
        install_id_hash = qs.get("install_id_hash", [None])[0]

        if not install_id_hash:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"error": "install_id_hash query parameter required"}')
            return

        try:
            conn = psycopg2.connect(DATABASE_URL)
            cur = conn.cursor()
            # Events stored as "event_name:<install_id_hash>" in umami's
            # event_name field.  DELETE all matching rows.
            cur.execute(
                "DELETE FROM website_event WHERE event_name LIKE %s",
                (f"%:{install_id_hash}",),
            )
            deleted = cur.rowcount
            conn.commit()
            cur.close()
            conn.close()
        except Exception as exc:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(exc)}).encode())
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"deleted": deleted}).encode())

    def do_GET(self):
        """Health check endpoint."""
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status": "ok", "service": "smoodle-telemetry-forget-api"}')

    def log_message(self, fmt, *args):
        # Suppress per-request logs; startup log is enough.
        pass


if __name__ == "__main__":
    print("forget-api listening on :8080")
    HTTPServer(("0.0.0.0", 8080), ForgetHandler).serve_forever()

"""Sidecar HTTP server for per-install telemetry delete (TELEM-06).

Accepts: DELETE /api/forget?install_id_hash=<64-char-hex>
Runs:    DELETE FROM website_event
         WHERE event_id IN (
           SELECT website_event_id FROM event_data
           WHERE data_key = 'install_id_hash' AND string_value = $1
         )
Returns: {"deleted": <int>}

Umami v3 stores custom event data in a separate `event_data` table keyed
on (website_event_id, data_key). The smoodle client sends install_id_hash
as one of those rows (data_key='install_id_hash'). The previous filter
`event_name LIKE '%:<hash>'` never matched because telemetry.{sh,ps1}
writes event_name="install_started" without a hash suffix.

Dogfood-grade — no authentication. Add basic auth before non-founder installs.

Scope limitation (accepted, TELEM-06 dogfood): `session` and `session_data`
rows are NOT deleted. Sessions in umami v3 are keyed on a request
fingerprint (ua, screen, ip-derived) not on install_id_hash, so we
cannot reliably attribute them. CP-3 privacy-trigger `null_hostname` +
`round_event_timestamp` reduce session-side PII to near-zero already.
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
            # Umami v3 does NOT declare FK constraints between event_data
            # and website_event at the DB layer (enforced in Prisma app
            # layer only). Verified on dxc 2026-05-25: zero foreign keys
            # on event_data. Must explicitly delete both sides in one tx.
            cur.execute(
                """
                CREATE TEMP TABLE _target_events ON COMMIT DROP AS
                SELECT DISTINCT website_event_id AS event_id
                FROM event_data
                WHERE data_key = 'install_id_hash'
                  AND string_value = %s
                """,
                (install_id_hash,),
            )
            cur.execute(
                "DELETE FROM event_data WHERE website_event_id IN (SELECT event_id FROM _target_events)"
            )
            cur.execute(
                "DELETE FROM website_event WHERE event_id IN (SELECT event_id FROM _target_events)"
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

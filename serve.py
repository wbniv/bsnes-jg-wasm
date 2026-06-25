#!/usr/bin/env python3
"""Serve web/ for local development.

Single-threaded WASM (the snes9x showcase core, and a single-thread bsnes-jg build)
needs no special headers and runs on any static host. A *threaded* core build needs
the page to be cross-origin isolated — pass --isolated to add the COOP/COEP headers.
"""
import argparse
import http.server
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    isolated = False

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        if self.isolated:
            # Required for SharedArrayBuffer / WASM threads (web.dev/articles/webassembly-threads)
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # .wasm must be served with the right type for streaming compilation
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-p", "--port", type=int, default=8000)
    ap.add_argument("--isolated", action="store_true",
                    help="send COOP/COEP headers (needed only for a threaded core build)")
    args = ap.parse_args()

    Handler.isolated = args.isolated
    Handler.extensions_map[".wasm"] = "application/wasm"

    httpd = http.server.ThreadingHTTPServer(("0.0.0.0", args.port), Handler)
    mode = "cross-origin isolated (COOP/COEP)" if args.isolated else "plain (single-thread)"
    print(f"serving {ROOT}")
    print(f"  http://localhost:{args.port}   [{mode}]")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nbye")


if __name__ == "__main__":
    main()

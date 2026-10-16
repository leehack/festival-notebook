"""Serve a built web app locally with the isolation headers required by WASM."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    directory = Path(__file__).resolve().parents[1] / "build" / "web"
    if not (directory / "index.html").is_file():
        parser.error("Run flutter build web --release first")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), partial(Handler, directory=str(directory)))
    print(f"Festival Notebook: http://127.0.0.1:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

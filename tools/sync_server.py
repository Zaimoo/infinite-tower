import os
import json
import http.server
import socketserver
import urllib.parse
import threading
import subprocess

PORT = 38291
SRC_DIR = os.path.abspath("src")

def get_branch_files():
    # Get modified/added files in git relative to origin/main
    try:
        res = subprocess.run(["git", "diff", "--name-only", "origin/main"], capture_output=True, text=True, check=True)
        files = [line.strip().replace(chr(92), "/") for line in res.stdout.splitlines() if line.strip().startswith("src/") and line.strip().endswith(".luau")]
        if files:
            return set(files)
    except Exception as e:
        print("Git diff error:", e)
    return None

def scan_files(only_branch=True):
    branch_set = get_branch_files() if only_branch else None
    file_list = []
    idx = 0
    for dirpath, _, filenames in os.walk(SRC_DIR):
        for f in filenames:
            if not f.endswith(".luau"):
                continue
            full_path = os.path.join(dirpath, f)
            rel = "src/" + os.path.relpath(full_path, SRC_DIR).replace(chr(92), "/")
            
            if branch_set is not None and rel not in branch_set:
                continue

            parts = rel[4:].split("/")
            base = parts[0]
            
            if base == "ReplicatedStorage":
                service = "ReplicatedStorage"
                folders = parts[1:-1]
            elif base == "ServerScriptService":
                service = "ServerScriptService"
                folders = parts[1:-1]
            elif base == "StarterPlayerScripts":
                service = "StarterPlayer"
                folders = ["StarterPlayerScripts"] + parts[1:-1]
            else:
                continue
                
            fname = parts[-1]
            if fname.endswith(".server.luau"):
                cname = "Script"
                iname = fname[:-12]
            elif fname.endswith(".client.luau"):
                cname = "LocalScript"
                iname = fname[:-12]
            elif fname.endswith(".luau"):
                cname = "ModuleScript"
                iname = fname[:-5]
            else:
                continue
                
            file_list.append({
                "id": idx,
                "localPath": rel,
                "fullPath": full_path,
                "service": service,
                "folders": folders,
                "instanceName": iname,
                "className": cname,
            })
            idx += 1
    return file_list

FILES = scan_files(only_branch=True)
print(f"Loaded {len(FILES)} modified files to sync.")

class SyncHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/files":
            manifest = [
                {
                    "id": f["id"],
                    "service": f["service"],
                    "folders": f["folders"],
                    "name": f["instanceName"],
                    "className": f["className"],
                    "relPath": f["localPath"],
                }
                for f in FILES
            ]
            data = json.dumps(manifest).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        elif parsed.path == "/file":
            qs = urllib.parse.parse_qs(parsed.query)
            file_id = int(qs.get("id", ["-1"])[0])
            if 0 <= file_id < len(FILES):
                with open(FILES[file_id]["fullPath"], "r", encoding="utf-8") as fh:
                    content = fh.read().encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
            else:
                self.send_response(404)
                self.end_headers()
        elif parsed.path == "/ping":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"pong")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/done":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            threading.Thread(target=self.server.shutdown, daemon=True).start()
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    with socketserver.TCPServer(("127.0.0.1", PORT), SyncHandler) as httpd:
        print(f"Sync server listening on 127.0.0.1:{PORT}")
        httpd.serve_forever()
    print("Sync server finished and stopped.")

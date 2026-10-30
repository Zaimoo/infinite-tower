"""
Bridge utility to interact with the live Blender instance via mcp-for-blender (port 9876).
Provides CLI operations for status, scene information, code execution, and view capture.
"""
import sys
import json
import subprocess
import argparse

def call_blender_mcp(tool_name: str, arguments: dict):
    proc = subprocess.Popen(
        ["uvx", "mcp-for-blender"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    # Initialize JSON-RPC handshake
    init_msg = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "infinite-tower-bridge", "version": "1.0"},
        },
    }
    proc.stdin.write(json.dumps(init_msg) + "\n")
    proc.stdin.flush()
    proc.stdout.readline()  # discard init response

    # Send tool call
    call_msg = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {"name": tool_name, "arguments": arguments},
    }
    proc.stdin.write(json.dumps(call_msg) + "\n")
    proc.stdin.flush()
    raw_response = proc.stdout.readline()
    proc.terminate()

    try:
        data = json.loads(raw_response)
        if "error" in data:
            return {"error": data["error"]}
        return data.get("result", {})
    except Exception as e:
        return {"error": str(e), "raw": raw_response}

def cmd_status(args):
    res = call_blender_mcp("get_addon_status", {"user_prompt": "check status"})
    print(json.dumps(res, indent=2))

def cmd_info(args):
    fields = args.fields.split(",") if args.fields else ["location", "size", "children", "hidden"]
    res = call_blender_mcp("get_scene_info", {"fields": fields, "user_prompt": "get scene info"})
    for content in res.get("content", []):
        if content.get("type") == "text":
            print(content.get("text"))

def cmd_exec(args):
    if args.file:
        with open(args.file, "r", encoding="utf-8") as f:
            code = f.read()
    else:
        code = args.code
    res = call_blender_mcp("execute_blender_code", {"code": code, "user_prompt": "execute code"})
    for content in res.get("content", []):
        if content.get("type") == "text":
            print(content.get("text"))

def cmd_look(args):
    params = {"mode": args.mode or "viewport", "user_prompt": "look at scene"}
    if args.max_size:
        params["max_size"] = args.max_size
    res = call_blender_mcp("look", params)
    for content in res.get("content", []):
        if content.get("type") == "image":
            import base64
            img_bytes = base64.b64decode(content.get("data", ""))
            out_file = args.output or "blender_view.png"
            with open(out_file, "wb") as f:
                f.write(img_bytes)
            print(f"Saved viewport capture to {out_file}")
        elif content.get("type") == "text":
            print(content.get("text"))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Blender MCP Bridge")
    subparsers = parser.add_subparsers(dest="cmd", required=True)

    p_status = subparsers.add_parser("status")
    p_status.set_defaults(func=cmd_status)

    p_info = subparsers.add_parser("info")
    p_info.add_argument("--fields", help="Comma-separated fields to display")
    p_info.set_defaults(func=cmd_info)

    p_exec = subparsers.add_parser("exec")
    p_exec.add_argument("--code", help="Python code to run in Blender")
    p_exec.add_argument("--file", help="Python file to run in Blender")
    p_exec.set_defaults(func=cmd_exec)

    p_look = subparsers.add_parser("look")
    p_look.add_argument("--output", default="blender_view.png", help="Path to save captured image")
    p_look.add_argument("--mode", default="viewport", help="angles, viewport, camera")
    p_look.add_argument("--max_size", type=int, default=768)
    p_look.set_defaults(func=cmd_look)

    parsed = parser.parse_args()
    parsed.func(parsed)

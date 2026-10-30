import socket
import json
import sys

def send_blender_command(cmd_type: str, params: dict = None, timeout: float = 10.0):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(('127.0.0.1', 9876))
    s.settimeout(timeout)

    payload = {'type': cmd_type}
    if params:
        payload['params'] = params
    
    s.sendall(json.dumps(payload).encode('utf-8'))

    data = b''
    result = None
    while True:
        try:
            chunk = s.recv(8192)
            if not chunk:
                break
            data += chunk
            try:
                result = json.loads(data.decode('utf-8'))
                break
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
        except socket.timeout:
            break
    s.close()
    return result

if __name__ == '__main__':
    print("Testing connection to Blender on 127.0.0.1:9876...")
    info = send_blender_command('get_addon_info')
    print("Addon Info:", json.dumps(info, indent=2))

    code = "import bpy\nprint('=== ACTIVE BLENDER SESSION ===')\nfor obj in bpy.data.objects:\n    print(f' - {obj.name} ({obj.type})')\n"
    res = send_blender_command('execute_code', {'code': code})
    print("Execution Result:", json.dumps(res, indent=2))

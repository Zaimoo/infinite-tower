import sys
sys.path.insert(0, 'tools')
from blender_client import send_blender_command

with open('tools/make_catio_hair.py', 'r', encoding='utf-8') as f:
    code = f.read()

code += "\nresult = create_catio_hair()\nprint('CREATION RESULT:', result)\n"

res = send_blender_command('execute_code', {'code': code}, timeout=30.0)
print("Blender Response:")
print(res.get('result', {}).get('result'))
if res.get('status') == 'error':
    print("Error:", res.get('message'))

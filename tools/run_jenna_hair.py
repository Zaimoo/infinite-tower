import os
import sys

sys.path.insert(0, os.path.abspath("tools"))
from blender_client import send_blender_command


script_path = os.path.abspath("tools/make_jenna_hair.py")
with open(script_path, "r", encoding="utf-8") as f:
    code = f.read()

code += "\nresult = create_jenna_hair()\nprint('CREATION_RESULT:', result)\n"
res = send_blender_command("execute_code", {"code": code}, timeout=30.0)

print("Execute Result:", res)

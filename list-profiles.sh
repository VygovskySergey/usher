#!/bin/bash
# Lists your Google Chrome profiles so you know what to put in ~/.config/usher/config.
python3 - <<'PY'
import json, os, sys
ls = os.path.expanduser("~/Library/Application Support/Google/Chrome/Local State")
try:
    info = json.load(open(ls))["profile"]["info_cache"]
except Exception as e:
    print("Could not read Chrome profiles:", e)
    print("Is Google Chrome installed and has it been launched at least once?")
    sys.exit(1)
print('Chrome profiles — put the DIRECTORY name into ~/.config/usher/config:\n')
print(f'  {"DIRECTORY":<12}  NAME / ACCOUNT')
print(f'  {"-"*12}  {"-"*20}')
for d, m in sorted(info.items()):
    label = " ".join(x for x in [m.get("name", ""), m.get("user_name", "")] if x)
    print(f'  {d:<12}  {label}')
PY

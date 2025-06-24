#!/usr/bin/lua
print("Content-Type: application/json\n")
os.execute("reboot &")
print('{"status":"ok"}')
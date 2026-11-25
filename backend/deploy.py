import paramiko
import sys

host = "76.13.19.62"
user = "root"
password = "cFW9uP?&(HmK?s9'E?I0"

try:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(host, username=user, password=password, timeout=10)
    print("Connected!")
    
    # Let's find the project path first
    stdin, stdout, stderr = client.exec_command("find / -name AyoCuci_API -type d 2>/dev/null")
    paths = stdout.read().decode('utf-8').strip()
    print("Found paths:", paths)
    
    if not paths:
        print("AyoCuci_API directory not found.")
    else:
        # Assume the first path is the project path
        path = paths.split('\n')[0]
        print("Deploying in path:", path)
        cmd = f"cd {path} && git pull origin development && systemctl restart ayocuci-api || pm2 restart all"
        print("Running command:", cmd)
        stdin, stdout, stderr = client.exec_command(cmd)
        print("Output:", stdout.read().decode('utf-8'))
        print("Error:", stderr.read().decode('utf-8'))

    client.close()
except Exception as e:
    print("Error:", e)

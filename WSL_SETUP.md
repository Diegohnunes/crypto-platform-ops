# WSL2 Memory Configuration

Since you are running on a host with limited RAM (8GB Total), it is **CRITICAL** to limit the memory assigned to the WSL2 VM. If you don't do this, the VM might consume all available RAM, causing Windows to freeze.

## Action Required

1.  Open File Explorer in Windows.
2.  Navigate to your user profile directory: `%UserProfile%` (usually `C:\Users\YourName`).
3.  Look for a file named `.wslconfig`. If it doesn't exist, create it.
4.  Open it with a text editor (Notepad) and paste the following content:

```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
localhostForwarding=true
```

5.  Save the file.
6.  Restart WSL2 by opening a PowerShell terminal as Administrator and running:
    ```powershell
    wsl --shutdown
    ```
7.  Wait a few seconds and open your WSL2 terminal again.

> [!IMPORTANT]
> This ensures the VM never takes more than 4GB of RAM, leaving 4GB for Windows.

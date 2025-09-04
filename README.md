````markdown
# NetstatService Installation Guide

This guide explains how to install and configure the **NetstatService** using [NSSM (Non-Sucking Service Manager)](https://nssm.cc/) to monitor network connections for Wazuh.

---

## Prerequisites
- Windows system with PowerShell available
- `nssm.exe` downloaded and placed in your working directory
- `netstat-service.ps1` script located in `C:\Scripts\`

---

## Step 1: Navigate to the Working Directory
```powershell
cd C:\Scripts\
````

---

## Step 2: Install the Service

Run the following command (replace paths with your actual ones):

```powershell
.\nssm.exe install NetstatService powershell.exe "-ExecutionPolicy Bypass -File C:\Scripts\netstat-service.ps1"
```

---

## Step 3: Configure Service Parameters

Set the display name, description, and startup type:

```powershell
.\nssm.exe set NetstatService DisplayName "Network Monitor Service"
.\nssm.exe set NetstatService Description "Monitors network connections for Wazuh"
.\nssm.exe set NetstatService Start SERVICE_AUTO_START
```

---

## Step 4: Start the Service

```powershell
.\nssm.exe start NetstatService
```

---

## Step 5: Verify Service Status

### Using `sc` command:

```cmd
sc query NetstatService
```

### Or in PowerShell:

```powershell
Get-Service NetstatService
```

---

✅ The service should now be installed, configured, and running as **Network Monitor Service**.

---

Would you like me to also add a **diagram (flowchart in ASCII/text)** showing the steps visually for quick reference inside the README?

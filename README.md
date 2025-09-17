````markdown
# NetstatService Installation Guide

This guide explains how to install and configure the **NetstatService** using [NSSM (Non-Sucking Service Manager)](https://nssm.cc/) to monitor network connections for Wazuh.

---

## Prerequisites
- Windows system with PowerShell available
- `nssm.exe` downloaded and placed in your working directory
- `netstat-service.ps1` script located in `C:\netstat\`

---

## Step 1: Navigate to the Working Directory
```powershell
cd C:\netstat\
````

---

## Step 2: Install the Service

Run the following command (replace paths with your actual ones):

```powershell
.\nssm.exe install NetstatService powershell.exe "-ExecutionPolicy Bypass -File C:\netstat\netstat-service.ps1"
.\nssm.exe set NetstatService DisplayName "Network Monitor Service"
.\nssm.exe set NetstatService Description "Monitors network connections for Wazuh"
.\nssm.exe set NetstatService Start SERVICE_AUTO_START
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
## Step 6: Configure Wazuh Agent (`ossec.conf`)

On the Wazuh agent, add the following configuration to monitor the Netstat JSON logs:

```xml
<localfile>
  <location>C:\netstat\logs\netstat*.json</location>
  <log_format>json</log_format>
</localfile>
```
---
## Step 7: add Custom rules Wazuh manager (`netstat.xml`)
```
<group name="windows,netstat,network">

  <!-- Base netstat rule -->
  <rule id="100101" level="3">
    <decoded_as>json</decoded_as>
    <field name="netstat_type">netstat</field>
    <description>Windows netstat: Network connection detected</description>
  </rule>

  <!-- Listening services -->
  <rule id="100102" level="4">
    <if_sid>100101</if_sid>
    <field name="netstat_state_name">Listen</field>
    <description>Windows netstat: Service listening on port $(netstat_lport)</description>
  </rule>

  <!-- External connections -->
  <rule id="100103" level="5">
    <if_sid>100101</if_sid>
    <field name="netstat_is_external">true</field>
    <field name="netstat_state_name">Established</field>
    <description>Windows netstat: External connection to $(netstat_remote_ip):$(netstat_rport)</description>
  </rule>

  <!-- Suspicious ports -->
  <rule id="100104" level="7">
    <if_sid>100101</if_sid>
    <field name="netstat_rport">22|23|3389|5900|4444|1337</field>
    <description>Windows netstat: Connection to suspicious port $(netstat_rport)</description>
  </rule>

</group>
```

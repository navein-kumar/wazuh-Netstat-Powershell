$LogPath = "C:\netstat\logs"
$MaxLogSizeMB = 50
$MaxLogFiles = 5

# Global variables
$global:DNSCache = @{}
$global:ProcessCache = @{}
$global:ExcludePorts = @(1514, 1515)

New-Item -ItemType Directory -Path $LogPath -Force -ErrorAction SilentlyContinue

function Get-ProcessName($processId) {
    if ($global:ProcessCache[$processId]) { return $global:ProcessCache[$processId] }
    
    try { 
        $name = (Get-Process -Id $processId -ErrorAction Stop).ProcessName
        $global:ProcessCache[$processId] = $name
        return $name
    }
    catch { 
        $global:ProcessCache[$processId] = "Unknown"
        return "Unknown" 
    }
}

function Get-DomainName($ip) {
    try {
        if ($ip -match "^(192\.168\.|10\.|172\.|127\.|0\.0\.0\.0|::|::1|fe80:)") { return "LOCAL" }
        
        if ($global:DNSCache[$ip]) { return $global:DNSCache[$ip] }
        
        $task = [System.Net.Dns]::GetHostEntryAsync($ip)
        if ($task.Wait(2000)) {
            $domain = $task.Result.HostName
            $global:DNSCache[$ip] = $domain
            return $domain
        } else {
            $global:DNSCache[$ip] = "TIMEOUT"
            return "TIMEOUT"
        }
    }
    catch {
        $global:DNSCache[$ip] = "UNRESOLVED"
        return "UNRESOLVED"
    }
}

function Get-StateNameFromEnum($state) {
    switch ([string]$state) {
        "Closed" { return "Closed" }
        "Listen" { return "Listen" }
        "SynSent" { return "SynSent" }
        "SynReceived" { return "SynReceived" }
        "Established" { return "Established" }
        "FinWait1" { return "FinWait1" }
        "FinWait2" { return "FinWait2" }
        "CloseWait" { return "CloseWait" }
        "Closing" { return "Closing" }
        "LastAck" { return "LastAck" }
        "TimeWait" { return "TimeWait" }
        "DeleteTcb" { return "DeleteTcb" }
        "1" { return "Closed" }
        "2" { return "Listen" }
        "3" { return "SynSent" }
        "4" { return "SynReceived" }
        "5" { return "Established" }
        "6" { return "FinWait1" }
        "7" { return "FinWait2" }
        "8" { return "CloseWait" }
        "9" { return "Closing" }
        "10" { return "LastAck" }
        "11" { return "TimeWait" }
        "12" { return "DeleteTcb" }
        default { return $state.ToString() }
    }
}

function Write-LogSafe($logEntry, $logFile) {
    try {
        $jsonLine = ($logEntry | ConvertTo-Json -Compress) + "`n"
        
        $fileStream = [System.IO.FileStream]::new(
            $logFile, 
            [System.IO.FileMode]::Append, 
            [System.IO.FileAccess]::Write, 
            [System.IO.FileShare]::ReadWrite
        )
        
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonLine)
        $fileStream.Write($bytes, 0, $bytes.Length)
        $fileStream.Close()
    }
    catch {
        Write-ErrorLog "Failed to write log: $($_.Exception.Message)"
    }
}

function Rotate-Logs {
    try {
        $currentLog = "$LogPath\netstat.json"
        
        if (Test-Path $currentLog) {
            $size = (Get-Item $currentLog).Length / 1MB
            if ($size -gt $MaxLogSizeMB) {
                $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                Rename-Item $currentLog "netstat-$timestamp.json" -ErrorAction Stop
                
                $oldFiles = Get-ChildItem "$LogPath\netstat-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -Skip $MaxLogFiles
                $oldFiles | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        # Rotation failed, continue anyway
    }
}

function Write-ErrorLog($message) {
    try {
        $errorLog = "$LogPath\errors.log"
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $message" | Add-Content $errorLog -ErrorAction SilentlyContinue
    }
    catch {
        # Can't even log errors, continue silently
    }
}

$LogFile = "$LogPath\netstat.json"

while ($true) {
    try {
        Rotate-Logs
        
        $connections = Get-NetTCPConnection -ErrorAction Stop
        
        foreach ($conn in $connections) {
            # Skip excluded ports
            if ($conn.LocalPort -in $global:ExcludePorts -or $conn.RemotePort -in $global:ExcludePorts) {
                continue
            }
            
            try {
                $processId = $conn.OwningProcess
                $stateValue = $conn.State
                $stateName = Get-StateNameFromEnum $stateValue
                
                $isListening = ($stateName -eq "Listen")
                $connectionDirection = if ($isListening) { "listening" } else {
                    if ($conn.RemoteAddress -match "^(0\.0\.0\.0|::)$") { "unknown" } else { "outbound" }
                }
                
                $isExternal = -not ($conn.RemoteAddress -match "^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.|0\.0\.0\.0|::|::1|fe80:)")
                
                # Use completely unique field names to avoid all mapping conflicts
                $logEntry = @{
                    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
                    netstat_type = "netstat"
                    netstat_log_source = "windows_netstat_monitor"
                    netstat_computer = [string]$env:COMPUTERNAME
                    netstat_local_ip = [string]$conn.LocalAddress
                    netstat_lport = [string]$conn.LocalPort
                    netstat_remote_ip = [string]$conn.RemoteAddress
                    netstat_rport = [string]$conn.RemotePort
                    netstat_domain = [string](Get-DomainName $conn.RemoteAddress)
                    netstat_state = [string]$stateValue
                    netstat_state_name = [string]$stateName
                    netstat_protocol = "TCP"
                    netstat_direction = [string]$connectionDirection
                    netstat_is_external = [string]$isExternal
                    netstat_pid = [string]$processId
                    netstat_process = [string](Get-ProcessName $processId)
                    netstat_event = "network_connection"
                }
                
                Write-LogSafe $logEntry $LogFile
            }
            catch {
                Write-ErrorLog "Failed to log connection: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-ErrorLog "Main loop error: $($_.Exception.Message)"
        Start-Sleep 30
        continue
    }
    
    Start-Sleep 60

}

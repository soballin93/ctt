# C:\ProgramData\PCS\RunCTT.ps1
    param(
        [string]$ConfigUrl = 
"https://raw.githubusercontent.com/soballin93/ctt/main/ctt.json"
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $Log = "C:\ProgramData\PCS\RunCTT.log"
    $Marker = "C:\ProgramData\PCS\CTT.done"

    function Write-Log($msg) {
        "[{0}] {1}" -f (Get-Date -f o), $msg | Out-File -FilePath $Log -Append
    }

    try {
        if (Test-Path $Marker) {
            Write-Log "Marker exists. Exiting without action."
            exit 0
        }

        Write-Log "Waiting for network up to 5 minutes..."
        $deadline = (Get-Date).AddMinutes(5)
        $hasNet=$false
        while ((Get-Date) -lt $deadline) {
            try {
                if (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet) { 
$hasNet=$true; break }
            } catch { }
            Start-Sleep -Seconds 3
        }
        if (-not $hasNet) { throw "No network detected; cannot fetch CTT." }

        $CTT_URL  = "https://christitus.com/win"
        $CTT_File = Join-Path $env:TEMP "ctt.ps1"
	$CTT_Config = "C:\programdata\PCS\ctt.json"

        Write-Log "Downloading CTT bootstrap: $CTT_URL"
        Invoke-WebRequest -Uri $CTT_URL -OutFile $CTT_File -UseBasicParsing

        if (-not (Test-Path $CTT_File)) { throw "CTT bootstrap not found after download." }

        Write-Log "Launching CTT with preset: $CTT_Config"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 
"$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$CTT_File`" -Config `"$CTT_Config`" -Run"
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute = $false
        $p = [System.Diagnostics.Process]::Start($psi)
        $out = $p.StandardOutput.ReadToEnd()
        $err = $p.StandardError.ReadToEnd()
        $p.WaitForExit()

        if ($out) { Write-Log "CTT OUT:`r`n$out" }
        if ($err) { Write-Log "CTT ERR:`r`n$err" }
        if ($p.ExitCode -ne 0) { throw "CTT exit code: $($p.ExitCode)" }

        # Mark success and remove the task so it never reruns
        New-Item -ItemType File -Path $Marker -Force | Out-Null
        Write-Log "CTT completed. Deleting scheduled task 'PCS\RunCTT'."
        schtasks /Delete /TN "PCS\RunCTT" /F | Out-Null

        Write-Log "Done."
        exit 0
    }
    catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        exit 1
    }
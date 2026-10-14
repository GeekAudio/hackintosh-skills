<#
  bios-audit.ps1  --  Read-only BIOS/UEFI audit helper (Windows side)

  Purpose : Collect everything Windows CAN tell you about your firmware settings,
            so you only have to walk into the BIOS for what Windows cannot read.

  Safety  : READ-ONLY. It never writes to disk, NVRAM, firmware or any device.
            Output is plain ASCII on purpose (avoids PowerShell 5.1 encoding issues).

  Usage   : powershell -ExecutionPolicy Bypass -File .\bios-audit.ps1
            powershell -ExecutionPolicy Bypass -File .\bios-audit.ps1 -OutFile C:\bios-audit.txt

  Run as Administrator for the complete result (Secure Boot / TPM checks need it).

  Companion document: references/bios-settings.md
#>

[CmdletBinding()]
param(
    [string]$OutFile = ""
)

$ErrorActionPreference = 'Continue'
$script:Report = New-Object System.Collections.Generic.List[string]

function W    { param([string]$s) $script:Report.Add($s); Write-Host $s }
function H    { param([string]$s) W ""; W ("=" * 74); W ("  " + $s); W ("=" * 74) }
function OK   { param([string]$s) W ("  [ OK   ] " + $s) }
function WARN { param([string]$s) W ("  [ WARN ] " + $s) }
function BAD  { param([string]$s) W ("  [ FAIL ] " + $s) }
function INFO { param([string]$s) W ("  [ info ] " + $s) }
function MAN  { param([string]$s) W ("  [  ?   ] " + $s) }
function SEP  { W ("  " + ("-" * 68)) }

# NOTE: & $Block runs in a CHILD scope, so any variable that must survive
# outside the block has to be written as $script:Name.
function Try-It {
    param([scriptblock]$Block)
    try { & $Block }
    catch { W ("  [ skip ] " + $_.Exception.Message) }
}

$IsAdmin = $false
try {
    $IsAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }

W "bios-audit.ps1   --   BIOS/UEFI audit (read-only)"
W ("Time        : " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
W ("Computer    : " + $env:COMPUTERNAME)
W ("Admin       : " + $IsAdmin)
if (-not $IsAdmin) {
    W ""
    W "  NOTE: Not running as Administrator. Secure Boot / TPM checks will be skipped."
    W "        Re-run from an elevated PowerShell for a complete result."
}

# ---------------------------------------------------------------- 1. firmware
H "1. FIRMWARE / BOOT MODE"

$script:FwType = ""
Try-It { $script:FwType = $env:firmware_type }
if ($script:FwType) {
    if ($script:FwType -eq 'UEFI') { OK ("firmware_type = UEFI") }
    else { BAD ("firmware_type = " + $script:FwType + "  -> must be UEFI for macOS") }
} else { MAN "firmware_type not exposed on this build; falling back to bcdedit" }

Try-It {
    $bcd = (& bcdedit /enum '{current}' 2>$null) -join "`n"
    if ($bcd -match 'winload\.efi') { OK "boot loader = winload.efi  (UEFI boot)" }
    elseif ($bcd -match 'winload\.exe') { BAD "boot loader = winload.exe  (LEGACY boot) -> macOS needs UEFI" }
    else { MAN "could not parse bcdedit output" }
}

Try-It {
    $disks = Get-Disk -ErrorAction Stop
    $sys = $disks | Where-Object { $_.IsSystem -eq $true }
    foreach ($d in $disks) {
        $tag = ""
        if ($d.IsSystem) { $tag = "  <== SYSTEM" }
        INFO ("disk " + $d.Number + "  " + $d.PartitionStyle + "  " + [math]::Round($d.Size/1GB,1) + " GB  " + $d.FriendlyName + $tag)
    }
    if ($sys -and $sys.PartitionStyle -eq 'GPT') { OK "system disk is GPT (consistent with UEFI)" }
    elseif ($sys) { WARN "system disk is " + $sys.PartitionStyle + " - expected GPT for UEFI" }
}

SEP
INFO "Secure Boot (BIOS setting - we want it OFF)"
if ($IsAdmin) {
    Try-It {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        if ($sb) { BAD "Secure Boot is ENABLED -> disable it in BIOS" }
        else     { OK  "Secure Boot is DISABLED" }
    }
} else { MAN "needs Administrator" }

SEP
INFO "TPM / Intel PTT / AMD fTPM (BIOS setting - we want it OFF)"
if ($IsAdmin) {
    Try-It {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm.TpmPresent) { WARN "TPM present (TpmPresent=True) -> consider disabling PTT/fTPM in BIOS" }
        else                 { OK   "no TPM present" }
    }
} else { MAN "needs Administrator" }

# -------------------------------------------------------------------- 2. CPU
H "2. CPU / VIRTUALISATION"

Try-It {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    INFO ("CPU            : " + $cpu.Name)
    INFO ("Cores          : " + $cpu.NumberOfCores)
    INFO ("Logical CPUs   : " + $cpu.NumberOfLogicalProcessors)
    if ($cpu.NumberOfCores -gt 0 -and
        $cpu.NumberOfLogicalProcessors -eq (2 * $cpu.NumberOfCores)) {
        OK "Hyper-Threading appears ENABLED (logical = 2 x cores)"
    } elseif ($cpu.NumberOfLogicalProcessors -eq $cpu.NumberOfCores) {
        WARN "Hyper-Threading appears DISABLED (logical = cores) -> enable it in BIOS"
    } else {
        MAN ("HT state unclear (" + $cpu.NumberOfCores + " cores / " + $cpu.NumberOfLogicalProcessors + " logical)")
    }

    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    INFO ("HypervisorPresent : " + $cs.HypervisorPresent)

    $vf = $cpu.VirtualizationFirmwareEnabled
    if ($vf -eq $true) {
        OK "VirtualizationFirmwareEnabled = True  (VT-x / SVM enabled in firmware)"
    } elseif ($cs.HypervisorPresent -eq $true) {
        WARN "VirtualizationFirmwareEnabled = False BUT a hypervisor is running"
        W "         -> this reading is unreliable while Hyper-V is active."
        W "         -> verify VT-x / SVM directly in BIOS."
    } else {
        BAD "VirtualizationFirmwareEnabled = False -> enable VT-x (Intel) / SVM (AMD) in BIOS"
    }

    if ($cpu.DataExecutionPrevention_Available -eq $true) {
        OK "DEP available (implies Execute Disable Bit / XD / NX is enabled)"
    } else {
        WARN "DEP not available -> check 'Execute Disable Bit' in BIOS"
    }
}

# ----------------------------------------------------------------- 3. memory
H "3. MEMORY (XMP/DOCP + slot layout)"

Try-It {
    $mem = Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop
    if (-not $mem) { MAN "no Win32_PhysicalMemory data"; return }
    $i = 0
    foreach ($m in $mem) {
        $i++
        $gb  = [math]::Round($m.Capacity / 1GB, 0)
        $spd = $m.Speed
        $cfg = $m.ConfiguredClockSpeed
        $line = "stick $i : " + $gb + " GB  slot=" + $m.DeviceLocator + "  bank=" + $m.BankLabel
        INFO $line
        INFO ("           rated=" + $spd + " MT/s   running=" + $cfg + " MT/s   " + $m.Manufacturer + " " + $m.PartNumber)
    }
    $anyXmp = $false
    foreach ($m in $mem) {
        if ($m.ConfiguredClockSpeed -and $m.Speed -and $m.ConfiguredClockSpeed -gt 0) {
            if ($m.Speed -gt 2400 -or $m.ConfiguredClockSpeed -gt 2666) { $anyXmp = $true }
        }
    }
    SEP
    if ($anyXmp) {
        WARN "Memory is running above default JEDEC speed -> XMP/DOCP/EXPO is likely ENABLED"
        W "         XMP is OPTIONAL for macOS. If you hit memory-related instability"
        W "         or sleep/wake problems, try disabling it in BIOS."
    } else {
        INFO "Memory appears to be running at default speed (XMP probably off)"
    }
    W ""
    INFO "Slot names above are also useful for memory injection"
    INFO "  -> see references/memory-injection.md"
}

# ------------------------------------------------------- 4. storage / VMD RST
H "4. STORAGE  (*** the VMD / Intel RST check ***)"

Try-It {
    $disks = Get-Disk -ErrorAction Stop
    $raid  = $false
    foreach ($d in $disks) {
        $line = "disk " + $d.Number + " : " + $d.BusType + "  " + [math]::Round($d.Size/1GB,1) + " GB  " + $d.FriendlyName
        INFO $line
        if ($d.BusType -eq 'RAID') { $raid = $true }
    }
    SEP
    if ($raid) {
        BAD "A disk reports BusType = RAID."
        W "         -> On Intel platforms this strongly suggests VMD (Volume Management"
        W "            Device) or Intel RST is ENABLED. macOS has no VMD driver, so you"
        W "            will NOT see the drive in the installer. DISABLE VMD in BIOS"
        W "            and set SATA Mode to AHCI."
    } else {
        OK "No disk reports BusType = RAID (good sign, but keep reading below)"
    }
}

SEP
INFO "Storage controllers detected:"
$script:CtrlHit = $false
Try-It {
    $ctrls = Get-PnpDevice -ErrorAction Stop |
             Where-Object { $_.Class -in @('SCSIAdapter','HDC','System') -and $_.Status -eq 'OK' }
    if (-not $ctrls) { MAN "no storage controller devices enumerated"; return }
    foreach ($c in $ctrls) {
        $name = $c.FriendlyName
        INFO ("  " + $name)
        if ($name -match 'VMD|Volume Management|RST|RAID|Optane') {
            $script:CtrlHit = $true
            BAD ("    ^^^ matches VMD / RST / RAID -> DISABLE VMD in BIOS")
        }
        try {
            $hw = (Get-PnpDeviceProperty -InstanceId $c.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data
            if ($hw) { INFO ("      hwids: " + ($hw -join ', ')) }
        } catch { }
    }
    SEP
    if (-not $script:CtrlHit) {
        INFO "No controller name matched VMD/RST/RAID."
        W "         Still verify in BIOS: search for 'VMD' / 'Volume Management Device'."
        W "         VMD can be enabled with the controller hidden behind a different name."
    }
}
if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
    MAN "Get-PnpDevice not available on this build - check Device Manager manually:"
    W "         Storage controllers -> look for 'Intel(R) Volume Management Device'"
}

# ------------------------------------------------------------ 5. GPU / ReBAR
H "5. GPU  (Above 4G / Re-Size BAR hints)"

Try-It {
    $gpus = Get-CimInstance Win32_VideoController -ErrorAction Stop
    foreach ($g in $gpus) {
        INFO ("GPU  : " + $g.Name)
        INFO ("  drv: " + $g.DriverVersion)
    }
}

Try-It {
    $disp = Get-PnpDevice -Class Display -Status OK -ErrorAction Stop
    foreach ($d in $disp) {
        INFO ("  " + $d.FriendlyName)
        try {
            $hw = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data
            if ($hw) { INFO ("      hwids: " + ($hw -join ', ')) }
        } catch { }
    }
}

SEP
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    Try-It {
        $q = (& nvidia-smi -q 2>$null) -join "`n"
        if ($q -match 'Resizable BAR\s*:\s*(\w+)') {
            INFO ("nvidia-smi reports Resizable BAR = " + $Matches[1])
        } else {
            MAN "nvidia-smi present but no 'Resizable BAR' line"
        }
    }
} else {
    MAN "nvidia-smi not found"
}
W ""
INFO "Above 4G Decoding / Re-Size BAR cannot be read reliably from Windows."
W "         Use GPU-Z (shows 'Resizable BAR' and 'Above 4G Decoding') or"
W "         NVIDIA Control Panel -> System Information."

# ----------------------------------------------------------- 6. serial ports
H "6. SERIAL / COM PORTS  (BIOS setting - we want them OFF)"

Try-It {
    $coms = Get-CimInstance Win32_SerialPort -ErrorAction Stop
    if ($coms) {
        WARN ("Found " + @($coms).Count + " serial port(s) -> consider disabling Serial/COM Port in BIOS")
        foreach ($p in $coms) { INFO ("  " + $p.DeviceID + "  " + $p.Description) }
    } else {
        OK "No serial ports enumerated (consistent with Serial/COM disabled)"
    }
}

# ------------------------------------------------- 7. BIOS / board inventory
H "7. BIOS / BOARD INVENTORY  (compare against the vendor website)"

Try-It {
    $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
    INFO ("BIOS vendor  : " + $bios.Manufacturer)
    INFO ("BIOS version : " + $bios.SMBIOSBIOSVersion)
    INFO ("BIOS date    : " + $bios.ReleaseDate)
    INFO ("SMBIOS       : " + $bios.SMBIOSMajorVersion + "." + $bios.SMBIOSMinorVersion)
}
Try-It {
    $bb = Get-CimInstance Win32_BaseBoard -ErrorAction Stop
    INFO ("Board        : " + $bb.Manufacturer + " " + $bb.Product)
    INFO ("Board ver    : " + $bb.Version)
}
Try-It {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    INFO ("Model        : " + $cs.Manufacturer + " " + $cs.Model)
    INFO ("RAM total    : " + [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) + " GB")
}

# ------------------------------------------------------------- 8. can't read
H "8. CANNOT BE READ FROM WINDOWS  -> check in BIOS or with a special tool"

W "  These MUST be verified manually. Windows gives no reliable reading:"
W ""
W "  [ ] CFG Lock (MSR 0xE2 write protection)   -> must be DISABLED"
W "      Windows cannot read MSRs from user mode. Use one of:"
W "        - OpenCore's bundled ControlMsrE2.efi  (most accurate; runs at the picker)"
W "        - RWEverything on Windows"
W "        - macOS: sudo wrmsr 0xE2 0x0   (fails with 'cannot set MSR' when locked)"
W ""
W "  [ ] CSM (Compatibility Support Module)     -> must be DISABLED"
W "  [ ] Fast Boot / Ultra Fast Boot            -> must be DISABLED"
W "  [ ] VMD / Volume Management Device         -> must be DISABLED  (see section 4)"
W "  [ ] SATA Mode = AHCI                       -> must be AHCI"
W "  [ ] Intel Speed Shift Technology           -> must be ENABLED"
W "  [ ] EHCI/XHCI Hand-off                     -> ENABLED"
W "  [ ] OS Type = Windows 8.1/10 UEFI Mode     -> (or 'Other OS')"
W "  [ ] DVMT Pre-Allocated >= 64MB             -> only if you keep the iGPU enabled"
W "  [ ] ACPI tables (DSDT / DMAR / FADT ...)   -> RWEverything / acpidump,"
W "      or OpenCore DEBUG build + Misc > Debug > SysReport"
W ""
W "  Full list, vendor-by-vendor menu names and the OpenCore fallbacks:"
W "      references/bios-settings.md"

# ------------------------------------------------------------------- footer
H "DONE"
W "  Reminder: BIOS settings are only half of it. The matching OpenCore side is:"
W "    - DisableIoMapper      <-> VT-d / IOMMU"
W "    - AppleXcpmCfgLock     <-> CFG Lock (avoid if you can disable it in BIOS)"
W "    - ResizeAppleGpuBars   <-> Re-Size BAR"
W "    - -wegnoigpu           <-> Internal Graphics with no driver"
W ""

if ($OutFile -ne "") {
    try {
        $script:Report -join "`r`n" | Out-File -FilePath $OutFile -Encoding ASCII
        Write-Host ("Report written to: " + $OutFile)
    } catch {
        Write-Host ("Could not write report: " + $_.Exception.Message)
    }
}

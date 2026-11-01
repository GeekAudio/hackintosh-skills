<#
  bios-audit.ps1  --  Read-only BIOS/UEFI audit helper (Windows side)

  Purpose : Collect everything Windows CAN tell you about your firmware settings,
            so you only have to walk into the BIOS for what Windows cannot read.

  Safety  : Read-only collection: no NVRAM, firmware or device changes.
            -OutFile writes only the requested report file.
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
    else { WARN ("firmware_type = " + $script:FwType + "  -> review the planned OpenCore boot method before changing Windows boot mode") }
} else { MAN "firmware_type not exposed on this build; falling back to bcdedit" }

Try-It {
    $bcd = (& bcdedit /enum '{current}' 2>$null) -join "`n"
    if ($bcd -match 'winload\.efi') { OK "boot loader = winload.efi  (UEFI boot)" }
    elseif ($bcd -match 'winload\.exe') { WARN "boot loader = winload.exe  (LEGACY boot); a UEFI migration needs a Windows recovery plan" }
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
INFO "UEFI Secure Boot (record the current Windows firmware state)"
if ($IsAdmin) {
    Try-It {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        if ($sb) { INFO "UEFI Secure Boot is ENABLED" }
        else     { INFO "UEFI Secure Boot is DISABLED" }
        W "         Check whether the planned OpenCore boot chain is trusted by this firmware."
        W "         Do not disable Secure Boot or clear keys just because it is enabled."
        W "         This is separate from OpenCore's Apple SecureBootModel setting."
    }
} else { MAN "needs Administrator" }

SEP
INFO "TPM / Intel PTT / AMD fTPM (presence is not a macOS failure)"
if ($IsAdmin) {
    Try-It {
        $tpm = Get-Tpm -ErrorAction Stop
        INFO ("TpmPresent=" + $tpm.TpmPresent + "  TpmReady=" + $tpm.TpmReady)
        W "         Windows security and BitLocker may depend on the current TPM state."
        W "         Do not disable or clear TPM based on this detection alone."
        W "         Before any required firmware/security change, retain recovery keys and a rollback plan."
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
        INFO "Logical CPUs = 2 x cores (consistent with SMT; verify the actual CPU topology)"
    } elseif ($cpu.NumberOfLogicalProcessors -eq $cpu.NumberOfCores) {
        INFO "Logical CPUs = cores; this alone does not prove SMT is disabled or supported"
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
        INFO "VirtualizationFirmwareEnabled = False; confirm VT-x / SVM in BIOS if the target workload needs it"
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
        WARN "A disk reports BusType = RAID (a Windows storage presentation clue)."
        W "         This alone does not identify VMD/RST, the firmware controller mode,"
        W "         or whether the target macOS disk is behind that controller."
        W "         Correlate controller hardware IDs, the target disk path and installer visibility."
    } else {
        INFO "No disk reports BusType = RAID; this does not prove VMD/RST is disabled"
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
            WARN ("    ^^^ name matches VMD / RST / RAID; verify the device and target disk path")
            W "         A matching device name does not establish the current controller mode."
        }
        try {
            $hw = (Get-PnpDeviceProperty -InstanceId $c.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data
            if ($hw) { INFO ("      hwids: " + ($hw -join ', ')) }
        } catch { }
    }
    SEP
    if (-not $script:CtrlHit) {
        INFO "No controller name matched VMD/RST/RAID."
        W "         Names alone cannot establish whether VMD/RST is enabled or disabled."
        W "         Check hardware IDs, firmware settings and the target disk path if needed."
    }
}
if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
    MAN "Get-PnpDevice not available on this build - check Device Manager manually:"
    W "         Storage controllers -> look for 'Intel(R) Volume Management Device'"
}
W ""
INFO "Do not switch VMD/RST/RAID or SATA mode solely from these observations."
W "         If the target disk needs direct NVMe/AHCI access, first confirm the mapping."
W "         Back up data and BitLocker recovery keys, and prepare the Windows storage"
W "         driver/migration and firmware rollback plan before an authorized change."

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
H "6. SERIAL / COM PORTS  (inventory; preserve ports needed by Windows)"

Try-It {
    $coms = Get-CimInstance Win32_SerialPort -ErrorAction Stop
    if ($coms) {
        INFO ("Found " + @($coms).Count + " serial port(s); presence alone does not require disabling them")
        foreach ($p in $coms) { INFO ("  " + $p.DeviceID + "  " + $p.Description) }
    } else {
        INFO "No serial ports enumerated; this does not establish the BIOS port setting"
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

W "  Review these only as needed for the target hardware, boot path and symptoms."
W "  Preserve working Windows settings; this report does not prescribe BIOS changes:"
W ""
W "  [ ] Intel CFG Lock (MSR 0xE2)             -> verify only if the CPU/EFI path needs it"
W "      WMI does not provide this MSR state. For a deliberate status check, use"
W "      ControlMsrE2.efi without arguments (verify only), not lock/unlock/interactive."
W ""
W "  [ ] CSM / UEFI boot path                  -> match the firmware, GPU GOP and Windows boot method"
W "  [ ] Fast Boot / Ultra Fast Boot           -> review for USB discovery or firmware-entry problems"
W "  [ ] VMD / RST / target disk mapping       -> confirm before considering a mode change (section 4)"
W "  [ ] SATA mode                            -> AHCI only where the target storage path requires it"
W "  [ ] Intel Speed Shift                    -> depends on the Intel CPU and macOS power-management path"
W "  [ ] EHCI/XHCI Hand-off                    -> review when USB hand-off symptoms require it"
W "  [ ] OS Type                              -> vendor-specific; review its actual Secure Boot effect"
W "  [ ] iGPU / DVMT pre-allocation            -> match the actual GPU, driver and display route"
W "  [ ] ACPI tables (DSDT / DMAR / FADT ...)   -> RWEverything / acpidump,"
W "      or OpenCore DEBUG build + Misc > Debug > SysReport"
W ""
W "  Full list, vendor-by-vendor menu names and the OpenCore fallbacks:"
W "      references/bios-settings.md"

# ------------------------------------------------------------------- footer
H "DONE"
W "  Reminder: BIOS settings are only half of it. The matching OpenCore side is:"
W "    - DisableIoMapper: macOS IOMapper workaround; not an instruction to disable Windows VT-d/IOMMU"
W "    - CFG Lock quirks: select for the actual CPU and kernel path; do not force a firmware unlock"
W "    - ResizeAppleGpuBars: macOS BAR handling; distinct from firmware Re-Size BAR and UEFI ResizeGpuBars"
W "    - iGPU handling: retain the selected driver/display route; do not automatically add -wegnoigpu"
W ""

if ($OutFile -ne "") {
    try {
        $script:Report -join "`r`n" | Out-File -FilePath $OutFile -Encoding ASCII
        Write-Host ("Report written to: " + $OutFile)
    } catch {
        Write-Host ("Could not write report: " + $_.Exception.Message)
    }
}

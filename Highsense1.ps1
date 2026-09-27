# ==============================================================================
# HIGHSENSE ENGINE - EXE READY
# ==============================================================================

Clear-Host
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$asciiLogo = @"

  ██╗  ██╗██╗ ██████╗ ██╗  ██╗███████╗███████╗███╗   ██╗███████╗███████╗
  ██║  ██║██║██╔════╝ ██║  ██║██╔════╝██╔════╝████╗  ██║██╔════╝██╔════╝
  ███████║██║██║  ███╗███████║███████╗█████╗  ██╔██╗ ██║███████╗█████╗  
  ██╔══██║██║██║   ██║██╔══██║╚════██║██╔══╝  ██║╚██╗██║╚════██║██╔══╝  
  ██║  ██║██║╚██████╔╝██║  ██║███████║███████╗██║ ╚████║███████║███████╗
  ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═══╝╚══════╝╚══════╝
"@

Write-Host $asciiLogo -ForegroundColor White
Write-Host "  ══════════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "        H I G H S E N S E   E N G I N E   //   Free Performance Suite" -ForegroundColor Cyan
Write-Host "  ══════════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

# ==============================================================================
# Check Administrator rights - if not Admin, editing Registry (HKLM) fails everywhere
# silently without the user knowing why, so we check first and warn / disable buttons
# ==============================================================================
$script:isAdmin = $false
try {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $script:isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {}

if (-not $script:isAdmin) {
    Write-Host " [WARNING] Not running as Administrator." -ForegroundColor Yellow
    Write-Host " [WARNING] Optimization modules need Admin rights to write to HKLM." -ForegroundColor Yellow
    Write-Host " [WARNING] Right-click Highsense.exe -> Run as administrator." -ForegroundColor Yellow
    Write-Host ""
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic

    # Win32 helper so we can keep the ASCII-logo console visible on launch,
    # then quietly hide it a few seconds later while the GUI stays open.
    try {
        if (-not ('Highsense.NativeConsole' -as [type])) {
            Add-Type -Namespace Highsense -Name NativeConsole -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern System.IntPtr GetConsoleWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
        }
    } catch {}

    # DWM helper: enables true OS-level (perfectly anti-aliased) rounded window
    # corners + a subtle border on Windows 11, instead of jagged Region clipping.
    try {
        if (-not ('Highsense.Dwm' -as [type])) {
            Add-Type -Namespace Highsense -Name Dwm -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int attrValue, int attrSize);
'@
        }
    } catch {}

    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

    # Color Palette (Dark Theme Modern)
    $bgColor           = [System.Drawing.Color]::FromArgb(18, 18, 18)
    $panelColor        = [System.Drawing.Color]::FromArgb(26, 26, 26)
    $tabBgColor        = [System.Drawing.Color]::FromArgb(35, 35, 35)
    $tabActiveBg       = [System.Drawing.Color]::FromArgb(44, 44, 48)
    # Bright clean white glow for the active category tab (text + indicator)
    $script:tabAccent  = [System.Drawing.Color]::FromArgb(248, 250, 253)
    $textPrimary       = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $textMuted         = [System.Drawing.Color]::FromArgb(150, 150, 150)
    $btnColor          = [System.Drawing.Color]::FromArgb(32, 32, 32)
    $btnHoverColor     = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnActiveColor    = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $btnText           = [System.Drawing.Color]::FromArgb(235, 235, 235)
    $progressBgColor   = [System.Drawing.Color]::FromArgb(40, 40, 40)
    # Monochrome accent (black/grey theme) used across progress, indicator, border
    $script:accentColor  = [System.Drawing.Color]::FromArgb(210, 210, 210)
    $script:accentColor2 = [System.Drawing.Color]::FromArgb(150, 150, 150)
    $progressFillCol   = $script:accentColor
    # Per-module status indicator colors
    $script:statusDone    = [System.Drawing.Color]::FromArgb(74, 201, 126)
    $script:statusPending = [System.Drawing.Color]::FromArgb(95, 95, 100)

    # ===========================================================================
    # HIGHSENSE PUBLIC RELEASE PROFILE
    # Default: aggressive/undocumented tweaks are OFF unless explicitly
    # enabled by the distributor/user after understanding their trade-offs.
    # ===========================================================================
    $script:enableHags              = $true
    $script:disablePowerThrottling = $false
    $script:disableBackgroundApps  = $false
    $script:forceGameDvrPolicy    = $false
    $script:advancedNetTweaks      = $false
    $script:optimizeNicPower       = $true
    $script:advancedInputQueues    = $false
    $script:disableHibernation     = $false
    $script:gamesTaskPriority      = $true
    $script:disableMpo             = $false
    $script:disableMemoryIntegrity = $false
    $script:disableTelemetry       = $false
    $script:ntfsTweaks             = $false

    $cachedCpu = "Unknown CPU"
    try {
        $cachedCpu = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).Name.Trim()
    } catch {}

    $cachedGpu = "Unknown GPU"
    try {
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction Stop |
            Where-Object { $_.Name -and $_.Name -notmatch "Microsoft Basic Display Adapter" } |
            Select-Object -First 1
        if ($gpu -and $gpu.Name) { $cachedGpu = $gpu.Name.Trim() }
    } catch {}

    $cachedOs = "Windows"
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1
        if ($osInfo) {
            $cachedOs = "$($osInfo.Caption) | Build $($osInfo.BuildNumber)"
        }
    } catch {}

    function Limit-SpecText {
        param([string]$Value, [int]$Max = 52)
        if ([string]::IsNullOrWhiteSpace($Value)) { return "Unknown" }
        $v = $Value.Trim()
        if ($v.Length -le $Max) { return $v }
        return $v.Substring(0, $Max - 1) + "…"
    }

    function Format-SpecLine {
        param([string]$Label, [string]$Value)
        $safe = Limit-SpecText $Value 58
        return ("{0,-5} : {1}" -f $Label, $safe)
    }

    $computerInfo = New-Object Microsoft.VisualBasic.Devices.ComputerInfo

    function Get-SystemSpecsFast {
        try {
            $totalRam = [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 1)
            $freeRam  = [math]::Round($computerInfo.AvailablePhysicalMemory / 1GB, 1)
            $usedRam  = [math]::Round($totalRam - $freeRam, 1)
            $ramPct   = if ($totalRam -gt 0) { [math]::Round(($usedRam / $totalRam) * 100) } else { 0 }
        } catch {
            $totalRam = 16.0
            $usedRam  = 0
            $ramPct   = 0
        }

        try {
            $driveC  = [System.IO.DriveInfo]::GetDrives() | Where-Object {$_.Name -eq "C:\" }
            $freeSSD = if ($driveC) { [math]::Round($driveC.AvailableFreeSpace / 1GB, 1) } else { 0 }
        } catch {
            $freeSSD = 0
        }

        return [PSCustomObject]@{
            CPU       = $cachedCpu
            GPU       = $cachedGpu
            OS        = $cachedOs
            TotalRAM  = $totalRam
            UsedRAM   = $usedRam
            FreeRAM   = [math]::Round($freeRam, 1)
            RamPct    = $ramPct
            FreeSSD   = $freeSSD
        }
    }

    $currentSpecs = Get-SystemSpecsFast

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "HIGHSENSE Engine"
    $form.Size = New-Object System.Drawing.Size(550, 640)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.BackColor = $bgColor
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.MaximizeBox = $false

    # Window corners are rounded by the OS (DWM) below - see $form.Add_Shown -
    # which yields perfectly smooth, anti-aliased edges (no hand-drawn border needed).

    function Set-RoundedControl {
        param($ctrl, $radius)
        if ($null -eq $ctrl -or $ctrl.Width -le 0 -or $ctrl.Height -le 0) { return }
        try {
            $rect = New-Object System.Drawing.Rectangle(0, 0, $ctrl.Width, $ctrl.Height)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddArc($rect.X, $rect.Y, $radius, $radius, 180, 90)
            $path.AddArc($rect.Right - $radius, $rect.Y, $radius, $radius, 270, 90)
            $path.AddArc($rect.Right - $radius, $rect.Bottom - $radius, $radius, $radius, 0, 90)
            $path.AddArc($rect.X, $rect.Bottom - $radius, $radius, $radius, 90, 90)
            $path.CloseFigure()
            $ctrl.Region = New-Object System.Drawing.Region($path)
            $path.Dispose()
        } catch {}
    }

    # --- Double-buffering helper (defined early so the glass painters below use it) ---
    $script:dbProp = [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    function Set-DoubleBuffered($ctrl) {
        try { if ($script:dbProp) { $script:dbProp.SetValue($ctrl, $true, $null) } } catch {}
    }

    # Build an anti-aliased rounded-rectangle GraphicsPath ($arc = corner diameter).
    function New-RoundedPath {
        param([int]$w, [int]$h, [int]$arc)
        if ($arc -gt $w) { $arc = $w }
        if ($arc -gt $h) { $arc = $h }
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        if ($arc -le 1) {
            $path.AddRectangle((New-Object System.Drawing.Rectangle(0, 0, $w, $h)))
            return $path
        }
        $path.AddArc(0, 0, $arc, $arc, 180, 90)
        $path.AddArc(($w - $arc), 0, $arc, $arc, 270, 90)
        $path.AddArc(($w - $arc), ($h - $arc), $arc, $arc, 0, 90)
        $path.AddArc(0, ($h - $arc), $arc, $arc, 90, 90)
        $path.CloseFigure()
        return $path
    }

    # Frosted-glass background for a Panel: NO Region clipping (which jags the corners);
    # instead we paint the parent color into the corners and fill an anti-aliased rounded
    # rect on top, add a soft top sheen + a hairline light border => clean modern glass.
    function Set-GlassPanel {
        param($panel, [int]$arc = 14, $fill, [int]$sheen = 12, [int]$borderAlpha = 46)
        if ($null -eq $fill) { $fill = $panel.BackColor }
        Add-Member -InputObject $panel -MemberType NoteProperty -Name GArc -Value $arc -Force
        Add-Member -InputObject $panel -MemberType NoteProperty -Name GFill -Value $fill -Force
        Add-Member -InputObject $panel -MemberType NoteProperty -Name GSheen -Value $sheen -Force
        Add-Member -InputObject $panel -MemberType NoteProperty -Name GBorder -Value $borderAlpha -Force
        Set-DoubleBuffered $panel
        $panel.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $w = $s.Width; $h = $s.Height
            $arc = [int]$s.GArc
            $pc = if ($null -ne $s.Parent) { $s.Parent.BackColor } else { $s.BackColor }
            $g.Clear($pc)
            $fill = $s.GFill
            $sh = [int]$s.GSheen
            $path = New-RoundedPath ($w - 1) ($h - 1) $arc
            $topCol = [System.Drawing.Color]::FromArgb(255, [math]::Min(255, $fill.R + $sh), [math]::Min(255, $fill.G + $sh), [math]::Min(255, $fill.B + $sh))
            $rectF = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
            $fb = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF, $topCol, $fill, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
            $g.FillPath($fb, $path)
            $fb.Dispose()
            # frosted top sheen (a faint white highlight fading down over the top half)
            $shH = [math]::Max(2, [int]($h * 0.5))
            $shRect = New-Object System.Drawing.Rectangle(0, 0, $w, $shH)
            $shB = New-Object System.Drawing.Drawing2D.LinearGradientBrush($shRect, [System.Drawing.Color]::FromArgb(24, 255, 255, 255), [System.Drawing.Color]::FromArgb(0, 255, 255, 255), [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
            $g.SetClip($path)
            $g.FillRectangle($shB, $shRect)
            $g.ResetClip()
            $shB.Dispose()
            # hairline glass border
            $ba = [int]$s.GBorder
            if ($ba -gt 0) {
                $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($ba, 255, 255, 255), [single]1)
                $g.DrawPath($pen, $path)
                $pen.Dispose()
            }
            $path.Dispose()
        })
        $panel.Invalidate()
    }

    # Anti-aliased rounded button (reads its own BackColor as the fill), with a soft
    # top sheen, a hairline glass border and crisp centered text - no Region, no jaggies.
    function Set-GlassButton {
        param($btn, [int]$arc = 10)
        Add-Member -InputObject $btn -MemberType NoteProperty -Name GArc -Value $arc -Force
        Set-DoubleBuffered $btn
        $btn.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $w = $s.Width; $h = $s.Height
            $arc = [int]$s.GArc
            $pc = if ($null -ne $s.Parent) { $s.Parent.BackColor } else { $s.BackColor }
            $g.Clear($pc)
            $fill = $s.BackColor
            $path = New-RoundedPath ($w - 1) ($h - 1) $arc
            $topCol = [System.Drawing.Color]::FromArgb(255, [math]::Min(255, $fill.R + 14), [math]::Min(255, $fill.G + 14), [math]::Min(255, $fill.B + 16))
            $rectF = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
            $fb = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF, $topCol, $fill, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
            $g.FillPath($fb, $path)
            $fb.Dispose()
            $shRect = New-Object System.Drawing.Rectangle(0, 0, $w, [math]::Max(2, [int]($h / 2)))
            $shB = New-Object System.Drawing.Drawing2D.LinearGradientBrush($shRect, [System.Drawing.Color]::FromArgb(22, 255, 255, 255), [System.Drawing.Color]::FromArgb(0, 255, 255, 255), [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
            $g.SetClip($path)
            $g.FillRectangle($shB, $shRect)
            $g.ResetClip()
            $shB.Dispose()
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(48, 255, 255, 255), [single]1)
            $g.DrawPath($pen, $path)
            $pen.Dispose()
            $path.Dispose()
            $tf = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine
            [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $s.Text, $s.Font, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)), $s.ForeColor, $tf)
        })
        $btn.Invalidate()
    }

    # Wrap a control (e.g. a TextBox, which can't be owner-drawn) inside an
    # anti-aliased frosted-glass card so it reads as a rounded glass panel with
    # smooth corners. The inner control is inset so its square corners hide behind
    # the card's rounded edge.
    function Wrap-GlassCard {
        param($ctrl, [int]$arc = 14, [int]$pad = 6, $fill)
        if ($null -eq $fill) { $fill = [System.Drawing.Color]::FromArgb(30, 30, 34) }
        $parent = $ctrl.Parent
        if ($null -eq $parent) { return $null }
        $loc = $ctrl.Location; $sz = $ctrl.Size
        $card = New-Object System.Windows.Forms.Panel
        $card.Location = $loc
        $card.Size = $sz
        $card.BackColor = $parent.BackColor
        $parent.Controls.Add($card)
        $parent.Controls.Remove($ctrl)
        $ctrl.Location = New-Object System.Drawing.Point($pad, $pad)
        $ctrl.Size = New-Object System.Drawing.Size(($sz.Width - $pad * 2), ($sz.Height - $pad * 2))
        $ctrl.BackColor = $fill
        $card.Controls.Add($ctrl)
        Set-GlassPanel $card $arc $fill 12 52
        return $card
    }

    # Smooth, OS-level rounded window corners on Windows 11 (perfectly anti-aliased,
    # no jagged Region clipping) + a subtle window border. Silent no-op on older OS.
    $form.Add_Shown({
        try {
            $pref = 2
            [void][Highsense.Dwm]::DwmSetWindowAttribute($form.Handle, 33, [ref]$pref, 4)
            $bcol = 0x3C3C3C
            [void][Highsense.Dwm]::DwmSetWindowAttribute($form.Handle, 34, [ref]$bcol, 4)
        } catch {}
    })

    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Size = New-Object System.Drawing.Size(550, 75)
    $headerPanel.Location = New-Object System.Drawing.Point(0, 0)
    $headerPanel.BackColor = $panelColor
    $form.Controls.Add($headerPanel)

    $dragging = $false
    $mouseOffset = $null

    $startDrag = {
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:dragging = $true
            $script:mouseOffset = $e.Location
        }
    }
    
    $doDrag = {
        param($sender, $e)
        if ($script:dragging) {
            $currentPos = [System.Windows.Forms.Cursor]::Position
            $form.Location = New-Object System.Drawing.Point(($currentPos.X - $script:mouseOffset.X), ($currentPos.Y - $script:mouseOffset.Y))
        }
    }
    
    $stopDrag = {
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:dragging = $false
        }
    }

    $headerPanel.Add_MouseDown($startDrag)
    $headerPanel.Add_MouseMove($doDrag)
    $headerPanel.Add_MouseUp($stopDrag)

    $lblLogo = New-Object System.Windows.Forms.Label
    $lblLogo.Text = "H I G H S E N S E"
    $lblLogo.Font = New-Object System.Drawing.Font("Segoe UI", 17, [System.Drawing.FontStyle]::Bold)
    $lblLogo.ForeColor = $textPrimary
    $lblLogo.Size = New-Object System.Drawing.Size(340, 32)
    $lblLogo.Location = New-Object System.Drawing.Point(15, 8)
    $lblLogo.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $lblLogo.Add_MouseDown($startDrag)
    $lblLogo.Add_MouseMove($doDrag)
    $lblLogo.Add_MouseUp($stopDrag)
    $headerPanel.Controls.Add($lblLogo)

    # --- Smooth Logo Fade Loop ---
    $fadeStep = 0
    $fadeDir = 1
    $fadeTimer = New-Object System.Windows.Forms.Timer
    $fadeTimer.Interval = 25
    $fadeTimer.Add_Tick({
        $script:fadeStep += ($script:fadeDir * 2)
        if ($script:fadeStep -ge 100) { $script:fadeDir = -1 }
        if ($script:fadeStep -le 0) { $script:fadeDir = 1 }
        
        $p = $script:fadeStep / 100
        $c = [int](26 + (240 - 26) * $p)
        $lblLogo.ForeColor = [System.Drawing.Color]::FromArgb($c, $c, $c)
    })
    $fadeTimer.Start()

    function Get-HeaderSpecText {
        param([object]$Specs)
        $cpuShort = Limit-SpecText $Specs.CPU 38
        return "RAM $($Specs.RamPct)% | C: $($Specs.FreeSSD) GB free | $cpuShort"
    }

    $lblSpecs = New-Object System.Windows.Forms.Label
    $lblSpecs.Text = Get-HeaderSpecText $currentSpecs
    $lblSpecs.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $lblSpecs.ForeColor = $textMuted
    $lblSpecs.Size = New-Object System.Drawing.Size(460, 20)
    $lblSpecs.Location = New-Object System.Drawing.Point(15, 44)
    $lblSpecs.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $lblSpecs.Add_MouseDown($startDrag)
    $lblSpecs.Add_MouseMove($doDrag)
    $lblSpecs.Add_MouseUp($stopDrag)
    $headerPanel.Controls.Add($lblSpecs)

    $specTimer = New-Object System.Windows.Forms.Timer
    $specTimer.Interval = 1000
    $specTimer.Add_Tick({
        try {
            $liveSpecs = Get-SystemSpecsFast
            $lblSpecs.Text = Get-HeaderSpecText $liveSpecs
            if ($script:systemStatusLines.Count -gt 0) {
                $script:systemStatusLines[2] = (Format-SpecLine "CPU" $liveSpecs.CPU)
                $script:systemStatusLines[3] = (Format-SpecLine "GPU" $liveSpecs.GPU)
                $script:systemStatusLines[4] = (Format-SpecLine "RAM" ("$($liveSpecs.UsedRAM) / $($liveSpecs.TotalRAM) GB | $($liveSpecs.RamPct)% used | $($liveSpecs.FreeRAM) GB free"))
                $script:systemStatusLines[5] = (Format-SpecLine "DISK" "C: $($liveSpecs.FreeSSD) GB free")
                $script:systemStatusLines[6] = (Format-SpecLine "OS" $liveSpecs.OS)
                Render-Log
            }
        } catch {}
    })
    $specTimer.Start()

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "X"
    $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $btnClose.Size = New-Object System.Drawing.Size(30, 30)
    $btnClose.Location = New-Object System.Drawing.Point(505, 10)
    $btnClose.BackColor = $panelColor
    $btnClose.ForeColor = $textMuted
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClose.Add_MouseEnter({ 
        $this.BackColor = [System.Drawing.Color]::FromArgb(196, 43, 28)
        $this.ForeColor = [System.Drawing.Color]::White 
    })
    $btnClose.Add_MouseLeave({ 
        $this.BackColor = $panelColor
        $this.ForeColor = $textMuted 
    })
    $btnClose.Add_Click({ $form.Close() })
    $headerPanel.Controls.Add($btnClose)

    $btnMinimize = New-Object System.Windows.Forms.Button
    $btnMinimize.Text = "-"
    $btnMinimize.Font = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
    $btnMinimize.Size = New-Object System.Drawing.Size(30, 30)
    $btnMinimize.Location = New-Object System.Drawing.Point(470, 10)
    $btnMinimize.BackColor = $panelColor
    $btnMinimize.ForeColor = $textMuted
    $btnMinimize.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnMinimize.FlatAppearance.BorderSize = 0
    $btnMinimize.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnMinimize.Add_MouseEnter({ 
        $this.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
        $this.ForeColor = [System.Drawing.Color]::White 
    })
    $btnMinimize.Add_MouseLeave({ 
        $this.BackColor = $panelColor
        $this.ForeColor = $textMuted 
    })
    $btnMinimize.Add_Click({ $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized })
    $headerPanel.Controls.Add($btnMinimize)

    $btnTab1 = New-Object System.Windows.Forms.Button
    $btnTab1.Text = "SenseOptimize"
    $btnTab1.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnTab1.Size = New-Object System.Drawing.Size(248, 32)
    $btnTab1.Location = New-Object System.Drawing.Point(24, 83)
    $btnTab1.BackColor = $tabActiveBg
    $btnTab1.ForeColor = $script:tabAccent
    $btnTab1.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnTab1.FlatAppearance.BorderSize = 0
    $btnTab1.Cursor = [System.Windows.Forms.Cursors]::Hand
    Set-GlassButton $btnTab1 10
    $form.Controls.Add($btnTab1)

    $btnTab2 = New-Object System.Windows.Forms.Button
    $btnTab2.Text = "Junk Cleaner"
    $btnTab2.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnTab2.Size = New-Object System.Drawing.Size(248, 32)
    $btnTab2.Location = New-Object System.Drawing.Point(278, 83)
    $btnTab2.BackColor = $tabBgColor
    $btnTab2.ForeColor = $textMuted
    $btnTab2.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnTab2.FlatAppearance.BorderSize = 0
    $btnTab2.Cursor = [System.Windows.Forms.Cursors]::Hand
    Set-GlassButton $btnTab2 10
    $form.Controls.Add($btnTab2)

    # Premium: sliding accent indicator under the active tab
    $script:tabIndicator = New-Object System.Windows.Forms.Panel
    $script:tabIndicator.Size = New-Object System.Drawing.Size(248, 3)
    $script:tabIndicator.Location = New-Object System.Drawing.Point(24, 113)
    $script:tabIndicator.BackColor = $script:tabAccent
    Set-GlassPanel $script:tabIndicator 3 $script:tabAccent 0 0
    $form.Controls.Add($script:tabIndicator)
    $script:tabIndicator.BringToFront()

    # Enable double-buffering on containers so the tab-switch slide repaints in one
    # smooth pass (no tearing/jank while the panels glide). Uses the protected
    # DoubleBuffered property via reflection - safe and standard for WinForms.
    $script:dbProp = [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    function Set-DoubleBuffered($ctrl) {
        try { if ($script:dbProp) { $script:dbProp.SetValue($ctrl, $true, $null) } } catch {}
    }

    $containerPanel = New-Object System.Windows.Forms.Panel
    $containerPanel.Size = New-Object System.Drawing.Size(550, 480)
    $containerPanel.Location = New-Object System.Drawing.Point(0, 123)
    $containerPanel.BackColor = $bgColor
    $form.Controls.Add($containerPanel)
    Set-DoubleBuffered $containerPanel

    $tab1Panel = New-Object System.Windows.Forms.Panel
    $tab1Panel.Size = New-Object System.Drawing.Size(550, 480)
    $tab1Panel.Location = New-Object System.Drawing.Point(0, 0)
    $tab1Panel.BackColor = $bgColor
    $containerPanel.Controls.Add($tab1Panel)
    Set-DoubleBuffered $tab1Panel

    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Multiline = $true
    $txtLog.ReadOnly = $true
    $txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $txtLog.BackColor = [System.Drawing.Color]::FromArgb(22, 22, 22)
    # Premium blue log text: a clean, comfortable azure - bright but easy on the eyes
    $txtLog.ForeColor = [System.Drawing.Color]::FromArgb(108, 172, 228)
    $txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
    $txtLog.Size = New-Object System.Drawing.Size(502, 175)
    $txtLog.Location = New-Object System.Drawing.Point(24, 10)
    $txtLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txtLog.WordWrap = $true
    $script:systemStatusLines = @(
        "HIGHSENSE / SYSTEM",
        "------------------------------",
        (Format-SpecLine "CPU" $currentSpecs.CPU),
        (Format-SpecLine "GPU" $currentSpecs.GPU),
        (Format-SpecLine "RAM" ("$($currentSpecs.UsedRAM) / $($currentSpecs.TotalRAM) GB | $($currentSpecs.RamPct)% used | $($currentSpecs.FreeRAM) GB free")),
        (Format-SpecLine "DISK" "C: $($currentSpecs.FreeSSD) GB free"),
        (Format-SpecLine "OS" $currentSpecs.OS),
        "",
        "ready.",
        "select a module to begin."
    )
    $script:logEntries = @()

    function Render-Log {
        $newText = (($script:systemStatusLines + $script:logEntries) -join "`r`n")
        # Only rewrite when the content actually changed - avoids a per-second
        # full redraw of the TextBox (which shows up as an annoying blink).
        if ($txtLog.Text -eq $newText) { return }
        $keepAtEnd = ($txtLog.SelectionStart -ge [math]::Max(0, $txtLog.TextLength - 1))
        $txtLog.Text = $newText
        if ($keepAtEnd) {
            $txtLog.SelectionStart = $txtLog.TextLength
            $txtLog.ScrollToCaret()
        }
    }
    Render-Log
    $tab1Panel.Controls.Add($txtLog)
    [void](Wrap-GlassCard $txtLog 14 6 ([System.Drawing.Color]::FromArgb(13, 13, 16)))


    $pBarBg = New-Object System.Windows.Forms.Panel
    $pBarBg.Size = New-Object System.Drawing.Size(502, 6)
    $pBarBg.Location = New-Object System.Drawing.Point(24, 193)
    $pBarBg.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    Set-RoundedControl $pBarBg 3
    $tab1Panel.Controls.Add($pBarBg)

    $pBarFill = New-Object System.Windows.Forms.Panel
    $pBarFill.Size = New-Object System.Drawing.Size(0, 6)
    $pBarFill.Location = New-Object System.Drawing.Point(0, 0)
    $pBarFill.BackColor = $progressFillCol
    Set-RoundedControl $pBarFill 3
    $pBarBg.Controls.Add($pBarFill)

    # Premium: gradient fill (teal -> sky) for the progress bar
    $pBarFill.Add_Paint({
        param($s, $e)
        if ($s.Width -le 0) { return }
        try {
            $rect = New-Object System.Drawing.Rectangle(0, 0, [math]::Max(1, $s.Width), $s.Height)
            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $script:accentColor, $script:accentColor2, [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
            $e.Graphics.FillRectangle($brush, $rect)
            $brush.Dispose()
        } catch {}
    })

    function Set-Progress($percent) {
        $percent = [math]::Max(0, [math]::Min(100, [double]$percent))
        $targetWidth = [math]::Round(502 * ($percent / 100))
        $currentWidth = $pBarFill.Width

        if ($targetWidth -eq $currentWidth) {
            $pBarBg.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
            return
        }

        $step = if ($targetWidth -gt $currentWidth) { 10 } else { -10 }
        while (($step -gt 0 -and $currentWidth -lt $targetWidth) -or ($step -lt 0 -and $currentWidth -gt $targetWidth)) {
            $currentWidth += $step
            if (($step -gt 0 -and $currentWidth -gt $targetWidth) -or ($step -lt 0 -and $currentWidth -lt $targetWidth)) {
                $currentWidth = $targetWidth
            }
            $pBarFill.Width = $currentWidth
            $pBarBg.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 8
        }
    }

    function Write-Log($text) {
        $script:logEntries += [string]$text
        Render-Log
        $txtLog.SelectionStart = $txtLog.TextLength
        $txtLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    function Write-ModuleInfo {
        param(
            [string]$Module,
            [string]$Engine,
            [string]$Scope,
            [string]$Action,
            [string]$Benefit,
            [string]$Tradeoff,
            [string]$Revert = "Repair High / original backup"
        )

        Write-Log ""
        Write-Log $Module
        Write-Log ("engine  : {0}" -f $Engine)
        Write-Log ("target  : {0}" -f $Scope)
        Write-Log ("action  : {0}" -f $Action)
        Write-Log ("result  : {0}" -f $Benefit)
        Write-Log ("note    : {0}" -f $Tradeoff)
        Write-Log ("revert  : {0}" -f $Revert)
    }

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.AutoPopDelay = 12000
    $toolTip.InitialDelay = 350
    $toolTip.ReshowDelay = 200
    $toolTip.ShowAlways = $true

    # ===========================================================================
    # PREMIUM UI - smooth micro-interaction engine (button color fade + tab slide)
    # A single shared timer interpolates BackColor for any registered control,
    # giving fluid hover/press transitions without per-control timers.
    # ===========================================================================
    $script:animControls = New-Object System.Collections.ArrayList
    $script:animTimer = New-Object System.Windows.Forms.Timer
    $script:animTimer.Interval = 15
    $script:animTimer.Add_Tick({
        for ($i = $script:animControls.Count - 1; $i -ge 0; $i--) {
            $a = $script:animControls[$i]
            $done = $false
            if ($a.cur -lt $a.target) {
                $a.cur = [math]::Min($a.target, $a.cur + 0.2)
                if ($a.cur -ge $a.target) { $done = $true }
            } elseif ($a.cur -gt $a.target) {
                $a.cur = [math]::Max($a.target, $a.cur - 0.2)
                if ($a.cur -le $a.target) { $done = $true }
            } else {
                $done = $true
            }
            $t = $a.cur
            $r = [int]($a.base.R + ($a.hover.R - $a.base.R) * $t)
            $g = [int]($a.base.G + ($a.hover.G - $a.base.G) * $t)
            $b = [int]($a.base.B + ($a.hover.B - $a.base.B) * $t)
            try { $a.ctrl.BackColor = [System.Drawing.Color]::FromArgb($r, $g, $b) } catch {}
            if ($done) { $script:animControls.RemoveAt($i) }
        }
        if ($script:animControls.Count -eq 0) { $script:animTimer.Stop() }
    })

    function Register-Anim($a) {
        if ($null -eq $a) { return }
        if (-not $script:animControls.Contains($a)) { [void]$script:animControls.Add($a) }
        if (-not $script:animTimer.Enabled) { $script:animTimer.Start() }
    }

    function Move-TabIndicator($targetX) {
        # Smooth, frame-rate-independent glide (ease-out-cubic). Kept for standalone use;
        # the tab switch drives the indicator through Switch-Panels for a synced motion.
        if ($null -eq $script:tabIndicator) { return }
        $startX = [double]$script:tabIndicator.Location.X
        $delta  = $targetX - $startX
        if ([math]::Abs($delta) -lt 1) { return }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $dur = 220.0
        while ($true) {
            $t = $sw.Elapsed.TotalMilliseconds / $dur
            if ($t -ge 1) { break }
            $ease = 1 - [math]::Pow(1 - $t, 3)
            $x = [int]($startX + $delta * $ease)
            $script:tabIndicator.Location = New-Object System.Drawing.Point($x, 113)
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 4
        }
        $script:tabIndicator.Location = New-Object System.Drawing.Point([int]$targetX, 113)
    }

    # Clean, artifact-free tab transition.
    #
    # Why not a bitmap cross-fade: WinForms has no real per-control opacity, so a true
    # fade requires snapshotting the panels - but DrawToBitmap ignores each button's
    # rounded Region, so the snapshot shows SQUARE corners and swapping the overlay in/out
    # flickers. To keep every rounded corner crisp and avoid any flicker, the content is
    # swapped instantly (no distortion) and the premium motion lives in the accent
    # indicator, which is a small solid bar that glides perfectly smoothly.
    function Switch-Panels($outgoing, $incoming, $forward, $indicatorTargetX) {
        # instant, pixel-perfect content swap (rounded UI stays crisp, zero flicker)
        $incoming.Location = New-Object System.Drawing.Point(0, 0)
        $incoming.Visible  = $true
        $incoming.BringToFront()
        $outgoing.Visible  = $false
        $outgoing.Location = New-Object System.Drawing.Point(0, 0)
        if ($null -ne $script:tabIndicator) { $script:tabIndicator.BringToFront() }

        # Single accent bar glides smoothly to the selected tab (ease-out-cubic:
        # quick off the mark, gentle soft landing).
        if ($null -ne $indicatorTargetX -and $null -ne $script:tabIndicator) {
            $startX = [double]$script:tabIndicator.Location.X
            $delta  = $indicatorTargetX - $startX
            if ([math]::Abs($delta) -ge 1) {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $dur = 260.0
                while ($true) {
                    $t = $sw.Elapsed.TotalMilliseconds / $dur
                    if ($t -ge 1) { break }
                    $ease = 1 - [math]::Pow(1 - $t, 3)
                    $x = [int]($startX + $delta * $ease)
                    $script:tabIndicator.Location = New-Object System.Drawing.Point($x, 113)
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Milliseconds 5
                }
            }
            $script:tabIndicator.Location = New-Object System.Drawing.Point([int]$indicatorTargetX, 113)
        }
    }

    function Create-CustomButton {
        param($parent, $text, $x, $y, $w, $h, $fontSize = 8.5, $action)
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $text
        $btn.Size = New-Object System.Drawing.Size($w, $h)
        $btn.Location = New-Object System.Drawing.Point($x, $y)
        $btn.BackColor = $btnColor
        $btn.ForeColor = $btnText
        $btn.Font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold)
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.FlatAppearance.BorderSize = 0
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand

        # Smooth anti-aliased pill (painted, not Region-clipped, so corners stay crisp)
        Set-DoubleBuffered $btn

        $btn.Tag = @{ ctrl = $btn; cur = 0.0; target = 0.0; base = $btnColor; hover = $btnHoverColor }

        $btn.Add_MouseEnter({ if ($this.Enabled) { $this.Tag.target = 1.0; Register-Anim $this.Tag; $this.ForeColor = [System.Drawing.Color]::White } })
        $btn.Add_MouseLeave({ if ($this.Enabled) { $this.Tag.target = 0.0; Register-Anim $this.Tag; $this.ForeColor = $btnText } })
        $btn.Add_MouseDown({ if ($this.Enabled) { $this.Tag.cur = 1.0; $this.BackColor = $btnActiveColor } })
        $btn.Add_MouseUp({ if ($this.Enabled) { $this.Tag.cur = 1.0; $this.BackColor = $btnHoverColor } })

        # Premium button painter: animated glowing edge on hover + status dot
        $btn.Add_Paint({
            param($s, $e)
            try {
                $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                $e.Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $e.Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $e.Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

                # --- Premium soft gradient fill (clipped to the pill region) ---
                # A gentle vertical sheen that warms up + gains a soft blue tint as
                # the hover/press animation rises, so there is no flat, hard edge.
                $cur = 0.0
                if ($null -ne $s.Tag -and $null -ne $s.Tag.cur) { $cur = [double]$s.Tag.cur }
                if ($cur -lt 0) { $cur = 0 } elseif ($cur -gt 1) { $cur = 1 }
                $bc = $s.BackColor
                $topAdd  = [int](16 + 26 * $cur)
                $blueT   = [int](46 * $cur)
                $topR = [math]::Min(255, $bc.R + $topAdd)
                $topG = [math]::Min(255, $bc.G + $topAdd + [int](10 * $cur))
                $topB = [math]::Min(255, $bc.B + $topAdd + $blueT)
                $botR = [math]::Min(255, $bc.R + [int](4 * $cur))
                $botG = [math]::Min(255, $bc.G + [int](10 * $cur))
                $botB = [math]::Min(255, $bc.B + [int](26 * $cur))
                $topCol = [System.Drawing.Color]::FromArgb(255, $topR, $topG, $topB)
                $botCol = [System.Drawing.Color]::FromArgb(255, $botR, $botG, $botB)
                $pc = if ($null -ne $s.Parent) { $s.Parent.BackColor } else { $s.BackColor }
                $e.Graphics.Clear($pc)
                $bpath = New-RoundedPath ($s.Width - 1) ($s.Height - 1) $s.Height
                $grRect = New-Object System.Drawing.Rectangle(0, -1, $s.Width, ($s.Height + 2))
                $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($grRect, $topCol, $botCol, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
                $e.Graphics.FillPath($bgBrush, $bpath)
                $bgBrush.Dispose()
                $bpath.Dispose()
                # re-draw the label on top of the gradient (control text was covered)
                $tfFlags = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine
                [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $s.Text, $s.Font, (New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)), $s.ForeColor, $tfFlags)

                # subtle glowing white edge that fades in/out with the hover animation
                if ($null -ne $s.Tag -and $s.Tag.cur -gt 0.04) {
                    $al = [int]([math]::Min(1.0, [double]$s.Tag.cur) * 70)
                    $rad = $s.Height
                    $rr = New-Object System.Drawing.Rectangle(0, 0, ($s.Width - 1), ($s.Height - 1))
                    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
                    $gp.AddArc($rr.X, $rr.Y, $rad, $rad, 180, 90)
                    $gp.AddArc(($rr.Right - $rad), $rr.Y, $rad, $rad, 270, 90)
                    $gp.AddArc(($rr.Right - $rad), ($rr.Bottom - $rad), $rad, $rad, 0, 90)
                    $gp.AddArc($rr.X, ($rr.Bottom - $rad), $rad, $rad, 90, 90)
                    $gp.CloseFigure()
                    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 255, 255, 255), 1)
                    $e.Graphics.DrawPath($pen, $gp)
                    $pen.Dispose(); $gp.Dispose()
                }

                # per-module status: a soft white light that glides back and forth
                # along ONLY the bottom edge of the category when applied - smooth,
                # dim, easing at the turns then continuing seamlessly.
                if ($null -ne $s.Tag) {
                    $key = $s.Tag.statusKey
                    if ($key) {
                        $st = $script:moduleStatus[$key]
                        $rad = $s.Height
                        $by = [double]($s.Height - 2.5)
                        $bx1 = [double]$rad
                        $bx2 = [double]($s.Width - $rad)
                        $span = $bx2 - $bx1
                        if ($span -gt 4) {
                            if ($st -eq 'APPLIED') {
                                # faint always-on base line so the bottom edge reads softly
                                $basePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(16, 255, 255, 255), [single]1.0)
                                $e.Graphics.DrawLine($basePen, [single]$bx1, [single]$by, [single]$bx2, [single]$by)
                                $basePen.Dispose()

                                # Premium DUAL orbit: two comet-like light beams travel the
                                # bottom edge in OPPOSITE directions - beam A slides left->right,
                                # beam B slides right->left. Each has a bright head with a soft
                                # trailing tail (tail points BACKWARD along its own travel), so
                                # the two clearly PASS THROUGH each other rather than bounce.
                                # Both fade fully to nothing right at the ends, then re-emerge
                                # from the start of their travel - a clean, looping cross.
                                $p = [double]$script:pulsePhase / 6.2831853
                                $p = $p - [math]::Floor($p)
                                # each cycle = one travel sweep, then a ~1.5s dark HOLD where
                                # both beams stay fully gone before the next sweep begins
                                $travelFrac = 0.57
                                $fA = 0.0
                                $inHold = $true
                                if ($p -lt $travelFrac) { $fA = $p / $travelFrac; $inHold = $false }
                                $fB = 1.0 - $fA
                                $cA = $bx1 + $span * $fA
                                $cB = $bx1 + $span * $fB
                                # travel envelope: 0 at both ends (fully vanish), full in middle
                                $envA = 1.0
                                if     ($fA -lt 0.20) { $envA = $fA / 0.20 }
                                elseif ($fA -gt 0.80) { $envA = (1.0 - $fA) / 0.20 }
                                $envA = $envA * $envA * (3.0 - 2.0 * $envA)
                                $envB = 1.0
                                if     ($fB -lt 0.20) { $envB = $fB / 0.20 }
                                elseif ($fB -gt 0.80) { $envB = (1.0 - $fB) / 0.20 }
                                $envB = $envB * $envB * (3.0 - 2.0 * $envB)
                                $sLead = $span * 0.055
                                $sTail = $span * 0.16
                                if ($sLead -lt 1) { $sLead = 1 }
                                if ($sTail -lt 1) { $sTail = 1 }
                                $peakA = 165 * $envA
                                $peakB = 165 * $envB
                                if ($inHold) { $peakA = 0; $peakB = 0 }
                                if ($peakA -gt 3 -or $peakB -gt 3) {
                                    $x = $bx1
                                    while ($x -le $bx2) {
                                        # beam A moves RIGHT: sharp head ahead (right), tail left
                                        $dA = $x - $cA
                                        if ($dA -gt 0) { $sa = $sLead } else { $sa = $sTail }
                                        $ra = $dA / $sa
                                        # beam B moves LEFT: sharp head ahead (left), tail right
                                        $dB = $x - $cB
                                        if ($dB -lt 0) { $sb = $sLead } else { $sb = $sTail }
                                        $rb = $dB / $sb
                                        $al = [int]($peakA * [math]::Exp(-($ra * $ra)) + $peakB * [math]::Exp(-($rb * $rb)))
                                        if ($al -gt 3) {
                                            if ($al -gt 255) { $al = 255 }
                                            $lp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($al, 255, 255, 255), [single]1.6)
                                            $lp.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                                            $lp.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                                            $e.Graphics.DrawLine($lp, [single]$x, [single]$by, [single]($x + 1.8), [single]$by)
                                            $lp.Dispose()
                                        }
                                        $x += 1.6
                                    }
                                }
                            } else {
                                # not applied: a very faint static bottom line
                                $offPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(12, 200, 205, 215), [single]1.0)
                                $e.Graphics.DrawLine($offPen, [single]$bx1, [single]$by, [single]$bx2, [single]$by)
                                $offPen.Dispose()
                            }
                        }
                    }
                }
            } catch {}
        })

        if ($action) { 
            $btn.Add_Click($action) 
        }

        $parent.Controls.Add($btn)
        return $btn
    }

    # ===========================================================================
    # HIGHSENSE SAFETY LAYER - Backup original values before every change + Restore Point
    # Core of "do not break the PC": every value any button changes must have its original saved first
    # always. If already saved in a previous session it will not be overwritten (avoid re-saving a modified value)
    # ===========================================================================
    $script:backupDir  = Join-Path $env:ProgramData "Highsense"
    $script:backupFile = Join-Path $script:backupDir "highsense_backup.json"
    $script:backupMap  = @{}
    $script:restorePointDone = $false

    try { if (!(Test-Path $script:backupDir)) { New-Item -Path $script:backupDir -ItemType Directory -Force | Out-Null } } catch {}

    if (Test-Path $script:backupFile) {
        try {
            $loaded = Get-Content $script:backupFile -Raw -ErrorAction Stop | ConvertFrom-Json
            foreach ($item in @($loaded)) {
                if ($item.Key) { $script:backupMap[$item.Key] = $item }
            }
        } catch {}
    }

    # ===========================================================================
    # PER-MODULE STATUS - remember which modules were already applied/reverted
    # so each category shows an on/off status dot across sessions.
    # ===========================================================================
    $script:modStatusFile = Join-Path $script:backupDir "highsense_modstatus.json"
    $script:moduleStatus  = @{}
    $script:moduleButtons = @{}

    if (Test-Path $script:modStatusFile) {
        try {
            $ms = Get-Content $script:modStatusFile -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($ms) {
                foreach ($p in $ms.PSObject.Properties) { $script:moduleStatus[$p.Name] = [string]$p.Value }
            }
        } catch {}
    }

    function Save-ModuleStatus {
        try {
            if (!(Test-Path $script:backupDir)) { New-Item -Path $script:backupDir -ItemType Directory -Force -ErrorAction Stop | Out-Null }
            ($script:moduleStatus | ConvertTo-Json) | Set-Content -Path $script:modStatusFile -Encoding UTF8 -ErrorAction Stop
        } catch {}
    }

    function Set-ModuleStatus($key, $state) {
        if (-not $key) { return }
        $script:moduleStatus[$key] = $state
        Save-ModuleStatus
        if ($script:moduleButtons.ContainsKey($key)) {
            try { $script:moduleButtons[$key].Invalidate() } catch {}
        }
        Ensure-PulseTimer
    }

    function Reset-ModuleStatus {
        foreach ($k in @('CMD','POWERPLAN','NET','SYSTEM','INPUT')) { $script:moduleStatus[$k] = 'NONE' }
        Save-ModuleStatus
        foreach ($k in @('CMD','POWERPLAN','NET','SYSTEM','INPUT')) {
            if ($script:moduleButtons.ContainsKey($k)) { try { $script:moduleButtons[$k].Invalidate() } catch {} }
        }
    }

    # ---- Smooth looping "twinkle" glow for applied module dots ----
    $script:pulsePhase = 0.0
    $script:pulseTimer = New-Object System.Windows.Forms.Timer
    $script:pulseTimer.Interval = 25
    $script:pulseTimer.Add_Tick({
        $script:pulsePhase += 0.045
        if ($script:pulsePhase -gt 6.2831853) { $script:pulsePhase -= 6.2831853 }
        $any = $false
        foreach ($k in @('CMD','POWERPLAN','NET','SYSTEM','INPUT')) {
            if ($script:moduleStatus[$k] -eq 'APPLIED') {
                $any = $true
                if ($script:moduleButtons.ContainsKey($k)) { try { $script:moduleButtons[$k].Invalidate() } catch {} }
            }
        }
        if (-not $any) { $script:pulseTimer.Stop() }
    })

    function Ensure-PulseTimer {
        foreach ($k in @('CMD','POWERPLAN','NET','SYSTEM','INPUT')) {
            if ($script:moduleStatus[$k] -eq 'APPLIED') {
                if (-not $script:pulseTimer.Enabled) { $script:pulseTimer.Start() }
                return
            }
        }
    }


function Save-BackupMap {
    try {
        if (!(Test-Path $script:backupDir)) {
            New-Item -Path $script:backupDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        $json = @($script:backupMap.Values) | ConvertTo-Json -Depth 8
        Set-Content -Path $script:backupFile -Value $json -Encoding UTF8 -ErrorAction Stop
        return $true
    } catch {
        Write-Log "[BACKUP] FAILED to save backup file: $($_.Exception.Message)"
        return $false
    }
}

function Backup-RegValue {
    param([string]$Path, [string]$Name)

    $key = "$Path|$Name"
    if ($script:backupMap.ContainsKey($key)) { return }

    $entry = [PSCustomObject]@{
        Key     = $key
        Type    = "Registry"
        Path    = $Path
        Name    = $Name
        Existed = $false
        Value   = $null
    }

    try {
        if (Test-Path $Path) {
            try {
                $existing = Get-ItemProperty -Path $Path -ErrorAction Stop
                if ($null -ne $existing.PSObject.Properties[$Name]) {
                    $entry.Existed = $true
                    $entry.Value   = $existing.PSObject.Properties[$Name].Value
                }
            } catch {
                # Value not present; keep Existed = false.
            }
        }
    } catch {}

    $script:backupMap[$key] = $entry
    if (-not (Save-BackupMap)) {
        $script:backupMap.Remove($key)
        throw "Could not persist registry backup for $Path -> $Name"
    }
}

function Backup-PowerScheme {
    $key = "PowerScheme|Active"
    if ($script:backupMap.ContainsKey($key)) { return }

    try {
        $active = powercfg -getactivescheme 2>&1
        $m = [regex]::Match(($active -join "`n"), "([a-fA-F0-9\-]{36})")
        if (-not $m.Success) {
            throw "Could not determine the active Power Scheme GUID."
        }

        $script:backupMap[$key] = [PSCustomObject]@{
            Key  = $key
            Type = "PowerScheme"
            Guid = $m.Value
        }

        if (-not (Save-BackupMap)) {
            $script:backupMap.Remove($key)
            throw "Could not persist the active Power Scheme backup."
        }
    } catch {
        Write-Log "[BACKUP] Power Scheme backup failed: $($_.Exception.Message)"
        throw
    }
}

function Register-CreatedPowerScheme {
    param([Parameter(Mandatory)][string]$Guid)

    $key = "PowerSchemeCreated|$Guid"
    $script:backupMap[$key] = [PSCustomObject]@{
        Key  = $key
        Type = "PowerSchemeCreated"
        Guid = $Guid
    }

    if (-not (Save-BackupMap)) {
        $script:backupMap.Remove($key)
        throw "Could not persist the created HighSense Power Plan backup."
    }
}

function Backup-HibernateState {
    $key = "Hibernate|State"
    if ($script:backupMap.ContainsKey($key)) { return }

    $wasOn = $true
    try {
        $v = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HiberFileEnabled" -ErrorAction SilentlyContinue).HiberFileEnabled
        if ($null -ne $v) { $wasOn = [bool]$v }
    } catch {}

    $script:backupMap[$key] = [PSCustomObject]@{
        Key   = $key
        Type  = "Hibernate"
        WasOn = $wasOn
    }

    if (-not (Save-BackupMap)) {
        $script:backupMap.Remove($key)
        throw "Could not persist the Hibernation backup."
    }
}

function New-SafetyRestorePoint {
    if ($script:restorePointDone) { return }

    try {
        Write-Log "[BACKUP] Attempting Windows Restore Point (8s non-blocking timeout)..."
        Set-Progress 4

        try {
            # Checkpoint-Computer can block the WinForms UI for a long time on some systems.
            # Run it in a short-lived background PowerShell job. Persistent JSON backup remains
            # the primary reversible state even when System Restore is unavailable.
            $job = Start-Job -ScriptBlock {
                try {
                    Checkpoint-Computer -Description "HIGHSENSE Before Optimize" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
                    "SUCCESS"
                } catch {
                    "FAILED: $($_.Exception.Message)"
                }
            }

            $deadline = (Get-Date).AddSeconds(8)
            $restoreResult = $null

            while ((Get-Date) -lt $deadline -and $job.State -in @("NotStarted", "Running")) {
                $elapsed = 8 - [math]::Max(0, ($deadline - (Get-Date)).TotalSeconds)
                $pct = 5 + [math]::Min(10, [math]::Round(($elapsed / 8) * 10))
                Set-Progress $pct
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 120
                try { $restoreResult = Receive-Job -Job $job -ErrorAction SilentlyContinue } catch {}
                if ($restoreResult) { break }
            }

            if ($job.State -eq "Completed") {
                $restoreResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
                if ($restoreResult -and ($restoreResult -join "`n") -match "^SUCCESS") {
                    Write-Log "[BACKUP] Windows Restore Point created."
                } else {
                    Write-Log "[BACKUP] Restore Point unavailable; persistent HIGHSENSE backup remains active."
                }
            } elseif ($job.State -in @("Running", "NotStarted")) {
                Write-Log "[BACKUP] Restore Point timed out; continuing without blocking the tweak."
                try { Stop-Job -Job $job -ErrorAction SilentlyContinue } catch {}
            } else {
                $restoreResult = Receive-Job -Job $job -ErrorAction SilentlyContinue
                Write-Log "[BACKUP] Restore Point unavailable: $($restoreResult -join ' ')"
            }

            try { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue } catch {}
        } catch {
            Write-Log "[BACKUP] Could not start Restore Point task; persistent backup remains active."
        }
    } finally {
        $script:restorePointDone = $true
        Set-Progress 12
    }
}

function Restore-AllBackups {
    if (-not (Test-Path $script:backupFile)) {
        Write-Log "[REPAIR] No HIGHSENSE backup found yet - nothing to restore."
        return [PSCustomObject]@{ Restored = 0; Failed = 0 }
    }

    $items = @()
    try {
        $items = @(Get-Content $script:backupFile -Raw -ErrorAction Stop | ConvertFrom-Json)
    } catch {
        Write-Log "[REPAIR] Backup file could not be read: $($_.Exception.Message)"
        return [PSCustomObject]@{ Restored = 0; Failed = 1 }
    }

    if ($items.Count -eq 0) {
        Write-Log "[REPAIR] Backup file is empty - nothing to restore."
        return [PSCustomObject]@{ Restored = 0; Failed = 0 }
    }

    $restored = 0
    $failed = 0

    # Restore Registry + Hibernation first.
    foreach ($item in $items | Where-Object { $_.Type -eq "Registry" -or $_.Type -eq "Hibernate" }) {
        try {
            if ($item.Type -eq "Registry") {
                if ($item.Existed) {
                    if (Test-Path $item.Path) {
                        Set-ItemProperty -Path $item.Path -Name $item.Name -Value $item.Value -ErrorAction Stop
                    } else {
                        throw "Registry path does not exist: $($item.Path)"
                    }
                } else {
                    if (Test-Path $item.Path) {
                        Remove-ItemProperty -Path $item.Path -Name $item.Name -ErrorAction SilentlyContinue
                    }
                }
                $restored++
            }
            elseif ($item.Type -eq "Hibernate") {
                if ($item.WasOn) {
                    $p = Start-Process cmd -ArgumentList "/c powercfg -h on" -NoNewWindow -Wait -PassThru
                } else {
                    $p = Start-Process cmd -ArgumentList "/c powercfg -h off" -NoNewWindow -Wait -PassThru
                }
                if ($p.ExitCode -ne 0) { throw "powercfg -h returned exit code $($p.ExitCode)" }
                $restored++
            }
        } catch {
            $failed++
            Write-Log "[REPAIR] Failed to restore $($item.Path) -> $($item.Name): $($_.Exception.Message)"
        }
    }

    # Restore the original active Power Scheme before deleting any HighSense clone.
    $powerRestoreOk = $true
    $powerItems = @($items | Where-Object { $_.Type -eq "PowerScheme" })

    foreach ($item in $powerItems) {
        try {
            $schemeList = powercfg -list 2>&1
            if (($schemeList -join "`n") -notmatch [regex]::Escape($item.Guid)) {
                throw "Original Power Scheme $($item.Guid) no longer exists."
            }

            powercfg -setactive $item.Guid 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "powercfg -setactive returned exit code $LASTEXITCODE" }
            $restored++
        } catch {
            $powerRestoreOk = $false
            $failed++
            Write-Log "[REPAIR] Failed to restore original Power Scheme $($item.Guid): $($_.Exception.Message)"
        }
    }

    # Remove only Power Plans created by HighSense, and only after the original plan is active.
    if ($powerRestoreOk) {
        foreach ($item in $items | Where-Object { $_.Type -eq "PowerSchemeCreated" }) {
            try {
                $schemeList = powercfg -list 2>&1
                if (($schemeList -join "`n") -notmatch [regex]::Escape($item.Guid)) {
                    Write-Log "[REPAIR] HighSense Power Plan $($item.Guid) is already absent; cleanup considered complete."
                    $restored++
                    continue
                }

                powercfg -delete $item.Guid 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "powercfg -delete returned exit code $LASTEXITCODE" }
                $restored++
                Write-Log "[REPAIR] Removed HighSense Power Plan $($item.Guid)."
            } catch {
                $failed++
                Write-Log "[REPAIR] Could not remove HighSense Power Plan $($item.Guid): $($_.Exception.Message)"
            }
        }

        # Sweep any leftover HighSense-named plans from earlier runs (best-effort cleanup).
        try {
            $listRaw2 = (powercfg -list 2>&1) -join "`n"
            foreach ($ln in ($listRaw2 -split "`n")) {
                $gm = [regex]::Match($ln, "([a-fA-F0-9\-]{36})")
                $nm = [regex]::Match($ln, "\(([^)]*)\)")
                if ($gm.Success -and $nm.Success -and $nm.Groups[1].Value -match "HighSense") {
                    powercfg -delete $gm.Value 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) { Write-Log "[REPAIR] Removed leftover HighSense plan $($gm.Value)." }
                }
            }
        } catch {}
    } elseif (@($items | Where-Object { $_.Type -eq "PowerSchemeCreated" }).Count -gt 0) {
        Write-Log "[REPAIR] Keeping HighSense Power Plan clone(s) because the original active scheme could not be restored correctly."
    }

    if ($failed -eq 0) {
        try {
            $script:backupMap.Clear()
            Remove-Item -Path $script:backupFile -Force -ErrorAction Stop
            Write-Log "[REPAIR] Backup state cleared after a complete restore."
        } catch {
            $failed++
            Write-Log "[REPAIR] Settings were restored, but backup cleanup failed: $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{ Restored = $restored; Failed = $failed }
}

    function Clear-FolderSafe {
        param([string]$Path)
        $freed = 0.0
        if (Test-Path -LiteralPath $Path) {
            Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $item = $_
                try {
                    $size = 0.0
                    if ($item.PSIsContainer) {
                        $sum = (Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        if ($sum) { $size = [double]$sum }
                    } elseif ($item.Length) {
                        $size = [double]$item.Length
                    }
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                    $freed += $size
                } catch {}
            }
        }
        return $freed
    }

    $btnRepair = (Create-CustomButton $tab1Panel " Repair High" 24 212 502 38 8.0 {
        $tab1Panel.Enabled = $false; $ErrorActionPreference = 'Stop'
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        Write-ModuleInfo `
            -Module "REPAIR HIGH" `
            -Engine "PowerShell + Registry + powercfg" `
            -Scope "Only values previously backed up by HIGHSENSE" `
            -Action "Restore backed-up registry/hibernate values and the prior active Power Scheme" `
            -Benefit "Returns to recorded values instead of guessing Windows defaults" `
            -Tradeoff "Only values saved by HIGHSENSE are restored"
        Write-Log "[REPAIR HIGH] Restoring all HIGHSENSE changes to their original values..."
        Set-Progress 8

        $result = Restore-AllBackups
        Set-Progress 85

        if ($result.Failed -eq 0 -and $result.Restored -gt 0) {
            $script:restorePointDone = $false
            Write-Log "[SUCCESS] Restored $($result.Restored) setting(s) and removed tracked HighSense Power Plans."
            Write-Log "[INFO] Reboot recommended for changes that are documented as reboot-dependent."
        } elseif ($result.Failed -gt 0) {
            Write-Log "[WARNING] Restore completed with $($result.Failed) failure(s). Backup was kept for another repair attempt."
        } else {
            Write-Log "[INFO] Nothing to restore - no active HIGHSENSE backup was found."
        }
        Set-Progress 100
        Start-Sleep -Milliseconds 300
        Set-Progress 0

        $tab1Panel.Enabled = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    })
    
    # ---------------------------------------------------------
    # CMD / REG button (System Core) - Registry + powercfg
    # ---------------------------------------------------------
    $btnCMD = (Create-CustomButton $tab1Panel "CMD / REG" 24 262 240 38 8.5 {
        $tab1Panel.Enabled = $false; $ErrorActionPreference = 'Stop'
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        Write-ModuleInfo `
            -Module "CMD / REG" `
            -Engine "PowerShell Registry Provider + powercfg.exe" `
            -Scope "HKLM/HKCU gaming and system settings" `
            -Action "Driver/temp check, scheduler, GameDVR, windowed-game optimizations; optional power controls" `
            -Benefit "Reduces selected capture/background work; no web downloads" `
            -Tradeoff "Recording/sync may be reduced; gains vary by workload"
        Write-Log "[CMD / REG] System tuning started..."
        Set-Progress 2
        New-SafetyRestorePoint

        # --- Read-only diagnostics (merged from the old DRIVER CHECK / TEMP CHECK) ---
        try {
            Set-Progress 8
            Write-Log "[CHECK] Read-only driver + temperature snapshot (nothing is installed or overclocked)..."
            $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -and $_.Name -notmatch "Microsoft Basic Display Adapter" }
            foreach ($g in $gpus) {
                $drvDate = $null
                try { $drvDate = [Management.ManagementDateTimeConverter]::ToDateTime($g.DriverDate) } catch {}
                Write-Log "[GPU] $($g.Name) | driver $($g.DriverVersion)"
                if ($drvDate) {
                    $ageDays = [int]((Get-Date) - $drvDate).TotalDays
                    if ($ageDays -gt 120) {
                        Write-Log "       [ADVICE] GPU driver is $ageDays days old - consider updating (NVIDIA App / Adrenalin / Arc)."
                    } else {
                        Write-Log "       [OK] GPU driver looks recent ($ageDays days old). HIGHSENSE never auto-installs drivers."
                    }
                }
            }
            $load = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).LoadPercentage
            if ($null -ne $load) { Write-Log "[CPU] Current load: $load%" }
            try {
                $tz = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
                foreach ($z in @($tz)) {
                    $c2 = [math]::Round(($z.CurrentTemperature / 10) - 273.15, 1)
                    Write-Log "[ACPI] Thermal zone: $c2 °C"
                }
            } catch { Write-Log "[INFO] ACPI thermal zone not exposed by this system (common on desktops)." }
            try {
                $smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
                if ($smi) {
                    $gt = (& nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null)
                    foreach ($t in @($gt)) { if ($t) { Write-Log "[GPU] NVIDIA temp: $($t.ToString().Trim()) °C" } }
                }
            } catch {}
            Write-Log "[GUIDE] Healthy gaming range: CPU < ~85 °C, GPU < ~83 °C. Higher = clean fans / improve airflow."
        } catch { Write-Log "[ERROR] Diagnostics: $($_.Exception.Message)" }

        try {
            Set-Progress 18
            Write-Log "[CHECK] 1/10 Hardware-Accelerated GPU Scheduling (HAGS) is left at the Windows/driver default."
            Write-Log "       -> HIGHSENSE no longer forces HAGS: it can cause stutter on some GPUs/drivers. Set it in Windows Graphics settings if you want it."
        } catch { Write-Log "[ERROR] Step 1: $($_.Exception.Message)" }

        try {
            Set-Progress 30
            Write-Log "[REG] 2/10 Setting multimedia/gaming scheduler (SystemResponsiveness = 10)..."
            $mmProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            if (!(Test-Path $mmProfile)) { New-Item -Path $mmProfile -Force | Out-Null }
            Backup-RegValue -Path $mmProfile -Name "SystemResponsiveness"
            Set-ItemProperty -Path $mmProfile -Name "SystemResponsiveness" -Value 10 -Type DWord
            Write-Log "       -> Gives games/multimedia more CPU headroom (Windows clamps below 10). Reversible via Repair."

            if ($script:gamesTaskPriority) {
                Write-Log "[REG] 2b/10 Raising MMCSS 'Games' task priority (optional flag = ON)..."
                $gamesTask = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
                if (!(Test-Path $gamesTask)) { New-Item -Path $gamesTask -Force | Out-Null }
                Backup-RegValue -Path $gamesTask -Name "GPU Priority"
                Set-ItemProperty -Path $gamesTask -Name "GPU Priority" -Value 8 -Type DWord
                Backup-RegValue -Path $gamesTask -Name "Priority"
                Set-ItemProperty -Path $gamesTask -Name "Priority" -Value 6 -Type DWord
                Backup-RegValue -Path $gamesTask -Name "Scheduling Category"
                Set-ItemProperty -Path $gamesTask -Name "Scheduling Category" -Value "High" -Type String
                Backup-RegValue -Path $gamesTask -Name "SFIO Priority"
                Set-ItemProperty -Path $gamesTask -Name "SFIO Priority" -Value "High" -Type String
                Backup-RegValue -Path $gamesTask -Name "Clock Rate"
                Set-ItemProperty -Path $gamesTask -Name "Clock Rate" -Value 10000 -Type DWord
                Write-Log "       -> Games get higher GPU/CPU scheduling priority. Safe and fully reversible via Repair."
            } else {
                Write-Log "[SKIP] 2b/10 MMCSS 'Games' task priority is OFF."
            }
        } catch { Write-Log "[ERROR] Step 2: $($_.Exception.Message)" }

        try {
            Set-Progress 48
            Write-Log "[REG] 3/10 Disabling Game DVR capture overhead; leaving Game Mode enabled..."
            $gameCfgPath = "HKCU:\System\GameConfigStore"
            if (!(Test-Path $gameCfgPath)) { New-Item -Path $gameCfgPath -Force | Out-Null }
            Backup-RegValue -Path $gameCfgPath -Name "GameDVR_Enabled"
            Set-ItemProperty -Path $gameCfgPath -Name "GameDVR_Enabled" -Value 0 -Type DWord
            if ($script:forceGameDvrPolicy) {
                $dvrPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
                if (!(Test-Path $dvrPolicy)) { New-Item -Path $dvrPolicy -Force | Out-Null }
                Backup-RegValue -Path $dvrPolicy -Name "AllowGameDVR"
                Set-ItemProperty -Path $dvrPolicy -Name "AllowGameDVR" -Value 0 -Type DWord
                Write-Log "       -> Optional machine policy applied because forceGameDvrPolicy = ON."
            } else {
                Write-Log "       -> Machine-level GameDVR policy is OFF by default."
            }
            $gameBarPath = "HKCU:\Software\Microsoft\GameBar"
            if (!(Test-Path $gameBarPath)) { New-Item -Path $gameBarPath -Force | Out-Null }
            Backup-RegValue -Path $gameBarPath -Name "AutoGameModeEnabled"
            Set-ItemProperty -Path $gameBarPath -Name "AutoGameModeEnabled" -Value 1 -Type DWord
        } catch { Write-Log "[ERROR] Step 3: $($_.Exception.Message)" }

        try {
            Set-Progress 58
            if ($script:disablePowerThrottling) {
                Write-Log "[REG] 4/10 Disabling Windows Power Throttling (profile flag = ON)..."
                $powerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
                if (!(Test-Path $powerPath)) { New-Item -Path $powerPath -Force | Out-Null }
                Backup-RegValue -Path $powerPath -Name "PowerThrottlingOff"
                Set-ItemProperty -Path $powerPath -Name "PowerThrottlingOff" -Value 1 -Type DWord
                Write-Log "       -> Trade-off: may increase power use / background CPU activity."
            } else {
                Write-Log "[SKIP] 4/10 Power Throttling left at Windows default."
            }
        } catch { Write-Log "[ERROR] Step 4: $($_.Exception.Message)" }

        try {
            Set-Progress 68
            if ($script:disableBackgroundApps) {
                Write-Log "[REG] 5/10 Restricting background app activity (profile flag = ON)..."
                $bgApps = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
                if (!(Test-Path $bgApps)) { New-Item -Path $bgApps -Force | Out-Null }
                Backup-RegValue -Path $bgApps -Name "GlobalUserDisabled"
                Set-ItemProperty -Path $bgApps -Name "GlobalUserDisabled" -Value 1 -Type DWord
                Write-Log "       -> Trade-off: Mail/Calendar/Store background sync can stop."
            } else {
                Write-Log "[SKIP] 5/10 Background app restriction is OFF by default."
            }
        } catch { Write-Log "[ERROR] Step 5: $($_.Exception.Message)" }

        try {
            Set-Progress 82
            Write-Log "[CHECK] 6/10 Hibernation remains unchanged by default."
            if ($script:disableHibernation) {
                Write-Log "[CMD] Advanced flag is ON -> disabling Hibernation after backup."
                Backup-HibernateState
                $p = Start-Process cmd -ArgumentList "/c powercfg -h off" -NoNewWindow -Wait -PassThru
                if ($p.ExitCode -ne 0) { throw "powercfg -h off returned exit code $($p.ExitCode)" }
                Write-Log "       -> Trade-off: Hibernate/Fast Startup support is removed until Repair."
            } else {
                Write-Log "       -> Hibernation is not a gaming optimization, so it stays untouched."
            }
        } catch { Write-Log "[ERROR] Step 6: $($_.Exception.Message)" }

        try {
            Set-Progress 90
            Write-Log "[REG] 7/10 Setting CPU quantum to favor the foreground app (Win32PrioritySeparation = 0x26)..."
            $prioPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
            if (!(Test-Path $prioPath)) { New-Item -Path $prioPath -Force | Out-Null }
            Backup-RegValue -Path $prioPath -Name "Win32PrioritySeparation"
            Set-ItemProperty -Path $prioPath -Name "Win32PrioritySeparation" -Value 0x26 -Type DWord
            Write-Log "       -> Gives the active game more CPU time-slices. Fully reversible via Repair High."
        } catch { Write-Log "[ERROR] Step 7: $($_.Exception.Message)" }

        try {
            Set-Progress 95
            Write-Log "[REG] 8/10 Disabling Xbox Game Bar background capture (AppCaptureEnabled = 0)..."
            $capPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
            if (!(Test-Path $capPath)) { New-Item -Path $capPath -Force | Out-Null }
            Backup-RegValue -Path $capPath -Name "AppCaptureEnabled"
            Set-ItemProperty -Path $capPath -Name "AppCaptureEnabled" -Value 0 -Type DWord
            Write-Log "       -> Stops idle capture overhead. Win+G may stop working until Repair (rarely used)."
        } catch { Write-Log "[ERROR] Step 8: $($_.Exception.Message)" }

        try {
            Set-Progress 97
            Write-Log "[REG] 9/10 Enabling 'Optimizations for windowed games' (flip-model presentation)..."
            $dxPref = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
            if (!(Test-Path $dxPref)) { New-Item -Path $dxPref -Force | Out-Null }
            Backup-RegValue -Path $dxPref -Name "DirectXUserGlobalSettings"
            $existingDx = ""
            try { $existingDx = (Get-ItemProperty -Path $dxPref -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings } catch {}
            if (-not $existingDx) { $existingDx = "" }
            $dxFlags = @{}
            foreach ($pair in ($existingDx -split ";")) {
                if ($pair -match "^\s*([^=]+)=(.*)$") { $dxFlags[$matches[1].Trim()] = $matches[2].Trim() }
            }
            $dxFlags["SwapEffectUpgradeEnable"] = "1"
            $dxFlags["VRROptimizeEnable"] = "1"
            $newDx = (($dxFlags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ";") + ";"
            Set-ItemProperty -Path $dxPref -Name "DirectXUserGlobalSettings" -Value $newDx -Type String
            Write-Log "       -> Lower latency + smoother frames for borderless/windowed games. Reversible via Repair."
        } catch { Write-Log "[ERROR] Step 9: $($_.Exception.Message)" }

        try {
            Set-Progress 99
            Write-Log "[CHECK] 10/10 Memory Integrity / VBS is left ON (Windows default)."
            Write-Log "       -> HIGHSENSE never disables Memory Integrity: it would lower kernel security for only a few % FPS."
        } catch { Write-Log "[ERROR] Step 10: $($_.Exception.Message)" }

        # --- (11) Keep kernel + drivers resident in RAM (no paging to disk) ---
        # Safe on machines with enough RAM; helps frametime consistency, never forces lag.
        try {
            Set-Progress 99
            $ramGb = 0
            try { $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB) } catch {}
            if ($ramGb -ge 8) {
                Write-Log "[REG] 11/12 Keeping kernel/drivers resident in RAM (DisablePagingExecutive = 1)..."
                $memMgmt = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
                if (!(Test-Path $memMgmt)) { New-Item -Path $memMgmt -Force | Out-Null }
                Backup-RegValue -Path $memMgmt -Name "DisablePagingExecutive"
                Set-ItemProperty -Path $memMgmt -Name "DisablePagingExecutive" -Value 1 -Type DWord
                Write-Log "       -> Smoother frametimes on RAM-rich systems ($ramGb GB detected). Reversible via Repair."
            } else {
                Write-Log "[SKIP] 11/12 DisablePagingExecutive skipped: less than 8 GB RAM detected."
            }
        } catch { Write-Log "[ERROR] Step 11: $($_.Exception.Message)" }

        # --- (12) Reduce menu/UI show delay so the desktop feels instant while gaming/alt-tabbing ---
        # Pure responsiveness tweak, no CPU/GPU cost, fully reversible.
        try {
            Set-Progress 99
            Write-Log "[REG] 12/12 Reducing UI menu show delay for snappier alt-tab/response..."
            $deskPath = "HKCU:\Control Panel\Desktop"
            Backup-RegValue -Path $deskPath -Name "MenuShowDelay"
            Set-ItemProperty -Path $deskPath -Name "MenuShowDelay" -Value "100" -Type String
            Write-Log "       -> Menus/UI feel more responsive. No performance cost. Reversible via Repair."
        } catch { Write-Log "[ERROR] Step 12: $($_.Exception.Message)" }

        Write-Log "[SUCCESS] System tuning completed."
        Set-Progress 100
        Start-Sleep -Milliseconds 250
        Set-Progress 0

        $tab1Panel.Enabled = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    })
    
    # ---------------------------------------------------------
    # POWERPLAN button - uses built-in Windows High Performance plan
    # ---------------------------------------------------------

$btnPowerplan = (Create-CustomButton $tab1Panel "POWERPLAN" 286 262 240 38 8.5 {
    $tab1Panel.Enabled = $false; $ErrorActionPreference = 'Stop'
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    Write-ModuleInfo `
        -Module "POWERPLAN" `
        -Engine "powercfg.exe" `
        -Scope "Windows power-scheme selection" `
        -Action "Back up current plan; create/activate Ultimate Performance and lock high clocks" `
        -Benefit "Unlocks Ultimate Performance, 100% min CPU, no core parking, aggressive boost, no USB/PCIe power saving" `
        -Tradeoff "Higher power use and heat (fine on desktops, avoid on battery)" `
        -Revert "Repair High restores the previous scheme and deletes the plan HIGHSENSE created"
    Write-Log "[POWERPLAN] Building a high-performance power profile..."
    Set-Progress 2
    New-SafetyRestorePoint

    try {
        Set-Progress 20
        Backup-PowerScheme

        $activeGuid = $null
        $planName = "HighSense"
        $planDesc = "Gaming power profile by HIGHSENSE - high clocks, no core parking. Use Repair to remove."

        # 0) Reuse an existing HighSense plan (prevents duplicate plans piling up on repeat runs).
        try {
            $listRaw = (powercfg -list 2>&1) -join "`n"
            foreach ($ln in ($listRaw -split "`n")) {
                $gm = [regex]::Match($ln, "([a-fA-F0-9\-]{36})")
                $nm = [regex]::Match($ln, "\(([^)]*)\)")
                if ($gm.Success -and $nm.Success -and $nm.Groups[1].Value -match "HighSense") {
                    $activeGuid = $gm.Value
                    Register-CreatedPowerScheme -Guid $activeGuid
                    Write-Log "[POWERPLAN] Reusing existing HighSense plan ($activeGuid); no duplicate created."
                    break
                }
            }
        } catch {}

        # 1) Otherwise duplicate the hidden Ultimate Performance template.
        $ultTemplate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        if (-not $activeGuid) {
            try {
                $dup = powercfg -duplicatescheme $ultTemplate 2>&1
                $mDup = [regex]::Match(($dup -join "`n"), "([a-fA-F0-9\-]{36})")
                if ($mDup.Success) {
                    $activeGuid = $mDup.Value
                    Register-CreatedPowerScheme -Guid $activeGuid
                    Write-Log "[POWERPLAN] Ultimate Performance plan created ($activeGuid)."
                }
            } catch {}
        }

        # 1b) Rename it so it clearly appears as 'HighSense' in Power Options.
        if ($activeGuid -and $activeGuid -ne "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c") {
            powercfg -changename $activeGuid $planName $planDesc 2>&1 | Out-Null
            Write-Log "[POWERPLAN] Plan named '$planName' - look for it in Power Options."
        }

        # 2) Fallback: built-in High Performance (no custom values written).
        if (-not $activeGuid) {
            $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
            $schemeList = powercfg -list 2>&1
            if (($schemeList -join "`n") -notmatch [regex]::Escape($highPerfGuid)) {
                throw "Neither Ultimate nor High Performance Power Plan is available on this system."
            }
            $activeGuid = $highPerfGuid
            Write-Log "[POWERPLAN] Ultimate unavailable; using built-in High Performance instead."
        }

        Set-Progress 45
        powercfg -setactive $activeGuid 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "powercfg -setactive failed for $activeGuid" }

        # Only tune values on a plan HIGHSENSE created, so Repair can delete it cleanly.
        if ($activeGuid -ne "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c") {
            Set-Progress 65
            Write-Log "[POWERPLAN] Locking minimum processor state to 100% (AC + DC)..."
            powercfg -setacvalueindex $activeGuid SUB_PROCESSOR PROCTHROTTLEMIN 100 2>&1 | Out-Null
            powercfg -setdcvalueindex $activeGuid SUB_PROCESSOR PROCTHROTTLEMIN 100 2>&1 | Out-Null

            Write-Log "[POWERPLAN] Disabling USB selective suspend..."
            powercfg -setacvalueindex $activeGuid 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1 | Out-Null

            Write-Log "[POWERPLAN] Disabling PCI Express link power saving (ASPM Off)..."
            powercfg -setacvalueindex $activeGuid SUB_PCIEXPRESS ASPM 0 2>&1 | Out-Null

            Write-Log "[POWERPLAN] Disabling CPU core parking (min cores = 100%)..."
            powercfg -setacvalueindex $activeGuid SUB_PROCESSOR CPMINCORES 100 2>&1 | Out-Null
            powercfg -setdcvalueindex $activeGuid SUB_PROCESSOR CPMINCORES 100 2>&1 | Out-Null

            Write-Log "[POWERPLAN] Setting processor performance boost mode to Aggressive..."
            powercfg -setacvalueindex $activeGuid SUB_PROCESSOR PERFBOOSTMODE 2 2>&1 | Out-Null
            powercfg -setdcvalueindex $activeGuid SUB_PROCESSOR PERFBOOSTMODE 2 2>&1 | Out-Null

            powercfg -setactive $activeGuid 2>&1 | Out-Null
        }

        Set-Progress 85
        Write-Log "[POWERPLAN] High-performance power profile is now active."
        Write-Log "[INFO] On laptops this increases heat/battery drain; use Repair to revert."
        Set-Progress 100
        Start-Sleep -Milliseconds 250
        Set-Progress 0
    } catch {
        Write-Log "[ERROR] Power Plan: $($_.Exception.Message)"
    } finally {
        $tab1Panel.Enabled = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

    # ---------------------------------------------------------
    # NET button (Ultimate Network and Latency Optimization) - shows errors normally
    # ---------------------------------------------------------

$btnNet = (Create-CustomButton $tab1Panel "NET / REG" 24 312 240 38 8.5 {
    $tab1Panel.Enabled = $false; $ErrorActionPreference = 'Stop'
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    Write-ModuleInfo `
        -Module "NET / REG" `
        -Engine "PowerShell NetAdapter + Registry + ipconfig" `
        -Scope "Current network adapters and DNS client cache" `
        -Action "Inspect TCP; disable NIC power-saving/EEE; latency check; optional TCP tuning; flush DNS" `
        -Benefit "More stable link (anti micro-stutter/disconnect) + latency insight; DNS refresh" `
        -Tradeoff "None boost FPS; DNS flush does not lower in-game ping; advanced TCP is OFF"
    Write-Log "[NET / REG] Network module started..."
    Set-Progress 2
    New-SafetyRestorePoint

    try {
        Set-Progress 20
        Write-Log "[NET] Current TCP global configuration:"
        $tcpGlobal = netsh int tcp show global 2>&1
        foreach ($line in @($tcpGlobal)) {
            if ($line -and $line.ToString().Trim()) {
                Write-Log ("       " + $line.ToString().Trim())
            }
        }
    } catch {
        Write-Log "[ERROR] TCP state query: $($_.Exception.Message)"
    }

    try {
        Set-Progress 42
        if ($script:advancedNetTweaks) {
            Write-Log "[REG] Applying advanced TCPNoDelay / TcpAckFrequency / NetworkThrottlingIndex..."
            $mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            Backup-RegValue -Path $mmcssPath -Name "NetworkThrottlingIndex"
            Set-ItemProperty -Path $mmcssPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord

            $interfaces = @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" })
            foreach ($nic in $interfaces) {
                $nicRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($nic.InterfaceGuid)"
                if (Test-Path $nicRegistryPath) {
                    Backup-RegValue -Path $nicRegistryPath -Name "TcpAckFrequency"
                    Set-ItemProperty -Path $nicRegistryPath -Name "TcpAckFrequency" -Value 1 -Type DWord

                    Backup-RegValue -Path $nicRegistryPath -Name "TCPNoDelay"
                    Set-ItemProperty -Path $nicRegistryPath -Name "TCPNoDelay" -Value 1 -Type DWord
                    Write-Log "       -> Tuned adapter: $($nic.Name)"
                }
            }
            Write-Log "[NET] Advanced TCP registry tweaks are experimental and workload-dependent."
        } else {
            Write-Log "[INFO] Advanced TCP registry tweaks are OFF by default."
            Write-Log "       -> Reason: many games use UDP, so TCPNoDelay/TcpAckFrequency are not universal gaming optimizations."
        }
    } catch {
        Write-Log "[ERROR] Advanced TCP step: $($_.Exception.Message)"
    }

    # --- NIC power-saving / Energy Efficient Ethernet (safe, fully reversible) ---
    try {
        Set-Progress 55
        if ($script:optimizeNicPower -and $script:isAdmin) {
            Write-Log "[REG] Disabling NIC power-saving (PnPCapabilities) + Green/EEE where the driver supports it..."
            $classRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
            $upNics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" })
            if ($upNics.Count -eq 0) { Write-Log "       [INFO] No active physical adapter found." }
            foreach ($nic in $upNics) {
                $guid = $nic.InterfaceGuid
                $matchKey = $null
                foreach ($sub in @(Get-ChildItem -Path $classRoot -ErrorAction SilentlyContinue)) {
                    if ($null -ne $matchKey) { break }
                    $inst = $null
                    try { $inst = (Get-ItemProperty -Path $sub.PSPath -Name "NetCfgInstanceId" -ErrorAction SilentlyContinue).NetCfgInstanceId } catch {}
                    if ($inst -and $guid -and ($inst -eq $guid)) { $matchKey = $sub.PSPath }
                }
                if ($null -eq $matchKey) {
                    Write-Log "       [SKIP] $($nic.Name): driver registry key not found."
                    continue
                }
                # 1) Disable 'Allow the computer to turn off this device to save power'
                Backup-RegValue -Path $matchKey -Name "PnPCapabilities"
                Set-ItemProperty -Path $matchKey -Name "PnPCapabilities" -Value 24 -Type DWord
                Write-Log "       -> $($nic.Name): NIC power-down disabled (anti micro-stutter / random disconnect)."
                # 2) Disable Green/EEE ONLY if the driver already exposes the keyword
                foreach ($greenName in @("*EEE", "EEELinkAdvertisement", "EnableGreenEthernet")) {
                    $hasProp = $false
                    try {
                        $props = Get-ItemProperty -Path $matchKey -ErrorAction SilentlyContinue
                        if ($props -and $null -ne $props.PSObject.Properties[$greenName]) { $hasProp = $true }
                    } catch {}
                    if ($hasProp) {
                        Backup-RegValue -Path $matchKey -Name $greenName
                        Set-ItemProperty -Path $matchKey -Name $greenName -Value "0" -Type String
                        Write-Log "       -> $($nic.Name): '$greenName' disabled."
                    }
                }
            }
            Write-Log "       -> Fully reversible via Repair High. Takes effect after adapter restart or reboot."
        } elseif (-not $script:isAdmin) {
            Write-Log "[SKIP] NIC power tuning needs Administrator rights."
        } else {
            Write-Log "[SKIP] NIC power tuning disabled in the profile."
        }
    } catch { Write-Log "[ERROR] NIC power step: $($_.Exception.Message)" }

    # --- Read-only latency / jitter snapshot (changes nothing) ---
    try {
        Set-Progress 70
        Write-Log "[NET] Latency check (read-only, nothing is modified)..."
        $gw = $null
        try { $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop } catch {}
        $targets = @()
        if ($gw -and $gw -ne "0.0.0.0") { $targets += [PSCustomObject]@{ Name = "Gateway ($gw)"; Host = $gw } }
        $targets += [PSCustomObject]@{ Name = "Cloudflare 1.1.1.1"; Host = "1.1.1.1" }
        $targets += [PSCustomObject]@{ Name = "Google 8.8.8.8"; Host = "8.8.8.8" }
        foreach ($t in $targets) {
            try {
                $reply = Test-Connection -ComputerName $t.Host -Count 4 -ErrorAction Stop
                $rtts = @($reply | ForEach-Object { $_.ResponseTime })
                if ($rtts.Count -gt 0) {
                    $avg = [math]::Round(($rtts | Measure-Object -Average).Average, 1)
                    $min = ($rtts | Measure-Object -Minimum).Minimum
                    $max = ($rtts | Measure-Object -Maximum).Maximum
                    $jit = $max - $min
                    $loss = [math]::Round((1 - ($rtts.Count / 4)) * 100)
                    Write-Log "       $($t.Name): avg ${avg}ms | min ${min}ms | max ${max}ms | jitter ${jit}ms | loss ${loss}%"
                } else {
                    Write-Log "       $($t.Name): no reply (100% loss)."
                }
            } catch {
                Write-Log "       $($t.Name): unreachable."
            }
        }
        Write-Log "       -> High jitter/loss = a network problem (WiFi/ISP), not something any FPS tweak can fix."
    } catch { Write-Log "[ERROR] Latency check: $($_.Exception.Message)" }

    try {
        Set-Progress 85
        Write-Log "[CMD] Flushing DNS Resolver Cache (does not change in-game ping)..."
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Log "[NET] PowerShell DNS cache clear completed."
        Start-Process cmd -ArgumentList "/c ipconfig /flushdns" -NoNewWindow -Wait
    } catch {
        Write-Log "[ERROR] DNS flush: $($_.Exception.Message)"
    }

    Write-Log "[SUCCESS] Network module completed."
    Set-Progress 100
    Start-Sleep -Milliseconds 250
    Set-Progress 0

    $tab1Panel.Enabled = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
})

    $btnSystemTweaks = (Create-CustomButton $tab1Panel "SYSTEM TWEAKS" 286 312 240 38 8.5 {
        $tab1Panel.Enabled = $false; $ErrorActionPreference = 'Stop'
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

        Write-ModuleInfo `
            -Module "SYSTEM TWEAKS" `
            -Engine "PowerShell Registry Provider" `
            -Scope "Desktop/UI registry (HKCU) + optional MPO (HKLM)" `
            -Action "Reduce animations/transparency, restrict background apps, gaming DND, cut Start bloat/Widgets, optional MPO/telemetry/NTFS, Startup Manager" `
            -Benefit "Trims UI/background overhead + notification/bloat noise; frees some RAM/CPU; no FPS guarantee" `
            -Tradeoff "UI less animated; notifications/Store sync stop; optional items need Admin; no guaranteed FPS gain"
        Write-Log "[SYSTEM TWEAKS] System/UI tuning started..."
        Set-Progress 2
        New-SafetyRestorePoint

        try {
            Set-Progress 35
            Write-Log "[REG] Reducing selected desktop visual effects..."
            $themePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            if (!(Test-Path $themePath)) { New-Item -Path $themePath -Force | Out-Null }
            Backup-RegValue -Path $themePath -Name "EnableTransparency"
            Set-ItemProperty -Path $themePath -Name "EnableTransparency" -Value 0 -Type DWord

            $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Backup-RegValue -Path $advPath -Name "TaskbarAnimations"
            Set-ItemProperty -Path $advPath -Name "TaskbarAnimations" -Value 0 -Type DWord

            $wmPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
            Backup-RegValue -Path $wmPath -Name "MinAnimate"
            Set-ItemProperty -Path $wmPath -Name "MinAnimate" -Value "0" -Type String

            $desktopPath = "HKCU:\Control Panel\Desktop"
            Backup-RegValue -Path $desktopPath -Name "DragFullWindows"
            Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value "0" -Type String

            $vfxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
            if (!(Test-Path $vfxPath)) { New-Item -Path $vfxPath -Force | Out-Null }
            Backup-RegValue -Path $vfxPath -Name "VisualFXSetting"
            Set-ItemProperty -Path $vfxPath -Name "VisualFXSetting" -Value 2 -Type DWord
            Write-Log "       -> VisualFXSetting = 2 ('Adjust for best performance')."
        } catch { Write-Log "[ERROR] Visual effects: $($_.Exception.Message)" }

        try {
            Set-Progress 55
            Write-Log "[REG] Restricting background apps to free RAM/CPU..."
            $bgPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
            if (!(Test-Path $bgPath)) { New-Item -Path $bgPath -Force | Out-Null }
            Backup-RegValue -Path $bgPath -Name "GlobalUserDisabled"
            Set-ItemProperty -Path $bgPath -Name "GlobalUserDisabled" -Value 1 -Type DWord
            Write-Log "       -> Store apps stop syncing in the background (Mail/Calendar/Store). Reversible."
        } catch { Write-Log "[ERROR] Background apps: $($_.Exception.Message)" }

        try {
            Set-Progress 62
            if ($script:disableMpo) {
                Write-Log "[REG] Disabling Multi-Plane Overlay (MPO) to fix flicker/stutter (optional flag = ON)..."
                $dwmPath = "HKLM:\SOFTWARE\Microsoft\Windows\Dwm"
                if (!(Test-Path $dwmPath)) { New-Item -Path $dwmPath -Force | Out-Null }
                Backup-RegValue -Path $dwmPath -Name "OverlayTestMode"
                Set-ItemProperty -Path $dwmPath -Name "OverlayTestMode" -Value 5 -Type DWord
                Write-Log "       -> Fixes flicker/stutter on some multi-monitor / high-refresh setups. Restart required. May raise GPU load slightly."
            } else {
                Write-Log "[SKIP] Multi-Plane Overlay (MPO) left at Windows default (enable only if you see flicker/stutter)."
            }
        } catch { Write-Log "[ERROR] MPO step: $($_.Exception.Message)" }

        # --- (1) Gaming Do-Not-Disturb: turn off toast notifications ---
        try {
            Set-Progress 64
            Write-Log "[REG] Enabling gaming Do-Not-Disturb (disabling toast notifications)..."
            $pushPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
            if (!(Test-Path $pushPath)) { New-Item -Path $pushPath -Force | Out-Null }
            Backup-RegValue -Path $pushPath -Name "ToastEnabled"
            Set-ItemProperty -Path $pushPath -Name "ToastEnabled" -Value 0 -Type DWord
            Write-Log "       -> Stops pop-ups that steal focus / cause alt-tab stutter. Reversible via Repair."
        } catch { Write-Log "[ERROR] DND step: $($_.Exception.Message)" }

        # --- (2) Cut Start-menu suggestions / tips / promo auto-installs ---
        try {
            Set-Progress 66
            Write-Log "[REG] Disabling suggested content / tips / auto-installed promo apps..."
            $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            if (!(Test-Path $cdmPath)) { New-Item -Path $cdmPath -Force | Out-Null }
            foreach ($cdmName in @(
                "SilentInstalledAppsEnabled",
                "SystemPaneSuggestionsEnabled",
                "PreInstalledAppsEnabled",
                "OemPreInstalledAppsEnabled",
                "SubscribedContent-338388Enabled",
                "SubscribedContent-338389Enabled",
                "SubscribedContent-310093Enabled",
                "SubscribedContent-338393Enabled"
            )) {
                Backup-RegValue -Path $cdmPath -Name $cdmName
                Set-ItemProperty -Path $cdmPath -Name $cdmName -Value 0 -Type DWord
            }
            Write-Log "       -> Cuts Start-menu ads/tips and background promo-app installs. Reversible via Repair."
        } catch { Write-Log "[ERROR] Consumer content step: $($_.Exception.Message)" }

        # --- (3) Hide Widgets / News feed (frees background WebExperience) ---
        try {
            Set-Progress 68
            Write-Log "[REG] Hiding Widgets / News feed from the taskbar..."
            $advWidgets = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            if (!(Test-Path $advWidgets)) { New-Item -Path $advWidgets -Force | Out-Null }
            Backup-RegValue -Path $advWidgets -Name "TaskbarDa"
            Set-ItemProperty -Path $advWidgets -Name "TaskbarDa" -Value 0 -Type DWord
            $feedsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"
            if (Test-Path $feedsPath) {
                Backup-RegValue -Path $feedsPath -Name "ShellFeedsTaskbarViewMode"
                Set-ItemProperty -Path $feedsPath -Name "ShellFeedsTaskbarViewMode" -Value 2 -Type DWord
            }
            Write-Log "       -> Removes the Widgets/News button + its background feed. Reversible via Repair."
        } catch { Write-Log "[ERROR] Widgets/News step: $($_.Exception.Message)" }

        # --- (5) Disable DiagTrack telemetry service (OPTIONAL, flag OFF by default) ---
        try {
            Set-Progress 70
            if ($script:disableTelemetry -and $script:isAdmin) {
                Write-Log "[REG] Disabling Connected User Experiences & Telemetry (DiagTrack) service (flag = ON)..."
                $diagPath = "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack"
                if (Test-Path $diagPath) {
                    Backup-RegValue -Path $diagPath -Name "Start"
                    Set-ItemProperty -Path $diagPath -Name "Start" -Value 4 -Type DWord
                    Write-Log "       -> Trade-off: reduces MS diagnostics. Reboot to apply. Reversible via Repair."
                } else {
                    Write-Log "[SKIP] DiagTrack service key not found."
                }
            } elseif ($script:disableTelemetry -and -not $script:isAdmin) {
                Write-Log "[SKIP] Telemetry disable needs Administrator rights."
            } else {
                Write-Log "[SKIP] Telemetry (DiagTrack) left at Windows default (flag OFF)."
            }
        } catch { Write-Log "[ERROR] Telemetry step: $($_.Exception.Message)" }

        # --- (6) NTFS write-reduction tweaks (OPTIONAL, flag OFF by default) ---
        try {
            Set-Progress 71
            if ($script:ntfsTweaks -and $script:isAdmin) {
                Write-Log "[REG] Applying NTFS write-reduction tweaks (flag = ON)..."
                $fsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
                if (!(Test-Path $fsPath)) { New-Item -Path $fsPath -Force | Out-Null }
                Backup-RegValue -Path $fsPath -Name "NtfsDisableLastAccessUpdate"
                Set-ItemProperty -Path $fsPath -Name "NtfsDisableLastAccessUpdate" -Value 1 -Type DWord
                Backup-RegValue -Path $fsPath -Name "NtfsDisable8dot3NameCreation"
                Set-ItemProperty -Path $fsPath -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord
                Write-Log "       -> Fewer NTFS metadata writes. Minor but safe. Reversible via Repair."
            } elseif ($script:ntfsTweaks -and -not $script:isAdmin) {
                Write-Log "[SKIP] NTFS tweaks need Administrator rights."
            } else {
                Write-Log "[SKIP] NTFS write-reduction left at Windows default (flag OFF)."
            }
        } catch { Write-Log "[ERROR] NTFS step: $($_.Exception.Message)" }

        try {
            Set-Progress 72
            Write-Log "[CHECK] GPU MSI: skipped."
            Write-Log "       -> MSI mode should be controlled by the device driver/installation state, not forced by HIGHSENSE."
        } catch { Write-Log "[ERROR] GPU MSI audit: $($_.Exception.Message)" }

        try {
            Set-Progress 84
            Write-Log "[CHECK] Delivery Optimization bandwidth policy: skipped."
            Write-Log "       -> No deprecated bandwidth registry policy is written by the public release."
        } catch { Write-Log "[ERROR] Delivery Optimization audit: $($_.Exception.Message)" }

        # --- Startup Manager ---
        # Reads only Windows Registry startup entries (Run + StartupApproved\Run).
        # The actual registry value names/commands remain untouched; the UI shows
        # friendly names so users can understand what each entry belongs to.
        try {
            Set-Progress 92
            Write-Log "[STARTUP] Opening startup manager..."

            $enBytes  = [byte[]]@(2,0,0,0,0,0,0,0,0,0,0,0)
            $disBytes = [byte[]]@(3,0,0,0,0,0,0,0,0,0,0,0)

            $runKeys = @(
                @{ Run="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; SU="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; Hive="HKCU" },
                @{ Run="HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"; SU="HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; Hive="HKLM" }
            )

            function Get-StartupFriendlyInfo {
                param([string]$Name, [string]$Command)

                $n = $Name.ToLowerInvariant()

                if ($n -eq "onedrive") {
                    return [PSCustomObject]@{ DisplayName="Microsoft OneDrive"; Description="Cloud file sync and backup client." }
                }
                if ($n -eq "steam") {
                    return [PSCustomObject]@{ DisplayName="Steam"; Description="Game launcher and Steam background services." }
                }
                if ($n -eq "docker desktop") {
                    return [PSCustomObject]@{ DisplayName="Docker Desktop"; Description="Container platform and local Docker engine." }
                }
                if ($n -eq "discord") {
                    return [PSCustomObject]@{ DisplayName="Discord"; Description="Chat and voice application for gaming/community." }
                }
                if ($n -like "microsoftcopilotautolaunch*") {
                    return [PSCustomObject]@{ DisplayName="Microsoft Copilot"; Description="Microsoft Copilot auto-launch entry." }
                }
                if ($n -like "googlechromeautolaunch*") {
                    return [PSCustomObject]@{ DisplayName="Google Chrome"; Description="Chrome auto-launch/background entry." }
                }
                if ($n -eq "robloxplayerbeta") {
                    return [PSCustomObject]@{ DisplayName="Roblox"; Description="Roblox player/launcher startup entry." }
                }
                if ($n -like "microsoftedgeautolaunch*") {
                    return [PSCustomObject]@{ DisplayName="Microsoft Edge"; Description="Edge auto-launch/background entry." }
                }
                if ($n -eq "securityhealth") {
                    return [PSCustomObject]@{ DisplayName="Windows Security"; Description="Windows Security notification component." }
                }
                if ($n -eq "steelseriesgg") {
                    return [PSCustomObject]@{ DisplayName="SteelSeries GG"; Description="SteelSeries device software and companion services." }
                }

                $friendly = $Name -replace '(?i)autolaunch_[0-9a-f]{8,}$',''
                if ([string]::IsNullOrWhiteSpace($friendly)) { $friendly = $Name }

                return [PSCustomObject]@{
                    DisplayName=$friendly
                    Description="Registry startup entry."
                }
            }

            $entries = @()

            foreach ($rk in $runKeys) {
                if (-not (Test-Path $rk.Run)) { continue }

                $props = Get-ItemProperty -Path $rk.Run -ErrorAction SilentlyContinue
                foreach ($p in $props.PSObject.Properties) {
                    if ($p.Name -like "PS*") { continue }

                    $enabled = $true
                    try {
                        if (Test-Path $rk.SU) {
                            $b = (Get-ItemProperty -Path $rk.SU -Name $p.Name -ErrorAction SilentlyContinue).$($p.Name)
                            if ($b -and $b[0] -eq 3) { $enabled = $false }
                        }
                    } catch {}

                    $friendly = Get-StartupFriendlyInfo -Name ([string]$p.Name) -Command ([string]$p.Value)

                    $entries += [PSCustomObject]@{
                        Name        = [string]$p.Name
                        DisplayName = [string]$friendly.DisplayName
                        Description = [string]$friendly.Description
                        Cmd         = [string]$p.Value
                        Hive        = [string]$rk.Hive
                        Run         = [string]$rk.Run
                        SU          = [string]$rk.SU
                        Enabled     = [bool]$enabled
                    }
                }
            }

            if ($entries.Count -eq 0) {
                Write-Log "[STARTUP] No Registry startup entries found."
            } else {
                $suForm = New-Object System.Windows.Forms.Form
                $suForm.Text = "HIGHSENSE - Startup Manager"
                $suForm.Size = New-Object System.Drawing.Size(620, 500)
                $suForm.MinimumSize = New-Object System.Drawing.Size(620, 500)
                $suForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
                $suForm.BackColor = [System.Drawing.Color]::FromArgb(18,18,18)
                $suForm.ForeColor = [System.Drawing.Color]::FromArgb(240,240,240)

                $lbl = New-Object System.Windows.Forms.Label
                $lbl.Text = "Registry Startup Entries"
                $lbl.Location = New-Object System.Drawing.Point(18, 12)
                $lbl.Size = New-Object System.Drawing.Size(580, 22)
                $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                $lbl.ForeColor = [System.Drawing.Color]::FromArgb(235,235,235)
                $suForm.Controls.Add($lbl)

                $subLbl = New-Object System.Windows.Forms.Label
                $subLbl.Text = "Uncheck an item to stop it launching with Windows. Re-check to restore."
                $subLbl.Location = New-Object System.Drawing.Point(18, 35)
                $subLbl.Size = New-Object System.Drawing.Size(580, 20)
                $subLbl.ForeColor = [System.Drawing.Color]::FromArgb(145,145,145)
                $suForm.Controls.Add($subLbl)

                $clb = New-Object System.Windows.Forms.CheckedListBox
                $clb.Location = New-Object System.Drawing.Point(18, 64)
                $clb.Size = New-Object System.Drawing.Size(580, 305)
                $clb.BackColor = [System.Drawing.Color]::FromArgb(26,26,26)
                $clb.ForeColor = [System.Drawing.Color]::FromArgb(235,235,235)
                $clb.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
                $clb.CheckOnClick = $true
                $clb.HorizontalScrollbar = $true
                $clb.IntegralHeight = $false

                for ($i=0; $i -lt $entries.Count; $i++) {
                    $itemText = "{0}  |  {1}  |  {2}" -f $entries[$i].DisplayName, $entries[$i].Hive, $entries[$i].Description
                    [void]$clb.Items.Add($itemText, $entries[$i].Enabled)
                }
                $suForm.Controls.Add($clb)

                $details = New-Object System.Windows.Forms.Label
                $details.Location = New-Object System.Drawing.Point(18, 380)
                $details.Size = New-Object System.Drawing.Size(580, 40)
                $details.ForeColor = [System.Drawing.Color]::FromArgb(135,135,135)
                $details.AutoEllipsis = $true
                $details.Text = "Select an entry to view its Registry path."
                $suForm.Controls.Add($details)

                $clb.Add_SelectedIndexChanged({
                    $i = $clb.SelectedIndex
                    if ($i -ge 0 -and $i -lt $entries.Count) {
                        $details.Text = "Path: {0}   |   Value: {1}" -f $entries[$i].Run, $entries[$i].Name
                    }
                })

                $btnApply = New-Object System.Windows.Forms.Button
                $btnApply.Text = "Apply"
                $btnApply.Location = New-Object System.Drawing.Point(398, 428)
                $btnApply.Size = New-Object System.Drawing.Size(95, 34)
                $btnApply.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
                $btnApply.BackColor = [System.Drawing.Color]::FromArgb(40,40,40)
                $btnApply.ForeColor = [System.Drawing.Color]::White
                $btnApply.Add_Click({
                    for ($i=0; $i -lt $entries.Count; $i++) {
                        $want = $clb.GetItemChecked($i)
                        if ($want -eq $entries[$i].Enabled) { continue }

                        try {
                            if (-not (Test-Path $entries[$i].SU)) {
                                New-Item -Path $entries[$i].SU -Force | Out-Null
                            }

                            $bytes = if ($want) { $enBytes } else { $disBytes }

                            Set-ItemProperty `
                                -Path $entries[$i].SU `
                                -Name $entries[$i].Name `
                                -Value $bytes `
                                -Type Binary `
                                -ErrorAction Stop

                            $entries[$i].Enabled = $want

                            $state = if ($want) { "ENABLED" } else { "DISABLED" }
                            Write-Log "[STARTUP] $($entries[$i].DisplayName) -> $state"
                        } catch {
                            Write-Log "[ERROR] $($entries[$i].DisplayName): $($_.Exception.Message)"
                        }
                    }

                    $suForm.Close()
                })
                $suForm.Controls.Add($btnApply)

                $btnCancelSu = New-Object System.Windows.Forms.Button
                $btnCancelSu.Text = "Close"
                $btnCancelSu.Location = New-Object System.Drawing.Point(503, 428)
                $btnCancelSu.Size = New-Object System.Drawing.Size(95, 34)
                $btnCancelSu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
                $btnCancelSu.BackColor = [System.Drawing.Color]::FromArgb(40,40,40)
                $btnCancelSu.ForeColor = [System.Drawing.Color]::White
                $btnCancelSu.Add_Click({ $suForm.Close() })
                $suForm.Controls.Add($btnCancelSu)

                [void]$suForm.ShowDialog()
                Write-Log "[STARTUP] Closed."
            }
        } catch {
            Write-Log "[ERROR] Startup manager: $($_.Exception.Message)"
        }

        # --- (4) Optional: restart Explorer so visual/taskbar changes apply now ---
        try {
            $restartExp = [System.Windows.Forms.MessageBox]::Show(
                "Apply the visual / taskbar changes now by restarting Windows Explorer?`r`n`r`nThe taskbar will blink for a second. Your open apps are NOT closed.",
                "HIGHSENSE - Apply now?",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($restartExp -eq [System.Windows.Forms.DialogResult]::Yes) {
                Write-Log "[SYSTEM] Restarting Explorer to apply changes..."
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 800
                if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
                    Start-Process explorer.exe
                }
                Write-Log "       -> Explorer restarted."
            } else {
                Write-Log "[SYSTEM] Explorer restart skipped; changes apply after next sign-in."
            }
        } catch { Write-Log "[ERROR] Explorer restart: $($_.Exception.Message)" }

        Write-Log "[SUCCESS] System tuning applied successfully!"
        Set-Progress 100
        Start-Sleep -Milliseconds 250
        Set-Progress 0

        $tab1Panel.Enabled = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    })

    $btnInputlag = (Create-CustomButton $tab1Panel "INPUT / REG" 24 368 502 38 8.5 {
    $tab1Panel.Enabled = $false; $ErrorActionPreference = 'Stop'
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

    Write-ModuleInfo `
        -Module "INPUT / REG" `
        -Engine "PowerShell Registry Provider" `
        -Scope "Current user's mouse settings" `
        -Action "Disable classic pointer acceleration; optional queues OFF" `
        -Benefit "Consistent 1:1 desktop pointer response" `
        -Tradeoff "Pointer feel changes; Raw Input games may ignore it" `
        -Revert "Repair High restores the original Mouse registry values"
    Write-Log "[INPUT / REG] Input latency tuning started..."
    Set-Progress 2
    New-SafetyRestorePoint

    try {
        Set-Progress 42
        Write-Log "[REG] 1/2 Disabling classic Windows mouse acceleration..."
        $mousePath = "HKCU:\Control Panel\Mouse"
        Backup-RegValue -Path $mousePath -Name "MouseSpeed"
        Set-ItemProperty -Path $mousePath -Name "MouseSpeed" -Value "0" -Type String
        Backup-RegValue -Path $mousePath -Name "MouseThreshold1"
        Set-ItemProperty -Path $mousePath -Name "MouseThreshold1" -Value "0" -Type String
        Backup-RegValue -Path $mousePath -Name "MouseThreshold2"
        Set-ItemProperty -Path $mousePath -Name "MouseThreshold2" -Value "0" -Type String
        Backup-RegValue -Path $mousePath -Name "MouseSensitivity"
        Set-ItemProperty -Path $mousePath -Name "MouseSensitivity" -Value "10" -Type String
        Write-Log "       -> Pointer speed set to 6/11 (1:1, no scaling)."
        Write-Log "       -> This affects Windows pointer acceleration; raw-input games may use their own path."
    } catch {
        Write-Log "[ERROR] Mouse acceleration: $($_.Exception.Message)"
    }

    try {
        Set-Progress 70
        if ($script:advancedInputQueues) {
            Write-Log "[REG] 2/2 Applying advanced mouse/keyboard queue sizes = 20..."
            $mousePath2 = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
            if (!(Test-Path $mousePath2)) { New-Item -Path $mousePath2 -Force | Out-Null }
            Backup-RegValue -Path $mousePath2 -Name "MouseDataQueueSize"
            Set-ItemProperty -Path $mousePath2 -Name "MouseDataQueueSize" -Value 20 -Type DWord

            $kbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
            if (!(Test-Path $kbPath)) { New-Item -Path $kbPath -Force | Out-Null }
            Backup-RegValue -Path $kbPath -Name "KeyboardDataQueueSize"
            Set-ItemProperty -Path $kbPath -Name "KeyboardDataQueueSize" -Value 20 -Type DWord
            Write-Log "       -> Requires a reboot/replug in many systems."
        } else {
            Write-Log "[INFO] 2/2 Advanced input queue size edits are OFF by default."
            Write-Log "       -> Reason: these are low-level changes with little evidence of a universal gaming benefit."
        }
    } catch {
        Write-Log "[ERROR] Input queue step: $($_.Exception.Message)"
    }

    Set-Progress 88
    Write-Log "[INFO] USB polling rate (125/500/1000Hz) is controlled by the mouse/driver, not this registry module."
    Write-Log "[INFO] Set polling rate with the mouse vendor software when supported."

    Write-Log "[SUCCESS] Input module completed."
    Set-Progress 100
    Start-Sleep -Milliseconds 250
    Set-Progress 0

    $tab1Panel.Enabled = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
})


    # ===========================================================================
    # Quick Tweak Guide: hover each button for a compact explanation.
    # ===========================================================================
    # Tooltips removed on all category buttons (no hover popups), including Repair High.
    # Tooltips on module category buttons intentionally removed (no hover popups).

    # ===========================================================================
    # Wire each module button to its status dot: green = already applied,
    # dim ring = not applied yet. Clicking Repair High clears them all.
    # ===========================================================================
    $btnCMD.Tag.statusKey          = 'CMD';       $script:moduleButtons['CMD'] = $btnCMD
    $btnPowerplan.Tag.statusKey    = 'POWERPLAN'; $script:moduleButtons['POWERPLAN'] = $btnPowerplan
    $btnNet.Tag.statusKey          = 'NET';       $script:moduleButtons['NET'] = $btnNet
    $btnSystemTweaks.Tag.statusKey = 'SYSTEM';    $script:moduleButtons['SYSTEM'] = $btnSystemTweaks
    $btnInputlag.Tag.statusKey     = 'INPUT';     $script:moduleButtons['INPUT'] = $btnInputlag

    # Category names align to the front (left) of each box, smaller & with breathing room
    foreach ($mb in @($btnCMD, $btnPowerplan, $btnNet, $btnSystemTweaks, $btnInputlag)) {
        $mb.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $mb.Padding = New-Object System.Windows.Forms.Padding(16, 0, 0, 0)
        $mb.Font = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
    }

    $btnCMD.Add_Click({ Set-ModuleStatus 'CMD' 'APPLIED' })
    $btnPowerplan.Add_Click({ Set-ModuleStatus 'POWERPLAN' 'APPLIED' })
    $btnNet.Add_Click({ Set-ModuleStatus 'NET' 'APPLIED' })
    $btnSystemTweaks.Add_Click({ Set-ModuleStatus 'SYSTEM' 'APPLIED' })
    $btnInputlag.Add_Click({ Set-ModuleStatus 'INPUT' 'APPLIED' })
    $btnRepair.Add_Click({ Reset-ModuleStatus })

    foreach ($k in @('CMD','POWERPLAN','NET','SYSTEM','INPUT')) {
        if ($script:moduleButtons.ContainsKey($k)) { $script:moduleButtons[$k].Invalidate() }
    }
    Ensure-PulseTimer

    # If not running as Administrator, disable buttons that write to HKLM to avoid silent failures/errors
    if (-not $script:isAdmin) {
        foreach ($b in @($btnRepair, $btnCMD, $btnPowerplan, $btnNet, $btnSystemTweaks, $btnInputlag)) {
            $b.Enabled = $false
        }
        Write-Log "[WARNING] Not running as Administrator - optimization modules are disabled."
        Write-Log "[WARNING] Close HIGHSENSE and 'Run as administrator' to enable them."
    }

    # --- TAB 2: JUNK CLEANER UI ---
    $cleanerContainer = New-Object System.Windows.Forms.Panel
    $cleanerContainer.Size = New-Object System.Drawing.Size(550, 480)
    $cleanerContainer.Location = New-Object System.Drawing.Point(0, 0)
    $cleanerContainer.BackColor = $bgColor
    $cleanerContainer.Visible = $false
    $containerPanel.Controls.Add($cleanerContainer)
    Set-DoubleBuffered $cleanerContainer

    $txtCleanerLog = New-Object System.Windows.Forms.TextBox
    $txtCleanerLog.Multiline = $true
    $txtCleanerLog.ReadOnly = $true
    $txtCleanerLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $txtCleanerLog.BackColor = [System.Drawing.Color]::FromArgb(22, 22, 22)
    $txtCleanerLog.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $txtCleanerLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
    $txtCleanerLog.Size = New-Object System.Drawing.Size(502, 175)
    $txtCleanerLog.Location = New-Object System.Drawing.Point(24, 10)
    $txtCleanerLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txtCleanerLog.Text = @"
============= JUNK CLEANER =============
[STATUS] Ready to select and clean system garbage.
[INFO] Tick the modules you want to clean below.
========================================
Select categories and click Clean Selected.
"@
    $cleanerContainer.Controls.Add($txtCleanerLog)
    [void](Wrap-GlassCard $txtCleanerLog 14 6 ([System.Drawing.Color]::FromArgb(13, 13, 16)))

    $pCleanerBarBg = New-Object System.Windows.Forms.Panel
    $pCleanerBarBg.Size = New-Object System.Drawing.Size(502, 6)
    $pCleanerBarBg.Location = New-Object System.Drawing.Point(24, 193)
    $pCleanerBarBg.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    Set-RoundedControl $pCleanerBarBg 3
    $cleanerContainer.Controls.Add($pCleanerBarBg)

    $pCleanerBarFill = New-Object System.Windows.Forms.Panel
    $pCleanerBarFill.Size = New-Object System.Drawing.Size(0, 6)
    $pCleanerBarFill.Location = New-Object System.Drawing.Point(0, 0)
    $pCleanerBarFill.BackColor = $progressFillCol
    Set-RoundedControl $pCleanerBarFill 3
    $pCleanerBarBg.Controls.Add($pCleanerBarFill)

    function Set-CleanerProgress($percent) {
        $pCleanerBarFill.Width = [math]::Round(502 * ($percent / 100))
        $pCleanerBarBg.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    }

    function Write-CleanerLog($text) {
        $txtCleanerLog.AppendText("`r`n" + $text)
        $txtCleanerLog.SelectionStart = $txtCleanerLog.TextLength
        $txtCleanerLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    # --- Premium pill toggle switch (replaces plain checkboxes; smooth animated on/off) ---
    # Each toggle is a Panel exposing a .Checked property so the existing cleaner logic
    # (which reads $chkX.Checked) keeps working unchanged.
    function New-ToggleSwitch($parent, $labelText, $x, $y, $checked) {
        $row = New-Object System.Windows.Forms.Panel
        $row.Size = New-Object System.Drawing.Size(502, 26)
        $row.Location = New-Object System.Drawing.Point($x, $y)
        $row.BackColor = $bgColor
        $row.Cursor = [System.Windows.Forms.Cursors]::Hand
        Add-Member -InputObject $row -MemberType NoteProperty -Name Checked -Value ([bool]$checked) -Force
        Add-Member -InputObject $row -MemberType NoteProperty -Name AnimPos -Value $(if ($checked) { 1.0 } else { 0.0 }) -Force

        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $labelText
        $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 8)
        $lbl.ForeColor = $btnText
        $lbl.AutoSize = $false
        $lbl.Size = New-Object System.Drawing.Size(440, 26)
        $lbl.Location = New-Object System.Drawing.Point(60, 0)
        $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $lbl.BackColor = [System.Drawing.Color]::Transparent
        $lbl.Cursor = [System.Windows.Forms.Cursors]::Hand
        $row.Controls.Add($lbl)
        Add-Member -InputObject $row -MemberType NoteProperty -Name Label -Value $lbl -Force

        $row.Add_Paint({
            param($s, $e)
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $p = [double]$s.AnimPos
            $trackX = 0; $trackY = 4; $trackW = 46; $trackH = 18; $rad = $trackH
            $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
            $gp.AddArc($trackX, $trackY, $rad, $rad, 90, 180)
            $gp.AddArc(($trackX + $trackW - $rad), $trackY, $rad, $rad, 270, 180)
            $gp.CloseFigure()
            # track eases from a dark grey (off) into a soft blue gradient (on) - no hard edge
            $c1r = [int](42 + (46  - 42) * $p); $c1g = [int](42 + (104 - 42) * $p); $c1b = [int](42 + (168 - 42) * $p)
            $c2r = [int](42 + (92  - 42) * $p); $c2g = [int](42 + (176 - 42) * $p); $c2b = [int](42 + (248 - 42) * $p)
            $col1 = [System.Drawing.Color]::FromArgb(255, $c1r, $c1g, $c1b)
            $col2 = [System.Drawing.Color]::FromArgb(255, $c2r, $c2g, $c2b)
            $trackRect = New-Object System.Drawing.Rectangle($trackX, ($trackY - 1), $trackW, ($trackH + 2))
            $tb = New-Object System.Drawing.Drawing2D.LinearGradientBrush($trackRect, $col1, $col2, [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
            $g.FillPath($tb, $gp)
            $tb.Dispose()
            # soft blue sheen along the rim when on (premium glow, fades in smoothly)
            if ($p -gt 0.02) {
                $glowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int](70 * $p), 150, 200, 255), [single]1.2)
                $g.DrawPath($glowPen, $gp)
                $glowPen.Dispose()
            }
            $gp.Dispose()
            # knob slides with an eased position; clean and bright, brighter when on
            $knobD = 12
            $knobX = $trackX + 3 + ($trackW - 6 - $knobD) * $p
            $knobY = $trackY + 3
            $kc = [int](170 + 70 * $p)
            if ($kc -gt 255) { $kc = 255 }
            $kb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, $kc, $kc, $kc))
            $g.FillEllipse($kb, [single]$knobX, [single]$knobY, [single]$knobD, [single]$knobD)
            $kb.Dispose()
        })

        $onToggle = {
            if ($this -is [System.Windows.Forms.Label]) { $r = $this.Parent } else { $r = $this }
            $r.Checked = -not $r.Checked
            $target = if ($r.Checked) { 1.0 } else { 0.0 }
            $start = [double]$r.AnimPos
            for ($f = 1; $f -le 10; $f++) {
                $tt = $f / 10.0
                $ease = 1 - [math]::Pow(1 - $tt, 3)
                $r.AnimPos = $start + ($target - $start) * $ease
                $r.Invalidate(); $r.Update()
                Start-Sleep -Milliseconds 11
            }
            $r.AnimPos = $target
            $r.Invalidate()
        }
        $row.Add_Click($onToggle)
        $lbl.Add_Click($onToggle)
        $row.Add_MouseEnter({ $this.Label.ForeColor = [System.Drawing.Color]::White })
        $row.Add_MouseLeave({ $this.Label.ForeColor = $btnText })
        $lbl.Add_MouseEnter({ $this.ForeColor = [System.Drawing.Color]::White })
        $lbl.Add_MouseLeave({ $this.ForeColor = $btnText })

        $parent.Controls.Add($row)
        return $row
    }

    $chkTemp     = New-ToggleSwitch $cleanerContainer "TEMP FILES (Windows & User Temp directories)" 24 206 $true
    $chkShader   = New-ToggleSwitch $cleanerContainer "DIRECTX SHADER CACHE (auto-regenerates)" 24 234 $false
    $chkThumb    = New-ToggleSwitch $cleanerContainer "THUMBNAIL CACHE (Explorer thumbnails)" 24 262 $false
    $chkBrowser  = New-ToggleSwitch $cleanerContainer "BROWSER CACHE (Chrome / Edge / Firefox)" 24 290 $false
    $chkDns      = New-ToggleSwitch $cleanerContainer "FLUSH DNS (Flush DNS Resolver Cache)" 24 318 $false
    $chkPrefetch = New-ToggleSwitch $cleanerContainer "PREFETCH (legacy cache cleanup - optional)" 24 346 $false
    $chkWU       = New-ToggleSwitch $cleanerContainer "WINDOWS UPDATE CACHE (SoftwareDistribution\Download)" 24 374 $false
    $chkRecycle  = New-ToggleSwitch $cleanerContainer "RECYCLE BIN (Empty all deleted files - permanent)" 24 402 $false

    [void](Create-CustomButton $cleanerContainer "Clean Selected" 24 438 502 34 8.5 {
        $cleanerContainer.Enabled = $false
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

      try {
        Write-CleanerLog "[CLEAN] Starting selected cleanup modules..."

        $totalTasks = 0
        if ($chkTemp.Checked) { $totalTasks++ }
        if ($chkPrefetch.Checked) { $totalTasks++ }
        if ($chkRecycle.Checked) { $totalTasks++ }
        if ($chkBrowser.Checked) { $totalTasks++ }
        if ($chkWU.Checked) { $totalTasks++ }
        if ($chkShader.Checked) { $totalTasks++ }
        if ($chkThumb.Checked) { $totalTasks++ }
        if ($chkDns.Checked) { $totalTasks++ }

        if ($totalTasks -eq 0) {
            Write-CleanerLog "[WARNING] No cleanup module selected!"
        } else {
            $progressStep = 100 / $totalTasks
            $currentProg = 0
            $freedBytes = 0.0

            if ($chkTemp.Checked) {
                Write-CleanerLog "[TEMP] Clearing Windows & User Temp directories..."
                try {
                    $freedBytes += Clear-FolderSafe "$env:TEMP"
                    $freedBytes += Clear-FolderSafe "$env:WINDIR\Temp"
                } catch { Write-CleanerLog "[ERROR] Temp: $($_.Exception.Message)" }
                $currentProg += $progressStep
                Set-CleanerProgress ([math]::Round($currentProg))
            }
            if ($chkPrefetch.Checked) {
                Write-CleanerLog "[PREFETCH] Cleaning Windows Prefetch cache..."
                try { $freedBytes += Clear-FolderSafe "$env:WINDIR\Prefetch" } catch { Write-CleanerLog "[ERROR] Prefetch: $($_.Exception.Message)" }
                $currentProg += $progressStep
                Set-CleanerProgress ([math]::Round($currentProg))
            }
            if ($chkRecycle.Checked) {
                Write-CleanerLog "[RECYCLE] Permanently emptying Recycle Bin (selected by user)..."
                try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
                $currentProg += $progressStep
                Set-CleanerProgress ([math]::Round($currentProg))
            }
            if ($chkBrowser.Checked) {
                Write-CleanerLog "[BROWSER] Clearing Chrome/Edge/Firefox cache only (passwords/bookmarks/history untouched)..."
                try {
                    $freedBytes += Clear-FolderSafe "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
                    $freedBytes += Clear-FolderSafe "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
                    $ffBase = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
                    if (Test-Path $ffBase) {
                        Get-ChildItem -Path $ffBase -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            $freedBytes += Clear-FolderSafe (Join-Path $_.FullName "cache2")
                        }
                    }
                } catch { Write-CleanerLog "[ERROR] Browser cache: $($_.Exception.Message)" }
                $currentProg += $progressStep
                Set-CleanerProgress ([math]::Round($currentProg))
            }
            if ($chkWU.Checked) {
                Write-CleanerLog "[WU] Clearing Windows Update download cache..."
                try {
                    if ($script:isAdmin) {
                        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                        Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Milliseconds 400
                    }
                    $freedBytes += Clear-FolderSafe "$env:WINDIR\SoftwareDistribution\Download"
                } catch { Write-CleanerLog "[ERROR] WU cache: $($_.Exception.Message)" }
                finally {
                    if ($script:isAdmin) {
                        Start-Service -Name bits -ErrorAction SilentlyContinue
                        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
                    }
                }
                $currentProg += $progressStep
                Set-CleanerProgress ([math]::Round($currentProg))
            }
            if ($chkShader.Checked) {
                Write-CleanerLog "[SHADER] Clearing DirectX shader cache (regenerates automatically)..."
                try { $freedBytes += Clear-FolderSafe "$env:LOCALAPPDATA\D3DSCache" } catch { Write-CleanerLog "[ERROR] Shader cache: $($_.Exception.Message)" }
                $currentProg += $progressStep
                Set-CleanerProgress ([math]::Round($currentProg))
            }
            if ($chkThumb.Checked) {
                Write-CleanerLog "[THUMB] Clearing Explorer thumbnail/icon cache (locked files are skipped)..."
                try {
                    $explorerCache = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                    if (Test-Path -LiteralPath $explorerCache) {
                        foreach ($mask in @("thumbcache_*.db", "iconcache_*.db")) {
                            Get-ChildItem -LiteralPath $explorerCache -Filter $mask -Force -ErrorAction SilentlyContinue | ForEach-Object {
                                $sz = [double]$_.Length
                                try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop; $freedBytes += $sz } catch {}
                            }
                        }
                    }
                } catch { Write-CleanerLog "[ERROR] Thumbnail cache: $($_.Exception.Message)" }
                $currentProg += $progressStep
                Set-CleanerProgress ([math]::Round($currentProg))
            }
            if ($chkDns.Checked) {
                Write-CleanerLog "[NET] Flushing DNS Resolver Cache..."
                try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch {}
                Set-CleanerProgress 100
            }

            $freedMB = [math]::Round($freedBytes / 1MB, 1)
            if ($freedMB -gt 0) {
                Write-CleanerLog "[SUCCESS] Cleanup complete - approx. $freedMB MB freed."
            } else {
                Write-CleanerLog "[SUCCESS] All selected items cleaned successfully!"
            }
        }

      }
      catch {
          Write-CleanerLog "[ERROR] Cleanup stopped: $($_.Exception.Message)"
      }
      finally {
          Start-Sleep -Milliseconds 300
          Set-CleanerProgress 0
          $cleanerContainer.Enabled = $true
          $form.Cursor = [System.Windows.Forms.Cursors]::Default
      }
    })

    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Size = New-Object System.Drawing.Size(550, 26)
    $statusPanel.Location = New-Object System.Drawing.Point(0, 614)
    $statusPanel.BackColor = $panelColor
    $form.Controls.Add($statusPanel)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = if ($script:isAdmin) { "HIGHSENSE H  |  ADMINISTRATOR MODE" } else { "HIGHSENSE H  |  STANDARD MODE - restart as Admin" }
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
    $lblStatus.ForeColor = $textMuted
    $lblStatus.Location = New-Object System.Drawing.Point(15, 5)
    $lblStatus.AutoSize = $true
    $statusPanel.Controls.Add($lblStatus)

    $script:activeTab = 1
    $btnTab1.Add_Click({
        if ($script:activeTab -eq 1) { return }
        $btnTab1.BackColor = $tabActiveBg
        $btnTab1.ForeColor = $script:tabAccent
        $btnTab2.BackColor = $tabBgColor
        $btnTab2.ForeColor = $textMuted
        # indicator glides in sync with the panel slide (one smooth motion)
        Switch-Panels $cleanerContainer $tab1Panel $false 24
        $script:activeTab = 1
    })

    $btnTab2.Add_Click({
        if ($script:activeTab -eq 2) { return }
        $btnTab2.BackColor = $tabActiveBg
        $btnTab2.ForeColor = $script:tabAccent
        $btnTab1.BackColor = $tabBgColor
        $btnTab1.ForeColor = $textMuted
        # indicator glides in sync with the panel slide (one smooth motion)
        Switch-Panels $tab1Panel $cleanerContainer $true 278
        $script:activeTab = 2
    })

    # Keep the console (with the ASCII logo) visible when launching, then hide
    # it automatically 3 seconds after the GUI appears. The timer runs on the
    # UI message loop that ShowDialog pumps, so it fires reliably.
    $script:consoleHideTimer = New-Object System.Windows.Forms.Timer
    $script:consoleHideTimer.Interval = 3000
    $script:consoleHideTimer.Add_Tick({
        $script:consoleHideTimer.Stop()
        try {
            $hWndConsole = [Highsense.NativeConsole]::GetConsoleWindow()
            if ($hWndConsole -ne [System.IntPtr]::Zero) {
                [void][Highsense.NativeConsole]::ShowWindow($hWndConsole, 0)  # 0 = SW_HIDE
            }
        } catch {}
    })
    $form.Add_Shown({ $script:consoleHideTimer.Start() })

    [void]$form.ShowDialog()
}
catch {
    $err = $_
    $errorMsg = "An error occurred: $($err.Exception.Message)`nLine: $($err.InvocationInfo.ScriptLineNumber)"
    [System.Windows.Forms.MessageBox]::Show($errorMsg, "HIGHSENSE Critical Error", [System.Windows.Forms.MessageBox]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

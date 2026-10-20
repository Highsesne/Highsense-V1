#Requires -Version 5.1
# =============================================================================
# HIGHSCRIPT - Key Page -> Loading Bar -> Success -> Main Dashboard
# Standalone UI foundation extracted from HighX(6).ps1.
# This build contains UI code only. It does not boost FPS or modify Windows.
# IMPORTANT: DEMO activation only. Any non-empty key advances the visual flow;
# this build does not validate a real license or contact a licensing server.
# =============================================================================

param(
    [switch]$HSHiddenElevationLaunch
)

# Relaunch this UI elevated and hide the PowerShell console window.
# The WinForms application window remains visible. If UAC is cancelled,
# stop cleanly instead of continuing in a non-elevated process.
$hsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$hsPrincipal = New-Object Security.Principal.WindowsPrincipal($hsIdentity)
$hsIsAdministrator = $hsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $hsIsAdministrator) {
    $hsScriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($hsScriptPath) -or -not (Test-Path -LiteralPath $hsScriptPath -PathType Leaf)) {
        throw 'HIGHSCRIPT must be launched from its saved .ps1 file so it can request Administrator privileges.'
    }

    $hsPowerShellExe = Join-Path -Path $PSHOME -ChildPath 'powershell.exe'
    $hsLaunchArguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -HSHiddenElevationLaunch' -f $hsScriptPath
    try {
        Start-Process -FilePath $hsPowerShellExe -ArgumentList $hsLaunchArguments -Verb RunAs -WindowStyle Hidden -ErrorAction Stop | Out-Null
    }
    catch {
        # UAC cancellation is not a script error; simply stop this instance.
    }
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

if (-not ('HsNative' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class HsNative {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hwnd, int command);
}
"@
}

# Extra safeguard: hide only the PowerShell window spawned by this script.
# Do not hide a developer's already-open terminal when running interactively.
if ($HSHiddenElevationLaunch) {
    try {
        $hsConsoleHandle = [HsNative]::GetConsoleWindow()
        if ($hsConsoleHandle -ne [IntPtr]::Zero) {
            [void][HsNative]::ShowWindow($hsConsoleHandle, 0) # SW_HIDE
        }
    }
    catch { }
}

$W = 897
# Reduce only the initial Key window height by 15% (672 * 0.85 = 571.2, rounded to 571).
# The Main page keeps its established size; only the Key page's vertical layout is compressed.
$script:keyReferenceHeight = 672
$H = [int][math]::Round($script:keyReferenceHeight * 0.85)
# Landscape dashboard canvas, proportioned to the supplied UI reference.
# The Key page keeps its own 897x571 layout; only the post-activation workspace uses these dimensions.
$script:mainPageWidth = 1110
$script:mainPageHeight = 700
$fam = 'Corbel'
$loginHeaderH = 64.0
$headerCtlSize = 20.0
$headerCtlY = 8.0  # Move window controls closer to the top edge.
$loginCenterX = [single]($W / 2.0)
$script:loginOpticalCenterX = [double]$loginCenterX
$licenseCenterX = [single]($W / 2.0)
$licenseCtlW = 440.0
$licenseCtlH = 47.0
$licenseRect = [System.Drawing.RectangleF]::new(([single]($licenseCenterX - ($licenseCtlW / 2.0))), [single]($H * 0.470), [single]$licenseCtlW, [single]$licenseCtlH)
$activateW = $licenseCtlW
$activateH = 47.0
$activateRect = [System.Drawing.RectangleF]::new(([single]($licenseCenterX - ($activateW / 2.0))), [single]($H * 0.586), [single]$activateW, [single]$activateH)
$script:closeRect = [System.Drawing.RectangleF]::new(($W - 38.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
$script:maxRect = [System.Drawing.RectangleF]::new(($W - 70.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
$script:minRect = [System.Drawing.RectangleF]::new(($W - 70.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
$script:mainActiveSection = 'HOME'
$script:mainHover = ''
$script:mainNavRects = @{}
# The active pill appears directly at the selected row with a restrained spring-pop.
# Its diagonal liquid reveal plays inside the fixed row; Hover remains an independent effect.
$script:mainNavAnim = @{ 'HOME'=1.0; 'FPS TWEAK'=0.0; 'LATENCY'=0.0; 'NET'=0.0; 'CLEAN UP'=0.0 }
$script:mainNavAnimFrom = @{ 'HOME'=1.0; 'FPS TWEAK'=0.0; 'LATENCY'=0.0; 'NET'=0.0; 'CLEAN UP'=0.0 }
$script:mainNavAnimTarget = @{ 'HOME'=1.0; 'FPS TWEAK'=0.0; 'LATENCY'=0.0; 'NET'=0.0; 'CLEAN UP'=0.0 }
$script:mainNavAnimStartTime = 0.0
$script:mainNavAnimDuration = 0.32
$script:mainNavSelectionProgress = 1.0 # normalized timeline for the pop and liquid reveal
$script:mainNavPillFromY = 101.0
$script:mainNavPillToY = 101.0
$script:mainNavPillCurrentY = 101.0
$script:mainNavSelectionAnimating = $false
# Hover has its own spring-like ease; it never changes menu geometry or click targets.
$script:mainNavHoverTargetKey = ''
$script:mainNavHoverAnim = @{ 'HOME'=0.0; 'FPS TWEAK'=0.0; 'LATENCY'=0.0; 'NET'=0.0; 'CLEAN UP'=0.0 }
$script:mainNavHoverAnimFrom = @{ 'HOME'=0.0; 'FPS TWEAK'=0.0; 'LATENCY'=0.0; 'NET'=0.0; 'CLEAN UP'=0.0 }
$script:mainNavHoverAnimTarget = @{ 'HOME'=0.0; 'FPS TWEAK'=0.0; 'LATENCY'=0.0; 'NET'=0.0; 'CLEAN UP'=0.0 }
$script:mainNavHoverAnimStartTime = 0.0
$script:mainNavHoverAnimDuration = 0.27
$script:mainNavHoverAnimating = $false

$script:page = 'license'
$script:sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:lastFrameTime = 0.0
$script:frameDt = 0.016
$script:shinySpeed = 2.7
$script:shinyDelay = 0.0
$script:shinyPhase = 0.0
$script:shinyPaused = $false
$script:hxLightDirty = $true
$script:hxLastRenderPhase = -1.0
$script:lastHighXLightUpdate = -1.0
$script:hover = ''
$script:hoverT = 0.0
$script:btnTarget = 0.0
$script:windowDragging = $false
$script:windowDragStartScreenX = 0
$script:windowDragStartScreenY = 0
$script:windowDragBaseX = 0
$script:windowDragBaseY = 0
$script:licenseDemoMode = $true
$script:licenseText = ''
# Key contents are always masked; only the original value is retained for activation.
$script:licenseFocused = $false
$script:licenseActivated = $false
$script:licenseStatus = 'LICENSE REQUIRED'
$script:licenseStatusKind = 'idle'
$script:licenseCaretVisible = $true
$script:licenseCaretClock = 0.0
$script:licenseFlash = 0.0
$script:loadElapsed = 0.0
$script:loadDuration = 0.95
$script:loadFadeElapsed = 0.0
$script:loadFadeDuration = 0.16
$script:drainElapsed = 0.0
$script:drainDuration = 0.65
$script:checkElapsed = 0.0
$script:checkDuration = 0.94
$script:checkRingDuration = 0.30
$script:checkTickDrawDuration = 0.28
$script:checkTickSettleDuration = 0.07
$script:checkIntroDuration = 0.58
$script:exiting = $false

$form = New-Object System.Windows.Forms.Form
$form.Text = 'HIGHSCRIPT'
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.ClientSize = [System.Drawing.Size]::new($W, $H)
$form.BackColor = [System.Drawing.Color]::FromArgb(8, 8, 9)
$form.ShowInTaskbar = $true
$form.KeyPreview = $true
$form.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic').SetValue($form, $true, $null)
try {
    $cornerPreference = 2
    [void][HsNative]::DwmSetWindowAttribute($form.Handle, 33, [ref]$cornerPreference, 4)
    $noBorder = -2
    [void][HsNative]::DwmSetWindowAttribute($form.Handle, 34, [ref]$noBorder, 4)
    $zeroFrame = 0
    [void][HsNative]::DwmSetWindowAttribute($form.Handle, 37, [ref]$zeroFrame, 4)
} catch { }

# True soft-glow helper: separable multi-pass box blur on alpha only.
# This produces a continuous bloom from a rasterized glyph mask rather than
# stacked hard vector outlines, avoiding the pixel/layer look on High X.
if (-not ('SoftGlowFx' -as [type])) {
Add-Type @"
using System;
public class SoftGlowFx {
    private static int Clamp(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }

    public static void BoxBlurAlpha(int[] pixels, int w, int h, int radius, int passes, double alphaScale) {
        if (pixels == null || w <= 0 || h <= 0 || radius <= 0 || passes <= 0) return;
        int[] tmp = new int[w * h];
        for (int pass = 0; pass < passes; pass++) {
            // Horizontal pass.
            for (int y = 0; y < h; y++) {
                int row = y * w;
                for (int x = 0; x < w; x++) {
                    int sum = 0;
                    int count = 0;
                    int x0 = Clamp(x - radius, 0, w - 1);
                    int x1 = Clamp(x + radius, 0, w - 1);
                    for (int xx = x0; xx <= x1; xx++) {
                        sum += (pixels[row + xx] >> 24) & 0xFF;
                        count++;
                    }
                    int a = (int)(sum / (double)count + 0.5);
                    tmp[row + x] = (a << 24) | (pixels[row + x] & 0x00FFFFFF);
                }
            }
            // Vertical pass.
            for (int y = 0; y < h; y++) {
                int row = y * w;
                for (int x = 0; x < w; x++) {
                    int sum = 0;
                    int count = 0;
                    int y0 = Clamp(y - radius, 0, h - 1);
                    int y1 = Clamp(y + radius, 0, h - 1);
                    for (int yy = y0; yy <= y1; yy++) {
                        sum += (tmp[yy * w + x] >> 24) & 0xFF;
                        count++;
                    }
                    int a = (int)(sum / (double)count + 0.5);
                    if (alphaScale != 1.0) a = (int)(a * alphaScale + 0.5);
                    if (a > 255) a = 255;
                    pixels[row + x] = (a << 24) | (pixels[row + x] & 0x00FFFFFF);
                }
            }
        }
    }
}
"@
}


# Dynamic HIGH X light-field helper.
# The effect is generated from the real anti-aliased glyph mask, then the same
# light field is softened to create the outside bloom. No duplicate glyph layer.
if (-not ('HighXGlyphFxPremiumChrome' -as [type])) {
Add-Type @"
using System;
public class HighXGlyphFxPremiumChrome {
    private static int ClampByte(int v) { return v < 0 ? 0 : (v > 255 ? 255 : v); }

    public static void RenderSpot(
        int[] glyphPixels, int[] bloomSourcePixels, int[] corePixels, int[] bloomPixels,
        int w, int h,
        double spotX, double spotY,
        double coreRx, double coreRy,
        double bloomRx, double bloomRy,
        double strength,
        double angleDegrees
    ) {
        if (glyphPixels == null || bloomSourcePixels == null || corePixels == null || bloomPixels == null || w <= 0 || h <= 0) return;
        double coreInvX = 1.0 / (2.0 * coreRx * coreRx);
        double coreInvY = 1.0 / (2.0 * coreRy * coreRy);
        double bloomInvX = 1.0 / (2.0 * bloomRx * bloomRx);
        double bloomInvY = 1.0 / (2.0 * bloomRy * bloomRy);
        // Rotate the elongated light field so it reads as a diagonal metallic reflection,
        // not a horizontal streak or a collection of detached rays.
        double angle = angleDegrees * Math.PI / 180.0;
        double cosA = Math.Cos(angle);
        double sinA = Math.Sin(angle);

        for (int y = 0; y < h; y++) {
            double py = y + 0.5;
            double dy = py - spotY;
            int row = y * w;
            for (int x = 0; x < w; x++) {
                int idx = row + x;
                int glyphA = (glyphPixels[idx] >> 24) & 0xFF;
                int bloomSourceA = (bloomSourcePixels[idx] >> 24) & 0xFF;
                if (glyphA <= 0 && bloomSourceA <= 0) {
                    corePixels[idx] = 0;
                    bloomPixels[idx] = 0;
                    continue;
                }

                double dx = (x + 0.5) - spotX;
                // Transform pixel deltas into the flare's own coordinate frame.
                double rx = dx * cosA + dy * sinA;
                double ry = -dx * sinA + dy * cosA;
                double coreG = Math.Exp(-(rx * rx * coreInvX + ry * ry * coreInvY));
                double bloomG = Math.Exp(-(rx * rx * bloomInvX + ry * ry * bloomInvY));

                // Core = bright light traveling inside the real glyph mask.
                int ca = ClampByte((int)(glyphA * coreG * strength * 1.05 + 0.5));
                // Bloom uses a pre-blurred copy of the same glyph mask, so its
                // light spills naturally outside the actual letter edges.
                int ba = ClampByte((int)(bloomSourceA * bloomG * strength * 0.86 + 0.5));

                corePixels[idx] = (ca << 24) | 0x00FFFFFF;
                bloomPixels[idx] = (ba << 24) | 0x00FFFFFF;
            }
        }
    }

    public static void CombineLight(int[] corePixels, int[] bloomPixels, int[] dstPixels, int w, int h) {
        if (corePixels == null || bloomPixels == null || dstPixels == null || w <= 0 || h <= 0) return;
        int n = w * h;
        for (int i = 0; i < n; i++) {
            int ca = (corePixels[i] >> 24) & 0xFF;
            int ba = (bloomPixels[i] >> 24) & 0xFF;
            if (ca == 0 && ba == 0) {
                dstPixels[i] = 0;
                continue;
            }
            // Union the same light field into one raster surface. This keeps the
            // inside highlight and outside bloom visually fused instead of reading
            // as two stacked text/effect layers.
            int a = 255 - (int)(((255 - ca) * (long)(255 - ba) + 127) / 255);
            if (a > 255) a = 255;
            dstPixels[i] = (a << 24) | 0x00FFFFFF;
        }
    }
}
"@
}


function Ease-OutCubic([double]$t) {
    if ($t -le 0.0) { return 0.0 }
    if ($t -ge 1.0) { return 1.0 }
    return 1.0 - [math]::Pow(1.0 - $t, 3.0)
}

function Ease-InCubic([double]$t) {
    if ($t -le 0.0) { return 0.0 }
    if ($t -ge 1.0) { return 1.0 }
    return $t * $t * $t
}

function Ease-InOutCubic([double]$t) {
    if ($t -le 0.0) { return 0.0 }
    if ($t -ge 1.0) { return 1.0 }
    if ($t -lt 0.5) {
        return 4.0 * $t * $t * $t
    }
    $u = -2.0 * $t + 2.0
    return 1.0 - ([math]::Pow($u, 3.0) / 2.0)
}

function Draw-LoadingSequence {
    param($graphics)

    $baseCW = [double]$W
    $baseCH = [double]$H
    $cx = [single]($baseCW / 2.0)
    $cy = [single]($baseCH / 2.0 + 5.0)

    if ($script:page -eq 'loading' -or $script:page -eq 'drain') {
        # -----------------------------------------------------------------
        # PREMIUM SILVER LOADING BAR
        # -----------------------------------------------------------------
        $barW = 340.0
        $baseBarH = 5.2
        $barX = ($W - $barW) / 2.0
        $barY = $cy + 9.0

        if ($script:page -eq 'loading') {
            $prog = [math]::Min(1.0, [math]::Max(0.0,
                $script:loadElapsed / $script:loadDuration
            ))
            $fadeT = [math]::Min(1.0, [math]::Max(0.0,
                $script:loadFadeElapsed / $script:loadFadeDuration
            ))
            $appear = Ease-OutCubic $fadeT
            $drawX = [double]$barX
            $drawW = [double]($barW * $prog)
            $drawH = 4.8 + 0.4 * $appear
            $barAlpha = [int](252.0 * $appear)
            $pulseT = $script:sw.Elapsed.TotalSeconds
            $pulse = 0.78 + 0.22 * (0.5 + 0.5 * [math]::Sin($pulseT * 3.55))
        }
        else {
            $drainT = [math]::Min(1.0, [math]::Max(0.0,
                $script:drainElapsed / $script:drainDuration
            ))
            $squeezeT = Ease-InOutCubic $drainT
            $drawX = [double]$barX
            $drawW = [double]($barW * (1.0 - $squeezeT))
            $fadeT = Ease-InCubic $drainT
            $barAlpha = [int](252.0 * (1.0 - $fadeT))
            $drawH = [math]::Max(0.8, $baseBarH * (1.0 - 0.72 * $squeezeT))
            $pulse = 1.0
        }

        if ($drawW -gt 0.8 -and $barAlpha -gt 0) {
            $drawY = $barY + ($baseBarH - $drawH) / 2.0
            $a = $barAlpha / 255.0

            $trackPath = New-CapsulePath ([single]$barX) ([single]($barY - 0.35)) ([single]$barW) ([single]($baseBarH + 0.7))
            $trackBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb([int](6.0 * $a),210,210,220))
            $graphics.FillPath($trackBrush,$trackPath); $trackBrush.Dispose(); $trackPath.Dispose()

            $farPath = New-CapsulePath ([single]$drawX) ([single]($drawY - 11.5)) ([single]$drawW) ([single]28.0)
            $farRect = [System.Drawing.RectangleF]::new([single]$drawX,[single]($drawY - 11.5),[single]$drawW,28.0)
            $farBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($farRect,[System.Drawing.Color]::Transparent,[System.Drawing.Color]::Transparent,90.0)
            $farCb = New-Object System.Drawing.Drawing2D.ColorBlend(5)
            $farCb.Colors = @([System.Drawing.Color]::Transparent,[System.Drawing.Color]::FromArgb([int](5.0*$a*$pulse),196,197,202),[System.Drawing.Color]::FromArgb([int](8.0*$a*$pulse),224,225,230),[System.Drawing.Color]::FromArgb([int](5.0*$a*$pulse),196,197,202),[System.Drawing.Color]::Transparent)
            $farCb.Positions = @([single]0.0,[single]0.22,[single]0.50,[single]0.78,[single]1.0)
            $farBrush.InterpolationColors=$farCb; $graphics.FillPath($farBrush,$farPath); $farBrush.Dispose(); $farPath.Dispose()

            $outerPath = New-CapsulePath ([single]$drawX) ([single]($drawY - 8.0)) ([single]$drawW) 21.0
            $outerRect = [System.Drawing.RectangleF]::new([single]$drawX,[single]($drawY - 8.0),[single]$drawW,21.0)
            $outerBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($outerRect,[System.Drawing.Color]::Transparent,[System.Drawing.Color]::Transparent,90.0)
            $outerCb = New-Object System.Drawing.Drawing2D.ColorBlend(5)
            $outerCb.Colors=@([System.Drawing.Color]::Transparent,[System.Drawing.Color]::FromArgb([int](8.0*$a*$pulse),202,203,208),[System.Drawing.Color]::FromArgb([int](13.0*$a*$pulse),232,233,238),[System.Drawing.Color]::FromArgb([int](8.0*$a*$pulse),202,203,208),[System.Drawing.Color]::Transparent)
            $outerCb.Positions=@([single]0.0,[single]0.20,[single]0.50,[single]0.80,[single]1.0)
            $outerBrush.InterpolationColors=$outerCb; $graphics.FillPath($outerBrush,$outerPath); $outerBrush.Dispose(); $outerPath.Dispose()

            $midPath = New-CapsulePath ([single]$drawX) ([single]($drawY - 5.0)) ([single]$drawW) 15.0
            $midRect = [System.Drawing.RectangleF]::new([single]$drawX,[single]($drawY - 5.0),[single]$drawW,15.0)
            $midBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($midRect,[System.Drawing.Color]::Transparent,[System.Drawing.Color]::Transparent,90.0)
            $midCb = New-Object System.Drawing.Drawing2D.ColorBlend(5)
            $midCb.Colors=@([System.Drawing.Color]::Transparent,[System.Drawing.Color]::FromArgb([int](12.0*$a*$pulse),208,209,214),[System.Drawing.Color]::FromArgb([int](19.0*$a*$pulse),238,239,244),[System.Drawing.Color]::FromArgb([int](12.0*$a*$pulse),208,209,214),[System.Drawing.Color]::Transparent)
            $midCb.Positions=@([single]0.0,[single]0.20,[single]0.50,[single]0.80,[single]1.0)
            $midBrush.InterpolationColors=$midCb; $graphics.FillPath($midBrush,$midPath); $midBrush.Dispose(); $midPath.Dispose()

            $silverBloomPath = New-CapsulePath ([single]$drawX) ([single]($drawY - 2.0)) ([single]$drawW) 9.0
            $silverRect = [System.Drawing.RectangleF]::new([single]$drawX,[single]($drawY - 2.0),[single]$drawW,9.0)
            $silverBloom = [System.Drawing.Drawing2D.LinearGradientBrush]::new($silverRect,[System.Drawing.Color]::Transparent,[System.Drawing.Color]::Transparent,90.0)
            $silverCb = New-Object System.Drawing.Drawing2D.ColorBlend(5)
            $silverCb.Colors=@([System.Drawing.Color]::Transparent,[System.Drawing.Color]::FromArgb([int](12.0*$a*$pulse),236,237,243),[System.Drawing.Color]::FromArgb([int](25.0*$a*$pulse),250,250,255),[System.Drawing.Color]::FromArgb([int](12.0*$a*$pulse),236,237,243),[System.Drawing.Color]::Transparent)
            $silverCb.Positions=@([single]0.0,[single]0.18,[single]0.50,[single]0.82,[single]1.0)
            $silverBloom.InterpolationColors=$silverCb; $graphics.FillPath($silverBloom,$silverBloomPath); $silverBloom.Dispose(); $silverBloomPath.Dispose()

            $fillPath = New-CapsulePath ([single]$drawX) ([single]$drawY) ([single]$drawW) ([single]$drawH)
            $fillRect = [System.Drawing.RectangleF]::new([single]$drawX,[single]$drawY,[single][math]::Max(1.0,$drawW),[single]$drawH)
            $silverBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($fillRect,[System.Drawing.Color]::FromArgb($barAlpha,252,252,255),[System.Drawing.Color]::FromArgb($barAlpha,190,193,199),90.0)
            $graphics.FillPath($silverBrush,$fillPath); $silverBrush.Dispose(); $fillPath.Dispose()

            if ($drawW -gt 8.0) {
                $sheenH=[math]::Min(1.15,$drawH*0.28)
                $sheenPath=New-CapsulePath ([single]($drawX+0.9)) ([single]($drawY+0.58)) ([single][math]::Max(1.5,$drawW-1.8)) ([single]$sheenH)
                $sheenBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb([int](88.0*$a*$pulse),255,255,255))
                $graphics.FillPath($sheenBrush,$sheenPath); $sheenBrush.Dispose(); $sheenPath.Dispose()
            }

            if ($script:page -eq 'loading') {
                $breathPath=New-CapsulePath ([single]$drawX) ([single]($drawY-1.0)) ([single]$drawW) ([single]($drawH+2.0))
                $breathBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb([int](10.0*$a*$pulse),216,217,222))
                $graphics.FillPath($breathBrush,$breathPath); $breathBrush.Dispose(); $breathPath.Dispose()
            }
        }

    }
    elseif ($script:page -eq 'check') {
        # -----------------------------------------------------------------
        # PREMIUM SUCCESS TRANSITION
        # Ring grows 0 -> 360, the tick draws in, and the COMPLETE Success
        # composition (ring + tick) gets a strong spring-pop on entry.
        # After the settle, the same COMPLETE composition softly curls,
        # shrinks, and rotates into its center; the ring never unwinds.
        # -----------------------------------------------------------------
        $elapsed = [double]$script:checkElapsed
        $ringInDuration = [double]$script:checkRingDuration
        $tickStart = $ringInDuration + 0.01
        $tickDrawEnd = $tickStart + [double]$script:checkTickDrawDuration
        $tickSettleEnd = $tickDrawEnd + [double]$script:checkTickSettleDuration
        $ringOutStart = $tickSettleEnd + 0.02
        $ringOutDuration = [math]::Max(0.24, [double]$script:checkDuration - $ringOutStart)

        # Strong but refined spring-pop for the whole Success mark.
        # The tick is inside the same transform, so it expands/settles with
        # the ring instead of feeling like a separate effect.
        $introT = [math]::Min(1.0,[math]::Max(0.0,$elapsed/[double]$script:checkIntroDuration))
        $introDecay = [math]::Exp(-7.0 * $introT)
        $introOsc = [math]::Cos(12.4 * $introT)
        $introScale = 1.0 - (0.72 * $introDecay * $introOsc)
        if ($introScale -lt 0.28) { $introScale = 0.28 }
        $introRotate = 2.7 * $introDecay * [math]::Sin(12.4 * $introT)
        $introNudgeX = 1.7 * $introDecay * [math]::Sin(7.2 * $introT)
        $introNudgeY = -1.1 * $introDecay * [math]::Sin(7.2 * $introT)

        $outT = 0.0
        if ($elapsed -ge $ringOutStart) {
            $outT = [math]::Min(1.0,[math]::Max(0.0,($elapsed-$ringOutStart)/$ringOutDuration))
        }
        $outEase = Ease-InOutCubic $outT
        $outShrink = 1.0 - (0.86 * $outEase) + (0.045 * [math]::Sin($outT * [math]::PI))
        if ($outShrink -lt 0.14) { $outShrink = 0.14 }
        $outRotate = 9.0 * [math]::Sin($outT * [math]::PI)
        $outNudgeX = 2.2 * [math]::Sin($outT * [math]::PI)
        $outNudgeY = 1.4 * [math]::Sin($outT * [math]::PI)

        if ($elapsed -lt $ringInDuration) {
            $ringT = [math]::Min(1.0,[math]::Max(0.0,$elapsed/$ringInDuration))
            $ringEase = Ease-InOutCubic $ringT
            $sweep = [single](360.0*$ringEase)
        } else {
            # Once complete, the ring stays fully closed. The outro is
            # position/scale/rotation only — never a 360 -> 0 sweep.
            $sweep = [single]360.0
        }

        $cxD=[double]$cx; $cyD=[double]$cy; $radius=38.0
        $ringBox=[System.Drawing.RectangleF]::new([single]($cxD-$radius),[single]($cyD-$radius),[single]($radius*2.0),[single]($radius*2.0))

        $successState = $graphics.Save()
        try {
            # Entry: ring + tick share the same spring-pop.
            $graphics.TranslateTransform([single]($cxD + $introNudgeX),[single]($cyD + $introNudgeY))
            $graphics.RotateTransform([single]$introRotate)
            $graphics.ScaleTransform([single]$introScale,[single]$introScale)
            $graphics.TranslateTransform([single](-$cxD),[single](-$cyD))

            # Outro: ring + tick move as ONE premium composition.
            # No 100 -> 0 ring sweep. The complete mark simply curls,
            # shrinks into the center, rotates slightly, and gently fades.
            if ($outT -gt 0.0) {
                $graphics.TranslateTransform([single]($cxD + $outNudgeX),[single]($cyD + $outNudgeY))
                $graphics.RotateTransform([single]$outRotate)
                $graphics.ScaleTransform([single]$outShrink,[single]$outShrink)
                $graphics.TranslateTransform([single](-$cxD),[single](-$cyD))
            }

            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::GammaCorrected

            $fadeFactor = 1.0
            if ($outT -gt 0.0) { $fadeFactor = 1.0 - $outEase }

            # Keep the ring luminous but refined. White is dominant; violet
            # exists only as a very soft outer atmosphere.
            if ($sweep -gt 0.15 -and $fadeFactor -gt 0.0) {
                $violetA = [int](10.0 * $fadeFactor)
                $softA   = [int](20.0 * $fadeFactor)
                $midA    = [int](38.0 * $fadeFactor)
                $coreA   = [int](250.0 * $fadeFactor)

                if ($violetA -gt 0) {
                    $p0=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($violetA,200,201,206),[single]5.8)
                    $p0.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $p0.EndCap=[System.Drawing.Drawing2D.LineCap]::Round
                    Draw-HSSafeArc -Graphics $graphics -Pen $p0 -Bounds $ringBox -StartAngle ([single]-90.0) -SweepAngle $sweep; $p0.Dispose()
                }
                if ($softA -gt 0) {
                    $p1=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($softA,228,231,236),[single]4.4)
                    $p1.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $p1.EndCap=[System.Drawing.Drawing2D.LineCap]::Round
                    Draw-HSSafeArc -Graphics $graphics -Pen $p1 -Bounds $ringBox -StartAngle ([single]-90.0) -SweepAngle $sweep; $p1.Dispose()
                }
                if ($midA -gt 0) {
                    $p2=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($midA,250,250,255),[single]3.0)
                    $p2.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $p2.EndCap=[System.Drawing.Drawing2D.LineCap]::Round
                    Draw-HSSafeArc -Graphics $graphics -Pen $p2 -Bounds $ringBox -StartAngle ([single]-90.0) -SweepAngle $sweep; $p2.Dispose()
                }
                if ($coreA -gt 0) {
                    $p3=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($coreA,244,246,248),[single]2.05)
                    $p3.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $p3.EndCap=[System.Drawing.Drawing2D.LineCap]::Round
                    Draw-HSSafeArc -Graphics $graphics -Pen $p3 -Bounds $ringBox -StartAngle ([single]-90.0) -SweepAngle $sweep; $p3.Dispose()
                }
            }

            # Tick: same draw-in animation as before. During the outro it is
            # carried by the SAME group transform as the ring, so it pops and
            # curls into the center together with the complete Success mark.
            if ($elapsed -ge $tickStart -and $elapsed -lt $script:checkDuration) {
                $tickElapsed=[math]::Max(0.0,$elapsed-$tickStart)
                $drawT=[math]::Min(1.0,[math]::Max(0.0,$tickElapsed/[double]$script:checkTickDrawDuration))
                $settleT=[math]::Min(1.0,[math]::Max(0.0,($tickElapsed-[double]$script:checkTickDrawDuration)/[double]$script:checkTickSettleDuration))
                if ($drawT -gt 0.0) {
                    $firstT=[math]::Min(1.0,[math]::Max(0.0,$drawT/0.46))
                    $secondT=[math]::Min(1.0,[math]::Max(0.0,($drawT-0.30)/0.70))
                    $firstE=Ease-OutCubic $firstT; $secondE=Ease-OutCubic $secondT
                    $tickScale=0.88+0.12*$drawT
                    if ($settleT -gt 0.0) {$tickScale=1.0+(0.035*[math]::Sin($settleT*[math]::PI))}
                    $tickAlpha=[int](255.0*[math]::Min(1.0,$drawT*3.0))
                    $tickAlpha=[int]($tickAlpha * $fadeFactor)
                    $tickWidth=3.0+(0.34*$drawT)
                    if ($settleT -gt 0.0) {$tickWidth=3.18-(0.10*$settleT)}

                    $p0=[System.Drawing.PointF]::new([single]($cxD-15.5*$tickScale),[single]($cyD+0.7*$tickScale))
                    $p1=[System.Drawing.PointF]::new([single]($cxD-5.2*$tickScale),[single]($cyD+11.0*$tickScale))
                    $p2=[System.Drawing.PointF]::new([single]($cxD+17.0*$tickScale),[single]($cyD-14.0*$tickScale))
                    $tickA = [int]($tickAlpha * 0.96)
                    $drawLine = {
                        param($pen)
                        if ($firstE -gt 0.0) {
                            $m1=[System.Drawing.PointF]::new([single]($p0.X+(($p1.X-$p0.X)*$firstE)),[single]($p0.Y+(($p1.Y-$p0.Y)*$firstE)))
                            $graphics.DrawLine($pen,$p0,$m1)
                        }
                        if ($secondE -gt 0.0) {
                            $m2=[System.Drawing.PointF]::new([single]($p1.X+(($p2.X-$p1.X)*$secondE)),[single]($p1.Y+(($p2.Y-$p1.Y)*$secondE)))
                            $graphics.DrawLine($pen,$p1,$m2)
                        }
                    }

                    $tp0=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb([int](8.0*($tickA/255.0)),202,203,208),[single]([math]::Max(4.6,$tickWidth+2.6)))
                    $tp0.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $tp0.EndCap=[System.Drawing.Drawing2D.LineCap]::Round; $tp0.LineJoin=[System.Drawing.Drawing2D.LineJoin]::Round
                    & $drawLine $tp0; $tp0.Dispose()
                    $tp1=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb([int](14.0*($tickA/255.0)),226,229,234),[single]([math]::Max(3.6,$tickWidth+1.15)))
                    $tp1.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $tp1.EndCap=[System.Drawing.Drawing2D.LineCap]::Round; $tp1.LineJoin=[System.Drawing.Drawing2D.LineJoin]::Round
                    & $drawLine $tp1; $tp1.Dispose()
                    $tickPen=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($tickA,246,248,250),[single]([math]::Max(2.0,$tickWidth-0.55)))
                    $tickPen.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $tickPen.EndCap=[System.Drawing.Drawing2D.LineCap]::Round; $tickPen.LineJoin=[System.Drawing.Drawing2D.LineJoin]::Round
                    & $drawLine $tickPen; $tickPen.Dispose()
                }
            }
        }
        finally {
            $graphics.Restore($successState)
        }
    }
}

function Draw-GlassPath {
    param(
        $graphics,
        $path,
        [double]$alphaScale = 1.0,
        [double]$coreWidth = 0.68
    )
    if ($null -eq $path) { return }
    # Same faint glass-gray treatment for rounded UI outlines (Start, cards, etc.).
    $scale = [math]::Max(0.0, [math]::Min(1.0, $alphaScale))
    $pWide = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb([int](7*$scale), 242, 244, 247), [single]4.4)
    $pMid  = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb([int](14*$scale), 205, 208, 213), [single]2.0)
    $pCore = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb([int](86*$scale), 166, 170, 176), [single]$coreWidth)
    foreach ($p in @($pWide,$pMid,$pCore)) {
        $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $p.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    }
    $graphics.DrawPath($pWide, $path)
    $graphics.DrawPath($pMid,  $path)
    $graphics.DrawPath($pCore, $path)
    $pWide.Dispose(); $pMid.Dispose(); $pCore.Dispose()
}

function New-CapsulePath([single]$x, [single]$y, [single]$w, [single]$h) {
    $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $p.AddArc($x, $y, $h, $h, 90, 180)
    $p.AddArc(($x + $w - $h), $y, $h, $h, 270, 180)
    $p.CloseFigure()
    return $p
}

function New-RoundedRectPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$radius = 8.0) {
    $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $r = [single][math]::Max(1.0, [math]::Min([double]$radius, [math]::Min([double]($h / 2.0), [double]($w / 2.0))))
    $d = [single](2.0 * $r)
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc([single]($x + $w - $d), $y, $d, $d, 270, 90)
    $p.AddArc([single]($x + $w - $d), [single]($y + $h - $d), $d, $d, 0, 90)
    $p.AddArc($x, [single]($y + $h - $d), $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Draw-TrackedCenteredText {
    param(
        $graphics,
        [string]$text,
        [System.Drawing.Font]$font,
        [System.Drawing.Brush]$brush,
        [double]$centerX,
        [double]$centerY,
        [double]$tracking=2.8
    )
    if ([string]::IsNullOrEmpty($text)) { return }

    # Do not merge glyphs with GraphicsPath.AddPath here.
    # Some GDI+ builds used by Windows PowerShell 5.1 can throw
    # "Parameter is not valid" during AddPath on transient glyph paths.
    # Drawing each already-built glyph separately keeps the typography
    # crisp, tracked and visually centered without that failure mode.
    $items = @()
    $minX = [double]::PositiveInfinity
    $minY = [double]::PositiveInfinity
    $maxX = [double]::NegativeInfinity
    $maxY = [double]::NegativeInfinity
    $cursor = 0.0

    foreach($ch in $text.ToCharArray()){
        # Spaces need their real advance width. A space has almost no visible
        # path bounds, so using GetBounds().Right would collapse "X Start".
        if ([char]::IsWhiteSpace($ch)) {
            $spaceW = [double]$graphics.MeasureString(
                [string]$ch,
                $font,
                10000,
                [System.Drawing.StringFormat]::GenericTypographic
            ).Width
            # Add a refined word gap on top of the font's native space width.
            # This makes "X Start" read as two distinct words rather than XStart.
            $cursor += $spaceW + ([double]$tracking * 1.65)
            continue
        }

        $glyph = [System.Drawing.Drawing2D.GraphicsPath]::new()
        try {
            $glyph.AddString(
                [string]$ch,
                $font.FontFamily,
                [int]$font.Style,
                [single]$font.Size,
                ([System.Drawing.PointF]::new([single]$cursor,0)),
                [System.Drawing.StringFormat]::GenericTypographic
            )

            $gb = $glyph.GetBounds()
            $shift = New-Object System.Drawing.Drawing2D.Matrix
            try {
                $shift.Translate([single]($cursor - $gb.X), 0.0)
                $glyph.Transform($shift)
            } finally {
                $shift.Dispose()
            }

            $placed = $glyph.GetBounds()
            $items += ,@($glyph, [double]$placed.X, [double]$placed.Right)
            if ($placed.X -lt $minX) { $minX = [double]$placed.X }
            if ($placed.Y -lt $minY) { $minY = [double]$placed.Y }
            if ($placed.Right -gt $maxX) { $maxX = [double]$placed.Right }
            if ($placed.Bottom -gt $maxY) { $maxY = [double]$placed.Bottom }

            $cursor = [double]$placed.Right + [double]$tracking
        }
        catch {
            $glyph.Dispose()
            throw
        }
    }

    if ($items.Count -eq 0) { return }

    $dx = [double]$centerX - (($minX + $maxX) / 2.0)
    $dy = [double]$centerY - (($minY + $maxY) / 2.0)

    foreach($item in $items) {
        $glyph = $item[0]
        $move = New-Object System.Drawing.Drawing2D.Matrix
        try {
            $move.Translate([single]$dx,[single]$dy)
            $glyph.Transform($move)
            $graphics.FillPath($brush,$glyph)
        }
        finally {
            $move.Dispose()
            $glyph.Dispose()
        }
    }
}

#  LOGIN BACKGROUND : React Bits LightPillar-style renderer
#  Active setting: intensity 0.8 / rotationSpeed 0.6 / glowAmount 0.001 / width 1.3 / height 0.3 / rotation 56 / interactive false / mixBlendMode normal
#  Presentation view widened (1.22x) so the pillar reads smaller/farther away without changing the shader quality.
#  The legacy Login background renderer is intentionally removed.  The login
#  surface is only the black base + this LightPillar field + the existing UI.
#
#  Supplied settings:
#    topColor="#000000"
#    bottomColor="#ffffff"
#    intensity=0.8
#    rotationSpeed=0.6
#    glowAmount=0.001
#    pillarWidth=1.3
#    pillarHeight=0.3
#    noiseIntensity=0
#    pillarRotation=56
#    mixBlendMode="normal"
#    interactive=false
#    mixBlendMode="normal"
#
#  The render engine uses the same ray-march equations as the supplied
#  LightPillar shader, but runs on a background thread so the WinForms UI and
#  the HIGH X animation stay on the UI thread.
# -----------------------------------------------------------------------------

if (-not ('LightPillarGpuV5' -as [type])) {
# PowerShell 5.1 does not automatically pass the WinForms assembly to Add-Type.
# The LightPillar GPU host uses NativeWindow/CreateParams, so reference both
# WinForms and Drawing explicitly during compilation.
$lpFormsAssembly = [System.Windows.Forms.Form].Assembly.Location
$lpDrawingAssembly = [System.Drawing.Bitmap].Assembly.Location
Add-Type -ReferencedAssemblies @($lpFormsAssembly, $lpDrawingAssembly) @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

public sealed class LightPillarGpuV5 : IDisposable
{
    private const int PFD_DRAW_TO_WINDOW = 0x00000004;
    private const int PFD_SUPPORT_OPENGL = 0x00000020;
    private const byte PFD_TYPE_RGBA = 0;
    private const byte PFD_MAIN_PLANE = 0;

    private const uint GL_COLOR_BUFFER_BIT = 0x00004000;
    private const uint GL_QUADS = 0x0007;
    private const uint GL_BGRA = 0x80E1;
    private const uint GL_UNSIGNED_BYTE = 0x1401;
    private const uint GL_PACK_ALIGNMENT = 0x0D05;
    private const uint GL_DEPTH_TEST = 0x0B71;
    private const uint GL_BLEND = 0x0BE2;
    private const uint GL_VERTEX_SHADER = 0x8B31;
    private const uint GL_FRAGMENT_SHADER = 0x8B30;
    private const uint GL_COMPILE_STATUS = 0x8B81;
    private const uint GL_LINK_STATUS = 0x8B82;
    private const uint GL_INFO_LOG_LENGTH = 0x8B84;

    [StructLayout(LayoutKind.Sequential)]
    private struct PIXELFORMATDESCRIPTOR
    {
        public ushort nSize;
        public ushort nVersion;
        public uint dwFlags;
        public byte iPixelType;
        public byte cColorBits;
        public byte cRedBits;
        public byte cRedShift;
        public byte cGreenBits;
        public byte cGreenShift;
        public byte cBlueBits;
        public byte cBlueShift;
        public byte cAlphaBits;
        public byte cAlphaShift;
        public byte cAccumBits;
        public byte cAccumRedBits;
        public byte cAccumGreenBits;
        public byte cAccumBlueBits;
        public byte cAccumAlphaBits;
        public byte cDepthBits;
        public byte cStencilBits;
        public byte cAuxBuffers;
        public byte iLayerType;
        public byte bReserved;
        public uint dwLayerMask;
        public uint dwVisibleMask;
        public uint dwDamageMask;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("gdi32.dll")] private static extern int ChoosePixelFormat(IntPtr hdc, ref PIXELFORMATDESCRIPTOR pfd);
    [DllImport("gdi32.dll")] private static extern bool SetPixelFormat(IntPtr hdc, int format, ref PIXELFORMATDESCRIPTOR pfd);
    [DllImport("opengl32.dll")] private static extern IntPtr wglCreateContext(IntPtr hdc);
    [DllImport("opengl32.dll")] private static extern bool wglDeleteContext(IntPtr hglrc);
    [DllImport("opengl32.dll")] private static extern bool wglMakeCurrent(IntPtr hdc, IntPtr hglrc);
    [DllImport("opengl32.dll")] private static extern IntPtr wglGetProcAddress(string name);
    [DllImport("opengl32.dll")] private static extern void glViewport(int x, int y, int width, int height);
    [DllImport("opengl32.dll")] private static extern void glClearColor(float r, float g, float b, float a);
    [DllImport("opengl32.dll")] private static extern void glClear(uint mask);
    [DllImport("opengl32.dll")] private static extern void glDisable(uint cap);
    [DllImport("opengl32.dll")] private static extern void glPixelStorei(uint pname, int param);
    [DllImport("opengl32.dll")] private static extern void glBegin(uint mode);
    [DllImport("opengl32.dll")] private static extern void glEnd();
    [DllImport("opengl32.dll")] private static extern void glVertex2f(float x, float y);
    [DllImport("opengl32.dll")] private static extern void glFlush();
    [DllImport("opengl32.dll")] private static extern void glReadPixels(int x, int y, int width, int height, uint format, uint type, IntPtr pixels);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate uint glCreateShader_t(uint type);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glShaderSource_t(uint shader, int count, IntPtr strings, IntPtr lengths);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glCompileShader_t(uint shader);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glGetShaderiv_t(uint shader, uint pname, out int value);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glGetShaderInfoLog_t(uint shader, int maxLength, out int length, StringBuilder infoLog);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate uint glCreateProgram_t();
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glAttachShader_t(uint program, uint shader);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glLinkProgram_t(uint program);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glGetProgramiv_t(uint program, uint pname, out int value);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glGetProgramInfoLog_t(uint program, int maxLength, out int length, StringBuilder infoLog);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glUseProgram_t(uint program);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate int glGetUniformLocation_t(uint program, string name);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glUniform1f_t(int location, float v0);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glUniform2f_t(int location, float v0, float v1);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glUniform3f_t(int location, float v0, float v1, float v2);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glDeleteShader_t(uint shader);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] private delegate void glDeleteProgram_t(uint program);

    private glCreateShader_t glCreateShader;
    private glShaderSource_t glShaderSource;
    private glCompileShader_t glCompileShader;
    private glGetShaderiv_t glGetShaderiv;
    private glGetShaderInfoLog_t glGetShaderInfoLog;
    private glCreateProgram_t glCreateProgram;
    private glAttachShader_t glAttachShader;
    private glLinkProgram_t glLinkProgram;
    private glGetProgramiv_t glGetProgramiv;
    private glGetProgramInfoLog_t glGetProgramInfoLog;
    private glUseProgram_t glUseProgram;
    private glGetUniformLocation_t glGetUniformLocation;
    private glUniform1f_t glUniform1f;
    private glUniform2f_t glUniform2f;
    private glUniform3f_t glUniform3f;
    private glDeleteShader_t glDeleteShader;
    private glDeleteProgram_t glDeleteProgram;

    private const string VertexShaderSource = @"
#version 120
varying vec2 vUv;
void main() {
    vUv = gl_Vertex.xy * 0.5 + 0.5;
    gl_Position = gl_Vertex;
}
";

    private const string FragmentShaderSource = @"
#version 120
varying vec2 vUv;
uniform float uTime;
uniform vec2 uResolution;
uniform vec3 uTopColor;
uniform vec3 uBottomColor;
uniform float uIntensity;
uniform float uGlowAmount;
uniform float uPillarWidth;
uniform float uPillarHeight;
uniform float uNoiseIntensity;
uniform float uInteractive;
uniform vec2 uMouse;
uniform float uRotCos;
uniform float uRotSin;
uniform float uPillarRotCos;
uniform float uPillarRotSin;
uniform float uViewScale;

const int MAX_ITER = 80;
const int WAVE_ITER = 4;

float softTanh(float x) {
    x = clamp(x, -20.0, 20.0);
    float e = exp(2.0 * x);
    return (e - 1.0) / (e + 1.0);
}

float hashNoise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 uv = (vUv * 2.0 - 1.0) * vec2(uResolution.x / uResolution.y, 1.0);
    // Wider camera field-of-view: keeps the same shader/detail but makes the pillar
    // feel farther away and less zoomed-in inside the Login surface.
    uv *= uViewScale;
    uv = vec2(
        uPillarRotCos * uv.x - uPillarRotSin * uv.y,
        uPillarRotSin * uv.x + uPillarRotCos * uv.y
    );

    vec3 ro = vec3(0.0, 0.0, -10.0);
    vec3 rd = normalize(vec3(uv, 1.0));

    float rotC = uRotCos;
    float rotS = uRotSin;
    if (uInteractive > 0.5 && (abs(uMouse.x) > 0.001 || abs(uMouse.y) > 0.001)) {
        float a = uMouse.x * 6.28318531;
        rotC = cos(a);
        rotS = sin(a);
    }

    vec3 col = vec3(0.0);
    float t = 0.1;

    for (int i = 0; i < MAX_ITER; i++) {
        vec3 p = ro + rd * t;
        p.xz = vec2(
            rotC * p.x - rotS * p.z,
            rotS * p.x + rotC * p.z
        );

        vec3 q = p;
        q.y = p.y * uPillarHeight + uTime;

        float freq = 1.0;
        float amp = 1.0;
        for (int j = 0; j < WAVE_ITER; j++) {
            q.xz = vec2(
                cos(0.4) * q.x - sin(0.4) * q.z,
                sin(0.4) * q.x + cos(0.4) * q.z
            );
            q += cos(q.zxy * freq - uTime * float(j) * 2.0) * amp;
            freq *= 2.0;
            amp *= 0.5;
        }

        float d = length(cos(q.xz)) - 0.2;
        float bound = length(p.xz) - uPillarWidth;
        float k = 4.0;
        float h = max(k - abs(d - bound), 0.0);
        d = max(d, bound) + h * h * 0.0625 / k;
        d = abs(d) * 0.15 + 0.01;

        float grad = clamp((15.0 - p.y) / 30.0, 0.0, 1.0);
        col += mix(uBottomColor, uTopColor, grad) / d;

        t += d;
        if (t > 50.0) break;
    }

    float widthNorm = max(uPillarWidth / 3.0, 0.0001);
    col = vec3(
        softTanh(col.r * uGlowAmount / widthNorm),
        softTanh(col.g * uGlowAmount / widthNorm),
        softTanh(col.b * uGlowAmount / widthNorm)
    );

    float noise = hashNoise(gl_FragCoord.xy) / 15.0 * uNoiseIntensity;
    col -= vec3(noise);

    col = clamp(col * uIntensity, 0.0, 1.0);
    gl_FragColor = vec4(col, 1.0);
}
";

    private int width;
    private int height;
    private int[] front;
    private int[] back;
    private readonly object sync = new object();
    private volatile bool running;
    private Thread worker;
    private bool frameReady;

    private NativeWindow host;
    private IntPtr hdc;
    private IntPtr hglrc;
    private uint program;
    private IntPtr readback;
    private int readbackBytes;
    private int[] rawPixels;

    private int uTime;
    private int uResolution;
    private int uTopColor;
    private int uBottomColor;
    private int uIntensity;
    private int uGlowAmount;
    private int uPillarWidth;
    private int uPillarHeight;
    private int uNoiseIntensity;
    private int uInteractive;
    private int uMouse;
    private int uRotCos;
    private int uRotSin;
    private int uPillarRotCos;
    private int uPillarRotSin;
    private int uViewScale;

    private double intensity = 1.1;
    private double rotationSpeed = 0.6;
    private double glowAmount = 0.001;
    private double pillarWidth = 1.3;
    private double pillarHeight = 0.3;
    private double noiseIntensity = 0.0;
    private double pillarRotationRad = 56.0 * Math.PI / 180.0;
    private bool interactive = false;
    private double mouseX = 0.0;
    private double mouseY = 0.0;
    // Presentation-only camera scale. 1.35 widens the field without changing
    // the LightPillar prop values themselves.
    private double viewScale = 1.22;

    public LightPillarGpuV5() {
        width = 1;
        height = 1;
        front = new int[1];
        back = new int[1];
    }

    public void Configure(int w, int h, double i, double rs, double ga, double pw, double ph, double ni, double pr, bool inter) {
        width = Math.Max(1, w);
        height = Math.Max(1, h);
        intensity = i;
        rotationSpeed = rs;
        glowAmount = ga;
        pillarWidth = pw;
        pillarHeight = ph;
        noiseIntensity = ni;
        pillarRotationRad = pr * Math.PI / 180.0;
        interactive = inter;
        lock (sync) {
            front = new int[width * height];
            back = new int[width * height];
            frameReady = false;
        }
    }

    public void SetMouse(double x, double y) {
        if (x < -1.0) x = -1.0;
        if (x > 1.0) x = 1.0;
        if (y < -1.0) y = -1.0;
        if (y > 1.0) y = 1.0;
        mouseX = x;
        mouseY = y;
    }

    private T LoadProc<T>(string name) where T : class {
        IntPtr ptr = wglGetProcAddress(name);
        if (ptr == IntPtr.Zero || ptr == new IntPtr(1) || ptr == new IntPtr(2) || ptr == new IntPtr(3) || ptr == new IntPtr(-1)) {
            throw new InvalidOperationException("OpenGL function not available: " + name);
        }
        return Marshal.GetDelegateForFunctionPointer(ptr, typeof(T)) as T;
    }

    private uint Compile(uint type, string source) {
        uint shader = glCreateShader(type);
        byte[] bytes = Encoding.ASCII.GetBytes(source + "\0");
        IntPtr srcMem = Marshal.AllocHGlobal(bytes.Length);
        IntPtr ptrMem = Marshal.AllocHGlobal(IntPtr.Size);
        try {
            Marshal.Copy(bytes, 0, srcMem, bytes.Length);
            Marshal.WriteIntPtr(ptrMem, srcMem);
            glShaderSource(shader, 1, ptrMem, IntPtr.Zero);
            glCompileShader(shader);
            int ok;
            glGetShaderiv(shader, GL_COMPILE_STATUS, out ok);
            if (ok == 0) {
                int len;
                glGetShaderiv(shader, GL_INFO_LOG_LENGTH, out len);
                StringBuilder sb = new StringBuilder(Math.Max(1, len));
                int outLen;
                glGetShaderInfoLog(shader, sb.Capacity, out outLen, sb);
                throw new InvalidOperationException("LightPillar shader compile failed: " + sb.ToString());
            }
            return shader;
        }
        finally {
            Marshal.FreeHGlobal(srcMem);
            Marshal.FreeHGlobal(ptrMem);
        }
    }

    private void InitGl() {
        host = new NativeWindow();
        CreateParams cp = new CreateParams();
        cp.Caption = "HighX LightPillar GPU Surface";
        cp.Style = unchecked((int)0x80000000); // WS_POPUP
        cp.ExStyle = 0x00000080;                // WS_EX_TOOLWINDOW
        cp.X = 0;
        cp.Y = 0;
        cp.Width = width;
        cp.Height = height;
        host.CreateHandle(cp);

        hdc = GetDC(host.Handle);
        if (hdc == IntPtr.Zero) throw new InvalidOperationException("GetDC failed");

        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR();
        pfd.nSize = (ushort)Marshal.SizeOf(typeof(PIXELFORMATDESCRIPTOR));
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 32;
        pfd.cAlphaBits = 8;
        pfd.iLayerType = PFD_MAIN_PLANE;

        int pf = ChoosePixelFormat(hdc, ref pfd);
        if (pf == 0 || !SetPixelFormat(hdc, pf, ref pfd)) throw new InvalidOperationException("SetPixelFormat failed");

        hglrc = wglCreateContext(hdc);
        if (hglrc == IntPtr.Zero || !wglMakeCurrent(hdc, hglrc)) throw new InvalidOperationException("OpenGL context creation failed");

        glCreateShader = LoadProc<glCreateShader_t>("glCreateShader");
        glShaderSource = LoadProc<glShaderSource_t>("glShaderSource");
        glCompileShader = LoadProc<glCompileShader_t>("glCompileShader");
        glGetShaderiv = LoadProc<glGetShaderiv_t>("glGetShaderiv");
        glGetShaderInfoLog = LoadProc<glGetShaderInfoLog_t>("glGetShaderInfoLog");
        glCreateProgram = LoadProc<glCreateProgram_t>("glCreateProgram");
        glAttachShader = LoadProc<glAttachShader_t>("glAttachShader");
        glLinkProgram = LoadProc<glLinkProgram_t>("glLinkProgram");
        glGetProgramiv = LoadProc<glGetProgramiv_t>("glGetProgramiv");
        glGetProgramInfoLog = LoadProc<glGetProgramInfoLog_t>("glGetProgramInfoLog");
        glUseProgram = LoadProc<glUseProgram_t>("glUseProgram");
        glGetUniformLocation = LoadProc<glGetUniformLocation_t>("glGetUniformLocation");
        glUniform1f = LoadProc<glUniform1f_t>("glUniform1f");
        glUniform2f = LoadProc<glUniform2f_t>("glUniform2f");
        glUniform3f = LoadProc<glUniform3f_t>("glUniform3f");
        glDeleteShader = LoadProc<glDeleteShader_t>("glDeleteShader");
        glDeleteProgram = LoadProc<glDeleteProgram_t>("glDeleteProgram");

        uint vs = Compile(GL_VERTEX_SHADER, VertexShaderSource);
        uint fs = Compile(GL_FRAGMENT_SHADER, FragmentShaderSource);
        program = glCreateProgram();
        glAttachShader(program, vs);
        glAttachShader(program, fs);
        glLinkProgram(program);
        int linked;
        glGetProgramiv(program, GL_LINK_STATUS, out linked);
        glDeleteShader(vs);
        glDeleteShader(fs);
        if (linked == 0) {
            int len;
            glGetProgramiv(program, GL_INFO_LOG_LENGTH, out len);
            StringBuilder sb = new StringBuilder(Math.Max(1, len));
            int outLen;
            glGetProgramInfoLog(program, sb.Capacity, out outLen, sb);
            throw new InvalidOperationException("LightPillar program link failed: " + sb.ToString());
        }

        uTime = glGetUniformLocation(program, "uTime");
        uResolution = glGetUniformLocation(program, "uResolution");
        uTopColor = glGetUniformLocation(program, "uTopColor");
        uBottomColor = glGetUniformLocation(program, "uBottomColor");
        uIntensity = glGetUniformLocation(program, "uIntensity");
        uGlowAmount = glGetUniformLocation(program, "uGlowAmount");
        uPillarWidth = glGetUniformLocation(program, "uPillarWidth");
        uPillarHeight = glGetUniformLocation(program, "uPillarHeight");
        uNoiseIntensity = glGetUniformLocation(program, "uNoiseIntensity");
        uInteractive = glGetUniformLocation(program, "uInteractive");
        uMouse = glGetUniformLocation(program, "uMouse");
        uRotCos = glGetUniformLocation(program, "uRotCos");
        uRotSin = glGetUniformLocation(program, "uRotSin");
        uPillarRotCos = glGetUniformLocation(program, "uPillarRotCos");
        uPillarRotSin = glGetUniformLocation(program, "uPillarRotSin");
        uViewScale = glGetUniformLocation(program, "uViewScale");

        glUseProgram(program);
        glUniform2f(uResolution, (float)width, (float)height);
        glUniform3f(uTopColor, 0f, 0f, 0f);
        glUniform3f(uBottomColor, 1f, 1f, 1f);
        glUniform1f(uIntensity, (float)intensity);
        glUniform1f(uGlowAmount, (float)glowAmount);
        glUniform1f(uPillarWidth, (float)pillarWidth);
        glUniform1f(uPillarHeight, (float)pillarHeight);
        glUniform1f(uNoiseIntensity, (float)noiseIntensity);
        glUniform1f(uInteractive, interactive ? 1f : 0f);
        glUniform2f(uMouse, (float)mouseX, (float)mouseY);
        glUniform1f(uPillarRotCos, (float)Math.Cos(pillarRotationRad));
        glUniform1f(uPillarRotSin, (float)Math.Sin(pillarRotationRad));
        glUniform1f(uViewScale, (float)viewScale);
        glPixelStorei(GL_PACK_ALIGNMENT, 1);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_BLEND);
        glClearColor(0f, 0f, 0f, 1f);

        readbackBytes = width * height * 4;
        readback = Marshal.AllocHGlobal(readbackBytes);
        rawPixels = new int[width * height];
    }

    public void Start() {
        if (running) return;
        running = true;
        worker = new Thread(RenderLoop);
        worker.IsBackground = true;
        worker.Priority = ThreadPriority.BelowNormal;
        worker.SetApartmentState(ApartmentState.STA);
        worker.Start();
    }

    private void RenderLoop() {
        try {
            InitGl();
            double time = 0.0;
            long previous = Environment.TickCount;
            while (running) {
                long now = Environment.TickCount;
                double dt = (now - previous) / 1000.0;
                previous = now;
                if (dt < 0.001) dt = 0.001;
                if (dt > 0.05) dt = 0.05;
                time += dt * rotationSpeed;

                glUseProgram(program);
                glViewport(0, 0, width, height);
                glClear(GL_COLOR_BUFFER_BIT);
                glUniform1f(uTime, (float)time);
                glUniform1f(uInteractive, interactive ? 1f : 0f);
                glUniform2f(uMouse, (float)mouseX, (float)mouseY);
                glUniform1f(uRotCos, (float)Math.Cos(time * 0.3));
                glUniform1f(uRotSin, (float)Math.Sin(time * 0.3));
                glUniform1f(uPillarRotCos, (float)Math.Cos(pillarRotationRad));
                glUniform1f(uPillarRotSin, (float)Math.Sin(pillarRotationRad));

                glBegin(GL_QUADS);
                glVertex2f(-1f, -1f);
                glVertex2f(1f, -1f);
                glVertex2f(1f, 1f);
                glVertex2f(-1f, 1f);
                glEnd();
                glFlush();
                glReadPixels(0, 0, width, height, GL_BGRA, GL_UNSIGNED_BYTE, readback);
                Marshal.Copy(readback, rawPixels, 0, rawPixels.Length);

                lock (sync) {
                    int stride = width;
                    for (int y = 0; y < height; y++) {
                        int srcRow = (height - 1 - y) * stride;
                        int dstRow = y * stride;
                        Array.Copy(rawPixels, srcRow, back, dstRow, stride);
                    }
                    int[] tmp = front;
                    front = back;
                    back = tmp;
                    frameReady = true;
                }

                // Pace the worker when the GPU finishes early.  This avoids a
                // tight render/readback loop stealing CPU time from WinForms
                // without lowering the shader iteration count or image quality.
                long frameElapsedMs = Environment.TickCount - now;
                int remainingMs = (int)Math.Floor(16.666 - Math.Max(0, frameElapsedMs));
                if (remainingMs > 0) Thread.Sleep(Math.Min(remainingMs, 6));
            }
        }
        catch {
            // Keep the Login UI alive even if the GPU path is unavailable.
        }
        finally {
            try {
                if (program != 0) glDeleteProgram(program);
            } catch { }
            program = 0;
            try { wglMakeCurrent(IntPtr.Zero, IntPtr.Zero); } catch { }
            try { if (hglrc != IntPtr.Zero) wglDeleteContext(hglrc); } catch { }
            hglrc = IntPtr.Zero;
            try { if (hdc != IntPtr.Zero && host != null) ReleaseDC(host.Handle, hdc); } catch { }
            hdc = IntPtr.Zero;
            try { if (host != null && host.Handle != IntPtr.Zero) host.DestroyHandle(); } catch { }
            host = null;
            try { if (readback != IntPtr.Zero) Marshal.FreeHGlobal(readback); } catch { }
            readback = IntPtr.Zero;
        }
    }

    public bool TryCopyFrame(int[] destination) {
        if (destination == null) return false;
        lock (sync) {
            if (!frameReady || front == null || destination.Length < front.Length) return false;
            Array.Copy(front, destination, front.Length);
            frameReady = false;
            return true;
        }
    }

    public void Dispose() {
        running = false;
        Thread t = worker;
        if (t != null && t.IsAlive) {
            try { t.Join(700); } catch { }
        }
        worker = null;
        lock (sync) { frameReady = false; }
    }
}
"@
}

$script:lightPillarBitmap = $null
$script:lightPillarPixels = $null
$script:lightPillarW = 0
$script:lightPillarH = 0
$script:lightPillarEngine = $null
$script:lightPillarLastPresent = -1.0

function Initialize-LightPillarBackground {
    param([int]$targetW, [int]$targetH)
    try {
        if ($targetW -le 0 -or $targetH -le 0) { return }

        # GPU shader surface: render below full-size, then upscale smoothly.
        # This keeps the visual field detailed while moving the expensive raymarch
        # completely off the WinForms UI thread.
        $renderScale = 0.72
        $rw = [int][math]::Round($targetW * $renderScale)
        $rh = [int][math]::Round($targetH * $renderScale)
        if ($rw -lt 480) { $rw = 480 }
        if ($rh -lt 320) { $rh = 320 }
        if ($rw -gt 640) { $rw = 640 }
        if ($rh -gt 460) { $rh = 460 }

        $script:lightPillarW = $rw
        $script:lightPillarH = $rh

        if ($null -ne $script:lightPillarEngine) { try { $script:lightPillarEngine.Dispose() } catch { } }
        if ($null -ne $script:lightPillarBitmap) { try { $script:lightPillarBitmap.Dispose() } catch { } }

        $script:lightPillarBitmap = New-Object System.Drawing.Bitmap($rw, $rh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $script:lightPillarPixels = New-Object int[] ($rw * $rh)
        $script:lightPillarEngine = New-Object LightPillarGpuV5
        $script:lightPillarEngine.Configure($rw, $rh, 0.8, 0.6, 0.001, 1.3, 0.3, 0.0, 56.0, $false)
        $script:lightPillarEngine.Start()
    }
    catch {
        if ($null -ne $script:lightPillarEngine) { try { $script:lightPillarEngine.Dispose() } catch { } }
        $script:lightPillarEngine = $null
    }
}

function Update-LightPillarBackgroundFrame {
    param([double]$Now)
    try {
        # Present at the same cadence as the UI pump (target: ~100 Hz).
        if (($Now - $script:lightPillarLastPresent) -lt 0.010) { return }
        if ($null -eq $script:lightPillarEngine -or $null -eq $script:lightPillarBitmap -or $null -eq $script:lightPillarPixels) { return }
        if (-not $script:lightPillarEngine.TryCopyFrame($script:lightPillarPixels)) { return }

        $rect = [System.Drawing.Rectangle]::new(0, 0, $script:lightPillarW, $script:lightPillarH)
        $bmpData = $script:lightPillarBitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            [System.Runtime.InteropServices.Marshal]::Copy($script:lightPillarPixels, 0, $bmpData.Scan0, $script:lightPillarPixels.Length)
        }
        finally { $script:lightPillarBitmap.UnlockBits($bmpData) }
        $script:lightPillarLastPresent = $Now
    }
    catch { }
}

# -----------------------------------------------------------------------------
#  PRE-RENDER the static Login fallback surface ONCE
#  No legacy Ether/arc/line background is baked into Login.
# -----------------------------------------------------------------------------
$script:bg = New-Object System.Drawing.Bitmap(
    $W, $H,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$bgG = [System.Drawing.Graphics]::FromImage($script:bg)
$bgG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bgG.Clear([System.Drawing.Color]::FromArgb(255, 0, 0, 0))

# Login header has no divider line.
$hx0 = 2.0
$hx1 = [double]($W - 2)
$hy0 = 2.0
$hHt = 34.0
$bgG.Dispose()

# Start the LightPillar engine before the Login window is shown.
try { Initialize-LightPillarBackground $W $H } catch { }

# -----------------------------------------------------------------------------

#  EMBEDDED High X FONTS
#  HIGH  = FFF AZADLIQ Black (embedded in this script)
#  Font source: FFF_AZADLIQ-Black.otf
#  X     = Bagnard Sans (embedded in this script)
#  Both are loaded privately from memory so customers do not need to install fonts.
# -----------------------------------------------------------------------------
$script:hxEmbeddedFontCollection = $null
$script:hxEmbeddedFontFamily = $null
$script:hxEmbeddedFontBytes = $null
$script:hxEmbeddedFontBase64 = @'
T1RUTwAMAIAAAwBAQ0ZGIORmTFwAAAzAAAAiZEdERUYETwSFAAAvJAAAAGJHUE9TE4AKRwAAL4gAABPuR1NVQqhYuk4AAEN4AAAA
ak9TLzIy8ppRAAADgAAAAGBjbWFwzKnXawAAClgAAAJIaGVhZBjOsLgAAADUAAAANmhoZWENGwoFAAADXAAAACRobXR49/ALNwAA
AQwAAAJQbWF4cACUUAAAAADMAAAABm5hbWVBTCTmAAAD4AAABndwb3N0/7gAMgAADKAAAAAgAABQAACUAAAAAQAAAAEAQQm2artf
Dzz1AAMD6AAAAADYKrayAAAAANgqtrL+Nv7DCywDcAAAAAMAAgAAAAAAAAD6AAABLAAAAdoABQHaAAUByQAjAb8AGQG/ABkB2wAj
AWEAIwFSACMByQAZAckAGQHgACMA+gAjAPoAIwEuAAAB4AAjAU0AIwKGACMB+wAjAc4AGQHOABkBuwAjAfIAGQHLACMBrgAKAa4A
CgI0AB4ByQAUAX4ABQHUAB4B1AAeAdAAAALUAAUByv/2Acz/9gFgAAoB2gAFAdoABQHJACMBvwAZAb8AGQHbACMBYQAjAckAFAFS
ACMByQAZAckAGQHgACMA+gAjAPoAIwEuAAAB4AAjAU0AIwKGACMB+wAjAc4AGQHOABkBuwAjAfIAGQHLACMBrgAKAa4ACgI0AB4B
fgAFAdQAHgHUAB4B0AAAAtQABQHK//YBzP/2AWAACgKmADIBzgAZASYAAAGlAAoBsgAKAdMACgGtAAoByAAZAYMAAAHKAA8ByAAK
AaYACgD1ACgA9QAoAPUAKAD1ACgBGQAyAZYAAAHhAB4CrwAeAZcACgGcAAoBRQAyAUUAHgFsAAoBbAAeAUUAMgFFAB4BXAAyAdgA
MgKAADIBngAAAPUAKAG9ACgBvQAoAb0AKAD1ACgA9QAoAdwAMgHcADIBDQAyAQ0AMgHJADIBBQAyAckACgGGABkBmQAKAkwAMgJM
ADICTQAyAvUAMgNIABQBnQAPAbAACgJ+ADIBhwAyARgAMgAA/jYAAP8aAAD+qwAAADsAAP8qAU8APQGHADIBwgBQAQgAMgHCAFAB
/AAyARgAMgFPAD0CFgBFAXAAMgD9ADEBLwAeAYMAHgs2AAoAAQAAA7b/BgAACzb+Nv80CywAAQAAAAAAAAAAAAAAAAAAAJQAAwG7
A4QABQAIAooCWAAAAEsCigJYAAABXgAyASwAAAAACgAAAAAAAAAAAAABAAAAAAAAAAAAAAAAYkIgIABAACAiEgLu/wYAyAO2APoA
AAAQAAAAAAH0ArwAAAAgAAcAAAAcAVYAAQAAAAAAAABjAAAAAQAAAAAAAQALAGMAAQAAAAAAAgAFAG4AAQAAAAAAAwAcAHMAAQAA
AAAABAARAI8AAQAAAAAABQA8AKAAAQAAAAAABgARANwAAQAAAAAACAAOAO0AAQAAAAAACQAOAO0AAQAAAAAACwAMAPsAAQAAAAAA
DAAMAPsAAQAAAAAADQCQAQcAAQAAAAAADgAaAZcAAwABBAkAAADGAbEAAwABBAkAAQAiAncAAwABBAkAAgAOApkAAwABBAkAAwA4
AqcAAwABBAkABAAiAncAAwABBAkABQB4At8AAwABBAkABgAiA1cAAwABBAkACAAcA3kAAwABBAkACQAcA3kAAwABBAkACwAYA5UA
AwABBAkADAAYA5UAAwABBAkADQEgA60AAwABBAkADgA0BM0AAwABBAkAEAAWBQEAAwABBAkAEQAKBRdDb3B5cmlnaHQgqSAyMDE4
IGJ5IGJCb3h0eXBlLmNvbSAmIFNlcnZpY2VwbGFuIENhbXBhaWduIEhhbWJ1cmcgR21iSCAmIENvLiBLRy4gQWxsIHJpZ2h0cyBy
ZXNlcnZlZC5GRkZfQVpBRExJUUJsYWNrMS4wMDE7YkIgIDtGRkZfQVpBRExJUS1CbGFja0ZGRl9BWkFETElRIEJsYWNrVmVyc2lv
biAxLjAwMTtQUyAwMDEuMDAxO2hvdGNvbnYgMS4wLjg4O21ha2VvdGYubGliMi41LjY0Nzc1RkZGX0FaQURMSVEtQmxhY2tiQm94
IFR5cGUgR21iSGJCb3h0eXBlLmNvbVRoaXMgRm9udCBTb2Z0d2FyZSBpcyBsaWNlbnNlZCB1bmRlciB0aGUgU0lMIE9wZW4gRm9u
dCBMaWNlbnNlLCBWZXJzaW9uIDEuMS4gVGhpcyBsaWNlbnNlIGlzIGF2YWlsYWJsZSB3aXRoIGEgRkFRIGF0OiBodHRwOi8vc2Ny
aXB0cy5zaWwub3JnL09GTGh0dHA6Ly9zY3JpcHRzLnNpbC5vcmcvT0ZMAEMAbwBwAHkAcgBpAGcAaAB0ACAAqQAgADIAMAAxADgA
IABiAHkAIABiAEIAbwB4AHQAeQBwAGUALgBjAG8AbQAgACYAIABTAGUAcgB2AGkAYwBlAHAAbABhAG4AIABDAGEAbQBwAGEAaQBn
AG4AIABIAGEAbQBiAHUAcgBnACAARwBtAGIASAAgACYAIABDAG8ALgAgAEsARwAuACAAQQBsAGwAIAByAGkAZwBoAHQAcwAgAHIA
ZQBzAGUAcgB2AGUAZAAuAEYARgBGAF8AQQBaAEEARABMAEkAUQAgAEIAbABhAGMAawBSAGUAZwB1AGwAYQByADEALgAwADAAMQA7
AGIAQgAgACAAOwBGAEYARgBfAEEAWgBBAEQATABJAFEALQBCAGwAYQBjAGsAVgBlAHIAcwBpAG8AbgAgADEALgAwADAAMQA7AFAA
UwAgADAAMAAxAC4AMAAwADEAOwBoAG8AdABjAG8AbgB2ACAAMQAuADAALgA4ADgAOwBtAGEAawBlAG8AdABmAC4AbABpAGIAMgAu
ADUALgA2ADQANwA3ADUARgBGAEYAXwBBAFoAQQBEAEwASQBRAC0AQgBsAGEAYwBrAGIAQgBvAHgAIABUAHkAcABlACAARwBtAGIA
SABiAEIAbwB4AHQAeQBwAGUALgBjAG8AbQBUAGgAaQBzACAARgBvAG4AdAAgAFMAbwBmAHQAdwBhAHIAZQAgAGkAcwAgAGwAaQBj
AGUAbgBzAGUAZAAgAHUAbgBkAGUAcgAgAHQAaABlACAAUwBJAEwAIABPAHAAZQBuACAARgBvAG4AdAAgAEwAaQBjAGUAbgBzAGUA
LAAgAFYAZQByAHMAaQBvAG4AIAAxAC4AMQAuACAAVABoAGkAcwAgAGwAaQBjAGUAbgBzAGUAIABpAHMAIABhAHYAYQBpAGwAYQBi
AGwAZQAgAHcAaQB0AGgAIABhACAARgBBAFEAIABhAHQAOgAgAGgAdAB0AHAAOgAvAC8AcwBjAHIAaQBwAHQAcwAuAHMAaQBsAC4A
bwByAGcALwBPAEYATABoAHQAdABwADoALwAvAHMAYwByAGkAcAB0AHMALgBzAGkAbAAuAG8AcgBnAC8ATwBGAEwARgBGAEYAXwBB
AFoAQQBEAEwASQBRAEIAbABhAGMAawAAAAACAAAAAwAAABQAAwABAAAAFAAEAjQAAABkAEAABQAkAC8AOQA7AD0ASQBPAFMAVQBa
AF0AaQBvAHMAdQB6AH0AogCpAKsAsAC0ALgAuwDEAMcA1gDcAN8A5ADnAPYA/AEfATABXwGPAlkCxwLdAwgDJx6eIBQgGiAeIDog
RCCsIhL//wAAACAAMAA6AD0APwBKAFAAVABWAFsAXwBqAHAAdAB2AHsAogCnAKsArwC0ALgAuwDEAMcA1gDcAN8A5ADnAPYA/AEe
ATABXgGPAlkCxgLYAwYDJh6eIBMgGCAcIDkgRCCsIhL//wAAABkAHAA8AAD/xf/GAAD/ygAAAAD/yf/KAAD/zQAA/9MAAP/DAAD/
0v/R/7T/P/8//z//Q/9g/0L/Qv9D/0YAAP7eAAD+jf3TAAAAAAAA/V7hfeBSAAAAAOA34A/fyN5mAAEAZAAAAAAAAAB8AAAAAACM
AAAAjACQAAAAAACgAAAAoAAAAKIAAACkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAI4AAACOAAAAAACMAI4AmAAAAAAAAACWAJoA
AAAAAAAAAAAAAAEAWAByAFsAdgB6AHwAcwBeAF8AWgB3AFUAZABUAFwAWQB7AAIABAAFAAcACAAJAAoADAANAB0AHgBiAF0AYwBn
AI0AJQAnACgAKgArAC0ALgAwADEAQABBAGAAgABhAH0AiwB+AI8AfwALAC8AGgA+AIoAiACHAIwAkQCQAJIAjgCDAIIAgQBsAG0A
aABqAGsAaQADAAAAAAAA/7UAMgAAAAAAAAAAAAAAAAAAAAAAAAAAAQAEAgABAQESRkZGX0FaQURMSVEtQmxhY2sAAQEBIvgQAPgs
AfgtAvgTBPxe+9EcCyz6BAX33A/5AxGpHBXiEgATAQEHERggJy40PUVKTlVcY2pxeN/wR2JyZXZlSWRvdGFjY2VudHVuaTFFOUVT
Y2VkaWxsYXVuaTAxOEZ1bmkwMjU5Z2JyZXZlaS5sb2NsVFJLc2NlZGlsbGFGX0ZfRkV1cm91bmkwMzA4dW5pMDMyNnVuaTAzMDd1
bmkwMzA2dW5pMDMyN0FaQURMSUdDb3B5cmlnaHQgXChjXCkgMjAxOCBieSBiQm94dHlwZS5jb20gJiBTZXJ2aWNlcGxhbiBDYW1w
YWlnbiBIYW1idXJnIEdtYkggJiBDby4gS0cuIEFsbCByaWdodHMgcmVzZXJ2ZWQuRkZGX0FaQURMSVEgQmxhY2sAAAEAAQAAIgAA
rQAAIwEAsQAAJQMBhwAAKQEBiAAAKwUAvQAAMQMBigABiQABiwAANQEAwwAANwQAQgAAygAAQwEAzgAARQEBjAAARwEBjQAASQEB
jgAASwUA2gAAUQMBjwAAlQAAVQEA4AAAVwQBkAAAEQkAYwAADwAADQAAGwEAAgAAIAAACwAABAAAEAAAPQAACQEAXAAAXgAAPAAA
PgAADgAAbwAAiQAAQAAAdQEAaQAAdwAAQQAACAAAagAAeAAAawEAAwAAaAABkQAAYQAABQAADAAApgAAHgAABgAAIQAABwAAZgAA
qgAAoQAAXQABkgABlAEBkwABlgAAfQAAgQAAiAAAhQAAfgAAgwAAggAAfAAAhgAAgAAAhwAAhAAAfwABlwAAlAIAAQAEAAYACAAK
AAwADgAQABIAFAAWABgAGgAcAB4AIAAiACQAJgAoACoALAAuADAAMgA0ADYAOAA6ADwAPgBAAGcAaQBrAG0AbwBxAHMAdQB3AHkA
ewB9AH8AgQCDAIUAhwCJAIsAjQCPAJEAkwCVAJcAmQCbAJ0AnwChAKMApQCnAKkAqwDAAMIAxADGAMgAygQWBEkEXQSdBQEFPgWd
BfEGEQaLBu0HBQcNBw8HGQcmB1QHnQfUCDsIUwhpCIwIrQj+CU8JZgl9CZAJowm3CcsJzQnfCfMKAgoOChkKKwo8CkUKTgplCm4K
zgs8C9YMAQwPDCYMeA0FDY4OLw7FDwcPGA8qDzYPSA9oD30PlA+kD8UP2A//EA8QFxAxEFMQaRCqEOARJRJH+xIOPw4+Ci0KKwoq
CiMKPApRCmQKKQoiClQKkQpmCmMKSgp/CkYKUgoyCiQKOAoxCjQKIQogCigKLAp2ClAK5/ic90j7I78KE2ip+VA1ChOg/Cz7SBUT
kPdI/AaKCvgG90j72lwKbQo/CkUKVQpHCj4KLQorCioKIwo8ClEKLApkCikKIgpUCpEKZgpjCkoKfwpGClIKMgokCjgKMQo0CiEK
IAooCnYKUArn+XW/ChPQqfoENQr8LPtIFROgOwptCj8KRQpVCkcK98KLuLeUpLWgm42Wg5WHpXqbmpt8v2qVkZyamZGVkJ19mvdg
m/cYmxK9nKqmp6ZzpZWklKOXpHejgJKLpY6lk6V+p4KueJKZk4WmmaZxnJmhtaSnnBOhEvQgib0W+Nb42waRiY+Hjx77IPchBY+H
iIyFG/w3Bpz81hX4xvgg+yj3KPwyB/sX+EIV9w8H9w77DwUTAAgoAAD8M/umFcUKEwACKAAAygoTAAgoAADkChMACAAAQPdlFqGU
kpYfEwABAAIAn2eFkBqMjYyPHhMAAQAAQJGUioiSHxMAAQACAJKYBY2HgI97G3SCg4IfEwAIAABAeLGPhRqKioqGhIGMkIIehH4F
h5OUiJwbEwAEMAAA+77XChMAAhEAAKacVQb3FFcVo6AGEwACAEAAnXYFor9zdgYTAAIBCAB3oAV2BuVXFaWtnp1LeZ4GEwCIKAAA
+xV4Swo3BMUKEwAQKAAAygoTAIgoAADkChMAIDAAADLXChMAEBAAAKacVQYTAEABAAD3FFcVpQYTACABAACxChMAQCAAAKwKEwAQ
IQAAwAphBhMAgCAAAGRmSwoTEEABACDMpAr3WykVExAAAAAQxQoTAgAAABCagJd0HhMCAAAAIHSAf3wfigcTEEABACDkChMBADAA
APv5jBWmBhMEADAAAJ6blXuRBxMBABAAAKacVQYTEAAEAADFVxWlBhMIAAQAALEKExAAAgAArAoTAQACAADAChMBAAQAAGEGExAA
AQAAz1cVxZtrkAYTBAABAACflXeQBhMBAACAAKubBhMBAAEAAFEGExAAABAAylcVxZtrkAYTBAAAEACflXeQBhMBAAAQAKubUQYT
EAAABADKVxUTEAAAAQCuBqCWmJcfjQcTAQAAAQCYgJd2HhMBAAAEBGgG9yRXFaEGEwIAAAAEqAcTAQAAAAWWbgWhBhMCAAAAAZSo
BRMBAAAAAW4HEwEAAAAGpL9nBoNwg6YFZgYTEAAABCBkZksKPBYTAQAABAChkQeRi42Hi4SLhImHiwwlE5AAJAAA+1ykCnr7PhUT
IAAkIADZ9wMHE8AAICAAtQrQFhMgAAAggNn3AwcTwAAAIIC1CtAWEyAAAACB2fcDBxPAAAAAAbUKDnIK+VgVmgof+8wmCvfMB04K
HvsRBKDlCvsfB1djBfdHfQqgHvxmBIwK9x8Hv7MF+0eUCjmmCtqbCveXhwr7l/sl2vy/3QoOuIv3JffqbgqV90i590gTuPdR9yUV
9zb3d2P3gxo3Ch4T2Hj3SAcTuMpzCk4H+wv7eJGN+3sejPslBfgp9yUGDsWgCveBxvcby24KlvdIZ66890gTq/eB+FsVdYCBdR5a
+xu8BqSVgXUfIQdlCnmGlaIeE2u8ChOrpQpECvcKcKdRnx7EoqWp6BpICvsMHhOt+ww4fgofE7V4BxOz3QoTq8pzCg7moHb3Evcl
93l393B3AfeC90kD+F33EhX3JWX3efs1B3f7eQVbBtT4QQX7SAZC/EEF+yX3ePsS90n3EgcOwKAK94HT9zLr9yUSlfdI+zf3SKau
ChO2+DL3qxX3IiuxSR4TtH2Ciol1H+73R/cl+/v8IwcTtvdDXQr7CweFCnoeE7R6hpWiHxN02gcTePtIaAYTuuYK9wv3C2sKHg7b
g/cl9yT3Jsf3cZ4KufdI+zr3SRPa92H4LRX3IX0KnR4T3M0KE+y9ChPcNwoe+6IH+0LMRfcoHhPa9zq18fcR9xxQ0yNpcISAeh/H
+zUVyArJCg6WpgqL+BcD+BeHCvwX+yX3WQb7Lvy/BfdOBvcy+OIFDt2D+WAS91fPTsEToPd5+VgV9xDbfgozcm1XdB/GeKdu+w8a
+yU4UvsW+xg4jQr3D6ioxZ4eV6JyqeMa9yXexPcNHoz7rBWblZWiH+UHoYGVenqBgXUeMQd0lYGdHhPA+8sEnpmVrB/lB6t9lXd3
fYFrHjEHapmBoB4O26AK93HH9yb3JPclEpX3Sfs690i590gTuveP97cV+yEHhQp5HhO2eYaVoh8Tdsr7SHgHE7alCvcMawoe96IH
90JK0fsoHhO6+zphJfsR+xzGQ/OtppKWnB9P9zUVyQrICg65QwqV+CYD96mHCvufsgr3Gwb3n/lQBQ6LuAr3MnsKDm8Ki5cK+zn7
6nsKDvsidvc3lwr76gQnCg4si/cy+LJ3Er33SftB9zkT4Pd7hwr7SfuGBqL7fwX3Gwai94EFE9D7QfvCewoOqYv3MvfdbgqL90g0
9zn7NPcuca4KE6L3dvhzFSP7FLz7axoTpPcuBhOy9xz3Lm73Uho3Ch4T0Hj3SAcTsspzChOo+xn8HHsKDvT5UHcBqfg5A/fOhwr7
Jwac+xL7AcZe+x/3D3AzOfcKNcX3AsT7AvcK4TPd9w+mXvcf+wFQBQ73y6B29yr3Jeb3Jfc9dwGp+QcD+Qb4FhWq9yUFTQavzwpO
BrDPCk8GbPslBccGdzAFTwZr+yUFyAZq+yoF3Qqs9yoFyAZq+yoF90kGq/cqBcoGqvclBU0GnuYF+1wwFU4Gn+YFyAYOqkMKlfgX
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
aQWSBZwFwAXmBfMF+QX+BgIGBgYdBisGMgY4BkUGTwZVBlwGfwaaBp4GvAbRBtcG4AbmBuoG7wcOBxMHHwctBzEHOgdBB0sHTwdp
B3sHgAeKB5IHmwehB6UHqQfDB8kHzgfTB90H4QflB+kH7Qf2CAAICwgTCBcIGwg1CE8IZAhzCHwIhgiJCI8IlQigCKUIqgiwCLQI
uAjACMYIzgjSCNYI2wjuCQEJBgkNCREJFQkcCSAJMAlBCUkJTglTCVwJbAlwCX4JggmLCZQJnQmhCacJrgmyCbgJvgnDCc8J3Qnj
CecJ6gnuCfYJ+gn+CgoKFgoiCicKLQoxCjUKQApHCkwKUQpYCl0KYgpnCnEKdwp8CoYKkAqUCpgKnQqmCq8KuAq9CsMKyQrOCtLB
+z/133b4fWgKZvcMYroKE9iA96H4RxVFmYKUqhrIfQqdHhPZAM0KE+kAvQoT2QBBChPUgFMKvAoT0gD7C8NP4noecl8KogcT2IDi
nMPH9wsakwoOwaAK94H3lmgKtboKEwATlfdtgxX3DGsKH5MKE5pFmYKUqhrIcwoTqr0KE5pBChOVUwoTVbwKE5WlCh4OYAr7Efch
EqT3SI61kq4KE8rf+fA5ChPV90H9WkAKE+VF90ilBxPVJQrS+z/13nb4WdEKafcMaa4KE+r4SfhWFcMHE9qtCvsMxE/keh4T1HNf
CqEHE9rknMTH9wwaw/tIJwdCChPqJwcOiwqo9yPWCqb6BDUK+2D+DBVECh/3zAcT+IAKE7iwChP4XgoTuHEKSAr7DvsOOC8K91r7
Y/sbpgcOqApECh4L+zn7MtAGb/s3BcsGx/c3BQv3UIv3Efcw9xH3PfcRAan3SPc9mwr4P/gqFd33NAX3GvudB/srTH4KH/yG90j4
rweimZiiHu4GPPs9ivsRBcIGuJiDYB9bB2B+fV4eSvsR5Qb3INTE9xEfzwfvWcM5Hg5gChKk90i/90gT3PeV9ypAChPsRfdIpQcT
3CUK0qAK95b3XPeWywoTnPeV9yoVQgoTrCf3SMMHE5z3JTjE+w/7DjcvChNcw/tIBw7ci/cR+FbTCvgI9/wVt52eqcQaxU0K+3P9
UPd6aQrZB8Rzq12bHvsE6hW7Cvcspwr8FgS7Cvc2pwoOegr3VPcRAZ9qCgP3d/lZFfsOOH4KH3D3SNLQCvsz+3z7WiYK980HSAr7
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
AAAAAAAA//b/9gAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/+//7//sAAP/7//v/+wAA//YAAP/s/+wAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAD/2P/2//v/+wAA//sAAAAAAAAAAAAA/+z/9v/7AAUAAAAAAAD/4v/2//b/sP/s//H/9v/i/84AAAAA
AAAAAAAK/+z/8f/x//b/8f/2AAD/7P/iAAD/4v/i//EAAP/s/+wAAAAAAAD/9gAAAAD/9v/xAAAAHv/2AAAAAAAAAAD/8f/x//H/
xP/s/9j/xP/O/9j/zv/i/87/7P/Y/87/zv/iAAAAAAAAAAAAAP/2AAAAAAAA//YAAAAAAAD/9gAAAAAAAP/xAAD/9v/nAAAAAP/s
AAAAAAAAAAAAAAAA//b/9v/x//b/9gAAAAAAAP/sAAAAAAAAAAAAAP/OAAAAAAAAAAAAAAAA//YAAAAAAAD/4v/sAAAAFAAUABQA
Cv/Y/+z/8f+cAAAAAAAA/87/nAAFAAoAAAAAAAD/9gAAAAD/4v/x/+f/2P/Y/+z/4v/i/+L/9gAA/+L/4v/sAAoAAAAAAAAAAAAA
AAAAAAAKAAAACgAAAAAAAAAAAAAAAP/2AAD/+//2AAD/9v/x//H/9gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAA//sAAAAA/+cAAAAA//YAAAAAAAD/+wAAAAD/+//7//YAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/9j/8QAA//YABf/7
AAAAAAAA/+IAAP/Y/9gAAAAKAAoAAAAK/9j/+//2/87/3f/2/+z/2AAA//YAAP/2AAD/9gAAAAAAAP/7AAAAAP/2AAAAAAAAAAAA
AAAAAAAAAAAAAAD/8f/2//v/9gAAAAAAAP/2AAAAAAAAAAAAAP/i//YAAP/2AAAAAAAAAAAAAP/sAAD/4v/iAAAACgAAAAAAAP/i
AAAAAP/O/+z/9v/2/+L/4v/2//b/9gAAAAr/8f/2AAD/+//2AAAAAP/s/+wAAP/s/+IAAAAA//EAAAAAAAAAAAAAAAAAAAAAAAAA
AAAe//YAAP/2AAD/zv/n/+z/7AAA//YAAAAA/+z/4gAA/87/uv/xAA//8QAAAAr/zgAAAAD/sP/O//H/8f/Y/87/7P/x/+wAAAAA
//EAAP/2//b/+wAAAAAAAP/iAAD/4v/YAAAAAAAAAAAAAP/2AAAAAAAAAAD/9v/2AAAAAAAAAAAAAAACBToABAAACZgJoAACAAYA
AP/2//b/9v/sAAAAAP/i/+wAAP/i//YAAgUaAAQAAAm4ChYACwAMAAD/zv/Y/+z/7AAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/2P/Y
//b/4gAAAAAAAAAAAAAAAAAAAAD/zv/dAAD/7AAAAAAAAAAAAAD/7P/s/+z/zv/YAAD/4v/2/+wAAAAAAAD/9v/Y/+L/uv/YAAD/
4gAA/+wAAAAAAAD/4gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/sP/O//b/zgAAAAD/9v/2AAAAAAAAAAAAAAAFAAAAAAAA
AAAAAAAAAAD/zv/OAAAAAAAAAAAAAAAAAAAAAAAAAAD/4v/OAAAAAAAAAAAAAAAAAAD/7P/sAAAAAAAUAB7/zgAAAAD/4gAAAAAA
AAAAAAEEMAQ8AAIADAAeAAQAAQAqAAEAMAABADYAAAAkAAQAKgAwADYAPABCAEgAVABOAAH/kgAAAAH/AgH0AAH/dAH0AAH/PQH0
AAEA5wAAAAEA5wK8AAEA8QAAAAEA6gK8AAEAzgAAAAEAywKZAAEBkgHqAAEAAAAAAAEDuAPQAAIADAAeAAQAAAEcAAABIgAAASgA
AQEuAEIBIgJUASgCVAE0AS4BNAE6AUYBQAFSAUwBXgFYAWoBZAFwAWQBfAF2AYgBggGIAYIBlAGOAXwBdgGgAZoBrAGmAbgBsgG+
AS4BxAEuAdABygHWAlQBagHcAegB4gHoAe4B9AFkAgAB+gIMAgYCDAIGAhgCEgIkAh4CMAIqAWoB3AI8AjYBIgJUASgCVAJIAkIB
NAE6AUYBQAFSAUwB9AFkAV4BWAFqAWQBcAFkAXwBdgGIAYIBiAJUAZQBjgF8AXYBoAGaAawBpgG4AbIBvgEuAcQBLgHQAcoB1gJU
AWoB3AHoAeIB6AHuAgAB+gIMAgYCTgIGAhgCEgIkAh4CMAIqAWoB3AI8AjYAAf8CAfQAAf90AfQAAf89AfQAAf+SAAAAAQDtArwA
AQDtA3AAAQDnAAAAAQDgArwAAQDR/1UAAQDvAAAAAQDvArwAAQCxAAAAAQCxArwAAQCpAAAAAQCpArwAAQDlAAAAAQDmArwAAQDm
A1wAAQDwAAAAAQDwArwAAQB9AAAAAQB9ArwAAQCXAAAAAQC2ArwAAQCnAAAAAQCnArwAAQFDAAAAAQFDArwAAQEDAAAAAQEDArwA
AQDnArwAAQDnA3AAAQDeAAAAAQDeArwAAQD5ArwAAQDmAAAAAQDZAAAAAQDWArwAAQDD/1UAAQDlArwAAQC/AAAAAQC/ArwAAQDq
AAAAAQDqArwAAQDoAAAAAQDoArwAAQFqAAAAAQFqArwAAQDkAAAAAQDkArwAAQCwAAAAAQCwArwAAQFFAAAAAQFFApQAAQDqA3AA
AQAAAAAAAQF6AYAAAQAMABIAAQAAAAwAAgAMABIAAf+SAAAAAf98/1UAAQCE/1UAAQFeAWgAAQAMABoAAwAAABwAAAAiAAAAKAAG
ACAAJgAsADIAOAA+AAH/AgH0AAH/dAH0AAH/PQH0AAH/AgKoAAH/dAKoAAH/PQKUAAEAxAKUAAEA/gKoAAEAjAKoAAEAAwB0AHUA
fAACAAcAVABaAAAAXABeAAcAYABgAAoAYgBiAAsAZABzAAwAdwB4ABwAfwB/AB4AAgABAEsAUQAAAAIACgACAAsAAAAPABEACgAU
ABoADQAcAC8AFAAzADUAKAA4AD4AKwBAAEcAMgBJAEkAOgBSAFIAOwB2AHYAPAABAAIAewB8AAIABwBUAFcAAABZAF0ABABkAG0A
CQBvAG8AEwBxAHMAFAB3AHgAFwB/AH8AGQABAAQAgQCCAIMAhQABAAQASQB0AHYAewACAAUAAgADAAAABQAaAAIAHAAmABgAKAA+
ACMAQABHADoAAQABAIUAAQACAIUAiQACAAEAgQCDAAAAAQAGAIEAggCDAIcAiwCMAAIAAgB1AHUAAgB8AHwAAQACAAYASgBKAAMA
UABQAAQAZABmAAEAbgBuAAIAcABwAAIAdwB4AAEAAQBUACwACAAIAAIAAgADAAkAAAAAAAsAAQAHAAAABwAAAAcAAAAGAAYABgAM
AAgACAAKAAoACgAKAAQABQAEAAUACgAKAAAAAAAAAAYABgAAAAAAAAAAAAAAAAAKAAEASgA2AAkAEgANABUADwAAAAwAFwAIAAAA
AwADAA4ADgAWAAoABgAAAAQABwAAABEAAAARAAAAEQACAAIAAgAFAAMAAwALAAsACwALAAEAEAABABAACwALABMAAAAAAAIAAgAA
AAAAFAAAAAAAAAALAAEASwAGAAYABQACAAEABAADAAIAHwACAAMADAAPAA8ADQAdAB0AAQAgACEAAgAjACMAAwAlACYADAAzADMA
DQBAAEAAAQBDAEQAAgBGAEYAAwBKAEoABQBMAEwACgBQAFAABgBRAFEAEQBSAFIACABUAFUAFABWAFcAEABZAFkACQBaAFoABwBd
AF0ABABkAGYAEwBnAGcAFQBoAGkAFABqAG0ACwBuAG4AEgBwAHAAEgByAHMACwB1AHUADwB3AHgAEwB7AHsADgB/AH8ACwABAAQA
cwABAAIAAgAHAAMABAAHAAcAAAAAAAAADQAFAAYAAAAAAAcABwAIAAkACgALAAsAAAAHAAwADQANAA4ADgAPABAAEQAAAAAAAQAC
AAIABwADAAcABAAHAAcAAAAAAAAADQAFAAYAAAAAAAcABwAIAAkACgALAAsAAAAMAA0ADQAOAA4ADwAQABEAAAAHAAAAAAAAAAAA
AAAAAAAAAAAHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAALAAEAAgB+ABMAEwAAAAIAAgAAAAAAAAACAAIAAAAAAAAAAQAAAAAAAAAAAAIAAgAAAAIAAAADAAMAAAAEAAUABgAGAAcA
BwAUAAgAFQATABMAAAACAAIAAAAAAAQAAAACAAIAAAAAAAAAAQAAAAAAAAAAAAIAAgAAAAIAAAADAAMAAAAFAAYABgAHAAcAFAAI
ABUAAAACAA8AHQAcABkAAAACABIAGAAOAAAAFgAWABcAFwAAABAACQAAABoACwAAAAAAAAAAAAAAAAANAA0ADQAbABYAFgARABEA
EQARAAwAAAAMAAAAEQARAAAAAAADAA0ADQAAAAAACgAeAAAAAAARAAEAewABAAEAAgAKAB0AHQABACAAIQACACIAIgADACMAIwAE
ACQAJAAFAEAAQAABAEMARAACAEUARQADAEYARgAEAEcARwAFAAIADwBUAFUABgBWAFcAAgBZAFkABwBbAFsABQBcAFwACQBdAF0A
AQBkAGYABABnAGcACgBoAGkABgBqAG0ACABvAG8AAwBxAHEAAwByAHMACAB3AHgABAB/AH8ACAACAB8AAgADAAEABQAGAAoACgAL
AAoADwAPAAIAFAAVAAoAFwAXAAoAGQAaAAgAHAAcAAsAHQAdAAUAHgAfAAYAIAAhAAcAIgAiAAMAIwAjAAQAJAAkAAkAJQAmAAEA
KAApAAoALAAsAAsALgAvAAoAMwAzAAIAOAA5AAoAOwA7AAoAPQA+AAgAQABAAAUAQQBCAAYAQwBEAAcARQBFAAMARgBGAAQARwBH
AAkASQBJAAoATwBPAAoAdgB2AAgAAAABAAAACgAeACwAAURGTFQACAAEAAAAAP//AAEAAAABY2FsdAAIAAAAAQAAAAEABAAEAAAA
AQAIAAEAKgACAAoAHgABAAQAkwAHACQAAgAHABEADQAKAAEABABIAAMACQAJAAEAAgACAAkAAA==
'@

try {
    Add-Type -AssemblyName System.Drawing
    $script:hxEmbeddedFontBytes = [Convert]::FromBase64String($script:hxEmbeddedFontBase64)
    $script:hxEmbeddedFontCollection = New-Object System.Drawing.Text.PrivateFontCollection

    $fontMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($script:hxEmbeddedFontBytes.Length)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy(
            $script:hxEmbeddedFontBytes,
            0,
            $fontMem,
            $script:hxEmbeddedFontBytes.Length
        )
        $script:hxEmbeddedFontCollection.AddMemoryFont($fontMem, $script:hxEmbeddedFontBytes.Length)
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($fontMem)
    }

    if ($script:hxEmbeddedFontCollection.Families.Count -gt 0) {
        $script:hxEmbeddedFontFamily = $script:hxEmbeddedFontCollection.Families[0]
    }
} catch {
    $script:hxEmbeddedFontFamily = $null
} finally {
    $script:hxEmbeddedFontBase64 = $null
    $script:hxEmbeddedFontBytes = $null
}

try {
    Add-Type -AssemblyName System.Drawing
    $script:hxXEmbeddedFontBytes = [Convert]::FromBase64String($script:hxXEmbeddedFontBase64)
    $script:hxXEmbeddedFontCollection = New-Object System.Drawing.Text.PrivateFontCollection

    $fontXMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($script:hxXEmbeddedFontBytes.Length)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy(
            $script:hxXEmbeddedFontBytes,
            0,
            $fontXMem,
            $script:hxXEmbeddedFontBytes.Length
        )
        $script:hxXEmbeddedFontCollection.AddMemoryFont($fontXMem, $script:hxXEmbeddedFontBytes.Length)
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($fontXMem)
    }

    if ($script:hxXEmbeddedFontCollection.Families.Count -gt 0) {
        $script:hxXEmbeddedFontFamily = $script:hxXEmbeddedFontCollection.Families[0]
    }
} catch {
    $script:hxXEmbeddedFontFamily = $null
} finally {
    $script:hxXEmbeddedFontBase64 = $null
    $script:hxXEmbeddedFontBytes = $null
}

# -----------------------------------------------------------------------------
#  EMBEDDED LOGIN WORDMARK FONT
#  HIGH X login mark = Syne ExtraBold (HIGH + X)
#  Loaded privately from memory so the Login screen does not depend on the font
#  being installed system-wide.
# -----------------------------------------------------------------------------
$script:meleteFontCollection = $null
$script:meleteFontFamily = $null
$script:meleteFontBytes = $null
$script:meleteFontBase64 = @'
T1RUTwALAIAAAwAwQ0ZGIGHIUDYAAAcwAAASakdQT1Ov+b7vAAAZnAAAAFpHU1VCJOka8AAAGfgAAABeT1MvMnqW
FmkAAAK0AAAAYGNtYXBIg0tWAAAGKAAAAOZoZWFkKJrCfAAAAMQAAAA2aGhlYRZPDTcAAAKQAAAAJGhtdHjqZ7/n
AAAA/AAAAZRtYXhwAGVQAAAAALwAAAAGbmFtZdOBOwoAAAMUAAADE3Bvc3T/OwBkAAAHEAAAACAAAFAAAGUAAAAB
AAAAADMza8aQx18PPPUAAwfQAAAAAN5LoswAAAAA3kuizAC6/nAMMwZ1AAAABwACAAAAAAAAA+gAugTbAAALkwFO
CrcCAAthAi4LUgICCxUCPQqCAj0LjgIuDBECPQWSAj0K+gGrCtACPQqyAj0M8gGEC9sCPQwlAi4LTAI9DCUCLgrH
AYkLOgIfCuMBdgwHAj0LuQFhDa0BegpmAZkKtQEXCusBpAsWAVsL+gI9C3QCIAurAj0LYQIuC6sCAQu8Ai4LTwGs
C/4CLgwnAj0FkgI9CpYBdQwRAj0KcgI9DT4CPQvNAj0MJQIuC0wCPQtMAaMKNwI9CzoCHwsqAZILjQH2C7kBYQ2t
AXoKZgGZCyoBXQrrAaQMJQIuDCUECgwlAj8MJQJLDCUCCwwlAl4MJQI9DCUB5wwlAgYMJQIpC/8CDAPbAV0D2wFd
A9sBXQPbAV0JkQFdBZwCPQrrAT4FnAI9BdgCPQtcAiIMRgHnBsYBPwbGAT8HRwHpCh8CPQcBAj0HAQGsBsABXQbA
Aa0HAQI9BwEBrAamAcEGpgHBBKMBwQSjAcEGpgHBBKMBwQzBAi4LewHgBZICPQWSAj0LigI9CXUCPQ0HAa0AAQAA
B9D+cAGQDa0AugC0DDMAAQAAAAAAAAAAAAAAAAAAAGUABAnsAfQABgAIBRQEsAAAAJYFFASwAAACvABkBXgAAAAA
AAAAAAAAAACAAAADAAAAAAAAAAAAAAAAVUtXTgDAACAgJgZA/nABkAfQAZAAAAABAAAAAAV4BXgAAAAgAAIAAAAU
APYAAQAAAAAAAQANAAAAAQAAAAAAAgAHAA0AAQAAAAAABAANAAAAAQAAAAAABQAYABQAAQAAAAAABgANACwAAwAB
BAkAAAAgADkAAwABBAkAAQAaAFkAAwABBAkAAgAOAHMAAwABBAkAAwAwAIEAAwABBAkABAAaAFkAAwABBAkABQAw
ALEAAwABBAkABgAaAOEAAwABBAkACAASAPsAAwABBAkACQAWAQ0AAwABBAkACwAmASMAAwABBAkADAAmASMAAwAB
BAkADQA8AUkAAwABBAkADgCAAYUAAwABBAkAEAAMAgUAAwABBAkAEQAMAhFNZWxldGUgTWVkaXVtUmVndWxhclZl
cnNpb24gMC4yMDA7RkVBS2l0IDEuME1lbGV0ZS1NZWRpdW0AqQAyADAAMgAyACAARABPAFQAIABDAE8ATABPAE4A
LgBNAGUAbABlAHQAZQAgAE0AZQBkAGkAdQBtAFIAZQBnAHUAbABhAHIAMAAuADIAMAAwADsAVQBLAFcATgA7AE0A
ZQBsAGUAdABlAC0ATQBlAGQAaQB1AG0AVgBlAHIAcwBpAG8AbgAgADAALgAyADAAMAA7AEYARQBBAEsAaQB0ACAA
MQAuADAATQBlAGwAZQB0AGUALQBNAGUAZABpAHUAbQBEAE8AVAAgAEMATwBMAE8ATgBTAG8AcgBhACAAUwBhAGcA
YQBuAG8AaAB0AHQAcAA6AC8ALwBkAG8AdABjAG8AbABvAG4ALgBuAGUAdABTAEkATAAgAE8AcABlAG4AIABGAG8A
bgB0ACAATABpAGMAZQBuAHMAZQAsACAAVgBlAHIAIAAxAC4AMQBoAHQAdABwAHMAOgAvAC8AcwBjAHIAaQBwAHQA
cwAuAHMAaQBsAC4AbwByAGcALwBjAG0AcwAvAHMAYwByAGkAcAB0AHMALwBwAGEAZwBlAC4AcABoAHAAPwBzAGkA
dABlAF8AaQBkAD0AbgByAHMAaQAmAGkAZAA9AE8ARgBMAE0AZQBsAGUAdABlAE0AZQBkAGkAdQBtAAAAAAIAAAAD
AAAAFAADAAEAAAAUAAQA0gAAACQAIAAEAAQAIwAqAC8AOQA7AEAAWgBfAHoAfgCgAKYAtyAZIB0gIiAm//8AAAAg
ACUALAAwADoAPwBBAFsAYQB7AKAApgC3IBggHCAiICb//wAAAAAAAAAIAAsAAP/BAAD/vQAA/2H/u/+T4ELgPOAp
4CEAAQAkACoANAAAAAAANgAAADYAAAA8AAAAAAAAAAAAAAAAAAAAAAABAEgAXABNAGQAXwBdAFIAUwBMAEQAUABD
AE4ASQBeAFYATwBXAGMAUQBUAGAAVQBiAAAAAwAAAAAAAP84AGQAAAAAAAAAAAAAAAAAAAAAAAAAAAEABAIAAQEB
Dk1lbGV0ZS1NZWRpdW0AAQEBOB6gAF+Lix6gAF+LiwwH+B4A+B8B+CAC+BcE+44MA+8MBPdO/CQcDDMcBnUF9y8P
96IRpxwOEhIABgEBBw0WHTE+QS5zYWx0Ui5zYWx0Zm91ci5zYWx0MDAwLjIwMFwoY1wpMjAyMiBET1QgQ09MT04u
TWVsZXRlIE1lZGl1bQAAAQABAAAiGQGHAQBCGQARCQGJAAAPAAANAAAbAQB5AAACAAAgAAByAAB0AAALAAAEAAAQ
AAA9AAAOAABAAAAJAQBcAABeAAA8AAA+AABpAAB3AABBAAAIAAADAABoAAAhAAAHAABdAACgAABfAAA/AAAGAABl
AgABAKkArQDPAPwA/wEiAUcBXgFwAYsBlQGzAdoB6gIUAjYCOAI7AlgCiwKOAqECvgLdAuEC5QMJAwwDLgNhA6wD
zwPSA/UELgRZBJMEqgTGBOwFFAUvBT8FUgVUBVcFfQWXBZoFwQXdBgAGBAYIBiwGLwZnBnUGoQbFBugHCgdFB2QH
jgfJB+sH9AgGCBUIKghCCF0IkQihCLEI/QltCYcJnAmoCbYJ3AoICjQKaAqACpgKqwqvCrUKugq+CsMLNwtrC3wL
mAvNC/AMNhz45/nIJwr9Dhz4MPkOBvx69x4VzQf3IOkF+yDN9+BJSwb7IC0F92BJBvvg96QV93b34Pt2B/vg9+4V
93bN+zT3XOlJXUf3BPdc+3YH++D3ohXP9573GM37XAf74PcGFc33GNX7GM334En7GPsgB/tc95gV92T3XPsg9xhH
B/vg95gVzfcY1fsWzffeSfsYQfcYSQf7nhz7YBX3XOn7XAb6FgTN00kGDhz52g73JhwJGBb3wbIG/oEcBVEF+7IG
/oAoCmT3vwf54hwEdQUOQfiUFhwFlikK+1v3VQY4Cv3n+5H5qwb3HaIjCvs0/jz7khwFSwdhChz6pgYO60UK3BwH
qCAKHPpa+5EcBWoG9xyjIwr80jkKHPqW+5EcBaZSCg6f+OBACvjw95IH/P/9zxUcBqX3kRz5Wwb6EgQcBo33kRz5
cwYO+xM8Cveh+NH4nveS/J731BwF+veRBw73IUsK+dT+LPuS+RT72f71Tgr3pCYK+NYcBWf81vesHAV4+6z8zBz6
mfjMBw4c+pEmChwFeAcOhBwHpSAK/m8lCv44LAr3sfur+9IkCvqvKgr6kAcOWiYKHAV4B+f9ahX6o/02BfgQsgb+
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
AAEAAwACABMAPAAA
'@

try {
    Add-Type -AssemblyName System.Drawing
    $script:meleteFontBytes = [Convert]::FromBase64String($script:meleteFontBase64)
    $script:meleteFontCollection = New-Object System.Drawing.Text.PrivateFontCollection

    $meleteMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($script:meleteFontBytes.Length)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy(
            $script:meleteFontBytes,
            0,
            $meleteMem,
            $script:meleteFontBytes.Length
        )
        $script:meleteFontCollection.AddMemoryFont($meleteMem, $script:meleteFontBytes.Length)
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($meleteMem)
    }

    if ($script:meleteFontCollection.Families.Count -gt 0) {
        $script:meleteFontFamily = $script:meleteFontCollection.Families[0]
    }
} catch {
    $script:meleteFontFamily = $null
} finally {
    $script:meleteFontBase64 = $null
    $script:meleteFontBytes = $null
}


# -----------------------------------------------------------------------------
#  SYNE BOLD (HIGH only)
#  Uses the user-provided LT Avocado font privately from memory so no
#  system-wide installation is required.
# -----------------------------------------------------------------------------
$script:theNeueFontCollection = $null
$script:theNeueFontFamily = $null
$script:theNeueFontBytes = $null
$script:theNeueFontBase64 = @'
AAEAAAARAQAABAAQR0RFRkSCRMgAAR/oAAABQEdQT1OSSodKAAEhKAAAQMpHU1VCAfaMxQABYfQAAA+yT1MvMoLQZpwAAAGYAAAA
YGNtYXDM2dacAAANFAAABTZjdnQgHJMJoAAAIRgAAABwZnBnbWIu/30AABJMAAAODGdhc3AAAAAQAAEf4AAAAAhnbHlm0WF7rQAA
JxgAANxKaGVhZB2lSSwAAAEcAAAANmhoZWEIkgVLAAABVAAAACRobXR4EWSJGwAAAfgAAAscbG9jYeF1GE0AACGIAAAFkG1heHAE
Nw9kAAABeAAAACBuYW1lfECg8QABA2QAAASIcG9zdF9b9+kAAQfsAAAX8nByZXDftmJDAAAgWAAAAL0AAQAAAAIzM4uM9EhfDzz1
AA8D6AAAAADbSI4NAAAAAN5FRFf/Vv79BZwDtQABAAYAAgAAAAAAAAABAAADnf7tAAAF0/9W/cMFnAABAAAAAAAAAAAAAAAAAAAC
xwABAAACxwCjABEAXgAFAAIAKABUAI0AAACgDgwABAABAAQCrAK8AAUAAAKKAlgAAABLAooCWAAAAV4ASwEqAAAAAAAAAAAAAAAA
oAAA71AAIHsAAAAAAAAAAE5PTkUAoAAN+wEDnf7tAAADuwHvIAAAmwAAAAAB8QKHAAAAIAADAcgAYQMVABEDFQARAxUAEQMVABED
FQARAxUAEQMVABEDFQARAxUAEQMVABEEhgARAwwATQN1ADUDdQA1A3UANQN1ADUDdQA1A28ATQNv//sDbwBNA2//+wMBAE0DAQBN
AwEATQMBAE0DAQBNAwEATQMBAE0DAQBNAwEATQLlAE0DkgA1A5IANQOSADUDkgA1A38ATQN/ACUBRABgAvIAYAFEAFwBRP+7AUT/
6gFEAFcBRP+yAUQACQFE/+4CqwAaAy4ATQMuAE0CrwBNAq8ASQKvAE0CrwBNAq8ATQKv/+EESwBNA4UATQOFAE0DhQBNA4UATQOF
AE0DhQBNA5wANQOcADUDnAA1A50ANQOcADUDnAA1A5wANQOcADUDnAA1A5wANQT9ADUDEABLAvcASwOcADUDOgBNAzoATQM6AE0D
OgBNArYAHwK2AB8CtgAfArYAHwK2AB8C0gAUAtIAFALSABQC0gAUAtIAFANxAE0DcQBNA3EATQNxAE0DcQBNA3EATQNxAE0DcQBN
A3EATQMHABQFFAAUBRQAFAUUABQFFAAUBRQAFAMMACcC5AATAuQAEwLkABMC5AATAuQAEwM1AD8DNQA/AzUAPwM1AD8DFQARAxUA
EQMVABEDFQARAxUAEQMVABEDFQARAxUAEQN1ADUDdQA1A3UANQN1ADUDbwBNAwEATQMBAE0DAQBNAwEATQMBAE0DAQBNA5IANQOS
ADUDkgA1AUQAVwFEAFcBRABXAUQAVwFEAFYDLgBNAq8ARAKvAE0CrwBNA4UATQOFAE0DhQBNA4UATQOcADUDnAA1A5wANQOcADUD
nAA1A5wANQM6AE0DOgBNAzoATQK2AB8CtgAfArYAHwK2AB8C0gAUAtIAFALSABQDcQBNA3EATQNxAE0DcQBNA3EATQNxAE0DcQBN
BRQAFAUUABQFFAAUAuQAEwLkABMC5AATAzUAPwM1AD8FKgAUAtMAJALTACQC0wAkAtMAJALTACQC0wAkAtMAJALTACQC0wAkAtMA
JATyACQC6ABQAq4AJAKuACQCrgAkAq4AJAKuACQC6QAkArQAJALpACQC6QAkAqYAJAKmACQCpgAkAqYAJAKmACQCpgAkAqYAJAKm
ACQCpgAkAb4AGQKfACQCnwAkAp8AJAKfACQCvgBFAr4AAAEMADoA9wA6APcANQD3/5QA9//nAPcAMAD3/4sCGAA6APf/4gEMAAMB
DAA6AokARQKJAEUBDwBGAQ8ARgGkAEYBDwA7AckARgEk/+wEZwA8ArUAPAK1ADwCtQA8ArUAPAK1ADwCtQA8AsAAJALAACQCwAAk
AsAAJALAACQCwAAkAsAAJALAACQCwAAkBJwAJALUADwC1AA8AukAJAGRADwBkQA8AZEADAGRADECNAAlAjQAJQI0ACUCNAAmAjQA
JQLJAEUBsgAZAbEAGAGxABkBsgAZAbIAGQK1ADwCtQA8ArUAPAK1ADwCtQA8ArUAPAK1ADwCtQA8ArUAPAJzAA8D3AAPA9wADwPc
AA8D3AAPA9wADwKRABQCfwAPAn8ADwJ/AA8CfwAPAn8ADwJuADkCbgA5Am4AOQJuADkC0wAkAtMAJALTACQC0wAkAtMAJALTACQC
0wAkAtMAJAKuACQCrgAkAq4AJALpACQCpgAkAqYAJAKmACQCpgAkAqYAJAKmACQCnwAkAp8AJAD3ADAA9wAwAPcAMAD3ADABDAA6
AokARQEPAEEBpQBGAQ8APQK1ADwCtQA8ArUAPAK1ADwCwAAkAsAAJALAACQCwAAkAsAAJALAACQBkQA8AZEAPAGRADMCNAAlAjQA
JQI0ACUCNAAlAbIAGQGyABkBsgAZArUAPAK1ADwCtQA8ArUAPAK1ADwCtQA8ArUAPAPcAA8D3AAPA9wADwJ/AA8CfwAPAn8ADwJu
ADkCbgA5ArgAIwK4ACMCuAAjArgAIwM9ABkERQAZAsoAGQK2ABkD8gAZAqIAJALAAEYDFQARAwwATQKsAE0DFQARAwEATQL5AD8D
fwBNA5wANQFEAGADLgBNAxUAEQRLAE0DhQBNAwAAPAOcADUDfwBNAxAASwMlAE0C0gAUAuQAEwPYADUDDAAnA7oARANoACMDWgAB
BBwAAASaAAACXwAABF0AAAQTAAAEEAAAAUT/6gLkABMC0wAkAtQAPAJzAA8CtwAkArAALwIjADICtQA8AuUALgFAADwCgAA8AnMA
EAL3ADwCcwAPAgkALgLAACQDDwAyAtQAPAKuACQCwAAkAc8AHgK4ADwDngAtApEAFANsADwDuAAkAUAANwFA/8oBQP9hArgAPAK4
ADwCuAAsAsAAJAO4ACQC0wAkArAALwK1ADwCrgAkAq4AJALiADUBhgAZAnAAHwKBACECxwAvAq0AOgKxABoCgwAhAqMAKgK5ACQD
AwA1AYMAHAKYACYCgwAiAscALwK1ADkCugAaAmcAFAKYACQCwAAkAsAAJAGDABkCkQA2AoEAIQLHAC8CtwA6ArEAGgKDACECowAq
ArkAJALEACkCxABZAsQASQLEAEMCxAAqAsQARALEACsCxABEAsQAPwLEADMCxAAsAsQAZwLEAEgCxABBAsQAJgLEAEECxAAzAsQA
QALEAEACxAAzAeMAJAGlABkBqAAfAasAIAHFAC8B0gA6AbMAGwGAABcBugAqAbUAJAHjACQBpQAZAagAHwGrACABxQAvAdIAOgGz
ABsBgAAXAboAKgG1ACQAVP9WA8MAGQPiACQDxgAZA9gAHwOWABkDhwAgA+0AGQP/AB8D3gAgBAUALwOoABkDswA6A9MAGQPVABkD
xgAgA+AAOgNwABcD0AAZBdMAGQBU/1YA9wAoAU0ALQFIAC8BOgAoAlgAAADxAAAA8QAAAQ8APAERADwDVQAfAQ8APADnACcBKwBD
AREAPAKzADwBMQBNATEATQJyADMCcQA0AQ8APAHIAGEB9wApA40AQwHhACQB4QAkATEATQExAE0CRQApAlYANAHuAFACWABQAlwA
UANMADwDUQBHAVAANQFQADUB4wAxAeMAWQGYAFkBmgA8AVAANQFQADUA5wAnAa0AJwGtACcBrQAnAOcAJwDnACcCSAAwAk4AUAGn
ADwBpwAyAZ4AJwDmACcDiQAlA1wAHgQxADQDCwAkAt8AHgI1ACID9gA1A80ANQRbAE0BwAAvAUMAZAFDAGQC+wBgAtwAUAMVAE0D
IgA1A38ATQKuACQCogBLAi8AIAPEABQCkgAiAuQAEwGyAAACMAAyAeoAMgH0ADsCEgAyAkoAMgJKADICGgBeAhQAPQIfAF4CRgBq
AjAAMgJuADABNwBQAtMAVQJLANoDHAA8BFAANQH4ABcDWQAoAtcAVAMnAA8C6QA8Ar4AJAO0ACgEHQAoAr8AWwMcAGQDaQAoAxwA
ZAK/AFoDHABkA2kAPAMcAGQEMgA8Ar8AWgK0ADIB5ABfAmAAAAAAAFAAAABLAAAAZAAAAF8AAABkAAAAjwAAAGcAAABrAAAAbQAA
AGcAAABVAAAAZAAAAOgAAAAeAAAAaQAAAGQAAABLAAAASwAAAEsAAABLAAAASwAAAEsAAABEAAAAQQAAAEsAAABLAAAASwAAAEsA
AABLAAAASwAAAOkAAABBAAAASwAAAEsCHQBQATAASwH8AGQB5ABfAn4AZAKcAGcClgBrAn8AbQHqAGcCoQBVAfsAZAH/AGkBpgBk
AS0ASwEwAFUCHQBQATAAVQEtAEsCVADfAS0ASwJUAN8BMABNATAASwEwAEsCWAA2AAAAAgAAAAMAAAAUAAMAAQAAABQABAUiAAAA
igCAAAYACgANAC8AOQB+AQcBEwEbASMBJwErATMBNwFIAU0BWwFnAWsBfgGSAhsCLgLHAt0DBAMIAwwDEgMoAzgDfgOKA4wDkAOh
A6kDsAPJA84ehR7zIBQgGiAeICIgJiAwIDogRCB0IKwhIiFeIYkhmSICIgUiDyISIhUiGiIeIisiSCJgImUlyvj/+wH//wAAAA0A
IAAwADoAoAEKARYBHgEmASoBLgE2ATkBSgFQAV4BagFuAZICGAIuAsYC2AMAAwYDCgMSAyYDNQN+A4QDjAOOA5EDowOqA7EDyh6A
HvIgEyAYIBwgICAmIDAgOSBEIHQgrCEiIVAhiSGQIgIiBSIPIhEiFSIaIh4iKyJIImAiZCXK+P/7Af//Ag8AAAGNAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAALwAAP4V/+0AAAAAAAAAAP+G/3P/Z/6iAAD+BgAA/eX95AAA/eYAAAAAAADiJAAAAAAAAOIA
4k7iEeG/4afhtuE0AADgfAAA4HrgcOBpAADgUOBg4FjgTOAp4AsAANy/CVAGcAABAAAAiAAAAKQBLAH6AgwCFgIgAiICJAIuAjAC
TgJUAmoCfAJ+AAACnAAAAAACngKoArACtAAAAAAAAAAAArAAAAK6AAAAAAK6AAACxALMAtYAAALWAtoC3gAAAAAAAAAAAAAAAAAA
AtQAAALuAAAAAAAAAvoAAAAAAAAAAAAAAAAC8AAAAAAAAAAAAh0CJwJMAi4CYQJ9AlECTQI6AjsCLQJmAiMCNQIiAi8CJAIlAm0C
agJsAikCUAABAAwADQASABYAHwAgACQAJgAvADAAMgA4ADkAPwBKAEwATQBRAFYAWwBkAGUAagBrAHACPgIwAj8CdAI5ArAAtwDC
AMMAyADMANUA1gDaANwA5gDnAOkA7wDwAPYBAAECAQMBBwENARIBGwEcASEBIgEnAjwCWAI9AnICHgIoAl8CYwJgAmQCWQJTAq4C
VAF0AkgCcwI2AlUCuAJXAnACGQIaArECewJSAisCuQIYAXUCSQIIAgQCCQIqAAYAAgAEAAoABQAJAAsAEAAcABcAGQAaACwAKAAp
ACoAEwA9AEQAQABBAEgAQgJoAEcAXwBcAF0AXgBsAEsBDAC8ALgAugDAALsAvwDBAMYA0gDNAM8A0ADiAN4A3wDgAMkA9AD6APcA
+AD+APkCaQD9ARYBEwEUARUBIwEBASUABwC9AAMAuQAIAL4ADgDEABEAxwAPAMUAFADKABUAywAdANMAGwDRAB4A1AAYAM4AIQDX
ACMA2QAiANgAJQDbAC0A5AAuAOUAKwDdACcA4wAxAOgAMwDqADUA7AA0AOsANgDtADcA7gA6APEAPADzADsA8gA+APUARgD8AEUA
+wBJAP8ATgEEAFABBgBPAQUAUgEIAFQBCgBTAQkAWQEQAFgBDwBXAQ4AYQEYAGMBGgBgARcAYgEZAGcBHgBtASQAbgBxASgAcwEq
AHIBKQBVAQsAWgERArUCrwK2AroCtwKyAo4CjwKSApYClwKUAo0CjAKVApACkwKKAosBjgIfAY8BkAGRAZMBlAGyAZUBlgG4AbkB
ugGwAbUBsQG0AbYBswG3AGkBIABmAR0AaAEfAG8BJgJGAkcCQgJEAkUCQwJaAlsCLAIQAhUCFgIGAgcCCgILAgwCDQIOAg8CEQIS
AhMCFAKFAn8CgQKDAocCiAKGAoACggKEAnkCZwJvAm4AALAALCCwAFVYRVkgIEu4AA5RS7AGU1pYsDQbsChZYGYgilVYsAIlYbkI
AAgAY2MjYhshIbAAWbAAQyNEsgABAENgQi2wASywIGBmLbACLCMhIyEtsAMsIGSzAxQVAEJDsBNDIGBgQrECFENCsSUDQ7ACQ1R4
ILAMI7ACQ0NhZLAEUHiyAgICQ2BCsCFlHCGwAkNDsg4VAUIcILACQyNCshMBE0NgQiOwAFBYZVmyFgECQ2BCLbAELLADK7AVQ1gj
ISMhsBZDQyOwAFBYZVkbIGQgsMBQsAQmWrIoAQ1DRWNFsAZFWCGwAyVZUltYISMhG4pYILBQUFghsEBZGyCwOFBYIbA4WVkgsQEN
Q0VjRWFksChQWCGxAQ1DRWNFILAwUFghsDBZGyCwwFBYIGYgiophILAKUFhgGyCwIFBYIbAKYBsgsDZQWCGwNmAbYFlZWRuwAiWw
DENjsABSWLAAS7AKUFghsAxDG0uwHlBYIbAeS2G4EABjsAxDY7gFAGJZWWRhWbABK1lZI7AAUFhlWVkgZLAWQyNCWS2wBSwgRSCw
BCVhZCCwB0NQWLAHI0KwCCNCGyEhWbABYC2wBiwjISMhsAMrIGSxB2JCILAII0KwBkVYG7EBDUNFY7EBDUOwA2BFY7AFKiEgsAhD
IIogirABK7EwBSWwBCZRWGBQG2FSWVgjWSFZILBAU1iwASsbIbBAWSOwAFBYZVktsAcssAlDK7IAAgBDYEItsAgssAkjQiMgsAAj
QmGwAmJmsAFjsAFgsAcqLbAJLCAgRSCwDkNjuAQAYiCwAFBYsEBgWWawAWNgRLABYC2wCiyyCQ4AQ0VCKiGyAAEAQ2BCLbALLLAA
QyNEsgABAENgQi2wDCwgIEUgsAErI7AAQ7AEJWAgRYojYSBkILAgUFghsAAbsDBQWLAgG7BAWVkjsABQWGVZsAMlI2FERLABYC2w
DSwgIEUgsAErI7AAQ7AEJWAgRYojYSBksCRQWLAAG7BAWSOwAFBYZVmwAyUjYUREsAFgLbAOLCCwACNCsw0MAANFUFghGyMhWSoh
LbAPLLECAkWwZGFELbAQLLABYCAgsA9DSrAAUFggsA8jQlmwEENKsABSWCCwECNCWS2wESwgsBBiZrABYyC4BABjiiNhsBFDYCCK
YCCwESNCIy2wEixLVFixBGREWSSwDWUjeC2wEyxLUVhLU1ixBGREWRshWSSwE2UjeC2wFCyxABJDVVixEhJDsAFhQrARK1mwAEOw
AiVCsQ8CJUKxEAIlQrABFiMgsAMlUFixAQBDYLAEJUKKiiCKI2GwECohI7ABYSCKI2GwECohG7EBAENgsAIlQrACJWGwECohWbAP
Q0ewEENHYLACYiCwAFBYsEBgWWawAWMgsA5DY7gEAGIgsABQWLBAYFlmsAFjYLEAABMjRLABQ7AAPrIBAQFDYEItsBUsALEAAkVU
WLASI0IgRbAOI0KwDSOwA2BCIGC3GBgBABEAEwBCQkKKYCCwFCNCsAFhsRQIK7CLKxsiWS2wFiyxABUrLbAXLLEBFSstsBgssQIV
Ky2wGSyxAxUrLbAaLLEEFSstsBsssQUVKy2wHCyxBhUrLbAdLLEHFSstsB4ssQgVKy2wHyyxCRUrLbArLCMgsBBiZrABY7AGYEtU
WCMgLrABXRshIVktsCwsIyCwEGJmsAFjsBZgS1RYIyAusAFxGyEhWS2wLSwjILAQYmawAWOwJmBLVFgjIC6wAXIbISFZLbAgLACw
DyuxAAJFVFiwEiNCIEWwDiNCsA0jsANgQiBgsAFhtRgYAQARAEJCimCxFAgrsIsrGyJZLbAhLLEAICstsCIssQEgKy2wIyyxAiAr
LbAkLLEDICstsCUssQQgKy2wJiyxBSArLbAnLLEGICstsCgssQcgKy2wKSyxCCArLbAqLLEJICstsC4sIDywAWAtsC8sIGCwGGAg
QyOwAWBDsAIlYbABYLAuKiEtsDAssC8rsC8qLbAxLCAgRyAgsA5DY7gEAGIgsABQWLBAYFlmsAFjYCNhOCMgilVYIEcgILAOQ2O4
BABiILAAUFiwQGBZZrABY2AjYTgbIVktsDIsALEAAkVUWLEOBkVCsAEWsDEqsQUBFUVYMFkbIlktsDMsALAPK7EAAkVUWLEOBkVC
sAEWsDEqsQUBFUVYMFkbIlktsDQsIDWwAWAtsDUsALEOBkVCsAFFY7gEAGIgsABQWLBAYFlmsAFjsAErsA5DY7gEAGIgsABQWLBA
YFlmsAFjsAErsAAWtAAAAAAARD4jOLE0ARUqIS2wNiwgPCBHILAOQ2O4BABiILAAUFiwQGBZZrABY2CwAENhOC2wNywuFzwtsDgs
IDwgRyCwDkNjuAQAYiCwAFBYsEBgWWawAWNgsABDYbABQ2M4LbA5LLECABYlIC4gR7AAI0KwAiVJiopHI0cjYSBYYhshWbABI0Ky
OAEBFRQqLbA6LLAAFrAXI0KwBCWwBCVHI0cjYbEMAEKwC0MrZYouIyAgPIo4LbA7LLAAFrAXI0KwBCWwBCUgLkcjRyNhILAGI0Kx
DABCsAtDKyCwYFBYILBAUVizBCAFIBuzBCYFGllCQiMgsApDIIojRyNHI2EjRmCwBkOwAmIgsABQWLBAYFlmsAFjYCCwASsgioph
ILAEQ2BkI7AFQ2FkUFiwBENhG7AFQ2BZsAMlsAJiILAAUFiwQGBZZrABY2EjICCwBCYjRmE4GyOwCkNGsAIlsApDRyNHI2FgILAG
Q7ACYiCwAFBYsEBgWWawAWNgIyCwASsjsAZDYLABK7AFJWGwBSWwAmIgsABQWLBAYFlmsAFjsAQmYSCwBCVgZCOwAyVgZFBYIRsj
IVkjICCwBCYjRmE4WS2wPCywABawFyNCICAgsAUmIC5HI0cjYSM8OC2wPSywABawFyNCILAKI0IgICBGI0ewASsjYTgtsD4ssAAW
sBcjQrADJbACJUcjRyNhsABUWC4gPCMhG7ACJbACJUcjRyNhILAFJbAEJUcjRyNhsAYlsAUlSbACJWG5CAAIAGNjIyBYYhshWWO4
BABiILAAUFiwQGBZZrABY2AjLiMgIDyKOCMhWS2wPyywABawFyNCILAKQyAuRyNHI2EgYLAgYGawAmIgsABQWLBAYFlmsAFjIyAg
PIo4LbBALCMgLkawAiVGsBdDWFAbUllYIDxZLrEwARQrLbBBLCMgLkawAiVGsBdDWFIbUFlYIDxZLrEwARQrLbBCLCMgLkawAiVG
sBdDWFAbUllYIDxZIyAuRrACJUawF0NYUhtQWVggPFkusTABFCstsEMssDorIyAuRrACJUawF0NYUBtSWVggPFkusTABFCstsEQs
sDsriiAgPLAGI0KKOCMgLkawAiVGsBdDWFAbUllYIDxZLrEwARQrsAZDLrAwKy2wRSywABawBCWwBCYgICBGI0dhsAwjQi5HI0cj
YbALQysjIDwgLiM4sTABFCstsEYssQoEJUKwABawBCWwBCUgLkcjRyNhILAGI0KxDABCsAtDKyCwYFBYILBAUVizBCAFIBuzBCYF
GllCQiMgR7AGQ7ACYiCwAFBYsEBgWWawAWNgILABKyCKimEgsARDYGQjsAVDYWRQWLAEQ2EbsAVDYFmwAyWwAmIgsABQWLBAYFlm
sAFjYbACJUZhOCMgPCM4GyEgIEYjR7ABKyNhOCFZsTABFCstsEcssQA6Ky6xMAEUKy2wSCyxADsrISMgIDywBiNCIzixMAEUK7AG
Qy6wMCstsEkssAAVIEewACNCsgABARUUEy6wNiotsEossAAVIEewACNCsgABARUUEy6wNiotsEsssQABFBOwNyotsEwssDkqLbBN
LLAAFkUjIC4gRoojYTixMAEUKy2wTiywCiNCsE0rLbBPLLIAAEYrLbBQLLIAAUYrLbBRLLIBAEYrLbBSLLIBAUYrLbBTLLIAAEcr
LbBULLIAAUcrLbBVLLIBAEcrLbBWLLIBAUcrLbBXLLMAAABDKy2wWCyzAAEAQystsFksswEAAEMrLbBaLLMBAQBDKy2wWyyzAAAB
QystsFwsswABAUMrLbBdLLMBAAFDKy2wXiyzAQEBQystsF8ssgAARSstsGAssgABRSstsGEssgEARSstsGIssgEBRSstsGMssgAA
SCstsGQssgABSCstsGUssgEASCstsGYssgEBSCstsGcsswAAAEQrLbBoLLMAAQBEKy2waSyzAQAARCstsGosswEBAEQrLbBrLLMA
AAFEKy2wbCyzAAEBRCstsG0sswEAAUQrLbBuLLMBAQFEKy2wbyyxADwrLrEwARQrLbBwLLEAPCuwQCstsHEssQA8K7BBKy2wciyw
ABaxADwrsEIrLbBzLLEBPCuwQCstsHQssQE8K7BBKy2wdSywABaxATwrsEIrLbB2LLEAPSsusTABFCstsHcssQA9K7BAKy2weCyx
AD0rsEErLbB5LLEAPSuwQistsHossQE9K7BAKy2weyyxAT0rsEErLbB8LLEBPSuwQistsH0ssQA+Ky6xMAEUKy2wfiyxAD4rsEAr
LbB/LLEAPiuwQSstsIAssQA+K7BCKy2wgSyxAT4rsEArLbCCLLEBPiuwQSstsIMssQE+K7BCKy2whCyxAD8rLrEwARQrLbCFLLEA
PyuwQCstsIYssQA/K7BBKy2whyyxAD8rsEIrLbCILLEBPyuwQCstsIkssQE/K7BBKy2wiiyxAT8rsEIrLbCLLLILAANFUFiwBhuy
BAIDRVgjIRshWVlCK7AIZbADJFB4sQUBFUVYMFktAEu4AMhSWLEBAY5ZsAG5CAAIAGNwsQAHQrQALR0DACqxAAdCtzIEIggSCAMK
KrEAB0K3NgIqBhoGAwoqsQAKQrwMwAjABMAAAwALKrEADUK8AEAAQABAAAMACyq5AAMAAESxJAGIUViwQIhYuQADAGREsSgBiFFY
uAgAiFi5AAMAAERZG7EnAYhRWLoIgAABBECIY1RYuQADAABEWVlZWVm3NAIkBhQGAw4quAH/hbAEjbECAESzBWQGAEREAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAhACEAGMAYwKH//QCuQHx//T/OAKU//MCxQH8//T/OACEAIQAYwBjAocAAAK5
AfEAAP84ApT/8wK5Afz/9P84ABgAGAAYABgCxgGQAsYBfgAAAAgAOABKAFoAagCEAJQApgECARQBJAFoAbwCAgIUAiYCugLMAwgD
GgMsAz4DbgOAA5ADoAOyA8QD1APmBEYEcATkBPYFAgUUBTwFgAWWBfoGCgYcBiwGPAZOBl4GnAbwBxoHJgdGB1YHYgduB4AHkgfC
B+wH/ggOCBoIKghyCLoIzAjeCPgJCgkcCS4JQAlSCWQKBgpGCoQK0AsYCyoLOgtMC6QLtgvIDHAMggyiDNQM5A02DUINdg2IDZgN
qg26DcwN3g4oDjoOXg6QDqIOtA7ODuAPEA84D0oPWg9qD3oPpg+4D8oP3A/uEAAQEhAkEDYQSBBaEGwQfhCQEJwQrhDAENIQ5BD2
EQgRGhEmETgRRBFWEWYRdhGGEZYRohGuEb4RyhHWEegR+hIGEhgSKhI8Ek4SYBJyEoQSlhKoEroSzBLeEvATAhMUEyATLBM+E1AT
YhN0E4YTmBOqE7wTzhPgE/IUBBQWFCgUOhSEFP4VChUWFSIVLhU6FUYWABYMFhgXBheEF84X2hfmGFwYaBjmGUQZUBliGa4ZuhnG
GdIZ3hnqGfYaAhqIGrwbcht+G4oblhvQG+IcGBwuHEAcUhyUHKYcuBzEHNYdPh10HaIdrh3EHdYd4h3uHgAeKh6OHtYe4h7uHvof
Bh90H7wfyB/UH+Af7B/4IAQgcCB8IIgg8iFIIbAh7CH4IgQiECJ8IogilCM0I0YjuiPyJD4kjCT+JQolVCVgJWwleCWEJZAlnCYC
Jg4mMiZiJm4meiaGJpImuibcJugm9CcAJwwnOCdEJ1AnXCdoJ3QngCeMJ5gnpCewJ7wnyCfUJ+Yn8if+KAooFigiKC4oOihGKFIo
ZCh2KIgomiimKLIoxCjQKNwo6Cj0KQApDCkYKSQpMCk8KUgpVClgKWwpeCmEKZApoim0KcYp0ineKeop9ioCKg4qGiomKjIqPipK
KlYqYipuKnoqhiqSK5IrniuqK7YsOCzCLRItfC3KLjwueC6ALogusi7oLvAvKi8yL4gvkC+YL8gv0C/YMBowIjBQMFgwmDCgMKgx
CjESMWAxwjHUMeYx+DIKMhwyLjJAMlAyYDLeM2AziDPqNFo0mDT2NUg1ZjWeNeQ17DX0Nkw2VDaYNug3Kjd0N543zDgcOEY4eDji
OO45CDkaOSY5QDlQOVw5aDl0OYA5jDneOeo58jn6OgI6CjoSOho6IjoqOjI6OjqEOqQ66jtMO4I74Dw4PF48yj0gPWg9iD3KPio+
cj7OPyY/TD+4QA5AUkB2QH5AhkCOQOxBRkFOQVZBsEHyQhZCHkImQi5CikLkQwpDEkNsQ6hDzEQaRJZExkUYRXpFnkYARk5Gikau
RvxHkkfUSCZIhkiqSSJJhEmWSaZJtknGSdZJ5kn2SgZKFkomSjZKRkpWSmZKdkqGSpZKpkq2SspK3EsYS2hMCkxOTE5MTkxOTF5M
dEzyTQpNKE06TVBNYE2UTbxORk64TsZO4E8MT3BPgk+WT7xP4lA0UNxQ9lD+URhRMlFQUXhRnlIEUmpSoFLSUvpTIFMoU0BTTFNY
U3hTmFO4U9hT7FQCVA5UKlTyViBXEle+WABYwFlGWhZaYFqiWrxa6FsQW0pbgFwQXR5dgF3kXlJetF8YX1RfXl+GX6BfvF/0YBhg
UmBoYIBgrGDYYSZhyGHWYgZiFmJ+YwBjNmNeY45jvmRMZKZlImXMZfRmImZOZoBmombSZv5nLmdqZ5JnrmfMaBxoSGhoaIZopGjS
aO5pFGk6aWxprmn0ahRqNmpaaqBqzmrsawprHGsua1Jremuwa8pr8mwabEJsamySbLps4mz6bRJtKm1CbUptUm1abWJtam1ybXpt
gm2KbZJtmm2ibaptum3CbdJt2m3obfBt+m4CbgpuEm4l//8AYQCDAWcBiQIGAiwAAAACABEAAAMEAocABwAKACxAKQoBBAABTAAE
AAIBBAJoAAAAJE0FAwIBASUBTgAACQgABwAHERERBggZKzMBMwEjJyEHNzMDEQEwkAEzkUD+rkBy7XcCh/15jY38AQUAAP//ABEA
AAMEA3MCJgABAAABBwKPAOUAfAAIsQIBsHywNSsAAP//ABEAAAMEA1YCJgABAAABBgKUS3wACLECAbB8sDUr//8AEQAAAwQDcwIm
AAEAAAEGApI8fAAIsQIBsHywNSv//wARAAADBAKOAiYAAQAAACcCIgABAhwBBwIiAgcCHAASsQIBuAIcsDUrsQMBuAIcsDUr//8A
EQAAAwQDcwImAAEAAAEGAo42fAAIsQIBsHywNSv//wARAAADBAMuAiYAAQAAAQcClwCNAHwACLECAbB8sDUrAAAAAgAR/ygDBAKH
ABQAFwBlQAoXAQYAEQEBBAJMS7AfUFhAHwAGAAQBBgRoAAAAJE0HBQIBASVNAAICA2EAAwMpA04bQBwABgAEAQYEaAACAAMCA2UA
AAAkTQcFAgEBJQFOWUAQAAAWFQAUABQWERUREQgIGyszATMBIwYGFRQWMxUiJjU0NjcnIQc3MwMRATCQATNOHSRCN2Z4Mys7/q5A
cu13Aof9eQkjHCQnRUM6KDAOgo38AQUA//8AEQAAAwQDnAImAAEAAAEHApUAlQB8AAixAgKwfLA1KwAA//8AEQAAAwQDYAImAAEA
AAEGApY6fAAIsQIBsHywNSsAAgARAAAESgKHAA8AEgBCQD8SAQYFAUwABgkBBwgGB2cACAACAAgCZwAFBQRfAAQEJE0AAAABXwMB
AQElAU4AABEQAA8ADxEREREREREKCB0rARUhFSE1IwcjASEVIRUhFQUzEQJXAfP9iNNfjwF/Arn+DgGY/UmaAQ6fb6SkAodvoWkI
AQsAAAMATQAAAuMChwAQABkAIwA5QDYIAQUCAUwAAgAFBAIFZwADAwBfAAAAJE0ABAQBXwYBAQElAU4AACMhHBoZFxMRABAADyEH
CBcrMxEhMhYVFAYHHgIVFAYGBwEzMjY1NCYjIxEhMjY1NCYmIyNNAXWCh1pONlczQHJL/uzrP0REOPIBBj9EKEIm+QKHV1ZHQgoE
HDw2PE8oAgF1JS0tJf5VKS0hHgcAAAEANf/zA0AClAAbADZAMwACAwUDAgWABgEFBAMFBH4AAwMBYQABASpNAAQEAGEAAAArAE4A
AAAbABskIhImIgcIGyslBgYjIiYmNTQ2NjMyFhcjJiYjIgYVFBYzMjY3A0ANwKN5umhounmkvw2EFHVjfJaWfGN0Fel2gEuVb3CW
TIR2P0hxbmxxRz3//wA1//MDQAN3AiYADQAAAQcCjwEhAIAACLEBAbCAsDUrAAD//wA1//MDQAN3AiYADQAAAQcCkwB7AIAACLEB
AbCAsDUrAAAAAQA1/xEDQAKUADMAlUAMKQwLAwgGBwEACAJMS7AJUFhANAACAwUDAgWAAAUEAwUEfgkBCAYABggAgAAAAAcAB2UA
AwMBYQABASpNAAQEBmEABgYrBk4bQDQAAgMFAwIFgAAFBAMFBH4JAQgGAAYIAIAAAAAHAAdlAAMDAWEAAQEqTQAEBAZhAAYGLgZO
WUARAAAAMwAzJhISJCISLiMKCB4rBR4CMzI2NTQmJic1LgI1NDY2MzIWFyMmJiMiBhUUFjMyNjczBgYHFRYWFRQGIyImJjcBcAIJ
GBccFwkeImmeWGi6eaS/DYQUdWN8lpZ8Y3QVhAymjSAqT08yRyQCdAUUEBgQBxQUBjUJUI5mcJZMhHY/SHFubHFHPW1+CSALKyUq
PyM5H///ADX/8wNAA00CJgANAAABBwKNATAAgAAIsQEBsICwNSsAAAACAE0AAAM6AocADAAXAChAJQADAwBfBAEAACRNAAICAV8A
AQElAU4BABcVDw0LCQAMAQwFCBYrATIeAhUUDgIjIRETMzI2NjU0JiYjIwG/bZJXJSlZkWj+joXqYGssLGtg6gKHNFl0QEB2WzUC
h/3rPGE3N146AP////sAAAM6AocCJgASAAABBgKcsL8ACbECAbj/v7A1KwAAAP//AE0AAAM6A4gCJgASAAABBwKTAE8AkQAIsQIB
sJGwNSsAAP////sAAAM6AocCJgASAAABBgKcsL8ACbECAbj/v7A1KwAAAAABAE0AAALFAocACwAvQCwABAYBBQAEBWcAAwMCXwAC
AiRNAAAAAV8AAQElAU4AAAALAAsREREREQcIGysTFSEVIREhFSEVIRXSAfP9iAJ3/g4BmAEOn28Ch2+haQAAAP//AE0AAALFA3MC
JgAWAAABBwKPAOgAfAAIsQEBsHywNSsAAP//AE0AAALFA3MCJgAWAAABBgKTQnwACLEBAbB8sDUr//8ATQAAAsUDcwImABYAAAEG
ApI/fAAIsQEBsHywNSv//wBNAAACxQNIAiYAFgAAAQcCjACFAHwACLEBArB8sDUrAAD//wBNAAACxQNJAiYAFgAAAQcCjQD3AHwA
CLEBAbB8sDUrAAD//wBNAAACxQNzAiYAFgAAAQYCjjl8AAixAQGwfLA1K///AE0AAALFAy4CJgAWAAABBwKXAJAAfAAIsQEBsHyw
NSsAAAABAE3/IQLFAocAGQBuS7AVUFhAKQAHCQEIAAcIZwAGBgVfAAUFJE0AAAABXwQBAQElTQACAgNhAAMDKQNOG0AmAAcJAQgA
BwhnAAIAAwIDZQAGBgVfAAUFJE0AAAABXwQBAQElAU5ZQBEAAAAZABkREREVERUREQoIHisTFSEVIwYGFRQWMxUiJjU0NjchESEV
IRUhFdIB81ApNUI3ZngtJv5IAnf+DgGYAQ6fbwcmIiQnRUM6JS8OAodvoWkAAAABAE0AAALEAocACQApQCYAAQACAwECZwAAAARf
BQEEBCRNAAMDJQNOAAAACQAJEREREQYIGisBFSEVIRUhESMRAsT+DgGY/miFAodvrmj+/gKHAAABADX/8wNTApQAIgB+tSABBAUB
TEuwE1BYQCcAAgMGAwIGgAAGAAUEBgVnAAMDAWEAAQEqTQAEBABhBwgCAAArAE4bQCsAAgMGAwIGgAAGAAUEBgVnAAMDAWEAAQEq
TQAHByVNAAQEAGEIAQAAKwBOWUAXAQAdHBsaGRgWFBAODAsJBwAiASIJCBYrBSImJjU0NjYzMhYXIyYmIyIGFRQWMzI2NyM1IREj
NDY3BgYBwXezYme6eqS+CoATc2aDj3+JZIUa+AGCcwsHH50NS5RsbphQhnE7SXxnZHRJN1X+xSVjL11nAAD//wA1//MDUwNaAiYA
IAAAAQcClACHAIAACLEBAbCAsDUrAAD//wA1/wcDUwKUAiYAIAAAAAcCmQFbAAD//wA1//MDUwNNAiYAIAAAAQcCjQEwAIAACLEB
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
NjMyFhYVFAYGJzI2NjU0JiYjIgYGFRQWFgHOgbdhYbeBgrZhYbaCUHlFRXlQT3xGRnwNUZZpapZRUZZqaZZRczBiS0tiMTFiS0ti
MP//ADX/8wNnA3cCJgA/AAABBwKPASkAgAAIsQIBsICwNSsAAP//ADX/8wNnA3cCJgA/AAABBwKSAIAAgAAIsQIBsICwNSsAAP//
ADX/8wNnAvsAJgA/AAAAJwIiABACiQEHAiICiQKJABKxAgG4AomwNSuxAwG4AomwNSv//wA1//MDZwNNAiYAPwAAAQcCjQE4AIAA
CLECAbCAsDUrAAD//wA1//MDZwN3AiYAPwAAAQcCjgB6AIAACLECAbCAsDUrAAD//wA1//MDZwN3AiYAPwAAAQcCkAC6AIAACLEC
ArCAsDUrAAD//wA1//MDZwMyAiYAPwAAAQcClwDRAIAACLECAbCAsDUrAAD//wA1/8gDZwK1AiYAPwAAAQcCnwCi/+UACbECAbj/
5bA1KwD//wA1//MDZwNkAiYAPwAAAQcClgB+AIAACLECAbCAsDUrAAAAAgA1//MEwQKUABgAKADES7ATUFhAIwAEAAUGBAVnCQED
AwFhAgEBASpNCwgCBgYAYQcKAgAAKwBOG0uwGVBYQDgABAAFBgQFZwkBAwMBYQABASpNCQEDAwJfAAICJE0LCAIGBgdfAAcHJU0L
CAIGBgBhCgEAACsAThtAMwAEAAUGBAVnAAkJAWEAAQEqTQADAwJfAAICJE0ABgYHXwAHByVNCwEICABhCgEAACsATllZQB8aGQEA
IiAZKBooFxYVFBIREA8NDAsKCQcAGAEYDAgWKwUiJiY1NDY2MzIXIRUhFhchFSEGByEVIQYnMjY2NTQmJiMiBgYVFBYWAc6Bt2Fh
t4FIPgJs/mA4DAEB/v8NNwGh/ZM+SFB5RUV5UE98RkZ8DVGWaWqWUQ1wQl5pXUFwDXMwYktLYjExYktLYjAAAAAAAgBLAAAC4AKH
AAwAFQAyQC8ABAUBAAEEAGcGAQMDAl8AAgIkTQABASUBTg4NAQARDw0VDhUGBAMCAAwBDAcIFislIRUjESEyFhYVFAYGAyEVITI2
NTQmAdz+9IUBkUl1RkZ1Pf7oARg1Pj7S0gKHLmNOTV8qAUPZOTM1OAAAAAACAEsAAALHAocADgAXAC5AKwABBgEEBQEEZwAFAAID
BQJnAAAAJE0AAwMlA04QDxMRDxcQFxEmIRAHCBorEzMVMzIWFhUUBgYjIxUjASMVMzI2NTQmS4XzSXVGRnVJ84UBhP//M0BAAodr
LF9OTl8rawGw2TkzNTgAAAAAAgA1/zgDZwKUABAAIAAtQCoGAwIAAgFMAAMDAWEAAQEqTQQBAgIAXwAAACkAThIRGhgRIBIgJxQF
CBgrARQGBxUjNSYmNTQ2NjMyFhYBMjY2NTQmJiMiBgYVFBYWA2e0pIKktGG3gYK2Yf5nUHlFRXlQT3xGRnwBQ5CuD76+D66QapZR
UZb+uTBiS0tiMTFiS0tiMAAAAAACAE0AAAL8AocAFQAdADNAMAkBAgQBTAAEAAIBBAJnAAUFAF8AAAAkTQYDAgEBJQFOAAAdGxgW
ABUAFSQaIQcIGSszESEyFhUUBgYHFhYVFSM1NCYmIyMVESEyNjU0IyFNAbdwiCtJLktJhRpDP/sBMjg7c/7OAodeZjZFJggGNUWa
kSUpEO8BVzYuWgAAAP//AE0AAAL8A3MCJgBNAAABBwKPAPMAfAAIsQIBsHywNSsAAP//AE0AAAL8A3MCJgBNAAABBgKTTXwACLEC
AbB8sDUr//8ATf8CAvwChwImAE0AAAEHApkBKv/7AAmxAgG4//uwNSsAAAEAH//yAo4ClAAsADBALQADBAAEAwCAAAABBAABfgAE
BAJhAAICKk0AAQEFYQAFBSsFTiwiEiwjEAYIHCs3Mx4CMzI2NTQmJicuAjU0NjMyFgcjJiYjIgYVFBYWFx4CFRQGIyIuAiKHBDda
OExJKFZGSXxKk4uMlwKCBFtFQFMlXFJMcUCKl1qAUCTaIjcfMCobHRMKCy1PPVZpd2g7NCYuGCAXDQspTEBYajBJTwD//wAf//IC
jgN3AiYAUQAAAQcCjwCuAIAACLEBAbCAsDUrAAD//wAf//ICjgN3AiYAUQAAAQcCkwAIAIAACLEBAbCAsDUrAAAAAQAf/wwCjgKU
AEQAkUAPQAEFAT8pAgcFOwEIBwNMS7ALUFhAMwADBAAEAwCAAAABBAABfgAHBQgFBwiAAAgABggGZQAEBAJhAAICKk0AAQEFYQAF
BSsFThtAMwADBAAEAwCAAAABBAABfgAHBQgFBwiAAAgABggGZQAEBAJhAAICKk0AAQEFYQAFBS4FTllADCMTJhwiEiwjEAkIHys3
Mx4CMzI2NTQmJicuAjU0NjMyFgcjJiYjIgYVFBYWFx4CFRQGBxUWFhUUBiMiJiY3Mx4CMzI2NTQmJic1LgMihwQ3WjhMSShWRkl8
SpOLjJcCggRbRUBTJVxSTHFAfYcgKk9PMkckAl4CCRgXHBcJHiJEYj0b2iI3HzAqGx0TCgstTz1WaXdoOzQmLhggFw0LKUxAVGgF
IwsrJSo/IzkfBRQQGBAHFBQGPQszQ0UAAAD//wAf/wICjgKUAiYAUQAAAQcCmQDt//sACbEBAbj/+7A1KwAAAQAUAAACvgKHAAcA
G0AYAwEBAQBfAAAAJE0AAgIlAk4REREQBAgaKxMhFSERIxEhFAKq/u6F/u0Ch2/96AIYAAEAFAAAAr4ChwAPAC9ALAQBAAgHAgUG
AAVnAwEBAQJfAAICJE0ABgYlBk4AAAAPAA8RERERERERCQgdKxM1MzUhNSEVIRUzFSMRIxFQ1/7tAqr+7tbWhQEeS69vb69L/uIB
Hv//ABQAAAK+A3MCJgBWAAABBgKTHnwACLEBAbB8sDUrAAEAFP8RAr4ChwAgAD5AOxYLAgYEBwEABgJMBwEGBAAEBgCAAAAABQAF
ZQMBAQECXwACAiRNAAQEJQROAAAAIAAgJhERERkjCAgcKwUeAjMyNjU0JiYnNSMRITUhFSERIxUWFhUUBiMiJiY3AQoCCRgXHBcJ
HiIH/u0Cqv7uESAqT08yRyQCdAUUEBgQBxQUBkACGG9v/egrCyslKj8jOR8AAAD//wAU/wcCvgKHAiYAVgAAAAcCmQD+AAAAAQBN
//MDJAKHABcAG0AYAgEAACRNAAMDAWEAAQErAU4kFSURBAgaKwERMxEUDgIjIi4CNREzERQWFjMyNjYCn4U6ZINJTIVkOIU8aUNB
Zz0BHgFp/olRbUIdHUJtUQF3/pdMTx0dT///AE3/8wMkA3MCJgBbAAABBwKPARUAfAAIsQEBsHywNSsAAP//AE3/8wMkA3MCJgBb
AAABBgKSbHwACLEBAbB8sDUr//8ATf/zAyQChwImAFsAAAEHAowAsP+7AAmxAQK4/7uwNSsA//8ATf/zAyQDcwImAFsAAAEGAo5m
fAAIsQEBsHywNSv//wBN//MDJAM0AiYAWwAAAQcCkACvAD0ACLEBArA9sDUrAAD//wBN//MDJAMuAiYAWwAAAQcClwC9AHwACLEB
AbB8sDUrAAAAAQBN/xwDJAKHACUAJEAhAAUAAAUAZQQBAgIkTQADAwFhAAEBKwFOGhQkFTUQBggcKwUiJjU0NjcGIyIuAjURMxEU
FhYzMjY2NREzERQGBxUGBhUUFjMCg2Z4Ih0VFUyFZDiFPGlDQWc9hWlTKTVCN+RDOiAsDwEdQm1RAXf+l0xPHR1PTAFp/olufBsC
ECshJScA//8ATf/zAyQDnAImAFsAAAEHApUAxQB8AAixAQKwfLA1KwAAAAEAFAAAAvMChwAGACFAHgMBAgABTAEBAAAkTQMBAgIl
Ak4AAAAGAAYSEQQIGCshATMTEzMBATL+4pPe3ZH+5QKH/e8CEf15AAEAFAAABQAChwAMACdAJAsGAwMDAAFMAgECAAAkTQUEAgMD
JQNOAAAADAAMERISEQYIGishATMTEzMTEzMBIwMDASX+75PRx5nH0ZD+8qPDxAKH/fkCB/35Agf9eQH7/gUAAP//ABQAAAUAA4MC
JgBlAAABBwKPAekAjAAIsQEBsIywNSsAAP//ABQAAAUAA4MCJgBlAAABBwKSAUAAjAAIsQEBsIywNSsAAP//ABQAAAUAAqUCJgBl
AAAAJwIiAOACMwEHAiIDJwIzABKxAQG4AjOwNSuxAgG4AjOwNSv//wAUAAAFAAODAiYAZQAAAQcCjgE6AIwACLEBAbCMsDUrAAAA
AQAnAAAC5QKHAAsAJkAjCgcEAQQBAAFMBAMCAAAkTQIBAQElAU4AAAALAAsSEhIFCBkrExc3MwEBIycHIwEB07W4ov7wAROpt7yi
ART+9gKH4+P+wv637e0BSAE/AAAAAQATAAAC0QKHAAgAI0AgBwQBAwABAUwDAgIBASRNAAAAJQBOAAAACAAIEhIECBgrAQEVIzUB
MxMTAtH+5Ib+5JrHwwKH/kXMzAG7/r4BQv//ABMAAALRA3MCJgBrAAABBwKPAM0AfAAIsQEBsHywNSsAAP//ABMAAALRA3MCJgBr
AAABBgKSJHwACLEBAbB8sDUr//8AEwAAAtEDSAImAGsAAAEGAoxqfAAIsQECsHywNSv//wATAAAC0QNzAiYAawAAAQYCjh58AAix
AQGwfLA1KwABAD8AAAL2AocACQAnQCQCAQMHAQECSwADAwBfAAAAJE0AAQECXwACAiUCThIREhAECBorEyEVASEVITUBIT8Ct/3t
AhP9SQIT/e0Ch2/+V29vAakAAAD//wA/AAAC9gODAiYAcAAAAQcCjwD2AIwACLEBAbCMsDUrAAD//wA/AAAC9gODAiYAcAAAAQcC
kwBQAIwACLEBAbCMsDUrAAD//wA/AAAC9gNZAiYAcAAAAQcCjQEFAIwACLEBAbCMsDUrAAD//wARAAADBANJAiYAAQAAAQcCoQD0
AHwACLECAbB8sDUrAAD//wARAAADBANJAiYAAQAAAQcCpgD0AHwACLECAbB8sDUrAAD//wARAAADBANJAiYAAQAAAQcCpAD0AHwA
CLECAbB8sDUrAAD//wARAAADBANJAiYAAQAAAQcCoAD0AHwACLECAbB8sDUrAAD//wARAAADBANJAiYAAQAAAQcCqQD0AHwACLEC
AbB8sDUrAAD//wAR/z8DDwKHAiYAAQAAAQcCrQItAAcACLECAbAHsDUrAAD//wARAAADBANJAiYAAQAAAQcCpwD0AHwACLECAbB8
sDUrAAD//wARAAADBANJAiYAAQAAAQcCqAD0AHwACLECAbB8sDUrAAD//wA1//MDQANNAiYADQAAAQcCoQEwAIAACLEBAbCAsDUr
AAD//wA1//MDQANNAiYADQAAAQcCpQEwAIAACLEBAbCAsDUrAAD//wA1/zgDQAKUAiYADQAAAAcCrAE5AAD//wA1//MDQANNAiYA
DQAAAQcCjQEwAIAACLEBAbCAsDUrAAD//wBNAAADOgNeAiYAEgAAAQcCpQEEAJEACLECAbCRsDUrAAD//wBNAAACxQNJAiYAFgAA
AQcCoQD3AHwACLEBAbB8sDUrAAD//wBNAAACxQNJAiYAFgAAAQcCpQD3AHwACLEBAbB8sDUrAAD//wBNAAACxQNJAiYAFgAAAQcC
pAD3AHwACLEBAbB8sDUrAAD//wBNAAACxQNJAiYAFgAAAQcCoAD3AHwACLEBAbB8sDUrAAD//wBNAAACxQNJAiYAFgAAAQcCqQD3
AHwACLEBAbB8sDUrAAD//wBN/zgC0AKHAiYAFgAAAAcCrQHuAAD//wA1//MDUwNNAiYAIAAAAQcCpgEwAIAACLEBAbCAsDUrAAD/
/wA1/zgDUwKUAiYAIAAAAAcCqwE6AAD//wA1//MDUwNNAiYAIAAAAQcCjQEwAIAACLEBAbCAsDUrAAD//wBXAAAA7gNJAiYAJgAA
AQYCoQx8AAixAQGwfLA1K///AFcAAADuA0kCJgAmAAABBgKkDHwACLEBAbB8sDUr//8AVwAAAO4DSQImACYAAAEGAqAMfAAIsQEB
sHywNSv//wBXAAAA7gNJAiYAJgAAAQYCqQx8AAixAQGwfLA1K///AFb/OADtAocCJgAmAAAABgKtCwAAAP//AE3/OAMVAocCJgAw
AAAABwKrAPUAAP//AEQAAAKAA0kCJgAyAAABBgKh+XwACLEBAbB8sDUr//8ATQAAAoACuQImADIAAAAHAqMBMwAA//8ATf84AoAC
hwImADIAAAAHAqsA+gAA//8ATQAAAzgDSQImADkAAAEHAqEBMwB8AAixAQGwfLA1KwAA//8ATQAAAzgDSQImADkAAAEHAqUBMwB8
AAixAQGwfLA1KwAA//8ATf84AzgChwImADkAAAAHAqsBQAAA//8ATQAAAzgDSQImADkAAAEHAqgBMwB8AAixAQGwfLA1KwAA//8A
Nf/zA2cDTQImAD8AAAEHAqEBOACAAAixAgGwgLA1KwAA//8ANf/zA2cDTQImAD8AAAEHAqQBOACAAAixAgGwgLA1KwAA//8ANf/z
A2cDTQImAD8AAAEHAqABOACAAAixAgGwgLA1KwAA//8ANf/zA2cDTAImAD8AAAEHAqIAywCAAAixAgKwgLA1KwAA//8ANf/zA2cD
TQImAD8AAAEHAqkBOACAAAixAgGwgLA1KwAA//8ANf/zA2cDTQImAD8AAAEHAqgBOACAAAixAgGwgLA1KwAA//8ATQAAAvwDSQIm
AE0AAAEHAqEBAgB8AAixAgGwfLA1KwAA//8ATQAAAvwDSQImAE0AAAEHAqUBAgB8AAixAgGwfLA1KwAA//8ATf8zAvwChwImAE0A
AAEHAqsBCf/7AAmxAgG4//uwNSsA//8AH//yAo4DTQImAFEAAAEHAqEAvQCAAAixAQGwgLA1KwAA//8AH//yAo4DTQImAFEAAAEH
AqUAvQCAAAixAQGwgLA1KwAA//8AH/8zAo4ClAImAFEAAAEHAqwAwv/7AAmxAQG4//uwNSsA//8AH/8zAo4ClAImAFEAAAEHAqsA
zP/7AAmxAQG4//uwNSsA//8AFAAAAr4DSQImAFYAAAEHAqUA0wB8AAixAQGwfLA1KwAA//8AFP84Ar4ChwImAFYAAAAHAqwA0wAA
//8AFP84Ar4ChwImAFYAAAAHAqsA3QAA//8ATf/zAyQDSQImAFsAAAEHAqEBJAB8AAixAQGwfLA1KwAA//8ATf/zAyQDSQImAFsA
AAEHAqQBJAB8AAixAQGwfLA1KwAA//8ATf/zAyQDSQImAFsAAAEHAqABJAB8AAixAQGwfLA1KwAA//8ATf/zAyQChwImAFsAAAEH
AowAsP+7AAmxAQK4/7uwNSsA//8ATf/zAyQDSQImAFsAAAEHAqkBJAB8AAixAQGwfLA1KwAA//8ATf8zAywChwImAFsAAAEHAq0C
Sv/7AAmxAQG4//uwNSsA//8ATf/zAyQDSQImAFsAAAEHAqcBJAB8AAixAQGwfLA1KwAA//8AFAAABQADWQImAGUAAAEHAqEB+ACM
AAixAQGwjLA1KwAA//8AFAAABQADWQImAGUAAAEHAqQB+ACMAAixAQGwjLA1KwAA//8AFAAABQADWQImAGUAAAEHAqAB+ACMAAix
AQGwjLA1KwAA//8AEwAAAtEDSQImAGsAAAEHAqEA3AB8AAixAQGwfLA1KwAA//8AEwAAAtEDSQImAGsAAAEHAqQA3AB8AAixAQGw
fLA1KwAA//8AEwAAAtEDSQImAGsAAAEHAqAA3AB8AAixAQGwfLA1KwAA//8APwAAAvYDWQImAHAAAAEHAqEBBQCMAAixAQGwjLA1
KwAA//8APwAAAvYDWQImAHAAAAEHAqUBBQCMAAixAQGwjLA1KwAAAAEAFAAABPAChwAeADJALxYCAgIDAUwHAQUFAF8AAAAkTQAD
AwFhAAEBLU0GBAICAiUCThERERQjFSUQCAgeKxMhET4DMzIeAhURIxE0JiMiBgYHESMRIREjESEUAx4IHzZROCZNPyaCRkgtRi8M
gv78hf7tAof+3hU2MiESLEo4/r0BFkQ4IzQb/uACGP3oAhgAAAACACT/9QKZAfwAFwAjAIm2FAsCBAUBTEuwC1BYQBkABQUBYQIB
AQEtTQcBBAQAYQMGAgAAKwBOG0uwF1BYQBkABQUBYQIBAQEtTQcBBAQAYQMGAgAALgBOG0AhAAICJ00ABQUBYQABAS1NAAMDJU0H
AQQEAGEGAQAALgBOWVlAFxkYAQAfHRgjGSMPDg0MCQcAFwEXCAgWKwUiJiY1NDY2MzIWFzUzESMwJiY1NQ4CJzI2NTQmIyIGFRQW
AS5KeUdIfE1hbRSCeQUEDjpeGVlmZ1hTXGALQXVNT3RBWEeU/g8nPB0gLU4wZFhHTVJXSEhXAAD//wAk//UCmQL3AiYAtwAAAAcC
jwCzAAD//wAk//UCmQLaAiYAtwAAAAYClBkAAAD//wAk//UCmQL3AiYAtwAAAAYCkgoAAAD//wAk//UCmQLMAiYAtwAAAAYCjFAA
AAD//wAk//UCmQL3AiYAtwAAAAYCjgQAAAD//wAk//UCmQKyAiYAtwAAAAYCl1sAAAAAAgAk/yECmQH8ACMALwDqS7AXUFhACyAL
AgYHHAEABgJMG0ALIAsCBgccAQMGAkxZS7ALUFhAIwAHBwFhAgEBAS1NCQEGBgBhAwgCAAArTQAEBAVhAAUFKQVOG0uwFVBYQCMA
BwcBYQIBAQEtTQkBBgYAYQMIAgAALk0ABAQFYQAFBSkFThtLsBdQWEAgAAQABQQFZQAHBwFhAgEBAS1NCQEGBgBhAwgCAAAuAE4b
QCgABAAFBAVlAAICJ00ABwcBYQABAS1NAAMDJU0JAQYGAGEIAQAALgBOWVlZQBslJAEAKykkLyUvFxYVFA8ODQwJBwAjASMKCBYr
BSImJjU0NjYzMhYXNTMRIwYGFRQWMxUiJjU0NjcmJjU1DgInMjY1NCYjIgYVFBYBLkp5R0h8TWFtFIIyKTVCN2Z4RDcCBg46XhlZ
ZmdYU1xgC0F1TU90QVhHlP4PByYiJCdFQzouMwwRQyEgLU4wZFhHTVJXSEhXAAD//wAk//UCmQMgAiYAtwAAAAYClWMAAAD//wAk
//UCmQLkAiYAtwAAAAYClggAAAAAAwAk//IE1AH8ACsANwA+ASZADA4LAgwKKCICBQYCTEuwC1BYQC4ABgQFBAYFgAAMAAQGDARn
DwsCCgoBYQMCAgEBLU0OCQIFBQBhCAcNAwAAKwBOG0uwF1BYQC4ABgQFBAYFgAAMAAQGDARnDwsCCgoBYQMCAgEBLU0OCQIFBQBh
CAcNAwAALgBOG0uwG1BYQD0ABgQFBAYFgAAMAAQGDARnDwsCCgoBYQABAS1NDwsCCgoCYQMBAgInTQAICCVNDgkCBQUAYQcNAgAA
LgBOG0A2AAYEBQQGBYAADAAEBgwEZwACAidNDwsCCgoBYQMBAQEtTQAICCVNDgkCBQUAYQcNAgAALgBOWVlZQCk5OC0sAQA8Ozg+
OT4zMSw3LTckIyAeHBsZFxUUEhANDAkHACsBKxAIFisFIiYmNTQ2NjMyFhc1MxU2NjMyFgchFhYzMjY3MwYGIyImJxUjJiY1NQ4C
JzI2NTQmIyIGFRQWASIGByEmJgEuSnlHSHxNYW0UgieQX5KTB/4mCGBVPlMMfg2Mf2CSKHkDBg46XhlZZmdYU1xgAqBIWg0BUgVV
C0F1TU90QVhHlG45PouROk4rIkxlPjlpF0kgIC1OMGRYR01SV0hIVwE+Py4yOwACAFD/9QLEArkAFgAiAJG2DAQCBAUBTEuwC1BY
QB0AAgImTQAFBQNhAAMDLU0HAQQEAGEBBgIAACsAThtLsBdQWEAdAAICJk0ABQUDYQADAy1NBwEEBABhAQYCAAAuAE4bQCEAAgIm
TQAFBQNhAAMDLU0AAQElTQcBBAQAYQYBAAAuAE5ZWUAXGBcBAB4cFyIYIhAOCwoJCAAWARYICBYrBSImJicVFAYHIxEzETY2MzIW
FhUUBgYnMjY1NCYjIgYVFBYBu0NeOg4GA3mCFHBlTXdFRnh1T19bU1hnZwswTi0gIEkXArn+pEdYQXRPTXVBZFdISFhTTUdYAAAB
ACT/9AKKAfwAHQA2QDMAAgMFAwIFgAYBBQQDBQR+AAMDAWEAAQEtTQAEBABhAAAALgBOAAAAHQAdJiISJiIHCBsrJQYGIyImJjU0
NjYzMhYXIyYmIyIGBhUUFhYzMjY3AooHm4RckVNTkVyDmQl3EVxBNFUzMlY0RlkQxGJuO3NVVXQ8bWEyOCRHNjVHIzg0AAD//wAk
//QCigL3AiYAwwAAAAcCjwC4AAD//wAk//QCigL3AiYAwwAAAAYCkxIAAAAAAQAk/wcCigH8ADUAUEBNKyoMCwQHBAcBAAcCTAAC
AwUDAgWAAAUEAwUEfgAEBwMEB34IAQcAAwcAfgAAAAYABmYAAwMBYQABAS0DTgAAADUANSkSJiISLiMJCB0rBR4CMzI2NTQmJic1
LgI1NDY2MzIWFyMmJiMiBgYVFBYWMzI2NzMGBgcVFhYVFAYjIiYmNwEEAgkYFxwXCR4iTXVCU5Fcg5kJdxFcQTRVMzJWNEZZEHcH
gG4gKk9PMkckAn4FFBAYEAcUFAZBCUBrTFV0PG1hMjgkRzY1RyM4NFlrCisLKyUqPyM5HwAAAP//ACT/9AKKAs0CJgDDAAAABwKN
AMcAAAACACT/9QKZArkAFgAiAJG2EwsCBAUBTEuwC1BYQB0AAgImTQAFBQFhAAEBLU0HAQQEAGEDBgIAACsAThtLsBdQWEAdAAIC
Jk0ABQUBYQABAS1NBwEEBABhAwYCAAAuAE4bQCEAAgImTQAFBQFhAAEBLU0AAwMlTQcBBAQAYQYBAAAuAE5ZWUAXGBcBAB4cFyIY
Ig8ODQwJBwAWARYICBYrBSImJjU0NjYzMhYXETMRIyYmNTUOAicyNjU0JiMiBhUUFgEuS3lGRXhNZXAUgnkDBg46XhlZZmdYU1xg
C0F1TU90QVhHAVz9RxdJICAtTjBkWEdNU1hISFcAAAACACT/9AKJAsUAHQArADRAMRoBAgMBTAcGBQQBBQFKAAMDAWEAAQEnTQQB
AgIAYQAAAC4ATh8eJyUeKx8rJi4FCBgrEzcWFhc3FwceAhUUBgYjIiYmNTQ2NjMyFhcuAhMyNjY1NCYmIyIGFRQWoRRNfDBhN1Q7
QhpOiVpgikpEdkpVcRwRVZNNNFMyNFUzU19jAmZfDy0cWDtLMGxtMFB8RkF2TU9wPEQ4NltG/gsmRzAxRSRVR0lSAAAA//8AJP/1
A2YCuQImAMgAAAAHApECPgAA//8AJP/1AtoCuQImAMgAAAEHApwBKADRAAixAgGw0bA1KwAAAAIAJP/0AogB/AAVABwAOUA2AAAD
BAMABIAABgADAAYDZwcBBQUCYQACAi1NAAQEAWEAAQEuAU4XFhoZFhwXHCISJiIQCAgbKyUzBgYjIiYmNTQ2NjMyFgchFhYzMjYD
IgYHISYmAgF+DYx/X5JSUI9gkpMH/iYIYFU+U5hIWg0BUgVVpUxlPXRSUnU+i5E6TisBFj8uMjv//wAk//QCiAL3AiYAzAAAAAcC
jwC7AAD//wAk//QCiAL3AiYAzAAAAAYCkxUAAAD//wAk//QCiAL3AiYAzAAAAAYCkhIAAAD//wAk//QCiALMAiYAzAAAAAYCjFgA
AAD//wAk//QCiALNAiYAzAAAAAcCjQDKAAD//wAk//QCiAL3AiYAzAAAAAYCjgwAAAD//wAk//QCiAKyAiYAzAAAAAYCl2MAAAAA
AgAk/yECiAH8ACUALACEtRIBAwYBTEuwFVBYQDAAAAUGBQAGgAAIAAUACAVnCQEHBwRhAAQELU0ABgYDYQADAy5NAAEBAmIAAgIp
Ak4bQC0AAAUGBQAGgAAIAAUACAVnAAEAAgECZgkBBwcEYQAEBC1NAAYGA2EAAwMuA05ZQBInJiopJiwnLCISJiYRGRAKCB0rJTMG
BgcVBgYVFBYzFSImNTQ2NwYjIiYmNTQ2NjMyFgchFhYzMjYDIgYHISYmAgF+CDcwKTZDN2d4HBkNDV+SUlCPYJKTB/4mCGBVPlOY
SFoNAVIFVaUtShgBFiwiJChEQzodKhABPXRSUnU+i5E6TisBFj8uMjsAAAEAGQAAAbACuQATAClAJgACAgFfAAEBJk0GAQQEAF8D
AQAAJ00ABQUlBU4RERETISMQBwgdKxMzNTQ2MzMVIyYGFRUzFSMRIxEjGXBiXmdILDGenoJwAegkWlNpASIzFGP+ewGFAAAAAgAk
/zMChgH8ACsANwDPS7AVUFi1GwEEAgFMG7UbAQkDAUxZS7APUFhAKwABCAUGAXILAQgABQYIBWkABgAABwYAaAkBBAQCYQMBAgIt
TQoBBwcpB04bS7AVUFhALAABCAUIAQWACwEIAAUGCAVpAAYAAAcGAGgJAQQEAmEDAQICLU0KAQcHKQdOG0A0AAEIBQgBBYALAQgA
BQYIBWkABgAABwYAaAAJCQJhAAICLU0ABAQDXwADAydNCgEHBykHTllZQBgtLAAAMzEsNy03ACsAKzMnERImFTMMCB0rBTU0JiMj
IiYmNTQ2MyYmNTQ2NjMyFhcXFQYmJxYWFRQGIwYGFRQzMzIWFRUBMjY1NCYjIgYVFBYB2zszmzxFHVZBTVpCe1MXKxX7KVYlKDiR
fT89LqNlb/7XQU9PQUFQT80YLiQZKxszKRRmT0NiNgYFAWIBEg0ZRzFibQIRGSBEWi8Bdz44OEFAOTg+//8AJP8zAoYC2gImANYA
AAAGApT1AAAA//8AJP8zAoYC9wImANYAAAAGApgAAAAA//8AJP8zAoYCzQImANYAAAAHAo0AngAAAAEARQAAAoQCuQAVAC5AKxQD
AgIDAUwAAAAmTQADAwFhAAEBLU0FBAICAiUCTgAAABUAFSMUJBEGCBorMxEzET4CMzIWFhURIxE0JiMiBgcRRYINPl4+PWE4gkBM
P18RArn+qidGLCpUQP7CARE9Pjwp/tn//wAAAAAChAK5AiYA2gAAAQcCnP+1ANMACLEBAbDTsDUrAAAAAgA6AAAA0QLLAAMABwBG
S7AbUFhAFgAAAAFfBAEBASZNAAICJ00AAwMlA04bQBQEAQEAAAIBAGcAAgInTQADAyUDTllADgAABwYFBAADAAMRBQgXKxMVIzUX
MxEj0ZcKgoICy3Jy2v4PAAAAAQA6AAAAvAHxAAMAE0AQAAAAJ00AAQElAU4REAIIGCsTMxEjOoKCAfH+D///ADUAAAFpAvUCJgDd
AAABBgKP1v4ACbEBAbj//rA1KwAAAP///5QAAAFhAvUCJgDdAAABBwKS/y3//gAJsQEBuP/+sDUrAAAD/+cAAAEWAswAAwAHAAsA
VEuwG1BYQBkCAQAAAV8HAwYDAQEmTQAEBCdNAAUFJQVOG0AXBwMGAwECAQAEAQBnAAQEJ00ABQUlBU5ZQBYEBAAACwoJCAQHBAcG
BQADAAMRCAgXKxMVIzUhFSM1BzMRI3OMAS+MUIKCAsxycnJy2/4PAP//ADAAAADHAssCJgDdAAABBgKN5f4ACbEBAbj//rA1KwAA
AP///4sAAAC/AvUCJgDdAAABBwKO/yf//gAJsQEBuP/+sDUrAP//ADr/OAHdAssAJgDcAAAABwDmAQwAAP///+IAAAEVArACJgDd
AAABBwKX/37//gAJsQEBuP/+sDUrAAACAAP/IQDhAssAAwAUAIe0DgEDAUtLsBVQWEAgAAAAAV8GAQEBJk0ABAQnTQADAyVNAAUF
AmEAAgIpAk4bS7AbUFhAHQAFAAIFAmUAAAABXwYBAQEmTQAEBCdNAAMDJQNOG0AbBgEBAAAEAQBnAAUAAgUCZQAEBCdNAAMDJQNO
WVlAEgAAFBMNDAsKBQQAAwADEQcIFysTFSM1EyImNTQ2NyMRMxEGBhUUFjPRl6dmeC0mEoIpNUI3AstycvxWQzolLw4B8f4PByYi
JCcAAAAAAgA6/zgA0QLLAAMABwBGS7AbUFhAFgAAAAFfBAEBASZNAAICJ00AAwMpA04bQBQEAQEAAAIBAGcAAgInTQADAykDTllA
DgAABwYFBAADAAMRBQgXKxMVIzUXMxEj0ZcMgoICy3Jy2v1HAAAAAgBFAAACgQK5AAMACQAoQCUIBQIBAwFMAAAAJk0EAQMDJ00C
AQEBJQFOBAQECQQJExEQBQgZKxMzESMBBwEjATdFgoICJfwBE6X+7u8Cuf1HAfHe/u0BF9oAAP//AEX/BwKBArkCJgDnAAAABwKZ
ANkAAAABAEYAAADIArkAAwATQBAAAAAmTQABASUBThEQAggYKxMzESNGgoICuf1H//8ARgAAAXoDtQImAOkAAAEHAo//5wC+AAix
AQGwvrA1KwAA//8ARgAAAZECuQAmAOkAAAAGApFpAAAA//8AO/8HANQCuQImAOkAAAAGApkdAAAA//8ARgAAAYICuQAmAOkAAAEH
AiIArwEOAAmxAQG4AQ6wNSsAAAH/7AAAATcCuQALAB9AHAsIBwYFAgEHAAEBTAABASZNAAAAJQBOFRMCCBgrARcHESMRByc3ETMR
ARIlZYJBI2SCAdw1Rf6eAQksNUUBYv73AAAAAAEAPAAABC0B/AAoAFJACSYaCQIEAwQBTEuwF1BYQBUGAQQEAGECAQIAACdNBwUC
AwMlA04bQBkAAAAnTQYBBAQBYQIBAQEtTQcFAgMDJQNOWUALFCMVIxQlJBAICB4rEzMVPgIzMhYXPgIzMhYWFREjETQmIyIGBxQV
ESMRNCYjIgYGBxEjPIINPl4+THESED9bOD1hOYI+RTtcFoI9RS1LNguCAfGPKEYsREklQCgrWkf+0AEZPzszIwYH/tABGT87HjEc
/tgAAQA8AAACewH8ABYARbYUAgICAwFMS7AXUFhAEgADAwBhAQEAACdNBAECAiUCThtAFgAAACdNAAMDAWEAAQEtTQQBAgIlAk5Z
txQjFCQQBQgbKxMzFT4CMzIWFhURIxE0JiMiBgYHESM8gg0+Xj49YTiCPUUtSzYLggHxjyhGLCtaR/7QARk/Ox4xHP7YAAD//wA8
AAACewL3AiYA8AAAAAcCjwDXAAD//wA8AAACewL3AiYA8AAAAAYCkzEAAAD//wA8/wcCewH8AiYA8AAAAAcCmQDxAAD//wA8AAAC
ewLkAiYA8AAAAAYCliwAAAAAAQA8/ywCewH8ABwAhrYbAwIFBAFMS7AXUFhAHAAEBABhAQEAACdNBgEFBSVNAAMDAmEAAgIpAk4b
S7ApUFhAIAAAACdNAAQEAWEAAQEtTQYBBQUlTQADAwJhAAICKQJOG0AdAAMAAgMCZQAAACdNAAQEAWEAAQEtTQYBBQUlBU5ZWUAO
AAAAHAAcJREWJBEHCBsrMxEzFT4CMzIWFhURFAYjNTI2NRE0JiMiBgYHETyCDT5ePj1hOH6JRz49RS1LNgsB8Y8oRiwrWkf+rFVb
azI3ARk/Ox4xHP7YAAIAJP/0ApwB/AAPAB4ALUAqAAMDAWEAAQEtTQUBAgIAYQQBAAAuAE4REAEAGRcQHhEeCQcADwEPBggWKwUi
JiY1NDY2MzIWFhUUBgYnMjY2NTQmJiMiBgYVFBYBYV6PUFCPXl6NUFCNXjRTMDBSNTRUMWoMPHNUVHU8PHVUVHM8ZCVHMzNJJiZI
NExTAAAA//8AJP/0ApwC9wImAPYAAAAHAo8AvAAA//8AJP/0ApwC9wImAPYAAAAGApITAAAA//8AJP/0ApwCzAImAPYAAAAGAoxZ
AAAA//8AJP/0ApwC9wImAPYAAAAGAo4NAAAA//8AJP/0ApwC9wImAPYAAAAGApBNAAAA//8AJP/0ApwCsgImAPYAAAAGApdkAAAA
AAMAJP/UApwCHwAXACEAKwBKQEcRDgICASopHBsEAwIFAgIAAwNMEA8CAUoEAwIASQACAgFhAAEBLU0FAQMDAGEEAQAALgBOIyIB
ACIrIysfHQ0LABcBFwYIFisFIicHJzcmJjU0NjYzMhc3FwcWFhUUBgYBFBYXEyYjIgYGFzI2NjU0JicDFgFhPTQbNBNDTVCPXjoy
HDYWRU5Qjf7pJSCpGRw0VDG5NFMwJiKpGwwNLSAhHnJSVHU8DC8eJR50U1RzPAEDLEIUAR4GJkjTJUczLUQU/uIG//8AJP/0ApwC
5AImAPYAAAAGApYRAAAA//8AJP/0BH4B/AAmAPYAAAAHAMwB9gAAAAIAPP84ArAB/AAUACEAa7YKBAIEBQFMS7AXUFhAHQAFBQJh
AwECAidNBwEEBABhBgEAAC5NAAEBKQFOG0AhAAICJ00ABQUDYQADAy1NBwEEBABhBgEAAC5NAAEBKQFOWUAXFhUBABwaFSEWIQ4M
CAcGBQAUARQICBYrBSImJicRIxEzFxU2NjMyFhYVFAYGJzI2NTQmIyIGBhUUFgGmQl46DoJ8BhRwZEt4R0h4dFBfW1Q1VzJmDDBP
Lf6YArmEEEdYQnVNT3VAZVdISFgmRzNIVwAAAgA8/zgCsAK4ABQAIQBCQD8KBAIEBQFMAAICJk0ABQUDYQADAy1NBwEEBABhBgEA
AC5NAAEBKQFOFhUBABwaFSEWIQ4MCAcGBQAUARQICBYrBSImJicRIxEzERU2NjMyFhYVFAYGJzI2NTQmIyIGBhUUFgGmQl46DoKC
FHBkS3hHSHh0UF9bVDVXMmYMME8t/pgDgP61EEdYQnVNT3VAZVdISFgmRzNIVwAAAAIAJP84ApkB/AAUACAAa7YRCwIEBQFMS7AX
UFhAHQAFBQFhAgEBAS1NBwEEBABhBgEAAC5NAAMDKQNOG0AhAAICJ00ABQUBYQABAS1NBwEEBABhBgEAAC5NAAMDKQNOWUAXFhUB
ABwaFSAWIBAPDg0JBwAUARQICBYrBSImJjU0NjYzMhYXNTczESMRDgInMjY1NCYjIgYVFBYBLkp5R0d5SmVwFAR+gg46XhlZZmdY
U1xgDEB1T011QlhHGXv9RwFoLU8wZVdITVNYSEhXAAABADwAAAF9AfwADgBCtgwCAgMCAUxLsBdQWEARAAICAGEBAQAAJ00AAwMl
A04bQBUAAAAnTQACAgFhAAEBLU0AAwMlA05ZthQRFRAECBorEzMVPgMzFSIGBgcRIzyCBx0uQSwyTTMNggHxlRc3MiB2IzYb/u4A
AP//ADwAAAHaAvcCJgEDAAAABgKPRwAAAP//AAwAAAHSAvcCJgEDAAAABgKToQAAAP//ADH/BwF9AfwCJgEDAAAABgKZEwAAAAAB
ACX/9AINAfwAKgBeS7ASUFhAIwADBAAEA3IAAAEEAAF+AAQEAmEAAgItTQABAQVhAAUFLgVOG0AkAAMEAAQDAIAAAAEEAAF+AAQE
AmEAAgItTQABAQVhAAUFLgVOWUAJKyISLCIQBggcKzczFhYzMjY1NCYnLgI1NDY2MzIWFyMmJiMiBhUUFhceAhUUBiMiLgIoeAtF
ODknPD44Yzw9aUJvbQFzCDAyMTJFRTRaOXpqT2c5FaUiKyAaIBYKCh46MjBDI19LJSEeGh8YCwsdODVITSk8Ov//ACX/9AINAvcC
JgEHAAAABgKPcwAAAP//ACX/9AINAvcCJgEHAAAABgKTzQAAAAABACb/BwINAfwAQgCIQA0+PScmBAYBOQEHBgJMS7ASUFhALgAD
BAAEA3IAAAEEAAF+AAEGBAEGfgAGBwQGB34ABwAFBwVmAAQEAmEAAgItBE4bQC8AAwQABAMAgAAAAQQAAX4AAQYEAQZ+AAYHBAYH
fgAHAAUHBWYABAQCYQACAi0ETllADjc1MjEuLCISLCIQCAgbKzczFhYzMjY1NCYnLgI1NDY2MzIWFyMmJiMiBhUUFhceAhUUBgcV
FhYVFAYjIiYmNzMeAjMyNjU0JiYnNS4DKHgLRTg5Jzw+OGM8PWlCb20BcwgwMjEyRUU0WjlbUCAqT08yRyQCXgIJGBccFwkeIj9S
LhClIisgGiAWCgoeOjIwQyNfSyUhHhofGAsLHTg1PkoKLAsrJSo/IzkfBRQQGBAHFBQGQQcrODQA//8AJf79Ag0B/AImAQcAAAEH
ApkAxf/2AAmxAQG4//awNSsAAAEARf9TArgCuQAkAH1ACw0BBgIhDgIFBgJMS7AyUFhAKgAFBgcGBQeAAAQAAwQDZQABAQBfAAAA
Jk0ABgYCXwACAidNCAEHByUHThtAKAAFBgcGBQeAAAIABgUCBmcABAADBANlAAEBAF8AAAAmTQgBBwclB05ZQBAAAAAkACQSJhEZ
EyEjCQgdKzMRNDYzMxUjJgYVFQUVBx4CFRQGBiM1MjY2NTQmJiMjNTchEUViXnFcJS4Btac+Zz5XnGhUXiUjVk8jmv7kAgxaU2kB
JTAUAVfGBSRIO0NbLWQVLSMhLRdfpf57AAABABkAAAGbAnkACwBFS7AjUFhAFwABASRNBQEDAwBfAgEAACdNAAQEJQROG0AXBQED
AwBfAgEAACdNAAEBBF8ABAQlBE5ZQAkRERERERAGCBwrEzM1MxUzFSMRIxEjGYCCgICCgAHxiIhl/nQBjAAAAQAYAAABmwJ5ABMA
XkuwI1BYQCEGAQAJAQcIAAdnAAMDJE0FAQEBAl8EAQICJ00ACAglCE4bQCEGAQAJAQcIAAdnBQEBAQJfBAECAidNAAMDCF8ACAgl
CE5ZQA4TEhEREREREREREAoIHysTMzUjNTM1MxUzFSMVMxUjFSM1IxiBgICCgIB+foKBAUNJZYiIZUlL+PgAAAACABkAAAHCAvQA
BQARAF+2BQICAwEBTEuwI1BYQB8AAQAAAgEAZwADAyRNBwEFBQJfBAECAidNAAYGJQZOG0AfAAEAAAIBAGcHAQUFAl8EAQICJ00A
AwMGXwAGBiUGTllACxEREREREhIQCAgeKwEjJzUzFQUzNTMVMxUjESMRIwGdPiaJ/leAgoCAgoACInxWVq2IiGX+dAGMAAABABn/
EQGbAnkAJAB6QAsaCwIIBgcBAAgCTEuwI1BYQCcJAQgGAAYIAIAAAAAHAAdlAAMDJE0FAQEBAl8EAQICJ00ABgYlBk4bQCcJAQgG
AAYIAIAAAAAHAAdlBQEBAQJfBAECAidNAAMDBl8ABgYlBk5ZQBEAAAAkACQmEREREREZIwoIHisXHgIzMjY1NCYmJzUjESM1MzUz
FTMVIxEjFRYWFRQGIyImJjd7AgkYFxwXCR4iBoCAgoCADyAqT08yRyQCdAUUEBgQBxQUBkABjGWIiGX+dCsLKyUqPyM5HwAAAP//
ABn/BwGbAnkCJgENAAAABgKZbwAAAAABADz/9AJ7AfEAGABFthYCAgMCAUxLsBVQWEASBAECAidNAAMDAGEBAQAAJQBOG0AWBAEC
AidNAAAAJU0AAwMBYQABAS4BTlm3FCMVJRAFCBsrISM1DgMjIi4CNREzERQWMzI2NjcRMwJ7ggggNU01KU9AJoJGPjBJMQ2Cqhk/
OSUUL1A9AS3+6Uk0JzoeARUAAAD//wA8//QCewL3AiYBEgAAAAcCjwDAAAD//wA8//QCewL3AiYBEgAAAAYCkhcAAAD//wA8//QC
ewLMAiYBEgAAAAYCjF0AAAD//wA8//QCewL3AiYBEgAAAAYCjhEAAAD//wA8//QCjgL3AiYBEgAAAAYCkFEAAAD//wA8//QCewKy
AiYBEgAAAAYCl2gAAAAAAQA8/yECewHxACUAXkALIw8CBQQOAQAFAkxLsBVQWEAcBgEEBCdNAAUFAGEDAQAAJU0AAQECYQACAikC
ThtAHQABAAIBAmUGAQQEJ00AAAAlTQAFBQNhAAMDLgNOWUAKFCMVKhEVEAcIHSshIwYGFRQWMxUiJjU0Njc1DgMjIi4CNREzERQW
MzI2NjcRMwJ7Lik1QjdmeD0yCCA1TTUpT0AmgkY+MEkxDYIHJiIkJ0VDOiszDaEZPzklFC9QPQEt/ulJNCc6HgEVAAD//wA8//QC
ewMgAiYBEgAAAAYClXAAAAAAAQAPAAACYwHxAAYAIUAeBQEAAQFMAwICAQEnTQAAACUATgAAAAYABhERBAgYKwEDIwMzExMCY+97
6o+ZngHx/g8B8f6aAWYAAQAPAAADzAHxAAwAJ0AkCQYBAwABAUwDAgIBASdNBQQCAAAlAE4AAAAMAAwSEhESBggaKyEDAyMDMxMT
MxMTMwMCd4qPetWPh36VeYyP2wFb/qUB8f6gAWD+oQFf/g///wAPAAADzAL3AiYBHAAAAAcCjwFGAAD//wAPAAADzAL3AiYBHAAA
AAcCkgCdAAD//wAPAAADzALMAiYBHAAAAAcCjADjAAD//wAPAAADzAL3AiYBHAAAAAcCjgCXAAAAAQAUAAACfQHxAAsAIEAdCwgF
AgQCAAFMAQEAACdNAwECAiUCThISEhAECBorEzMXNzMHEyMnByM3FJ+Uip7f7Z+Zkp/oAfGhofD+/6ys+wABAA//OAJvAfEABwAc
QBkHAgICAAFMAQEAACdNAAICKQJOERIQAwgZKxMzExMzASM3D4qkp4v+qIduAfH+kwFt/UfN//8AD/84Am8C9wImASIAAAAHAo8A
mwAA//8AD/84Am8C9wImASIAAAAGApLyAAAA//8AD/84Am8CzAImASIAAAAGAow4AAAA//8AD/84Am8C9wImASIAAAAGAo7sAAAA
AAEAOQAAAjYB8QAJACdAJAABAgUBAAJLAAICA18AAwMnTQAAAAFfAAEBJQFOERIREQQIGisBASEVITUBITUhAi/+oQFm/gMBX/6h
AfYBjv7UYmIBLGMAAP//ADkAAAI2AvcCJgEnAAAABwKPAJAAAP//ADkAAAI2AvcCJgEnAAAABgKT6gAAAP//ADkAAAI2As0CJgEn
AAAABwKNAJ8AAP//ACT/9QKZAs0CJgC3AAAABwKhAMIAAP//ACT/9QKZAs0CJgC3AAAABwKmAMIAAP//ACT/9QKZAs0CJgC3AAAA
BwKkAMIAAP//ACT/9QKZAs0CJgC3AAAABwKgAMIAAP//ACT/9QKZAs0CJgC3AAAABwKpAMIAAP//ACT/OAKjAfwCJgC3AAAABwKt
AcEAAP//ACT/9QKZAs0CJgC3AAAABwKnAMIAAP//ACT/9QKZAs0CJgC3AAAABwKoAMIAAP//ACT/9AKKAs0CJgDDAAAABwKhAMcA
AP//ACT/9AKKAs0CJgDDAAAABwKlAMcAAP//ACT/LgKKAfwCJgDDAAABBwKsAM3/9gAJsQEBuP/2sDUrAP//ACT/9QNmArkCJgDI
AAAABwKjAo8AAP//ACT/9AKIAs0CJgDMAAAABwKhAMoAAP//ACT/9AKIAs0CJgDMAAAABwKlAMoAAP//ACT/9AKIAs0CJgDMAAAA
BwKkAMoAAP//ACT/9AKIAs0CJgDMAAAABwKgAMoAAP//ACT/9AKIAs0CJgDMAAAABwKpAMoAAP//ACT/OAKIAfwCJgDMAAAABwKt
AaUAAP//ACT/MwKGAs0CJgDWAAAABwKmAJ4AAP//ACT/MwKGAsYCJgDWAAAABgKqAAAAAP//ADAAAADHAssCJgDdAAABBgKh5f4A
CbEBAbj//rA1KwAAAP//ADAAAADHAssCJgDdAAABBgKk5f4ACbEBAbj//rA1KwAAAP//ADAAAADHAssCJgDdAAABBgKg5f4ACbEB
Abj//rA1KwAAAP//ADAAAADHAssCJgDdAAABBgKp5f4ACbEBAbj//rA1KwAAAP//ADr/OAENAssCJgDcAAAABgKtKwAAAP//AEX/
OAKBArkCJgDnAAAABwKrALgAAP//AEEAAADYA4sCJgDpAAABBwKh//YAvgAIsQEBsL6wNSsAAP//AEYAAAGRArkAJgDpAAAABwKj
ALoAAP//AD3/OADTArkCJgDpAAAABgKr/AAAAP//ADwAAAJ7As0CJgDwAAAABwKhAOYAAP//ADwAAAJ7As0CJgDwAAAABwKlAOYA
AP//ADz/OAJ7AfwCJgDwAAAABwKrANAAAP//ADwAAAJ7As0CJgDwAAAABwKoAOYAAP//ACT/9AKcAs0CJgD2AAAABwKhAMsAAP//
ACT/9AKcAs0CJgD2AAAABwKkAMsAAP//ACT/9AKcAs0CJgD2AAAABwKgAMsAAP//ACT/9AKcAswCJgD2AAAABgKiXgAAAP//ACT/
9AKcAs0CJgD2AAAABwKpAMsAAP//ACT/9AKcAs0CJgD2AAAABwKoAMsAAP//ADwAAAF9As0CJgEDAAAABgKhVgAAAP//ADwAAAF9
As0CJgEDAAAABgKlVgAAAP//ADP/OAF9AfwCJgEDAAAABgKr8gAAAP//ACX/9AINAs0CJgEHAAAABwKhAIIAAP//ACX/9AINAs0C
JgEHAAAABwKlAIIAAP//ACX/LgINAfwCJgEHAAABBwKsAJr/9gAJsQEBuP/2sDUrAP//ACX/LgINAfwCJgEHAAABBwKrAKT/9gAJ
sQEBuP/2sDUrAP//ABkAAAHSAvQCJgENAAABBwKjAPsAOwAIsQEBsDuwNSsAAP//ABn/OAGbAnkCJgENAAAABgKsRAAAAP//ABn/
OAGbAnkCJgENAAAABgKrTgAAAP//ADz/9AJ7As0CJgESAAAABwKhAM8AAP//ADz/9AJ7As0CJgESAAAABwKkAM8AAP//ADz/9AJ7
As0CJgESAAAABwKgAM8AAP//ADz/9AJ7AswCJgESAAAABgKiYgAAAP//ADz/9AJ7As0CJgESAAAABwKpAM8AAP//ADz/OAKJAfEC
JgESAAAABwKtAacAAP//ADz/9AJ7As0CJgESAAAABwKnAM8AAP//AA8AAAPMAs0CJgEcAAAABwKhAVUAAP//AA8AAAPMAs0CJgEc
AAAABwKkAVUAAP//AA8AAAPMAs0CJgEcAAAABwKgAVUAAP//AA//OAJvAs0CJgEiAAAABwKhAKoAAP//AA//OAJvAs0CJgEiAAAA
BwKkAKoAAP//AA//OAJvAs0CJgEiAAAABwKgAKoAAP//ADkAAAI2As0CJgEnAAAABwKhAJ8AAP//ADkAAAI2As0CJgEnAAAABwKl
AJ8AAAAEACP/AgKQAf0AMAA1AEEATwEeS7AbUFi3NTMrAwcFAUwbS7AhUFi3NTMrAwkFAUwbtzUzKwMJBgFMWVlLsBtQWEA3AAQI
AAgEAIAAAwELAQMLgA0BCAwBAAEIAGkAAQALCgELZw4BCgACCgJkCQEHBwVhBgEFBS0HThtLsCFQWEBBAAQIAAgEAIAAAwELAQML
gA0BCAwBAAEIAGkAAQALCgELZw4BCgACCgJkAAkJBWEGAQUFLU0ABwcFYQYBBQUtB04bQD8ABAgACAQAgAADAQsBAwuADQEIDAEA
AQgAaQABAAsKAQtnDgEKAAIKAmQACQkFYQAFBS1NAAcHBl8ABgYnB05ZWUAnREI3NgMAS0hCT0RPPTs2QTdBKSgnJiUjHRwXFhIP
CgcAMAMwDwgWKyUiJwYGFRQWMzMyFhYVFAYjIyImNTQ2NyYmNTQ2NyYmNTQ2NjMyFyEVBiYnFhYVFAYDFhcmJwMyNjU0JiMiBhUU
FhMzMjY1NCYjIyIGFRQWAT4QEEY7GRXkPF02kY9KfHU4OTUyVEVHUUV3SyshAQ8yZCcxSJEjCgkKCVtBUE9BQVFQKzlaR0VXT0w2
Q3MBARIZEBAZOjJSTzw6JzAECCghMSoCFFhEP1syB2MBGhAYRjRYXwFiBAMEBf70NjIyNjcyMTb+kCIiIQ8THR8l//8AI/8CApAC
2gImAWsAAAAGApT5AAAA//8AI/8CApAC9wImAWsAAAAGApgEAAAA//8AI/8CApACzQImAWsAAAAHAo0AogAAAAEAGQAAAy8CuQAj
AKFLsBFQWEAiBgEDAwJfBQECAiZNCggCAAABXwcEAgEBJ00MCwIJCSUJThtLsCNQWEAqAAYGBV8ABQUmTQADAwJfAAICJk0KCAIA
AAFfBwQCAQEnTQwLAgkJJQlOG0AoAAIAAwECA2cABgYFXwAFBSZNCggCAAABXwcEAgEBJ00MCwIJCSUJTllZQBYAAAAjACMiISAf
ERMhIyIhIxERDQgfKzMRIzUzNTQ2MzMVIyYGFRUhNTQ2MzMVIyYGFRUzFSMRIxEhEYRra2JeaEksMQECYl5nSCwxpKSC/v4BhWMW
WlNpASE0BiRaU2kBIjMUY/57AYX+ewAAAQAZAAAECgK5ACUApkuwEVBYQCMGAQMDAl8FAQICJk0LCQIAAAFfBwQCAQEnTQ0MCgMI
CCUIThtLsCNQWEArAAYGBV8ABQUmTQADAwJfAAICJk0LCQIAAAFfBwQCAQEnTQ0MCgMICCUIThtAKQACAAMBAgNnAAYGBV8ABQUm
TQsJAgAAAV8HBAIBASdNDQwKAwgIJQhOWVlAGAAAACUAJSQjIiEgHxETISMiISMREQ4IHyszESM1MzU0NjMzFSMmBhUVITU0NjMh
FSEmBhUVIREjESMRIxEhEYRra2JeaEksMQECYl4BQv7dLDEBf4L9gv7+AYVjFlpTaQEhNAYkWlNpASIzFP4YAYX+ewGF/nsAAAAA
AQAZAAACjwK5ABUAWEuwFVBYQB4AAwMCXwACAiZNBgEAAAFfBAEBASdNCAcCBQUlBU4bQBwEAQEGAQAFAQBnAAMDAl8AAgImTQgH
AgUFJQVOWUAQAAAAFQAVERETISMREQkIHSszESM1MzU0NjMhFSEmBhUVIREjESERiXBwYl4BRv7ZLDEBhIL+/gF3YzJaU2kBIjMi
/iYBd/6JAAAAAAIAGQAAAnsCywADABEAlEuwG1BYQCMAAwMkTQAAAAFfCQEBASZNCAEGBgJfBAECAidNBwEFBSUFThtLsCNQWEAh
CQEBAAACAQBnAAMDJE0IAQYGAl8EAQICJ00HAQUFJQVOG0AhCQEBAAACAQBnCAEGBgJfBAECAidNAAMDBV8HAQUFJQVOWVlAGAAA
ERAPDg0MCwoJCAcGBQQAAwADEQoIFysBFSM1BTM1MxUhESMRIxEjESMCe5f+NXeCAV6C3IJ3AstyctqIiP4PAY7+cgGOAAAAAQAZ
/zgD4gJ5ABEAW7YLBgIGBQFMS7AjUFhAHQABASRNBwEFBQBfAwICAAAnTQAGBiVNAAQEKQROG0AdBwEFBQBfAwICAAAnTQABAQZf
AAYGJU0ABAQpBE5ZQAsRERIREhEREAgIHisTMzUzFTMTEzMBIzcDIxEjESMZd4L6pKeL/qiHbr+ggncB8YiI/pMBbf1HzQGJ/nIB
jgAAAgAkASUCaALEABcAJQBythQLAgQFAUxLsCZQWEAhAAMEAAQDAIAHAQQGAQAEAGUAAgI0TQAFBQFhAAEBNAVOG0AkAAIBBQEC
BYAAAwQABAMAgAcBBAYBAAQAZQAFBQFhAAEBNAVOWUAXGRgBACEfGCUZJQ8ODQwJBwAXARcICRYrASImJjU0NjYzMhYXNTMRIzAm
JjU1DgInMjY2NTQmJiMiBhUUFgENRWk7O2xJVGoUgnkFBA45WBY1US8wUTRGQkYBJTVcOj9gNU05e/53JzcYDiNBK2MdLxwkMho9
My07AAAAAgBGAR0CegLEAAsAFwAqQCcFAQIEAQACAGUAAwMBYQABATQDTg0MAQATEQwXDRcHBQALAQsGCRYrASImNTQ2MzIWFRQG
JzI2NTQmIyIGFRQWAWGDmJiDg5aWg01LSU9OTEsBHXBjYnJyYmNwX0EzMkNDMjNBAAD//wARAAADBAKHAgYAAQAA//8ATQAAAuMC
hwIGAAwAAAABAE0AAAKbAocABQAzS7ApUFhAEAABAQBfAAAAFE0AAgIVAk4bQBAAAgEChgABAQBfAAAAFAFOWbURERADBxkrEyEV
IREjTQJO/jeFAodv/egAAAACABEAAAMEAocAAwAGAEC1BgECAAFMS7ApUFhAEQAAABRNAAICAWADAQEBFQFOG0AOAAIDAQECAWQA
AAAUAE5ZQAwAAAUEAAMAAxEEBxcrMwEzASUhAxEBMJABM/3PAW23Aof9eW8BkgAAAP//AE0AAALFAocCBgAWAAAAAQA/AAACugKH
AAkARLcCAQMHAQECS0uwKVBYQBUAAwMAXwAAABRNAAEBAl8AAgIVAk4bQBIAAQACAQJjAAMDAF8AAAAUA05ZthIREhAEBxorEyEV
ASEVITUBIT8Ce/4lAdv9hQHb/iUCh2/+V29vAakAAP//AE0AAAMyAocCBgAkAAAAAwA1//MDZwKUAA8AHwAjADlANgAEAAUCBAVn
AAMDAWEAAQEaTQcBAgIAYQYBAAAbAE4REAEAIyIhIBkXEB8RHwkHAA8BDwgHFisFIiYmNTQ2NjMyFhYVFAYGJzI2NjU0JiYjIgYG
FRQWFgMhFSEBzoG3YWG3gYK2YWG2glB5RUV5UE98RkZ8fwGY/mgNUZZpapZRUZZqaZZRczBiS0tiMTFiS0tiMAEWaQAA//8AYAAA
AOUChwIGACYAAP//AE0AAAMVAocCBgAwAAAAAQARAAADBAKHAAYAOrUFAQEAAUxLsClQWEANAAAAFE0DAgIBARUBThtADQMCAgEA
AYYAAAAUAE5ZQAsAAAAGAAYREQQHGCszATMBIwMDEQEwkAEzkeroAof9eQIB/f///wBNAAAD/gKHAgYAOAAA//8ATQAAAzgChwIG
ADkAAAADADwAAALEAocAAwAHAAsATkuwKVBYQB0AAgADBAIDZwABAQBfAAAAFE0ABAQFXwAFBRUFThtAGgACAAMEAgNnAAQABQQF
YwABAQBfAAAAFAFOWUAJEREREREQBgccKxMhFSEXIRUhByEVITwCiP14WgHU/ixaAoj9eAKHb5dpqW8AAP//ADX/8wNnApQCBgA/
AAAAAQBNAAADMgKHAAcANkuwKVBYQBEAAgIAXwAAABRNAwEBARUBThtAEQMBAQIBhgACAgBfAAAAFAJOWbYREREQBAcaKxMhESMR
IREjTQLlhf4lhQKH/XkCGP3oAP//AEsAAALgAocCBgBKAAAAAQBNAAAC2AKHAAsASUAMCwoEAwIBCQEDAgJMS7ApUFhAFQABAQBf
AAAAFE0AAgIDXwADAxUDThtAEgACAAMCA2MAAQEAXwAAABQBTlm2ERIREAQHGisTIRUhBQUhFSE1JSVNAoH+IgEr/tUB6P11ASP+
3QKHb9TVb27W0QAAAP//ABQAAAK+AocCBgBWAAD//wATAAAC0QKHAgYAawAAAAMANQAAA6MCigARABgAHwBaS7ApUFhAHwUBAQgB
BwYBB2kJAQYEAQIDBgJpAAAAFE0AAwMVA04bQB8FAQEIAQcGAQdpCQEGBAECAwYCaQADAwBfAAAAFANOWUAOHh0UERMUEREUERAK
Bx8rATMVFhYVFAYHFSM1JiY1NDY3BxQWFxEGBgU0JicRNjYBqoWywsKyhbLDw7LtfXBwfQJbem9vegKKUQhxfXxxCE5OCHF8fXEI
9kg2BAEFBDdISDcE/vsENv//ACcAAALlAocCBgBqAAAAAQBEAAADdgKKABsAR0uwKVBYQBcHAQEFAQMEAQNpBgICAAAUTQAEBBUE
ThtAFwcBAQUBAwQBA2kABAQAXwYCAgAAFAROWUALFBQRERQUERAIBx4rATMRPgI1NTMVFAYGBxUjNS4CNTUzFRQWFhcBmoU+XzWF
UJpthWyaUIU1Xj4Civ62AxxHRKCgZHk6Bc7OBTp5ZKCgREccAwAAAQAjAAADSwKUACYAVEAJJRcSAwQABAFMS7ApUFhAGAAEBAFh
AAEBGk0CAQAAA18GBQIDAxUDThtAFQIBAAYFAgMAA2MABAQBYQABARoETllADgAAACYAJicRGCcRBwcbKzM1MzUmJjU0NjYzMhYW
FRQGBgcVMxUhNT4CNTQmIyIGFRQWFhcVI+pndV+udnauX0JkNO7+qi9XN36Af385WjBvERt7WFGFUFCFUUViOg0Rb5gQM044VG1t
VDpPMQ+YAAAA//8AAQAAA0kChwAmAAFFAAEGAoqikAAJsQIBuP+QsDUrAAAA//8AAAAAA+AChwAnABYBGwAAAQYCiqGQAAmxAQG4
/5CwNSsA//8AAAAABE0ChwAnACQBGwAAAQYCiqGQAAmxAQG4/5CwNSsA//8AAAAAAgAChwAnACYBGwAAAQYCiqGQAAmxAQG4/5Cw
NSsA//8AAP/zBCgClAAnAD8AwQAAAQYCiqGQAAmxAgG4/5CwNSsA//8AAAAABAAChwAnAGsBLwAAAQYCiqGQAAmxAQG4/5CwNSsA
//8AAAAAA/MClAAnAY0AqAAAAQYCiqGTAAmxAQG4/5OwNSsA////6gAAAVoDSAImACYAAAEGAoyafAAIsQECsHywNSv//wATAAAC
0QNIAiYAawAAAQYCjGp8AAixAQKwfLA1KwACACT/9QKZAfwAFwAjAJG2FAsCBAUBTEuwF1BYQBkABQUBYQIBAQEdTQcBBAQAYQMG
AgAAFQBOG0uwKVBYQCEAAgIXTQAFBQFhAAEBHU0AAwMVTQcBBAQAYQYBAAAVAE4bQCEABQUBYQABAR1NAAMDAl8AAgIXTQcBBAQA
YQYBAAAVAE5ZWUAXGRgBAB8dGCMZIw8ODQwJBwAXARcIBxYrBSImJjU0NjYzMhYXNTMRIzQmJjU1DgInMjY1NCYjIgYVFBYBLkp5
R0h8TWFtFIJ5BQQOOl4ZWWZnWFNcYAtBdU1PdEFYR5T+DwMnOR0gLU4wZFhHTVJXSEhXAAACADz/OAKwAsUAFwAuAH21CAEGBwFM
S7AbUFhAKgADBAcHA3IIAQQABwYEB2cABQUCYQACAhxNAAYGAGEAAAAVTQABARkBThtAKwADBAcEAweACAEEAAcGBAdnAAUFAmEA
AgIcTQAGBgBhAAAAFU0AAQEZAU5ZQBMZGC0rJyUfHRguGS4VIxQjCQcaKyUUBgYjIiYmJxEjETQ2MzIWFRQGBgcWFiUyNTQmJiMi
BgYVFRQWMzI2NTQmIyM1ArBDc0pDYj4PgpealZA0SB5TZf7pdBlFQjVPK2ZYV1hIS3u8QFkvMlAu/pQCiYl7blouPB4BClmCViE3
IBhBPdNIV0g5MTtNAAEAD/84AmMB8QAIACNAIAcEAQMAAQFMAwICAQEXTQAAABkATgAAAAgACBISBAcYKwEDFSM1AzMTEwJj7ILm
j5meAfH+Fc7QAen+mgFmAAAAAgAk//QCjgK5AB0AKwBEQEELAQQFAUwRAQMBSwABAAUEAQVpAAMDAl8AAgIWTQcBBAQAYQYBAAAV
AE4fHgEAJyUeKx8rFhUUEwkHAB0BHQgHFisFIiYmNTQ2NjMyFhczLgMnIzUhFSEeAhUUBgYnMjY2NTQmJiMiBhUUFgFYYIpKSHdF
SnoeAwpOcH03BQHj/vdmgz9Mi1k0UzI0VTNTX2MMPHFNSmc2QD8qTkU0D2NjJ3KCP1B3QWUhQjAxQB9JR0lKAAEAL//0ApYB/AAx
AFJATwADBAUEAwWAAAEFBgUBBoAACAYHBggHgAAFAAYIBQZnAAQEAmEAAgIdTQAHBwBhCQEAABUATgEALy4rKSMhIB0ZFxQTEQ8J
CAAxATEKBxYrBSImJjU0NjY3LgI1NDY2MzIWFyMuAiMiBhUUFhYzMxUjIgYGFRQWFjMyNjY3MwYGAVxTiVE2Uy0tTzFMhFSDphB3
CzxQK0pRJjwie3sjQCgsSiwvUDkLdxagDBw/MyoxGAIBFy8kLkUna1kiKhQqIBcUBEwJGBcaHgsQKydiZAAAAQAy/zgCLQK5AB8A
HkAbAAEBAUsAAQECXwACAhZNAAAAGQBOER0eAwcZKwEOAxUUHgUVFSM1NC4FNTQ2NjchNSECLW6SVCMiN0NCOCKCIjhDQzgiWZ5p
/sIB2QJWLVhXVywpMB0XHTJSQVBQKjIeGB0xUD9MhGskYwAAAAEAPP84AnsB/AAWAHC2FAICBAMBTEuwF1BYQBYAAwMAYQEBAAAX
TQAEBBVNAAICGQJOG0uwKVBYQBoAAAAXTQADAwFhAAEBHU0ABAQVTQACAhkCThtAGgADAwFhAAEBHU0ABAQAXwAAABdNAAICGQJO
WVm3FCMUJBAFBxsrEzMVPgIzMhYWFREjETQmIyIGBgcRIzyCDT5ePj1hOII9RS1LNguCAfGPKEYsK1pH/ggB4T87HjEc/tgAAAAA
AwAu//MCtwLDAA8AFgAdAD5AOwADAAUEAwVnBwECAgFhAAEBHE0IAQQEAGEGAQAAGwBOGBcREAEAGxoXHRgdFBMQFhEWCQcADwEP
CQcWKwUiJiY1NDY2MzIWFhUUBgYDIgYHISYmAzI2NyEWFgF0cpBERJByc45CQo5zVV8KAXkJXVVVXAr+hwpfDV2jaWqhXFyhammj
XQJtdFxcdP32dVxcdQABADz/8QEeAfEACQASQA8JAAIASQAAABcAThQBBxcrIQYmNREzERQWNwEeemiCLzEPXloBSP7FMyQHAAAC
ADwAAAJ4AfEAAwAJAD62CAUCAQABTEuwKVBYQA4EAwIAABdNAgEBARUBThtADgIBAQEAXwQDAgAAFwFOWUAMBAQECQQJExEQBQcZ
KxMzESMBBwEjATc8goICJfwBE6X+7u8B8f4PAfHe/u0BF9oAAQAQAAACZAK8ABAASbYKBwIBAwFMS7ApUFhAEgADAwBfBAEAABZN
AgEBARUBThtAEgIBAQMBhgADAwBfBAEAABYDTllADwEADw0JCAYFABABEAUHFisTMhYXFxMjAwMjEycmJiMjNaU8VBsq6o+dmo7n
FRMnJjcCvDM7Xf4PAVz+pAHhMSwbYwAAAP//ADz/OALbAfEABgJ7AAD//wAPAAACYwHxAgYBGwAAAAEALv84Af8CuQAuADFALg4B
AQFLAAADBAMABIAAAwAEBQMEZwABAQJfAAICFk0ABQUZBU4cIScRFRQGBxwrNzQ2NjcmJjU0NjcjNSEVDgMVFDczFSMiBgYVFB4F
FRUjNTQuBS4vSig8SWt38gHFXHVBGmaFhSM+KCI4QkM3IoIhOENCOCK+Lj4gAgI/Lz1HFmNjFCEiKBtOAUwMIyMcIRYUHjNSP1BQ
KjQhFxgjOAD//wAk//QCnAH8AgYA9gAAAAEAMv/1At0B8QAUAEVACgQBAQABTAUBAUlLsClQWEASBAICAAADXwADAxdNAAEBFQFO
G0ASAAEAAYYEAgIAAANfAAMDFwBOWbcRERERGwUHGyslFBYWNxUGLgI1NSMRIxEjNSEVIwJtEjEtUWAuDsyCcAKrcL8mKw0FZgsV
Nk0s1f5yAY5jYwACADz/OAKwAfwAEgAfADpANwQBAwQBTAAEBAJhAAICHU0GAQMDAGEFAQAAFU0AAQEZAU4UEwEAGhgTHxQfDAoG
BQASARIHBxYrBSImJicRIxE0NjYzMhYWFRQGBicyNjU0JiMiBgYVFBYBpkJeOg6CS49mX4pLSHh0UF9bVDVXMmYMME8t/pgBtlF6
Q0J1TU91QGVXSEhYJkczSFcAAAAAAQAk/zgCiQH8ACEAIkAfAAIDAAMCAIAAAwMBYQABAR1NAAAAGQBOIhIsGQQHGis3FB4FFRUj
NTQuBTU0NjYzMhYXIyYmIyIGBqgtSVhYSS2CLUlZWEotU5Fcg5kJdxFcQTRVM/c2PB8TFSlMQVBQKCoVEBo0XkxVdDxtYTI4JEcA
AAAAAgAk//QCwAHxABIAIAAwQC0EAQICAV8AAQEXTQYBAwMAYQUBAAAVAE4UEwEAGxkTIBQgCwoJBwASARIHBxYrBSImJjU0NjYz
IRUjHgIVFAYGJzI2NjU0JiMiBgYVFBYBYV6PUFCPXgFf5DJYNlCNXjRTMGhPNFQxagw7dFNUcDdkCitNPEBjOGQgQjNMVCBDNExS
AAEAHv/1AbEB8QAQABpAFwUEAgBJAgEAAAFfAAEBFwBOEREbAwcZKyUUFhY3FQYuAjU1IzUhFSMBIxIxLVFgLg6IAZOOvyYrDQVm
CxU2TSzVY2MAAAEAPP/0AnwB8QARACFAHgQDAgEBF00AAgIAYQAAABUATgAAABEAESMTIwUHGSsBFRQGIyImNTUzFRQWMzI2NTUC
fJOMjZSETk9OTQHx+n6FhX76+kxTU0z6AAAAAwAt/zgDcQK5ABEAGAAfADRAMQADAxZNCQEGBgJhBAECAhdNCAEHBwFhBQEBARVN
AAAAGQBOHh0UERMUEREUERAKBx8rBSM1JiY1NDY3NTMVFhYVFAYHEzQmJxE2NiUUFhcRBgYCEIK2q6q3greqqrfcZXd3Zf3GZXd3
Zci+CYB6eYAJvr4JgHl6gAkBA0pNB/7DCE5JSU4IAT0ITgAAAAEAFP84An0B8QALACBAHQsIBQIEAgABTAEBAAAXTQMBAgIZAk4S
EhIQBAcaKxMzFzczAxMjJwcjExSamY+Z4/Ganpea7QHx6+v+rf6a9/cBXwAAAAEAPP84AzAB8QAVACBAHRUNCgIEAAEBTAMCAgEB
F00AAAAZAE4UFBUQBAcaKwUjNSYmNTUzFRQXETMRNjU1MxUUBgcB94Kan4S1grWEn5rIvgyJgObmmhUBlf5qFZvm5oCKCwABACT/
9AOUAf0AMgBEQEEwAQMEAUwABAIDAgQDgAYBAgIBYQcBAQEdTQUBAwMAYQgJAgAAFQBOAQAuLCYlJCMdGxcWEhAKCQgHADIBMgoH
FisFIiYmNTQ2NjMVIgYGFRQWFjMyNjY1NTMVFBYWMzI2NjU0JiYjNTIWFhUUBgYjIiYnBgYBE0prOkB5VCs9IR04KisyFoQXMysl
OCAhPStUeUA5akpRZBYVYwxFdkpKdkRkLkkpKUouLkopZWUpSi4uSikpSS5kRHZKSnZFTENDTAAA//8AN//xAWsC9wImAZ8AAAAG
Ao/YAAAA////yv/xAToCzAImAZ8AAAAnAiL/jgJaAQcCIgBnAloAErEBAbgCWrA1K7ECAbgCWrA1K////2H/8QHBAvkCJgGfAAAB
BwKL/2EAFAAIsQEDsBSwNSsAAP//ADz/9AJ8AvcCJgGrAAAABwKPALgAAP//ADz/9AJ8AswCJgGrAAAAJwIiAGgCWgEHAiIBQQJa
ABKxAQG4AlqwNSuxAgG4AlqwNSv//wAs//QCjAL5AiYBqwAAAQYCiywUAAixAQOwFLA1K///ACT/9AKcAvcCJgD2AAAABwKPALwA
AP//ACT/9AOUAvcCJgGvAAAABwKPATYAAP//ACT/9QKZAvcCJgGXAAAABwKKALMAAP//AC//9AKWAvcCJgGbAAAABwKPALYAAP//
ADz/OAJ7AvcCJgGdAAAABwKPANcAAAABACT/9AKKAfwAHgBBQD4AAgMEAwIEgAgBBwUGBQcGgAAEAAUHBAVnAAMDAWEAAQEtTQAG
BgBhAAAALgBOAAAAHgAeIhESIhImIgkIHSslBgYjIiYmNTQ2NjMyFhcjJiYjIgYHIRUhFhYzMjY3AooHm4RckVNTkVyDmQl3EVxB
RGYOART+7AxnRUZZEMRibjtzVVV0PG1hMjg9PEw+PTg0AAAA//8AJP/0AooC9wImAbsAAAAHAo8AtgAA//8ANf/0Aq0B/AAGAdER
AP//ABkAAAEoAfEABgHSAAD//wAfAAACSAH9AAYB0+kA//8AIf9cAl0B/gIGAdQAAP//AC//bwKfAfUCBgHVAAD//wA6/10CfgH0
AAYB1gAA//8AGv/zAo4ChwIGAdcAAP//ACH/agJcAfECBgHYAAD//wAq//MCeQKUAgYB2QAA//8AJP9qAp8CAAIGAdoAAAACADX/
8wLVApQADwAfAC1AKgADAwBhBAEAACpNBQECAgFhAAEBKwFOERABABkXEB8RHwkHAA8BDwYIFisBMhYWFRQGBiMiJiY1NDY2EzI2
NjU0JiYjIgYGFRQWFgGFbpZMTJZubpZMTJZuN1k1NVk3N1s2NlsClFWYZGOYVVWYY2SYVf3ONGVISWM0NGNJSGU0AAAAAQAcAAAB
LAKHAAUAH0AcAwECAgBfAAAAJE0AAQElAU4AAAAFAAUREQQIGCsTNSERIxEcARCCAhts/XkCGwAAAAEAJgAAAlUClAAeAC1AKgUB
AAFLAAMCAAIDAIAAAgIEYQAEBCpNAAAAAV8AAQElAU4jEikREQUIGyslByEVITU+BDU0JiMiBgcjJjY2MzIWFhUUDgIBN30Bm/3f
cZRWKQxCSEFQAn4DQXxUUXxGLk9ivE1vb01pRS4jEycxMik5WzUqVEAsTkQ/AAAAAQAi//MCXgKUAC0AQUA+KgEDBAFMAAYFBAUG
BIAAAQMCAwECgAAEAAMBBANnAAUFB2EABwcqTQACAgBhAAAAKwBOIxIkISQiEyMICB4rJRQGBiMiJiY3MxYWMzI2NTQmIyM1MzI2
NTQmIyIGByMmNjYzMhYVFAYGBx4CAl5HgVhXgUQDfgJZQEhOWlJVVVZLSkFAUgJ+A0l/TYGTNV09QWM3sjhXMDVdPCs0MTEwM0kx
LSkuMik/WjFhTzQ+HQUFIEEAAAIALwAAAp8ChwAKAA0AM0AwDQEABAFMCQEAAUsFAQADAQECAAFnBgEEBCRNAAICJQJOAAAMCwAK
AAoRERERBwgaKwERMxUjFSM1ITUBAzM1Aixzc4L+hQF74OACh/5iY4aGYwGe/mL6AAAAAAEAOf/zAnwCigAkAElARiIBBAAdHAIC
BAJMAAIEAwQCA4AHAQAABAIABGkABgYFXwAFBSRNAAMDAWEAAQErAU4BACEgHx4aGBIQDQwJBwAkASQICBYrATIWFhUUBgYjIiYm
JzMeAjMyNjY1NCYmIyIGBycTIRUhBzY2AZM/akBGflRQhlIDfAQwSisnSC4tRiYvXhhxHgHP/qoSHWoBmS5bRUVhMjFaQB8rFhcx
JicxGBskFQF4b9AmKAAAAgAa//MCjgKKABcAIwA4QDUVAQQAAUwFAQAABAMABGoAAgIkTQYBAwMBYQABASsBThkYAQAfHRgjGSMU
EwgGABcBFwcIFisBMhYWBwYGIyImJjc0Njc+AzczAzY2EzI2NzYmIyIGBwYWAYhPdkEBAaCMY5NQAQ8UBS5ETSKk4iNOAk1hAQFf
TVZmAQFpAao2Y0JkeDJhRBg5IQdEY28x/uccHf6zPDg4PUQyODsAAAABABQAAAJQAocABgAkQCEDAQIBSwMBAgIAXwAAACRNAAEB
JQFOAAAABgAGEhEECBgrEzUhFQEjARQCPP7HnAFJAhhvb/3oAhgAAAAAAwAk//MCdAKUABkAJQAxAEVAQhMHAgUCAUwHAQIABQQC
BWkAAwMBYQABASpNCAEEBABhBgEAACsATicmGxoBAC0rJjEnMSEfGiUbJQ4MABkBGQkIFisFIiYmNTQ2NyYmNTQ2MzIWFRQGBxYW
FRQGBgMyNjU0JiMiBhUUFhMyNjU0JiMiBhUUFgFMZINBWFFKTImMjIlMSlFYQYNkSkdHSkpEREpUUFBUVE1NDTNWNkVQDw1FPE1j
Y008RQ0PUEU1VzMBiDMlJi8vJiUz/uY1KSw1NSwpNQAAAgAkAAACnwKWABgAJAA4QDUWAQAEAUwABAUBAAIEAGkGAQMDAWEAAQEq
TQACAiUCThoZAQAgHhkkGiQVEwgGABgBGAcIFislIiYmNTY2MzIWBxQGBw4FMSMTBgYTIgYHBhYzMjY3NiYBKk13QgKjlZWsAhIW
AyQzODAfpeMkUgJSYQEBX1JWZwEBaeA3YkJmdW9nGjoiBjVLUUcsARsdHgFNOjo4PUI0OToAAAIAJP/0ApwB/AAPAB8ALUAqAAMD
AWEAAQEtTQUBAgIAYQQBAAAuAE4REAEAGRcQHxEfCQcADwEPBggWKwUiJiY1NDY2MzIWFhUUBgYnMjY2NTQmJiMiBgYVFBYWAWFe
j1BQj15ejVBQjV4zUzExUjQzVDIxVAw8c1RUdTw8dVRUczxkJUczM0kmJkg0M0clAAEAGQAAASgB8QAFAB9AHAMBAgIAXwAAACdN
AAEBJQFOAAAABQAFEREECBgrEzUhESMRGQEPggGCb/4PAYIAAAABADYAAAJfAf0AGgAtQCoFAQABSwADAgACAwCAAAICBGEABAQt
TQAAAAFfAAEBJQFOIxInEREFCBsrJQchFSE1PgI1NCYjIgYHIyY2NjMyFhYVFAYBkW0BO/3rea1dQUc/TQJ+Az96U1F7RVuXM2Rk
NkY9KCMsMSo6WDIpSzQ7VAAAAAABACH/XAJdAf4ALQA+QDsqAQMEAUwABgUEBQYEgAABAwIDAQKAAAQAAwEEA2cAAgAAAgBlAAUF
B2EABwctBU4jEiQhJCITIwgIHislFAYGIyImJjczFhYzMjY1NCYjIzUzMjY1NCYjIgYHIyY2NjMyFhUUBgYHHgICXUeCWFaBRAN+
AVJHSU5aUlVVVktCSkZLAn4DSX9MgZM0XT1BYzcbOFYxNV09KzUyMS8nZCMsKS8yKT5bMWFQND0dBQUfQgACAC//bwKfAfUACgAN
AFhACw0BAAQBTAkBAAFLS7AtUFhAGAUBAAABXwMBAQElTQACAgRfBgEEBCcCThtAFgUBAAMBAQIAAWcAAgIEXwYBBAQnAk5ZQA8A
AAwLAAoAChEREREHCBorAREzFSMVIzUhNQEDMzUCLHNzgv6FAXve3gH1/mRkhoZkAZz+ZPkAAAABADr/XQJ+AfQAJABGQEMiAQQA
HRwCAgQCTAACBAMEAgOABwEAAAQCAARpAAMAAQMBZQAGBgVfAAUFJwZOAQAhIB8eGhgSEA0MCQcAJAEkCAgWKwEyFhYVFAYGIyIm
JiczHgIzMjY2NTQmJiMiBgcnEyEVIQc2NgGUQmo+Rn5VT4ZTA3wEMEsrKEctK0YoL14YcR4Bz/6qER1qAQMuW0VFYDMxWz8fKxYX
MSYnMRgbJBUBeG/OJCgAAgAa//MCjgKHABkAJQA4QDUXAQQAAUwFAQAABAMABGoAAgIkTQYBAwMBYQABASsBThsaAQAhHxolGyUW
FAgGABkBGQcIFisBMhYWBwYGIyImJjc0Njc+BTEzAzY2EzI2NzYmIyIGBwYWAYhPdkEBAaCMY5NQAQ8UBCQ1ODIfpOAjTQFNYQEB
X01WZgEBaQGqNmNCZHgyYUQYOSEHNUtRRyz+7Bod/rM8ODg9RDI4OwABACH/agJcAfEABgAkQCEDAQIBSwABAgGGAwECAgBfAAAA
JwJOAAAABgAGEhEECBgrEzUhFQEjASECO/7InQFJAYJvb/3oAhgAAAAAAwAq//MCeQKUABkAJQAxAEVAQhMHAgUCAUwHAQIABQQC
BWkAAwMBYQABASpNCAEEBABhBgEAACsATicmGxoBAC0rJjEnMSEfGiUbJQ4MABkBGQkIFisFIiYmNTQ2NyYmNTQ2MzIWFRQGBxYW
FRQGBgMyNjU0JiMiBhUUFhMyNjU0JiMiBhUUFgFRY4NBV1FJTImLjIlMSlFYQYNkSkdHSklERElVT09VVExMDTNXNUVQDw1FPE1j
Y008RQ0PUEU1VzMBiDMlJi8vJiUz/uY1KSw1NSwpNQAAAgAk/2oCnwIAABgAJAA4QDUWAQAEAUwAAgAChgAEBQEAAgQAaQYBAwMB
YQABAS0DThoZAQAgHhkkGiQVEwgGABgBGAcIFislIiYmNTY2MzIWBxQGBw4FMSMTBgYTIgYHBhYzMjY3NiYBKk13QgKjlZWsAhIW
AyQzODAfpeMkUgJSYQEBX1JWZwEBaUo3YkJmdW9nGjoiBjVLUUcsARsdHgFNOjo4PUI0OToAAAIAKf/zApsClAAPABsALUAqAAMD
AGEEAQAAKk0FAQICAWEAAQErAU4REAEAFxUQGxEbCQcADwEPBggWKwEyFhYVFAYGIyImJjU0NjYTMjY1NCYjIgYVFBYBYmmLRUWL
aWmLRUWLaVBdXVBQYWEClFWYZGOYVVWYY2SYVf3OdG1tc3NtbXQAAAABAFkAAAJtAocACQAhQB4AAQECXwACAiRNAwEAAARfAAQE
JQROERERERAFCBsrNzMRIzUhETMVIVnUtAE2vv3sbwGsbP3ob///AEkAAAJ4ApQABgHJIwD//wBD//MCfwKUAAYByiEA//8AKgAA
ApoChwAGAcv7AAABAET/8wKHAooAIwBJQEYhAQQAHBsCAgQCTAACBAMEAgOABwEAAAQCAARpAAYGBV8ABQUkTQADAwFhAAEBKwFO
AQAgHx4dGRcRDw0MCQcAIwEjCAgWKwEyFhYVFAYGIyImJiczFhYzMjY2NTQmJiMiBgcnEyEVIQc2NgGdP2pBR35UT4ZSA3wFYUMl
RzAvRiQxWxhxHQHP/qoRHWkBmS5bRUVhMjFaQC4yFzEmJzEYGyQVAXhvzyUoAAAAAAIAK//zAokChwAaACcAOEA1GAEEAAFMBQEA
AAQDAARqAAICJE0GAQMDAWEAAQErAU4cGwEAIiAbJxwnFxUJBwAaARoHCBYrATIWFgcOAiMiJiY1NjY3PgUxMwM2NgMyNjc2JiMi
BgcUFhYBjEtxQQEBSIJZXY1PAQ8UBCIxNi8dpdMfRgFIXAEBWkhPYgEtUAGqNmNCQmM3MmFEGDkhBzVLUUcs/vIYGf6zOzk4PUMz
JjMa//8ARAAAAoAChwAGAc4wAP//AD//8wKOApQABgHZFQAAAgAzAAACkQKUABoAJwA4QDUYAQAEAUwABAUBAAIEAGkGAQMDAWEA
AQEqTQACAiUCThwbAQAiIBsnHCcXFQkHABoBGgcIFislIiYmNz4CMzIWFgcUBgcOBTEjEwYGEyIGBwYWMzI2NzYmJgEvSHNBAQFH
gllejU8BDxQEIzE2Lx2k0h9GAklbAQFZSU1jAQEvTt03YkJDYjcyYUUXOSEGNktRRywBDhgZAU07OTg9QzMmMxoAAgAs//QCmAH8
AA4AGgAtQCoAAwMBYQABAS1NBQECAgBhBAEAAC4AThAPAQAWFA8aEBoJBwAOAQ4GCBYrBSImJjU0NjYzMhYWFRQGJzI2NTQmIyIG
FRQWAWNejE1NjF5fikynjk5kY09OZmUMPHNUVHU8PHVUfoVlUkxNVFRNTFIAAAAAAQBnAAACZgHxAAkAIUAeAAEBAl8AAgInTQMB
AAAEXwAEBCUEThEREREQBQgbKzczESM1IREzFSFnxrQBNrf+AWwBGWz+e2z//wBIAAACcQH9AAYB0xIA//8AQf9cAn0B/gAGAdQg
AP//ACb/bwKWAfUABgHV9wAAAQBB/1oChQHxACMARkBDIQEEABwbAgIEAkwAAgQDBAIDgAcBAAAEAgAEaQADAAEDAWUABgYFXwAF
BScGTgEAIB8eHRkXEQ8NDAkHACMBIwgIFisBMhYWFRQGBiMiJiYnMxYWMzI2NjU0JiYjIgYHJxMhFSEHNjYBnEBpQEZ+VFGGUgN8
BWJDJkcvLkUlMV8YcR4B0/6mEh5sAQAuXERFYDMxWz8uMhcxJicxGBskFQF4b88lKAAAAAIAM//zApEChwAaACYAOEA1GAEEAAFM
BQEAAAQDAARqAAICJE0GAQMDAWEAAQErAU4cGwEAIiAbJhwmFxUJBwAaARoHCBYrATIWFgcUBgYjIiYmNzQ2Nz4FMTMDNjYDMjY3
NiYjIgYHBhYBlEtyQAFIglldjk8BDxQEIzE1Lx2l1B9HAUhcAQFaSE9hAQFkAao2Y0JCYzcyYUQYOSEHNUtRRyz+8Rga/rM7OTg9
QzM5OgAAAAEAQP9qAnsB8QAGACRAIQMBAgFLAAECAYYDAQICAF8AAAAnAk4AAAAGAAYSEQQIGCsTNSEVASMBQAI7/sidAUkBgm9v
/egCGAAAAP//AED/8wKPApQABgHZFgAAAgAz/2gCkQH8ABoAJgA4QDUYAQAEAUwAAgAChgAEBQEAAgQAaQYBAwMBYQABAS0DThwb
AQAiIBsmHCYXFQkHABoBGgcIFislIiYmNz4CMzIWFgcUBgcOBTEjEwYGEyIGBwYWMzI2NzYmAS9Ic0EBAUeDWF6NTwEPFAQjMTYv
HaTRHkYFSV4BAVxJUF0BAWBFN2NCQmM2MmBFGDghBzVMUUcsAQ4YGQFNOjo3PkMzOToAAAAAAgAk//MBvwGSAAsAFwArQCgEAQAA
AwIAA2kFAQICAWEAAQErAU4NDAEAExEMFw0XBwUACwELBggWKxMyFhUUBiMiJjU0NhMyNjU0JiMiBhUUFvFlaWllZGlpZC8wMC8u
MTEBknNdXXJyXV1z/sU6MTI4ODIxOgAAAQAZAAABbgGJAAkAJUAiAAIAAQACAWcDAQAABF8FAQQEJQROAAAACQAJEREREQYIGisz
NTM1IzUzETMVGXt36WhX21f+zlcAAQAfAAABgAGUABYAUbUCAQAEAUxLsB1QWEAaAAIBBAECcgADAAECAwFpAAQEAF8AAAAlAE4b
QBsAAgEEAQIEgAADAAECAwFpAAQEAF8AAAAlAE5ZtxYiEiUQBQgbKyEhNTY2NTQjIgYHIyY2MzIWFRQGBwc3AYD+qX5oPCkkA2ED
XFlLXVc+RN1VN1wiLhwON088ODpRIR8DAAAAAQAg//MBhwGTACgAhkuwC1BYQDMABgUEBQYEgAkBCAQDBQhyAAEDAgMBAoAABwAF
BgcFaQAEAAMBBANpAAICAGEAAAArAE4bQDQABgUEBQYEgAkBCAQDBAgDgAABAwIDAQKAAAcABQYHBWkABAADAQQDaQACAgBhAAAA
KwBOWUARAAAAKAAoIxIkISMiEiUKCB4rNxYWFRQGIyImNzMWFjMyNjU0IyM1MzI2NTQmIyIGByMmNjYzMhYVFAb9PkxdU1ZhBFYB
Li0oI1k6Oi0mIyUnLQFWAixPMVNbR8kFJzA3Q0s7FhkYGDE3GBYSFhcRKDsgPy0tLQACAC8AAAGdAYkACgANAC9ALA0DAgIBAUwA
AQIBhQUBAgMBAAQCAGgGAQQEJQROAAAMCwAKAAoRERIRBwgaKzM1IzU3MxUzFSMVJzM1+MnVZTQ0y15IUu/yT0iTfgAAAAABADr/
8wGjAYoAHQBHQEQcAQQAFxYCAgQCTAACBAMEAgOAAAUABgAFBmcHAQAABAIABGkAAwMBYQABASsBTgEAGxoZGBQSDgwKCQcFAB0B
HQgIFislMhYVFAYjIiYnMxYWMzI2NTQmIyIGByc3IRUjBzYBEkBRXFVQZQNbAjMrICcmHiUzBlAOASXWCCj8RD1ASEg+FhsdGxwb
Dg8V21ViKQAAAAIAG//zAY8BiQAVACEAX7UUAQQAAUxLsAtQWEAbAAIAAAJwBQEAAAQDAARqBgEDAwFhAAEBKwFOG0AaAAIAAoUF
AQAABAMABGoGAQMDAWEAAQErAU5ZQBUXFgEAHRsWIRchExEHBQAVARUHCBYrEzIWFRQGIyImNTQ2Nz4EMTMHNhcyNjU0JiMiBhUU
FvlEUlxTXWgLEQYcJCEWenccByspKispMTEBDUw+Qk5NOhQoFwssNTAgjRHDIhobISEbGiIAAAABABcAAAFpAYkABgAjQCADAQEC
AUwAAAMBAgEAAmcAAQElAU4AAAAGAAYSEQQIGCsTNSEVAyMTFwFSnnqlATRVVv7NATQAAAADACr/8wGQAZIAFwAjAC8AO0A4DAEF
AwFMAAEGAQIDAQJpAAMABQQDBWkHAQQEAGEAAAArAE4lJBkYKykkLyUvHx0YIxkjKiUICBgrJRYWFRQGIyImNTQ2NyYmNTQ2MzIW
FRQGJyIGFRQWMzI2NTQmBzI2NTQmIyIGFRQWAS8pOFpZWVo3JSIvVlJSVTB3IR8gICAiIiAmJycmJyUlygcuKTZDQzYpLwcIKyQ0
PDw0JCxqFhMTGBgTExb0GhYXGhoXFhoAAgAkAAABmQGTABYAIgA2QDMOAQIDAUwFAQAABAMABGkGAQMAAgEDAmkAAQElAU4YFwEA
HhwXIhgiEhANCwAWARYHCBYrEzIWFRQGBw4EMSM3BgYjIiY1NDYXMjY1NCYjIgYVFBbYWmcLEQYdJCEWenUNGxFJVF9YKTAwKSkp
KgGTTTsTKBgKKzQwH4gHCEw+Qk7PIRsaISEaGyEAAgAkAPEBvwKPAAsAFwAqQCcFAQIAAQIBZQADAwBhBAEAACoDTg0MAQATEQwX
DRcHBQALAQsGCBYrEzIWFRQGIyImNTQ2EzI2NTQmIyIGFRQW8WVpaWVkaWlkLzAwLy4xMQKPcl1dcnJdXXL+xjkyMTk5MTE6AAAA
AQAZAP4BbgKHAAkAJEAhAwEABQEEAARjAAEBAl8AAgIkAU4AAAAJAAkRERERBggaKzc1MzUjNTMRMxUZe3fpaP5X21f+zlcAAQAf
AP4BgAKRABYAT7UCAQAEAUxLsB9QWEAZAAIBBAECcgAEAAAEAGMAAQEDYQADAyoBThtAGgACAQQBAgSAAAQAAAQAYwABAQNhAAMD
KgFOWbcWIhIlEAUIGyslITU2NjU0IyIGByMmNjMyFhUUBgcHNwGA/ql+aDwpJANhA1xZS11XPkTd/lU3WyMtGw42Tzs5OVEhHwMA
AAAAAQAgAPEBhwKRACgAuUuwHVBYQDMABwYFBgcFgAAABQQFAHIAAgQDBAIDgAADAAEDAWUABgYIYQAICCpNAAQEBWEABQUnBE4b
S7AwUFhAMQAHBgUGBwWAAAAFBAUAcgACBAMEAgOAAAUABAIFBGkAAwABAwFlAAYGCGEACAgqBk4bQDIABwYFBgcFgAAABQQFAASA
AAIEAwQCA4AABQAEAgUEaQADAAEDAWUABgYIYQAICCoGTllZQAwjEiQhIyISJBAJCB8rExYWFRQGIyImNzMWFjMyNjU0IyM1MzI2
NTQmIyIGByMmNjYzMhYVFAb6QE1dU1ZhBFYBLi0oI1k6Oi0mIyUnLQFWAixPMVNbSAHGBCYxN0NLOxYaGRgxNxgWEhYXESg7ID8t
LS4AAgAvAP4BnQKHAAoADQBStg0DAgIBAUxLsBFQWEAXBgEEAAAEcQUBAgMBAAQCAGgAAQEkAU4bQBYGAQQABIYFAQIDAQAEAgBo
AAEBJAFOWUAPAAAMCwAKAAoRERIRBwgaKzc1IzU3MxUzFSMVJzM1+MnVZTQ0y17+R1Pv8lBHk34AAAAAAQA6APEBowKHAB0ASEBF
HAEEABcWAgIEAkwAAgQDBAIDgAADAAEDAWUABgYFXwAFBSRNAAQEAGEHAQAALQROAQAbGhkYFBIODAoJBwUAHQEdCAgWKwEyFhUU
BiMiJiczFhYzMjY1NCYjIgYHJzchFSMHNgESQFFcVVBlA1sCMysgJyYeJTMGUA4BJdYIKAH6RD5AR0g+FhscHBwbDw4U21RiKQAC
ABsA8QGPAocAFgAiAFq1FAEEAAFMS7AjUFhAGQYBAwABAwFlAAICJE0ABAQAYQUBAAAtBE4bQBcFAQAABAMABGoGAQMAAQMBZQAC
AiQCTllAFRgXAQAeHBciGCITEQcFABYBFgcIFisTMhYVFAYjIiY1NDY3PgQxMwc2NgcyNjU0JiMiBhUUFvlEUlxTXWgLEQYcJCEW
encOIAsrKSorKTExAgpLPkNNTToUKBcKLTUwII0ICMIhGhsiIhsaIQABABcA/gFpAocABgAlQCIDAQECAUwAAQIBhgMBAgIAXwAA
ACQCTgAAAAYABhIRBAgYKxM1IRUDIxMXAVKeeqUCMVZX/s4BMwADACoA8QGQApAAFwAjAC8AZLUMAQUDAUxLsClQWEAeBwEEAAAE
AGUGAQICAWEAAQEqTQAFBQNhAAMDJwVOG0AcAAMABQQDBWkHAQQAAAQAZQYBAgIBYQABASoCTllAFSUkGRgrKSQvJS8fHRgjGSMq
JQgIGCsBFhYVFAYjIiY1NDY3JiY1NDYzMhYVFAYnIgYVFBYzMjY1NCYHMjY1NCYjIgYVFBYBLyk4WllZWjclIi9WUlJVMHchHyAg
ICIiICYnJyYnJSUByAcvKDZDQzYoMAcIKiU0PDw0JStqFxMTGBgTExf0GhYWGxsWFhoAAAACACQA/gGZApAAFQAhAF+1DgECAwFM
S7ALUFhAGwABAgIBcQYBAwACAQMCaQAEBABhBQEAACoEThtAGgABAgGGBgEDAAIBAwJpAAQEAGEFAQAAKgROWUAVFxYBAB0bFiEX
IREPDQsAFQEVBwgWKxMyFhUUBgcOBDEjNwYjIiY1NDYXMjY1NCYjIgYVFBbYWmcLEQYdJCEWenUZIElUX1gpMDApKSkqApBMOxMo
GAorNDAfiA9MPUNNzyIbGiEhGhsiAAAAAf9W/+wBCAK8AAMABrMCAAEyKxMXASfSNv6CNAK8Hv1OIAD//wAZ/+wDmwK8ACYB+gAA
ACcCAwHHAAAABwHxAhsAAP//ACT/7AO+ArwAJgH5AAAAJwIDAeMAAAAHAfICNwAA//8AGf/sA6ICvAAmAfoAAAAnAgMBxwAAAAcB
8gIbAAD//wAf/+wDtAK8ACYB+wAAACcCAwHZAAAABwHyAi0AAP//ABn/7ANuArwAJgH6AAAAJwIDAccAAAAHAfMB0QAA//8AIP/s
A18CvAAmAfwAAAAnAgMBuAAAAAcB8wHCAAD//wAZ/+wDvgK8ACYB+gAAACcCAwHHAAAABwH0AhsAAP//AB//7APQArwAJgH7AAAA
JwIDAdkAAAAHAfQCLQAA//8AIP/sA68CvAAmAfwAAAAnAgMBuAAAAAcB9AIMAAD//wAv/+wD1gK8ACYB/QAAACcCAwHfAAAABwH0
AjMAAP//ABn/7AOEArwAJgH6AAAAJwIDAccAAAAHAfUB9QAA//8AOv/sA48CvAAmAf4AAAAnAgMB0gAAAAcB9QIAAAD//wAZ/+wD
vAK8ACYB+gAAACcCAwHHAAAABwH2AlMAAP//ABn/7AOrArwAJgH6AAAAJwIDAccAAAAHAfcCGwAA//8AIP/sA5wCvAAmAfwAAAAn
AgMBuAAAAAcB9wIMAAD//wA6/+wDtgK8ACYB/gAAACcCAwHSAAAABwH3AiYAAP//ABf/7ANGArwAJgIAAAAAJwIDAWIAAAAHAfcB
tgAA//8AGf/sA7QCvAAmAfoAAAAnAgMBxwAAAAcB+AIbAAD//wAZ/+wFnAK8ACYB+gAAACcCAwHJAAAAJwHwAngAAAAHAe8D3QAA
AAH/Vv/sAQgCvAADAAazAgABMisTFwEn0jb+gjQCvB79TiAAAAEAKAGQALsCvAAFAFpLsCtQWEARAwECAgBfAAAANE0AAQE1AU4b
S7AyUFhAEQABAgGGAwECAgBfAAAANAJOG0AWAAECAYYAAAICAFcAAAACXwMBAgACT1lZQAsAAAAFAAUREQQJGCsTNTMRIzUok0QC
fED+1OwAAAEALQGQARsCxgAYAFO1BAEBAAFMS7ArUFhAHQADAgACAwCAAAICBGEABAQ0TQAAAAFfAAEBNQFOG0AaAAMCAAIDAIAA
AAABAAFjAAICBGEABAQ0Ak5ZtyMSJxEQBQkbKxM3FSM1PgI1NCYjIgYXIyY2NjMyFhUUBo+J3TBEIxgXGBsHQggbOiY4O0cBzQZD
PyQrIRYTGCIYIzojPSozPwABAC8BfgEWAsYAJQDZS7AeUFhAKwAGBQQFBnIAAQMCAgFyAAQAAwEEA2kABQUHYQAHBzRNAAICAGIA
AAA3AE4bS7AiUFhALAAGBQQFBnIAAQMCAwECgAAEAAMBBANpAAUFB2EABwc0TQACAgBiAAAANwBOG0uwK1BYQC0ABgUEBQYEgAAB
AwIDAQKAAAQAAwEEA2kABQUHYQAHBzRNAAICAGIAAAA3AE4bQCoABgUEBQYEgAABAwIDAQKAAAQAAwEEA2kAAgAAAgBmAAUFB2EA
Bwc0BU5ZWVlACyISIyEjIhIkCAkeKxMWFRQGIyImNzMGFjMyNjU0IyM1MzI2NTQjIgYXIyY2MzIWFRQG0EY1O0A3A0IBEyAXFDA3
NxgUKRwVAT0HOjw1Nx8CJQ89IjlFKw0dFhAiMRQQIRgNKj8zJxkmAAACACgBkAEmAr8ACgANAFVACwwBAAQBTAgBAAFLS7ArUFhA
FgYFAgADAQECAAFoAAQENE0AAgI1Ak4bQBYAAgEChgYFAgADAQECAAFoAAQENAROWUAOCwsLDQsNEhERERAHCRsrEzMVIxUjNSM1
NzMHNQf+KCg/l5NDP04CGDxMTDynp1paAAD//wA8AX8A0wHxAwcCIgAAAX8ACbEAAbgBf7A1KwAAAP//ADz/eADVAeMAJwIiAAAB
cQEGAiMVDQARsQABuAFxsDUrsQEBsA2wNSsAAAMAHwAAAyICxAAgACQAKAB6QBcjIgICAxQTBQMBAgIBAAEkBAMDBQAETEuwLVBY
QB8AAQYBAAUBAGkAAgIDYQADAyZNBwEFBQRfAAQEJQROG0AdAAMAAgEDAmkAAQYBAAUBAGkHAQUFBF8ABAQlBE5ZQBclJQEAJSgl
KCcmGRcRDwoIACABIAgIFisBIicHJzcXFhYzMjY1NCYmIyIGByc+AjMyHgIVFAYGBQM3ExcVIzUCVycvFnQxOBopEDM2MkkjIjIK
ego2Vjg2alk1MVv+NKt7q2eXAQIOUCWlEwcJQy4kNh4lICgmQikjQFc0PWA3TQHbLf4mcXJyAAEAPAAAANMAcgADABlAFgIBAQEA
XwAAACUATgAAAAMAAxEDCBcrNxUjNdOXcnJyAAEAJ/9rAMAAcwAKABFADgUEAQMASQAAAHYWAQgXKxcnNjY3JzUzFRQGQxIPHQE3
mUOVIhY2HAtzUkdX//8AQwAAANoB7wAmAiIHAAEHAiIABwF9AAmxAQG4AX2wNSsA//8APP94ANUB4wAnAiIAAAFxAQYCIxUNABGx
AAG4AXGwNSuxAQGwDbA1KwD//wA8AAACdwByACcCIgGkAAAAJgIiAAAABwIiANIAAAACAE0AAADkApcAAwAHAERLsB9QWEAWAAEB
AF8AAAAkTQQBAwMCXwACAiUCThtAFAAAAAEDAAFnBAEDAwJfAAICJQJOWUAMBAQEBwQHEhEQBQgZKxMzESMXFSM1VoSEjpcCl/4z
WHJyAAIATf+lAOQCPAADAAcAKEAlAAEAAAIBAGcAAgMDAlcAAgIDXwQBAwIDTwQEBAcEBxIREAUIGSsTIzUzAxEzEeSXl46EAcpy
/WkBzf4zAAAAAgAzAAACQQLFABoAHgC3S7ARUFhALgACAQABAgCAAAQABQUEcgAACAEFBgAFZwABAQNhAAMDJk0ABgYHXwkBBwcl
B04bS7ApUFhALwACAQABAgCAAAQABQAEBYAAAAgBBQYABWcAAQEDYQADAyZNAAYGB18JAQcHJQdOG0AtAAIBAAECAIAABAAFAAQF
gAADAAECAwFpAAAIAQUGAAVnAAYGB18JAQcHJQdOWVlAFhsbAAAbHhseHRwAGgAaFiQSJCEKCBsrNzUzMjY1NCYjIgYHIyY+AjMy
FhYVFAYGBxUHNTMV4ztRTEg8QEACgQEeP2VFWnQ5PGU+iJfJpjw3Nzo6KiRMPyc7ZEBCWzEES8lycgAAAgA0/4UCQgJKAAMAHgCF
S7ARUFhAMAAEBQYFBHIAAgYHBgIHgAAACAEBBQABZwAFAAYCBQZpAAcDAwdZAAcHA2EAAwcDURtAMQAEBQYFBAaAAAIGBwYCB4AA
AAgBAQUAAWcABQAGAgUGaQAHAwMHWQAHBwNhAAMHA1FZQBYAAB0bFxUUExIRCwkFBAADAAMRCQgXKwE1MxUTMxYOAiMiJiY1NDY2
NzUzFSMiBhUUFjMyNgEElyWAAh4/ZUVZdTk8ZT5/O1JLRz1BQAHYcnL+gyRMPyc7ZT9CWzEES6Y8Nzc6OgD//wA8ANgA0wFKAwcC
IgAAANgACLEAAbDYsDUrAAEAYQCDAWcBiQADABhAFQAAAQEAVwAAAAFfAAEAAU8REAIIGCsTIREhYQEG/voBif76AAABACkBRwHP
AtwADgAaQBcOCwoJCAcGBQQDAgEMAEkAAAB2HAEIFysBFwcXBycHJzcnNxcnMwcBsB+GWVFXVlFZgx+EBGQFAnxfKHM7fn47cydg
L4+QAAAAAgBDAA4DSwJ5ABsAHwBzS7AjUFhAJw4LAgUKCAIGBwUGZwIBAAAkTQ8MAgQEAV8NAwIBASdNCQEHByUHThtAJA4LAgUK
CAIGBwUGZwIBAAkBBwAHYw8MAgQEAV8NAwIBAScETllAGh8eHRwbGhkYFxYVFBMSEREREREREREQEAgfKxMzFTM1MxUzFSMVMxUj
FSM1IxUjNSM1MzUjNTMXMzUj8Xq8eqqqqqp6vHqurq6uery8AnmRkZFckV2QkJCQXZFc7ZEAAAABACT/iAG9AvEAAwAGswIAATIr
ARcBJwFUaf7PaALxJvy9JgABACT/iAG9AvEAAwAGswIAATIrEwEHAYwBMWn+0ALx/L0mA0MAAAAAAgBNAAAA5AKHAAMABwAlQCIA
AQEAXwAAACRNBAEDAwJfAAICJQJOBAQEBwQHEhEQBQgZKxMzESMXFSM1VoSEjpcCh/5DWHJyAAAAAAIATQAAAOQChwADAAcAJUAi
AAAAAV8AAQEkTQACAgNfBAEDAyUDTgQEBAcEBxIREAUIGSsTIzUzAxEzEeSXl46EAhVy/XkBvf5DAAACACkAAAIbApQAGQAdAERA
QQgBAQIBTAAEAwIDBAKAAAIAAQYCAWcAAwMAYQcBAAAqTQAGBgVfAAUFJQVOAQAdHBsaFhUTEQ0LCgkAGQEZCAgWKwEyFhYVFAYG
BxUjNTMyNjU0JiMiBgcjJjY2EyM1MwEhV241NVs6f0k7QD04OjoCgQE0bo+WlgKUNVk4O1MuBUSmNCgpLjEjLVs+/WxyAAAAAAIA
NP/2AicCigADAB0A80uwC1BYQC4AAwQFBANyAAcFBgUHBoAABAAFBwQFZwgBAQEAXwAAACRNAAYGAmEJAQICLgJOG0uwDVBYQC4A
AwQFBANyAAcFBgUHBoAABAAFBwQFZwgBAQEAXwAAACRNAAYGAmEJAQICKwJOG0uwE1BYQC4AAwQFBANyAAcFBgUHBoAABAAFBwQF
ZwgBAQEAXwAAACRNAAYGAmEJAQICLgJOG0AvAAMEBQQDBYAABwUGBQcGgAAEAAUHBAVnCAEBAQBfAAAAJE0ABgYCYQkBAgIuAk5Z
WVlAGgUEAAAaGRcVEQ8ODQwLBB0FHQADAAMRCggXKxM1MxUDIiYmNTQ2Njc1MxUjIgYVFBYzMjY3MxYGBvWXXlZvNTVcOn9JOkE8
ODo7AoACNW4CGHJy/d41Wjc8Ui8ERKYzKSgvMSMtWz4AAAEAUADeAZ4BQAADABhAFQAAAQEAVwAAAAFfAAEAAU8REAIIGCsTIRUh
UAFO/rIBQGIAAP//AFAA3gGeAUAABgI1AAAAAQBQAN0CDAFBAAMAGEAVAAABAQBXAAAAAV8AAQABTxEQAggYKxMhFSFQAbz+RAFB
ZAAAAAEAPADeAxABQgADABhAFQAAAQEAVwAAAAFfAAEAAU8REAIIGCsTIRUhPALU/SwBQmQAAAABAEf/OAML/5wAAwAgsQZkREAV
AAABAQBXAAAAAV8AAQABTxEQAggYK7EGAEQXIRUhRwLE/TxkZAAAAAABADX/bgEbAsoAFwAGswwBATIrBQcwLgM1ND4DMRcwDgIV
FB4CARtFIS8wISEwLyFFJzInJzInWjglSGmIUlOHZ0ckNzBfi1tdjV8vAAAAAAEANf9uARsCygAXAAazFgsBMisXMD4CNTQuAjE3
MB4DFRQOAzE1JzInJzInRSEwLyEhLzAhWi9fjV1bi18wNyRHZ4dTUohpSCUAAAABADH/TgGKAyAAJgBdtQsBBAUBTEuwF1BYQBsA
AAABBQABZwAFAAQCBQRpAAICA18AAwMpA04bQCAAAAABBQABZwAFAAQCBQRpAAIDAwJXAAICA18AAwIDT1lADSAfHh0WFRQTERAG
CBgrEyEVIxQeAhUUBgcWFhUUDgIVMxUhJj4CNTQmIzUyNjU0LgJ6ARCcExkTT0JCTxMZE5z+8AgUIxxHTU1HHCMUAyBmGjxBQR85
RA8PRDkfQUE8GmYvZGBQGiw1VjUsGlBgZQABAFn/TgGyAyAAJgBbtRcBAQABTEuwF1BYQBsABQAEAAUEZwAAAAEDAAFpAAMDAl8A
AgIpAk4bQCAABQAEAAUEZwAAAAEDAAFpAAMCAgNXAAMDAl8AAgMCT1lACyIhIB8RFxESBggaKwEUFjMVIgYVFB4CByE1MzQuAjU0
NjcmJjU0PgI1IzUhFg4CAR5HTU1HHSIUCP7wnBMZE09CQk8TGROcARAIFCIdAcMsNVY1LBpQYGQvZho8QUEfOUQPD0Q5H0FBPBpm
LmVgUAABAFn/SAFdAyAABwBIS7AfUFhAFAABAAIDAQJnBAEDAwBfAAAAKQBOG0AaAAEAAgMBAmcEAQMAAANXBAEDAwBfAAADAE9Z
QAwAAAAHAAcREREFCBkrBRUhESEVIxEBXf78AQSeUmYD2Gb89AABADz/SQFAAyAABwA/S7AdUFhAEwACAAEAAgFnAAAAA18AAwMp
A04bQBgAAgABAAIBZwAAAwMAVwAAAANfAAMAA09ZthERERAECBorFzMRIzUhESE8n58BBP78UQMLZvwpAAAAAQA1/5MBGwLvABcA
BrMMAQEyKwUHMC4DNTQ+AzEXMA4CFRQeAgEbRSEvMCEhMC8hRScyJycyJzU4JUhpiFJTh2dHJDcwX4tbXY1fLwAAAAABADX/kwEb
Au8AFwAGsxYLATIrFzA+AjU0LgIxNzAeAxUUDgMxNScyJycyJ0UhMC8hIS8wITUvX41dW4tfMDckR2eHU1KIaUglAAD//wAn/2sA
wABzAgYCIwAA//8AJ/9qAYYAcgAnAkcAAP3lAQcCRwDG/eUAErEAAbj95bA1K7EBAbj95bA1KwAA//8AJwG2AYYCvgAmAkYAAAAH
AkYAxgAA//8AJwGFAYYCjQAmAkcAAAAHAkcAxgAAAAEAJwG2AMACvgAKABFADgUEAQMASgAAAHYWAQgXKxMXBgYHFxUjNTQ2oxMQ
GwI3mUMCviIWNh0Kc1JHVwAAAAABACcBhQDAAo0ACgATQBAFBAEDAEkAAAAkAE4WAQgXKxMnNjY3JzUzFRQGQxIPHQE3mUMBhSIW
NxwLclJGVwAAAgAwABIB8QIcAAUACwAItQoGBAACMisBFwcXBwMlFwcXBycBIUi2tkjxAXtGUlJHigIcRcDBRAEFmkRUVUOYAAIA
UAASAhICHAAFAAsACLUJBwMBAjIrEzcTAyc3JTcXByc32Ujx8Um2/sJHi4tHUgHXRf77/vtEwVZEmJhDVQABADwAEgF1AhwABQAG
swUBATIrExMXBxcHPPFItrZIARcBBUXAwUQAAQAyABIBawIcAAUABrMFAQEyKwEDJzcnNwFr8Ui2tkgBF/77RMHARQAAAP//ACcB
uwF3Ao0AJgJNAAAABwJNALgAAAABACcBuwC/Ao0ABQAaQBcFAgIAAQFMAAAAAV8AAQEkAE4SEAIIGCsTIyc1MxWVRSmYAbt8VlYA
AAEAJf/2A2QClAAoAR9LsAtQWEAuAAIDAAMCcgAHBQgFBwiABAEACQEFBwAFZwADAwFhAAEBKk0ACAgGYQAGBi4GThtLsA1QWEAu
AAIDAAMCcgAHBQgFBwiABAEACQEFBwAFZwADAwFhAAEBKk0ACAgGYQAGBisGThtLsA5QWEAvAAIDAAMCAIAABwUIBQcIgAQBAAkB
BQcABWcAAwMBYQABASpNAAgIBmEABgYuBk4bS7APUFhALgACAwADAnIABwUIBQcIgAQBAAkBBQcABWcAAwMBYQABASpNAAgIBmEA
BgYuBk4bQC8AAgMAAwIAgAAHBQgFBwiABAEACQEFBwAFZwADAwFhAAEBKk0ACAgGYQAGBi4GTllZWVlADignIhMkESMiEiQQCggf
KxMzNTQ2NjMyFhUjJiYjIgYGFRUzFSMVFAYGIyImJjUzFhYzMjY2NTUj+4hDc0hudXwBNDIiOSGBgT9uR0ZrO3wBPzAhNB2IAWwH
an45cVgoMh1NSAdFG2J7OTVaNygvHElCGwARAB7/9gM+ApQAEwAaACEAKAAwADkAQQBIAE8AWABfAGYAcAB3AH4AhgCOAI9AjD81
LiwnJSEeGBUKAgFORj04BAcCblICEAuMiYSCe3h1cQgAEARMAAECAYUSAQAQAIYDEwICCQEHBAIHaggGBQMEDw0MAwoLBApnDgEL
EBALWQ4BCwsQYREBEAsQURQUAQB+fXRya2pmZWRjXl1cW1ZVTEtKSUhHQ0I7OjIxHBsUGhQaCwkAEwETFAYWKwUiLgI1ND4CMzIe
AhUUDgIDNQYGBxYWFzY2NyYmJwc2NjcGBxYFNjY3JicWFhczJiYnBgYHFgUzNjcmJwYGBTMmJicGBwczNSYmJwYHNjcmJicjFhY3
NjY3NSMWBTY2NyMVFhc2NjcjBgYHFhYFNQYGBxYWFzY2NyYmJwcmJicGBxYWBTY3JiYnBgYBrlWSbTw8bZJVVpFtPDxtkWwvQxQb
Q1UoQRwUQi/aDyocXDwbAa0UIQ08WhwqMW0CHRgPJRYR/cxtAxEuHhccAWeiAQgHPFbQoytKHwxqHjAHCgFuAhqMH0orowMBYAYI
AaJVsxYbAm4BCggYJv7bKEMcFERcL0MUHEIogR4sECocHlIBBGA/DiIWDy0KL1h8TE17WC8vWHtNTHxYLwHihAdDMAQFAQEFBS9D
B3MhNxMVOxEIBQ4IORUTNrIsSh0MEgg2Nzc0DxcdSSsaMRcNAlNTAQcGLugZDxoyGSpGFgYHAUwvLBYvFkwBQh1IKhkzGgcVgIoB
BAUxRwgIRjEFBQGEFDwiCxIfKwsVPwkPBSI7AAAAAgA0/8kEAAKuADsASQEXQA84CwIDCiIBBQAjAQYFA0xLsAlQWEAyAAgAAwha
DAkCAwsBAAUDAGoABQAGBQZlAAQEB2EABwcmTQACAidNAAoKAWEAAQEtCk4bS7AbUFhAMwADAAgAAwhqDAEJCwEABQkAaQAFAAYF
BmUABAQHYQAHByZNAAICJ00ACgoBYQABAS0KThtLsC1QWEAxAAEACgMBCmkAAwAIAAMIagwBCQsBAAUJAGkABQAGBQZlAAQEB2EA
BwcmTQACAicCThtALwAHAAQBBwRpAAEACgMBCmkAAwAIAAMIagwBCQsBAAUJAGkABQAGBQZlAAICJwJOWVlZQCE9PAEARUM8ST1J
NTMvLSclIB4YFhIQDQwJBwA7ATsNCBYrJSImJjU0NjYzMhYXNTMVFBYzMjY1NCYjIgYGFRQWFjMyNjcXBgYjIiYmNTQ2NjMyFhUU
BiMiJiYnDgInMjY2NTQmJiMiBhUUFgHWRWk6OmxJVWkUghckJBbQtnq1Y16we0p7JSQtjVSW2XR13Jnm/FVUNkYmBA45WBIxTy8w
TzBLQkdvNVw7Pl83TTlmrig0NSuPiT19YV6FRRUTSRYaWql2d6JTuK1XYyI1HCNELGMdLxwkMho8NC46AAAAAAIAJP/1AvQClAAo
ADQAv0AKCAEFBCUBBwUCTEuwC1BYQCkAAgMEAwIEgAAECAEFBwQFZwADAwFhAAEBKk0KAQcHAGEGCQIAACsAThtLsBdQWEApAAID
BAMCBIAABAgBBQcEBWcAAwMBYQABASpNCgEHBwBhBgkCAAAuAE4bQC0AAgMEAwIEgAAECAEFBwQFZwADAwFhAAEBKk0ABgYlTQoB
BwcAYQkBAAAuAE5ZWUAdKikBADAuKTQqNCIhIB8eHBgWFBMQDgAoASgLCBYrBSImJjU0NjY3LgI1NDYzMhYWFSMmJiMiBhUUFjMh
FSMRIyYmJw4CJzI2NjU1IyIGFRQWAQc+Zz5AbkQ+YjeXhVF8RnoBUUVKTFJWAYV+eQUDAQ44XxE9UCmFV2pKCypMNDlKJwcFHzwx
UWIrV0EpKy8pKzJL/tsiQzApSS5kK0UlNzM3KzcAAAAAAgAeAAACkgKHABAAGQA0QDEIAQUDAQEABQFpAAYGBF8HAQQEJE0CAQAA
JQBOEhEAABUTERkSGQAQAA8hERERCQgaKwERIzUjFSM1IyImJjU0NjYzEzM1IyIGFRQWApKAS4AxSHBAPm9IA/z8L0RDAof9eezs
7C5cQ0NcL/7RvCo1NCkAAgAi/9wCDQLGADUAQQDAtj85AgcDAUxLsBVQWEAyAAUGAwYFA4AAAwcGAwd+AAcBBgcBfgABAgYBAn4A
BgYEYQAEBCZNAAICAGEAAAArAE4bS7AnUFhALwAFBgMGBQOAAAMHBgMHfgAHAQYHAX4AAQIGAQJ+AAIAAAIAZQAGBgRhAAQEJgZO
G0A1AAUGAwYFA4AAAwcGAwd+AAcBBgcBfgABAgYBAn4ABAAGBQQGaQACAAACWQACAgBhAAACAFFZWUALGyISJRsiFCIICB4rJRQG
IyIuAjczFhYXFjY1NCYnLgI1NDY3JiY1NDYzMhYXIyYmIyIGFRQWFx4CFRQGBxYWJRQWFzY2NTQmJwYGAghyYkZmQRwDcwlFPTMu
Pj1GbT1HTkxBd2ZrfAF0Bzw1KjNFPUJoO0BHQUH+n01DKClEQysvaUFMJTk9FyEsAQEfHCIYDAwkOSwpOAQYOCtAUVxNJCAeGyEb
DQwiOC8nNAUUPcAiIg8FJRwmHA0EIwAAAwA1AAcDwQKLAA8AHwA3AGmxBmREQF4ABgcJBwYJgAwBCQgHCQh+AAEAAwUBA2kABQAH
BgUHaQAIAAQCCARpCwECAAACWQsBAgIAYgoBAAIAUiAgERABACA3IDc2NDEvLSwqKCQiGRcQHxEfCQcADwEPDQgWK7EGAEQlIiYm
NTQ2NjMyFhYVFAYGJzI2NjU0JiYjIgYGFRQWFiUUBiMiJjU0NjMyFhcjJiYjIgYVFDMyNwH8i81vbs2MjMtub8uLaqRdXKRrbKRd
XaUBR2prbXl5bWtoAWAHODU+QX9nDgdQkmNkjk1NjmRjklBQOm1OTmo2NmpOTm063zpETUNETUM6FxolIEMxAAAAAAQANQBNA5gC
qQAPAB8AMwA6APixBmRES7ANUFhAOwAFCQcKBXINCAIGBwIHBnIAAQADBAEDaQAEAAoJBApnAAkABwYJB2cMAQIAAAJZDAECAgBh
CwEAAgBRG0uwD1BYQDwABQkHCQUHgA0IAgYHAgcGcgABAAMEAQNpAAQACgkECmcACQAHBgkHZwwBAgAAAlkMAQICAGELAQACAFEb
QD0ABQkHCQUHgA0IAgYHAgcGAoAAAQADBAEDaQAEAAoJBApnAAkABwYJB2cMAQIAAAJZDAECAgBhCwEAAgBRWVlAJSAgERABADo4
NjQgMyAzMjAtLCgnIyEZFxAfER8JBwAPAQ8OCBYrsQYARCUiJiY1NDY2MzIWFhUUBgYnMjY2NTQmJiMiBgYVFBYWJxEzMhYVFAYH
FhYVFSM1NCYjIxU1MzI1NCMjAeeBxG1sxIKCwm1tw4FkmllYmmVlm1hZmzncQz8hLS0aVxgsZYknJ4lNTopZWoZLS4ZaWYpOUTZl
RUZhMzNhRkVlNlUBHC8tIioDBh0XNzISDlKWIBsAAAAAAwBNAOkEDgKHAAcAFAAYAD5AOxANAgABAUwDAQEAAgFXCAQCAgcGBQMA
CgIAZwAKCQkKVwAKCglfAAkKCU8YFxYVERISERIREREQCwYfKwEjNSM1IRUjBTczFSMnByMnFSM1MwEhNSEBQ3WBAXuFAcuKdnQB
T3ZQdHUBifxKA7YBjZtfX1Kx+nV3dnT6/mJeAAAAAAIALwF3AZICkgALABcAObEGZERALgABAAMCAQNpBQECAAACWQUBAgIAYQQB
AAIAUQ0MAQATEQwXDRcHBQALAQsGCBYrsQYARBMiJjU0NjMyFhUUBicyNjU0JiMiBhUUFuBOY2NOT2NjTy8xMS8uMTEBd05AQE1N
QEBORiggHycnHyAoAAEAZP9gAN8DIAADABhAFQAAAQEAVwAAAAFfAAEAAU8REAIIGCsTMxEjZHt7AyD8QAAAAAACAGT/YADfAyAA
AwAHADBALQQBAQAAAwEAZwUBAwICA1cFAQMDAl8AAgMCTwQEAAAEBwQHBgUAAwADEQYIFysTESMRExEjEd97e3sDIP6UAWz9rP6U
AWwAAQBg/zgCmwK8AAsAI0AgAAEBJk0FAQMDAF8CAQAAJ00ABAQpBE4RERERERAGCBwrEzM1MxUzFSMRIxEjYNyC3d2C3AH0yMhv
/bMCTQAAAAABAFD/OAKLArwAEwA5QDYAAwMmTQUBAQECXwQBAgInTQYBAAAHXwoJAgcHJU0ACAgpCE4AAAATABMREREREREREREL
CB8rNzUzESM1MzUzFTMVIxEzFSMVIzVQ3d3dgtzc3NyCBW8BEW/IyG/+72/NzQAAAAIATf9uAwEChwALAA8AMUAuAAIDAoYAAAcB
AQYAAWcABQUEXwAEBCRNAAYGA18AAwMlA04REREREREREAgIHisTIRUjESM1IREhFSMRITUhzwIyiXv+UAF8+gEu/tIBgWn+VpIC
h2/+V6kAAAIANf/zAw0ChwAYACIAq0uwE1BYQBUIAQYCHxMOAwUDFgEABQNMCQECAUsbQBUIAQYCHxMOAwUDFgEEBQNMCQECAUtZ
S7ATUFhAKwAGAgMCBgOAAAICAV8AAQEkTQADAwBhBAcCAAArTQAFBQBhBAcCAAArAE4bQCgABgIDAgYDgAACAgFfAAEBJE0AAwME
XwAEBCVNAAUFAGEHAQAAKwBOWUAVAQAhIB0bFRQREA0MCwoAGAEYCAgWKwUiJiY1NDY2Nyc1IRUhATY3MwYHFyMnBgYnFBYzMjY3
JwYGAVxbhEg+ZDm0AiP+eAFZGAVxCThwhzIufPllVzBMHb9DUw0zWj06TCkGsmNj/p4oNmZHczEdIdw3OBAPvQQ3AAAAAAIATf9h
AywCtwCWAKIAUEBNoZ5qYllEPQcDBJptAgIDlk0CBQKMAQAFBEwAAwQCBAMCgAACBQQCBX4ABQAEBQB+AAAAhAAEBAFhAAEBJgRO
jo16eEZFNTMgHigGCBcrJQ4DBw4CIyImJicuAjU0NjY3PgM3PgMzMhYXHgIVFAYHDgMHBgYHBgYjIiYnJiY1NDY1NDY2BwYGBxUi
JwYGBwYGBwYmNjY3NjY3PgI1NDMyFhYXFhYXNjY3NhYWBwcUBgcxNzY2NTQmJy4CIyIOAgcOAwcOAhUUHgIXJjIXFjY2NzY2NwMG
Bgc3NjY3JiYnBgImARQdHQsZKSwfFD02DBcsHBQqIQoyQkQcFTo+NRAhVRsRHBIdDgMVHBwJBxIFBAYGBAkEGRcECwkDChMJCRkX
LBklWScEAQIFAwodDwcHAwQFGxsFDDkbChIII0AgEAkLAkoQFhARCCgrDgwwODMRGTo2JwciJg8RGh0MBBYkGiUmGRMhHGoTIQ4t
Ei0XECAMAycEHCQiChYoGBAZDh1CRSFKf3xGFjMyJwkGDQoHFw4JNEAcMWQuCTI8MQcGCQcECgcBCh8WL1ovAh4cAwkUCjUKHz4b
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
AAYGAGIBAQAALk0ABAQAYQEBAAAuTQACAikCThtAIAUBAwMnTQAGBgBiAAAALk0ABAQBYQABAS5NAAICKQJOWVlZQAoUFCQREiYQ
BwgdKwUiJicOAyMiJxUjETMRFBYWMzI2NjcRMxEUFhYzAtt4aAIGGy1EMVMlgoIkPSYwSDAMghUrIAdaUBk9NiM69gK5/u8zORcm
Oh4BFv7RJiUMAAACACT/9AKJAsUAGQAnADtAOAsBAgMBTBABAUoAAQADAgEDaQUBAgAAAlkFAQICAGEEAQACAFEbGgEAIyEaJxsn
CQcAGQEZBgYWKwUiJiY1NDY2MzIWFy4CJzceBBUUBgYnMjY2NTQmJiMiBhUUFgFYYIpKRHZKVXEcEVWTcBRzo2o8GE6JVDRTMjRV
M1NfYwxBdk1PcDxEODZbRhhfF0tfaGguUHxGZSZHMDFFJFVHSVIAAAAFACj/3gOMAq4AAwAPABsAJwAzAFlAVgEBAwEDAQQGAkwJ
AQIIAQAFAgBpAAUABwYFB2kAAwMBYQABASpNCwEGBgRhCgEEBC4ETikoHRwREAUELy0oMykzIyEcJx0nFxUQGxEbCwkEDwUPDAgW
KwEXAScDIiY1NDYzMhYVFAYnMjY1NCYjIgYVFBYBIiY1NDYzMhYVFAYnMjY1NCYjIgYVFBYCbjb+gjQOVmZmVlZlZVYmLy8mJy8v
AhVWZmZWVWVlVSYvLyYnLy8Crh79TiABT1hNT1dXT01YUi0mJy0tJyYt/lVXTk5YWE5OV1IsJyYuLScnLAAAAAcAKP+cA/UCrgAD
AA8AGwAnADMAPwBLAHhAdQEBAwEDAQoLAkwABQAHAgUHaQ0BAgwBAAYCAGkPAQYOAQQJBgRpAAkACwoJC2kRAQoQAQgKCGUAAwMB
YQABASoDTkFANTQpKB0cERAFBEdFQEtBSzs5ND81Py8tKDMpMyMhHCcdJxcVEBsRGwsJBA8FDxIIFisBFwEnAyImNTQ2MzIWFRQG
JzI2NTQmIyIGFRQWBSImNTQ2MzIWFRQGJzI2NTQmIyIGFRQWAyImNTQ2MzIWFRQGJzI2NTQmIyIGFRQWAmo2/oI0ClZmZlZWZWVW
Ji8vJicvLwJ9VmZmVlZlZVYmLy8mJy8vm1VnZ1VWZWVWJi8vJiYwLwKuHv1OIAFPWE1PV1dPTVhSLSYnLS0nJi2nWE1OWFhOTVhS
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
AQBfAAAAJgFOG0ARAAABAQBXAAAAAV8CAQEAAU9ZQAoAAAADAAMRAwgXKxM1MxXplwJTc3MAAAAAAQBB/zgA1/+rAAMAGUAWAgEB
AQBfAAAAKQBOAAAAAwADEQMIFysXFSM115ZVc3MAAQBL/zgA4v+rAAMAGUAWAgEBAQBfAAAAKQBOAAAAAwADEQMIFysXFSM14pdV
c3MAAQBL/zgA4v+qAAMAGUAWAgEBAQBfAAAAKQBOAAAAAwADEQMIFysXFSM14pdWcnL//wBQAloBwALMACcCIgAUAloBBwIiAO0C
WgASsQABuAJasDUrsQEBuAJasDUrAAD//wBLAlsA4gLNAAYCjQAA//8AZAJZAZgC9wAGAo4AAP//AF8CWQGTAvcABgKPAAD//wBk
AlkCPQL3AAYCkAAA//8AZwJZAjQC9wAGApIAAP//AGsCWQIxAvcABgKTAAD//wBtAkMCEQLaAAYClAAA//8AZwJBAYIDIAAGApUA
AP//AFUCWAI6AuQABgKWAAD//wBkAmEBlwKyAAYClwAA//8Aaf8RAaQAEQAGApoAAP//AGT/IQFCABYABgKbAAD//wBLAlsA4gLN
AAYCoAAA//8AVQJbAOwCzQEHAiIAGQJbAAmxAAG4AluwNSsAAAD//wBQAloBwALMAAYCjAAA//8AVQJbAOwCzQEHAiIAGQJbAAmx
AAG4AluwNSsAAAD//wBLAlsA4gLNAAYCpQAA//8A3wJwAXYC4gEHAqYAlAAVAAixAAGwFbA1K///AEsCWwDiAs0ABgKnAAD//wDf
AlsBdgLNAAcCqACUAAAAAP//AE0CWwDkAs0ABgKpAgD//wBL/zgA4v+rAAYCrAAA//8AS/84AOL/qgAGAq0AAAABADYAgQLEAmAA
AwAGswIAATIrEwEFA/8Bxf27SQJg/uXEAVIAAAAAAAASAN4AAwABBAkAAADCAAAAAwABBAkAAQAIAMIAAwABBAkAAgAIAMoAAwAB
BAkAAwAoANIAAwABBAkABAASAPoAAwABBAkABQBGAQwAAwABBAkABgASAVIAAwABBAkACAAaAWQAAwABBAkACQAcAX4AAwABBAkA
CwAwAZoAAwABBAkADAA4AcoAAwABBAkADQEiAgIAAwABBAkADgA2AyQAAwABBAkBAAASA1oAAwABBAkBAQAEA2wAAwABBAkBAgAO
A3AAAwABBAkBAwAeA34AAwABBAkBBAAOA5wAQwBvAHAAeQByAGkAZwBoAHQAIAAyADAAMQA5ACAAVABoAGUAIABTAHkAbgBlACAA
UAByAG8AagBlAGMAdAAgAEEAdQB0AGgAbwByAHMAIAAoAGgAdAB0AHAAcwA6AC8ALwBnAGkAdABsAGEAYgAuAGMAbwBtAC8AYgBv
AG4AagBvAHUAcgAtAG0AbwBuAGQAZQAvAGYAbwBuAGQAZQByAGkAZQAvAHMAeQBuAGUALQB0AHkAcABlAGYAYQBjAGUAKQBTAHkA
bgBlAEIAbwBsAGQAMgAuADIAMAAwADsATgBPAE4ARQA7AFMAeQBuAGUALQBCAG8AbABkAFMAeQBuAGUAIABCAG8AbABkAFYAZQBy
AHMAaQBvAG4AIAAyAC4AMgAwADAAOwAgAHQAdABmAGEAdQB0AG8AaABpAG4AdAAgACgAdgAxAC4AOAAuADQAKQBTAHkAbgBlAC0A
QgBvAGwAZABCAG8AbgBqAG8AdQByACAATQBvAG4AZABlAEwAdQBjAGEAcwAgAEQAZQBzAGMAcgBvAGkAeABoAHQAdABwAHMAOgAv
AC8AYgBvAG4AagBvAHUAcgBtAG8AbgBkAGUALgBuAGUAdABoAHQAdABwAHMAOgAvAC8AdwB3AHcALgBsAHUAYwBhAHMAZABlAHMA
YwByAG8AaQB4AC4AZgByAFQAaABpAHMAIABGAG8AbgB0ACAAUwBvAGYAdAB3AGEAcgBlACAAaQBzACAAbABpAGMAZQBuAHMAZQBk
ACAAdQBuAGQAZQByACAAdABoAGUAIABTAEkATAAgAE8AcABlAG4AIABGAG8AbgB0ACAATABpAGMAZQBuAHMAZQAsACAAVgBlAHIA
cwBpAG8AbgAgADEALgAxAC4AIABUAGgAaQBzACAAbABpAGMAZQBuAHMAZQAgAGkAcwAgAGEAdgBhAGkAbABhAGIAbABlACAAdwBp
AHQAaAAgAGEAIABGAEEAUQAgAGEAdAA6ACAAaAB0AHQAcABzADoALwAvAHMAYwByAGkAcAB0AHMALgBzAGkAbAAuAG8AcgBnAC8A
TwBGAEwAaAB0AHQAcABzADoALwAvAHMAYwByAGkAcAB0AHMALgBzAGkAbAAuAG8AcgBnAC8ATwBGAEwAQQBtAHAAZQByAHMAYQBu
AGQAYQB0AEEAYwBjAGUAbgB0AHMAZwAgAGQAbwB1AGIAbABlACAAcwB0AG8AcgBlAHkAZQBwAHMAaQBsAG8AbgACAAAAAAAA/2oA
SwAAAAAAAAAAAAAAAAAAAAAAAAAAAscAAAAkAMkBAgDHAGIArQEDAQQAYwCuAJAAJQAmAP0A/wBkAQUAJwDpAQYBBwAoAGUBCADI
AMoBCQDLAQoBCwApACoA+AEMAQ0AKwEOACwBDwDMAM0AzgD6AM8BEAERAC0ALgESAC8BEwEUARUBFgDiADAAMQEXARgBGQBmARoA
MgDQANEAZwEbANMBHAEdAJEArwCwADMA7QA0ADUBHgEfASAANgEhAOQA+wEiADcBIwEkASUBJgA4ANQA1QBoANYBJwEoASkBKgA5
ADoBKwEsAS0BLgA7ADwA6wEvALsBMAA9ATEA5gEyATMBNAE1ATYBNwE4ATkBOgE7ATwBPQE+AT8BQAFBAUIBQwFEAUUBRgFHAUgB
SQFKAUsBTAFNAU4BTwFQAVEBUgFTAVQBVQFWAVcBWAFZAVoBWwFcAV0BXgFfAWABYQFiAWMBZAFlAWYBZwFoAWkBagFrAWwBbQFu
AW8BcAFxAXIBcwF0AXUARABpAXYAawBsAGoBdwF4AG4AbQCgAEUARgD+AQAAbwF5AEcA6gF6AQEASABwAXsAcgBzAXwAcQF9AX4A
SQBKAPkBfwGAAEsBgQBMANcAdAB2AHcBggB1AYMBhAGFAE0ATgGGAE8BhwGIAYkBigDjAFAAUQGLAYwBjQB4AY4AUgB5AHsAfAB6
AY8BkAChAH0AsQBTAO4AVABVAZEBkgGTAFYBlADlAPwBlQCJAFcBlgGXAZgBmQBYAH4AgACBAH8BmgGbAZwBnQBZAFoBngGfAaAB
oQBbAFwA7AGiALoBowBdAaQA5wGlAaYBpwGoAakBqgGrAawBrQGuAa8BsAGxAbIBswG0AbUBtgG3AbgBuQG6AbsBvAG9Ab4BvwHA
AcEBwgHDAcQBxQHGAccByAHJAcoBywHMAc0BzgHPAdAB0QHSAdMB1AHVAdYB1wHYAdkB2gHbAdwB3QHeAd8B4AHhAeIB4wHkAeUB
5gHnAegB6QHqAesAwAHsAe0AnQCeAe4B7wHwAfEB8gHzAfQB9QH2AfcB+AH5AfoB+wH8Af0B/gH/AgACAQICAgMCBAIFAgYCBwII
AgkCCgILAgwCDQIOAg8CEAIRAhICEwIUAhUCFgIXAhgCGQIaAhsCHAIdAJsCHgIfAiACIQIiAiMCJAIlAiYCJwIoAikCKgIrAiwC
LQIuAi8CMAIxAjICMwATABQAFQAWABcAGAAZABoAGwAcAjQCNQI2AjcCOAI5AjoCOwI8Aj0CPgI/AkACQQJCAkMCRAJFAkYCRwJI
AkkCSgJLAkwCTQJOAk8CUAJRAlICUwJUAlUCVgJXAlgCWQJaAlsCXAJdAl4CXwJgAmECYgJjAmQCZQJmAmcCaAJpAmoCawJsAm0C
bgJvALwA9AJwAnECcgD1APYCcwJ0AnUCdgJ3AngCeQJ6AnsCfAJ9An4CfwKAAoECggKDAoQChQADAoYChwKIAokAEQAPAB0AHgCr
AAQAowAiAKIAwwCHAA0ABgASAD8CigKLAowCjQAQAo4AsgCzAEIACwAMAF4AYAA+AEACjwKQAMQAxQC0ALUAtgC3AKkAqgC+AL8A
BQAKAKYCkQAjAAkAiACGAIsAigCMAIMAXwDoAIIAwgKSApMClACEAL0ABwKVAIUAlgKWAA4A7wDwALgAIACPACEAHwCVAJQAkwCn
AGEApABBApcAkgCcAJoAmQClApgAmAAIAMYCmQKaApsCnAKdAp4CnwKgAqECogC5AqMCpAKlAqYCpwKoAqkCqgKrAqwCrQKuAq8C
sAKxArICswK0ArUCtgK3ArgCuQK6ArsCvAK9Ar4CvwLAAsECwgLDAsQCxQLGAI4A3ABDAI0A3wDYAOEA2wDdANkA2gDeAOACxwLI
AskCygLLAswCzQLOAs8C0ALRAtIGQWJyZXZlB0FtYWNyb24HQW9nb25lawpDZG90YWNjZW50BkRjYXJvbgZEY3JvYXQGRWNhcm9u
CkVkb3RhY2NlbnQHRW1hY3JvbgdFb2dvbmVrB3VuaTAxMjIKR2RvdGFjY2VudARIYmFyAklKB0ltYWNyb24HSW9nb25lawd1bmkw
MTM2BkxhY3V0ZQZMY2Fyb24HdW5pMDEzQgRMZG90Bk5hY3V0ZQZOY2Fyb24HdW5pMDE0NQNFbmcHdW5pMDIyRQ1PaHVuZ2FydW1s
YXV0B09tYWNyb24GUmFjdXRlBlJjYXJvbgd1bmkwMTU2BlNhY3V0ZQd1bmkwMjE4BFRiYXIGVGNhcm9uB3VuaTAxNjIHdW5pMDIx
QQ1VaHVuZ2FydW1sYXV0B1VtYWNyb24HVW9nb25lawVVcmluZwZXYWN1dGULV2NpcmN1bWZsZXgJV2RpZXJlc2lzBldncmF2ZQtZ
Y2lyY3VtZmxleAZZZ3JhdmUGWmFjdXRlClpkb3RhY2NlbnQLQWFjdXRlLnNzMDMLQWJyZXZlLnNzMDMQQWNpcmN1bWZsZXguc3Mw
MwtBZ3JhdmUuc3MwMwxBbWFjcm9uLnNzMDMMQW9nb25lay5zczAzCkFyaW5nLnNzMDMLQXRpbGRlLnNzMDMLQ2FjdXRlLnNzMDML
Q2Nhcm9uLnNzMDMNQ2NlZGlsbGEuc3MwMw9DZG90YWNjZW50LnNzMDMLRGNhcm9uLnNzMDMLRWFjdXRlLnNzMDMLRWNhcm9uLnNz
MDMQRWNpcmN1bWZsZXguc3MwMwtFZ3JhdmUuc3MwMwxFbWFjcm9uLnNzMDMMRW9nb25lay5zczAzC0dicmV2ZS5zczAzDHVuaTAx
MjIuc3MwMw9HZG90YWNjZW50LnNzMDMLSWFjdXRlLnNzMDMQSWNpcmN1bWZsZXguc3MwMwtJZ3JhdmUuc3MwMwxJbWFjcm9uLnNz
MDMMSW9nb25lay5zczAzDHVuaTAxMzYuc3MwMwtMYWN1dGUuc3MwMwtMY2Fyb24uc3MwMwx1bmkwMTNCLnNzMDMLTmFjdXRlLnNz
MDMLTmNhcm9uLnNzMDMMdW5pMDE0NS5zczAzC050aWxkZS5zczAzC09hY3V0ZS5zczAzEE9jaXJjdW1mbGV4LnNzMDMLT2dyYXZl
LnNzMDMST2h1bmdhcnVtbGF1dC5zczAzDE9tYWNyb24uc3MwMwtPdGlsZGUuc3MwMwtSYWN1dGUuc3MwMwtSY2Fyb24uc3MwMwx1
bmkwMTU2LnNzMDMLU2FjdXRlLnNzMDMLU2Nhcm9uLnNzMDMNU2NlZGlsbGEuc3MwMwx1bmkwMjE4LnNzMDMLVGNhcm9uLnNzMDMM
dW5pMDE2Mi5zczAzDHVuaTAyMUEuc3MwMwtVYWN1dGUuc3MwMxBVY2lyY3VtZmxleC5zczAzC1VncmF2ZS5zczAzElVodW5nYXJ1
bWxhdXQuc3MwMwxVbWFjcm9uLnNzMDMMVW9nb25lay5zczAzClVyaW5nLnNzMDMLV2FjdXRlLnNzMDMQV2NpcmN1bWZsZXguc3Mw
MwtXZ3JhdmUuc3MwMwtZYWN1dGUuc3MwMxBZY2lyY3VtZmxleC5zczAzC1lncmF2ZS5zczAzC1phY3V0ZS5zczAzC1pjYXJvbi5z
czAzA1RfaAZhYnJldmUHYW1hY3Jvbgdhb2dvbmVrCmNkb3RhY2NlbnQGZGNhcm9uBmVjYXJvbgplZG90YWNjZW50B2VtYWNyb24H
ZW9nb25lawd1bmkwMTIzCmdkb3RhY2NlbnQEaGJhcglpLmxvY2xUUksCaWoHaW1hY3Jvbgdpb2dvbmVrB3VuaTAxMzcGbGFjdXRl
BmxjYXJvbgd1bmkwMTNDBGxkb3QGbmFjdXRlBm5jYXJvbgd1bmkwMTQ2A2VuZw1vaHVuZ2FydW1sYXV0B29tYWNyb24GcmFjdXRl
BnJjYXJvbgd1bmkwMTU3BnNhY3V0ZQd1bmkwMjE5BHRiYXIGdGNhcm9uB3VuaTAxNjMHdW5pMDIxQg11aHVuZ2FydW1sYXV0B3Vt
YWNyb24HdW9nb25lawV1cmluZwZ3YWN1dGULd2NpcmN1bWZsZXgJd2RpZXJlc2lzBndncmF2ZQt5Y2lyY3VtZmxleAZ5Z3JhdmUG
emFjdXRlCnpkb3RhY2NlbnQLYWFjdXRlLnNzMDMLYWJyZXZlLnNzMDMQYWNpcmN1bWZsZXguc3MwMwthZ3JhdmUuc3MwMwxhbWFj
cm9uLnNzMDMMYW9nb25lay5zczAzCmFyaW5nLnNzMDMLYXRpbGRlLnNzMDMLY2FjdXRlLnNzMDMLY2Nhcm9uLnNzMDMNY2NlZGls
bGEuc3MwMwtkY2Fyb24uc3MwMwtlYWN1dGUuc3MwMwtlY2Fyb24uc3MwMxBlY2lyY3VtZmxleC5zczAzC2VncmF2ZS5zczAzDGVt
YWNyb24uc3MwMwxlb2dvbmVrLnNzMDMLZ2JyZXZlLnNzMDMMdW5pMDEyMy5zczAzC2lhY3V0ZS5zczAzEGljaXJjdW1mbGV4LnNz
MDMLaWdyYXZlLnNzMDMMaW1hY3Jvbi5zczAzDGlvZ29uZWsuc3MwMwx1bmkwMTM3LnNzMDMLbGFjdXRlLnNzMDMLbGNhcm9uLnNz
MDMMdW5pMDEzQy5zczAzC25hY3V0ZS5zczAzC25jYXJvbi5zczAzDHVuaTAxNDYuc3MwMwtudGlsZGUuc3MwMwtvYWN1dGUuc3Mw
MxBvY2lyY3VtZmxleC5zczAzC29ncmF2ZS5zczAzEm9odW5nYXJ1bWxhdXQuc3MwMwxvbWFjcm9uLnNzMDMLb3RpbGRlLnNzMDML
cmFjdXRlLnNzMDMLcmNhcm9uLnNzMDMMdW5pMDE1Ny5zczAzC3NhY3V0ZS5zczAzC3NjYXJvbi5zczAzDXNjZWRpbGxhLnNzMDMM
dW5pMDIxOS5zczAzC3RjYXJvbi5zczAzDHVuaTAxNjMuc3MwMwx1bmkwMjFCLnNzMDMLdWFjdXRlLnNzMDMQdWNpcmN1bWZsZXgu
c3MwMwt1Z3JhdmUuc3MwMxJ1aHVuZ2FydW1sYXV0LnNzMDMMdW1hY3Jvbi5zczAzDHVvZ29uZWsuc3MwMwp1cmluZy5zczAzC3dh
Y3V0ZS5zczAzEHdjaXJjdW1mbGV4LnNzMDMLd2dyYXZlLnNzMDMLeWFjdXRlLnNzMDMQeWNpcmN1bWZsZXguc3MwMwt5Z3JhdmUu
c3MwMwt6YWN1dGUuc3MwMwt6Y2Fyb24uc3MwMwZnLnNzMDQLZ2JyZXZlLnNzMDQMdW5pMDEyMy5zczA0D2dkb3RhY2NlbnQuc3Mw
NANmX2YFZl9mX2kDdF9pA3RfeQVBbHBoYQRCZXRhBUdhbW1hB3VuaTAzOTQHRXBzaWxvbgRaZXRhA0V0YQVUaGV0YQRJb3RhBUth
cHBhBkxhbWJkYQJNdQJOdQJYaQdPbWljcm9uAlBpA1JobwVTaWdtYQNUYXUHVXBzaWxvbgNQaGkDQ2hpA1BzaQd1bmkwM0E5CkFs
cGhhdG9ub3MMRXBzaWxvbnRvbm9zCEV0YXRvbm9zCUlvdGF0b25vcwxPbWljcm9udG9ub3MMVXBzaWxvbnRvbm9zCk9tZWdhdG9u
b3MMSW90YWRpZXJlc2lzD1Vwc2lsb25kaWVyZXNpcwVhbHBoYQRiZXRhBWdhbW1hBWRlbHRhB2Vwc2lsb24EemV0YQNldGEFdGhl
dGEEaW90YQVrYXBwYQZsYW1iZGEHdW5pMDNCQwJudQJ4aQdvbWljcm9uA3Jobwd1bmkwM0MyBXNpZ21hA3RhdQd1cHNpbG9uA3Bo
aQNjaGkDcHNpBW9tZWdhCWlvdGF0b25vcwxpb3RhZGllcmVzaXMRaW90YWRpZXJlc2lzdG9ub3MMdXBzaWxvbnRvbm9zD3Vwc2ls
b25kaWVyZXNpcxR1cHNpbG9uZGllcmVzaXN0b25vcwxvbWljcm9udG9ub3MKb21lZ2F0b25vcwphbHBoYXRvbm9zDGVwc2lsb250
b25vcwhldGF0b25vcwxlcHNpbG9uLnNzMDURZXBzaWxvbnRvbm9zLnNzMDUHemVyby5sZgZvbmUubGYGdHdvLmxmCHRocmVlLmxm
B2ZvdXIubGYHZml2ZS5sZgZzaXgubGYIc2V2ZW4ubGYIZWlnaHQubGYHbmluZS5sZgh6ZXJvLm9zZgdvbmUub3NmB3R3by5vc2YJ
dGhyZWUub3NmCGZvdXIub3NmCGZpdmUub3NmB3NpeC5vc2YJc2V2ZW4ub3NmCWVpZ2h0Lm9zZghuaW5lLm9zZgd6ZXJvLnRmBm9u
ZS50ZgZ0d28udGYIdGhyZWUudGYHZm91ci50ZgdmaXZlLnRmBnNpeC50ZghzZXZlbi50ZghlaWdodC50ZgduaW5lLnRmCXplcm8u
dG9zZghvbmUudG9zZgh0d28udG9zZgp0aHJlZS50b3NmCWZvdXIudG9zZglmaXZlLnRvc2YIc2l4LnRvc2YKc2V2ZW4udG9zZgpl
aWdodC50b3NmCW5pbmUudG9zZgl6ZXJvLmRub20Ib25lLmRub20IdHdvLmRub20KdGhyZWUuZG5vbQlmb3VyLmRub20JZml2ZS5k
bm9tCHNpeC5kbm9tCnNldmVuLmRub20KZWlnaHQuZG5vbQluaW5lLmRub20JemVyby5udW1yCG9uZS5udW1yCHR3by5udW1yCnRo
cmVlLm51bXIJZm91ci5udW1yCWZpdmUubnVtcghzaXgubnVtcgpzZXZlbi5udW1yCmVpZ2h0Lm51bXIJbmluZS5udW1yB3VuaTIx
ODkHdW5pMjE1Mwd1bmkyMTU0B3VuaTIxNTUHdW5pMjE1Ngd1bmkyMTU3B3VuaTIxNTgHdW5pMjE1OQd1bmkyMTVBB3VuaTIxNTAJ
b25lZWlnaHRoDHRocmVlZWlnaHRocwtmaXZlZWlnaHRocwxzZXZlbmVpZ2h0aHMHdW5pMjE1MQd1bmkyMTUyDGZyYWN0aW9uLjAw
MQd1bmkwMEI5B3VuaTAwQjIHdW5pMDBCMwd1bmkyMDc0AkNSB3VuaTAwQTAJYW5vdGVsZWlhB3VuaTAzN0UPZXhjbGFtX3F1ZXN0
aW9uC2V4Y2xhbS5jYXNlD2V4Y2xhbWRvd24uY2FzZQ1xdWVzdGlvbi5jYXNlEXF1ZXN0aW9uZG93bi5jYXNlB3VuaTAwQUQOcGFy
ZW5sZWZ0LmNhc2UPcGFyZW5yaWdodC5jYXNlB3VuaUY4RkYOYW1wZXJzYW5kLmNhc2UOYW1wZXJzYW5kLnNzMDEHYXQuc3MwMgRF
dXJvB3VuaTIyMTUIZW1wdHlzZXQHdW5pMDBCNQdhcnJvd3VwB3VuaTIxOTcKYXJyb3dyaWdodAd1bmkyMTk4CWFycm93ZG93bgd1
bmkyMTk5CWFycm93bGVmdAd1bmkyMTk2CWFycm93Ym90aAlhcnJvd3VwZG4FdG9ub3MNZGllcmVzaXN0b25vcwd1bmkwMzA4B3Vu
aTAzMDcJZ3JhdmVjb21iCWFjdXRlY29tYgd1bmkwMzBCC3VuaTAzMEMuYWx0B3VuaTAzMDIHdW5pMDMwQwd1bmkwMzA2B3VuaTAz
MEEJdGlsZGVjb21iB3VuaTAzMDQHdW5pMDMxMgd1bmkwMzI2B3VuaTAzMjcHdW5pMDMyOAd1bmkwMzM1B3VuaTAzMzYHdW5pMDMz
Nwd1bmkwMzM4DmdyYXZlY29tYi5zczAzDmFjdXRlY29tYi5zczAzDHVuaTAzMEIuc3MwMxB1bmkwMzBDLmFsdC5zczAzDHVuaTAz
MDIuc3MwMwx1bmkwMzBDLnNzMDMMdW5pMDMwNi5zczAzDHVuaTAzMEEuc3MwMw50aWxkZWNvbWIuc3MwMwx1bmkwMzA0LnNzMDMM
dW5pMDMxMi5zczAzDHVuaTAzMjYuc3MwMwx1bmkwMzI3LnNzMDMMdW5pMDMyOC5zczAzCmdyYXZlLnNzMDMKYWN1dGUuc3MwMxFo
dW5nYXJ1bWxhdXQuc3MwMw9jaXJjdW1mbGV4LnNzMDMKY2Fyb24uc3MwMwpicmV2ZS5zczAzCXJpbmcuc3MwMwp0aWxkZS5zczAz
C21hY3Jvbi5zczAzDGNlZGlsbGEuc3MwMwtvZ29uZWsuc3MwMwZyYW5kb20AAAABAAH//wAPAAEAAgAOAAAAxgAAARwAAgAeAAEA
tQABALYAtgACALcAyAABAMoA5QABAOcBbgABAW8BcwACAXQBdwABAXoBegABAXwBfAABAX4BfwABAYEBggABAYQBhAABAYYBhgAB
AYgBiQABAYsBiwABAY0BlwABAZkBmQABAZsBmwABAZ0BnQABAZ8BnwABAaMBowABAaUBpQABAasBqwABAa8BvQABAdEB0QABAeUB
5QABAlYCVgABAmECYgABAncCdwABAowCrQADABAABgAgACgAMAA+AEYATgABAAYAtgFvAXABcQFyAXMAAQAEAAECBwABAAQAAQFA
AAIABgAKAAEBKgABAlIAAQAEAAEBOAABAAQAAQEtAAEABAABAXIAAQABAAAACAACAAQCjAKQAAACkgKYAAUCoAKiAAwCpAKqAA8A
AQAAAAoAXACCAAJERkxUAA5sYXRuABIAOAAAADQACEFaRSAANENBVCAANENSVCAANEtBWiAANE1PTCAANFJPTSAANFRBVCAANFRS
SyAANAAA//8AAwAAAAEAAgADa2VybgAUbWFyawAabWttawAgAAAAAQAAAAAAAQABAAAAAQACAAMACCVoPwoAAgAIAAIAChjaAAEB
7gAEAAAA8hHCEcIRwhHCEcIRwhHCEcIRwhHCA8YYshiyGLIYshiyGLIYshiyBEgEUgTACtwK3AUyBTIFPBiyGLIYshiyGLIYshiy
GLIYshGUGLIFQgXcEZ4RnhGeByoSnhKeEp4SnhKeEp4HuBiGEp4SnhKeEp4KHhHCEcIRwhHCEcIRwhHCEcIYshiyGLIYshiyGLIK
3ArqGLIYshiyGLIYshiyEZ4RnhGeEp4SnhKeEp4SnhKeEegR6BHoEegR6BHoEegR6BHoEegR8hHyCxQR8hHyEfIR8hHyEfIR8hHy
EfIMegyAEbwRvAyaEfIR8hHyEfIR8hHyEfIR8hHyDLQOYhHeEdgR2BHYEdgR2BHYDswR2BHYEdgR2BHYEDIR6BHoEegR6BHoEegR
6BHoEfIR8hHyEfIR8hHyEbwR8hHyEfIR8hHyEfIR2BHYEdgR2BHYEdgRwhGeEcIYshHCGLIRlBGeGIYYshHCGLIYhhiGEegR2BHy
EfIYshG8EcIR2BHyEfIR8hHeEfIR6BHyEfIR8hHoEfIR8hHyEggSFhKYGLISnhLAEsYSzBLSEtgS3hL0FkQWRBZEE7oTuhNWE7AT
uhO6E7oTuhZEFcIVwhPIFcIWRBZEFmIWaBZuFm4W4BcCFyQYhhisGLIAAgBOAAEACgAAAAwAEAAKABIAFQAPAB8AIAATAC8AMgAV
ADQANAAZADgAOAAaAD8AQgAbAEQASAAfAEoASgAkAEwATAAlAFEAUQAmAFYAVgAnAFgAWwAoAGQAcAAsAHQAgAA5AIkAiQBGAI8A
jwBHAJEAkQBIAJcAnABJAKQApgBPAK4AswBSALcAwwBYAMwA1gBlAOcA6QBwAPYA/gBzAQMBAwB8AQcBBwB9AQ0BDQB+ARsBJwB/
ASsBMgCMATcBPACUAUQBRACaAUwBUQCbAWMBaAChAXYBdgCnAXgBeQCoAX0BfQCqAYABgACrAYQBhACsAYYBhgCtAYgBigCuAY4B
jgCxAZIBkwCyAZYBlwC0AZkBmwC2AZ4BngC5AaABoQC6AaMBowC8AaUBpQC9AacBqAC+AaoBqgDAAawBrADBAa4BrwDCAbYBuQDE
AbsBvADIAcEBwgDKAcYBxgDMAe8B7wDNAfYB9gDOAfoB/QDPAgACAADTAgMCAwDUAh0CHQDVAiICIwDWAiYCJgDYAisCLQDZAi8C
LwDcAjUCOgDdAjwCPADjAj4CPgDkAkACQADlAkICRADmAkYCRgDpAkgCTADqAmQCZADvAm0CbQDwAnwCfADxACAAAf/6AAL/+gAD
//oABP/6AAX/+gAG//oAB//6AAj/+gAJ//oACv/6AAv/+gBr//IAdP/6AHX/+gB2//oAd//6AHj/+gB5//oAev/6AHv/+gF2//oB
ef/6AYD/+gGJ//IBlv/yAiv/+QIs//kCNf/5Ajb/+QI3//kCOP/5AmT/8gACAiT/8gIl//IAGwBk//IAZf/yAGb/8gBn//IAaP/y
AGn/8gBq//IAa//SAGz/8gBt//IAbv/yAG//8gCu//IAr//yALD/8gCx//IAsv/yALP/8gGJ/9IBlv/SAiv//QIs//0CNf/9Ajb/
/QI3//0COP/9AmT/0gAcAAH/8wAC//MAA//zAAT/8wAF//MABv/zAAf/8wAI//MACf/zAAr/8wAL//MAdP/zAHX/8wB2//MAd//z
AHj/8wB5//MAev/zAHv/8wF2//MBef/zAYD/8wIi/+UCI//lAib/5QI5/+UCQv/lAkP/5QACAFH/8gBb/+8AAQBW/+wAJgAB//cA
Av/3AAP/9wAE//cABf/3AAb/9wAH//cACP/3AAn/9wAK//cAC//3AGv/+gB0//cAdf/3AHb/9wB3//cAeP/3AHn/9wB6//cAe//3
AXb/9wF5//cBgP/3AYn/+gGW//oCK//5Aiz/+QI1//kCNv/5Ajf/+QI4//kCRP/5AkX/+QJG//kCR//5Akz/+QJN//kCZP/6AFMA
Af/XAAL/1wAD/9cABP/XAAX/1wAG/9cAB//XAAj/1wAJ/9cACv/XAAv/1wAN/84ADv/OAA//zgAQ/84AIP/OADj/7AA//84AQP/O
AEH/zgBC/84ARP/OAEX/zgBG/84AR//OAEj/zgBJ/84ATP/OAHAABwB0/9cAdf/XAHb/1wB3/9cAeP/XAHn/1wB6/9cAe//XAHz/
zgB9/84Afv/OAH//zgCJ/84Al//OAJj/zgCZ/84Amv/OAJv/zgCc/84BB/++ARv/0AEc/9ABHf/QAR7/0AEf/9ABIP/QASH/nAEi
/9ABI//QAST/0AEl/9ABJv/QASf/sAFj/9ABZP/QAWX/0AFm/9ABZ//QAWj/0AF2/9cBef/XAX3/zgGA/9cBhP/OAYr/zgGZ/9AB
nv/OAaP/0AHv/84CLQANAkj/6wJJ/+sCSv/rAkv/8gAjAAH/1QAC/9UAA//VAAT/1QAF/9UABv/VAAf/1QAI/9UACf/VAAr/1QAL
/9UAav/5AHT/1QB1/9UAdv/VAHf/1QB4/9UAef/VAHr/1QB7/9UBdv/VAXn/1QGA/9UCIv/3AiP/9wIm//cCK//9Aiz//QI1//0C
Nv/9Ajf//QI4//0COf/3AkL/9wJD//cAmQAN/9UADv/VAA//1QAQ/9UAIP/VAD//1QBA/9UAQf/VAEL/1QBE/9UARf/VAEb/1QBH
/9UASP/VAEn/1QBM/9UAW//5AHz/1QB9/9UAfv/VAH//1QCJ/9UAl//VAJj/1QCZ/9UAmv/VAJv/1QCc/9UAt//qALj/6gC5/+oA
uv/qALv/6gC8/+oAvf/qAL7/6gC//+oAwP/qAMH/6gDD/+oAxP/qAMX/6gDG/+oAx//qAMj/6gDJ/+oAyv/qAMv/6gDM/+oAzf/q
AM7/6gDP/+oA0P/qANH/6gDS/+oA0//qANT/6gDW/+oA1//qANj/6gDZ/+oA9v/qAPf/6gD4/+oA+f/qAPr/6gD7/+oA/P/qAP3/
6gD+/+oBAv/qARv/8AEc//ABHf/wAR7/8AEf//ABIP/wASL/8AEj//ABJP/wASX/8AEm//ABK//qASz/6gEt/+oBLv/qAS//6gEw
/+oBMf/qATL/6gEz/+oBNP/qATX/6gE2/+oBN//qATj/6gE5/+oBOv/qATv/6gE8/+oBPf/qAT7/6gFM/+oBTf/qAU7/6gFP/+oB
UP/qAVH/6gFj//ABZP/wAWX/8AFm//ABZ//wAWj/8AFr/+oBbP/qAW3/6gFu/+oBff/VAYT/1QGK/9UBl//qAZn/8AGa/+oBm//q
AZ7/1QGj//ABpf/qAaj/6gGp/+oBrP/qAa//6gG2/+oBt//qAbj/6gG5/+oBu//qAbz/6gHv/9UCIv/9AiP//QIm//0CK//IAiz/
yAIt//YCNf/IAjb/yAI3/8gCOP/IAjn//QJC//0CQ//9Anz/6gAvAA3/7AAO/+wAD//sABD/7AAg/+wAL//9AD//7ABA/+wAQf/s
AEL/7ABE/+wARf/sAEb/7ABH/+wASP/sAEn/7ABM/+wAVgAHAFgABwBZAAcAWgAHAHz/7AB9/+wAfv/sAH//7ACJ/+wAl//sAJj/
7ACZ/+wAmv/sAJv/7ACc/+wApAAHAKUABwCmAAcBff/sAYT/7AGIAAcBiv/sAZ7/7AHv/+wCK//lAiz/5QI1/+UCNv/lAjf/5QI4
/+UAAwBR/+sAW//VAi3/3AAKAFH/8gBW/7YAWP+2AFn/tgBa/7YAW//vAKT/tgCl/7YApv+2AYj/tgBZALcAAAC4AAAAuQAAALoA
AAC7AAAAvAAAAL0AAAC+AAAAvwAAAMAAAADBAAAAwwAAAMQAAADFAAAAxgAAAMcAAADIAAAAyQAAAMoAAADLAAAAzAAAAM0AAADO
AAAAzwAAANAAAADRAAAA0gAAANMAAADUAAAA1gAAANcAAADYAAAA2QAAAPYAAAD3AAAA+AAAAPkAAAD6AAAA+wAAAPwAAAD9AAAA
/gAAAQIAAAEh/+wBKwAAASwAAAEtAAABLgAAAS8AAAEwAAABMQAAATIAAAEzAAABNAAAATUAAAE2AAABNwAAATgAAAE5AAABOgAA
ATsAAAE8AAABPQAAAT4AAAFMAAABTQAAAU4AAAFPAAABUAAAAVEAAAFrAAABbAAAAW0AAAFuAAABlwAAAZoAAAGbAAABpQAAAagA
AAGpAAABrAAAAa8AAAG2AAABtwAAAbgAAAG5AAABuwAAAbwAAAJ8AAAAAQItAA0ABgIi//ACI//KAib/8AI5//ACQv/wAkP/8AAG
ANX/7AEN/+wBb//sAXH/7AGq/+wCTf/sAGsAtwAAALgAAAC5AAAAugAAALsAAAC8AAAAvQAAAL4AAAC/AAAAwAAAAMEAAADDAAAA
xAAAAMUAAADGAAAAxwAAAMgAAADJAAAAygAAAMsAAADMAAAAzQAAAM4AAADPAAAA0AAAANEAAADSAAAA0wAAANQAAADVAAMA1gAA
ANcAAADYAAAA2QAAAPYAAAD3AAAA+AAAAPkAAAD6AAAA+wAAAPwAAAD9AAAA/gAAAQIAAAEHAAABDQADASsAAAEsAAABLQAAAS4A
AAEvAAABMAAAATEAAAEyAAABMwAAATQAAAE1AAABNgAAATcAAAE4AAABOQAAAToAAAE7AAABPAAAAT0AAAE+AAABTAAAAU0AAAFO
AAABTwAAAVAAAAFRAAABawAAAWwAAAFtAAABbgAAAW8AAwFxAAMBlwAAAZoAAAGbAAABpQAAAagAAAGpAAABqgADAawAAAGvAAAB
tgAAAbcAAAG4AAABuQAAAbsAAAG8AAACIv/FAiP/xQIm/8UCK//yAiz/8gItABACNf/yAjb/8gI3//ICOP/yAjn/xQJC/8UCQ//F
AnwAAAAaARv/7QEc/+0BHf/tAR7/7QEf/+0BIP/tASH/7QEi/+0BI//tAST/7QEl/+0BJv/tAWP/7QFk/+0BZf/tAWb/7QFn/+0B
aP/tAZn/7QGj/+0CIgAAAiMAAAImAAACOQAAAkIAAAJDAAAAWQC3/+kAuP/pALn/6QC6/+kAu//pALz/6QC9/+kAvv/pAL//6QDA
/+kAwf/pAMP/6QDE/+kAxf/pAMb/6QDH/+kAyP/pAMn/6QDK/+kAy//pAMz/6QDN/+kAzv/pAM//6QDQ/+kA0f/pANL/6QDT/+kA
1P/pANb/6QDX/+kA2P/pANn/6QD2/+kA9//pAPj/6QD5/+kA+v/pAPv/6QD8/+kA/f/pAP7/6QEC/+kBB//tASv/6QEs/+kBLf/p
AS7/6QEv/+kBMP/pATH/6QEy/+kBM//pATT/6QE1/+kBNv/pATf/6QE4/+kBOf/pATr/6QE7/+kBPP/pAT3/6QE+/+kBTP/pAU3/
6QFO/+kBT//pAVD/6QFR/+kBa//pAWz/6QFt/+kBbv/pAZf/6QGa/+kBm//pAaX/6QGo/+kBqf/pAaz/6QGv/+kBtv/pAbf/6QG4
/+kBuf/pAbv/6QG8/+kCfP/pAFgAt//5ALj/+QC5//kAuv/5ALv/+QC8//kAvf/5AL7/+QC///kAwP/5AMH/+QDD//kAxP/5AMX/
+QDG//kAx//5AMj/+QDJ//kAyv/5AMv/+QDM//kAzf/5AM7/+QDP//kA0P/5ANH/+QDS//kA0//5ANT/+QDW//kA1//5ANj/+QDZ
//kA9v/5APf/+QD4//kA+f/5APr/+QD7//kA/P/5AP3/+QD+//kBAv/5ASv/+QEs//kBLf/5AS7/+QEv//kBMP/5ATH/+QEy//kB
M//5ATT/+QE1//kBNv/5ATf/+QE4//kBOf/5ATr/+QE7//kBPP/5AT3/+QE+//kBTP/5AU3/+QFO//kBT//5AVD/+QFR//kBa//5
AWz/+QFt//kBbv/5AZf/+QGa//kBm//5AaX/+QGo//kBqf/5Aaz/+QGv//kBtv/5Abf/+QG4//kBuf/5Abv/+QG8//kCfP/5AAIA
av/tAHD/+gAHAHAABwEH/74CLQANAkj/6wJJ/+sCSv/rAkv/8gABAQf/8wAFADIAAABR//cAVv+uAFv/8AIt/7sAAQEH/+0AAgIt
ABACNf/rAAIAwv/2Aj//7AAFASH/6QEn//kCHQAAAin/8gI//9gAAwG+//oBxP/tAcb/+gAgAA3/9wAO//cAD//3ABD/9wAg//cA
P//3AED/9wBB//cAQv/3AET/9wBF//cARv/3AEf/9wBI//cASf/3AEz/9wB8//cAff/3AH7/9wB///cAif/3AJf/9wCY//cAmf/3
AJr/9wCb//cAnP/3AX3/9wGE//cBiv/3AZ7/9wHv//cAAQHDAAAACAAL/34Bwf+xAiT/6wIl/+sCSP/VAkn/1QJK/9UCS//cAAEC
AwAiAAECAwAxAAECAwANAAECAwAaAAECA//iAAUB8AA4AfP/tgH1/9oB9gA4AgcAAAAYAFb/2ABY/9gAWf/YAFr/2ABkAAAAZQAA
AGYAAABnAAAAaAAAAGkAAABsAAAAbQAAAG4AAABvAAAApP/YAKX/2ACm/9gArgAAAK8AAACwAAAAsQAAALIAAACzAAABiP/YABYA
Af+7AAL/uwAD/7sABP+7AAX/uwAG/7sAB/+7AAj/uwAJ/7sACv+7AAv/uwB0/7sAdf+7AHb/uwB3/7sAeP+7AHn/uwB6/7sAe/+7
AXb/uwF5/7sBgP+7AAICL/+MAmz/5AADAFv//QBq/8gAcP/yAH4ADf/rAA7/6wAP/+sAEP/rACD/6wA//+sAQP/rAEH/6wBC/+sA
RP/rAEX/6wBG/+sAR//rAEj/6wBJ/+sATP/rAHz/6wB9/+sAfv/rAH//6wCJ/+sAl//rAJj/6wCZ/+sAmv/rAJv/6wCc/+sAt//Y
ALj/2AC5/9gAuv/YALv/2AC8/9gAvf/YAL7/2AC//9gAwP/YAMH/2ADD/9gAxP/YAMX/2ADG/9gAx//YAMj/2ADJ/9gAyv/YAMv/
2ADM/9gAzf/YAM7/2ADP/9gA0P/YANH/2ADS/9gA0//YANT/2ADW/9gA1//YANj/2ADZ/9gA9v/YAPf/2AD4/9gA+f/YAPr/2AD7
/9gA/P/YAP3/2AD+/9gBAv/YASv/2AEs/9gBLf/YAS7/2AEv/9gBMP/YATH/2AEy/9gBM//YATT/2AE1/9gBNv/YATf/2AE4/9gB
Of/YATr/2AE7/9gBPP/YAT3/2AE+/9gBTP/YAU3/2AFO/9gBT//YAVD/2AFR/9gBa//YAWz/2AFt/9gBbv/YAX3/6wGE/+sBiv/r
AZf/2AGa/9gBm//YAZ7/6wGl/9gBqP/YAan/2AGs/9gBr//YAbb/2AG3/9gBuP/YAbn/2AG7/9gBvP/YAe//6wIi/8QCI//EAib/
xAI5/8QCQv/EAkP/xAJ8/9gAIAAN/+sADv/rAA//6wAQ/+sAIP/rAD//6wBA/+sAQf/rAEL/6wBE/+sARf/rAEb/6wBH/+sASP/r
AEn/6wBM/+sAfP/rAH3/6wB+/+sAf//rAIn/6wCX/+sAmP/rAJn/6wCa/+sAm//rAJz/6wF9/+sBhP/rAYr/6wGe/+sB7//rAAcA
W//3AGr//QG+/94CHQAAAjv/4gI//8QCTP+wAAEAL//3AAEAL//eABwAVv/rAFj/6wBZ/+sAWv/rAGT/6wBl/+sAZv/rAGf/6wBo
/+sAaf/rAGv/6wBs/+sAbf/rAG7/6wBv/+sApP/rAKX/6wCm/+sArv/rAK//6wCw/+sAsf/rALL/6wCz/+sBiP/rAYn/6wGW/+sC
ZP/rAAgAVv/yAFj/8gBZ//IAWv/yAKT/8gCl//IApv/yAYj/8gAIAFb/6wBY/+sAWf/rAFr/6wCk/+sApf/rAKb/6wGI/+sAWAC3
/84AuP/OALn/zgC6/84Au//OALz/zgC9/84Avv/OAL//zgDA/84Awf/OAMP/zgDE/84Axf/OAMb/zgDH/84AyP/OAMn/zgDK/84A
y//OAMz/zgDN/84Azv/OAM//zgDQ/84A0f/OANL/zgDT/84A1P/OANb/zgDX/84A2P/OANn/zgD2/84A9//OAPj/zgD5/84A+v/O
APv/zgD8/84A/f/OAP7/zgEC/84BK//OASz/zgEt/84BLv/OAS//zgEw/84BMf/OATL/zgEz/84BNP/OATX/zgE2/84BN//OATj/
zgE5/84BOv/OATv/zgE8/84BPf/OAT7/zgFM/84BTf/OAU7/zgFP/84BUP/OAVH/zgFr/84BbP/OAW3/zgFu/84Bl//OAZr/zgGb
/84Bpf/OAaj/zgGp/84BrP/OAa//zgG2/84Bt//OAbj/zgG5/84Bu//OAbz/zgJ8/84ACQBR//oBAP/eAQf/0AEn//ACJP/rAiX/
6wIp/+sCSP/VAkv/3AABAi//3gAHAGr/1QBw/+wBwv/3Ajv/6wI9/+sCP//rAkH/6wACBRgABAAABuoJuAAcABcAAAAAAAAAAAAA
/+z/vgAA/7IAAAAA//YAAAAAAAAAAAAAAAD/+QAAAAAAAAAAAAAAAAAAAAD/3wAA/9kAAP/sAAD/9v/YAAAAAAAAAAAAAAAAAAAA
AP/PAAD/7AAAAAAAAAAAAAD/9gAAAAAAAP/5AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/6AAD/3wAA/8//twAAAAD/x//U
AAAAAAAAAAAAAAAAAAD/3AAA/6IAAP/zAAD/6QAAAAAAAAAAAAAAAAAAAAD/5P+wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//MA
AP/6AAD/+QAAAAAAAAAA/+kAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//0AAP++//n/1f+w/+kAAAAAAAAACf/I/6gAAAAAAAAAAAAA
AAAAAP/qAAD/4v+tAAD/r//MAAD/1wAAAA4AAAAAABf/zv+gAAAAAAAAAAAAAAAAAAAAAAAKAAD/uwAA//cAAAAAAAAAAAAAAAAA
AAAAAAD/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/9AAAAAAAAAAD/8AAAAAAAAP/pAAAAAAAAAAAAAAAAAAAAAAAA//MAAAAA
AAD/+QAA/+L/wAAAAB4AAAAeAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJAAAAAAAAAAAAAAAA/9T/5P/IAAD/zgAAAAAAAAAAAAAA
AAAAAAAAAAAAAAD/sQAAAAAAAP/2AAD/zgAA/7D/qAAA/8n/1QAAAAAAAAAAAAAAAAAAAAD/2wAA/8gAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//oAHAAA/7H/9wAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAD/6gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//kAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAD/+v/zAAD/+gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/6wAA
AAAAAAAAAAAAAAAA/53/1P/P/6IAAAAAAAAACgAJ/7H/mAAAAAAAAAAAAAAAAP/i/9UAAAAA/5MAAP/jAAAAAAAAAAAAAAAAAAAA
AP/qAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/7AAA/+IAAP/V/9cAAP+o/6z/0P/YAAAAAAAAAAAAAAAAAAAAAP+oAAAAAAAA
/7sAAP+qAAD/uAAA//YAAP/9/7H/8gAAAAAAAAAAAAAAAAAAAAAAAAAA/+cAAP/5AAAAAAAAAAAAAAAAAAAAAAAA/94AAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAD/7wAA/+z/rQAA/9wAAAAAAAD/+v+sAAAAAAAAAAAAAAAAAAAAAP/wAAD//QAA//kAAAAAAAAAAAAA
AAAAAAAJAAD/zgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/V/9j/3/+u/84AAAAAABUAAP/s/7IAAAAAAAAAAAAAAAAAAAAAAAAA
AP/wAAIATQABAAoAAAANABAACgASAB8ADgAwADIAHAA0ADQAHwA/AEIAIABEAEgAJABKAEoAKQBMAFAAKgBWAFYALwBYAFoAMABk
AGkAMwBrAG8AOQB0AIYAPgCJAIkAUQCPAI8AUgCRAJEAUwCXAJ8AVACkAKYAXQCuALMAYADBAMIAZgDMANcAaADZANsAdADnAOgA
dwDvAP4AeQENAQ0AiQESASAAigEiASYAmQE3AT0AngFEAUQApQFIAVEApgFcAWgAsAFrAWwAvQFuAW4AvwF2AXYAwAF4AXoAwQF9
AX0AxAGAAYAAxQGDAYQAxgGGAYoAyAGOAY8AzQGSAZMAzwGWAZYA0QGZAZsA0gGdAZ4A1QGgAaEA1wGjAaMA2QGlAaUA2gGnAaoA
2wGsAawA3wGvAa8A4AG2AbcA4QG5AbwA4wG+Ab8A5wHBAcIA6QHEAcYA6wHIAckA7gHLAcwA8AHOAdAA8gHSAdMA9QHVAdYA9wHY
AdoA+QHcAd0A/AHfAeAA/gHiAeQBAAHmAecBAwHpAeoBBQHsAe8BBwH2AfYBCwIiAiMBDAImAiYBDgIrAiwBDwI1AjkBEQJCAkcB
FgJMAk0BHAJkAmQBHgJ8AnwBHwACAHcAAQAKAAMADQAQAAEAEgAVAAEAFgAeAAUAHwAfABsAMAAxABcAMgAyABYANAA0ABYAPwBC
AAEARABIAAEASgBKABkATABMAAEATQBQAAkAVgBWAAcAWABaAAcAZABpAAYAawBrABQAbABvAAYAdAB7AAMAfACAAAEAgQCGAAUA
iQCJAAEAjwCPABcAkQCRABYAlwCcAAEAnQCfAAkApACmAAcArgCzAAYA1QDVABoA1gDXAAgA2QDZAAgA2gDbAAIA5wDoABUA7wD1
AAIBDQENABgBEgEaAAIBGwEgAAQBIgEmAAQBPQE9AAgBRAFEABUBSAFLAAIBXAFiAAIBYwFoAAQBawFsAAgBbgFuAAgBdgF2AAMB
eAF4AAcBeQF5AAMBegF6AAUBfQF9AAEBgAGAAAMBgwGDAAUBhAGEAAEBhgGGABkBhwGHAAUBiAGIAAcBiQGJABQBigGKAAEBjgGO
AAMBjwGPAAUBkgGSAAEBkwGTABQBlgGWABQBmQGZAAQBnQGdAAIBngGeAAEBoAGgABUBoQGhAAMBowGjAAQBqQGpAAgBqgGqABgB
ugG6AAIBvgG+AA8BvwG/AA0BwQHBABEBwgHCABIBxAHEAA4BxQHFABMBxgHGABAByAHIAA8ByQHJAA0BywHLABEBzAHMABIBzgHO
AA4BzwHPABMB0AHQABAB0gHSAA8B0wHTAA0B1QHVABEB1gHWABIB2AHYAA4B2QHZABMB2gHaABAB3AHcAA8B3QHdAA0B3wHfABEB
4AHgABIB4gHiAA4B4wHjABMB5AHkABAB5gHmAA8B5wHnAA0B6QHpABEB6gHqABIB7AHsAA4B7QHtABMB7gHuABAB7wHvAAEB9gH2
AAYCIgIjAAwCJgImAAwCKwIsAAsCNQI4AAsCOQI5AAwCQgJDAAwCRAJHAAoCTAJNAAoCZAJkABQCfAJ8AAEAAgB3AAEACwAEAA0A
EAADACAAIAADACYAJgAHAC8ALwAWADAAMAAHADgAOAAVAD8AQgADAEQASQADAEwATAADAE0ATQAHAFYAVgAIAFgAWgAIAGQAaQAG
AGsAawAUAGwAbwAGAHQAewAEAHwAfwADAIkAiQADAJcAnAADAKQApgAIAK4AswAGALcAwQABAMMA1AABANUA1QASANYA2QABANoA
2gACAO8A9QACAPYA/gABAQIBAgABAQMBBgACAQ0BDQASARIBGgACARsBIAAFASIBJgAFASsBPgABAUgBSwACAUwBUQABAVIBVAAC
AVwBYgACAWMBaAAFAWsBbgABAW8BbwASAXEBcQASAXYBdgAEAXcBeAAHAXkBeQAEAXoBegAHAXwBfAAHAX0BfQADAX4BfwAHAYAB
gAAEAYEBggAHAYQBhAADAYUBhwAHAYgBiAAIAYkBiQAUAYoBigADAZYBlgAUAZcBlwABAZkBmQAFAZoBmwABAZ0BnQACAZ4BngAD
AaABoAACAaIBogACAaMBowAFAaUBpQABAacBpwACAagBqQABAaoBqgASAawBrAABAa4BrgACAa8BrwABAbYBuQABAboBugACAbsB
vAABAb0BvQAMAb4BvgAOAcEBwQAQAcIBwgARAcQBxAANAcYBxgAPAccBxwAMAcgByAAOAcsBywAQAcwBzAARAc4BzgANAdAB0AAP
AdEB0QAMAdIB0gAOAdUB1QAQAdYB1gARAdgB2AANAdoB2gAPAdsB2wAMAdwB3AAOAd8B3wAQAeAB4AARAeIB4gANAeQB5AAPAeUB
5QAMAeYB5gAOAekB6QAQAeoB6gARAewB7AANAe4B7gAPAe8B7wADAiICIwALAiYCJgALAisCLAAKAjUCOAAKAjkCOQALAkICQwAL
AkQCRwAJAkgCSwATAkwCTQAJAmQCZAAUAnwCfAABAAQAAAABAAgAAQAMABYABQDCAY4AAgABAowCrQAAAAIAHAABALUAAAC3AMgA
tQDKAOUAxwDnAW4A4wF0AXcBawF6AXoBbwF8AXwBcAF+AX8BcQGBAYIBcwGEAYQBdQGGAYYBdgGIAYkBdwGLAYsBeQGOAZMBegGV
AZcBgAGZAZkBgwGbAZsBhAGdAZ0BhQGfAZ8BhgGjAaMBhwGlAaUBiAGrAasBiQGvAb0BigHRAdEBmQHlAeUBmgJWAlYBmwJhAmIB
nAJ3AncBngAiAAAZdAAAGbYAABl6AAAZgAAAGYYAAQCKAAAZjAAAGZIAABmYAAAZngAAGaQAABmqAAAZvAACAJAAAgCWAAMAnAAE
AKIABACoAAQArgAEALQAABm2AAAZtgAAGbAAAQC6AAAZtgAAGbYAABm2AAAZtgAAGbYAABm2AAAZvAACAMAAAgDGAAMAxgABAJIB
8AABAGsAAAABASgAAAABARcAAAABAP8BiAABARMBigABASoBjgABASwBWgABAEEB8AABAIwAAAABAJYAAAGfEdYAABX2FfwAABA4
AAAV9hX8AAAQPgAAFfYV/AAAEEQAABX2FfwAABHWAAAV9hX8AAAQSgAAFfYV/AAAEFAAABX2FfwAABHWAAAV9hX8AAAQVgAAFfYV
/AAAEFwAABX2FfwAABBiAAAQaBBuAAAWAgAAFggAAAAAEgwR3BaYEeIR6BB0EdwWmBHiEegQehHcFpgR4hHoEgwR3BaYEeIR6BIS
EdwWmBHiEegR7gAAEfQAABH6Ee4AABH0AAAR+hCAAAAR9AAAEfoR7gAAEfQAABH6EgAAABYOFhQAABCGAAAWDhYUAAAQjAAAFg4W
FAAAEJIAABYOFhQAABCYAAAWDhYUAAAQngAAFg4WFAAAEKQAABYOFhQAABCqAAAWDhYUAAASAAAAFg4WFAAAELAAABX2AAAAABIM
EhgSHhIkEioQthIYEh4SJBIqEgwSGBIeEiQSKhISEhgSHhIkEioQvAAAFhoAABYgELwAABYaAAAWIBIwAAAW7BbyAAAQwgAAEMgQ
zgAAENQAABbsFvIAABDaAAAW7BbyAAAW5gAAFuwW8gAAEOAAABbsFvIAABDmAAAW7BbyAAAQ7AAAFuwW8gAAEjAAABbsFvIAABDy
AAAQ+AAAAAAWLAAAFjIAAAAAFiwAABYyAAAAABI2EjwSQgAAEkgQ/hI8EkIAABJIEjYSPBJCAAASSBI2EjwSQgAAEkgSNhI8EkIA
ABJIEjYSPBJCAAASSBY4AAAWPgAAAAAWRAAAFkoAAAAAEQQAABZKAAAAABEKAAAWSgAAAAAWRAAAFkoAAAAAERAAABZKAAAAABZE
AAAWSgAAAAASThZQFlYWXBZiERYWUBZWFlwWYhEcFlAWVhZcFmISThZQFlYWXBZiESIWUBZWFlwWYhEoFlAWVhZcFmIRLhZQFlYW
XBZiETQWUBZWFlwWYhJOFlAWVhZcFmIROhZQFlYWXBZiEk4WUBZWFlwWYhZoAAAWbgAAAAARQAAAEUYAAAAAEUwWUBZWFlwWYhJU
AAASWgAAAAARUgAAEloAAAAAEVgAABJaAAAAABJUAAASWgAAAAASYAAAEmYAAAAAEV4AABJmAAAAABFkAAASZgAAAAASYAAAEmYA
AAAAEmAAABJmAAAAABZ0AAAWegAAFoAWdAAAFnoAABaAEWoAABZ6AAAWgBZ0AAAWegAAFoAWdAAAFnoAABaAEnISeBJ+EoQAABFw
EngSfhKEAAARdhJ4En4ShAAAEmwSeBJ+EoQAABF8EngSfhKEAAARghJ4En4ShAAAEYgSeBJ+EoQAABJyEngSfhKEAAARjhJ4En4S
hAAAEZQAABGaAAAAABKKAAASkAAAAAARoAAAEpAAAAAAEaYAABKQAAAAABKKAAASkAAAAAARrAAAEpAAAAAAFowAABaSAAAAABKW
AAAW/gAAAAARsgAAFv4AAAAAEbgAABb+AAAAABb4AAAW/gAAAAARvgAAFv4AAAAAEpwAABKiAAAAABHEAAASogAAAAARygAAEqIA
AAAAEdAAABKiAAAAABHWAAAV9hX8AAAR1gAAFfYV/AAAEdYAABX2FfwAABHWAAAV9hX8AAAR1gAAFfYV/AAAEdYAABX2FfwAABHW
AAAV9hX8AAAR1gAAFfYV/AAAEgwR3BaYEeIR6BIMEdwWmBHiEegSDBHcFpgR4hHoEhIR3BaYEeIR6BHuAAAR9AAAEfoSAAAAFg4W
FAAAEgAAABYOFhQAABIAAAAWDhYUAAASAAAAFg4WFAAAEgAAABYOFhQAABIGAAAWDhYUAAASDBIYEh4SJBIqEgwSGBIeEiQSKhIS
EhgSHhIkEioSMAAAFuwW8gAAEjAAABbsFvIAABIwAAAW7BbyAAASMAAAFuwW8gAAEjAAABbsFvIAABYsAAAWMgAAAAASNhI8EkIA
ABJIEjYSPBJCAAASSBI2EjwSQgAAEkgWRAAAFkoAAAAAFkQAABZKAAAAABZEAAAWSgAAAAAWRAAAFkoAAAAAEk4WUBZWFlwWYhJO
FlAWVhZcFmISThZQFlYWXBZiEk4WUBZWFlwWYhJOFlAWVhZcFmISThZQFlYWXBZiElQAABJaAAAAABJUAAASWgAAAAASVAAAEloA
AAAAEmAAABJmAAAAABJgAAASZgAAAAASYAAAEmYAAAAAEmAAABJmAAAAABZ0AAAWegAAFoAWdAAAFnoAABaAFnQAABZ6AAAWgBJy
EngSfhKEAAASchJ4En4ShAAAEnISeBJ+EoQAABJsEngSfhKEAAASchJ4En4ShAAAEnISeBJ+EoQAABJyEngSfhKEAAASigAAEpAA
AAAAEooAABKQAAAAABKKAAASkAAAAAASlgAAFv4AAAAAEpYAABb+AAAAABKWAAAW/gAAAAASnAAAEqIAAAAAEpwAABKiAAAAABc6
FKYUrBSyFLgSqBSmFKwUshS4Eq4UphSsFLIUuBK0FKYUrBSyFLgSuhSmFKwUshS4EsAUphSsFLIUuBLGFKYUrBSyFLgXOhSmFKwU
shS4EswUphSsFLIUuBLSFKYUrBSyFLgS2BSmEt4S5BS4EuoAABLwEvYS/BdGF1IXWBdeF2QTAhdSF1gXXhdkExoXUhdYF14XZBdG
F1IXWBdeF2QTCBdSF1gXXhdkFzoUvhciFMQUyhc6FL4XIhTEFMoXOhS+FyIUxBTKFNAAABTWFNwAABMOAAAU1hTcAAATFAAAFNYU
3AAAExoAABTWFNwAABMgAAAU1hTcAAATJgAAFNYU3AAAEywAABTWFNwAABMyAAAU1hTcAAAU0AAAFNYU3AAAEzgAABM+AAAAABjw
FOIU6BTuFPQTRBTiFOgU7hT0GPAU4hToFO4U9BNKFOIU6BTuFPQTUAAAE1YAABNcE1AAABNWAAATXBUMAAAVEhUYAAAU+gAAFQAV
BgAAE2IAABUAFQYAABNoAAAVABUGAAAU+gAAFQAVBgAAE24AABUAFQYAABN0AAAVABUGAAAVDAAAFRIVGAAAE3oAABUAFQYAABUM
AAAVEhUYAAAVHgAAFSQAAAAAFR4AABUkAAAAABUqFTAVNgAAFTwTgBUwFTYAABU8FSoVMBU2AAAVPBUqFTAVNgAAFTwVKhUwFTYA
ABU8E4YTjBOSAAATmBOeAAATpAAAAAAXQAAAFUIAAAAAE6oAABVCAAAAABOwAAAVQgAAAAAXQAAAFUIAAAAAE7YAABVCAAAAABdA
AAAVQgAAAAAXiBeOF5QXmhegE7wXjheUF5oXoBPCF44XlBeaF6ATyBeOF5QXmhegE84XjheUF5oXoBPUF44XlBeaF6AT2heOF5QX
mhegF4gXjheUF5oXoBPgF44XlBeaF6AT5heOE+wAABegE/IAABP4AAAAABP+AAAUBAAAAAAYwAAAFAoAAAAAFUgAABVOAAAAABSC
AAAVTgAAAAAUEAAAFU4AAAAAFUgAABVOAAAAABVUAAAVWgAAAAAUFgAAFVoAAAAAFBwAABVaAAAAABVUAAAVWgAAAAAVVAAAFVoA
AAAAFCIAABQoAAAAABVgFWYVbAAAFXIVYBVmFWwAABVyFWAVZhVsAAAVchVgFWYVbAAAFXIVYBVmFWwAABVyFXgV3hV+FYQAABQu
Fd4VfhWEAAAUNBXeFX4VhAAAFDoV3hV+FYQAABRAFd4VfhWEAAAURhXeFX4VhAAAFEwV3hV+FYQAABV4Fd4VfhWEAAAUUhXeFX4V
hAAAFwoAABcQAAAAABWKAAAVkAAAAAAUWAAAFZAAAAAAFF4AABWQAAAAABRkAAAVkAAAAAAUagAAFZAAAAAAFHAAABR2AAAAABWW
AAAVnAAAAAAUfAAAFZwAAAAAFIIAABWcAAAAABSIAAAVnAAAAAAUjgAAFZwAAAAAFaIAABWoAAAAABSUAAAVqAAAAAAUmgAAFagA
AAAAFKAAABWoAAAAABc6FKYUrBSyFLgXOhSmFKwUshS4FzoUphSsFLIUuBc6FKYUrBSyFLgXOhSmFKwUshS4FzoUphSsFLIUuBc6
FKYUrBSyFLgXOhSmFKwUshS4F0YXUhdYF14XZBdGF1IXWBdeF2QXRhdSF1gXXhdkFzoUvhciFMQUyhTQAAAU1hTcAAAU0AAAFNYU
3AAAFNAAABTWFNwAABTQAAAU1hTcAAAU0AAAFNYU3AAAFNAAABTWFNwAABjwFOIU6BTuFPQY8BTiFOgU7hT0FPoAABUAFQYAABT6
AAAVABUGAAAU+gAAFQAVBgAAFPoAABUAFQYAABUMAAAVEhUYAAAVHgAAFSQAAAAAFSoVMBU2AAAVPBUqFTAVNgAAFTwVKhUwFTYA
ABU8F0AAABVCAAAAABdAAAAVQgAAAAAXQAAAFUIAAAAAF0AAABVCAAAAABeIF44XlBeaF6AXiBeOF5QXmhegF4gXjheUF5oXoBeI
F44XlBeaF6AXiBeOF5QXmhegF4gXjheUF5oXoBVIAAAVTgAAAAAVSAAAFU4AAAAAFUgAABVOAAAAABVUAAAVWgAAAAAVVAAAFVoA
AAAAFVQAABVaAAAAABVUAAAVWgAAAAAVYBVmFWwAABVyFWAVZhVsAAAVchVgFWYVbAAAFXIVeBXeFX4VhAAAFXgV3hV+FYQAABV4
Fd4VfhWEAAAVeBXeFX4VhAAAFXgV3hV+FYQAABV4Fd4VfhWEAAAVeBXeFX4VhAAAFYoAABWQAAAAABWKAAAVkAAAAAAVigAAFZAA
AAAAFZYAABWcAAAAABWWAAAVnAAAAAAVlgAAFZwAAAAAFaIAABWoAAAAABWiAAAVqAAAAAAVtBXAFcYVzBXSFa4VwBXGFcwV0hW0
FcAVxhXMFdIVuhXAFcYVzBXSFdgV3hXkFeoV8BeIF44XlBeaF6AAAAAAFfYV/AAAFgIAABYIAAAAAAAAAAAWDhYUAAAAAAAAFhoA
ABYgFiYAABbsFvIAABYsAAAWMgAAAAAWOAAAFj4AAAAAFkQAABZKAAAAAAAAFlAWVhZcFmIWaAAAFm4AAAAAFnQAABZ6AAAWgBaG
AAAW/gAAAAAWjAAAFpIAAAAAAAAAABaYFp4AAAAAAAAWpBaqAAAAAAAAFrAAABa2AAAAABa8FsIAAAAAFsgWzhbUFtoAAAAAFuAA
AAAAFuYAABbsFvIAABb4AAAW/gAAAAAXOgAAAAAAAAAAFwoAABcQAAAAABcEAAAAAAAAAAAXQAAAAAAAAAAAFxYAAAAAAAAAABcK
AAAXEAAAAAAXiBeOF5QXmhegF0YAAAAAAAAAABc0AAAAAAAAAAAXFgAAAAAAAAAAFxYAAAAAAAAAABcWAAAAAAAAAAAXRgAAAAAA
AAAAF0YXHBciFygXLhdGFxwXIhcoFy4XiBeOF5QXmhegFzQAAAAAAAAAABc6AAAAAAAAAAAXTAAAAAAAAAAAF0AAAAAAAAAAABdG
F1IXWBdeF2QXTBdSF1gXXhdkF2oXcBd2F3wXgheIF44XlBeaF6AXphesF7IXuBe+F8QAABfKAAAX0BfWAAAX3AAAAAAX4hfoF+4X
9Bf6GAAAABgGAAAAAAABAd4DcwABAYoDVgABAYoDcwABATQDcwABAYsDLgABAYoDnAABAYIDYAABAmsCqAABAmsAAAABBAkAAAAB
AhoDdwABAckDdwABAZ0DiAABAeEDcwABAZADcwABAY0DcwABAY0DSAABAY4DSQABATcDcwABAY4DLgABAYoCqAABAcYDWgABAdIC
qAABAIMCqAABAIMAAAABAQMACgABAPYDcwABAKIDcwABAKMDSQABAEwDcwABAKMDLgABAVkCqAABAVkAAAABAOMDcwABAh0DcwAB
AcwDcwABAcEDYAABAiIDdwABAc4DdwABAc8DTQABAXgDdwABAgsDdwABAc8DMgABAcYDZAABAS4CqAABAS4AAAABAc4CqAABAewD
cwABAZsDcwABAacDdwABAVYDdwABAWwDcwABAg4DcwABAboDcwABAWQDcwABAgADNAABAbsDLgABAboDnAABAYQCqAABAYQAAAAB
AuIDgwABAo4DgwABAjgDgwABAcYDcwABAXIDcwABARwDcwABAe8DgwABAZ4DgwABAZwDWQABAYoCegABA6kCqAABAwYAAAABAd4B
VAABAZoCjwABAbsAAAABATUBUQABAY0CegABATcCqAABAcYCfgABAccDTQABA6QCqAABAcYAAAABA10ACgABAdkBVAABAKICegAB
AI8CegABAXQB8AABAYYAAAABAUUBVAABAc4CfgABAZgCegABAZX/+wABAVMCfgABAVj/+wABAbgChwABAboCegABAz0CqAABAbj/
+wABAuD/+wABAo4CigABAl4AAAABAXICegABAZsCigABAZsAAAABAawC9wABAVgC2gABAVgC9wABAVgCzAABAQIC9wABAVkCsgAB
AVgDIAABAVAC5AABAa4B9AABAa4AAAABBIf//gABAZMB/gABAWD/9gABAJcAAAABAYgA+gABAbEC9wABAV4CzQABAbQC9wABAWMC
9wABAWAC9wABAWACzAABAWECzQABAQoC9wABAWECsgABAPwB9AABAPwAAAABATQC2gABATUCzQABAYwB/gABAWQAAAABAP0BXAAB
AM8C9QABAHsC9QABAHwCywABACUC9QABAHwCsAABAOADtQABAJYCvAABAQUB8AABAJIAAAABAJkBcwABAm4B9AABAkgAAAABAdAC
9wABAX8C9wABAXQC5AABAbUC9wABAWEC9wABAWECzAABAQsC9wABAZ4C9wABAWICsgABAVkC5AABAd8B9AABAd8AAAABAYMB/gAB
AYn/9gABAWwB9wABAW///QABAVP/9gABAO8C9wABAWwC9wABARsC9wABAU8B9AABAU8AAAABAbkC9wABAWUC9wABAWUCzAABAQ8C
9wABAaIC9wABAWYCsgABAWUDIAABAj8C9wABAesC9wABAesCzAABAZUC9wABAUgB9AABAUgAAAABAZQC9wABAUAC9wABAUACzAAB
AOoC9wABAYkC9wABATgC9wABATYCzQABAtUB9AABAOP/9gABAlcAAAABAVEA+gABAtAB8AABAlEAAAABAWEA+gABAWAB/gABAWoA
AAABAjsAAAABAo4B9AABATj/LgABAaUACgABATMA+gABAHsB/AABAHsAAAABALYAAAABAIYB/AABAIYAAAABAMEAAAABAUcB9AAB
AUQAAAABAIwCvAABAPsB8AABAIgAAAABAI8BcwABAVwAAAABAOwB/gABAH4AAAABARgB/gABATD/9gABANkCfwABATwCKwABANoA
AAABANYA+gABAWUB/gABAU4AAAABAj0AAAABAesB/gABAfMAAAABAUAB/gABAUAAAAABATUB/gABATUAAAABATgC2gABATgB/gAB
ATkCzQABApIB9AABATz/LgABAakACgABATcA+gABAS0B/gABAqoB9AABALj/9gABAiwAAAABAScA+gABAYoAAAABAsMABwABAXoC
qAABAXoAAAABAZgAAAABAoQAAAABAdIAAAABAdIBVAABAKMC0gABAYECqAABAYEAAAABAiUCnAABAiUAAAABAckCegABAcwAAAAB
A5gCqAABAc4AAAABA1EACgABAc4BTgABAYUCqAABAYUAAAABAWkCegABAWkAAAABAWkBVAABAXIC0gABAYMCqAABAYMAAAABAc8A
AAABAwgABwABArMAAAABA58AAAABAu0AAAABAu0BVAABAcoAAAABAbwAAAABBFkCqAABAo8AAAABBBIACgABAo8BTgABAqEAAAAB
AKIDSAABAK8AAAABAKEAAAABAXIDSAABAXIAAAABAVgB8QABATkB9AABATkAAAABAH0B8QABArYB9AABAV3/9gABAc4ACgABAVwA
+gABAdsB/gABAVgB/gABAXwB/gABAV0B/gABAVsB/gABAr4B9AABAWP/9gABAdUACgABAWMA+gABAXIB/gABAssB9AABAXL/9gAB
AeMACgABAXEA+gABAWEB/gABAroB9AABAWH/9gABAdIACgABAWAA+gABAWkB/gABAsIB9AABAWn/9gABAdoACgABAWgA+gABAW4C
qAABAW4AAAABAW4BVAABARMCPwABASoANwABAZUCqAABAwgCqAABAZUAAAABAtIACgABAaoBVAABASsB9AABASsAAAAGABAAAQAK
AAAAAQAMACgAAQA4AOAAAgAEAowCkAAAApICmAAFAqACogAMAqQCqgAPAAIAAgKMApAAAAKSApcABQAWAAAAWgAAAJwAAABgAAAA
ZgAAAGwAAAByAAAAeAAAAH4AAACEAAAAigAAAJAAAACiAAAAnAAAAJwAAACWAAAAnAAAAJwAAACcAAAAnAAAAJwAAACcAAAAogAB
AQgB/gABAVQB/gABAKUB/gABARQB/gABAU4B/gABAUsB/gABAT8B/gABAPUB/gABAVAB/gABAP0B/gABAQMB/gABAJYB/gABATQB
/gALABgAHgAkACoAMAA2ADYAPABCAEgATgABAQgCzAABAJcCzQABAP4C9wABAPkC9wABAVEC9wABAU4C9wABAT8C2gABAPUDIAAB
AUgC5AABAP4CsgAAAAEAAAAKAhgDigACREZMVAAObGF0bgA+AAQAAAAA//8AEwAAAAEAAgAEAAUABgAHAAgAEQASABMAFAAVABYA
FwAYABkAGgAbADQACEFaRSAAYENBVCAAjkNSVCAAvEtBWiAA6k1PTCABGFJPTSABRlRBVCABdFRSSyABogAA//8AEwAAAAEAAwAE
AAUABgAHAAgAEQASABMAFAAVABYAFwAYABkAGgAbAAD//wAUAAAAAQACAAQABQAGAAcACAAJABEAEgATABQAFQAWABcAGAAZABoA
GwAA//8AFAAAAAEAAgAEAAUABgAHAAgACgARABIAEwAUABUAFgAXABgAGQAaABsAAP//ABQAAAABAAIABAAFAAYABwAIAAsAEQAS
ABMAFAAVABYAFwAYABkAGgAbAAD//wAUAAAAAQACAAQABQAGAAcACAAMABEAEgATABQAFQAWABcAGAAZABoAGwAA//8AFAAAAAEA
AgAEAAUABgAHAAgADQARABIAEwAUABUAFgAXABgAGQAaABsAAP//ABQAAAABAAIABAAFAAYABwAIAA4AEQASABMAFAAVABYAFwAY
ABkAGgAbAAD//wAUAAAAAQACAAQABQAGAAcACAAPABEAEgATABQAFQAWABcAGAAZABoAGwAA//8AFAAAAAEAAgAEAAUABgAHAAgA
EAARABIAEwAUABUAFgAXABgAGQAaABsAHGFhbHQAqmNhc2UAsmNjbXAAuGNjbXAAwGRsaWcAymRub20A0GZyYWMA1mxpZ2EA4Gxu
dW0A5mxvY2wA7GxvY2wA8mxvY2wA+GxvY2wA/mxvY2wBBGxvY2wBCmxvY2wBEGxvY2wBFm51bXIBHG9udW0BIm9yZG4BKHBudW0B
LnNzMDEBNHNzMDIBPnNzMDMBSHNzMDQBUnNzMDUBXHN1cHMBZnRudW0BbAAAAAIAAAABAAAAAQAeAAAAAgACAAUAAAADAAIABQAF
AAAAAQAfAAAAAQASAAAAAwATABQAFQAAAAEAIAAAAAEAGgAAAAEABgAAAAEADQAAAAEABwAAAAEACAAAAAEADAAAAAEACwAAAAEA
CQAAAAEACgAAAAEAEQAAAAEAHQAAAAEAGAAAAAEAGwAGAAEAIQAAAQAABgABACIAAAEBAAYAAQAjAAABAgAGAAEAJAAAAQMABgAB
ACUAAAEEAAAAAQAQAAAAAQAcACYATgNIBUYFkAWQBZ4FugW6BboFugW6Bc4FzgXoBioGSgZqBqQGggaQBqQGsgbwBvAHCAdGB2gH
gAfACAAIWgjaCR4JUAlkCXgL9gwOAAEAAAABAAgAAgF6ALoBdAB0AHUAdgB3AHgAeQB6AHsAfAB9AH4AfwCAAIEAggCDAIQAhQCG
AIcAiACJAIoAiwCMAI0AjgCPAJAAkQCSAJMAlACVAJYBdQCXAJgAmQCaAJsAnACdAJ4AnwCgAKEAowCkAKYApwCoAKkAqgCrAKwA
rQCuAK8AsACxALIAswC0ALUBdAErASwBLQEuAS8BMAExATIBMwE0ATUBNgE3ATgBOQE6ATsBPAFrAW4A4QE/AUABQQFCAUMBRAFF
AUYBRwFIAUkBSgFLAXUBTAFNAU4BTwFQAVEBUgFTAVQBVQFWAVgBWQFbAVwBXQFeAV8BYAFhAWIBYwFkAWUBZgFnAWgBaQFqAbsB
vAHHAcgByQHKAcsBzAHNAc4BzwHQAe8B8AHxAfIB8wH0AfUB9gH3AfgCMQIyAjMCNAIDAkACQQJeAqACoQKiAqMCpAKlAqYCpwKo
AqkCqgKrAqwCrQK7ArwCvQK+Ar8CwALBAsICwwLEAsUAAQC6AAEAAgADAAQABgAHAAgACQAKAA4ADwAQABEAFAAXABgAGQAcAB0A
HgAhACIAIwAoACkALAAtAC4AMQAzADQANQA6ADsAPAA9AD8AQABBAEQARQBGAEgATgBPAFAAUgBTAFUAWABaAFwAXQBfAGAAYQBi
AGMAZgBnAGkAbABtAG8AcQByALcAuAC5ALoAvAC9AL4AvwDAAMQAxQDGAMoAzQDOAM8A0gDTANQA1gDZANwA3gDfAOIA5ADlAOgA
6gDrAOwA8QDyAPMA9AD2APcA+AD6APsA/AD+AQQBBQEGAQgBCQELAQ8BEQETARQBFgEXARgBGQEaAR0BHgEgASMBJAEmASgBKQGb
AbkB0QHSAdMB1AHVAdYB1wHYAdkB2gH5AfoB+wH8Af0B/gH/AgACAQICAicCKAIpAioCLwI6AjsCUAKOAo8CkAKRApICkwKUApUC
lgKXApgCmQKaApsCsAKxArICswK0ArUCtgK3ArgCuQK6AAMAAAABAAgAAQHCAC8AZABqAHAAdgB8AIIAiACUAKIAsAC+AMwA2ADk
APAA/AEIAQ4BFAEaASABJgEsATIBOAE+AUQBSgFQAVYBXAFiAWgBbgF0AXoBgAGGAYwBkgGYAZ4BpAGqAbABtgG8AAIAVQCiAAIA
WgClAAIBPQFsAAIBPgFtAAIBCwFXAAIBEQFaAAUBxwHRAeUB7wH5AAYByAHSAeYB8AH6AhgABgHJAdMB5wHxAfsCGQAGAcoB1AHo
AfIB/AIaAAYBywHVAekB8wH9AhsABQHMAdYB6gH0Af4ABQHNAdcB6wH1Af8ABQHOAdgB7AH2AgAABQHPAdkB7QH3AgEABQHQAdoB
7gH4AgIAAgG9AdsAAgG+AdwAAgG/Ad0AAgHAAd4AAgHBAd8AAgHCAeAAAgHDAeEAAgHEAeIAAgHFAeMAAgHGAeQAAgHHAeUAAgHI
AeYAAgHJAecAAgHKAegAAgHLAekAAgHMAeoAAgHNAesAAgHOAewAAgHPAe0AAgHQAe4AAgG9AccAAgG+AcgAAgG/AckAAgHAAcoA
AgHBAcsAAgHCAcwAAgHDAc0AAgHEAc4AAgHFAc8AAgHGAdAAAgJcAl0AAgAIAFQAVAAAAFkAWQABANcA2AACAQoBCgAEARABEAAF
Ab0B0AAGAdsB7gAaAlECUQAuAAYAAAACAAoAHAADAAAAAQB4AAEAMAABAAAAAwADAAAAAQBmAAIAFAAeAAEAAAAEAAIAAQKaAp8A
AAACAAICjAKQAAACkgKYAAUAAQAAAAEACAABADAAAQACAAAAAQAIAAEACAABAA4AAQABAXEAAgDVANwAAQAAAAEACAABAAYABQAB
AAEA3AABAAAAAQAIAAEABgABAAEABABUAFkBCgEQAAYAAAABAAgAAQAKAAIAEgAmAAEAAgAyAOkAAQAEAAAAAgIrAAEAMgABAAAA
DwABAAQAAAACAisAAQDpAAEAAAAOAAQAAAABAAgAAQASAAEACAABAAQA7QACAisAAQABAOkABAAAAAEACAABABIAAQAIAAEABAA2
AAICKwABAAEAMgABAAAAAQAIAAEABgBaAAIAAQG+AcEAAAABAAAAAQAIAAEA7AAyAAEAAAABAAgAAQAG/9QAAQABAi8AAQAAAAEA
CAABAMoAPAAGAAAAAgAKACIAAwABABIAAQBCAAAAAQAAABYAAQABAgMAAwABABIAAQAqAAAAAQAAABcAAgABAe8B+AAAAAEAAAAB
AAgAAQAG//YAAgABAfkCAgAAAAYAAAACAAoAJAADAAEAZAABABIAAAABAAAAGQABAAIAAQC3AAMAAQBKAAEAEgAAAAEAAAAZAAEA
AgA/APYAAQAAAAEACAACAA4ABAF0AXUBdAF1AAEABAABAD8AtwD2AAEAAAABAAgAAQAGAAoAAgABAb0BxgAAAAEAAAABAAgAAgAu
ABQBxwHIAckBygHLAcwBzQHOAc8B0AG9Ab4BvwHAAcEBwgHDAcQBxQHGAAIAAQHbAe4AAAABAAAAAQAIAAIALgAUAeUB5gHnAegB
6QHqAesB7AHtAe4B2wHcAd0B3gHfAeAB4QHiAeMB5AACAAEBvQHQAAAAAQAAAAEACAACAEIAHgHRAdIB0wHUAdUB1gHXAdgB2QHa
Ab0BvgG/AcABwQHCAcMBxAHFAcYB5QHmAecB6AHpAeoB6wHsAe0B7gACAAIBvQHQAAAB2wHkABQAAQAAAAEACAACAFAAJQHHAcgB
yQHKAcsBzAHNAc4BzwHQAccByAHJAcoBywHMAc0BzgHPAdABxwHIAckBygHLAcwBzQHOAc8B0AIxAjICMwI0AkACQQJcAAIABgG9
AcYAAAHRAdoACgHlAe4AFAInAioAHgI6AjsAIgJRAlEAJAAEAAgAAQAIAAEAMgADAAwAFgAoAAEABAC2AAIA2gACAAYADAFyAAIA
3AFzAAIBIgABAAQCIQACAikAAQADAFYBDQInAAQACAABAAgAAQAkAAEACAADAAgAEAAWAXAAAwDVANwBbwACANUBcQACANwAAQAB
ANUAAQAAAAEACAABAAYADAABAAECUQABAAAAAQAIAAEABgAOAAEAAQJQAAEAAAABAAgAAgE8AJsAdAB1AHYAdwB4AHkAegB7AHwA
fQB+AH8AgACBAIIAgwCEAIUAhgCHAIgAiQCKAIsAjACNAI4AjwCQAJEAkgCTAJQAlQCWAJcAmACZAJoAmwCcAJ0AngCfAKAAoQCi
AKMApAClAKYApwCoAKkAqgCrAKwArQCuAK8AsACxALIAswC0ALUBKwEsAS0BLgEvATABMQEyATMBNAE1ATYBNwE4ATkBOgE7ATwB
PQE+AT8BQAFBAUIBQwFEAUUBRgFHAUgBSQFKAUsBTAFNAU4BTwFQAVEBUgFTAVQBVQFWAVcBWAFZAVoBWwFcAV0BXgFfAWABYQFi
AWMBZAFlAWYBZwFoAWkBagKgAqECogKjAqQCpQKmAqcCqAKpAqoCqwKsAq0CuwK8Ar0CvgK/AsACwQLCAsMCxALFAAEAmwACAAMA
BAAGAAcACAAJAAoADgAPABAAEQAUABcAGAAZABwAHQAeACEAIgAjACgAKQAsAC0ALgAxADMANAA1ADoAOwA8AD0AQABBAEQARQBG
AEgATgBPAFAAUgBTAFQAVQBYAFkAWgBcAF0AXwBgAGEAYgBjAGYAZwBpAGwAbQBvAHEAcgC4ALkAugC8AL0AvgC/AMAAxADFAMYA
ygDNAM4AzwDSANMA1ADXANgA3gDfAOIA5ADlAOgA6gDrAOwA8QDyAPMA9AD3APgA+gD7APwA/gEEAQUBBgEIAQkBCgELAQ8BEAER
ARMBFAEWARcBGAEZARoBHQEeASABIwEkASYBKAEpAo4CjwKQApECkgKTApQClQKWApcCmAKZApoCmwKwArECsgKzArQCtQK2ArcC
uAK5AroAAQAAAAEACAABAAYAlQACAAEA1gDZAAAAAQAAAAEACAACAAoAAgG7AbwAAQACAZsBuQAA
'@
try {
    Add-Type -AssemblyName System.Drawing
    $script:theNeueFontBytes = [Convert]::FromBase64String($script:theNeueFontBase64)
    $script:theNeueFontCollection = New-Object System.Drawing.Text.PrivateFontCollection

    $theNeueMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($script:theNeueFontBytes.Length)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy(
            $script:theNeueFontBytes,
            0,
            $theNeueMem,
            $script:theNeueFontBytes.Length
        )
        $script:theNeueFontCollection.AddMemoryFont($theNeueMem, $script:theNeueFontBytes.Length)
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($theNeueMem)
    }

    if ($script:theNeueFontCollection.Families.Count -gt 0) {
        $script:theNeueFontFamily = $script:theNeueFontCollection.Families[0]
    }
} catch {
    $script:theNeueFontFamily = $null
} finally {
    $script:theNeueFontBase64 = $null
    $script:theNeueFontBytes = $null
}


# -----------------------------------------------------------------------------
#  EMBEDDED SYNE EXTRA BOLD FONT FOR LOGIN WORDMARK
#  HIGH uses the user-provided Syne ExtraBold face. Loaded privately from memory
#  so the Login screen does not depend on the font being installed system-wide.
# -----------------------------------------------------------------------------
$script:syneExtraBoldFontCollection = $null
$script:syneExtraBoldFontFamily = $null
$script:syneExtraBoldFontBytes = $null
$script:syneExtraBoldFontBase64 = @'
AAEAAAARAQAABAAQR0RFRkSCRMgAATo8AAABQEdQT1M3qbZ3AAE7fAAAOihHU1VCAfaMxQABdaQAAA+yT1MvMoMpZ+IAAAGYAAAAYGNtYXDM2dacAAANFAAABTZjdnQgHaYKuQAAIRgAAABwZnBnbWIu/30AABJMAAAODGdhc3AAAAAQAAE6NAAAAAhnbHlmlf83ggAAJxgAAPYyaGVhZB/wSOYAAAEcAAAANmhoZWEK3gcMAAABVAAAACRobXR4LGV3SgAAAfgAAAscbG9jYW6lq+sAACGIAAAFkG1heHAENw9uAAABeAAAACBuYW1ljyOxnwABHUwAAATycG9zdF9b9+kAASJAAAAX8nByZXDftmJDAAAgWAAAAL0AAQAAAAIzMzVjRu5fDzz1AA8D6AAAAADbSI4NAAAAAN5FRFj+2/68CGMDrwAAAAYAAgAAAAAAAAABAAADnf7tAAAIx/7b/JAIYwABAAAAAAAAAAAAAAAAAAACxwABAAACxwCnABEAZAAFAAIAKABUAI0AAACgDgwABAABAAQD2QMgAAUAAAKKAlgAAABLAooCWAAAAV4ASwEmAAAAAAAAAAAAAAAAoAAA71AAIHsAAAAAAAAAAE5PTkUAwAAN+wEDnf7tAAADuwHvIAAAmwAAAAAB6gKAAAAAIAADAd4AWgSIAAoEiAAKBIgACgSIAAoEiAAKBIgACgSIAAoEiAAKBIgACgSIAAoGkQAKBHQARgUkADwFJAA8BSQAPAUkADwFJAA8BRYARgUW//AFFgBGBRb/8AR0AEYEdABGBHQARgR0AEYEdABGBHQARgR0AEYEdABGBHQARgRoAEYFPAA8BTwAPAU8ADwFPAA8BQAARgUAAB4BpABVBCIAVQGkAEkBpP9oAaT/uwGkAFMBpP9VAaT/7wGk/70D7AAfBL8ARgS/AEYDrwBGA68ARQOvAEYDrwBGA68ARgOv/+kGLABGBRQARgUUAEYFFABGBRQARgUUAEYFFABGBTIAPAUyADwFMgA8BTIAPAUyADwFMgA8BTIAPAUyADwFMgA8BTIAPAeqADwEmQBEBEkARAUyADwE0ABGBNAARgTQAEYE0ABGBCAAIwQgACMEIAAjBCAAIwQgACMETAAeBEwAHgRMAB4ETAAeBEwAHgUJAEYFCQBGBQkARgUJAEYFCQBGBQkARgUJAEYFCQBGBQkARgSIABQHWgAUB1oAFAdaABQHWgAUB1oAFAR0AB4ELgAFBC4ABQQuAAUELgAFBC4ABQSwAEYEsABGBLAARgSwAEYEiAAKBIgACgSIAAoEiAAKBIgACgSIAAoEiAAKBIgACgUkADwFJAA8BSQAPAUkADwFFgBGBHQARgR0AEYEdABGBHQARgR0AEYEdABGBTwAPAU8ADwFPAA8AaQAUwGkAFMBpABTAaQAUwGkAFMEvwBGA68ARgOvAEYDrwBGBRQARgUUAEYFFABGBRQARgUyADwFMgA8BTIAPAUyADwFMgA8BTIAPATQAEYE0ABGBNAARgQgACMEIAAjBCAAIwQgACMETAAeBEwAHgRMAB4FCQBGBQkARgUJAEYFCQBGBQkARgUJAEYFCQBGB1oAFAdaABQHWgAUBC4ABQQuAAUELgAFBLAARgSwAEYHvwAeBCcAIwQnACMEJwAjBCcAIwQnACMEJwAjBCcAIwQnACMEJwAjBCcAIwd7ACMESgBQA+IAIwPiACMD4gAjA+IAIwPiACMESgAjA/AAIwRKACMESgAjA+IAIwPiACMD4gAjA+IAIwPiACMD4gAjA+IAIwPiACMD4gAjAqIAFAPJACMDyQAjA8kAIwPJACMD8AA3A/D//wFsADcBXgA3AV4AJgFe/0UBXv/dAV4AMAFe/zIC2AA3AV7/zAFs//oBbAA3A64ANwOuADcBaAA8AWgAMgJiADwBaAA5ApMAPAF9/+IGdgAtA+YALQPmAC0D5gAtA+YALQPmAC0D5gAtA/gAIwP4ACMD+AAjA/gAIwP4ACMD+AAjA/gAIwP4ACMD+AAjBqAAIwQnAC0EJwAtBEoAIwIzAC0CMwAtAjP/7AIzACoDSgAmA0oAJgNKACYDSgAlA0oAJgRyADcCdAAUAnQAFAJ0ABQCdAAUAnQAFAPmAC0D5gAtA+YALQPmAC0D5gAtA+YALQPmAC0D5gAtA+YALQOWAAUFtgAFBbYABQW2AAUFtgAFBbYABQPUAAoDogAFA6IABQOiAAUDogAFA6IABQOAADwDgAA8A4AAPAOAADwEJwAjBCcAIwQnACMEJwAjBCcAIwQnACMEJwAjBCcAIwPiACMD4gAjA+IAIwRKACMD4gAjA+IAIwPiACMD4gAjA+IAIwPiACMDyQAjA8kAIwFeADABXgAwAV4AMAFeADABbAA1A64ANwFoADwCZgA8AWgANgPmAC0D5gAtA+YALQPmAC0D+AAjA/gAIwP4ACMD+AAjA/gAIwP4ACMCMwAtAjMALQIzACcDSgAmA0oAJgNKACYDSgAmAnQAFAJ0ABQCdAAUA+YALQPmAC0D5gAtA+YALQPmAC0D5gAtA+YALQW2AAUFtgAFBbYABQOiAAUDogAFA6IABQOAADwDgAA8A9MAIwPTACMD0wAjA9MAIwTRABQGNgAUBCMAFAOlABQFgQAUA+sAIwP4AEsEiAAKBHQARgO0AEYEiAAKBHQARgRgAEYFAABGBTIAPAGkAFUEvwBGBIgACgYsAEYFFABGBGoAPAUyADwFAABGBJkARARmAFAETAAeBC4ABQVaADwEdAAeBTQAPQTsAB4FPgAABmAAAAbsAAADkAAABr8AAAY4AAAGTAAAAaT/uwQuAAUEJwAjBCcALQOWAAUECgAjA+UALQM0AC0D5gAtBDgALQGfAC0DpAAtA5YABQQnAC0DlgAFAxYALQP4ACMEdAAyBCcALQPiACMD+AAjAooAMgPkAC0E1AAjA9QACgSYAC0FxQAjAZ8AHAGf/5UBn/7bA+QALQPkAC0D5P/lA/gAIwXFACMEJwAjA+UALQPmAC0D4gAjA+IAIwQqADwCEQAZA+sAIwQfACMERgAyA/cANwRtAB4EgQA8BDkAIwSGACMEkgA8AhEAGQQEACgEHwAjBEYAMgPyADIEbQAeBCcAFAQ5ACMEgQAjA/gAIwIRABkEBAAyBB8AIwRGADID9wA3BG0AHgSBADwEOQAjBIYAIwQfACAEHwBqBB8ANgQfACMEHwAUBB8APwQfAB0EJwAUBB8AFgQfAB0EHwAyBB8AagQfADIEHwAjBB8AFAQfAD8EHwAdBB8AFQQfABYEHwAdAtAAIwK7ABkCqAAjAqsAIwKhADICowA3AqUAHgKQAB4CnAAjAqoAIwLQACMCuwAZAqgAIwKrACMCoQAyAqMANwKlAB4CkAAeApwAIwKqACMAVP9WBbcAGQXPACMFugAZBe0AIwV0ABkFjAAjBbIAGQXlACMFygAjBdQAMgV9ABkFZQA3BeUAGQWrABkFwwAjBZMANwViAB4FuQAZCMcAGQBU/1YA9wAoAU0ALQFIAC8BOgAoAlgAAAE2AAABNgAAAWIAMgFiADIEjwAKAWIAMgEvABkBYgAyAWIAMgQSADIBigBGAYoARgNgACYDYAAoAWIAMgHeAFoCmgAUBXAAPAJuADICbgAyAYoARgGKAEYDUQAmA1YAKAJOAFACWABQArwAUAOsADwD1AAyAZUAPAGVADwCbwAeAm8AWgImAFoCJgA8AZUAPAGVADwBLwAZAl4AGQJeABkCXgAZAS8AGQEvABkDBgA8AwYAUAHrADwB6wAyAlwAGQEsABkE7AAeA1wAHgXaACMExAAjBE8AHgNlACMGXAA8BlwAPAafAEYCmQAoAbgAZAG4AGQEagBQBAYAHgPtAEYFCAA8BNgAMgPiACMDngAeA1kAKwV+ABQEPwAjBC4ABQGyAAADDAAyAlgAMgLHAE8CgAAyA0gAMgNIADICKABQAhQAKAIoAFACKAA8AwwAMgN+ADIBngBQA+0AVQJLAKcEKgA8BlQAPALvAB4EnAAeA/YAVASsAAUEJwAtBAUAIwURAB4FwgAeAvkAXQNdAGQDrQAoA14AZAL5AFoDXgBkA60APANdAGQEuAA8AvkAWgPpADICtABkBBgAAAAAACUAAAAUAAAAZAAAAGQAAABkAAABaAAAAGQAAABkAAAAggAAAGQAAABkAAAAZAAAAUMAAAAcAAAAZAAAAGQAAAAUAAAAFAAAABQAAAAUAAAAFAAAABQAAAAUAAAALQAAABQAAABkAAAAFAAAABQAAAAUAAAAFAAAAUIAAP/dAAAAFAAAABQCLgARATAAFALSAGQCtABkA0AAZAOcAGQDnABkA/IAggIaAGQDqQBkAo4AZAK2AGQCJQBkASYAFAEwAEsCLgARATAASwHGAGQCVACrASYAFAJUAKsBMAAZATAAFAEwABQCWAA2AAAAAgAAAAMAAAAUAAMAAQAAABQABAUiAAAAigCAAAYACgANAC8AOQB+AQcBEwEbASMBJwErATMBNwFIAU0BWwFnAWsBfgGSAhsCLgLHAt0DBAMIAwwDEgMoAzgDfgOKA4wDkAOhA6kDsAPJA84ehR7zIBQgGiAeICIgJiAwIDogRCB0IKwhIiFeIYkhmSICIgUiDyISIhUiGiIeIisiSCJgImUlyvj/+wH//wAAAA0AIAAwADoAoAEKARYBHgEmASoBLgE2ATkBSgFQAV4BagFuAZICGAIuAsYC2AMAAwYDCgMSAyYDNQN+A4QDjAOOA5EDowOqA7EDyh6AHvIgEyAYIBwgICAmIDAgOSBEIHQgrCEiIVAhiSGQIgIiBSIPIhEiFSIaIh4iKyJIImAiZCXK+P/7Af//Ag8AAAGNAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALwAAP4V/+0AAAAAAAAAAP+G/3P/Z/6iAAD+BgAA/eX95AAA/eYAAAAAAADiJAAAAAAAAOIA4k7iEeG/4afhtuE0AADgfAAA4HrgcOBpAADgUOBg4FjgTOAp4AsAANy/CVAGcAABAAAAiAAAAKQBLAH6AgwCFgIgAiICJAIuAjACTgJUAmoCfAJ+AAACnAAAAAACngKoArACtAAAAAAAAAAAArAAAAK6AAAAAAK6AAACxALMAtYAAALWAtoC3gAAAAAAAAAAAAAAAAAAAtQAAALuAAAAAAAAAvoAAAAAAAAAAAAAAAAC8AAAAAAAAAAAAh0CJwJMAi4CYQJ9AlECTQI6AjsCLQJmAiMCNQIiAi8CJAIlAm0CagJsAikCUAABAAwADQASABYAHwAgACQAJgAvADAAMgA4ADkAPwBKAEwATQBRAFYAWwBkAGUAagBrAHACPgIwAj8CdAI5ArAAtwDCAMMAyADMANUA1gDaANwA5gDnAOkA7wDwAPYBAAECAQMBBwENARIBGwEcASEBIgEnAjwCWAI9AnICHgIoAl8CYwJgAmQCWQJTAq4CVAF0AkgCcwI2AlUCuAJXAnACGQIaArECewJSAisCuQIYAXUCSQIIAgQCCQIqAAYAAgAEAAoABQAJAAsAEAAcABcAGQAaACwAKAApACoAEwA9AEQAQABBAEgAQgJoAEcAXwBcAF0AXgBsAEsBDAC8ALgAugDAALsAvwDBAMYA0gDNAM8A0ADiAN4A3wDgAMkA9AD6APcA+AD+APkCaQD9ARYBEwEUARUBIwEBASUABwC9AAMAuQAIAL4ADgDEABEAxwAPAMUAFADKABUAywAdANMAGwDRAB4A1AAYAM4AIQDXACMA2QAiANgAJQDbAC0A5AAuAOUAKwDdACcA4wAxAOgAMwDqADUA7AA0AOsANgDtADcA7gA6APEAPADzADsA8gA+APUARgD8AEUA+wBJAP8ATgEEAFABBgBPAQUAUgEIAFQBCgBTAQkAWQEQAFgBDwBXAQ4AYQEYAGMBGgBgARcAYgEZAGcBHgBtASQAbgBxASgAcwEqAHIBKQBVAQsAWgERArUCrwK2AroCtwKyAo4CjwKSApYClwKUAo0CjAKVApACkwKKAosBjgIfAY8BkAGRAZMBlAGyAZUBlgG4AbkBugGwAbUBsQG0AbYBswG3AGkBIABmAR0AaAEfAG8BJgJGAkcCQgJEAkUCQwJaAlsCLAIQAhUCFgIGAgcCCgILAgwCDQIOAg8CEQISAhMCFAKFAn8CgQKDAocCiAKGAoACggKEAnkCZwJvAm4AALAALCCwAFVYRVkgIEu4AA5RS7AGU1pYsDQbsChZYGYgilVYsAIlYbkIAAgAY2MjYhshIbAAWbAAQyNEsgABAENgQi2wASywIGBmLbACLCMhIyEtsAMsIGSzAxQVAEJDsBNDIGBgQrECFENCsSUDQ7ACQ1R4ILAMI7ACQ0NhZLAEUHiyAgICQ2BCsCFlHCGwAkNDsg4VAUIcILACQyNCshMBE0NgQiOwAFBYZVmyFgECQ2BCLbAELLADK7AVQ1gjISMhsBZDQyOwAFBYZVkbIGQgsMBQsAQmWrIoAQ1DRWNFsAZFWCGwAyVZUltYISMhG4pYILBQUFghsEBZGyCwOFBYIbA4WVkgsQENQ0VjRWFksChQWCGxAQ1DRWNFILAwUFghsDBZGyCwwFBYIGYgiophILAKUFhgGyCwIFBYIbAKYBsgsDZQWCGwNmAbYFlZWRuwAiWwDENjsABSWLAAS7AKUFghsAxDG0uwHlBYIbAeS2G4EABjsAxDY7gFAGJZWWRhWbABK1lZI7AAUFhlWVkgZLAWQyNCWS2wBSwgRSCwBCVhZCCwB0NQWLAHI0KwCCNCGyEhWbABYC2wBiwjISMhsAMrIGSxB2JCILAII0KwBkVYG7EBDUNFY7EBDUOwA2BFY7AFKiEgsAhDIIogirABK7EwBSWwBCZRWGBQG2FSWVgjWSFZILBAU1iwASsbIbBAWSOwAFBYZVktsAcssAlDK7IAAgBDYEItsAgssAkjQiMgsAAjQmGwAmJmsAFjsAFgsAcqLbAJLCAgRSCwDkNjuAQAYiCwAFBYsEBgWWawAWNgRLABYC2wCiyyCQ4AQ0VCKiGyAAEAQ2BCLbALLLAAQyNEsgABAENgQi2wDCwgIEUgsAErI7AAQ7AEJWAgRYojYSBkILAgUFghsAAbsDBQWLAgG7BAWVkjsABQWGVZsAMlI2FERLABYC2wDSwgIEUgsAErI7AAQ7AEJWAgRYojYSBksCRQWLAAG7BAWSOwAFBYZVmwAyUjYUREsAFgLbAOLCCwACNCsw0MAANFUFghGyMhWSohLbAPLLECAkWwZGFELbAQLLABYCAgsA9DSrAAUFggsA8jQlmwEENKsABSWCCwECNCWS2wESwgsBBiZrABYyC4BABjiiNhsBFDYCCKYCCwESNCIy2wEixLVFixBGREWSSwDWUjeC2wEyxLUVhLU1ixBGREWRshWSSwE2UjeC2wFCyxABJDVVixEhJDsAFhQrARK1mwAEOwAiVCsQ8CJUKxEAIlQrABFiMgsAMlUFixAQBDYLAEJUKKiiCKI2GwECohI7ABYSCKI2GwECohG7EBAENgsAIlQrACJWGwECohWbAPQ0ewEENHYLACYiCwAFBYsEBgWWawAWMgsA5DY7gEAGIgsABQWLBAYFlmsAFjYLEAABMjRLABQ7AAPrIBAQFDYEItsBUsALEAAkVUWLASI0IgRbAOI0KwDSOwA2BCIGC3GBgBABEAEwBCQkKKYCCwFCNCsAFhsRQIK7CLKxsiWS2wFiyxABUrLbAXLLEBFSstsBgssQIVKy2wGSyxAxUrLbAaLLEEFSstsBsssQUVKy2wHCyxBhUrLbAdLLEHFSstsB4ssQgVKy2wHyyxCRUrLbArLCMgsBBiZrABY7AGYEtUWCMgLrABXRshIVktsCwsIyCwEGJmsAFjsBZgS1RYIyAusAFxGyEhWS2wLSwjILAQYmawAWOwJmBLVFgjIC6wAXIbISFZLbAgLACwDyuxAAJFVFiwEiNCIEWwDiNCsA0jsANgQiBgsAFhtRgYAQARAEJCimCxFAgrsIsrGyJZLbAhLLEAICstsCIssQEgKy2wIyyxAiArLbAkLLEDICstsCUssQQgKy2wJiyxBSArLbAnLLEGICstsCgssQcgKy2wKSyxCCArLbAqLLEJICstsC4sIDywAWAtsC8sIGCwGGAgQyOwAWBDsAIlYbABYLAuKiEtsDAssC8rsC8qLbAxLCAgRyAgsA5DY7gEAGIgsABQWLBAYFlmsAFjYCNhOCMgilVYIEcgILAOQ2O4BABiILAAUFiwQGBZZrABY2AjYTgbIVktsDIsALEAAkVUWLEOBkVCsAEWsDEqsQUBFUVYMFkbIlktsDMsALAPK7EAAkVUWLEOBkVCsAEWsDEqsQUBFUVYMFkbIlktsDQsIDWwAWAtsDUsALEOBkVCsAFFY7gEAGIgsABQWLBAYFlmsAFjsAErsA5DY7gEAGIgsABQWLBAYFlmsAFjsAErsAAWtAAAAAAARD4jOLE0ARUqIS2wNiwgPCBHILAOQ2O4BABiILAAUFiwQGBZZrABY2CwAENhOC2wNywuFzwtsDgsIDwgRyCwDkNjuAQAYiCwAFBYsEBgWWawAWNgsABDYbABQ2M4LbA5LLECABYlIC4gR7AAI0KwAiVJiopHI0cjYSBYYhshWbABI0KyOAEBFRQqLbA6LLAAFrAXI0KwBCWwBCVHI0cjYbEMAEKwC0MrZYouIyAgPIo4LbA7LLAAFrAXI0KwBCWwBCUgLkcjRyNhILAGI0KxDABCsAtDKyCwYFBYILBAUVizBCAFIBuzBCYFGllCQiMgsApDIIojRyNHI2EjRmCwBkOwAmIgsABQWLBAYFlmsAFjYCCwASsgiophILAEQ2BkI7AFQ2FkUFiwBENhG7AFQ2BZsAMlsAJiILAAUFiwQGBZZrABY2EjICCwBCYjRmE4GyOwCkNGsAIlsApDRyNHI2FgILAGQ7ACYiCwAFBYsEBgWWawAWNgIyCwASsjsAZDYLABK7AFJWGwBSWwAmIgsABQWLBAYFlmsAFjsAQmYSCwBCVgZCOwAyVgZFBYIRsjIVkjICCwBCYjRmE4WS2wPCywABawFyNCICAgsAUmIC5HI0cjYSM8OC2wPSywABawFyNCILAKI0IgICBGI0ewASsjYTgtsD4ssAAWsBcjQrADJbACJUcjRyNhsABUWC4gPCMhG7ACJbACJUcjRyNhILAFJbAEJUcjRyNhsAYlsAUlSbACJWG5CAAIAGNjIyBYYhshWWO4BABiILAAUFiwQGBZZrABY2AjLiMgIDyKOCMhWS2wPyywABawFyNCILAKQyAuRyNHI2EgYLAgYGawAmIgsABQWLBAYFlmsAFjIyAgPIo4LbBALCMgLkawAiVGsBdDWFAbUllYIDxZLrEwARQrLbBBLCMgLkawAiVGsBdDWFIbUFlYIDxZLrEwARQrLbBCLCMgLkawAiVGsBdDWFAbUllYIDxZIyAuRrACJUawF0NYUhtQWVggPFkusTABFCstsEMssDorIyAuRrACJUawF0NYUBtSWVggPFkusTABFCstsEQssDsriiAgPLAGI0KKOCMgLkawAiVGsBdDWFAbUllYIDxZLrEwARQrsAZDLrAwKy2wRSywABawBCWwBCYgICBGI0dhsAwjQi5HI0cjYbALQysjIDwgLiM4sTABFCstsEYssQoEJUKwABawBCWwBCUgLkcjRyNhILAGI0KxDABCsAtDKyCwYFBYILBAUVizBCAFIBuzBCYFGllCQiMgR7AGQ7ACYiCwAFBYsEBgWWawAWNgILABKyCKimEgsARDYGQjsAVDYWRQWLAEQ2EbsAVDYFmwAyWwAmIgsABQWLBAYFlmsAFjYbACJUZhOCMgPCM4GyEgIEYjR7ABKyNhOCFZsTABFCstsEcssQA6Ky6xMAEUKy2wSCyxADsrISMgIDywBiNCIzixMAEUK7AGQy6wMCstsEkssAAVIEewACNCsgABARUUEy6wNiotsEossAAVIEewACNCsgABARUUEy6wNiotsEsssQABFBOwNyotsEwssDkqLbBNLLAAFkUjIC4gRoojYTixMAEUKy2wTiywCiNCsE0rLbBPLLIAAEYrLbBQLLIAAUYrLbBRLLIBAEYrLbBSLLIBAUYrLbBTLLIAAEcrLbBULLIAAUcrLbBVLLIBAEcrLbBWLLIBAUcrLbBXLLMAAABDKy2wWCyzAAEAQystsFksswEAAEMrLbBaLLMBAQBDKy2wWyyzAAABQystsFwsswABAUMrLbBdLLMBAAFDKy2wXiyzAQEBQystsF8ssgAARSstsGAssgABRSstsGEssgEARSstsGIssgEBRSstsGMssgAASCstsGQssgABSCstsGUssgEASCstsGYssgEBSCstsGcsswAAAEQrLbBoLLMAAQBEKy2waSyzAQAARCstsGosswEBAEQrLbBrLLMAAAFEKy2wbCyzAAEBRCstsG0sswEAAUQrLbBuLLMBAQFEKy2wbyyxADwrLrEwARQrLbBwLLEAPCuwQCstsHEssQA8K7BBKy2wciywABaxADwrsEIrLbBzLLEBPCuwQCstsHQssQE8K7BBKy2wdSywABaxATwrsEIrLbB2LLEAPSsusTABFCstsHcssQA9K7BAKy2weCyxAD0rsEErLbB5LLEAPSuwQistsHossQE9K7BAKy2weyyxAT0rsEErLbB8LLEBPSuwQistsH0ssQA+Ky6xMAEUKy2wfiyxAD4rsEAr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AUIAAP//AC3/OAO5AfkCJgDwAAAABwKrAZcAAP//AC0AAAO5AvECJgDwAAAABwKoAZIAAP//ACP/8QPVAvECJgD2AAAABwKhAWsAAP//ACP/8QPVAvECJgD2AAAABwKkAWsAAP//ACP/8QPVAvECJgD2AAAABwKgAWsAAP//ACP/8QPVAvECJgD2AAAABwKiANMAAP//ACP/8QPVAvECJgD2AAAABwKpAWsAAP//ACP/8QPVAvECJgD2AAAABwKoAWsAAP//AC0AAAIfAvECJgEDAAAABwKhAMMAAP//AC0AAAIfAvECJgEDAAAABgKlcwAAAP//ACf/OAIfAfkCJgEDAAAABgKrSgAAAP//ACb/8QMnAvECJgEHAAAABwKhAQoAAP//ACb/8QMnAvECJgEHAAAABwKlALoAAP//ACb/LgMnAfkCJgEHAAABBwKsAS7/9gAJsQEBuP/2sDUrAP//ACb/LgMnAfkCJgEHAAABBwKrAWX/9gAJsQEBuP/2sDUrAP//ABQAAALVAvQCJgENAAABBwKjAaoAQgAIsQEBsEKwNSsAAP//ABT/OAJgAoACJgENAAAABwKsAKcAAP//ABT/OAJgAoACJgENAAAABwKrAN4AAP//AC3/8QO5AvECJgESAAAABwKhAW4AAP//AC3/8QO5AvECJgESAAAABwKkAW4AAP//AC3/8QO5AvECJgESAAAABwKgAW4AAP//AC3/8QO5AvECJgESAAAABwKiANYAAP//AC3/8QO5AvECJgESAAAABwKpAW4AAP//AC3/OAPKAeoCJgESAAAABwKtArgAAP//AC3/8QO5AvECJgESAAAABwKnAW4AAP//AAUAAAWxAvECJgEcAAAABwKhAkUAAP//AAUAAAWxAvECJgEcAAAABwKkAkUAAP//AAUAAAWxAvECJgEcAAAABwKgAkUAAP//AAX/OAOdAvECJgEiAAAABwKhAUgAAP//AAX/OAOdAvECJgEiAAAABwKkAUgAAP//AAX/OAOdAvECJgEiAAAABwKgAUgAAP//ADwAAANEAvECJgEnAAAABwKhASkAAP//ADwAAANEAvECJgEnAAAABwKlANkAAAADACP+vAO1AfoAMwA/AE4A40AKGgEDAgcBCQUCTEuwDVBYQC4AAQYEBgEEgAsBBgAEBQYEaQAFAAkIBQlnDAEICgEA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ABUACLEAAbAVsDUr//8AFAJbARIC8QAGAqcAAP//AKsCWwGpAvEABwKoAJcAAAAA//8AGQJbARcC8QAGAqkFAP//ABT/OAES/88ABgKsAAD//wAU/zgBEv/PAAYCrQAAAAEANgCBAsQCYAADAAazAgABMisTAQUD/wHF/btJAmD+5cQBUgAAAAAAABQA9gADAAEECQAAAMIAAAADAAEECQABABwAwgADAAEECQACAA4A3gADAAEECQADADIA7AADAAEECQAEABwBHgADAAEECQAFAEYBOgADAAEECQAGABwBgAADAAEECQAIABoBnAADAAEECQAJABwBtgADAAEECQALADAB0gADAAEECQAMADgCAgADAAEECQANASICOgADAAEECQAOADYDXAADAAEECQAQAAgDkgADAAEECQARABIDmgADAAEECQEAABIDrAADAAEECQEBAAQDvgADAAEECQECAA4DwgADAAEECQEDAB4D0AADAAEECQEEAA4D7gBDAG8AcAB5AHIAaQBnAGgAdAAgADIAMAAxADkAIABUAGgAZQAgAFMAeQBuAGUAIABQAHIAbwBqAGUAYwB0ACAAQQB1AHQAaABvAHIAcwAgACgAaAB0AHQAcABzADoALwAvAGcAaQB0AGwAYQBiAC4AYwBvAG0ALwBiAG8AbgBqAG8AdQByAC0AbQBvAG4AZABlAC8AZgBvAG4AZABlAHIAaQBlAC8AcwB5AG4AZQAtAHQAeQBwAGUAZgBhAGMAZQApAFMAeQBuAGUAIABFAHgAdAByAGEAQgBvAGwAZABSAGUAZwB1AGwAYQByADIALgAyADAAMAA7AE4ATwBOAEUAOwBTAHkAbgBlAC0ARQB4AHQAcgBhAEIAbwBsAGQAUwB5AG4AZQAgAEUAeAB0AHIAYQBCAG8AbABkAFYAZQByAHMAaQBvAG4AIAAyAC4AMgAwADAAOwAgAHQAdABmAGEAdQB0AG8AaABpAG4AdAAgACgAdgAxAC4AOAAuADQAKQBTAHkAbgBlAC0ARQB4AHQAcgBhAEIAbwBsAGQAQgBvAG4AagBvAHUAcgAgAE0AbwBuAGQAZQBMAHUAYwBhAHMAIABEAGUAcwBjAHIAbwBpAHgAaAB0AHQAcABzADoALwAvAGIAbwBuAGoAbwB1AHIAbQBvAG4AZABlAC4AbgBlAHQAaAB0AHQAcABzADoALwAvAHcAdwB3AC4AbAB1AGMAYQBzAGQAZQBzAGMAcgBvAGkAeAAuAGYAcgBUAGgAaQBzACAARgBvAG4AdAAgAFMAbwBmAHQAdwBhAHIAZQAgAGkAcwAgAGwAaQBjAGUAbgBzAGUAZAAgAHUAbgBkAGUAcgAgAHQAaABlACAAUwBJAEwAIABPAHAAZQBuACAARgBvAG4AdAAgAEwAaQBjAGUAbgBzAGUALAAgAFYAZQByAHMAaQBvAG4AIAAxAC4AMQAuACAAVABoAGkAcwAgAGwAaQBjAGUAbgBzAGUAIABpAHMAIABhAHYAYQBpAGwAYQBiAGwAZQAgAHcAaQB0AGgAIABhACAARgBBAFEAIABhAHQAOgAgAGgAdAB0AHAAcwA6AC8ALwBzAGMAcgBpAHAAdABzAC4AcwBpAGwALgBvAHIAZwAvAE8ARgBMAGgAdAB0AHAAcwA6AC8ALwBzAGMAcgBpAHAAdABzAC4AcwBpAGwALgBvAHIAZwAvAE8ARgBMAFMAeQBuAGUARQB4AHQAcgBhAEIAbwBsAGQAQQBtAHAAZQByAHMAYQBuAGQAYQB0AEEAYwBjAGUAbgB0AHMAZwAgAGQAbwB1AGIAbABlACAAcwB0AG8AcgBlAHkAZQBwAHMAaQBsAG8AbgAAAAIAAAAAAAD/agBLAAAAAAAAAAAAAAAAAAAAAAAAAAACxwAAACQAyQECAMcAYgCtAQMBBABjAK4AkAAlACYA/QD/AGQBBQAnAOkBBgEHACgAZQEIAMgAygEJAMsBCgELACkAKgD4AQwBDQArAQ4ALAEPAMwAzQDOAPoAzwEQAREALQAuARIALwETARQBFQEWAOIAMAAxARcBGAEZAGYBGgAyANAA0QBnARsA0wEcAR0AkQCvALAAMwDtADQANQEeAR8BIAA2ASEA5AD7ASIANwEjASQBJQEmADgA1ADVAGgA1gEnASgBKQEqADkAOgErASwBLQEuADsAPADrAS8AuwEwAD0BMQDmATIBMwE0ATUBNgE3ATgBOQE6ATsBPAE9AT4BPwFAAUEBQgFDAUQBRQFGAUcBSAFJAUoBSwFMAU0BTgFPAVABUQFSAVMBVAFVAVYBVwFYAVkBWgFbAVwBXQFeAV8BYAFhAWIBYwFkAWUBZgFnAWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQBEAGkBdgBrAGwAagF3AXgAbgBtAKAARQBGAP4BAABvAXkARwDqAXoBAQBIAHABewByAHMBfABxAX0BfgBJAEoA+QF/AYAASwGBAEwA1wB0AHYAdwGCAHUBgwGEAYUATQBOAYYATwGHAYgBiQGKAOMAUABRAYsBjAGNAHgBjgBSAHkAewB8AHoBjwGQAKEAfQCxAFMA7gBUAFUBkQGSAZMAVgGUAOUA/AGVAIkAVwGWAZcBmAGZAFgAfgCAAIEAfwGaAZsBnAGdAFkAWgGeAZ8BoAGhAFsAXADsAaIAugGjAF0BpADnAaUBpgGnAagBqQGqAasBrAGtAa4BrwGwAbEBsgGzAbQBtQG2AbcBuAG5AboBuwG8Ab0BvgG/AcABwQHCAcMBxAHFAcYBxwHIAckBygHLAcwBzQHOAc8B0AHRAdIB0wHUAdUB1gHXAdgB2QHaAdsB3AHdAd4B3wHgAeEB4gHjAeQB5QHmAecB6AHpAeoB6wDAAewB7QCdAJ4B7gHvAfAB8QHyAfMB9AH1AfYB9wH4AfkB+gH7AfwB/QH+Af8CAAIBAgICAwIEAgUCBgIHAggCCQIKAgsCDAINAg4CDwIQAhECEgITAhQCFQIWAhcCGAIZAhoCGwIcAh0AmwIeAh8CIAIhAiICIwIkAiUCJgInAigCKQIqAisCLAItAi4CLwIwAjECMgIzABMAFAAVABYAFwAYABkAGgAbABwCNAI1AjYCNwI4AjkCOgI7AjwCPQI+Aj8CQAJBAkICQwJEAkUCRgJHAkgCSQJKAksCTAJNAk4CTwJQAlECUgJTAlQCVQJWAlcCWAJZAloCWwJcAl0CXgJfAmACYQJiAmMCZAJlAmYCZwJoAmkCagJrAmwCbQJuAm8AvAD0AnACcQJyAPUA9gJzAnQCdQJ2AncCeAJ5AnoCewJ8An0CfgJ/AoACgQKCAoMChAKFAAMChgKHAogCiQARAA8AHQAeAKsABACjACIAogDDAIcADQAGABIAPwKKAosCjAKNABACjgCyALMAQgALAAwAXgBgAD4AQAKPApAAxADFALQAtQC2ALcAqQCqAL4AvwAFAAoApgKRACMACQCIAIYAiwCKAIwAgwBfAOgAggDCApICkwKUAIQAvQAHApUAhQCWApYADgDvAPAAuAAgAI8AIQAfAJUAlACTAKcAYQCkAEEClwCSAJwAmgCZAKUCmACYAAgAxgKZApoCmwKcAp0CngKfAqACoQKiALkCowKkAqUCpgKnAqgCqQKqAqsCrAKtAq4CrwKwArECsgKzArQCtQK2ArcCuAK5AroCuwK8Ar0CvgK/AsACwQLCAsMCxALFAsYAjgDcAEMAjQDfANgA4QDbAN0A2QDaAN4A4ALHAsgCyQLKAssCzALNAs4CzwLQAtEC0gZBYnJldmUHQW1hY3JvbgdBb2dvbmVrCkNkb3RhY2NlbnQGRGNhcm9uBkRjcm9hdAZFY2Fyb24KRWRvdGFjY2VudAdFbWFjcm9uB0VvZ29uZWsHdW5pMDEyMgpHZG90YWNjZW50BEhiYXICSUoHSW1hY3JvbgdJb2dvbmVrB3VuaTAxMzYGTGFjdXRlBkxjYXJvbgd1bmkwMTNCBExkb3QGTmFjdXRlBk5jYXJvbgd1bmkwMTQ1A0VuZwd1bmkwMjJFDU9odW5nYXJ1bWxhdXQHT21hY3JvbgZSYWN1dGUGUmNhcm9uB3VuaTAxNTYGU2FjdXRlB3VuaTAyMTgEVGJhcgZUY2Fyb24HdW5pMDE2Mgd1bmkwMjFBDVVodW5nYXJ1bWxhdXQHVW1hY3JvbgdVb2dvbmVrBVVyaW5nBldhY3V0ZQtXY2lyY3VtZmxleAlXZGllcmVzaXMGV2dyYXZlC1ljaXJjdW1mbGV4BllncmF2ZQZaYWN1dGUKWmRvdGFjY2VudAtBYWN1dGUuc3MwMwtBYnJldmUuc3MwMxBBY2lyY3VtZmxleC5zczAzC0FncmF2ZS5zczAzDEFtYWNyb24uc3MwMwxBb2dvbmVrLnNzMDMKQXJpbmcuc3MwMwtBdGlsZGUuc3MwMwtDYWN1dGUuc3MwMwtDY2Fyb24uc3MwMw1DY2VkaWxsYS5zczAzD0Nkb3RhY2NlbnQuc3MwMwtEY2Fyb24uc3MwMwtFYWN1dGUuc3MwMwtFY2Fyb24uc3MwMxBFY2lyY3VtZmxleC5zczAzC0VncmF2ZS5zczAzDEVtYWNyb24uc3MwMwxFb2dvbmVrLnNzMDMLR2JyZXZlLnNzMDMMdW5pMDEyMi5zczAzD0dkb3RhY2NlbnQuc3MwMwtJYWN1dGUuc3MwMxBJY2lyY3VtZmxleC5zczAzC0lncmF2ZS5zczAzDEltYWNyb24uc3MwMwxJb2dvbmVrLnNzMDMMdW5pMDEzNi5zczAzC0xhY3V0ZS5zczAzC0xjYXJvbi5zczAzDHVuaTAxM0Iuc3MwMwtOYWN1dGUuc3MwMwtOY2Fyb24uc3MwMwx1bmkwMTQ1LnNzMDMLTnRpbGRlLnNzMDMLT2FjdXRlLnNzMDMQT2NpcmN1bWZsZXguc3MwMwtPZ3JhdmUuc3MwMxJPaHVuZ2FydW1sYXV0LnNzMDMMT21hY3Jvbi5zczAzC090aWxkZS5zczAzC1JhY3V0ZS5zczAzC1JjYXJvbi5zczAzDHVuaTAxNTYuc3MwMwtTYWN1dGUuc3MwMwtTY2Fyb24uc3MwMw1TY2VkaWxsYS5zczAzDHVuaTAyMTguc3MwMwtUY2Fyb24uc3MwMwx1bmkwMTYyLnNzMDMMdW5pMDIxQS5zczAzC1VhY3V0ZS5zczAzEFVjaXJjdW1mbGV4LnNzMDMLVWdyYXZlLnNzMDMSVWh1bmdhcnVtbGF1dC5zczAzDFVtYWNyb24uc3MwMwxVb2dvbmVrLnNzMDMKVXJpbmcuc3MwMwtXYWN1dGUuc3MwMxBXY2lyY3VtZmxleC5zczAzC1dncmF2ZS5zczAzC1lhY3V0ZS5zczAzEFljaXJjdW1mbGV4LnNzMDMLWWdyYXZlLnNzMDMLWmFjdXRlLnNzMDMLWmNhcm9uLnNzMDMDVF9oBmFicmV2ZQdhbWFjcm9uB2FvZ29uZWsKY2RvdGFjY2VudAZkY2Fyb24GZWNhcm9uCmVkb3RhY2NlbnQHZW1hY3Jvbgdlb2dvbmVrB3VuaTAxMjMKZ2RvdGFjY2VudARoYmFyCWkubG9jbFRSSwJpagdpbWFjcm9uB2lvZ29uZWsHdW5pMDEzNwZsYWN1dGUGbGNhcm9uB3VuaTAxM0MEbGRvdAZuYWN1dGUGbmNhcm9uB3VuaTAxNDYDZW5nDW9odW5nYXJ1bWxhdXQHb21hY3JvbgZyYWN1dGUGcmNhcm9uB3VuaTAxNTcGc2FjdXRlB3VuaTAyMTkEdGJhcgZ0Y2Fyb24HdW5pMDE2Mwd1bmkwMjFCDXVodW5nYXJ1bWxhdXQHdW1hY3Jvbgd1b2dvbmVrBXVyaW5nBndhY3V0ZQt3Y2lyY3VtZmxleAl3ZGllcmVzaXMGd2dyYXZlC3ljaXJjdW1mbGV4BnlncmF2ZQZ6YWN1dGUKemRvdGFjY2VudAthYWN1dGUuc3MwMwthYnJldmUuc3MwMxBhY2lyY3VtZmxleC5zczAzC2FncmF2ZS5zczAzDGFtYWNyb24uc3MwMwxhb2dvbmVrLnNzMDMKYXJpbmcuc3MwMwthdGlsZGUuc3MwMwtjYWN1dGUuc3MwMwtjY2Fyb24uc3MwMw1jY2VkaWxsYS5zczAzC2RjYXJvbi5zczAzC2VhY3V0ZS5zczAzC2VjYXJvbi5zczAzEGVjaXJjdW1mbGV4LnNzMDMLZWdyYXZlLnNzMDMMZW1hY3Jvbi5zczAzDGVvZ29uZWsuc3MwMwtnYnJldmUuc3MwMwx1bmkwMTIzLnNzMDMLaWFjdXRlLnNzMDMQaWNpcmN1bWZsZXguc3MwMwtpZ3JhdmUuc3MwMwxpbWFjcm9uLnNzMDMMaW9nb25lay5zczAzDHVuaTAxMzcuc3MwMwtsYWN1dGUuc3MwMwtsY2Fyb24uc3MwMwx1bmkwMTNDLnNzMDMLbmFjdXRlLnNzMDMLbmNhcm9uLnNzMDMMdW5pMDE0Ni5zczAzC250aWxkZS5zczAzC29hY3V0ZS5zczAzEG9jaXJjdW1mbGV4LnNzMDMLb2dyYXZlLnNzMDMSb2h1bmdhcnVtbGF1dC5zczAzDG9tYWNyb24uc3MwMwtvdGlsZGUuc3MwMwtyYWN1dGUuc3MwMwtyY2Fyb24uc3MwMwx1bmkwMTU3LnNzMDMLc2FjdXRlLnNzMDMLc2Nhcm9uLnNzMDMNc2NlZGlsbGEuc3MwMwx1bmkwMjE5LnNzMDMLdGNhcm9uLnNzMDMMdW5pMDE2My5zczAzDHVuaTAyMUIuc3MwMwt1YWN1dGUuc3MwMxB1Y2lyY3VtZmxleC5zczAzC3VncmF2ZS5zczAzEnVodW5nYXJ1bWxhdXQuc3MwMwx1bWFjcm9uLnNzMDMMdW9nb25lay5zczAzCnVyaW5nLnNzMDMLd2FjdXRlLnNzMDMQd2NpcmN1bWZsZXguc3MwMwt3Z3JhdmUuc3MwMwt5YWN1dGUuc3MwMxB5Y2lyY3VtZmxleC5zczAzC3lncmF2ZS5zczAzC3phY3V0ZS5zczAzC3pjYXJvbi5zczAzBmcuc3MwNAtnYnJldmUuc3MwNAx1bmkwMTIzLnNzMDQPZ2RvdGFjY2VudC5zczA0A2ZfZgVmX2ZfaQN0X2kDdF95BUFscGhhBEJldGEFR2FtbWEHdW5pMDM5NAdFcHNpbG9uBFpldGEDRXRhBVRoZXRhBElvdGEFS2FwcGEGTGFtYmRhAk11Ak51AlhpB09taWNyb24CUGkDUmhvBVNpZ21hA1RhdQdVcHNpbG9uA1BoaQNDaGkDUHNpB3VuaTAzQTkKQWxwaGF0b25vcwxFcHNpbG9udG9ub3MIRXRhdG9ub3MJSW90YXRvbm9zDE9taWNyb250b25vcwxVcHNpbG9udG9ub3MKT21lZ2F0b25vcwxJb3RhZGllcmVzaXMPVXBzaWxvbmRpZXJlc2lzBWFscGhhBGJldGEFZ2FtbWEFZGVsdGEHZXBzaWxvbgR6ZXRhA2V0YQV0aGV0YQRpb3RhBWthcHBhBmxhbWJkYQd1bmkwM0JDAm51AnhpB29taWNyb24DcmhvB3VuaTAzQzIFc2lnbWEDdGF1B3Vwc2lsb24DcGhpA2NoaQNwc2kFb21lZ2EJaW90YXRvbm9zDGlvdGFkaWVyZXNpcxFpb3RhZGllcmVzaXN0b25vcwx1cHNpbG9udG9ub3MPdXBzaWxvbmRpZXJlc2lzFHVwc2lsb25kaWVyZXNpc3Rvbm9zDG9taWNyb250b25vcwpvbWVnYXRvbm9zCmFscGhhdG9ub3MMZXBzaWxvbnRvbm9zCGV0YXRvbm9zDGVwc2lsb24uc3MwNRFlcHNpbG9udG9ub3Muc3MwNQd6ZXJvLmxmBm9uZS5sZgZ0d28ubGYIdGhyZWUubGYHZm91ci5sZgdmaXZlLmxmBnNpeC5sZghzZXZlbi5sZghlaWdodC5sZgduaW5lLmxmCHplcm8ub3NmB29uZS5vc2YHdHdvLm9zZgl0aHJlZS5vc2YIZm91ci5vc2YIZml2ZS5vc2YHc2l4Lm9zZglzZXZlbi5vc2YJZWlnaHQub3NmCG5pbmUub3NmB3plcm8udGYGb25lLnRmBnR3by50Zgh0aHJlZS50Zgdmb3VyLnRmB2ZpdmUudGYGc2l4LnRmCHNldmVuLnRmCGVpZ2h0LnRmB25pbmUudGYJemVyby50b3NmCG9uZS50b3NmCHR3by50b3NmCnRocmVlLnRvc2YJZm91ci50b3NmCWZpdmUudG9zZghzaXgudG9zZgpzZXZlbi50b3NmCmVpZ2h0LnRvc2YJbmluZS50b3NmCXplcm8uZG5vbQhvbmUuZG5vbQh0d28uZG5vbQp0aHJlZS5kbm9tCWZvdXIuZG5vbQlmaXZlLmRub20Ic2l4LmRub20Kc2V2ZW4uZG5vbQplaWdodC5kbm9tCW5pbmUuZG5vbQl6ZXJvLm51bXIIb25lLm51bXIIdHdvLm51bXIKdGhyZWUubnVtcglmb3VyLm51bXIJZml2ZS5udW1yCHNpeC5udW1yCnNldmVuLm51bXIKZWlnaHQubnVtcgluaW5lLm51bXIHdW5pMjE4OQd1bmkyMTUzB3VuaTIxNTQHdW5pMjE1NQd1bmkyMTU2B3VuaTIxNTcHdW5pMjE1OAd1bmkyMTU5B3VuaTIxNUEHdW5pMjE1MAlvbmVlaWdodGgMdGhyZWVlaWdodGhzC2ZpdmVlaWdodGhzDHNldmVuZWlnaHRocwd1bmkyMTUxB3VuaTIxNTIMZnJhY3Rpb24uMDAxB3VuaTAwQjkHdW5pMDBCMgd1bmkwMEIzB3VuaTIwNzQCQ1IHdW5pMDBBMAlhbm90ZWxlaWEHdW5pMDM3RQ9leGNsYW1fcXVlc3Rpb24LZXhjbGFtLmNhc2UPZXhjbGFtZG93bi5jYXNlDXF1ZXN0aW9uLmNhc2URcXVlc3Rpb25kb3duLmNhc2UHdW5pMDBBRA5wYXJlbmxlZnQuY2FzZQ9wYXJlbnJpZ2h0LmNhc2UHdW5pRjhGRg5hbXBlcnNhbmQuY2FzZQ5hbXBlcnNhbmQuc3MwMQdhdC5zczAyBEV1cm8HdW5pMjIxNQhlbXB0eXNldAd1bmkwMEI1B2Fycm93dXAHdW5pMjE5NwphcnJvd3JpZ2h0B3VuaTIxOTgJYXJyb3dkb3duB3VuaTIxOTkJYXJyb3dsZWZ0B3VuaTIxOTYJYXJyb3dib3RoCWFycm93dXBkbgV0b25vcw1kaWVyZXNpc3Rvbm9zB3VuaTAzMDgHdW5pMDMwNwlncmF2ZWNvbWIJYWN1dGVjb21iB3VuaTAzMEILdW5pMDMwQy5hbHQHdW5pMDMwMgd1bmkwMzBDB3VuaTAzMDYHdW5pMDMwQQl0aWxkZWNvbWIHdW5pMDMwNAd1bmkwMzEyB3VuaTAzMjYHdW5pMDMyNwd1bmkwMzI4B3VuaTAzMzUHdW5pMDMzNgd1bmkwMzM3B3VuaTAzMzgO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AAAZRAAAGQgAABkOAAAZFAABFa4AABkaAAAZGgAAGSAAABkmAAAZLAAAGTIAABlKAAIAigACAJAAAwCWAAQAnAAEAKIABACoAAQArgAAGUQAABlEAAAZOAABALQAABlEAAAZPgAAGUQAABlEAAAZRAAAGUQAABlKAAIAugACAMAAAwDAAAEAmAAAAAEBiAAAAAEBeQAAAAEBCQGDAAEA3AGKAAEA8wGOAAEBBwFmAAEALQHqAAEAXAAAAAEAkwAAAZ8RygAAFagVrgAAEDgAABWoFa4AABA+AAAVqBWuAAAQRAAAFagVrgAAEcoAABWoFa4AABBKAAAVqBWuAAAQUAAAFagVrgAAEcoAABWoFa4AABBWAAAVqBWuAAAQXAAAFagVrgAAEGIAABBoEG4AABW0AAAVugAAAAAR0BHcEeIR6BHuEHQR3BHiEegR7hB6EdwR4hHoEe4R0BHcEeIR6BHuEdYR3BHiEegR7hH0AAAR+gAAEgAR9AAAEfoAABIAEIAAABH6AAASABH0AAAR+gAAEgASBgAAFcAVxgAAEIYAABXAFcYAABCMAAAVwBXGAAAQjAAAFcAVxgAAEJIAABXAFcYAABCSAAAVwBXGAAAQmAAAFcAVxgAAEJ4AABXAFcYAABIGAAAVwBXGAAAQpAAAEqgAAAAAEhISHhIkEioSMBCqEh4SJBIqEjASEhIeEiQSKhIwEhgSHhIkEioSMBCwAAAVzAAAFdIQtgAAELwAABIwEjYAABaeFqQAABDCAAAQyBDOAAAQ1AAAFp4WpAAAENoAABaeFqQAABaYAAAWnhakAAAWmAAAFp4WpAAAEOAAABaeFqQAABDmAAAWnhakAAASNgAAFp4WpAAAEOwAABDyAAAAABXeAAAV5AAAAAAV3gAAFeQAAAAAEjwSQhJIAAASThD4EkISSAAAEk4SPBJCEkgAABJOEjwSQhJIAAASThI8EkISSAAAEk4SPBJCEkgAABJOFeoAABXwAAAAABX2AAAV/AAAAAAQ/gAAFfwAAAAAEQQAABX8AAAAABX2AAAV/AAAAAARCgAAFfwAAAAAFfYAABX8AAAAABJUFgIWCBYOFhQREBYCFggWDhYUERYWAhYIFg4WFBJUFgIWCBYOFhQRHBYCFggWDhYUESIWAhYIFg4WFBEoFgIWCBYOFhQRLhYCFggWDhYUElQWAhYIFg4WFBE0FgIWCBYOFhQSVBYCFggWDhYUFhoAABYgAAAAABE6AAARQAAAAAARRhYCFggWDhYUEloAABJgAAAAABFMAAASYAAAAAARUgAAEmAAAAAAEloAABJgAAAAABJmAAASbAAAAAARWAAAEmwAAAAAEV4AABJsAAAAABJmAAASbAAAAAASZgAAEmwAAAAAFiYAABYsAAAWMhYmAAAWLAAAFjIRZAAAFiwAABYyFiYAABYsAAAWMhYmAAAWLAAAFjISeBJ+EoQSigAAEWoSfhKEEooAABFwEn4ShBKKAAASchJ+EoQSigAAEXYSfhKEEooAABF8En4ShBKKAAARghJ+EoQSigAAEngSfhKEEooAABGIEn4ShBKKAAARjgAAFagAAAAAEpAAABKWAAAAABGUAAASlgAAAAARmgAAEpYAAAAAEpAAABKWAAAAABGgAAASlgAAAAAWPgAAFkQAAAAAEpwAABawAAAAABGmAAAWsAAAAAARrAAAFrAAAAAAFqoAABawAAAAABGyAAAWsAAAAAASogAAEqgAAAAAEbgAABKoAAAAABG+AAASqAAAAAARxAAAEqgAAAAAEcoAABWoFa4AABHKAAAVqBWuAAARygAAFagVrgAAEcoAABWoFa4AABHKAAAVqBWuAAARygAAFagVrgAAEcoAABWoFa4AABHKAAAVqBWuAAAR0BHcEeIR6BHuEdAR3BHiEegR7hHQEdwR4hHoEe4R1hHcEeIR6BHuEfQAABH6AAASABIGAAAVwBXGAAASBgAAFcAVxgAAEgYAABXAFcYAABIGAAAVwBXGAAASBgAAFcAVxgAAEgwAABXAFcYAABISEh4SJBIqEjASEhIeEiQSKhIwEhgSHhIkEioSMBI2AAAWnhakAAASNgAAFp4WpAAAEjYAABaeFqQAABI2AAAWnhakAAASNgAAFp4WpAAAFd4AABXkAAAAABI8EkISSAAAEk4SPBJCEkgAABJOEjwSQhJIAAASThX2AAAV/AAAAAAV9gAAFfwAAAAAFfYAABX8AAAAABX2AAAV/AAAAAASVBYCFggWDhYUElQWAhYIFg4WFBJUFgIWCBYOFhQSVBYCFggWDhYUElQWAhYIFg4WFBJUFgIWCBYOFhQSWgAAEmAAAAAAEloAABJgAAAAABJaAAASYAAAAAASZgAAEmwAAAAAEmYAABJsAAAAABJmAAASbAAAAAASZgAAEmwAAAAAFiYAABYsAAAWMhYmAAAWLAAAFjIWJgAAFiwAABYyEngSfhKEEooAABJ4En4ShBKKAAASeBJ+EoQSigAAEnISfhKEEooAABJ4En4ShBKKAAASeBJ+EoQSigAAEngSfhKEEooAABKQAAASlgAAAAASkAAAEpYAAAAAEpAAABKWAAAAABKcAAAWsAAAAAASnAAAFrAAAAAAEpwAABawAAAAABKiAAASqAAAAAASogAAEqgAAAAAFHYUfBSCFIgUjhKuFHwUghSIFI4StBR8FIIUiBSOEroUfBSCFIgUjhLAFHwUghSIFI4SxhR8FIIUiBSOEswUfBSCFIgUjhR2FHwUghSIFI4S0hR8FIIUiBSOEtgUfBSCFIgUjhLeFHwS5BLqFI4S8AAAEvYS/BMCFvgXBBcKFxAXFhMIFwQXChcQFxYTDhcEFwoXEBcWFvgXBBcKFxAXFhMUFwQXChcQFxYVYBSUFJoUoBSmFWAUlBSaFKAUphVgFJQUmhSgFKYVMAAAFKwUsgAAE/4AABSsFLIAABQEAAAUrBSyAAAUBAAAFKwUsgAAFAoAABSsFLIAABQKAAAUrBSyAAAUEAAAFKwUsgAAFBwAABSsFLIAABUwAAAUrBSyAAATGgAAEyAAAAAAGIQVchV4FX4VhBVmFXIVeBV+FYQYhBVyFXgVfhWEFWwVchV4FX4VhBMmAAATLAAAEzITJgAAEywAABMyFMoAABTQFNYAABS4AAAUvhTEAAATOAAAFL4UxAAAEz4AABS+FMQAABS4AAAUvhTEAAATRAAAFL4UxAAAE0oAABS+FMQAABTKAAAU0BTWAAATUAAAFL4UxAAAFMoAABTQFNYAABa2AAAU3AAAAAAWtgAAFNwAAAAAFOIU6BTuAAAU9BNWFOgU7gAAFPQU4hToFO4AABT0FOIU6BTuAAAU9BTiFOgU7gAAFPQTXBNiE2gAABNuE3QAABN6AAAAABbyAAAU+gAAAAATgAAAFPoAAAAAE4YAABT6AAAAABbyAAAU+gAAAAATjAAAFPoAAAAAFvIAABT6AAAAABccFyIXKBcuFzQTkhciFygXLhc0E5gXIhcoFy4XNBOeFyIXKBcuFzQTpBciFygXLhc0E6oXIhcoFy4XNBOwFyIXKBcuFzQXHBciFygXLhc0E7YXIhco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AHYAdwB4AHkAegB7AHwAfQB+AH8AgACBAIIAgwCEAIUAhgCHAIgAiQCKAIsAjACNAI4AjwCQAJEAkgCTAJQAlQCWAJcAmACZAJoAmwCcAJ0AngCfAKAAoQCiAKMApAClAKYApwCoAKkAqgCrAKwArQCuAK8AsACxALIAswC0ALUBKwEsAS0BLgEvATABMQEyATMBNAE1ATYBNwE4ATkBOgE7ATwBPQE+AT8BQAFBAUIBQwFEAUUBRgFHAUgBSQFKAUsBTAFNAU4BTwFQAVEBUgFTAVQBVQFWAVcBWAFZAVoBWwFcAV0BXgFfAWABYQFiAWMBZAFlAWYBZwFoAWkBagKgAqECogKjAqQCpQKmAqcCqAKpAqoCqwKsAq0CuwK8Ar0CvgK/AsACwQLCAsMCxALFAAEAmwACAAMABAAGAAcACAAJAAoADgAPABAAEQAUABcAGAAZABwAHQAeACEAIgAjACgAKQAsAC0ALgAxADMANAA1ADoAOwA8AD0AQABBAEQARQBGAEgATgBPAFAAUgBTAFQAVQBYAFkAWgBcAF0AXwBgAGEAYgBjAGYAZwBpAGwAbQBvAHEAcgC4ALkAugC8AL0AvgC/AMAAxADFAMYAygDNAM4AzwDSANMA1ADXANgA3gDfAOIA5ADlAOgA6gDrAOwA8QDyAPMA9AD3APgA+gD7APwA/gEEAQUBBgEIAQkBCgELAQ8BEAERARMBFAEWARcBGAEZARoBHQEeASABIwEkASYBKAEpAo4CjwKQApECkgKTApQClQKWApcCmAKZApoCmwKwArECsgKzArQCtQK2ArcCuAK5AroAAQAAAAEACAABAAYAlQACAAEA1gDZAAAAAQAAAAEACAACAAoAAgG7AbwAAQACAZsBuQAA
'@

try {
    $script:syneExtraBoldFontBytes = [Convert]::FromBase64String($script:syneExtraBoldFontBase64)
    $script:syneExtraBoldFontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $syneExtraBoldMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($script:syneExtraBoldFontBytes.Length)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy(
            $script:syneExtraBoldFontBytes,
            0,
            $syneExtraBoldMem,
            $script:syneExtraBoldFontBytes.Length
        )
        $script:syneExtraBoldFontCollection.AddMemoryFont($syneExtraBoldMem, $script:syneExtraBoldFontBytes.Length)
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($syneExtraBoldMem)
    }

    if ($script:syneExtraBoldFontCollection.Families.Count -gt 0) {
        $script:syneExtraBoldFontFamily = $script:syneExtraBoldFontCollection.Families[0]
    }
} catch {
    $script:syneExtraBoldFontFamily = $null
} finally {
    $script:syneExtraBoldFontBase64 = $null
    $script:syneExtraBoldFontBytes = $null
}


# -----------------------------------------------------------------------------
#  EMBEDDED PENNA FONT FOR HOME SCRIPT WORDMARK
#  SCRIPT uses the user-provided Penna face and is loaded privately from memory
#  so the UI does not depend on Penna being installed system-wide.
# -----------------------------------------------------------------------------
$script:pennaFontCollection = $null
$script:pennaFontFamily = $null
$script:pennaFontBytes = $null
$script:pennaFontBase64 = @'
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
'@

try {
    $script:pennaFontBytes = [Convert]::FromBase64String($script:pennaFontBase64)
    $script:pennaFontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $pennaMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($script:pennaFontBytes.Length)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy(
            $script:pennaFontBytes,
            0,
            $pennaMem,
            $script:pennaFontBytes.Length
        )
        $script:pennaFontCollection.AddMemoryFont($pennaMem, $script:pennaFontBytes.Length)
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($pennaMem)
    }

    if ($script:pennaFontCollection.Families.Count -gt 0) {
        $script:pennaFontFamily = $script:pennaFontCollection.Families[0]
    }
} catch {
    $script:pennaFontFamily = $null
} finally {
    $script:pennaFontBase64 = $null
    $script:pennaFontBytes = $null
}

# -----------------------------------------------------------------------------
#  KEY PAGE FONT - FC FRIDAY MEDIUM
#  Embedded directly so the whole Key page uses the supplied typeface.
# -----------------------------------------------------------------------------
$script:keyFcFridayFontFamily = $null
$script:keyFcFridayFontCollection = $null
$script:keyFcFridayFontBase64 = @'
AAEAAAATAQAABAAwR0RFRgdNC/8AAAE8AAAAVEdQT1PsxMyLAAABkAAAEtJHU1VCmia9UAAAFGQAACWST1MvMle5KyoAADn4AAAAYFBDTFRDktUlAAA6WAAAADZjbWFwr4VBYQAAOpAAAAaGY3Z0IB6mCEMAASSoAAAAhGZwZ209HI58AAElLAAADW1nYXNwAAAAEAABJKAAAAAIZ2x5Zn2Kbj0AAEEYAACpImhlYWQWrY2ZAADqPAAAADZoaGVhBCkDbAAA6nQAAAAkaG10eA+B3sQAAOqYAAAH+Gtlcm6qXq8iAADykAAAGaRsb2Nh4KmygAABDDQAAAP+bWF4cARED1EAARA0AAAAIG5hbWV2wmsXAAEQVAAAB0Jwb3N0h9CeBAABF5gAAA0HcHJlcDaX5moAATKcAAAAowABAAAADAAAABwAAAACAAIBcwF0AAIB8gHzAAIADAAEABgAIAAoADAAAQAEAXMBdAHyAfMAAQAEAAEBEAABAAQAAQDLAAEABAABAWMAAQAEAAEBiAABAAAACgBUAIYABERGTFQAGmdyZWsAJmxhdG4AMnRoYWkAPgAEAAAAAP//AAEAAAAEAAAAAP//AAEAAQAEAAAAAP//AAEAAgAEAAAAAP//AAEAAwAEa2VybgAaa2VybgAga2VybgAma2VybgAsAAAAAQAAAAAAAQAAAAAAAQAAAAAAAQAAAAEABAACAAAAAQAIAAER2gAEAAAAMQBsAH4AhACyAMQAzgDYASoBUAFuAXQBrgG4AdYB4AICAiACLgI4AlICXAKCAqQCqgLEAwoDUAOWA9wEIgRoBg4HtAf6CEAIhgjMCRIJWAmeCeQKKgpwCrYK/AyiDkgP7hGUAAQANf/EADf/vwA4/84AOv+1AAEAIv/EAAsAQv/xAET/8QBF//EARv/xAEj/8QBQ//EAUv/xAFT/8QBV//YAV//sAFr/7AAEADX/xAA3/8QAOP/OADr/xAACADf/5wA5/9gAAgAi/84AK/+6ABQAIv/EACv/xABC/84ARP/OAEX/zgBG/84ASP/OAE7/7ABP/+wAUP/OAFH/7ABS/84AU//sAFT/zgBW/+wAV//sAFj/7ABZ/+wAWv/sAFv/7AAJACL/vwAr/8QAMP/nAET/4gBG/+IASP/iAFD/4gBS/+IAVP/iAAcAIv/OAET/4gBG/+IASP/iAFD/4gBS/+IAVP/iAAEAMP/YAA4AIv+1AEL/zgBE/84ARf/OAEb/zgBI/84ATv/sAE//7ABQ/84AUf/sAFL/zgBT/+wAVP/OAFb/7AACAFP//ABZ//YABwBC//sARf/7AEb/+wBI//wAUP/7AFL/+wBU//sAAgBX/+wAWf/xAAgAQv/dAET/3QBF/90ARv/dAEj/3QBQ/90AUv/dAFT/5wAHAEL/5wBF/+cARv/qAEj/8ABQ/+cAUv/nAFT/8QADAFf/4gBY//EAWf/nAAIAV//sAFn/9gAGAEL/7ABE/+wARv/sAEj/7ABQ/+wAUv/sAAIARP/9AFn/9AAJAEL/+wBE//sARf/7AEb/+wBJAAMAUP/8AFL/+wBX//sAWP/8AAgAQv/sAET/7ABF/+wARv/iAEj/7ABQ/+IAUv/sAFT/7AABAFD/8QAGAEL/8QBE//EARv/xAFD/5wBS//EAVP/0ABEANf/YADf/zgA4/9MAOv/YAFr/8QCf/9gAv//xAMH/8QDJ/9gByP/YAcn/8QHK/9gBy//xAcz/2AHN//EBzv/YAc//8QARADX/2AA3/84AOP/TADr/2ABa//EAn//YAL//8QDB//EAyf/YAcj/2AHJ//EByv/YAcv/8QHM/9gBzf/xAc7/2AHP//EAEQA1/9gAN//OADj/0wA6/9gAWv/xAJ//2AC///EAwf/xAMn/2AHI/9gByf/xAcr/2AHL//EBzP/YAc3/8QHO/9gBz//xABEANf/YADf/zgA4/9MAOv/YAFr/8QCf/9gAv//xAMH/8QDJ/9gByP/YAcn/8QHK/9gBy//xAcz/2AHN//EBzv/YAc//8QARADX/2AA3/84AOP/TADr/2ABa//EAn//YAL//8QDB//EAyf/YAcj/2AHJ//EByv/YAcv/8QHM/9gBzf/xAc7/2AHP//EAEQA1/9gAN//OADj/0wA6/9gAWv/xAJ//2AC///EAwf/xAMn/2AHI/9gByf/xAcr/2AHL//EBzP/YAc3/8QHO/9gBz//xAGkAIv/YAEL/7ABE/+cARv/nAEj/5wBO/+wAT//sAFD/5wBR/+wAUv/nAFP/7ABU/+cAVv/sAIL/2ACD/9gAhP/YAIX/2ACG/9gAh//YAKL/7ACj/+wApP/sAKX/7ACm/+wAp//sAKj/7ACp/+cAqv/nAKv/5wCs/+cArf/nALL/5wCz/+wAtP/nALX/5wC2/+cAt//nALj/5wC6/+cAu//sALz/7AC9/+wAvv/sAMb/5wDI/+cBdv/YAXf/7AF4/9gBef/sAXr/2AF7/+wBfP/YAX3/7AF+/9gBf//sAYD/2AGB/+wBgv/YAYP/7AGE/9gBhf/sAYb/2AGH/+wBiP/YAYn/7AGK/9gBi//sAYz/2AGN/+wBj//nAZH/5wGT/+cBlf/nAZf/5wGZ/+cBm//nAZ3/5wGj/+cBpf/nAaf/5wGp/+cBq//nAa3/5wGv/+cBsf/nAbP/5wG1/+cBt//nAbn/5wG7/+wBvf/sAb//7AHB/+wBw//sAcX/7AHH/+wB0v/YAdP/7AHV/+cB1//nAdv/5wHg/+cB4v/sAeT/5wHm/+wAaQAi/9gAQv/sAET/5wBG/+cASP/nAE7/7ABP/+wAUP/nAFH/7ABS/+cAU//sAFT/5wBW/+wAgv/YAIP/2ACE/9gAhf/YAIb/2ACH/9gAov/sAKP/7ACk/+wApf/sAKb/7ACn/+wAqP/sAKn/5wCq/+cAq//nAKz/5wCt/+cAsv/nALP/7AC0/+cAtf/nALb/5wC3/+cAuP/nALr/5wC7/+wAvP/sAL3/7AC+/+wAxv/nAMj/5wF2/9gBd//sAXj/2AF5/+wBev/YAXv/7AF8/9gBff/sAX7/2AF//+wBgP/YAYH/7AGC/9gBg//sAYT/2AGF/+wBhv/YAYf/7AGI/9gBif/sAYr/2AGL/+wBjP/YAY3/7AGP/+cBkf/nAZP/5wGV/+cBl//nAZn/5wGb/+cBnf/nAaP/5wGl/+cBp//nAan/5wGr/+cBrf/nAa//5wGx/+cBs//nAbX/5wG3/+cBuf/nAbv/7AG9/+wBv//sAcH/7AHD/+wBxf/sAcf/7AHS/9gB0//sAdX/5wHX/+cB2//nAeD/5wHi/+wB5P/nAeb/7AARADX/2AA3/84AOP/TADr/2ABa//EAn//YAL//8QDB//EAyf/YAcj/2AHJ//EByv/YAcv/8QHM/9gBzf/xAc7/2AHP//EAEQA1/9gAN//OADj/0wA6/9gAWv/xAJ//2AC///EAwf/xAMn/2AHI/9gByf/xAcr/2AHL//EBzP/YAc3/8QHO/9gBz//xABEANf/YADf/zgA4/9MAOv/YAFr/8QCf/9gAv//xAMH/8QDJ/9gByP/YAcn/8QHK/9gBy//xAcz/2AHN//EBzv/YAc//8QARADX/2AA3/84AOP/TADr/2ABa//EAn//YAL//8QDB//EAyf/YAcj/2AHJ//EByv/YAcv/8QHM/9gBzf/xAc7/2AHP//EAEQA1/9gAN//OADj/0wA6/9gAWv/xAJ//2AC///EAwf/xAMn/2AHI/9gByf/xAcr/2AHL//EBzP/YAc3/8QHO/9gBz//xABEANf/YADf/zgA4/9MAOv/YAFr/8QCf/9gAv//xAMH/8QDJ/9gByP/YAcn/8QHK/9gBy//xAcz/2AHN//EBzv/YAc//8QARADX/2AA3/84AOP/TADr/2ABa//EAn//YAL//8QDB//EAyf/YAcj/2AHJ//EByv/YAcv/8QHM/9gBzf/xAc7/2AHP//EAEQA1/9gAN//OADj/0wA6/9gAWv/xAJ//2AC///EAwf/xAMn/2AHI/9gByf/xAcr/2AHL//EBzP/YAc3/8QHO/9gBz//xABEANf/YADf/zgA4/9MAOv/YAFr/8QCf/9gAv//xAMH/8QDJ/9gByP/YAcn/8QHK/9gBy//xAcz/2AHN//EBzv/YAc//8QARADX/2AA3/84AOP/TADr/2ABa//EAn//YAL//8QDB//EAyf/YAcj/2AHJ//EByv/YAcv/8QHM/9gBzf/xAc7/2AHP//EAEQA1/9gAN//OADj/0wA6/9gAWv/xAJ//2AC///EAwf/xAMn/2AHI/9gByf/xAcr/2AHL//EBzP/YAc3/8QHO/9gBz//xABEANf/YADf/zgA4/9MAOv/YAFr/8QCf/9gAv//xAMH/8QDJ/9gByP/YAcn/8QHK/9gBy//xAcz/2AHN//EBzv/YAc//8QBpACL/2ABC/+wARP/nAEb/5wBI/+cATv/sAE//7ABQ/+cAUf/sAFL/5wBT/+wAVP/nAFb/7ACC/9gAg//YAIT/2ACF/9gAhv/YAIf/2ACi/+wAo//sAKT/7ACl/+wApv/sAKf/7ACo/+wAqf/nAKr/5wCr/+cArP/nAK3/5wCy/+cAs//sALT/5wC1/+cAtv/nALf/5wC4/+cAuv/nALv/7AC8/+wAvf/sAL7/7ADG/+cAyP/nAXb/2AF3/+wBeP/YAXn/7AF6/9gBe//sAXz/2AF9/+wBfv/YAX//7AGA/9gBgf/sAYL/2AGD/+wBhP/YAYX/7AGG/9gBh//sAYj/2AGJ/+wBiv/YAYv/7AGM/9gBjf/sAY//5wGR/+cBk//nAZX/5wGX/+cBmf/nAZv/5wGd/+cBo//nAaX/5wGn/+cBqf/nAav/5wGt/+cBr//nAbH/5wGz/+cBtf/nAbf/5wG5/+cBu//sAb3/7AG//+wBwf/sAcP/7AHF/+wBx//sAdL/2AHT/+wB1f/nAdf/5wHb/+cB4P/nAeL/7AHk/+cB5v/sAGkAIv/YAEL/7ABE/+cARv/nAEj/5wBO/+wAT//sAFD/5wBR/+wAUv/nAFP/7ABU/+cAVv/sAIL/2ACD/9gAhP/YAIX/2ACG/9gAh//YAKL/7ACj/+wApP/sAKX/7ACm/+wAp//sAKj/7ACp/+cAqv/nAKv/5wCs/+cArf/nALL/5wCz/+wAtP/nALX/5wC2/+cAt//nALj/5wC6/+cAu//sALz/7AC9/+wAvv/sAMb/5wDI/+cBdv/YAXf/7AF4/9gBef/sAXr/2AF7/+wBfP/YAX3/7AF+/9gBf//sAYD/2AGB/+wBgv/YAYP/7AGE/9gBhf/sAYb/2AGH/+wBiP/YAYn/7AGK/9gBi//sAYz/2AGN/+wBj//nAZH/5wGT/+cBlf/nAZf/5wGZ/+cBm//nAZ3/5wGj/+cBpf/nAaf/5wGp/+cBq//nAa3/5wGv/+cBsf/nAbP/5wG1/+cBt//nAbn/5wG7/+wBvf/sAb//7AHB/+wBw//sAcX/7AHH/+wB0v/YAdP/7AHV/+cB1//nAdv/5wHg/+cB4v/sAeT/5wHm/+wAaQAi/9gAQv/sAET/5wBG/+cASP/nAE7/7ABP/+wAUP/nAFH/7ABS/+cAU//sAFT/5wBW/+wAgv/YAIP/2ACE/9gAhf/YAIb/2ACH/9gAov/sAKP/7ACk/+wApf/sAKb/7ACn/+wAqP/sAKn/5wCq/+cAq//nAKz/5wCt/+cAsv/nALP/7AC0/+cAtf/nALb/5wC3/+cAuP/nALr/5wC7/+wAvP/sAL3/7AC+/+wAxv/nAMj/5wF2/9gBd//sAXj/2AF5/+wBev/YAXv/7AF8/9gBff/sAX7/2AF//+wBgP/YAYH/7AGC/9gBg//sAYT/2AGF/+wBhv/YAYf/7AGI/9gBif/sAYr/2AGL/+wBjP/YAY3/7AGP/+cBkf/nAZP/5wGV/+cBl//nAZn/5wGb/+cBnf/nAaP/5wGl/+cBp//nAan/5wGr/+cBrf/nAa//5wGx/+cBs//nAbX/5wG3/+cBuf/nAbv/7AG9/+wBv//sAcH/7AHD/+wBxf/sAcf/7AHS/9gB0//sAdX/5wHX/+cB2//nAeD/5wHi/+wB5P/nAeb/7ABpACL/2ABC/+wARP/nAEb/5wBI/+cATv/sAE//7ABQ/+cAUf/sAFL/5wBT/+wAVP/nAFb/7ACC/9gAg//YAIT/2ACF/9gAhv/YAIf/2ACi/+wAo//sAKT/7ACl/+wApv/sAKf/7ACo/+wAqf/nAKr/5wCr/+cArP/nAK3/5wCy/+cAs//sALT/5wC1/+cAtv/nALf/5wC4/+cAuv/nALv/7AC8/+wAvf/sAL7/7ADG/+cAyP/nAXb/2AF3/+wBeP/YAXn/7AF6/9gBe//sAXz/2AF9/+wBfv/YAX//7AGA/9gBgf/sAYL/2AGD/+wBhP/YAYX/7AGG/9gBh//sAYj/2AGJ/+wBiv/YAYv/7AGM/9gBjf/sAY//5wGR/+cBk//nAZX/5wGX/+cBmf/nAZv/5wGd/+cBo//nAaX/5wGn/+cBqf/nAav/5wGt/+cBr//nAbH/5wGz/+cBtf/nAbf/5wG5/+cBu//sAb3/7AG//+wBwf/sAcP/7AHF/+wBx//sAdL/2AHT/+wB1f/nAdf/5wHb/+cB4P/nAeL/7AHk/+cB5v/sABEANf/YADf/zgA4/9MAOv/YAFr/8QCf/9gAv//xAMH/8QDJ/9gByP/YAcn/8QHK/9gBy//xAcz/2AHN//EBzv/YAc//8QABADEAIgAnACwALQAwADEANQA3ADgAOQA6AEMARABGAEcATABQAFEAUwBUAFUAVwBYAFkAggCDAIQAhQCGAIcAnwDJAXYBeAF6AXwBfgGAAYIBhAGGAYgBigGMAcgBygHMAc4B0gAAAAEAAAAKAGwCzgAEREZMVAAaZ3JlawAsbGF0bgA+dGhhaQBQAAQAAAAA//8ABAAAAAQACAAMAAQAAAAA//8ABAABAAUACQANAAQAAAAA//8ABAACAAYACgAOAAQAAAAA//8ABAADAAcACwAPABBjY21wAGJjY21wAHJjY21wAIJjY21wAJJmcmFjAKJmcmFjAKhmcmFjAK5mcmFjALRsaWdhALpsaWdhAPBsaWdhASZsaWdhAVxybGlnAZJybGlnAcZybGlnAfpybGlnAi4AAAAGADIAMwA0ADUANgA3AAAABgAyADMANAA1ADYANwAAAAYAMgAzADQANQA2ADcAAAAGADIAMwA0ADUANgA3AAAAAQAAAAAAAQAAAAAAAQAAAAAAAQAAAAAAGQAZABoAGwAcAB0AHgAfACAAIQAiACMAJAAlACYAJwAoACkAKgArACwALQAuAC8AMAAxAAAAGQAZABoAGwAcAB0AHgAfACAAIQAiACMAJAAlACYAJwAoACkAKgArACwALQAuAC8AMAAxAAAAGQAZABoAGwAcAB0AHgAfACAAIQAiACMAJAAlACYAJwAoACkAKgArACwALQAuAC8AMAAxAAAAGQAZABoAGwAcAB0AHgAfACAAIQAiACMAJAAlACYAJwAoACkAKgArACwALQAuAC8AMAAxAAAAGAABAAIAAwAEAAUABgAHAAgACQAKAAsADAANAA4ADwAQABEAEgATABQAFQAWABcAGAAAABgAAQACAAMABAAFAAYABwAIAAkACgALAAwADQAOAA8AEAARABIAEwAUABUAFgAXABgAAAAYAAEAAgADAAQABQAGAAcACAAJAAoACwAMAA0ADgAPABAAEQASABMAFAAVABYAFwAYAAAAGAABAAIAAwAEAAUABgAHAAgACQAKAAsADAANAA4ADwAQABEAEgATABQAFQAWABcAGABCAIYAjgCWAJ4ApgCuALYAvgDGAM4A1gDeAOYA7gD4AQIBCgESARoBIgEqATIBOgFCAUoBUgFaAWIBagFyAXoBggGKAZIBmgGiAaoBsgG8AcYBzgHWAd4B5gHuAfYB/gIGAg4CFgIeAiYCLgI2Aj4CRgJOAlYCXgJmAm4CdgJ+AoYCjgKWAAQAAAABAhgABwAAAAECJAAHAAAAAQIkAAcAAAABAiQABwAAAAECJAAHAAAAAQIkAAcAAAABAiQABwAAAAECJAAHAAAAAQIkAAcAAAABAiQABwAAAAECJAAHAAAAAQIkAAcAAAABAiQABwAAAAICJAIsAAcAAAACAioCMgAHAAAAAQIwAAcAAAABAjAABwAAAAECMAAHAAAAAQIwAAcAAAABAjAABwAAAAECMAAHAAAAAQIwAAcAAAABAjAABwAAAAECMAAHAAAAAQIwAAcAAAABAjAABwAAAAECMAAHAAAAAQIwAAcAAAABAjAABwAAAAECMAAHAAAAAQIwAAcAAAABAjAABwAAAAECMAAHAAAAAQIwAAcAAAABAjAABwAAAAECMAAHAAAAAQIwAAcAAAACAjACOAAHAAAAAgI2Aj4ABwAAAAECPAAHAAAAAQI8AAcAAAABAjwABwAAAAECPAAHAAAAAQI8AAcAAAABAjwABwAAAAECPAAHAAAAAQI8AAcAAAABAjwABwAAAAECPAAHAAAAAQI8AAcAAAABAjwABwAAAAECPAAHAAAAAQI8AAcAAAABAjwABwAAAAECPAAHAAAAAQI8AAEAAAABAjwAAQAAAAECYgABAAAAAQJgAAEAAAABAnoAAQAAAAEClgABAAAAAQKsAAEAAAABAsQAAQAAAAECwgABAAAAAQLcAAEAAAABAvgAAQL2AAEACAABAAQAfwADABAAEwABAAQAAAOMAAEABAAAA6QAAQAGAAAD4AABAAYAAAP8AAEABgAABA4AAQAGAAAELAABAAYAAARUAAEABgAABHgAAQAGAAAEnAABAAYAAAS8AAEABgAABNYAAQAGAAAE8AABAAYAAAUKAAEABgAABSgAAQAGAAAFRgABAAYAAAVkAAEABgAABYIAAQAGAAAFngABAAYAAAW8AAEABgAABdIAAQAEAAAF7AABAAQAAAcCAAEABAAAB7wAAQAEAAAIGgABAAQAAAkwAAEABAAACeoAAQAEAAAKSAABAAQAAApgAAEABgAACpwAAQAGAAAKuAABAAYAAArKAAEABgAACugAAQAGAAALEAABAAYAAAs0AAEABgAAC1gAAQAGAAALeAABAAYAAAuSAAEABgAAC6wAAQAGAAALxgABAAYAAAvkAAEABgAADAIAAQAGAAAMIAABAAYAAAw+AAEABgAADFoAAQAGAAAMeAABAAYAAAyOAAEABAAADKgAAQAEAAANvgABAAQAAA54AAEABAAADtYAAQAEAAAP7AABAAQAABCmAAEABAAAEQQAAQAEAAARVgABAAQAABO4AAEABAAAFaIAAQAEAAAYBAABAAQAABnuAAEABAAAHFAAAgEQABQBZQFWAWYBVwFYAVkBWgFoAWABYQFiAWMBZAFnAXUBWwFcAV0BXgFfAAEBCv+5AAIBDgAOAGABbgFvAXABaQFqAWsBbAFtAWkBagFrAWwBbQACAQIADwENAQ4BDwH0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AAIB6QGiAAIB6gCUAAIB6wAFAAwAEgAYAB4AJAG8AAIB5wHhAAIB6ACcAAIB6QG6AAIB6gCbAAIB6wAFAAwAEgAYAB4AJAHMAAIB5wHOAAIB6ACfAAIB6QHKAAIB6gHIAAIB6wAFAAwAEgAYAB4AJAF5AAIB5wClAAIB6ACjAAIB6QF3AAIB6gCiAAIB6wABAAQB1QACAekABQAMABIAGAAeACQBkQACAecBkwACAegAqwACAekBjwACAeoAqgACAesABQAMABIAGAAeACQBnwACAecB3QACAegArwACAekBoQACAeoArgACAesAAQAEALMAAgHoAAUADAASABgAHgAkAaUAAgHnALcAAgHoALUAAgHpAaMAAgHqALQAAgHrAAUADAASABgAHgAkAb0AAgHnAeIAAgHoALwAAgHpAbsAAgHqALsAAgHrAAUADAASABgAHgAkAc0AAgHnAc8AAgHoAL8AAgHpAcsAAgHqAckAAgHrAAEAEAAiACQAJgAqAC8AMAA2ADoAQgBEAEYASgBPAFAAVgBaAAEB1gAMAB4AQABiAIQApgDIAOoBDAEuAVgBggGsAAQACgAQABYAHAF+AAIB5wGAAAIB6AF6AAIB6QF8AAIB6wAEAAoAEAAWABwBmAACAecBmgACAegBlAACAekBlgACAesABAAKABAAFgAcAaoAAgHnAawAAgHoAaYAAgHpAagAAgHrAAQACgAQABYAHAF/AAIB5wGBAAIB6AF7AAIB6QF9AAIB6wAEAAoAEAAWABwBmQACAecBmwACAegBlQACAekBlwACAesABAAKABAAFgAcAasAAgHnAa0AAgHoAacAAgHpAakAAgHrAAQACgAQABYAHAGIAAIB5wGKAAIB6AGEAAIB6QGGAAIB6wAEAAoAEAAWABwBiQACAecBiwACAegBhQACAekBhwACAesABQAMABIAGAAeACQBtAACAecBtgACAegBsAACAekBuAACAeoBsgACAesABQAMABIAGAAeACQBtQACAecBtwACAegBsQACAekBuQACAeoBswACAesABQAMABIAGAAeACQBwgACAecBxAACAegBvgACAekBxgACAeoBwAACAesABQAMABIAGAAeACQBwwACAecBxQACAegBvwACAekBxwACAeoBwQACAesAAQAMAIQAjACWAKQArAC2AdIB0wHjAeQB5QHmAAECRgAQACYAUABaAIQArgC4AOIBDAE2AWABagGUAb4ByAHyAhwABQAMABIAGAAeACQBeAACAecAhQACAegAgwACAekBdgACAeoAggACAesAAQAEAdQAAgHpAAUADAASABgAHgAkAZAAAgHnAZIAAgHoAIsAAgHpAY4AAgHqAIoAAgHrAAUADAASABgAHgAkAZ4AAgHnAdwAAgHoAI8AAgHpAaAAAgHqAI4AAgHrAAEABACTAAIB6AAFAAwAEgAYAB4AJAGkAAIB5wCXAAIB6ACVAAIB6QGiAAIB6gCUAAIB6wAFAAwAEgAYAB4AJAG8AAIB5wHhAAIB6ACcAAIB6QG6AAIB6gCbAAIB6wAFAAwAEgAYAB4AJAHMAAIB5wHOAAIB6ACfAAIB6QHKAAIB6gHIAAIB6wAFAAwAEgAYAB4AJAF5AAIB5wClAAIB6ACjAAIB6QF3AAIB6gCiAAIB6wABAAQB1QACAekABQAMABIAGAAeACQBkQACAecBkwACAegAqwACAekBjwACAeoAqgACAesABQAMABIAGAAeACQBnwACAecB3QACAegArwACAekBoQACAeoArgACAesAAQAEALMAAgHoAAUADAASABgAHgAkAaUAAgHnALcAAgHoALUAAgHpAaMAAgHqALQAAgHrAAUADAASABgAHgAkAb0AAgHnAeIAAgHoALwAAgHpAbsAAgHqALsAAgHrAAUADAASABgAHgAkAc0AAgHnAc8AAgHoAL8AAgHpAcsAAgHqAckAAgHrAAEAEAAiACQAJgAqAC8AMAA2ADoAQgBEAEYASgBPAFAAVgBaAAEB1gAMAB4AQABiAIQApgDIAOoBDAEuAVgBggGsAAQACgAQABYAHAF+AAIB5wGAAAIB6AF6AAIB6QF8AAIB6wAEAAoAEAAWABwBmAACAecBmgACAegBlAACAekBlgACAesABAAKABAAFgAcAaoAAgHnAawAAgHoAaYAAgHpAagAAgHrAAQACgAQABYAHAF/AAIB5wGBAAIB6AF7AAIB6QF9AAIB6wAEAAoAEAAWABwBmQACAecBmwACAegBlQACAekBlwACAesABAAKABAAFgAcAasAAgHnAa0AAgHoAacAAgHpAakAAgHrAAQACgAQABYAHAGIAAIB5wGKAAIB6AGEAAIB6QGGAAIB6wAEAAoAEAAWABwBiQACAecBiwACAegBhQACAekBhwACAesABQAMABIAGAAeACQBtAACAecBtgACAegBsAACAekBuAACAeoBsgACAesABQAMABIAGAAeACQBtQACAecBtwACAegBsQACAekBuQACAeoBswACAesABQAMABIAGAAeACQBwgACAecBxAACAegBvgACAekBxgACAeoBwAACAesABQAMABIAGAAeACQBwwACAecBxQACAegBvwACAekBxwACAeoBwQACAesAAQAMAIQAjACWAKQArAC2AdIB0wHjAeQB5QHmAAECRgAQACYAUABaAIQArgC4AOIBDAE2AWABagGUAb4ByAHyAhwABQAMABIAGAAeACQBeAACAecAhQACAegAgwACAekBdgACAeoAggACAesAAQAEAdQAAgHpAAUADAASABgAHgAkAZAAAgHnAZIAAgHoAIsAAgHpAY4AAgHqAIoAAgHrAAUADAASABgAHgAkAZ4AAgHnAdwAAgHoAI8AAgHpAaAAAgHqAI4AAgHrAAEABACTAAIB6AAFAAwAEgAYAB4AJAGkAAIB5wCXAAIB6ACVAAIB6QGiAAIB6gCUAAIB6wAFAAwAEgAYAB4AJAG8AAIB5wHhAAIB6ACcAAIB6QG6AAIB6gCbAAIB6wAFAAwAEgAYAB4AJAHMAAIB5wHOAAIB6ACfAAIB6QHKAAIB6gHIAAIB6wAFAAwAEgAYAB4AJAF5AAIB5wClAAIB6ACjAAIB6QF3AAIB6gCiAAIB6wABAAQB1QACAekABQAMABIAGAAeACQBkQACAecBkwACAegAqwACAekBjwACAeoAqgACAesABQAMABIAGAAeACQBnwACAecB3QACAegArwACAekBoQACAeoArgACAesAAQAEALMAAgHoAAUADAASABgAHgAkAaUAAgHnALcAAgHoALUAAgHpAaMAAgHqALQAAgHrAAUADAASABgAHgAkAb0AAgHnAeIAAgHoALwAAgHpAbsAAgHqALsAAgHrAAUADAASABgAHgAkAc0AAgHnAc8AAgHoAL8AAgHpAcsAAgHqAckAAgHrAAEAEAAiACQAJgAqAC8AMAA2ADoAQgBEAEYASgBPAFAAVgBaAAEB1gAMAB4AQABiAIQApgDIAOoBDAEuAVgBggGsAAQACgAQABYAHAF+AAIB5wGAAAIB6AF6AAIB6QF8AAIB6wAEAAoAEAAWABwBmAACAecBmgACAegBlAACAekBlgACAesABAAKABAAFgAcAaoAAgHnAawAAgHoAaYAAgHpAagAAgHrAAQACgAQABYAHAF/AAIB5wGBAAIB6AF7AAIB6QF9AAIB6wAEAAoAEAAWABwBmQACAecBmwACAegBlQACAekBlwACAesABAAKABAAFgAcAasAAgHnAa0AAgHoAacAAgHpAakAAgHrAAQACgAQABYAHAGIAAIB5wGKAAIB6AGEAAIB6QGGAAIB6wAEAAoAEAAWABwBiQACAecBiwACAegBhQACAekBhwACAesABQAMABIAGAAeACQBtAACAecBtgACAegBsAACAekBuAACAeoBsgACAesABQAMABIAGAAeACQBtQACAecBtwACAegBsQACAekBuQACAeoBswACAesABQAMABIAGAAeACQBwgACAecBxAACAegBvgACAekBxgACAeoBwAACAesABQAMABIAGAAeACQBwwACAecBxQACAegBvwACAekBxwACAeoBwQACAesAAQAMAIQAjACWAKQArAC2AdIB0wHjAeQB5QHmAAAAAwG2AfQABQAAArwCigAAAIMCvAKKAAABwgAyAPoIBQILBQAEAgACAAOhAABvUAAgWgAAAAAAAAAARkMgIABAACD7AgIB/4gAAAM5ANJgAQGDgAAAAAF0AdwAAAAgAAMAAQAAUAAAAADUAT8AAAAAAcUAFCAgICAgICAgICAgICAgICAAAAAAAAAAAABIU1IwMAAAQAAAAAAAAAMAAAADAAAENgABAAAAAAAcAAMAAQAAAeYABgHKAAAAIADgAfAAAgADAAQABQAGAAcACAAJAAoACwAMAA0ADgAPABAAEQASABMAFAAVABYAFwAYABkAGgAbABwAHQAeAB8AIAAhACIAIwAkACUAJgAnACgAKQAqACsALAAtAC4ALwAwADEAMgAzADQANQA2ADcAOAA5ADoAOwA8AD0APgA/AEAAQQBCAEMARABFAEYARwBIAEkASgBLAEwATQBOAE8AUABRAFIAUwBUAFUAVgBXAFgAWQBaAFsAXABdAF4AXwAAAIYAhwCJAIsAkwCYAJ4AowCiAKQApgClAKcAqQCrAKoArACtAK8ArgCwALEAswC1ALQAtgC4ALcAvAC7AL0AvgE5AHIAZQBmAGoBOwB4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AAAZoAABBEMYAAAKAZIAIgA1/8QAIgA3/78AIgA4/84AIgA6/7UAJwAi/8QALABC//EALABE//EALABF//EALABG//EALABI//EALABQ//EALABS//EALABU//EALABV//YALABX/+wALABa/+wALQA1/8QALQA3/8QALQA4/84ALQA6/8QAMAA3/+cAMAA5/9gAMQAi/84AMQAr/7oANQAi/8QANQAr/8QANQBC/84ANQBE/84ANQBF/84ANQBG/84ANQBI/84ANQBO/+wANQBP/+wANQBQ/84ANQBR/+wANQBS/84ANQBT/+wANQBU/84ANQBW/+wANQBX/+wANQBY/+wANQBZ/+wANQBa/+wANQBb/+wANwAi/78ANwAr/8QANwAw/+cANwBE/+IANwBG/+IANwBI/+IANwBQ/+IANwBS/+IANwBU/+IAOAAi/84AOABE/+IAOABG/+IAOABI/+IAOABQ/+IAOABS/+IAOABU/+IAOQAw/9gAOgAi/7UAOgBC/84AOgBE/84AOgBF/84AOgBG/84AOgBI/84AOgBO/+wAOgBP/+wAOgBQ/84AOgBR/+wAOgBS/84AOgBT/+wAOgBU/84AOgBW/+wAQwBT//wAQwBZ//YARABC//sARABF//sARABG//sARABI//wARABQ//sARABS//sARABU//sARgBX/+wARgBZ//EARwBC/90ARwBE/90ARwBF/90ARwBG/90ARwBI/90ARwBQ/90ARwBS/90ARwBU/+cATABC/+cATABF/+cATABG/+oATABI//AATABQ/+cATABS/+cATABU//EAUABX/+IAUABY//EAUABZ/+cAUQBX/+wAUQBZ//YAUwBC/+wAUwBE/+wAUwBG/+wAUwBI/+wAUwBQ/+wAUwBS/+wAVABE//0AVABZ//QAVQBC//sAVQBE//sAVQBF//sAVQBG//sAVQBJAAMAVQBQ//wAVQBS//sAVQBX//sAVQBY//wAVwBC/+wAVwBE/+wAVwBF/+wAVwBG/+IAVwBI/+wAVwBQ/+IAVwBS/+wAVwBU/+wAWABQ//EAWQBC//EAWQBE//EAWQBG//EAWQBQ/+cAWQBS//EAWQBU//QAggA1/9gAggA3/84AggA4/9MAggA6/9gAggBa//EAggCf/9gAggC///EAggDB//EAggDJ/9gAggHI/9gAggHJ//EAggHK/9gAggHL//EAggHM/9gAggHN//EAggHO/9gAggHP//EAgwA1/9gAgwA3/84AgwA4/9MAgwA6/9gAgwBa//EAgwCf/9gAgwC///EAgwDB//EAgwDJ/9gAgwHI/9gAgwHJ//EAgwHK/9gAgwHL//EAgwHM/9gAgwHN//EAgwHO/9gAgwHP//EAhAA1/9gAhAA3/84AhAA4/9MAhAA6/9gAhABa//EAhACf/9gAhAC///EAhADB//EAhADJ/9gAhAHI/9gAhAHJ//EAhAHK/9gAhAHL//EAhAHM/9gAhAHN//EAhAHO/9gAhAHP//EAhQA1/9gAhQA3/84AhQA4/9MAhQA6/9gAhQBa//EAhQCf/9gAhQC///EAhQDB//EAhQDJ/9gAhQHI/9gAhQHJ//EAhQHK/9gAhQHL//EAhQHM/9gAhQHN//EAhQHO/9gAhQHP//EAhgA1/9gAhgA3/84AhgA4/9MAhgA6/9gAhgBa//EAhgCf/9gAhgC///EAhgDB//EAhgDJ/9gAhgHI/9gAhgHJ//EAhgHK/9gAhgHL//EAhgHM/9gAhgHN//EAhgHO/9gAhgHP//EAhwA1/9gAhwA3/84AhwA4/9MAhwA6/9gAhwBa//EAhwCf/9gAhwC///EAhwDB//EAhwDJ/9gAhwHI/9gAhwHJ//EAhwHK/9gAhwHL//EAhwHM/9gAhwHN//EAhwHO/9gAhwHP//EAnwAi/9gAnwBC/+wAnwBE/+cAnwBG/+cAnwBI/+cAnwBO/+wAnwBP/+wAnwBQ/+cAnwBR/+wAnwBS/+cAnwBT/+wAnwBU/+cAnwBW/+wAnwCC/9gAnwCD/9gAnwCE/9gAnwCF/9gAnwCG/9gAnwCH/9gAnwCi/+wAnwCj/+wAnwCk/+wAnwCl/+wAnwCm/+wAnwCn/+wAnwCo/+wAnwCp/+cAnwCq/+cAnwCr/+cAnwCs/+cAnwCt/+cAnwCy/+cAnwCz/+wAnwC0/+cAnwC1/+cAnwC2/+cAnwC3/+cAnwC4/+cAnwC6/+cAnwC7/+wAnwC8/+wAnwC9/+wAnwC+/+wAnwDG/+cAnwDI/+cAnwF2/9gAnwF3/+wAnwF4/9gAnwF5/+wAnwF6/9gAnwF7/+wAnwF8/9gAnwF9/+wAnwF+/9gAnwF//+wAnwGA/9gAnwGB/+wAnwGC/9gAnwGD/+wAnwGE/9gAnwGF/+wAnwGG/9gAnwGH/+wAnwGI/9gAnwGJ/+wAnwGK/9gAnwGL/+wAnwGM/9gAnwGN/+wAnwGP/+cAnwGR/+cAnwGT/+cAnwGV/+cAnwGX/+cAnwGZ/+cAnwGb/+cAnwGd/+cAnwGj/+cAnwGl/+cAnwGn/+cAnwGp/+cAnwGr/+cAnwGt/+cAnwGv/+cAnwGx/+cAnwGz/+cAnwG1/+cAnwG3/+cAnwG5/+cAnwG7/+wAnwG9/+wAnwG//+wAnwHB/+wAnwHD/+wAnwHF/+wAnwHH/+wAnwHS/9gAnwHT/+wAnwHV/+cAnwHX/+cAnwHb/+cAnwHg/+cAnwHi/+wAnwHk/+cAnwHm/+wAyQAi/9gAyQBC/+wAyQBE/+cAyQBG/+cAyQBI/+cAyQBO/+wAyQBP/+wAyQBQ/+cAyQBR/+wAyQBS/+cAyQBT/+wAyQBU/+cAyQBW/+wAyQCC/9gAyQCD/9gAyQCE/9gAyQCF/9gAyQCG/9gAyQCH/9gAyQCi/+wAyQCj/+wAyQCk/+wAyQCl/+wAyQCm/+wAyQCn/+wAyQCo/+wAyQCp/+cAyQCq/+cAyQCr/+cAyQCs/+cAyQCt/+cAyQCy/+cAyQCz/+wAyQC0/+cAyQC1/+cAyQC2/+cAyQC3/+cAyQC4/+cAyQC6/+cAyQC7/+wAyQC8/+wAyQC9/+wAyQC+/+wAyQDG/+cAyQDI/+cAyQF2/9gAyQF3/+wAyQF4/9gAyQF5/+wAyQF6/9gAyQF7/+wAyQF8/9gAyQF9/+wAyQF+/9gAyQF//+wAyQGA/9gAyQGB/+wAyQGC/9gAyQGD/+wAyQGE/9gAyQGF/+wAyQGG/9gAyQGH/+wAyQGI/9gAyQGJ/+wAyQGK/9gAyQGL/+wAyQGM/9gAyQGN/+wAyQGP/+cAyQGR/+cAyQGT/+cAyQGV/+cAyQGX/+cAyQGZ/+cAyQGb/+cAyQGd/+cAyQGj/+cAyQGl/+cAyQGn/+cAyQGp/+cAyQGr/+cAyQGt/+cAyQGv/+cAyQGx/+cAyQGz/+cAyQG1/+cAyQG3/+cAyQG5/+cAyQG7/+wAyQG9/+wAyQG//+wAyQHB/+wAyQHD/+wAyQHF/+wAyQHH/+wAyQHS/9gAyQHT/+wAyQHV/+cAyQHX/+cAyQHb/+cAyQHg/+cAyQHi/+wAyQHk/+cAyQHm/+wBdgA1/9gBdgA3/84BdgA4/9MBdgA6/9gBdgBa//EBdgCf/9gBdgC///EBdgDB//EBdgDJ/9gBdgHI/9gBdgHJ//EBdgHK/9gBdgHL//EBdgHM/9gBdgHN//EBdgHO/9gBdgHP//EBeAA1/9gBeAA3/84BeAA4/9MBeAA6/9gBeABa//EBeACf/9gBeAC///EBeADB//EBeADJ/9gBeAHI/9gBeAHJ//EBeAHK/9gBeAHL//EBeAHM/9gBeAHN//EBeAHO/9gBeAHP//EBegA1/9gBegA3/84BegA4/9MBegA6/9gBegBa//EBegCf/9gBegC///EBegDB//EBegDJ/9gBegHI/9gBegHJ//EBegHK/9gBegHL//EBegHM/9gBegHN//EBegHO/9gBegHP//EBfAA1/9gBfAA3/84BfAA4/9MBfAA6/9gBfABa//EBfACf/9gBfAC///EBfADB//EBfADJ/9gBfAHI/9gBfAHJ//EBfAHK/9gBfAHL//EBfAHM/9gBfAHN//EBfAHO/9gBfAHP//EBfgA1/9gBfgA3/84BfgA4/9MBfgA6/9gBfgBa//EBfgCf/9gBfgC///EBfgDB//EBfgDJ/9gBfgHI/9gBfgHJ//EBfgHK/9gBfgHL//EBfgHM/9gBfgHN//EBfgHO/9gBfgHP//EBgAA1/9gBgAA3/84BgAA4/9MBgAA6/9gBgABa//EBgACf/9gBgAC///EBgADB//EBgADJ/9gBgAHI/9gBgAHJ//EBgAHK/9gBgAHL//EBgAHM/9gBgAHN//EBgAHO/9gBgAHP//EBggA1/9gBggA3/84BggA4/9MBggA6/9gBggBa//EBggCf/9gBggC///EBggDB//EBggDJ/9gBggHI/9gBggHJ//EBggHK/9gBggHL//EBggHM/9gBggHN//EBggHO/9gBggHP//EBhAA1/9gBhAA3/84BhAA4/9MBhAA6/9gBhABa//EBhACf/9gBhAC///EBhADB//EBhADJ/9gBhAHI/9gBhAHJ//EBhAHK/9gBhAHL//EBhAHM/9gBhAHN//EBhAHO/9gBhAHP//EBhgA1/9gBhgA3/84BhgA4/9MBhgA6/9gBhgBa//EBhgCf/9gBhgC///EBhgDB//EBhgDJ/9gBhgHI/9gBhgHJ//EBhgHK/9gBhgHL//EBhgHM/9gBhgHN//EBhgHO/9gBhgHP//EBiAA1/9gBiAA3/84BiAA4/9MBiAA6/9gBiABa//EBiACf/9gBiAC///EBiADB//EBiADJ/9gBiAHI/9gBiAHJ//EBiAHK/9gBiAHL//EBiAHM/9gBiAHN//EBiAHO/9gBiAHP//EBigA1/9gBigA3/84BigA4/9MBigA6/9gBigBa//EBigCf/9gBigC///EBigDB//EBigDJ/9gBigHI/9gBigHJ//EBigHK/9gBigHL//EBigHM/9gBigHN//EBigHO/9gBigHP//EBjAA1/9gBjAA3/84BjAA4/9MBjAA6/9gBjABa//EBjACf/9gBjAC///EBjADB//EBjADJ/9gBjAHI/9gBjAHJ//EBjAHK/9gBjAHL//EBjAHM/9gBjAHN//EBjAHO/9gBjAHP//EByAAi/9gByABC/+wByABE/+cByABG/+cByABI/+cByABO/+wByABP/+wByABQ/+cByABR/+wByABS/+cByABT/+wByABU/+cByABW/+wByACC/9gByACD/9gByACE/9gByACF/9gByACG/9gByACH/9gByACi/+wByACj/+wByACk/+wByACl/+wByACm/+wByACn/+wByACo/+wByACp/+cByACq/+cByACr/+cByACs/+cByACt/+cByACy/+cByACz/+wByAC0/+cByAC1/+cByAC2/+cByAC3/+cByAC4/+cByAC6/+cByAC7/+wByAC8/+wByAC9/+wByAC+/+wByADG/+cByADI/+cByAF2/9gByAF3/+wByAF4/9gByAF5/+wByAF6/9gByAF7/+wByAF8/9gByAF9/+wByAF+/9gByAF//+wByAGA/9gByAGB/+wByAGC/9gByAGD/+wByAGE/9gByAGF/+wByAGG/9gByAGH/+wByAGI/9gByAGJ/+wByAGK/9gByAGL/+wByAGM/9gByAGN/+wByAGP/+cByAGR/+cByAGT/+cByAGV/+cByAGX/+cByAGZ/+cByAGb/+cByAGd/+cByAGj/+cByAGl/+cByAGn/+cByAGp/+cByAGr/+cByAGt/+cByAGv/+cByAGx/+cByAGz/+cByAG1/+cByAG3/+cByAG5/+cByAG7/+wByAG9/+wByAG//+wByAHB/+wByAHD/+wByAHF/+wByAHH/+wByAHS/9gByAHT/+wByAHV/+cByAHX/+cByAHb/+cByAHg/+cByAHi/+wByAHk/+cByAHm/+wBygAi/9gBygBC/+wBygBE/+cBygBG/+cBygBI/+cBygBO/+wBygBP/+wBygBQ/+cBygBR/+wBygBS/+cBygBT/+wBygBU/+cBygBW/+wBygCC/9gBygCD/9gBygCE/9gBygCF/9gBygCG/9gBygCH/9gBygCi/+wBygCj/+wBygCk/+wBygCl/+wBygCm/+wBygCn/+wBygCo/+wBygCp/+cBygCq/+cBygCr/+cBygCs/+cBygCt/+cBygCy/+cBygCz/+wBygC0/+cBygC1/+cBygC2/+cBygC3/+cBygC4/+cBygC6/+cBygC7/+wBygC8/+wBygC9/+wBygC+/+wBygDG/+cBygDI/+cBygF2/9gBygF3/+wBygF4/9gBygF5/+wBygF6/9gBygF7/+wBygF8/9gBygF9/+wBygF+/9gBygF//+wBygGA/9gBygGB/+wBygGC/9gBygGD/+wBygGE/9gBygGF/+wBygGG/9gBygGH/+wBygGI/9gBygGJ/+wBygGK/9gBygGL/+wBygGM/9gBygGN/+wBygGP/+cBygGR/+cBygGT/+cBygGV/+cBygGX/+cBygGZ/+cBygGb/+cBygGd/+cBygGj/+cBygGl/+cBygGn/+cBygGp/+cBygGr/+cBygGt/+cBygGv/+cBygGx/+cBygGz/+cBygG1/+cBygG3/+cBygG5/+cBygG7/+wBygG9/+wBygG//+wBygHB/+wBygHD/+wBygHF/+wBygHH/+wBygHS/9gBygHT/+wBygHV/+cBygHX/+cBygHb/+cBygHg/+cBygHi/+wBygHk/+cBygHm/+wBzAAi/9gBzABC/+wBzABE/+cBzABG/+cBzABI/+cBzABO/+wBzABP/+wBzABQ/+cBzABR/+wBzABS/+cBzABT/+wBzABU/+cBzABW/+wBzACC/9gBzACD/9gBzACE/9gBzACF/9gBzACG/9gBzACH/9gBzACi/+wBzACj/+wBzACk/+wBzACl/+wBzACm/+wBzACn/+wBzACo/+wBzACp/+cBzACq/+cBzACr/+cBzACs/+cBzACt/+cBzACy/+cBzACz/+wBzAC0/+cBzAC1/+cBzAC2/+cBzAC3/+cBzAC4/+cBzAC6/+cBzAC7/+wBzAC8/+wBzAC9/+wBzAC+/+wBzADG/+cBzADI/+cBzAF2/9gBzAF3/+wBzAF4/9gBzAF5/+wBzAF6/9gBzAF7/+wBzAF8/9gBzAF9/+wBzAF+/9gBzAF//+wBzAGA/9gBzAGB/+wBzAGC/9gBzAGD/+wBzAGE/9gBzAGF/+wBzAGG/9gBzAGH/+wBzAGI/9gBzAGJ/+wBzAGK/9gBzAGL/+wBzAGM/9gBzAGN/+wBzAGP/+cBzAGR/+cBzAGT/+cBzAGV/+cBzAGX/+cBzAGZ/+cBzAGb/+cBzAGd/+cBzAGj/+cBzAGl/+cBzAGn/+cBzAGp/+cBzAGr/+cBzAGt/+cBzAGv/+cBzAGx/+cBzAGz/+cBzAG1/+cBzAG3/+cBzAG5/+cBzAG7/+wBzAG9/+wBzAG//+wBzAHB/+wBzAHD/+wBzAHF/+wBzAHH/+wBzAHS/9gBzAHT/+wBzAHV/+cBzAHX/+cBzAHb/+cBzAHg/+cBzAHi/+wBzAHk/+cBzAHm/+wBzgAi/9gBzgBC/+wBzgBE/+cBzgBG/+cBzgBI/+cBzgBO/+wBzgBP/+wBzgBQ/+cBzgBR/+wBzgBS/+cBzgBT/+wBzgBU/+cBzgBW/+wBzgCC/9gBzgCD/9gBzgCE/9gBzgCF/9gBzgCG/9gBzgCH/9gBzgCi/+wBzgCj/+wBzgCk/+wBzgCl/+wBzgCm/+wBzgCn/+wBzgCo/+wBzgCp/+cBzgCq/+cBzgCr/+cBzgCs/+cBzgCt/+cBzgCy/+cBzgCz/+wBzgC0/+cBzgC1/+cBzgC2/+cBzgC3/+cBzgC4/+cBzgC6/+cBzgC7/+wBzgC8/+wBzgC9/+wBzgC+/+wBzgDG/+cBzgDI/+cBzgF2/9gBzgF3/+wBzgF4/9gBzgF5/+wBzgF6/9gBzgF7/+wBzgF8/9gBzgF9/+wBzgF+/9gBzgF//+wBzgGA/9gBzgGB/+wBzgGC/9gBzgGD/+wBzgGE/9gBzgGF/+wBzgGG/9gBzgGH/+wBzgGI/9gBzgGJ/+wBzgGK/9gBzgGL/+wBzgGM/9gBzgGN/+wBzgGP/+cBzgGR/+cBzgGT/+cBzgGV/+cBzgGX/+cBzgGZ/+cBzgGb/+cBzgGd/+cBzgGj/+cBzgGl/+cBzgGn/+cBzgGp/+cBzgGr/+cBzgGt/+cBzgGv/+cBzgGx/+cBzgGz/+cBzgG1/+cBzgG3/+cBzgG5/+cBzgG7/+wBzgG9/+wBzgG//+wBzgHB/+wBzgHD/+wBzgHF/+wBzgHH/+wBzgHS/9gBzgHT/+wBzgHV/+cBzgHX/+cBzgHb/+cBzgHg/+cBzgHi/+wBzgHk/+cBzgHm/+wB0gA1/9gB0gA3/84B0gA4/9MB0gA6/9gB0gBa//EB0gCf/9gB0gC///EB0gDB//EB0gDJ/9gB0gHI/9gB0gHJ//EB0gHK/9gB0gHL//EB0gHM/9gB0gHN//EB0gHO/9gB0gHP//EAAAA4ADgAbACiAPYBXgICAngCngK6AtYDDAM6A2gDhAOoA8AEDAQuBHIE2gUKBaQGDAYwBqYHAAc8B4YHngfCB9gIMgj0CSIJfgnICggKOgpmCr4K7AsECzwLbAuOC8IL7gw8DHwM4A0mDYgNqg3kDgYOOg5qDpIOvg7mDwIPJg9KD2gPig/cEEwQlBD+EVYRsBIsEnwSuhMQE1YTeBPSFA4UVhSuFQAVMhWOFdIWBBYiFk4Wfha2FuAXLhdIF5gX1hhKGEoYShhKGI4Y5BkqGYoZvBneGn4athq2GrYa2BsIGwgbKBtqG54bnhueG54b3BwgHFAcUBxQHFAcchxyHPAc8BzwHPAc8BzwHPAc8BzwHPAc8BzwHPAc8BzwHPAc8BzwHPAc8BzwHPAc8BzwHPAc8B0QHRAdEB0QHRAdEB0QHRAdEB0QHRAdEB0QHRAdEB0QHRAdEB0QHRAdEB0QHRAdEB0QHRAdEB0QHRAdEB0QHRAdXh1eHV4dXh1eHV4dXh1eHV4dXh1eHV4dXh1eHV4dXh1eHV4dXh1eHV4dXh1eHV4dXh1eHV4dXh1eHZ4d/B5YHqoe/B9eH6of+iBUIMYhQCG2IlAi5COeJIYk4CVWJdAmICZ6JtQnECd8J7In5igcKIAo5ik8KZQp5iogKowq9itkK+AsRiyiLQgtVC3sLiYuwC8cL4gv1DAaMFAwhjD2MR4xXjGsMfYyKDJ+MqQzIjNSM6Az+DRGNJQ02jUqNXY1mDXENho2TDaMNtg3FDecN+I4SDjMOTI50jqQOyQ70jx4PR49dj2sPaw9rD2sPaw9yD3kPgo+MD5ePpQ+yj8aP1A/mD/IQBZA5EESQUhBYEF2QY5B+kH6QfpB+kH6QfpB+kIeQh5COkI6QjpCOkKiQqJC0EL6QxZD2kQ+RGJEnETsRTZFVEV8RdJGAEY+RlxGhEbYRwZHREfCR/RIPkiISKJIyEkYSURJgkmwSgZKKEtgS9JMSky8TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRM9Ez0TPRNkk4OToRO9k72TvZO9k72TvZO9k72TvZUkQAAAAEAAAH+AXAADAAAAAAAAgBgAHIAiwAAAU4NbQAAAAAAAAAdAWIAAQAAAAAAAABJAAAAAQAAAAAAAQAJAEkAAQAAAAAAAgAGAFIAAQAAAAAAAwAoAFgAAQAAAAAABAAQAIAAAQAAAAAABQCGAJAAAQAAAAAABgAOARYAAQAAAAAABwAJASQAAQAAAAAACAARAS0AAQAAAAAACQARAT4AAQAAAAAACwAVAU8AAQAAAAAADAAVAWQAAQAAAAAADQBiAXkAAQAAAAAADgAVAdsAAQAAAAAAEgAQAfAAAwABBAkAAACSAgAAAwABBAkAAQASApIAAwABBAkAAgAMAqQAAwABBAkAAwBQArAAAwABBAkABAAgAwAAAwABBAkABQEMAyAAAwABBAkABgAcBCwAAwABBAkABwASBEgAAwABBAkACAAiBFoAAwABBAkACQAiBHwAAwABBAkACwAqBJ4AAwABBAkADAAqBMgAAwABBAkADQDEBPIAAwABBAkADgAqBbZDb3B5cmlnaHQgKGMpIDIwMjAgYnkgRm9udGNyYWZ0IDogSnV0aXBvbmcgUG9vc3VtYXMuIEFsbCByaWdodHMgcmVzZXJ2ZWQuRkMgRnJpZGF5TWVkaXVtSnV0aXBvbmdQb29zdW1hczogRkMgRnJpZGF5IE1lZGl1bTogMjAyMEZDIEZyaWRheSBNZWRpdW1Ob24tY29tbWVyY2lhbCB1c2Ugb25seSwgcGxlYXNlIGNvbnRhY3QgRk9OVENSQUZUU1RVRElPLkNPTSBmb3IgYW55IGNvbW1lcmNpYWwgdXNlLiBWZXJzaW9uIDEuMDAgMjAyMCBieSBGb250Y3JhZnQgOiBKdXRpcG9uZyBQb29zdW1hc0ZDRnJpZGF5TWVkaXVtRm9udGNyYWZ0SnV0aXBvbmcgUG9vc3VtYXNKdXRpcG9uZyBQb29zdW1hc2ZvbnRjcmFmdEBob3RtYWlsLmNvbWZvbnRjcmFmdEBob3RtYWlsLmNvbUZvbnQgSW5mb3JtYXRpb24NCiAgICBGQyBGcmlkYXkNICAgIApGb250IERlc2lnbmVyCiAgICBKdXRpcG9uZyBQb29zdW1hcwogICAgZm9udGNyYWZ0QGhvdG1haWwuY29tZm9udGNyYWZ0QGhvdG1haWwuY29tRkMgRnJpZGF5IE1lZGl1bQBDAG8AcAB5AHIAaQBnAGgAdAAgACgAYwApACAAMgAwADIAMAAgAGIAeQAgAEYAbwBuAHQAYwByAGEAZgB0ACAAOgAgAEoAdQB0AGkAcABvAG4AZwAgAFAAbwBvAHMAdQBtAGEAcwAuACAAQQBsAGwAIAByAGkAZwBoAHQAcwAgAHIAZQBzAGUAcgB2AGUAZAAuAEYAQwAgAEYAcgBpAGQAYQB5AE0AZQBkAGkAdQBtAEoAdQB0AGkAcABvAG4AZwBQAG8AbwBzAHUAbQBhAHMAOgAgAEYAQwAgAEYAcgBpAGQAYQB5ACAATQBlAGQAaQB1AG0AOgAgADIAMAAyADAARgBDACAARgByAGkAZABhAHkAIABNAGUAZABpAHUAbQBOAG8AbgAtAGMAbwBtAG0AZQByAGMAaQBhAGwAIAB1AHMAZQAgAG8AbgBsAHkALAAgAHAAbABlAGEAcwBlACAAYwBvAG4AdABhAGMAdAAgAEYATwBOAFQAQwBSAEEARgBUAFMAVABVAEQASQBPAC4AQwBPAE0AIABmAG8AcgAgAGEAbgB5ACAAYwBvAG0AbQBlAHIAYwBpAGEAbAAgAHUAcwBlAC4AIABWAGUAcgBzAGkAbwBuACAAMQAuADAAMAAgADIAMAAyADAAIABiAHkAIABGAG8AbgB0AGMAcgBhAGYAdAAgADoAIABKAHUAdABpAHAAbwBuAGcAIABQAG8AbwBzAHUAbQBhAHMARgBDAEYAcgBpAGQAYQB5AE0AZQBkAGkAdQBtAEYAbwBuAHQAYwByAGEAZgB0AEoAdQB0AGkAcABvAG4AZwAgAFAAbwBvAHMAdQBtAGEAcwBKAHUAdABpAHAAbwBuAGcAIABQAG8AbwBzAHUAbQBhAHMAZgBvAG4AdABjAHIAYQBmAHQAQABoAG8AdABtAGEAaQBsAC4AYwBvAG0AZgBvAG4AdABjAHIAYQBmAHQAQABoAG8AdABtAGEAaQBsAC4AYwBvAG0ARgBvAG4AdAAgAEkAbgBmAG8AcgBtAGEAdABpAG8AbgANAAoAIAAgACAAIABGAEMAIABGAHIAaQBkAGEAeQANACAAIAAgACAACgBGAG8AbgB0ACAARABlAHMAaQBnAG4AZQByAAoAIAAgACAAIABKAHUAdABpAHAAbwBuAGcAIABQAG8AbwBzAHUAbQBhAHMACgAgACAAIAAgAGYAbwBuAHQAYwByAGEAZgB0AEAAaABvAHQAbQBhAGkAbAAuAGMAbwBtAGYAbwBuAHQAYwByAGEAZgB0AEAAaABvAHQAbQBhAGkAbAAuAGMAbwBtAAAAAgAAAAAAAP9pADIAAAAAAAAAAAAAAAAAAAAAAAAAAAH+AAAArAAEAAUABgAHAAgACQAKAAsADAANAA4ADwAQABEAEgATABQAFQAWABcAGAAZABoAGwAcAB0AHgAfACAAIQAiACMAJAAlACYAJwAoACkAKgArACwALQAuAC8AMAAxADIAMwA0ADUANgA3ADgAOQA6ADsAPAA9AD4APwBAAEEAQgBDAEQARQBGAEcASABJAEoASwBMAE0ATgBPAFAAUQBSAFMAVABVAFYAVwBYAFkAWgBbAFwAXQBeAF8AYABhAQIBAwEEAAIAowCEAIUAvQCWAOgAhgCOAIsAnQCpAKQAigDaAIMAkwDyAPMAjQCXAIgAwwDeAPEAngCqAPUA9AD2AKIArQDJAMcArgBiAGMAkABkAMsAZQDIAMoAzwDMAM0AzgDpAGYA0wDQANEArwBnAPAAkQDWANQA1QBoAOsA7QCJAGoAaQBrAG0AbABuAKAAbwBxAHAAcgBzAHUAdAB2AHcA6gB4AHoAeQB7AH0AfAC4AKEAfwB+AIAAgQDsAO4AugDXAOIA4wCwALEA5ADlALsA5gDnAKYA2ADhANsA3ADdAOAA2QDfAQUBBgEHAQgBCQEKAQsBDAENAQ4BDwEQAREBEgETARQBFQEWARcBGAEZARoBGwEcAR0BHgEfASABIQEiASMBJAElASYBJwEoASkBKgErASwBLQEuAS8BMAExATIBMwE0ATUBNgE3ATgBOQE6ATsBPAE9AT4BPwFAAUEBQgFDAUQBRQFGAUcBSAFJAUoBSwFMAU0BTgFPAVABUQFSAVMBVAFVAVYBVwFYAVkBWgFbAVwBXQFeAV8BYACyALMAtgC3AMQAtAC1AMUAggDCAIcAqwDGAWEBYgC+AL8AvAFjAWQAjAFlAWYAmACoAJoAmQDvAKUAkgCcAKcAjwCUAJUAuQFnAWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBewF8AX0BfgF/AYABgQGCAYMBhADAAMEBhQGGAYcBiAGJAYoBiwGMAY0BjgGPAZABkQGSAZMBlAGVAZYBlwGYAZkBmgGbAZwBnQGeAZ8BoAGhAaIBowGkAaUBpgGnAagBqQGqAasBrAGtAa4BrwGwAbEBsgGzAbQBtQG2AbcBuAG5AboBuwG8Ab0BvgG/AcABwQHCAcMBxAHFAcYBxwHIAckBygHLAcwBzQHOAc8B0AHRAdIB0wHUAdUB1gHXAdgB2QHaAdsB3AHdAd4B3wD3AeAB4QHiAP0A/gD/AQAB4wEBAPgA+QHkAeUA+gD7APwB5gHnAegB6QHqAesB7AHtAe4B7wHwAfEB8gHzAfQAAwH1AfYB9wH4AfkB+gH7AfwB/QH+Af8CAAIBDHVuaTBFMzMuYWx0MQUubnVsbBBub25tYXJraW5ncmV0dXJuB3VuaTBFMDAHdW5pMEUwMQd1bmkwRTAyB3VuaTBFMDMHdW5pMEUwNAd1bmkwRTA1B3VuaTBFMDYHdW5pMEUwNwd1bmkwRTA4B3VuaTBFMDkHdW5pMEUwQQd1bmkwRTBCB3VuaTBFMEMHdW5pMEUwRAd1bmkwRTBFB3VuaTBFMEYHdW5pMEUxMAd1bmkwRTExB3VuaTBFMTIHdW5pMEUxMwd1bmkwRTE0B3VuaTBFMTUHdW5pMEUxNgd1bmkwRTE3B3VuaTBFMTgHdW5pMEUxOQd1bmkwRTFBB3VuaTBFMUIHdW5pMEUxQwd1bmkwRTFEB3VuaTBFMUUHdW5pMEUxRgd1bmkwRTIwB3VuaTBFMjEHdW5pMEUyMgd1bmkwRTIzB3VuaTBFMjQHdW5pMEUyNQd1bmkwRTI2B3VuaTBFMjcHdW5pMEUyOAd1bmkwRTI5B3VuaTBFMkEHdW5pMEUyQgd1bmkwRTJDB3VuaTBFMkQHdW5pMEUyRQd1bmkwRTJGB3VuaTBFMzAHdW5pMEUzMQd1bmkwRTMyB3VuaTBFMzMHdW5pMEUzNAd1bmkwRTM1B3VuaTBFMzYHdW5pMEUzNwd1bmkwRTM4B3VuaTBFMzkHdW5pMEUzQQd1bmkwRTNGB3VuaTBFNDAHdW5pMEU0MQd1bmkwRTQyB3VuaTBFNDMHdW5pMEU0NAd1bmkwRTQ1B3VuaTBFNDYHdW5pMEU0Nwd1bmkwRTQ4B3VuaTBFNDkHdW5pMEU0QQd1bmkwRTRCB3VuaTBFNEMHdW5pMEU0RAd1bmkwRTRFB3VuaTBFNEYHdW5pMEU1MAd1bmkwRTUxB3VuaTBFNTIHdW5pMEU1Mwd1bmkwRTU0B3VuaTBFNTUHdW5pMEU1Ngd1bmkwRTU3B3VuaTBFNTgHdW5pMEU1OQd1bmkwRTVBB3VuaTBFNUISemVyb3dpZHRobm9uam9pbmVyD3plcm93aWR0aGpvaW5lcg9sZWZ0dG9yaWdodG1hcmsPcmlnaHR0b2xlZnRtYXJrBm1pbnV0ZQZzZWNvbmQERXVybwd1bmkyMTEzA09obQllc3RpbWF0ZWQMZG90dGVkY2lyY2xlDHVuaTBFMTAuYWx0MQx1bmkwRTM0LmFsdDEMdW5pMEUzNS5hbHQxDHVuaTBFMzYuYWx0MQx1bmkwRTM3LmFsdDEMdW5pMEU0OC5hbHQxDHVuaTBFNDkuYWx0MQx1bmkwRTRBLmFsdDEMdW5pMEU0Qi5hbHQxDHVuaTBFNEMuYWx0MQx1bmkwRTQ4LmFsdDIMdW5pMEU0OS5hbHQyDHVuaTBFNEEuYWx0Mgx1bmkwRTRCLmFsdDIMdW5pMEU0Qy5hbHQyDHVuaTBFMEQuYWx0MQx1bmkwRTMxLmFsdDEMdW5pMEU0RC5hbHQxDHVuaTBFNDcuYWx0MQx1bmkwRTQ4LmFsdDMMdW5pMEU0OS5hbHQzDHVuaTBFNEEuYWx0Mwx1bmkwRTRCLmFsdDMMdW5pMEU0Qy5hbHQzDHVuaTBFMzguYWx0MQx1bmkwRTM5LmFsdDEMdW5pMEUzQS5hbHQxDHVuaTBFMEYuYWx0MQx1bmkwRTJDLmFsdDEMdW5pMEU0RS5hbHQxB3VuaTFFQTAHdW5pMUVBMQd1bmkxRUEyB3VuaTFFQTMHdW5pMUVBNAd1bmkxRUE1B3VuaTFFQTYHdW5pMUVBNwd1bmkxRUE4B3VuaTFFQTkHdW5pMUVBQQd1bmkxRUFCB3VuaTFFQUMHdW5pMUVBRAd1bmkxRUFFB3VuaTFFQUYHdW5pMUVCMAd1bmkxRUIxB3VuaTFFQjIHdW5pMUVCMwd1bmkxRUI0B3VuaTFFQjUHdW5pMUVCNgd1bmkxRUI3B3VuaTFFQjgHdW5pMUVCOQd1bmkxRUJBB3VuaTFFQkIHdW5pMUVCQwd1bmkxRUJEB3VuaTFFQkUHdW5pMUVCRgd1bmkxRUMwB3VuaTFFQzEHdW5pMUVDMgd1bmkxRUMzB3VuaTFFQzQHdW5pMUVDNQd1bmkxRUM2B3VuaTFFQzcHdW5pMUVDOAd1bmkxRUM5B3VuaTFFQ0EHdW5pMUVDQgd1bmkxRUNDB3VuaTFFQ0QHdW5pMUVDRQd1bmkxRUNGB3VuaTFFRDAHdW5pMUVEMQd1bmkxRUQyB3VuaTFFRDMHdW5pMUVENAd1bmkxRUQ1B3VuaTFFRDYHdW5pMUVENwd1bmkxRUQ4B3VuaTFFRDkHdW5pMUVEQQd1bmkxRURCB3VuaTFFREMHdW5pMUVERAd1bmkxRURFB3VuaTFFREYHdW5pMUVFMAd1bmkxRUUxB3VuaTFFRTIHdW5pMUVFMwd1bmkxRUU0B3VuaTFFRTUHdW5pMUVFNgd1bmkxRUU3B3VuaTFFRTgHdW5pMUVFOQd1bmkxRUVBB3VuaTFFRUIHdW5pMUVFQwd1bmkxRUVEB3VuaTFFRUUHdW5pMUVFRgd1bmkxRUYwB3VuaTFFRjEGWWdyYXZlBnlncmF2ZQd1bmkxRUY0B3VuaTFFRjUHdW5pMUVGNgd1bmkxRUY3B3VuaTFFRjgHdW5pMUVGOQRkb25nBkFicmV2ZQZhYnJldmUGRGNyb2F0Bkl0aWxkZQZpdGlsZGUGVXRpbGRlBnV0aWxkZQVPaG9ybgVvaG9ybgVVaG9ybgV1aG9ybg1ob29rYWJvdmVjb21iCXRpbGRlY29t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
'@

try {
    $script:keyFcFridayFontBytes = [Convert]::FromBase64String($script:keyFcFridayFontBase64)
    $script:keyFcFridayFontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $keyFcFridayMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($script:keyFcFridayFontBytes.Length)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy(
            $script:keyFcFridayFontBytes,
            0,
            $keyFcFridayMem,
            $script:keyFcFridayFontBytes.Length
        )
        $script:keyFcFridayFontCollection.AddMemoryFont(
            $keyFcFridayMem,
            $script:keyFcFridayFontBytes.Length
        )
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($keyFcFridayMem)
    }

    if ($script:keyFcFridayFontCollection.Families.Count -gt 0) {
        $script:keyFcFridayFontFamily = $script:keyFcFridayFontCollection.Families[0]
    }
} catch {
    $script:keyFcFridayFontFamily = $null
} finally {
    $script:keyFcFridayFontBase64 = $null
    if ($null -eq $script:keyFcFridayFontFamily -and $null -ne $script:keyFcFridayFontCollection) {
        try { $script:keyFcFridayFontCollection.Dispose() } catch {}
        $script:keyFcFridayFontCollection = $null
    }
}

# Prepare only the permanently masked Key glyph before the window accepts input.
# The original Key value is retained internally, but Paint only ever draws cached '*'
# bitmaps. This removes the visible-text rendering path and reduces cold GDI+ work.
$script:keyInputFont = $null
$script:keyInputFormat = $null
$script:keyGlyphAdvance = [System.Collections.Generic.Dictionary[char,double]]::new()
$script:keyGlyphBitmaps = [System.Collections.Generic.Dictionary[char,System.Drawing.Bitmap]]::new()
$script:keyGlyphBitmapScale = 3.0
$script:keyMaskAdvance = 9.5
try {
    $keyInputFamily = if ($null -ne $script:keyFcFridayFontFamily) { $script:keyFcFridayFontFamily } else { $fam }
    $script:keyInputFont = [System.Drawing.Font]::new(
        $keyInputFamily,
        [single]14.0,
        [System.Drawing.FontStyle]::Regular,
        [System.Drawing.GraphicsUnit]::Pixel
    )
    $script:keyInputFormat = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
    $script:keyInputFormat.Alignment = [System.Drawing.StringAlignment]::Near
    $script:keyInputFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $script:keyInputFormat.Trimming = [System.Drawing.StringTrimming]::None

    $keyAsteriskScale = [double]$script:keyGlyphBitmapScale
    $keyAsteriskMeasureBitmap = [System.Drawing.Bitmap]::new(96, 48, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $keyAsteriskMeasureGraphics = $null
    $keyAsteriskMeasureBrush = $null
    try {
        $keyAsteriskMeasureGraphics = [System.Drawing.Graphics]::FromImage($keyAsteriskMeasureBitmap)
        $keyAsteriskMeasureGraphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $keyAsteriskMeasureBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $asteriskMeasure = $keyAsteriskMeasureGraphics.MeasureString('*', $script:keyInputFont, [single]256.0, $script:keyInputFormat)
        $script:keyGlyphAdvance[[char]'*'] = [double]$asteriskMeasure.Width
        $keyAsteriskMeasureGraphics.DrawString('*', $script:keyInputFont, $keyAsteriskMeasureBrush, [single]0.0, [single]0.0)
    } finally {
        if ($null -ne $keyAsteriskMeasureBrush) { $keyAsteriskMeasureBrush.Dispose() }
        if ($null -ne $keyAsteriskMeasureGraphics) { $keyAsteriskMeasureGraphics.Dispose() }
        if ($null -ne $keyAsteriskMeasureBitmap) { $keyAsteriskMeasureBitmap.Dispose() }
    }

    $keyAsteriskAdvance = [double]$script:keyGlyphAdvance[[char]'*']
    $keyAsteriskLogicalWidth = [double][math]::Max(10.0, [math]::Ceiling($keyAsteriskAdvance + 5.0))
    $keyAsteriskBitmap = [System.Drawing.Bitmap]::new(
        [int][math]::Ceiling($keyAsteriskLogicalWidth * $keyAsteriskScale),
        [int][math]::Round(44.0 * $keyAsteriskScale),
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $keyAsteriskGraphics = $null
    $keyAsteriskFont = $null
    $keyAsteriskBrush = $null
    try {
        $keyAsteriskGraphics = [System.Drawing.Graphics]::FromImage($keyAsteriskBitmap)
        $keyAsteriskGraphics.Clear([System.Drawing.Color]::Transparent)
        $keyAsteriskGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $keyAsteriskGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $keyAsteriskGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $keyAsteriskGraphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
        $keyAsteriskFont = [System.Drawing.Font]::new(
            $script:keyInputFont.FontFamily,
            [single]($script:keyInputFont.Size * $keyAsteriskScale * 1.08),
            $script:keyInputFont.Style,
            [System.Drawing.GraphicsUnit]::Pixel
        )
        $keyAsteriskBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,248,250,253))
        $keyAsteriskRect = [System.Drawing.RectangleF]::new(
            0.0, 0.0, [single]$keyAsteriskBitmap.Width, [single]$keyAsteriskBitmap.Height
        )
        $keyAsteriskGraphics.DrawString('*', $keyAsteriskFont, $keyAsteriskBrush, $keyAsteriskRect, $script:keyInputFormat)
        $script:keyGlyphBitmaps.Add([char]'*', $keyAsteriskBitmap)
        $keyAsteriskBitmap = $null
    } finally {
        if ($null -ne $keyAsteriskBrush) { $keyAsteriskBrush.Dispose() }
        if ($null -ne $keyAsteriskFont) { $keyAsteriskFont.Dispose() }
        if ($null -ne $keyAsteriskGraphics) { $keyAsteriskGraphics.Dispose() }
        if ($null -ne $keyAsteriskBitmap) { $keyAsteriskBitmap.Dispose() }
    }
} catch {
    # If rasterization fails, Paint retains a DrawString('*') fallback.
    if ($null -eq $script:keyInputFont) {
        try { $script:keyInputFont = [System.Drawing.Font]::new($fam, [single]14.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel) } catch { }
    }
    if ($null -eq $script:keyInputFormat) {
        try {
            $script:keyInputFormat = [System.Drawing.StringFormat]::new()
            $script:keyInputFormat.Alignment = [System.Drawing.StringAlignment]::Near
            $script:keyInputFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
        } catch { }
    }
}

# -----------------------------------------------------------------------------
#  PRE-BUILD the static 'HIGH X' vector wordmark ONCE
#  Restore the original embedded Syne ExtraBold typography and established dimensions.
#  Silver/chrome rendering remains; HIGH X sizes, tracking, gap, and key-page scale are unchanged.
# -----------------------------------------------------------------------------
$script:hxCy = 209.0  # Raise Login HIGH X closer to the original position while keeping a small lower bias.
# Login wordmark proportions: HIGH stays compact, while X is visibly larger and
# sits farther away for the requested premium separation.
$hxHighEm = 62.4
$hxXEm    = 96.9
$hxHighTrack = 13.5
# Compress the HIGH glyph shapes horizontally without changing the tracking/gaps between letters.
$hxHighScaleX = 0.84
$hxXGap      = 96.0
$measBmp = New-Object System.Drawing.Bitmap(8, 8)
$measG = [System.Drawing.Graphics]::FromImage($measBmp)

# Restore the original embedded Syne ExtraBold face; keep the existing sizes,
# tracking, X gap, and logo scale unchanged from the original Key-page design.
$highFam = $script:syneExtraBoldFontFamily
if ($null -eq $highFam) {
    $highFam = $script:theNeueFontFamily
}
if ($null -eq $highFam) {
    $highFam = $script:meleteFontFamily
}
if ($null -eq $highFam) {
    $highFam = $script:hxEmbeddedFontFamily
}
if ($null -eq $highFam) {
    try { $highFam = New-Object System.Drawing.FontFamily('Segoe UI') } catch { $highFam = New-Object System.Drawing.FontFamily('Corbel') }
}
$highStyle = [System.Drawing.FontStyle]::Regular
if ($null -ne $highFam -and -not $highFam.IsStyleAvailable($highStyle)) {
    if ($highFam.IsStyleAvailable([System.Drawing.FontStyle]::Bold)) { $highStyle = [System.Drawing.FontStyle]::Bold }
    elseif ($highFam.IsStyleAvailable([System.Drawing.FontStyle]::Italic)) { $highStyle = [System.Drawing.FontStyle]::Italic }
}

$xFam = $script:syneExtraBoldFontFamily
if ($null -eq $xFam) {
    $xFam = $script:meleteFontFamily
}
if ($null -eq $xFam) {
    $xFam = $script:hxXEmbeddedFontFamily
}
if ($null -eq $xFam) {
    try { $xFam = New-Object System.Drawing.FontFamily('Segoe UI') } catch { $xFam = New-Object System.Drawing.FontFamily('Corbel') }
}
$xStyle = [System.Drawing.FontStyle]::Regular
if ($null -ne $xFam -and -not $xFam.IsStyleAvailable($xStyle)) {
    if ($xFam.IsStyleAvailable([System.Drawing.FontStyle]::Bold)) { $xStyle = [System.Drawing.FontStyle]::Bold }
    elseif ($xFam.IsStyleAvailable([System.Drawing.FontStyle]::Italic)) { $xStyle = [System.Drawing.FontStyle]::Italic }
}

$sf0 = New-Object System.Drawing.StringFormat([System.Drawing.StringFormat]::GenericTypographic)
$highText = 'HIGH'

# Build each High glyph independently so letter spacing is real tracking rather
# than a single-string approximation. This prevents the letters from visually
# touching while keeping the complete wordmark mathematically centered.
$highGlyphWidths = @()
$highNaturalW = 0.0
foreach ($hc in $highText.ToCharArray()) {
    $hf = [System.Drawing.Font]::new($highFam, [single]$hxHighEm, $highStyle, [System.Drawing.GraphicsUnit]::Pixel)
    $hw = $measG.MeasureString([string]$hc, $hf, 10000, $sf0).Width
    $hf.Dispose()
    $highGlyphWidths += [double]$hw
    $highNaturalW += [double]$hw
}
$highNaturalW += $hxHighTrack * ([math]::Max(0, $highText.Length - 1))

$xFontMeasure = [System.Drawing.Font]::new($xFam, [single]$hxXEm, $xStyle, [System.Drawing.GraphicsUnit]::Pixel)
$xNaturalW = [double]$measG.MeasureString('X', $xFontMeasure, 10000, $sf0).Width
$xFontMeasure.Dispose()

$maxW = [double]($W - 110)
$totalNaturalW = $highNaturalW + $hxXGap + $xNaturalW
if ($totalNaturalW -gt $maxW -and $totalNaturalW -gt 0) {
    $sfac = $maxW / $totalNaturalW
    $hxHighEm = $hxHighEm * $sfac
    $hxXEm = $hxXEm * $sfac
    $hxHighTrack = $hxHighTrack * $sfac
    $hxXGap = $hxXGap * $sfac
}

# Re-measure after any proportional fit-to-window scaling.
$highGlyphWidths = @()
$highNaturalW = 0.0
foreach ($hc in $highText.ToCharArray()) {
    $hf = [System.Drawing.Font]::new($highFam, [single]$hxHighEm, $highStyle, [System.Drawing.GraphicsUnit]::Pixel)
    $hw = $measG.MeasureString([string]$hc, $hf, 10000, $sf0).Width
    $hf.Dispose()
    $highGlyphWidths += [double]$hw
    $highNaturalW += [double]$hw
}
$highNaturalW += $hxHighTrack * ([math]::Max(0, $highText.Length - 1))
$xFontMeasure = [System.Drawing.Font]::new($xFam, [single]$hxXEm, $xStyle, [System.Drawing.GraphicsUnit]::Pixel)
$xNaturalW = [double]$measG.MeasureString('X', $xFontMeasure, 10000, $sf0).Width
$xFontMeasure.Dispose()

$highFont = [System.Drawing.Font]::new($highFam, [single]$hxHighEm, $highStyle, [System.Drawing.GraphicsUnit]::Pixel)
$xFont = [System.Drawing.Font]::new($xFam, [single]$hxXEm, $xStyle, [System.Drawing.GraphicsUnit]::Pixel)

# Measure the actual glyph bounds so the final composite is centered by its
# visible geometry, not by nominal font advance widths. This also removes the
# slight optical drift caused by GDI+ side bearings on the larger X.
$highProbe = [System.Drawing.Drawing2D.GraphicsPath]::new()
$probeX = 0.0
for ($i = 0; $i -lt $highText.Length; $i++) {
    $glyphProbe = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $glyphProbe.AddString(
        [string]$highText[$i],
        $highFam,
        [int]$highStyle,
        [single]$hxHighEm,
        ([System.Drawing.PointF]::new([single]$probeX, 0)),
        $sf0
    )
    # Narrow the glyph itself, not the spacing between HIGH letters.
    $gb = $glyphProbe.GetBounds()
    $tx = [single]($gb.X * (1.0 - $hxHighScaleX))
    $gm = [System.Drawing.Drawing2D.Matrix]::new([single]$hxHighScaleX,0,0,1,[single]$tx,0)
    $glyphProbe.Transform($gm)
    $gm.Dispose()
    $highProbe.AddPath($glyphProbe, $false)
    $glyphProbe.Dispose()
    $probeX += [double]$highGlyphWidths[$i]
    if ($i -lt ($highText.Length - 1)) { $probeX += $hxHighTrack }
}
$highBounds = $highProbe.GetBounds()
$highProbe.Dispose()

$xProbe = [System.Drawing.Drawing2D.GraphicsPath]::new()
$xProbe.AddString('X', $xFam, [int]$xStyle, [single]$hxXEm, ([System.Drawing.PointF]::new(0,0)), $sf0)
$xBounds = $xProbe.GetBounds()
$xProbe.Dispose()

$drawHighX = [System.Drawing.Drawing2D.GraphicsPath]::new()
$drawHighPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
$drawXPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
$drawHighLetterPaths = New-Object System.Collections.ArrayList
$xY = $script:hxCy - ($xBounds.Height / 2.0) - $xBounds.Y
# Align HIGH to the same visible bottom edge as X instead of centering HIGH vertically
# inside X. This makes both wordmark elements sit on the same lower visual line.
$highY = $xY + $xBounds.Y + $xBounds.Height - $highBounds.Y - $highBounds.Height

$highX = 0.0
for ($i = 0; $i -lt $highText.Length; $i++) {
    $glyphPoint = [System.Drawing.PointF]::new([single]$highX, [single]$highY)
    $glyphPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $glyphPath.AddString(
        [string]$highText[$i],
        $highFam,
        [int]$highStyle,
        [single]$hxHighEm,
        $glyphPoint,
        $sf0
    )
    # Horizontally squeeze only the letterform. Tracking remains unchanged.
    $gb = $glyphPath.GetBounds()
    $tx = [single]($gb.X * (1.0 - $hxHighScaleX))
    $gm = [System.Drawing.Drawing2D.Matrix]::new([single]$hxHighScaleX,0,0,1,[single]$tx,0)
    $glyphPath.Transform($gm)
    $gm.Dispose()
    $drawHighX.AddPath($glyphPath, $false)
    $drawHighPath.AddPath($glyphPath, $false)
    [void]$drawHighLetterPaths.Add($glyphPath.Clone())
    $glyphPath.Dispose()
    if ($i -lt ($highText.Length - 1)) { $highX += [double]$highGlyphWidths[$i] + $hxHighTrack }
}

# Keep X on the same optical baseline, but give it a deliberately wider premium gap from HIGH.
$xDrawLeft = [double]($highX + $hxXGap)
$xPoint = [System.Drawing.PointF]::new([single]$xDrawLeft, [single]$xY)
$drawHighX.AddString(
    'X',
    $xFam,
    [int]$xStyle,
    [single]$hxXEm,
    $xPoint,
    $sf0
)
$hxXPathForGlow = [System.Drawing.Drawing2D.GraphicsPath]::new()
$hxXPathForGlow.AddString(
    'X',
    $xFam,
    [int]$xStyle,
    [single]$hxXEm,
    $xPoint,
    $sf0
)
[void]$drawHighLetterPaths.Add($hxXPathForGlow)
$drawXPath.AddString(
    'X',
    $xFam,
    [int]$xStyle,
    [single]$hxXEm,
    $xPoint,
    $sf0
)
$sf0.Dispose()

# Optical centering: center the visible ink mass of the complete HIGH X composition,
# rather than relying only on font advance/bounds. This keeps the heavier/larger X
# from making the wordmark look visually shifted to the right.
$rawBounds = $drawHighX.GetBounds()
$opticalCX = [double]($rawBounds.X + ($rawBounds.Width / 2.0))
$opticalCY = [double]($rawBounds.Y + ($rawBounds.Height / 2.0))
$optPad = 10
$optW = [int][math]::Ceiling($rawBounds.Width + ($optPad * 2) + 2)
$optH = [int][math]::Ceiling($rawBounds.Height + ($optPad * 2) + 2)
if ($optW -gt 0 -and $optH -gt 0) {
    try {
        $optBmp = New-Object System.Drawing.Bitmap($optW, $optH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $optG = [System.Drawing.Graphics]::FromImage($optBmp)
        $optG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $optG.Clear([System.Drawing.Color]::Transparent)
        $optG.TranslateTransform([single]($optPad - $rawBounds.X), [single]($optPad - $rawBounds.Y))
        $optBr = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $optG.FillPath($optBr, $drawHighX)
        $optBr.Dispose()
        $optG.Dispose()

        $optRect = [System.Drawing.Rectangle]::new(0,0,$optW,$optH)
        $optLock = $optBmp.LockBits($optRect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $optBytes = New-Object byte[] ($optW * $optH * 4)
        [System.Runtime.InteropServices.Marshal]::Copy($optLock.Scan0, $optBytes, 0, $optBytes.Length)
        $optBmp.UnlockBits($optLock)

        [double]$sumA = 0.0
        [double]$sumX = 0.0
        [double]$sumY = 0.0
        for ($oy = 0; $oy -lt $optH; $oy++) {
            $rowBase = $oy * $optW * 4
            for ($ox = 0; $ox -lt $optW; $ox++) {
                $idx = $rowBase + ($ox * 4)
                $aa = [double]$optBytes[$idx + 3]
                if ($aa -gt 0.0) {
                    $sumA += $aa
                    $sumX += $ox * $aa
                    $sumY += $oy * $aa
                }
            }
        }
        if ($sumA -gt 0.0) {
            # Convert centroid from temporary bitmap coordinates back to the original path space.
            $opticalCX = [double]($rawBounds.X + (($sumX / $sumA) - $optPad))
            $opticalCY = [double]($rawBounds.Y + (($sumY / $sumA) - $optPad))
        }
        $optBmp.Dispose()
    } catch {
        try { if ($null -ne $optG) { $optG.Dispose() } } catch { }
        try { if ($null -ne $optBmp) { $optBmp.Dispose() } } catch { }
    }
}

$hxTargetCX = [double]$script:loginOpticalCenterX
$shiftX = $hxTargetCX - $opticalCX
$shiftY = $script:hxCy - $opticalCY
$moveMx = New-Object System.Drawing.Drawing2D.Matrix
$moveMx.Translate([single]$shiftX, [single]$shiftY)
$drawHighX.Transform($moveMx)
$drawHighPath.Transform($moveMx)
$drawXPath.Transform($moveMx)
foreach ($lp in $drawHighLetterPaths) {
    try { $lp.Transform($moveMx) } catch { }
}
$moveMx.Dispose()

$script:hxPath = $drawHighX
$script:hxHighPath = $drawHighPath
$script:hxXPath = $drawXPath
$script:hxBounds = $drawHighX.GetBounds()
# Cache the X ink bounds separately so the metallic light sweep stays on X only.
$script:hxXBounds = $drawXPath.GetBounds()
$script:hxLetterPaths = $drawHighLetterPaths
$script:hxLetterCenters = @()
foreach ($lp in $script:hxLetterPaths) {
    $lb = $lp.GetBounds()
    $script:hxLetterCenters += ([System.Drawing.PointF]::new(
        [single]($lb.X + $lb.Width / 2.0),
        [single]($lb.Y + $lb.Height / 2.0)
    ))
}

# Pre-render the title bloom once. The title path is static, so the expensive
# blur never runs inside Paint; every frame draws one already-soft bitmap.
# Keep a generous transparent safety margin around the wordmark so the soft
# bloom can fade naturally past the glyph edges instead of being cropped by
# the offscreen surface into a visible rectangular cutoff.
try {
    $hxPad = 76
    $hxGlowW = [int][math]::Ceiling($script:hxBounds.Width + ($hxPad * 2))
    $hxGlowH = [int][math]::Ceiling($script:hxBounds.Height + ($hxPad * 2))
    $hxMask = New-Object System.Drawing.Bitmap($hxGlowW, $hxGlowH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $hxMaskG = [System.Drawing.Graphics]::FromImage($hxMask)
    $hxMaskG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $hxMaskG.Clear([System.Drawing.Color]::Transparent)
    $hxMaskG.TranslateTransform([single]($hxPad - $script:hxBounds.X), [single]($hxPad - $script:hxBounds.Y))
    $hxMaskBr = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $hxMaskG.FillPath($hxMaskBr, $script:hxPath)
    $hxMaskBr.Dispose()
    $hxMaskG.Dispose()

    $hxLen = $hxGlowW * $hxGlowH
    $hxLock = $hxMask.LockBits(([System.Drawing.Rectangle]::new(0,0,$hxGlowW,$hxGlowH)), [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $hxPixels = New-Object 'int[]' $hxLen
    [System.Runtime.InteropServices.Marshal]::Copy($hxLock.Scan0, $hxPixels, 0, $hxLen)
    $hxMask.UnlockBits($hxLock)

    # Keep the original anti-aliased glyph alpha as the only source for the
    # animated light. The same soft alpha field is reused by the animation.
    $script:hxGlyphMaskPixels = New-Object 'int[]' $hxLen
    [array]::Copy($hxPixels, $script:hxGlyphMaskPixels, $hxLen)

    # A wider, softer pre-blurred copy is computed once. The moving bloom samples
    # this soft silhouette every frame, so the Paint loop never runs a blur.
    $script:hxBloomMaskPixels = New-Object 'int[]' $hxLen
    [array]::Copy($hxPixels, $script:hxBloomMaskPixels, $hxLen)
    [SoftGlowFx]::BoxBlurAlpha($script:hxBloomMaskPixels, $hxGlowW, $hxGlowH, 11, 4, 0.80)

    # Preallocate one fused ARGB surface plus working arrays. Every frame only updates their pixels;
    # no PathGradientBrush/ellipse layer is created during Paint.
    $script:hxSpotW = $hxGlowW
    $script:hxSpotH = $hxGlowH
    $script:hxSpotCorePixels = New-Object 'int[]' $hxLen
    $script:hxSpotBloomPixels = New-Object 'int[]' $hxLen
    $script:hxSpotCombinedPixels = New-Object 'int[]' $hxLen
    $script:hxSpotCombinedBitmap = New-Object System.Drawing.Bitmap($hxGlowW, $hxGlowH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    # Static fallback bloom remains available for the existing UI surface; the
    # moving effect uses hxBloomMaskPixels so no blur runs during Paint.
    [SoftGlowFx]::BoxBlurAlpha($hxPixels, $hxGlowW, $hxGlowH, 10, 2, 0.78)

    $hxGlow = New-Object System.Drawing.Bitmap($hxGlowW, $hxGlowH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $hxWrite = $hxGlow.LockBits(([System.Drawing.Rectangle]::new(0,0,$hxGlowW,$hxGlowH)), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    # Color the full blurred alpha field a neutral silver-white. No hard outline is stored.
    for ($i=0; $i -lt $hxPixels.Length; $i++) {
        $a = ($hxPixels[$i] -shr 24) -band 0xFF
        # Keep the text itself crisp; only this diffuse outside-glyph halo is halved.
        $a = [int][math]::Round($a * 0.50)
        $hxPixels[$i] = ($a -shl 24) -bor 0x00D7DCE5
    }
    [System.Runtime.InteropServices.Marshal]::Copy($hxPixels, 0, $hxWrite.Scan0, $hxLen)
    $hxGlow.UnlockBits($hxWrite)
    $script:hxGlowBitmap = $hxGlow
    $script:hxGlowX = [int][math]::Floor($script:hxBounds.X - $hxPad)
    # The bitmap intentionally extends well beyond the visible glyphs; keep
    # the alpha field transparent out to the full blur falloff.
    $script:hxGlowY = [int][math]::Floor($script:hxBounds.Y - $hxPad)
    $hxMask.Dispose()
} catch {
    try { if ($null -ne $hxMask) { $hxMask.Dispose() } } catch { }
    $script:hxGlowBitmap = $null
    $script:hxGlowX = 0
    $script:hxGlowY = 0
}

$script:hxXCenter = [single]($script:hxBounds.X + $script:hxBounds.Width / 2.0)
# SCRIPT sits just below the visible HIGH X ink, using the actual wordmark bounds
# rather than a fixed offset from the title center.
if (-not [object]::ReferenceEquals($highFam, $xFam)) { $xFam.Dispose() }
$highFam.Dispose()
$measG.Dispose(); $measBmp.Dispose()
$highFont.Dispose(); $xFont.Dispose()

# -----------------------------------------------------------------------------
#  Premium metallic wordmark renderer (defined once, reused every frame)
# -----------------------------------------------------------------------------
# HIGH uses a restrained silver-chrome gradient; X is marginally brighter.
# A single diagonal in-glyph reflection travels across X and remains clipped
# to the existing vector lettering—no detached rays or extra background layers.
function Update-HighXLightField {
    param([double]$spotX,[double]$spotY,[double]$intensity)

    if ($null -eq $script:hxGlyphMaskPixels -or $null -eq $script:hxSpotCombinedBitmap) { return }
    try {
        $localX = $spotX - [double]$script:hxGlowX
        $localY = $spotY - [double]$script:hxGlowY

        [HighXGlyphFxPremiumChrome]::RenderSpot(
            $script:hxGlyphMaskPixels,
            $script:hxBloomMaskPixels,
            $script:hxSpotCorePixels,
            $script:hxSpotBloomPixels,
            $script:hxSpotW,
            $script:hxSpotH,
            $localX,
            $localY,
            24.0,
            3.6,
            32.0,
            9.5,
            $intensity,
            -43.0
        )

        # The bloom source is already softly blurred once at startup; here it is
        # only multiplied by the moving light field, keeping the animation light-weight.

        # Fuse the core + bloom into one alpha field before drawing.
        # Visually this reads as one luminous phenomenon, not stacked layers.
        [HighXGlyphFxPremiumChrome]::CombineLight(
            $script:hxSpotCorePixels,
            $script:hxSpotBloomPixels,
            $script:hxSpotCombinedPixels,
            $script:hxSpotW,
            $script:hxSpotH
        )

        $rect = [System.Drawing.Rectangle]::new(0,0,$script:hxSpotW,$script:hxSpotH)
        $lockCombined = $script:hxSpotCombinedBitmap.LockBits(
            $rect,
            [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        [System.Runtime.InteropServices.Marshal]::Copy(
            $script:hxSpotCombinedPixels,
            0,
            $lockCombined.Scan0,
            $script:hxSpotCombinedPixels.Length
        )
        $script:hxSpotCombinedBitmap.UnlockBits($lockCombined)
    } catch { }
}

function New-HXMetallicBrush {
    param($Bounds, [string]$Tone = 'high')

    if ($null -eq $Bounds) { return $null }
    $rect = [System.Drawing.RectangleF]::new(
        [single]($Bounds.X - 1.0),
        [single]($Bounds.Y - 1.0),
        [single]([math]::Max(1.0, $Bounds.Width + 2.0)),
        [single]([math]::Max(1.0, $Bounds.Height + 2.0))
    )
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $rect,
        [System.Drawing.Color]::FromArgb(248, 246, 248, 251),
        [System.Drawing.Color]::FromArgb(248, 231, 235, 241),
        [single]90
    )
    try {
        # Subtle, broad silver reflections suggest polished/brushed chrome without striping the letters.
        $blend = [System.Drawing.Drawing2D.ColorBlend]::new(5)
        $blend.Positions = [single[]]@(0.0, 0.22, 0.44, 0.70, 1.0)
        if ($Tone -eq 'x') {
            $blend.Colors = [System.Drawing.Color[]]@(
                [System.Drawing.Color]::FromArgb(250, 252, 253, 255),
                [System.Drawing.Color]::FromArgb(246, 222, 227, 235),
                [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
                [System.Drawing.Color]::FromArgb(246, 216, 222, 231),
                [System.Drawing.Color]::FromArgb(250, 245, 247, 250)
            )
        } else {
            $blend.Colors = [System.Drawing.Color[]]@(
                [System.Drawing.Color]::FromArgb(248, 246, 248, 251),
                [System.Drawing.Color]::FromArgb(246, 222, 226, 233),
                [System.Drawing.Color]::FromArgb(252, 251, 252, 254),
                [System.Drawing.Color]::FromArgb(244, 216, 221, 229),
                [System.Drawing.Color]::FromArgb(248, 239, 242, 246)
            )
        }
        $brush.InterpolationColors = $blend
        return $brush
    } catch {
        $brush.Dispose()
        throw
    }
}

function Draw-ShinyHighX {
    param($graphics)

    if ($null -eq $script:hxPath) { return }

    # Create once and cache. HIGH uses a restrained silver gradient; X gets a slightly
    # brighter chrome highlight so the larger glyph remains the visual focal point.
    if ($null -eq $script:hxHighBaseBrush -and $null -ne $script:hxHighPath) {
        $script:hxHighBaseBrush = New-HXMetallicBrush -Bounds ($script:hxHighPath.GetBounds()) -Tone 'high'
    }
    if ($null -eq $script:hxXGradientBrush -and $null -ne $script:hxXPath) {
        $script:hxXGradientBrush = New-HXMetallicBrush -Bounds ($script:hxXPath.GetBounds()) -Tone 'x'
    }
    if ($null -eq $script:hxHighEdgePen) {
        $script:hxHighEdgePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(38, 255, 255, 255), [single]0.42)
        $script:hxHighEdgePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    }
    if ($null -eq $script:hxXEdgePen) {
        $script:hxXEdgePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(58, 255, 255, 255), [single]0.48)
        $script:hxXEdgePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    }
    if ($null -ne $script:hxHighPath -and $null -ne $script:hxHighBaseBrush) {
        $graphics.FillPath($script:hxHighBaseBrush, $script:hxHighPath)
        # Hairline edge reflection only: intentionally far below a visible outline weight.
        if ($null -ne $script:hxHighEdgePen) { $graphics.DrawPath($script:hxHighEdgePen, $script:hxHighPath) }
    }
    if ($null -ne $script:hxXPath -and $null -ne $script:hxXGradientBrush) {
        $graphics.FillPath($script:hxXGradientBrush, $script:hxXPath)
        if ($null -ne $script:hxXEdgePen) { $graphics.DrawPath($script:hxXEdgePen, $script:hxXPath) }
    }

    # The moving light is rendered into a prepared bitmap outside Paint.
    if ($null -ne $script:hxSpotCombinedBitmap) {
        $oldComp = $graphics.CompositingMode
        $oldInterp = $graphics.InterpolationMode
        $oldPixel = $graphics.PixelOffsetMode
        try {
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
            $graphics.DrawImageUnscaled($script:hxSpotCombinedBitmap, $script:hxGlowX, $script:hxGlowY)
        } finally {
            $graphics.CompositingMode = $oldComp
            $graphics.InterpolationMode = $oldInterp
            $graphics.PixelOffsetMode = $oldPixel
        }
    }

}

# Reusable Penna SCRIPT wordmark, shared by the Key brand area and the dormant legacy launch composition.
# Keep the same font, tracking, colour and glyph-by-glyph path construction as the original Login visual.
function Update-HighXLightFrame {
    # Render one restrained diagonal chrome reflection only over X. The prebuilt
    # glyph mask clips the light to the real letter shape; the rest of HIGH stays calm.
    if ($null -eq $script:hxXBounds -or $null -eq $script:hxSpotCombinedBitmap) { return }
    try {
        $phase = [double]$script:shinyPhase
        if ($phase -lt 0.0) { $phase = 0.0 }
        if ($phase -gt 1.0) { $phase = 1.0 }

        $travelEase = 0.5 - (0.5 * [math]::Cos([math]::PI * $phase))
        # Travel through the inner portion of X, leaving a little breathing room at each corner.
        $spotX = [double]($script:hxXBounds.Left + ($script:hxXBounds.Width * (0.18 + (0.64 * $travelEase))))
        $spotY = [double]($script:hxXBounds.Bottom - ($script:hxXBounds.Height * (0.18 + (0.64 * $travelEase))))

        $wrap = 1.0
        if ($phase -lt 0.075) {
            $wrap = ($phase / 0.075)
        } elseif ($phase -gt 0.925) {
            $wrap = ((1.0 - $phase) / 0.075)
        }
        $intensity = [double](0.40 * [math]::Min(1.0, [math]::Max(0.0, $wrap)))

        [void](Update-HighXLightField $spotX $spotY $intensity)
        $script:hxLastRenderPhase = $phase
        $script:hxLightDirty = $false
    } catch {
        # Keep the last good light frame if a transient GDI resource hiccup occurs.
    }
}

function Draw-HXWindowControls {
    param($graphics, [double]$clientWidth)
    $cx = [single]($clientWidth - 28.0)
    $cy = [single]($headerCtlY + $headerCtlSize/2.0)
    $mx = [single]($clientWidth - 60.0)
    $my = $cy

    if ($null -eq $script:closeGlowPen) {
        if ($script:page -eq 'main') {
            $controlGlowColor = [System.Drawing.Color]::FromArgb(18, 70, 77, 88)
            $controlCoreColor = [System.Drawing.Color]::FromArgb(190, 67, 74, 84)
        } else {
            $controlGlowColor = [System.Drawing.Color]::FromArgb(34,220,222,227)
            $controlCoreColor = [System.Drawing.Color]::FromArgb(184,226,227,231)
        }
        $script:closeGlowPen = [System.Drawing.Pen]::new($controlGlowColor, [single]2.4)
        $script:minGlowPen = [System.Drawing.Pen]::new($controlGlowColor, [single]2.4)
        $script:closeCorePen = [System.Drawing.Pen]::new($controlCoreColor, [single]0.9)
        $script:minCorePen = [System.Drawing.Pen]::new($controlCoreColor, [single]0.9)
        foreach ($pen in @($script:closeGlowPen,$script:minGlowPen,$script:closeCorePen,$script:minCorePen)) {
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        }
    }
    if ($script:hover -eq 'close') {
        if ($null -eq $script:closeHoverBrush) {
            $closeHoverColor = if ($script:page -eq 'main') { [System.Drawing.Color]::FromArgb(22,70,77,88) } else { [System.Drawing.Color]::FromArgb(34,220,222,227) }
            $script:closeHoverBrush = [System.Drawing.SolidBrush]::new($closeHoverColor)
        }
        $graphics.FillEllipse($script:closeHoverBrush, [single]($cx-10), [single]($cy-10), 20.0, 20.0)
    } elseif ($script:hover -eq 'min') {
        if ($null -eq $script:minHoverBrush) {
            $minHoverColor = if ($script:page -eq 'main') { [System.Drawing.Color]::FromArgb(18,70,77,88) } else { [System.Drawing.Color]::FromArgb(24,180,184,190) }
            $script:minHoverBrush = [System.Drawing.SolidBrush]::new($minHoverColor)
        }
        $graphics.FillEllipse($script:minHoverBrush, [single]($mx-10), [single]($my-10), 20.0, 20.0)
    }
    $s = 4.1
    $graphics.DrawLine($script:closeGlowPen, $cx-$s, $cy-$s, $cx+$s, $cy+$s)
    $graphics.DrawLine($script:closeGlowPen, $cx+$s, $cy-$s, $cx-$s, $cy+$s)
    $graphics.DrawLine($script:closeCorePen, $cx-$s, $cy-$s, $cx+$s, $cy+$s)
    $graphics.DrawLine($script:closeCorePen, $cx+$s, $cy-$s, $cx-$s, $cy+$s)
    $graphics.DrawLine($script:minGlowPen, $mx-4.2, $my, $mx+4.2, $my)
    $graphics.DrawLine($script:minCorePen, $mx-4.2, $my, $mx+4.2, $my)
}


# -----------------------------------------------------------------------------
#  MAIN DASHBOARD : native GDI+ drawing only (no screenshot/background image)
# -----------------------------------------------------------------------------
function Draw-HSSafeArc {
    param(
        $Graphics,
        [System.Drawing.Pen]$Pen,
        [System.Drawing.RectangleF]$Bounds,
        [single]$StartAngle,
        [single]$SweepAngle,
        [single]$MaxStepDegrees = 3.5
    )

    # GDI+ can report a misleading OutOfMemoryException for invalid arc geometry.
    # Validate all inputs and draw the arc as a bounded polyline instead of calling Graphics.DrawArc.
    if ($null -eq $Graphics -or $null -eq $Pen) { return }
    $bx = [double]$Bounds.X
    $by = [double]$Bounds.Y
    $bw = [double]$Bounds.Width
    $bh = [double]$Bounds.Height
    $start = [double]$StartAngle
    $sweep = [double]$SweepAngle
    $step = [double]$MaxStepDegrees
    foreach ($value in @($bx,$by,$bw,$bh,$start,$sweep,$step)) {
        if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) { return }
    }
    if ($bw -le 0.5 -or $bh -le 0.5 -or [math]::Abs($sweep) -le 0.15 -or $step -le 0.0) { return }

    # A complete circle is more accurate as an ellipse and avoids a 360-degree arc edge case.
    if ([math]::Abs($sweep) -ge 359.95) {
        $Graphics.DrawEllipse($Pen, $Bounds)
        return
    }

    $segments = [int][math]::Ceiling([math]::Abs($sweep) / $step)
    $segments = [int][math]::Max(4, [math]::Min(128, $segments))
    $points = New-Object 'System.Drawing.PointF[]' ($segments + 1)
    $rx = $bw / 2.0
    $ry = $bh / 2.0
    $cx = $bx + $rx
    $cy = $by + $ry
    for ($i = 0; $i -le $segments; $i++) {
        $angle = ($start + ($sweep * ($i / [double]$segments))) * ([math]::PI / 180.0)
        $px = $cx + ([math]::Cos($angle) * $rx)
        $py = $cy + ([math]::Sin($angle) * $ry)
        if ([double]::IsNaN($px) -or [double]::IsInfinity($px) -or [double]::IsNaN($py) -or [double]::IsInfinity($py)) { return }
        $points[$i] = [System.Drawing.PointF]::new([single]$px, [single]$py)
    }
    $Graphics.DrawLines($Pen, $points)
}

function Draw-HSMainIcon {
    param(
        $graphics,
        [string]$kind,
        [single]$x,
        [single]$y,
        [single]$size,
        [System.Drawing.Color]$color,
        [bool]$filled = $false
    )

    # Unified premium outline language: balanced silhouettes, rounded joins, and no heavy fills.
    $lineWidth = [single][math]::Max(1.22, [double]$size * 0.060)
    $pen = [System.Drawing.Pen]::new($color, $lineWidth)
    $brush = [System.Drawing.SolidBrush]::new($color)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    try {
        $cx = [single]($x + ($size / 2.0))
        $cy = [single]($y + ($size / 2.0))
        switch ($kind) {
            'home' {
                # Quiet architectural home mark: one roof, open base, and centered doorway.
                $roof = [System.Drawing.PointF[]]@(
                    [System.Drawing.PointF]::new([single]($x + $size*0.14), [single]($y + $size*0.43)),
                    [System.Drawing.PointF]::new($cx, [single]($y + $size*0.16)),
                    [System.Drawing.PointF]::new([single]($x + $size*0.86), [single]($y + $size*0.43))
                )
                $graphics.DrawLines($pen, $roof)
                $graphics.DrawLine($pen, [single]($x+$size*0.25), [single]($y+$size*0.41), [single]($x+$size*0.25), [single]($y+$size*0.82))
                $graphics.DrawLine($pen, [single]($x+$size*0.75), [single]($y+$size*0.41), [single]($x+$size*0.75), [single]($y+$size*0.82))
                $graphics.DrawLine($pen, [single]($x+$size*0.25), [single]($y+$size*0.82), [single]($x+$size*0.42), [single]($y+$size*0.82))
                $graphics.DrawLine($pen, [single]($x+$size*0.58), [single]($y+$size*0.82), [single]($x+$size*0.75), [single]($y+$size*0.82))
                $graphics.DrawLine($pen, [single]($x+$size*0.42), [single]($y+$size*0.82), [single]($x+$size*0.42), [single]($y+$size*0.62))
                $graphics.DrawLine($pen, [single]($x+$size*0.58), [single]($y+$size*0.82), [single]($x+$size*0.58), [single]($y+$size*0.62))
                $graphics.DrawLine($pen, [single]($x+$size*0.42), [single]($y+$size*0.62), [single]($x+$size*0.58), [single]($y+$size*0.62))
            }
            'system' {
                # System Tuning: a clean monitor outline with a compact settings gear.
                # Draw with lines and ellipses only; no bitmap assets or arc calls.
                $screenLeft   = [single]($x + $size*0.14)
                $screenRight  = [single]($x + $size*0.84)
                $screenTop    = [single]($y + $size*0.16)
                $screenBottom = [single]($y + $size*0.61)
                $graphics.DrawLine($pen, $screenLeft,  $screenTop,    $screenRight, $screenTop)
                $graphics.DrawLine($pen, $screenLeft,  $screenTop,    $screenLeft,  $screenBottom)
                $graphics.DrawLine($pen, $screenRight, $screenTop,    $screenRight, $screenBottom)
                $graphics.DrawLine($pen, $screenLeft,  $screenBottom, $screenRight, $screenBottom)

                # Slim monitor stand and a short, centered foot.
                $standX = [single]($x + $size*0.49)
                $graphics.DrawLine($pen, $standX, [single]($y+$size*0.62), $standX, [single]($y+$size*0.78))
                $graphics.DrawLine($pen, [single]($x+$size*0.35), [single]($y+$size*0.81), [single]($x+$size*0.64), [single]($y+$size*0.81))

                # A small gear overlaps the lower-right bezel to communicate system settings.
                $gearCx = [single]($x + $size*0.75)
                $gearCy = [single]($y + $size*0.67)
                $gearR  = [single]($size*0.125)
                $toothR = [single]($size*0.17)
                $graphics.DrawEllipse($pen, [single]($gearCx-$gearR), [single]($gearCy-$gearR), [single]($gearR*2.0), [single]($gearR*2.0))
                $graphics.DrawLine($pen, [single]($gearCx-$toothR), $gearCy, [single]($gearCx-$gearR*0.78), $gearCy)
                $graphics.DrawLine($pen, [single]($gearCx+$gearR*0.78), $gearCy, [single]($gearCx+$toothR), $gearCy)
                $graphics.DrawLine($pen, $gearCx, [single]($gearCy-$toothR), $gearCx, [single]($gearCy-$gearR*0.78))
                $graphics.DrawLine($pen, $gearCx, [single]($gearCy+$gearR*0.78), $gearCx, [single]($gearCy+$toothR))
                $gearCore = [single][math]::Max(1.0, [double]$size*0.065)
                $graphics.FillEllipse($brush, [single]($gearCx-$gearCore/2.0), [single]($gearCy-$gearCore/2.0), $gearCore, $gearCore)
            }
            'latency' {
                # Precision Gauge: an open circular dial, restrained tick marks, and a crisp response needle.
                # The lower gap keeps the silhouette light at sidebar size and distinct from the Nexus rings.
                $dialD = [single]($size * 0.78)
                $dialX = [single]($cx - $dialD / 2.0)
                $dialY = [single]($cy - $dialD / 2.0)
                $gaugeDetailPen = $null
                try {
                    $detailAlpha = [int][math]::Round([double]$color.A * 0.68)
                    $detailColor = [System.Drawing.Color]::FromArgb($detailAlpha, $color.R, $color.G, $color.B)
                    $gaugeDetailPen = [System.Drawing.Pen]::new($detailColor, [single][math]::Max(1.0, [double]$size * 0.043))
                    $gaugeDetailPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                    $gaugeDetailPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                    $gaugeDetailPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

                    # Main dial: a 270-degree arc leaves a clear opening at the bottom.
                    $graphics.DrawArc($pen, $dialX, $dialY, $dialD, $dialD, [single]135.0, [single]270.0)

                    # Five quiet radial ticks add precision without crowding a 20–24 px glyph.
                    foreach ($tickAngle in [double[]]@(150.0, 200.0, 250.0, 300.0, 350.0, 400.0)) {
                        $tickRadians = $tickAngle * ([math]::PI / 180.0)
                        $tickInnerR = [single]($size * 0.275)
                        $tickOuterR = [single]($size * 0.345)
                        $tickX1 = [single]($cx + ([math]::Cos($tickRadians) * $tickInnerR))
                        $tickY1 = [single]($cy + ([math]::Sin($tickRadians) * $tickInnerR))
                        $tickX2 = [single]($cx + ([math]::Cos($tickRadians) * $tickOuterR))
                        $tickY2 = [single]($cy + ([math]::Sin($tickRadians) * $tickOuterR))
                        $graphics.DrawLine($gaugeDetailPen, $tickX1, $tickY1, $tickX2, $tickY2)
                    }

                    # The needle points into the upper-right performance range.
                    $needleAngle = 310.0 * ([math]::PI / 180.0)
                    $needleR = [single]($size * 0.245)
                    $needleX = [single]($cx + ([math]::Cos($needleAngle) * $needleR))
                    $needleY = [single]($cy + ([math]::Sin($needleAngle) * $needleR))
                    $graphics.DrawLine($pen, $cx, $cy, $needleX, $needleY)

                    # Small central hub anchors the needle and improves legibility at compact size.
                    $hubD = [single]($size * 0.17)
                    $hubX = [single]($cx - $hubD / 2.0)
                    $hubY = [single]($cy - $hubD / 2.0)
                    $graphics.DrawEllipse($gaugeDetailPen, $hubX, $hubY, $hubD, $hubD)
                    $hubCoreD = [single]($size * 0.075)
                    $graphics.FillEllipse($brush,
                        [single]($cx - $hubCoreD / 2.0),
                        [single]($cy - $hubCoreD / 2.0),
                        $hubCoreD, $hubCoreD)
                } finally {
                    if ($null -ne $gaugeDetailPen) { $gaugeDetailPen.Dispose() }
                }
            }

            'orbit' {
                # Premium Orbit: two elegant orbital paths, a clear central body, and balanced satellites.
                # The primary ring carries the silhouette; the secondary ring uses a softer stroke
                # to add depth without making the glyph busy at the 22 px sidebar size.
                $orbitPen = $null
                try {
                    $secondaryAlpha = [int][math]::Round([double]$color.A * 0.70)
                    $secondaryColor = [System.Drawing.Color]::FromArgb($secondaryAlpha, $color.R, $color.G, $color.B)
                    $orbitPen = [System.Drawing.Pen]::new($secondaryColor, [single][math]::Max(1.0, [double]$size * 0.045))
                    $orbitPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                    $orbitPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                    $orbitPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

                    # Main orbit: a broad, gently tilted ellipse. A small opening faces the satellite.
                    $orbitState = $graphics.Save()
                    try {
                        $graphics.TranslateTransform($cx, $cy)
                        $graphics.RotateTransform(-32.0)
                        $mainOrbitW = [single]($size * 0.86)
                        $mainOrbitH = [single]($size * 0.40)
                        $graphics.DrawArc($pen,
                            [single](-$mainOrbitW / 2.0),
                            [single](-$mainOrbitH / 2.0),
                            $mainOrbitW,
                            $mainOrbitH,
                            [single]22.0,
                            [single]316.0
                        )
                    } finally {
                        $graphics.Restore($orbitState)
                    }

                    # Secondary orbit: a slimmer cross-angle trajectory creates the orbital signature.
                    $orbitState = $graphics.Save()
                    try {
                        $graphics.TranslateTransform($cx, $cy)
                        $graphics.RotateTransform(47.0)
                        $secondaryOrbitW = [single]($size * 0.70)
                        $secondaryOrbitH = [single]($size * 0.31)
                        $graphics.DrawArc($orbitPen,
                            [single](-$secondaryOrbitW / 2.0),
                            [single](-$secondaryOrbitH / 2.0),
                            $secondaryOrbitW,
                            $secondaryOrbitH,
                            [single]202.0,
                            [single]316.0
                        )
                    } finally {
                        $graphics.Restore($orbitState)
                    }

                    # A fine halo separates the nucleus from crossing orbit paths.
                    $haloD = [single]($size * 0.29)
                    $graphics.DrawEllipse($orbitPen,
                        [single]($cx - $haloD / 2.0),
                        [single]($cy - $haloD / 2.0),
                        $haloD,
                        $haloD
                    )

                    # Center planet: stronger than the tracks so the icon remains readable at small sizes.
                    $planetD = [single]($size * 0.155)
                    $graphics.FillEllipse($brush,
                        [single]($cx - $planetD / 2.0),
                        [single]($cy - $planetD / 2.0),
                        $planetD,
                        $planetD
                    )

                    # Leading satellite: solid, placed just beyond the primary orbit's upper-right arc.
                    $satelliteD = [single]($size * 0.165)
                    $satelliteX = [single]($x + $size * 0.805)
                    $satelliteY = [single]($y + $size * 0.292)
                    $graphics.FillEllipse($brush,
                        [single]($satelliteX - $satelliteD / 2.0),
                        [single]($satelliteY - $satelliteD / 2.0),
                        $satelliteD,
                        $satelliteD
                    )

                    # Counterweight satellite: a small open node keeps the silhouette balanced, not crowded.
                    $satellite2D = [single]($size * 0.135)
                    $satellite2X = [single]($x + $size * 0.235)
                    $satellite2Y = [single]($y + $size * 0.285)
                    $graphics.DrawEllipse($orbitPen,
                        [single]($satellite2X - $satellite2D / 2.0),
                        [single]($satellite2Y - $satellite2D / 2.0),
                        $satellite2D,
                        $satellite2D
                    )
                } finally {
                    if ($null -ne $orbitPen) { $orbitPen.Dispose() }
                }
            }

            'nexus' {
                # Nexus: a focused network core surrounded by three interrupted concentric tracks.
                # Offset gaps keep the rings visually light at sidebar size; the small satellite
                # anchors the upper-right opening so the glyph reads as a connected network hub.
                $nexusMidPen = $null
                $nexusInnerPen = $null
                try {
                    $midAlpha = [int][math]::Round([double]$color.A * 0.72)
                    $innerAlpha = [int][math]::Round([double]$color.A * 0.56)
                    $midColor = [System.Drawing.Color]::FromArgb($midAlpha, $color.R, $color.G, $color.B)
                    $innerColor = [System.Drawing.Color]::FromArgb($innerAlpha, $color.R, $color.G, $color.B)
                    $nexusMidPen = [System.Drawing.Pen]::new($midColor, [single][math]::Max(1.0, [double]$size * 0.050))
                    $nexusInnerPen = [System.Drawing.Pen]::new($innerColor, [single][math]::Max(1.0, [double]$size * 0.044))
                    foreach ($nexusPen in @($nexusMidPen, $nexusInnerPen)) {
                        $nexusPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                        $nexusPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                        $nexusPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
                    }

                    # Outer track: largest silhouette, open at the upper-right for a distinct profile.
                    $outerD = [single]($size * 0.88)
                    $graphics.DrawArc($pen,
                        [single]($cx - $outerD / 2.0),
                        [single]($cy - $outerD / 2.0),
                        $outerD, $outerD,
                        [single]55.0, [single]250.0)

                    # Middle track: opening shifts to the lower-left, creating a measured rhythm.
                    $middleD = [single]($size * 0.64)
                    $graphics.DrawArc($nexusMidPen,
                        [single]($cx - $middleD / 2.0),
                        [single]($cy - $middleD / 2.0),
                        $middleD, $middleD,
                        [single]215.0, [single]270.0)

                    # Inner track: a restrained partial ring frames the central network core.
                    $innerD = [single]($size * 0.40)
                    $graphics.DrawArc($nexusInnerPen,
                        [single]($cx - $innerD / 2.0),
                        [single]($cy - $innerD / 2.0),
                        $innerD, $innerD,
                        [single]38.0, [single]268.0)

                    # Central core remains solid for legibility at 20–24 px icon sizes.
                    $coreD = [single]($size * 0.145)
                    $graphics.FillEllipse($brush,
                        [single]($cx - $coreD / 2.0),
                        [single]($cy - $coreD / 2.0),
                        $coreD, $coreD)

                    # One small satellite node sits at the outer track's upper-right opening.
                    $nodeD = [single]([math]::Max(2.0, [double]$size * 0.105))
                    $nodeX = [single]($x + $size * 0.815)
                    $nodeY = [single]($y + $size * 0.385)
                    $graphics.FillEllipse($brush,
                        [single]($nodeX - $nodeD / 2.0),
                        [single]($nodeY - $nodeD / 2.0),
                        $nodeD, $nodeD)
                } finally {
                    if ($null -ne $nexusMidPen) { $nexusMidPen.Dispose() }
                    if ($null -ne $nexusInnerPen) { $nexusInnerPen.Dispose() }
                }
            }

            'clean' {
                # Clean Up: a minimal, symmetrical trash bin matching the sidebar outline set.
                $binBody = [System.Drawing.PointF[]]@(
                    [System.Drawing.PointF]::new([single]($x+$size*0.29), [single]($y+$size*0.34)),
                    [System.Drawing.PointF]::new([single]($x+$size*0.33), [single]($y+$size*0.83)),
                    [System.Drawing.PointF]::new([single]($x+$size*0.67), [single]($y+$size*0.83)),
                    [System.Drawing.PointF]::new([single]($x+$size*0.71), [single]($y+$size*0.34))
                )
                $graphics.DrawLines($pen, $binBody)
                # Lid and short centered handle.
                $graphics.DrawLine($pen, [single]($x+$size*0.23), [single]($y+$size*0.29), [single]($x+$size*0.77), [single]($y+$size*0.29))
                $graphics.DrawLine($pen, [single]($x+$size*0.41), [single]($y+$size*0.20), [single]($x+$size*0.59), [single]($y+$size*0.20))
                $graphics.DrawLine($pen, [single]($x+$size*0.50), [single]($y+$size*0.20), [single]($x+$size*0.50), [single]($y+$size*0.29))
                # Two restrained inner slats keep the icon legible at sidebar size.
                $graphics.DrawLine($pen, [single]($x+$size*0.43), [single]($y+$size*0.43), [single]($x+$size*0.44), [single]($y+$size*0.73))
                $graphics.DrawLine($pen, [single]($x+$size*0.57), [single]($y+$size*0.43), [single]($x+$size*0.56), [single]($y+$size*0.73))
            }
        }
    } finally {
        $pen.Dispose()
        $brush.Dispose()
    }
}
function Draw-HSMainHighX {
    param($graphics, [double]$centerX, [double]$centerY, [double]$maxWidth, [double]$maxHeight)
    if ($null -eq $script:hxBounds -or $script:hxBounds.Width -le 0.0 -or $script:hxBounds.Height -le 0.0) { return }
    $scale = [double][math]::Min(($maxWidth / [double]$script:hxBounds.Width), ($maxHeight / [double]$script:hxBounds.Height))
    if ($scale -le 0.0) { return }
    $state = $graphics.Save()
    $matrix = $null
    $blackBrush = $null
    try {
        $currentCenterX = [double]($script:hxBounds.X + $script:hxBounds.Width/2.0)
        $currentCenterY = [double]($script:hxBounds.Y + $script:hxBounds.Height/2.0)
        $matrix = [System.Drawing.Drawing2D.Matrix]::new(
            [single]$scale, [single]0.0, [single]0.0, [single]$scale,
            [single]($centerX - ($currentCenterX*$scale)),
            [single]($centerY - ($currentCenterY*$scale))
        )
        $graphics.Transform = $matrix
        # Reuse the original Key-page HIGH X glyph paths, rendered crisp black on Main.
        $blackBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 0, 0, 0))
        if ($null -ne $script:hxHighPath) { $graphics.FillPath($blackBrush, $script:hxHighPath) }
        if ($null -ne $script:hxXPath) { $graphics.FillPath($blackBrush, $script:hxXPath) }
    } finally {
        if ($null -ne $blackBrush) { $blackBrush.Dispose() }
        $graphics.Restore($state)
        if ($null -ne $matrix) { $matrix.Dispose() }
    }
}

function Draw-HSMainWindowControls {
    param($graphics, [double]$clientWidth)
    $cy = [single]($headerCtlY + $headerCtlSize/2.0)
    $closeX = [single]($clientWidth - 28.0)
    $maxX = [single]($clientWidth - 60.0)
    $minX = [single]($clientWidth - 92.0)
    $coreColor = [System.Drawing.Color]::FromArgb(190, 70, 77, 87)
    $glowColor = [System.Drawing.Color]::FromArgb(20, 77, 84, 94)
    $core = [System.Drawing.Pen]::new($coreColor, [single]0.9)
    $glow = [System.Drawing.Pen]::new($glowColor, [single]2.3)
    foreach ($p in @($core,$glow)) { $p.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $p.EndCap=[System.Drawing.Drawing2D.LineCap]::Round }
    try {
        if ($script:hover -eq 'close') {
            $hoverBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(30, 198, 72, 75))
            try { $graphics.FillEllipse($hoverBrush, [single]($closeX-10), [single]($cy-10), 20.0, 20.0) } finally { $hoverBrush.Dispose() }
        } elseif ($script:mainHover -eq 'MAXIMIZE') {
            $hoverBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(22, 75, 83, 94))
            try { $graphics.FillEllipse($hoverBrush, [single]($maxX-10), [single]($cy-10), 20.0, 20.0) } finally { $hoverBrush.Dispose() }
        } elseif ($script:hover -eq 'min') {
            $hoverBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(18, 75, 83, 94))
            try { $graphics.FillEllipse($hoverBrush, [single]($minX-10), [single]($cy-10), 20.0, 20.0) } finally { $hoverBrush.Dispose() }
        }
        $s = [single]4.0
        $graphics.DrawLine($glow, [single]($closeX-$s), [single]($cy-$s), [single]($closeX+$s), [single]($cy+$s))
        $graphics.DrawLine($glow, [single]($closeX+$s), [single]($cy-$s), [single]($closeX-$s), [single]($cy+$s))
        $graphics.DrawLine($core, [single]($closeX-$s), [single]($cy-$s), [single]($closeX+$s), [single]($cy+$s))
        $graphics.DrawLine($core, [single]($closeX+$s), [single]($cy-$s), [single]($closeX-$s), [single]($cy+$s))
        $graphics.DrawRectangle($core, [single]($maxX-4.1), [single]($cy-4.1), [single]8.2, [single]8.2)
        $graphics.DrawLine($glow, [single]($minX-4.2), $cy, [single]($minX+4.2), $cy)
        $graphics.DrawLine($core, [single]($minX-4.2), $cy, [single]($minX+4.2), $cy)
    } finally { $core.Dispose(); $glow.Dispose() }
}

# Read the local machine's hardware once, outside Paint. The Home dashboard intentionally
# does not invent a live game-FPS value; its display remains a placeholder until a
# real game telemetry source is connected.
$script:mainHomeSpecs = @{
    CPU       = 'CPU unavailable'
    GPU       = 'GPU unavailable'
    RAM       = 'Unavailable'
    OS        = 'Windows unavailable'
    STORAGE   = 'Unavailable'
    TotalRamBytes = 0.0
}

$script:mainHomeMetrics = @{
    CPU = $null
    GPU = $null
    RAM = $null
    TEMP = $null
    FPS = $null
    PeakFPS = $null
}
$script:mainHomeCpuCounter = $null
$script:mainHomeMemoryAvailableCounter = $null
$script:mainHomeGpuCounters = @()
$script:mainHomeNvidiaSmi = $null
$script:mainHomeNvidiaProcess = $null
$script:mainHomeNvidiaProcessStart = -10.0
$script:mainHomeLastMetricsUpdate = -10.0
$script:mainHomeLastNvidiaUpdate = -10.0

function Initialize-HSMainHomeHardwareSpecs {
    # Collect static hardware identity once; drawing never calls WMI or reads the registry.
    try {
        $cpuItem = Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name 'ProcessorNameString' -ErrorAction Stop
        $cpuName = [string]$cpuItem.ProcessorNameString
        $cpuName = ($cpuName -replace '\s*\(R\)', '' -replace '\s*\(TM\)', '' -replace '\s{2,}', ' ').Trim()
        if (-not [string]::IsNullOrWhiteSpace($cpuName)) { $script:mainHomeSpecs.CPU = $cpuName }
    } catch { }

    try {
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ([double]$computerInfo.TotalPhysicalMemory -gt 0.0) {
            $script:mainHomeSpecs.TotalRamBytes = [double]$computerInfo.TotalPhysicalMemory
            $ramGb = [int][math]::Round(([double]$computerInfo.TotalPhysicalMemory / 1GB), 0)
            $script:mainHomeSpecs.RAM = ('{0} GB' -f $ramGb)
        }
    } catch { }

    try {
        $gpuCandidates = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and
                ([string]$_.Name -notmatch 'Microsoft Basic Display|Remote Display|Virtual Display|Indirect Display|Parsec|Citrix')
            })
        if ($gpuCandidates.Count -gt 0) {
            $gpu = $gpuCandidates | Sort-Object -Property @{ Expression = { if ($null -ne $_.AdapterRAM) { [double]$_.AdapterRAM } else { 0.0 } }; Descending = $true } | Select-Object -First 1
            $gpuName = [string]$gpu.Name
            $gpuName = ($gpuName -replace '\s*\(R\)', '' -replace '\s*\(TM\)', '' -replace '\s{2,}', ' ').Trim()
            if (-not [string]::IsNullOrWhiteSpace($gpuName)) { $script:mainHomeSpecs.GPU = $gpuName }
        }
    } catch { }

    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $osName = [string]$osInfo.Caption
        if (-not [string]::IsNullOrWhiteSpace($osName)) {
            $script:mainHomeSpecs.OS = ($osName -replace '\s{2,}', ' ').Trim()
        }
    } catch { }

    try {
        $systemDrive = [string]$env:SystemDrive
        if ([string]::IsNullOrWhiteSpace($systemDrive)) { $systemDrive = 'C:' }
        $driveInfo = [System.IO.DriveInfo]::new(($systemDrive + '\'))
        if ($driveInfo.IsReady -and $driveInfo.TotalSize -gt 0) {
            $driveGb = [int][math]::Round(([double]$driveInfo.TotalSize / 1GB), 0)
            $script:mainHomeSpecs.STORAGE = ('{0} / {1} GB' -f $systemDrive, $driveGb)
        }
    } catch { }
}

function Initialize-HSMainHomeMetricReaders {
    # Performance counters are persistent, so metric refreshes do not repeatedly query WMI.
    try {
        $script:mainHomeCpuCounter = [System.Diagnostics.PerformanceCounter]::new('Processor', '% Processor Time', '_Total', $true)
        [void]$script:mainHomeCpuCounter.NextValue()
    } catch { $script:mainHomeCpuCounter = $null }

    try {
        $script:mainHomeMemoryAvailableCounter = [System.Diagnostics.PerformanceCounter]::new('Memory', 'Available MBytes', $true)
        [void]$script:mainHomeMemoryAvailableCounter.NextValue()
    } catch { $script:mainHomeMemoryAvailableCounter = $null }

    # Prefer NVIDIA's telemetry endpoint when it exists; discover it before enumerating GPU counters.
    try {
        $nvidiaCommand = Get-Command 'nvidia-smi.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $nvidiaCommand) { $nvidiaCommand = Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($null -ne $nvidiaCommand -and -not [string]::IsNullOrWhiteSpace([string]$nvidiaCommand.Source)) {
            $script:mainHomeNvidiaSmi = [string]$nvidiaCommand.Source
        }
        if ([string]::IsNullOrWhiteSpace([string]$script:mainHomeNvidiaSmi)) {
            foreach ($candidate in @(
                (Join-Path ${env:ProgramFiles} 'NVIDIA Corporation\NVSMI\nvidia-smi.exe'),
                (Join-Path $env:windir 'System32\nvidia-smi.exe')
            )) {
                if (-not [string]::IsNullOrWhiteSpace([string]$candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                    $script:mainHomeNvidiaSmi = $candidate
                    break
                }
            }
        }
    } catch { $script:mainHomeNvidiaSmi = $null }

    # Fall back to Windows GPU Engine counters only when nvidia-smi is not available.
    if ([string]::IsNullOrWhiteSpace([string]$script:mainHomeNvidiaSmi)) {
        try {
            $gpuCategory = [System.Diagnostics.PerformanceCounterCategory]::new('GPU Engine')
            $instances = @($gpuCategory.GetInstanceNames() | Where-Object { $_ -match 'engtype_3D' } | Select-Object -First 48)
            $gpuReaders = @()
            foreach ($instanceName in $instances) {
                try {
                    $reader = [System.Diagnostics.PerformanceCounter]::new('GPU Engine', 'Utilization Percentage', [string]$instanceName, $true)
                    [void]$reader.NextValue()
                    $gpuReaders += $reader
                } catch { }
            }
            $script:mainHomeGpuCounters = $gpuReaders
        } catch { $script:mainHomeGpuCounters = @() }
    }
}

function Update-HSMainHomeMetrics {
    param([double]$Now)
    if (($Now - [double]$script:mainHomeLastMetricsUpdate) -lt 0.90) { return $false }
    $script:mainHomeLastMetricsUpdate = $Now

    if ($null -ne $script:mainHomeCpuCounter) {
        try {
            $cpu = [double]$script:mainHomeCpuCounter.NextValue()
            if (-not [double]::IsNaN($cpu) -and -not [double]::IsInfinity($cpu)) {
                $script:mainHomeMetrics.CPU = [double][math]::Max(0.0, [math]::Min(100.0, $cpu))
            }
        } catch { }
    }

    if ($null -ne $script:mainHomeMemoryAvailableCounter -and [double]$script:mainHomeSpecs.TotalRamBytes -gt 0.0) {
        try {
            $availableMb = [double]$script:mainHomeMemoryAvailableCounter.NextValue()
            $totalMb = [double]$script:mainHomeSpecs.TotalRamBytes / 1MB
            if ($totalMb -gt 0.0) {
                $usedPercent = 100.0 - (($availableMb / $totalMb) * 100.0)
                $script:mainHomeMetrics.RAM = [double][math]::Max(0.0, [math]::Min(100.0, $usedPercent))
            }
        } catch { }
    }

    # Use the busiest 3D engine rather than summing engines (which can exceed 100%).
    $gpuCounterValue = $null
    foreach ($reader in @($script:mainHomeGpuCounters)) {
        if ($null -eq $reader) { continue }
        try {
            $sample = [double]$reader.NextValue()
            if (-not [double]::IsNaN($sample) -and -not [double]::IsInfinity($sample)) {
                $sample = [double][math]::Max(0.0, [math]::Min(100.0, $sample))
                if ($null -eq $gpuCounterValue -or $sample -gt [double]$gpuCounterValue) { $gpuCounterValue = $sample }
            }
        } catch { }
    }
    if ($null -ne $gpuCounterValue) { $script:mainHomeMetrics.GPU = [double]$gpuCounterValue }

    # NVIDIA telemetry runs asynchronously so a slow driver utility cannot freeze the UI thread.
    if ($null -ne $script:mainHomeNvidiaProcess) {
        $nvidiaProcess = $script:mainHomeNvidiaProcess
        try {
            if ($nvidiaProcess.HasExited) {
                $output = [string]$nvidiaProcess.StandardOutput.ReadToEnd()
                $firstLine = @($output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
                if ($firstLine.Count -gt 0) {
                    $parts = @(([string]$firstLine[0]) -split ',')
                    if ($parts.Count -ge 1) {
                        $gpuText = ([string]$parts[0]).Trim()
                        $gpuNumber = 0.0
                        if ([double]::TryParse($gpuText, [ref]$gpuNumber)) {
                            $script:mainHomeMetrics.GPU = [double][math]::Max(0.0, [math]::Min(100.0, $gpuNumber))
                        }
                    }
                    if ($parts.Count -ge 2) {
                        $tempText = ([string]$parts[1]).Trim()
                        $temperature = 0.0
                        if ([double]::TryParse($tempText, [ref]$temperature) -and $temperature -ge 0.0 -and $temperature -le 150.0) {
                            $script:mainHomeMetrics.TEMP = [double]$temperature
                        }
                    }
                }
                $nvidiaProcess.Dispose()
                $script:mainHomeNvidiaProcess = $null
            } elseif (($Now - [double]$script:mainHomeNvidiaProcessStart) -gt 8.0) {
                # A driver tool that stops responding is abandoned safely.
                try { $nvidiaProcess.Kill() } catch { }
                try { $nvidiaProcess.Dispose() } catch { }
                $script:mainHomeNvidiaProcess = $null
            }
        } catch {
            try { $nvidiaProcess.Dispose() } catch { }
            $script:mainHomeNvidiaProcess = $null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$script:mainHomeNvidiaSmi) -and
        $null -eq $script:mainHomeNvidiaProcess -and
        (($Now - [double]$script:mainHomeLastNvidiaUpdate) -ge 2.0)) {
        $script:mainHomeLastNvidiaUpdate = $Now
        try {
            $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $startInfo.FileName = [string]$script:mainHomeNvidiaSmi
            $startInfo.Arguments = '--query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits'
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.CreateNoWindow = $true
            $process = [System.Diagnostics.Process]::new()
            $process.StartInfo = $startInfo
            if ($process.Start()) {
                $script:mainHomeNvidiaProcess = $process
                $script:mainHomeNvidiaProcessStart = $Now
            } else {
                $process.Dispose()
            }
        } catch {
            if ($null -ne $process) { try { $process.Dispose() } catch { } }
            $script:mainHomeNvidiaProcess = $null
        }
    }

    return $true
}

Initialize-HSMainHomeHardwareSpecs
Initialize-HSMainHomeMetricReaders
function Draw-HSHomeDashboard {
    param($graphics, [double]$width, [double]$height)
    if ($null -eq $graphics -or [string]$script:mainActiveSection -ne 'HOME') { return }

    $sidebarW = 218.0
    $availableW = [double]$width - $sidebarW - 54.0
    if ($availableW -lt 620.0 -or $height -lt 400.0) { return }
    $rowW = [double][math]::Min(900.0, $availableW)
    $rowX = $sidebarW + 27.0 + (($availableW - $rowW) / 2.0)

    $ink = [System.Drawing.Color]::FromArgb(255, 20, 25, 32)
    $muted = [System.Drawing.Color]::FromArgb(255, 103, 112, 124)
    $softMuted = [System.Drawing.Color]::FromArgb(255, 134, 143, 154)
    $lineColor = [System.Drawing.Color]::FromArgb(255, 224, 228, 233)
    $white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
    $quietFill = [System.Drawing.Color]::FromArgb(255, 250, 251, 253)

    $titleFont = $null; $subtitleFont = $null; $statusFont = $null; $microFont = $null
    $heroLabelFont = $null; $heroValueFont = $null; $profileTitleFont = $null
    $profileLabelFont = $null; $profileValueFont = $null; $metricLabelFont = $null
    $metricValueFont = $null; $footerFont = $null; $tinyFont = $null
    $titleBrush = $null; $subtitleBrush = $null; $inkBrush = $null; $mutedBrush = $null
    $softMutedBrush = $null; $greenBrush = $null; $whiteBrush = $null; $statusBrush = $null
    $linePen = $null; $borderPen = $null; $meterBgPen = $null; $meterPen = $null
    $heroRect = $null; $heroPath = $null; $heroShadowPath = $null; $heroShadowBrush = $null
    $heroBrush = $null; $heroBorderPen = $null; $heroTrackPen = $null; $heroArcPen = $null
    $heroDividerPen = $null; $centerFormat = $null; $leftFormat = $null; $rightFormat = $null
    $metricResources = @()

    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        # Brand heading and compact system-ready status, laid out like the supplied reference.
        $titleFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]31.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $subtitleFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]21.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $statusFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]8.6, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $microFont = [System.Drawing.Font]::new('Segoe UI', [single]8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $titleBrush = [System.Drawing.SolidBrush]::new($ink)
        $subtitleBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 122, 131, 143))
        $mutedBrush = [System.Drawing.SolidBrush]::new($muted)
        $softMutedBrush = [System.Drawing.SolidBrush]::new($softMuted)
        $inkBrush = [System.Drawing.SolidBrush]::new($ink)
        $greenBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 91, 166, 125))
        $whiteBrush = [System.Drawing.SolidBrush]::new($white)
        $statusBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 119, 129, 141))
        $linePen = [System.Drawing.Pen]::new($lineColor, [single]0.8)
        $borderPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 237, 241, 246), [single]0.8)
        $centerFormat = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
        $centerFormat.Alignment = [System.Drawing.StringAlignment]::Center
        $centerFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
        $leftFormat = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
        $leftFormat.FormatFlags = $leftFormat.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap
        $leftFormat.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
        $rightFormat = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
        $rightFormat.Alignment = [System.Drawing.StringAlignment]::Far
        $rightFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
        $rightFormat.FormatFlags = $rightFormat.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap

        $graphics.DrawString('H I G H S T E P', $titleFont, $titleBrush, [single]$rowX, [single]51.0)
        $graphics.DrawString('S C R I P T  X', $subtitleFont, $subtitleBrush, [single]$rowX, [single]96.0)

        $statusX = [single]($rowX + $rowW - 154.0)
        $graphics.FillEllipse($greenBrush, [single]($statusX - 10.0), [single]31.5, [single]5.0, [single]5.0)
        $graphics.DrawString('SYSTEM READY', $statusFont, $inkBrush, [single]($statusX + 1.0), [single]25.0)
        $graphics.DrawString('Live hardware monitoring', $microFont, $mutedBrush, [single]($statusX + 1.0), [single]42.0)

        # Wide, low-contrast system card: game FPS on the left; live machine profile on the right.
        $panelY = 150.0
        $panelH = 163.0
        $heroRect = [System.Drawing.RectangleF]::new([single]$rowX, [single]$panelY, [single]$rowW, [single]$panelH)
        $heroShadowPath = New-RoundedRectPath ([single]$heroRect.X) ([single]($heroRect.Y + 2.0)) ([single]$heroRect.Width) ([single]$heroRect.Height) ([single]14.0)
        $heroPath = New-RoundedRectPath ([single]$heroRect.X) ([single]$heroRect.Y) ([single]$heroRect.Width) ([single]$heroRect.Height) ([single]14.0)
        $heroShadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(12, 24, 31, 39))
        $heroBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $heroRect,
            [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
            [System.Drawing.Color]::FromArgb(255, 249, 251, 253),
            [single]90.0
        )
        $heroBorderPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(225, 236, 240, 245), [single]0.8)
        $graphics.FillPath($heroShadowBrush, $heroShadowPath)
        $graphics.FillPath($heroBrush, $heroPath)
        $graphics.DrawPath($heroBorderPen, $heroPath)

        # FPS value stays unavailable until a real game-telemetry source is connected.
        $ringD = [single]94.0
        $ringCX = [single]($rowX + 79.0)
        $ringCY = [single]($panelY + 81.5)
        $ringRect = [System.Drawing.RectangleF]::new([single]($ringCX - ($ringD / 2.0)), [single]($ringCY - ($ringD / 2.0)), $ringD, $ringD)
        $heroTrackPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 233, 237, 242), [single]3.2)
        $heroTrackPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $heroTrackPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $heroArcPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 30, 36, 44), [single]3.0)
        $heroArcPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $heroArcPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawEllipse($heroTrackPen, $ringRect)
        if ($null -ne $script:mainHomeMetrics.FPS) {
            $arcLength = [single](300.0 * ([math]::Min(300.0, [double]$script:mainHomeMetrics.FPS) / 300.0))
            if ($arcLength -gt 0.0) { $graphics.DrawArc($heroArcPen, $ringRect, [single]-120.0, $arcLength) }
        }
        $heroValueFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]27.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $tinyFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]7.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $heroLabelFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]9.2, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $graphics.DrawString('N/A', $heroValueFont, $inkBrush, $ringRect, $centerFormat)
        $fpsCaptionRect = [System.Drawing.RectangleF]::new([single]($ringCX - 35.0), [single]($ringCY + 23.0), [single]70.0, [single]12.0)
        $graphics.DrawString('GAME FPS', $tinyFont, $mutedBrush, $fpsCaptionRect, $centerFormat)

        $fpsTextX = [single]($rowX + 143.0)
        $graphics.DrawString('LIVE FPS', $heroLabelFont, $inkBrush, $fpsTextX, [single]($panelY + 43.0))
        $graphics.DrawString('HIGH X LIVE', $microFont, $mutedBrush, $fpsTextX, [single]($panelY + 61.0))
        $graphics.DrawString('Game telemetry is not connected', $microFont, $softMutedBrush, $fpsTextX, [single]($panelY + 82.0))
        $graphics.DrawString('Peak  N/A FPS', $microFont, $mutedBrush, $fpsTextX, [single]($panelY + 105.0))

        $splitX = [single]($rowX + 370.0)
        $heroDividerPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 226, 231, 237), [single]0.8)
        $graphics.DrawLine($heroDividerPen, $splitX, [single]($panelY + 20.0), $splitX, [single]($panelY + $panelH - 20.0))
        $profileTitleFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $profileLabelFont = [System.Drawing.Font]::new('Segoe UI', [single]8.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $profileValueFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]8.3, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $profileX = [single]($splitX + 22.0)
        $profileValueX = [single]($profileX + 40.0)
        $profileValueW = [single]([math]::Max(70.0, $heroRect.Right - $profileValueX - 18.0))
        $graphics.DrawString('SYSTEM PROFILE', $profileTitleFont, $mutedBrush, $profileX, [single]($panelY + 20.0))
        $profileRows = @(
            @{ Label='CPU'; Value=[string]$script:mainHomeSpecs.CPU; Y=47.0 },
            @{ Label='GPU'; Value=[string]$script:mainHomeSpecs.GPU; Y=74.0 },
            @{ Label='RAM'; Value=[string]$script:mainHomeSpecs.RAM; Y=101.0 },
            @{ Label='OS'; Value=[string]$script:mainHomeSpecs.OS; Y=128.0 }
        )
        foreach ($profileRow in $profileRows) {
            $rowTop = [single]($panelY + [double]$profileRow.Y)
            $labelRect = [System.Drawing.RectangleF]::new($profileX, $rowTop, [single]35.0, [single]14.0)
            $valueRect = [System.Drawing.RectangleF]::new($profileValueX, $rowTop, $profileValueW, [single]14.0)
            $graphics.DrawString([string]$profileRow.Label, $profileLabelFont, $mutedBrush, $labelRect, $leftFormat)
            $graphics.DrawString([string]$profileRow.Value, $profileValueFont, $inkBrush, $valueRect, $leftFormat)
        }

        # Four live monitor cards with restrained iconography, values, status, and usage bars.
        $metricY = 328.0
        $metricH = 120.0
        $metricGap = 12.0
        $metricW = [single](($rowW - (3.0 * $metricGap)) / 4.0)
        $metricLabelFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]8.5, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $metricValueFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]24.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $footerFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]7.8, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
        $meterBgPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 235, 238, 242), [single]1.4)
        $meterPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 34, 40, 48), [single]1.4)
        $meterBgPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $meterBgPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $meterPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $meterPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

        $metricItems = @(
            @{ Key='CPU'; Label='CPU'; Value=$script:mainHomeMetrics.CPU; Unit='%'; Icon='cpu' },
            @{ Key='GPU'; Label='GPU'; Value=$script:mainHomeMetrics.GPU; Unit='%'; Icon='gpu' },
            @{ Key='RAM'; Label='RAM'; Value=$script:mainHomeMetrics.RAM; Unit='%'; Icon='ram' },
            @{ Key='TEMP'; Label='TEMP'; Value=$script:mainHomeMetrics.TEMP; Unit=' C'; Icon='temp' }
        )
        for ($metricIndex = 0; $metricIndex -lt $metricItems.Count; $metricIndex++) {
            $item = $metricItems[$metricIndex]
            $cardX = [single]($rowX + ($metricIndex * ($metricW + $metricGap)))
            $cardRect = [System.Drawing.RectangleF]::new($cardX, [single]$metricY, $metricW, [single]$metricH)
            $cardPath = New-RoundedRectPath ([single]$cardRect.X) ([single]$cardRect.Y) ([single]$cardRect.Width) ([single]$cardRect.Height) ([single]11.0)
            $metricBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
                $cardRect,
                [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
                [System.Drawing.Color]::FromArgb(255, 250, 251, 253),
                [single]90.0
            )
            $graphics.FillPath($metricBrush, $cardPath)
            $graphics.DrawPath($borderPen, $cardPath)
            $metricResources += $cardPath; $metricResources += $metricBrush

            # Small line icons are drawn natively, so they do not depend on external assets.
            $iconPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 106, 116, 128), [single]0.9)
            $ix = [single]($cardX + 14.0); $iy = [single]($metricY + 16.0)
            switch ([string]$item.Icon) {
                'cpu' {
                    $graphics.DrawRectangle($iconPen, [single]($ix + 2.0), [single]($iy + 2.0), [single]10.0, [single]10.0)
                    for ($pin = 0; $pin -lt 3; $pin++) {
                        $px = [single]($ix + 4.0 + (3.0 * $pin))
                        $graphics.DrawLine($iconPen, $px, $iy, $px, [single]($iy + 2.0))
                        $graphics.DrawLine($iconPen, $px, [single]($iy + 12.0), $px, [single]($iy + 14.0))
                    }
                    $graphics.DrawLine($iconPen, $ix, [single]($iy + 4.0), [single]($ix + 2.0), [single]($iy + 4.0))
                    $graphics.DrawLine($iconPen, [single]($ix + 12.0), [single]($iy + 4.0), [single]($ix + 14.0), [single]($iy + 4.0))
                    $graphics.DrawLine($iconPen, $ix, [single]($iy + 9.0), [single]($ix + 2.0), [single]($iy + 9.0))
                    $graphics.DrawLine($iconPen, [single]($ix + 12.0), [single]($iy + 9.0), [single]($ix + 14.0), [single]($iy + 9.0))
                }
                'gpu' {
                    $graphics.DrawRectangle($iconPen, [single]($ix + 1.0), [single]($iy + 3.0), [single]13.0, [single]8.0)
                    $graphics.DrawEllipse($iconPen, [single]($ix + 5.0), [single]($iy + 5.0), [single]4.0, [single]4.0)
                    $graphics.DrawLine($iconPen, [single]($ix + 14.0), [single]($iy + 5.0), [single]($ix + 16.0), [single]($iy + 5.0))
                }
                'ram' {
                    $graphics.DrawRectangle($iconPen, [single]$ix, [single]($iy + 3.0), [single]16.0, [single]7.0)
                    for ($pin = 0; $pin -lt 4; $pin++) {
                        $px = [single]($ix + 2.0 + (4.0 * $pin))
                        $graphics.DrawLine($iconPen, $px, [single]($iy + 10.0), $px, [single]($iy + 13.0))
                        $graphics.DrawLine($iconPen, $px, [single]($iy + 4.0), $px, [single]($iy + 8.0))
                    }
                }
                'temp' {
                    $graphics.DrawArc($iconPen, [single]($ix + 4.0), [single]($iy + 1.0), [single]5.0, [single]10.0, [single]180.0, [single]180.0)
                    $graphics.DrawLine($iconPen, [single]($ix + 4.0), [single]($iy + 6.0), [single]($ix + 4.0), [single]($iy + 12.0))
                    $graphics.DrawLine($iconPen, [single]($ix + 9.0), [single]($iy + 6.0), [single]($ix + 9.0), [single]($iy + 12.0))
                    $graphics.DrawEllipse($iconPen, [single]($ix + 2.5), [single]($iy + 10.0), [single]8.0, [single]8.0)
                }
            }
            $metricResources += $iconPen

            $graphics.DrawString([string]$item.Label, $metricLabelFont, $inkBrush, [single]($cardX + 38.0), [single]($metricY + 16.0))
            $gaugeTrackRect = [System.Drawing.RectangleF]::new([single]($cardRect.Right - 38.0), [single]($metricY + 14.0), [single]25.0, [single]25.0)
            $graphics.DrawArc($meterBgPen, $gaugeTrackRect, [single]-90.0, [single]300.0)

            $valueText = 'N/A'
            $valueValid = $null -ne $item.Value
            if ($valueValid) {
                if ([string]$item.Key -eq 'TEMP') { $valueText = ('{0:N0}{1}' -f [double]$item.Value, [string]$item.Unit) }
                else { $valueText = ('{0:N1}{1}' -f [double]$item.Value, [string]$item.Unit) }
            }
            $valueRect = [System.Drawing.RectangleF]::new([single]($cardX + 14.0), [single]($metricY + 41.0), [single]($metricW - 25.0), [single]32.0)
            $graphics.DrawString($valueText, $metricValueFont, $inkBrush, $valueRect, $leftFormat)

            $statusText = 'Sensor unavailable'
            $barFraction = 0.0
            if ($valueValid) {
                $valueNumber = [double]$item.Value
                $barFraction = [double][math]::Max(0.0, [math]::Min(1.0, ($valueNumber / 100.0)))
                if ($valueNumber -ge 90.0) { $statusText = 'High' }
                elseif ($valueNumber -ge 75.0) { $statusText = 'Elevated' }
                else { $statusText = 'Normal' }
                if ([string]$item.Key -eq 'TEMP') {
                    $barFraction = [double][math]::Max(0.0, [math]::Min(1.0, ($valueNumber / 100.0)))
                    if ($valueNumber -ge 86.0) { $statusText = 'High' }
                    elseif ($valueNumber -ge 76.0) { $statusText = 'Elevated' }
                    else { $statusText = 'Normal' }
                }
            }
            $dotBrush = $statusBrush
            if ($valueValid -and $statusText -eq 'Normal') { $dotBrush = $greenBrush }
            $graphics.FillEllipse($dotBrush, [single]($cardX + 14.0), [single]($metricY + 88.0), [single]4.0, [single]4.0)
            $graphics.DrawString($statusText, $microFont, $mutedBrush, [single]($cardX + 22.0), [single]($metricY + 84.0))
            $barX = [single]($cardX + 14.0); $barY = [single]($metricY + 108.0)
            $barWidth = [single]($metricW - 28.0)
            $graphics.DrawLine($meterBgPen, $barX, $barY, [single]($barX + $barWidth), $barY)
            if ($valueValid -and $barFraction -gt 0.0) {
                $graphics.DrawLine($meterPen, $barX, $barY, [single]($barX + ($barWidth * $barFraction)), $barY)
            }
        }

        # Quiet footer rule and status; large blank area is intentional, as in the reference.
        $footerY = [single]($height - 48.0)
        $graphics.DrawLine($linePen, [single]$rowX, $footerY, [single]($rowX + $rowW), $footerY)
        $graphics.FillEllipse($inkBrush, [single]($rowX + 2.0), [single]($footerY + 12.0), [single]4.0, [single]4.0)
        $graphics.DrawString('SYSTEM MONITORING ACTIVE', $footerFont, $inkBrush, [single]($rowX + 14.0), [single]($footerY + 8.0))
    } finally {
        foreach ($resource in @(
            $titleFont, $subtitleFont, $statusFont, $microFont, $heroLabelFont, $heroValueFont,
            $profileTitleFont, $profileLabelFont, $profileValueFont, $metricLabelFont, $metricValueFont,
            $footerFont, $tinyFont, $titleBrush, $subtitleBrush, $inkBrush, $mutedBrush,
            $softMutedBrush, $greenBrush, $whiteBrush, $statusBrush, $linePen, $borderPen,
            $meterBgPen, $meterPen, $heroRect, $heroPath, $heroShadowPath, $heroShadowBrush,
            $heroBrush, $heroBorderPen, $heroTrackPen, $heroArcPen, $heroDividerPen,
            $centerFormat, $leftFormat, $rightFormat
        )) {
            if ($null -ne $resource) { try { $resource.Dispose() } catch { } }
        }
        foreach ($resource in @($metricResources)) {
            if ($null -ne $resource) { try { $resource.Dispose() } catch { } }
        }
    }
}

function Draw-HSMainInterface {
    param($graphics, [double]$width, [double]$height)

    $sidebarW = 218.0
    $fullRect = [System.Drawing.RectangleF]::new(0.0, 0.0, [single]$width, [single]$height)
    $bgBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $fullRect,
        [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
        [System.Drawing.Color]::FromArgb(255, 249, 250, 252),
        [single]90.0
    )
    try {
        $graphics.FillRectangle($bgBrush, $fullRect)
    } finally {
        $bgBrush.Dispose()
    }

    # Draw the navigation rail; the Home dashboard is drawn after the Sidebar when Home is active.
    $sideRect = [System.Drawing.RectangleF]::new(0.0, 0.0, [single]$sidebarW, [single]$height)
    $sideBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $sideRect,
        [System.Drawing.Color]::FromArgb(255, 250, 251, 253),
        [System.Drawing.Color]::FromArgb(255, 242, 244, 247),
        [single]90.0
    )
    try {
        $graphics.FillRectangle($sideBrush, $sideRect)
    } finally {
        $sideBrush.Dispose()
    }

    $dividerPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(100, 198, 204, 213), [single]0.8)
    try {
        $graphics.DrawLine($dividerPen, [single]$sidebarW, 0.0, [single]$sidebarW, [single]$height)
    } finally {
        $dividerPen.Dispose()
    }

    # Center the original HIGH X vector wordmark horizontally inside the Sidebar.
    # Keep its original glyph paths, crisp black rendering, and ample surrounding whitespace.
    Draw-HSMainHighX $graphics ($sidebarW / 2.0) 38.0 132.0 28.0
    $sideTagFont = [System.Drawing.Font]::new('Segoe UI', [single]7.2, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $sideTagBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 105, 114, 126))
    $sideTagFormat = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
    $sideTagFormat.Alignment = [System.Drawing.StringAlignment]::Center
    try {
        $sideTagRect = [System.Drawing.RectangleF]::new([single]12.0, [single]51.0, [single]194.0, [single]12.0)
        $graphics.DrawString('BOOST YOUR PERFORMANCE', $sideTagFont, $sideTagBrush, $sideTagRect, $sideTagFormat)
    } finally {
        $sideTagFont.Dispose(); $sideTagBrush.Dispose(); $sideTagFormat.Dispose()
    }

    $script:mainNavRects = @{}
    # Sidebar navigation is grouped with clear, uppercase section captions.
    # The captions are visual only: click targets and navigation keys remain unchanged.
    $navItems = @(
        @{ Key='HOME'; Label='Home'; Icon='home'; Y=102.0 },
        @{ Key='FPS TWEAK'; Label='Fps Tweak'; Icon='system'; Y=190.0 },
        @{ Key='LATENCY'; Label='Latency'; Icon='latency'; Y=239.0 },
        @{ Key='NET'; Label='Net'; Icon='nexus'; Y=288.0 },
        @{ Key='CLEAN UP'; Label='Clean Up'; Icon='clean'; Y=382.0 }
    )
    # Bounce-pop selection: the soft-gray pill is placed at the clicked row immediately.
    # Only its local scale settles into place; it never travels vertically between rows.
    # The subtle edge still reveals diagonally from the upper-left toward the lower-right.
    $selectionRawProgress = [math]::Max(0.0, [math]::Min(1.0, [double]$script:mainNavSelectionProgress))
    $pillProgress = $selectionRawProgress * $selectionRawProgress * (3.0 - (2.0 * $selectionRawProgress))
    $pillScale = 1.0
    if ($script:mainNavSelectionAnimating) {
        # Ease-out-back mapped to a small scale range: starts at 84%, overshoots gently,
        # and settles at 100% without moving the tile's center or changing hit rectangles.
        $popC1 = 1.70158
        $popC3 = $popC1 + 1.0
        $popT = $selectionRawProgress - 1.0
        $popEase = 1.0 + ($popC3 * [math]::Pow($popT, 3.0)) + ($popC1 * [math]::Pow($popT, 2.0))
        $pillScale = 0.84 + (0.16 * $popEase)
    }
    $pillBaseWidth = [single]204.0
    $pillBaseHeight = [single]48.0
    $pillWidth = [single]($pillBaseWidth * $pillScale)
    $pillHeight = [single]($pillBaseHeight * $pillScale)
    $pillCenterX = [single]109.0
    $pillTopY = [double]$script:mainNavPillCurrentY
    $pillCenterY = [single]($pillTopY + ($pillBaseHeight / 2.0))
    $pillRect = [System.Drawing.RectangleF]::new(
        [single]($pillCenterX - ($pillWidth / 2.0)),
        [single]($pillCenterY - ($pillHeight / 2.0)),
        $pillWidth,
        $pillHeight
    )
    $pillShadowPath = $null
    $pillPath = $null
    $pillHighlightPath = $null
    $liquidFillPath = $null
    $liquidFrontPath = $null
    $pillShadowBrush = $null
    $pillBaseBrush = $null
    $pillBrush = $null
    $pillEdgePen = $null
    $pillHighlightPen = $null
    $pillLiquidEdgePen = $null
    $pillGraphicsState = $null
    $pillClipState = $null
    try {
        $pillShadowPath = New-RoundedRectPath ([single]$pillRect.X) ([single]($pillRect.Y + 2.0)) ([single]$pillRect.Width) ([single]$pillRect.Height) ([single]12.0)
        $pillPath = New-RoundedRectPath ([single]$pillRect.X) ([single]$pillRect.Y) ([single]$pillRect.Width) ([single]$pillRect.Height) ([single]12.0)
        $pillHighlightPath = New-RoundedRectPath ([single]($pillRect.X + 1.0)) ([single]($pillRect.Y + 1.0)) ([single]($pillRect.Width - 2.0)) ([single]($pillRect.Height - 2.0)) ([single]11.0)
        $pillShadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(10, 0, 0, 0))
        # During the liquid reveal, the unfilled portion uses the same light-gray gradient
        # as the normal hover surface. The black fill advances over it; the tile stays fixed.
        $pillBaseBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $pillRect,
            [System.Drawing.Color]::FromArgb(174, 247, 248, 250),
            [System.Drawing.Color]::FromArgb(174, 232, 235, 240),
            [single]90.0
        )
        $pillBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $pillRect,
            [System.Drawing.Color]::FromArgb(255, 244, 246, 249),
            [System.Drawing.Color]::FromArgb(255, 232, 235, 240),
            [single]90.0
        )
        $pillEdgePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(112, 207, 213, 221), [single]0.8)
        $pillHighlightPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(30, 255, 255, 255), [single]0.65)

        $isLiquidTransition = [bool]($script:mainNavSelectionAnimating -and $pillProgress -lt 0.995)
        if ($isLiquidTransition) {
            # Smooth diagonal liquid reveal, authored as ONE cubic Bézier edge.
            # This replaces the per-frame List/array + nine-point AddCurve pipeline,
            # reducing allocations and keeping the leading edge continuous at 60+ Hz.
            $liquidFillPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
            $liquidFrontPath = [System.Drawing.Drawing2D.GraphicsPath]::new()

            $liquidDistance = $pillProgress * ([double]$pillWidth + [double]$pillHeight)
            $liquidTopX = [math]::Max(0.0, [math]::Min([double]$pillWidth, $liquidDistance))
            $liquidBottomX = [math]::Max(0.0, [math]::Min([double]$pillWidth, ($liquidDistance - [double]$pillHeight)))

            # A more organic, asymmetric S-curve keeps the flow from feeling like a stiff diagonal.
            # The Bézier handles bend in opposite directions; a subtle phase shift lets the crest
            # evolve gently while keeping a single curve and the same low-allocation render path.
            $liquidWaveEnvelope = [math]::Sin([math]::PI * $pillProgress)
            $liquidWavePhase = [math]::Sin((2.0 * [math]::PI * $pillProgress) - 0.45)
            $liquidWaveBend = 10.0 * $liquidWaveEnvelope
            $liquidWaveCounterBend = (7.2 + (1.6 * $liquidWavePhase)) * $liquidWaveEnvelope
            $liquidControl1X = [math]::Max(0.0, [math]::Min([double]$pillWidth, ($liquidDistance - ([double]$pillHeight * 0.30) + $liquidWaveBend)))
            $liquidControl2X = [math]::Max(0.0, [math]::Min([double]$pillWidth, ($liquidDistance - ([double]$pillHeight * 0.70) - $liquidWaveCounterBend)))

            $liquidTopAbsX = [single]([double]$pillRect.X + $liquidTopX)
            $liquidBottomAbsX = [single]([double]$pillRect.X + $liquidBottomX)
            $liquidTopAbsY = [single]$pillRect.Y
            $liquidBottomAbsY = [single]([double]$pillRect.Y + [double]$pillHeight)
            $liquidControl1AbsX = [single]([double]$pillRect.X + $liquidControl1X)
            $liquidControl2AbsX = [single]([double]$pillRect.X + $liquidControl2X)
            $liquidControl1AbsY = [single]([double]$pillRect.Y + ([double]$pillHeight * 0.30))
            $liquidControl2AbsY = [single]([double]$pillRect.Y + ([double]$pillHeight * 0.70))

            # Edge path is kept separate so the same curve can be stroked with a
            # single anti-aliased pen; corners remain controlled by the rounded clip.
            $liquidFrontPath.StartFigure()
            $liquidFrontPath.AddBezier(
                $liquidTopAbsX, $liquidTopAbsY,
                $liquidControl1AbsX, $liquidControl1AbsY,
                $liquidControl2AbsX, $liquidControl2AbsY,
                $liquidBottomAbsX, $liquidBottomAbsY
            )

            # Fill the area to the left of the leading edge.
            $liquidFillPath.StartFigure()
            $liquidFillPath.AddLine(
                [single]$pillRect.X, [single]$pillRect.Y,
                $liquidTopAbsX, $liquidTopAbsY
            )
            $liquidFillPath.AddBezier(
                $liquidTopAbsX, $liquidTopAbsY,
                $liquidControl1AbsX, $liquidControl1AbsY,
                $liquidControl2AbsX, $liquidControl2AbsY,
                $liquidBottomAbsX, $liquidBottomAbsY
            )
            $liquidFillPath.AddLine(
                $liquidBottomAbsX, $liquidBottomAbsY,
                [single]$pillRect.X, [single]($pillRect.Y + $pillRect.Height)
            )
            $liquidFillPath.CloseFigure()

            # A single restrained silver edge peaks in the middle of the transition.
            $liquidEdgeAlpha = [int][math]::Round(44.0 * $liquidWaveEnvelope)
            $pillLiquidEdgePen = [System.Drawing.Pen]::new(
                [System.Drawing.Color]::FromArgb($liquidEdgeAlpha, 176, 181, 190),
                [single]0.75
            )
            $pillLiquidEdgePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pillLiquidEdgePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pillLiquidEdgePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        }

        $pillGraphicsState = $graphics.Save()
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        # The soft shadow and rounded outline stay attached to the moving tile.
        $graphics.FillPath($pillShadowBrush, $pillShadowPath)
        if ($isLiquidTransition) {
            # A subdued shell traces the same smooth path as the pill. The diagonal black
            # fill advances inside it, clipped to the fixed-radius rounded silhouette.
            $graphics.FillPath($pillBaseBrush, $pillPath)
            $pillClipState = $graphics.Save()
            $graphics.SetClip($pillPath, [System.Drawing.Drawing2D.CombineMode]::Intersect)
            $graphics.FillPath($pillBrush, $liquidFillPath)
            if ($pillProgress -gt 0.025 -and $pillProgress -lt 0.975 -and $null -ne $pillLiquidEdgePen -and $null -ne $liquidFrontPath) {
                $graphics.DrawPath($pillLiquidEdgePen, $liquidFrontPath)
            }
            $graphics.Restore($pillClipState)
            $pillClipState = $null
        } else {
            $graphics.FillPath($pillBrush, $pillPath)
        }
        # Draw the stable rounded border after clipping so corners never wobble or break.
        $graphics.DrawPath($pillEdgePen, $pillPath)
        $graphics.DrawPath($pillHighlightPen, $pillHighlightPath)
    } finally {
        if ($null -ne $pillClipState) { $graphics.Restore($pillClipState) }
        if ($null -ne $pillGraphicsState) { $graphics.Restore($pillGraphicsState) }
        if ($null -ne $pillShadowPath) { $pillShadowPath.Dispose() }
        if ($null -ne $pillPath) { $pillPath.Dispose() }
        if ($null -ne $pillHighlightPath) { $pillHighlightPath.Dispose() }
        if ($null -ne $liquidFillPath) { $liquidFillPath.Dispose() }
        if ($null -ne $liquidFrontPath) { $liquidFrontPath.Dispose() }
        if ($null -ne $pillShadowBrush) { $pillShadowBrush.Dispose() }
        if ($null -ne $pillBaseBrush) { $pillBaseBrush.Dispose() }
        if ($null -ne $pillBrush) { $pillBrush.Dispose() }
        if ($null -ne $pillEdgePen) { $pillEdgePen.Dispose() }
        if ($null -ne $pillHighlightPen) { $pillHighlightPen.Dispose() }
        if ($null -ne $pillLiquidEdgePen) { $pillLiquidEdgePen.Dispose() }
    }
    # Minimal section labels: subdued gray typography only, with no rules or accent marks.
    # Vertical spacing separates the groups without adding visual clutter.
    $sectionFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]9.8, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $sectionBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 112, 119, 130))
    $sectionFormat = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
    $sectionFormat.FormatFlags = $sectionFormat.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap
    $sectionCaptions = @(
        @{ Text='MAIN'; Y=81.0 },
        @{ Text='TUNE'; Y=169.0 },
        @{ Text='SYSTEM'; Y=361.0 }
    )
    try {
        foreach ($caption in $sectionCaptions) {
            $captionText = [string]$caption.Text
            $captionY = [single]$caption.Y
            $graphics.DrawString($captionText, $sectionFont, $sectionBrush, [single]18.0, $captionY, $sectionFormat)
        }
    } finally {
        $sectionFormat.Dispose()
        $sectionBrush.Dispose()
        $sectionFont.Dispose()
    }
    $navTileHeight = 46.0
    # Base label style stays consistent; hover scales the item as a single visual unit.
    $navFont = [System.Drawing.Font]::new('Segoe UI Semibold', [single]13.2, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    # Optical vertical alignment is calibrated per icon silhouette rather than applying one
    # global offset: the monitor/gear and trash-bin glyphs have different visual centers.
    $navLabelVerticalOffsets = @{
        'HOME'       = 9.0
        'FPS TWEAK'  = 10.0
        'LATENCY'    = 8.7
        'NET'        = 10.0
        'CLEAN UP'   = 10.3
    }
    $navFormat = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
    $navFormat.FormatFlags = $navFormat.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap
    $navFormat.Alignment = [System.Drawing.StringAlignment]::Near
    $navFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $navFormat.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
    try {
        for ($navIndex = 0; $navIndex -lt $navItems.Count; $navIndex++) {
            $nav = $navItems[$navIndex]
            $navY = [double]$nav.Y
            # Preserve a stable hit-test rectangle; the selected tile does not move or scale.
            $navRect = [System.Drawing.RectangleF]::new(10.0, [single]$navY, 198.0, [single]$navTileHeight)
            $script:mainNavRects[$nav.Key] = $navRect
            $animRawT = 0.0
            if ($null -ne $script:mainNavAnim -and $script:mainNavAnim.ContainsKey([string]$nav.Key)) {
                $animRawT = [double]$script:mainNavAnim[[string]$nav.Key]
            }
            # Hit rectangles remain stable. Only the painted tile, icon and label react to hover.
            $animT = [math]::Max(0.0, [math]::Min(1.0, $animRawT))
            $visualRect = [System.Drawing.RectangleF]::new(7.0, [single]($navY - 1.0), 204.0, 48.0)
            $visualCenterX = [double]($visualRect.X + ($visualRect.Width / 2.0))
            $visualCenterY = [double]($visualRect.Y + ($visualRect.Height / 2.0))
            $hoverRawT = 0.0
            if ($null -ne $script:mainNavHoverAnim -and $script:mainNavHoverAnim.ContainsKey([string]$nav.Key)) {
                $hoverRawT = [double]$script:mainNavHoverAnim[[string]$nav.Key]
            }
            # Out-back easing can briefly reach ~1.1; that overshoot creates a confident, polished pop.
            $hoverT = [math]::Max(0.0, [math]::Min(1.12, $hoverRawT))
            $hoverStrength = [math]::Min(1.0, $hoverT)
            $hoverScale = 1.0 + (0.04 * $hoverT)
            $hoverLift = 2.5 * $hoverT
            $drawWidth = [single]($visualRect.Width * $hoverScale)
            $drawHeight = [single]($visualRect.Height * $hoverScale)
            $drawRect = [System.Drawing.RectangleF]::new(
                [single]($visualCenterX - ($drawWidth / 2.0)),
                [single]($visualCenterY - ($drawHeight / 2.0) - $hoverLift),
                $drawWidth,
                $drawHeight
            )
            # Unselected hover gets a restrained raised glass-gray surface and a soft shadow.
            if ($hoverStrength -gt 0.002 -and $animT -lt 0.15 -and -not $script:mainNavSelectionAnimating) {
                $hoverRadius = [single]12.0
                $hoverAlpha = [int][math]::Round(174.0 * $hoverStrength)
                $hoverShadowAlpha = [int][math]::Round(26.0 * $hoverStrength)
                $hoverShadowPath = New-RoundedRectPath ([single]$drawRect.X) ([single]($drawRect.Y + 2.0)) ([single]$drawRect.Width) ([single]$drawRect.Height) $hoverRadius
                $hoverPath = New-RoundedRectPath ([single]$drawRect.X) ([single]$drawRect.Y) ([single]$drawRect.Width) ([single]$drawRect.Height) $hoverRadius
                $hoverShadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($hoverShadowAlpha, 35, 39, 45))
                $hoverBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
                    $drawRect,
                    [System.Drawing.Color]::FromArgb($hoverAlpha, 235, 238, 243),
                    [System.Drawing.Color]::FromArgb($hoverAlpha, 216, 221, 228),
                    [single]90.0
                )
                $hoverPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb([int][math]::Round(78.0 * $hoverStrength), 151, 159, 170), [single]0.8)
                try {
                    $graphics.FillPath($hoverShadowBrush, $hoverShadowPath)
                    $graphics.FillPath($hoverBrush, $hoverPath)
                    $graphics.DrawPath($hoverPen, $hoverPath)
                } finally {
                    $hoverShadowPath.Dispose()
                    $hoverPath.Dispose()
                    $hoverShadowBrush.Dispose()
                    $hoverBrush.Dispose()
                    $hoverPen.Dispose()
                }
            }

            # Since selection appears directly at the clicked row, icon and label ink
            # cross-fade between the old and new active states; there is no moving-pill overlap.
            $labelInkT = $animT
            $iconInkT = $animT
            $inkChannel = [int][math]::Round(112.0 - (67.0 * $labelInkT))
            $navColor = [System.Drawing.Color]::FromArgb(255, $inkChannel, $inkChannel, $inkChannel)
            $iconChannel = [int][math]::Round(112.0 - (67.0 * $iconInkT))
            $iconColor = [System.Drawing.Color]::FromArgb(255, $iconChannel, $iconChannel, $iconChannel)
            $baseIconSize = [single]22.7
            $baseIconX = [double]($navRect.X + 9.0)
            $baseIconY = [double]($visualRect.Y + (($visualRect.Height - $baseIconSize) / 2.0))
            $iconX = [single]($visualCenterX + (($baseIconX - $visualCenterX) * $hoverScale))
            $iconY = [single]($visualCenterY + (($baseIconY - $visualCenterY) * $hoverScale) - $hoverLift)
            $iconSize = [single]($baseIconSize * $hoverScale)
            Draw-HSMainIcon $graphics $nav.Icon $iconX $iconY $iconSize $iconColor ([bool]($labelInkT -ge 0.985 -and $nav.Icon -eq 'home'))

            $labelBrush = $null
            $itemNavFont = $navFont
            try {
                $labelBrush = [System.Drawing.SolidBrush]::new($navColor)
                $baseLabelX = [double][math]::Round($navRect.X + 48.0)
                $labelFontHeight = [single]($itemNavFont.GetHeight($graphics))
                $labelVerticalOffset = [double]$navLabelVerticalOffsets[[string]$nav.Key]
                $baseLabelY = [double]($visualCenterY - ([double]$labelFontHeight / 2.0) + $labelVerticalOffset)
                # Keep the label's horizontal origin fixed during hover. The tile and icon
                # provide the pop; moving a fixed-size DrawString origin toward the tile center
                # made the text appear to drift and then snap right when hover ended.
                $labelX = [single]$baseLabelX
                $labelY = [single]($visualCenterY + (($baseLabelY - $visualCenterY) * $hoverScale) - $hoverLift)
                $labelPoint = [System.Drawing.PointF]::new($labelX, $labelY)
                $graphics.DrawString([string]$nav.Label, $itemNavFont, $labelBrush, $labelPoint, $navFormat)
            } finally {
                if ($null -ne $labelBrush) { $labelBrush.Dispose() }
            }
        }
    } finally {
        $navFormat.Dispose()
        $navFont.Dispose()
    }

    # Keep the lower Sidebar intentionally empty for the clean reference layout.

    # Home shows the live system dashboard; other sections keep the clean canvas.
    if ([string]$script:mainActiveSection -eq 'HOME') {
        Draw-HSHomeDashboard $graphics $width $height
    }

    # Keep the window chrome above the content cards.
    $outerPath = New-RoundedRectPath 0.5 0.5 ([single]($width - 1.0)) ([single]($height - 1.0)) 14.0
    $outerPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(100, 204, 210, 219), [single]0.8)
    try {
        $graphics.DrawPath($outerPen, $outerPath)
    } finally {
        $outerPath.Dispose()
        $outerPen.Dispose()
    }
    Draw-HSMainWindowControls $graphics $width
}

function Get-HSMainNavVisualTop {
    param([string]$SectionKey)
    switch ($SectionKey) {
        'HOME'      { return 101.0 }
        'FPS TWEAK' { return 189.0 }
        'LATENCY'   { return 238.0 }
        'NET'       { return 287.0 }
        'CLEAN UP'  { return 381.0 }
        default     { return 101.0 }
    }
}

function Get-HSMainHitTest {
    param([single]$x, [single]$y)
    if ($null -ne $script:mainNavRects) {
        foreach ($key in $script:mainNavRects.Keys) {
            if ($script:mainNavRects[$key].Contains($x,$y)) { return ('NAV:' + [string]$key) }
        }
    }
    if ($null -ne $script:maxRect -and $script:maxRect.Contains($x,$y)) { return 'MAXIMIZE' }
    return ''
}

function Invalidate-HSMainSidebar {
    if ($null -eq $form -or $form.IsDisposed) { return }
    $invalidateWidth = [int][math]::Min(226.0, [double]$form.ClientSize.Width)
    $invalidateHeight = [int]$form.ClientSize.Height
    if ($invalidateWidth -gt 0 -and $invalidateHeight -gt 0) {
        $form.Invalidate([System.Drawing.Rectangle]::new(0, 0, $invalidateWidth, $invalidateHeight), $false)
    }
}

function Invalidate-HSHomeDashboard {
    if ($null -eq $form -or $form.IsDisposed -or [string]$script:page -ne 'main' -or [string]$script:mainActiveSection -ne 'HOME') { return }
    $width = [double]$form.ClientSize.Width
    $height = [double]$form.ClientSize.Height
    $left = 218
    $rect = [System.Drawing.Rectangle]::new($left, 0, [int][math]::Max(1.0, $width - $left), [int][math]::Max(1.0, $height))
    $form.Invalidate($rect, $false)
}

function Set-HSMainNavHoverTarget {
    param([string]$HitTarget)

    $newHoverKey = ''
    if (-not [string]::IsNullOrWhiteSpace($HitTarget) -and $HitTarget.StartsWith('NAV:', [System.StringComparison]::Ordinal)) {
        $candidate = $HitTarget.Substring(4)
        if ($script:mainNavHoverAnim.ContainsKey($candidate)) { $newHoverKey = $candidate }
    }
    if ($newHoverKey -eq [string]$script:mainNavHoverTargetKey) { return }

    $script:mainNavHoverTargetKey = $newHoverKey
    $hoverNow = [double]$script:sw.Elapsed.TotalSeconds
    foreach ($navKey in @('HOME','FPS TWEAK','LATENCY','NET','CLEAN UP')) {
        $script:mainNavHoverAnimFrom[$navKey] = [double]$script:mainNavHoverAnim[$navKey]
        $script:mainNavHoverAnimTarget[$navKey] = [double]($navKey -eq $newHoverKey)
    }
    $script:mainNavHoverAnimStartTime = $hoverNow
    $script:mainNavHoverAnimating = $true
    $timer.Interval = 10
    if (-not $timer.Enabled) { $timer.Start() }
    Invalidate-HSMainSidebar
}

function Start-HSActivationSequence {
    if ([string]::IsNullOrWhiteSpace([string]$script:licenseText)) {
        $script:licenseStatus = 'ENTER YOUR LICENSE KEY'
        $script:licenseStatusKind = 'error'
        $script:licenseFlash = 1.0
        return $false
    }
    # Visual prototype only. Real license validation is intentionally not implemented yet.
    $script:licenseActivated = $true
    $script:licenseFocused = $false
    $script:licenseCaretVisible = $false
    $script:licenseStatus = 'DEMO KEY ACCEPTED'
    $script:licenseStatusKind = 'success'
    $script:page = 'loading'
    $script:loadElapsed = 0.0
    $script:loadFadeElapsed = 0.0
    $script:drainElapsed = 0.0
    $script:checkElapsed = 0.0
    $script:hover = ''
    $script:btnTarget = 0.0
    $script:hoverT = 0.0
    $script:lastFrameTime = $script:sw.Elapsed.TotalSeconds
    # The background is only needed on the Key page. Stop it as soon as the page leaves.
    if ($null -ne $script:lightPillarEngine) { try { $script:lightPillarEngine.Dispose() } catch { }; $script:lightPillarEngine = $null }
    if ($null -ne $script:lightPillarBitmap) { try { $script:lightPillarBitmap.Dispose() } catch { }; $script:lightPillarBitmap = $null }
    return $true
}

# -----------------------------------------------------------------------------
# STATIC UI CACHE
# Static text, frame and vector resources are prepared once, not rebuilt each Paint.
# This keeps the key page smooth while preserving crisp WinForms/GDI+ rendering.
# -----------------------------------------------------------------------------
$script:activateLabelBitmap = $null
$script:activationHeadingBitmap = $null
$script:footerTaglineBitmap = $null
$script:footerRulePen = $null
$script:ctaArrowPen = $null
$script:hxHighBaseBrush = $null
$script:hxXGradientBrush = $null
$script:hxHighEdgePen = $null
$script:hxXEdgePen = $null
$script:closeGlowPen = $null
$script:minGlowPen = $null
$script:closeCorePen = $null
$script:minCorePen = $null
$script:closeHoverBrush = $null
$script:minHoverBrush = $null

try {
    $script:footerRulePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(58, 191, 198, 208), [single]0.65)
    $script:footerRulePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
    $script:footerRulePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat
    $script:ctaArrowPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255,28,31,36), [single]1.55)
    $script:ctaArrowPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $script:ctaArrowPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    if ($null -ne $script:hxHighPath) {
        $script:hxHighBaseBrush = New-HXMetallicBrush -Bounds ($script:hxHighPath.GetBounds()) -Tone 'high'
        $script:hxHighEdgePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(38,255,255,255), [single]0.42)
        $script:hxHighEdgePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    }
    if ($null -ne $script:hxXPath) {
        $script:hxXGradientBrush = New-HXMetallicBrush -Bounds ($script:hxXPath.GetBounds()) -Tone 'x'
        $script:hxXEdgePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(58,255,255,255), [single]0.48)
        $script:hxXEdgePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    }
} catch { }

# Centered, widely tracked SCRIPT caption below the wordmark.
$headingG = $null; $headingFont = $null; $headingBrush = $null
try {
    # Extra-wide tracking for the minimal SCRIPT wordmark.
    # The wider cached surface prevents the letterforms from clipping while keeping the caption centered.
    $script:activationHeadingBitmap = [System.Drawing.Bitmap]::new(360,28,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $headingG = [System.Drawing.Graphics]::FromImage($script:activationHeadingBitmap)
    $headingG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $headingG.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $headingG.Clear([System.Drawing.Color]::Transparent)
    $headingFont = [System.Drawing.Font]::new($fam,10.2,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
    $headingBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(102,220,225,234))
    Draw-TrackedCenteredText $headingG 'SCRIPT' $headingFont $headingBrush 180.0 14.0 22.5
} catch {
    if ($null -ne $script:activationHeadingBitmap) { try { $script:activationHeadingBitmap.Dispose() } catch { } }
    $script:activationHeadingBitmap = $null
} finally {
    if ($null -ne $headingG) { try { $headingG.Dispose() } catch { } }
    if ($null -ne $headingFont) { try { $headingFont.Dispose() } catch { } }
    if ($null -ne $headingBrush) { try { $headingBrush.Dispose() } catch { } }
}

# Bottom micro-tagline is rasterized once; only the thin rules are painted on each frame.
$footerG = $null; $footerFont = $null; $footerBrush = $null
try {
    $script:footerTaglineBitmap = [System.Drawing.Bitmap]::new(240,24,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $footerG = [System.Drawing.Graphics]::FromImage($script:footerTaglineBitmap)
    $footerG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $footerG.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $footerG.Clear([System.Drawing.Color]::Transparent)
    $footerFont = [System.Drawing.Font]::new($fam,7.8,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
    $footerBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(164,212,217,226))
    Draw-TrackedCenteredText $footerG 'HIGH X / PERFORMANCE BOOSTER' $footerFont $footerBrush 120.0 12.0 2.0
} catch {
    if ($null -ne $script:footerTaglineBitmap) { try { $script:footerTaglineBitmap.Dispose() } catch { } }
    $script:footerTaglineBitmap = $null
} finally {
    if ($null -ne $footerG) { try { $footerG.Dispose() } catch { } }
    if ($null -ne $footerFont) { try { $footerFont.Dispose() } catch { } }
    if ($null -ne $footerBrush) { try { $footerBrush.Dispose() } catch { } }
}

# Static CTA label cache; centered within the wider reference-style button.
$ctaLabelG = $null; $ctaLabelFont = $null; $ctaLabelBrush = $null
try {
    $script:activateLabelBitmap = [System.Drawing.Bitmap]::new(220,42,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $ctaLabelG = [System.Drawing.Graphics]::FromImage($script:activateLabelBitmap)
    $ctaLabelG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $ctaLabelG.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $ctaLabelG.Clear([System.Drawing.Color]::Transparent)
    $ctaLabelFont = [System.Drawing.Font]::new($fam,10.0,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $ctaLabelBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,18,20,23))
    Draw-TrackedCenteredText $ctaLabelG 'ACTIVATE' $ctaLabelFont $ctaLabelBrush 110.0 21.0 3.0
} catch {
    if ($null -ne $script:activateLabelBitmap) { try { $script:activateLabelBitmap.Dispose() } catch { } }
    $script:activateLabelBitmap = $null
} finally {
    if ($null -ne $ctaLabelBrush) { try { $ctaLabelBrush.Dispose() } catch { } }
    if ($null -ne $ctaLabelFont) { try { $ctaLabelFont.Dispose() } catch { } }
    if ($null -ne $ctaLabelG) { try { $ctaLabelG.Dispose() } catch { } }
}

$form.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.ResetTransform()

    if ($script:page -eq 'license') {
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.Clear([System.Drawing.Color]::FromArgb(255,0,0,1))
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver

        # Preserve the Key page's original LightPillar background at full opacity.
        $keyBgSource = if ($null -ne $script:lightPillarBitmap) { $script:lightPillarBitmap } else { $script:bg }
        if ($null -ne $keyBgSource) {
            $keyBgDest = [System.Drawing.Rectangle]::new(0,0,[int]$W,[int]$H)
            $g.DrawImage($keyBgSource, $keyBgDest, 0,0,[int]$keyBgSource.Width,[int]$keyBgSource.Height,[System.Drawing.GraphicsUnit]::Pixel)
        }

        Draw-HXWindowControls $g ([double]$form.ClientSize.Width)
        # --- CENTERED HIGH X WORDMARK ---
        # Keep the original Syne ExtraBold vector lettering and metallic X sweep;
        # scale/position the existing wordmark as one optical unit for this layout.
        $brandCx = [double]($W / 2.0)
        $brandHighCy = [double]($H * 0.307)
        $brandLogoState = $g.Save()
        $logoScale = 0.89
        $logoMatrix = $null
        try {
            $logoCurrentCx = [double]($script:hxBounds.X + ($script:hxBounds.Width / 2.0))
            $logoCurrentCy = [double]($script:hxBounds.Y + ($script:hxBounds.Height / 2.0))
            $logoMatrix = [System.Drawing.Drawing2D.Matrix]::new(
                [single]$logoScale,
                [single]0.0,
                [single]0.0,
                [single]$logoScale,
                [single]($brandCx - ($logoCurrentCx * $logoScale)),
                [single]($brandHighCy - ($logoCurrentCy * $logoScale))
            )
            $g.Transform = $logoMatrix
            if ($null -ne $script:hxGlowBitmap) {
                $g.DrawImageUnscaled($script:hxGlowBitmap, $script:hxGlowX, $script:hxGlowY)
            }
            Draw-ShinyHighX $g
        } finally {
            $g.Restore($brandLogoState)
            if ($null -ne $logoMatrix) { $logoMatrix.Dispose() }
        }

        if ($null -ne $script:activationHeadingBitmap) {
            $headingX = [single](($W - $script:activationHeadingBitmap.Width) / 2.0)
            $headingY = [single](($H * 0.408) - ($script:activationHeadingBitmap.Height / 2.0))
            $g.DrawImageUnscaled($script:activationHeadingBitmap, [int]$headingX, [int]$headingY)
        }

# --- LICENSE KEY CTA ---
    # Frameless Key screen: slightly enlarged central composition with balanced vertical spacing.
        # Centered monochrome-glass Key field and matching Activate CTA.
        $licenseState = if($script:licenseFocused){1.0}else{0.0}

        # Minimal single-rim key field. Keep the translucent fill, but avoid extra
        # reflection strips and nested glow outlines.
        $keyFramePath = New-RoundedRectPath ([single]$licenseRect.X) ([single]$licenseRect.Y) `
            ([single]$licenseRect.Width) ([single]$licenseRect.Height) 9.0
        $keyFrameRect = [System.Drawing.RectangleF]::new(
            [single]$licenseRect.X, [single]$licenseRect.Y,
            [single]$licenseRect.Width, [single]$licenseRect.Height
        )

        # Subtle translucent monochrome glass fill; the dark background remains visible.
        $keyGlassBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $keyFrameRect,
            [System.Drawing.Color]::FromArgb([int](18 + 8*$licenseState), 246, 248, 252),
            [System.Drawing.Color]::FromArgb([int](6 + 5*$licenseState), 151, 160, 172),
            [single]90.0
        )
        $g.FillPath($keyGlassBrush, $keyFramePath)
        $keyGlassBrush.Dispose()

        # Hairline silver contour: a single clean rim with a gentle top-to-bottom falloff.
        $keyFrameBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $keyFrameRect,
            [System.Drawing.Color]::FromArgb([int](176 + 34*$licenseState), 242, 247, 255),
            [System.Drawing.Color]::FromArgb([int](104 + 24*$licenseState), 177, 191, 211),
            [single]90.0
        )
        $keyFramePen = [System.Drawing.Pen]::new($keyFrameBrush, [single]0.74)
        $keyFramePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPath($keyFramePen, $keyFramePath)
        $keyFramePen.Dispose()
        $keyFrameBrush.Dispose()
        $keyFramePath.Dispose()

        # Intentionally no key icon: keep the input field clean and minimal.



        # Key input typography: clean left-aligned text with no leading icon.
        # Glyph ink bounds are used instead of font metrics so placeholder text
        # remains crisp and vertically balanced.
        $lf = $script:keyInputFont
        $keyInputFontTemporary = $false
        if ($null -eq $lf) {
            $keyUIFontFamily = if ($null -ne $script:keyFcFridayFontFamily) { $script:keyFcFridayFontFamily } else { $fam }
            $lf = [System.Drawing.Font]::new($keyUIFontFamily, [single]14.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $keyInputFontTemporary = $true
        }
        $hasText = -not [string]::IsNullOrWhiteSpace($script:licenseText)
        $lText = if($hasText){[string]$script:licenseText}else{''}
        $textColor = if($hasText){
            [System.Drawing.Color]::FromArgb(255, 248, 250, 253)
        } else {
            [System.Drawing.Color]::FromArgb([int](120 + 18*$licenseState), 225, 228, 233)
        }
        $lb = [System.Drawing.SolidBrush]::new($textColor)

        # Empty-state hint: muted silver, hidden during typing so the caret stays clear.
        if (-not $hasText -and -not $script:licenseFocused) {
            $placeholderBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(105, 190, 195, 203))
            $placeholderRect = [System.Drawing.RectangleF]::new(
                [single]($licenseRect.X + 24.0), [single]$licenseRect.Y,
                [single](($licenseRect.Right - 18.0) - ($licenseRect.X + 24.0)), [single]$licenseRect.Height
            )
            $placeholderFormat = [System.Drawing.StringFormat]::new()
            $placeholderFormat.Alignment = [System.Drawing.StringAlignment]::Near
            $placeholderFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
            $g.DrawString('Enter your key...', $lf, $placeholderBrush, $placeholderRect, $placeholderFormat)
            $placeholderFormat.Dispose()
            $placeholderBrush.Dispose()
        }

        # Keep a refined left inset while preserving the wide text area.
        $textAreaLeft  = [double]($licenseRect.X + 24.0)
        $textAreaRight = [double]($licenseRect.Right - 18.0)
        $textCenterY = [double]($licenseRect.Y + $licenseRect.Height / 2.0)
        $renderedTextWidth = 0.0

        if(-not [string]::IsNullOrEmpty($lText)) {
            # The actual Key value remains internal; only cached asterisks are drawn.
            # This keeps every Paint pass independent of the typed characters.
            $textRect = [System.Drawing.RectangleF]::new(
                [single]$textAreaLeft,
                [single]($licenseRect.Y + 5.0),
                [single]($textAreaRight - $textAreaLeft),
                [single]($licenseRect.Height - 10.0)
            )
            $keyTextFormat = $script:keyInputFormat
            $temporaryKeyTextFormat = $false
            if ($null -eq $keyTextFormat) {
                $keyTextFormat = [System.Drawing.StringFormat]::new()
                $keyTextFormat.Alignment = [System.Drawing.StringAlignment]::Near
                $keyTextFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
                $temporaryKeyTextFormat = $true
            }
            try {
                # Password mode: draw cached asterisks (not round bullets) at a fixed
                # advance, so hidden characters stay evenly spaced without revealing
                # the width of the original characters or rasterizing text during Paint.
                $glyphClipState = $g.Save()
                try {
                    $g.SetClip($textRect)
                    $maskCursorX = [double]$textAreaLeft
                    # A compact 9.5px cell keeps every allowed character visible in the wider
                    # reference-style field without crowding the right inset.
                    $maskAdvance = [double]$script:keyMaskAdvance
                    $maskGlyphBitmap = $null
                    $maskGlyphAdvance = 7.0
                    if ($null -ne $script:keyGlyphBitmaps -and $script:keyGlyphBitmaps.ContainsKey([char]'*')) {
                        $maskGlyphBitmap = $script:keyGlyphBitmaps[[char]'*']
                    }
                    if ($null -ne $script:keyGlyphAdvance -and $script:keyGlyphAdvance.ContainsKey([char]'*')) {
                        $maskGlyphAdvance = [double]$script:keyGlyphAdvance[[char]'*']
                    }
                    $maskGlyphOffsetX = [math]::Max(0.0, ($maskAdvance - $maskGlyphAdvance) / 2.0)
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    for ($maskIndex = 0; $maskIndex -lt $lText.Length; $maskIndex++) {
                        if ($maskCursorX -ge $textAreaRight) { break }
                        if ($null -ne $maskGlyphBitmap) {
                            # Scale the supersampled glyph down to the input's logical text height.
                            $maskGlyphWidth = [single]($maskGlyphBitmap.Width / $script:keyGlyphBitmapScale)
                            $maskGlyphDest = [System.Drawing.RectangleF]::new(
                                [single]($maskCursorX + $maskGlyphOffsetX), [single]$textRect.Y,
                                $maskGlyphWidth, [single]$textRect.Height
                            )
                            # Use the RectangleF/RectangleF DrawImage overload; the overload
                            # taking separate source coordinates requires an integer Rectangle
                            # and throws when the destination is a RectangleF.
                            $maskGlyphSource = [System.Drawing.RectangleF]::new(
                                [single]0.0, [single]0.0,
                                [single]$maskGlyphBitmap.Width, [single]$maskGlyphBitmap.Height
                            )
                            $g.DrawImage(
                                $maskGlyphBitmap, $maskGlyphDest, $maskGlyphSource,
                                [System.Drawing.GraphicsUnit]::Pixel
                            )
                        } else {
                            # Rare fallback only if startup glyph rasterization failed.
                            $maskCharRect = [System.Drawing.RectangleF]::new(
                                [single]$maskCursorX, [single]$textRect.Y,
                                [single]$maskAdvance, [single]$textRect.Height
                            )
                            $g.DrawString('*', $lf, $lb, $maskCharRect, $keyTextFormat)
                        }
                        $maskCursorX += $maskAdvance
                    }
                } finally {
                    $g.Restore($glyphClipState)
                }
                $renderedTextWidth = [double]($lText.Length * $maskAdvance)
            } finally {
                if ($temporaryKeyTextFormat) { $keyTextFormat.Dispose() }
            }
        }

        if($script:licenseFocused) {
            # With no text, the caret starts at the left inset. Once text exists,
            # the caret follows the measured right edge of the left-aligned masked string.
            $caretX = if(-not [string]::IsNullOrEmpty($lText)) {
                [single]([math]::Min($textAreaRight - 1.0, $textAreaLeft + $renderedTextWidth + 1.0))
            } else {
                [single]$textAreaLeft
            }
            if($script:licenseCaretVisible){
                $caretGlow = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(30, 244, 247, 252), 2.6)
                $caretPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(225, 250, 252, 255), 0.85)
                $g.DrawLine($caretGlow,$caretX,[single]($licenseRect.Y+9),$caretX,[single]($licenseRect.Bottom-9))
                $g.DrawLine($caretPen,$caretX,[single]($licenseRect.Y+9),$caretX,[single]($licenseRect.Bottom-9))
                $caretGlow.Dispose(); $caretPen.Dispose()
            }
        }

        if ($keyInputFontTemporary) { $lf.Dispose() }
        $lb.Dispose()

        # Dedicated Activate CTA on the License page.
        $ctaRect = $activateRect
        # Activate button uses the same compact glass style as the source Key page.
        $bcx = [double]($ctaRect.X + $ctaRect.Width / 2.0)
        $bcy = [double]($ctaRect.Y + $ctaRect.Height / 2.0)
        $btnState = $g.Save()
        try {
            $g.TranslateTransform([single]$bcx, [single]$bcy)
            $g.ScaleTransform([single](1.0 + ([double]$script:hoverT * 0.02)), [single](1.0 + ([double]$script:hoverT * 0.02)))
            $g.TranslateTransform([single](-$bcx), [single](-$bcy))
            $btnPath = New-RoundedRectPath ([single]$ctaRect.X) ([single]$ctaRect.Y) ([single]$ctaRect.Width) ([single]$ctaRect.Height) 9.5
            $btnGlassRect = [System.Drawing.RectangleF]::new([single]$ctaRect.X,[single]$ctaRect.Y,[single]$ctaRect.Width,[single]$ctaRect.Height)
            $btnHover = [math]::Max(0.0,[math]::Min(1.0,[double]$script:hoverT))
            $btnGlassBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
                $btnGlassRect,
                [System.Drawing.Color]::FromArgb([int](244+8*$btnHover),250,251,253),
                [System.Drawing.Color]::FromArgb([int](228+12*$btnHover),205,212,222),
                [single]90.0
            )
            $g.FillPath($btnGlassBrush,$btnPath)
            $btnGlassBrush.Dispose()
            # One fine silver rim instead of three stacked outlines; keep the button clean.
            $btnEdgeBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
                $btnGlassRect,
                [System.Drawing.Color]::FromArgb([int](174 + 24*$btnHover), 244, 248, 255),
                [System.Drawing.Color]::FromArgb([int](96 + 22*$btnHover), 174, 190, 211),
                [single]90.0
            )
            $btnEdgePen = [System.Drawing.Pen]::new($btnEdgeBrush, [single]0.72)
            $btnEdgePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.DrawPath($btnEdgePen, $btnPath)
            $btnEdgePen.Dispose()
            $btnEdgeBrush.Dispose()
            $btnPath.Dispose()
            if ($null -ne $script:activateLabelBitmap) {
                $labelX = [single]($bcx - ($script:activateLabelBitmap.Width / 2.0))
                $labelY = [single]($bcy - ($script:activateLabelBitmap.Height / 2.0))
                $g.DrawImageUnscaled($script:activateLabelBitmap, [int]$labelX, [int]$labelY)
            } else {
                $btnFont = [System.Drawing.Font]::new($fam,10.0,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
                $btnBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,18,20,23))
                Draw-TrackedCenteredText $g 'ACTIVATE' $btnFont $btnBrush $bcx $bcy 3.0
                $btnFont.Dispose(); $btnBrush.Dispose()
            }
            if ($null -ne $script:ctaArrowPen) {
                $arrowCx = [single]($ctaRect.Right - 32.0)
                $arrowCy = [single]$bcy
                $g.DrawLine($script:ctaArrowPen, [single]($arrowCx-8.0), $arrowCy, [single]($arrowCx+8.0), $arrowCy)
                $g.DrawLine($script:ctaArrowPen, [single]($arrowCx+2.5), [single]($arrowCy-5.2), [single]($arrowCx+8.0), $arrowCy)
                $g.DrawLine($script:ctaArrowPen, [single]($arrowCx+2.5), [single]($arrowCy+5.2), [single]($arrowCx+8.0), $arrowCy)
            }
        } finally { $g.Restore($btnState) }

        if ($script:licenseStatusKind -eq 'error') {
            $statusFont = [System.Drawing.Font]::new($fam, 10.0, [System.Drawing.FontStyle]::Regular)
            $statusBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(210,221,224,230))
            Draw-TrackedCenteredText $g ([string]$script:licenseStatus) $statusFont $statusBrush $licenseCenterX ([double]($H*0.682)) 1.3
            $statusFont.Dispose(); $statusBrush.Dispose()
        }

        # Reference-style footer: a quiet tracked tagline with short silver rules.
        $footerCy = [single]($H * 0.718)
        if ($null -ne $script:footerRulePen) {
            $g.DrawLine($script:footerRulePen, [single]($licenseCenterX-182.0), $footerCy, [single]($licenseCenterX-135.0), $footerCy)
            $g.DrawLine($script:footerRulePen, [single]($licenseCenterX+135.0), $footerCy, [single]($licenseCenterX+182.0), $footerCy)
        }
        if ($null -ne $script:footerTaglineBitmap) {
            $footerX = [single]($licenseCenterX - ($script:footerTaglineBitmap.Width / 2.0))
            $footerY = [single]($footerCy - ($script:footerTaglineBitmap.Height / 2.0))
            $g.DrawImageUnscaled($script:footerTaglineBitmap, [int]$footerX, [int]$footerY)
        }
    }
    elseif ($script:page -eq 'loading' -or $script:page -eq 'drain' -or $script:page -eq 'check') {
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.Clear([System.Drawing.Color]::Black)
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        Draw-LoadingSequence $g
    }
    elseif ($script:page -eq 'main') {
        # Render the navigation rail and the selected section's content.
        Draw-HSMainInterface $g ([double]$form.ClientSize.Width) ([double]$form.ClientSize.Height)
    } else {
        # Safe visual fallback for any unrecognized page state.
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.Clear([System.Drawing.Color]::FromArgb(255,0,0,1))
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        Draw-HXWindowControls $g ([double]$form.ClientSize.Width)
    }
})

$form.Add_KeyDown({
    param($sender, $e)
    if ($script:page -ne 'license' -or -not $script:licenseFocused) { return }
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        [void](Start-HSActivationSequence)
        $form.Invalidate(); $e.SuppressKeyPress = $true; return
    }
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        $script:licenseFocused = $false; $script:hover = ''; $form.Invalidate(); $e.SuppressKeyPress = $true; return
    }
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Back) {
        if ($script:licenseText.Length -gt 0) { $script:licenseText = $script:licenseText.Substring(0,$script:licenseText.Length-1) }
        $script:licenseStatusKind = 'idle'; $form.Invalidate(); $e.SuppressKeyPress = $true; return
    }
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::V) {
        try {
            $clip = [System.Windows.Forms.Clipboard]::GetText()
            if ($null -ne $clip) {
                $script:licenseText = [string]($clip -replace '[^A-Za-z0-9-]','')
                if ($script:licenseText.Length -gt 40) { $script:licenseText = $script:licenseText.Substring(0,40) }
                $script:licenseStatusKind = 'idle'; $form.Invalidate()
            }
        } catch { }
        $e.SuppressKeyPress = $true
    }
})
$form.Add_KeyPress({
    param($sender, $e)
    if ($script:page -ne 'license' -or -not $script:licenseFocused) { return }
    $ch = [char]$e.KeyChar
    if ([char]::IsLetterOrDigit($ch) -or $ch -eq '-') {
        if ($script:licenseText.Length -lt 40) {
            # Store the actual Key value internally; its visible representation is always masked.
            $script:licenseText += [string]$ch
            $script:licenseStatusKind = 'idle'
            $form.Invalidate()
        }
        $e.Handled = $true
    }
})
$form.Add_MouseMove({
    param($sender, $e)
    if ($script:windowDragging) {
        $cp = [System.Windows.Forms.Cursor]::Position
        $form.Location = [System.Drawing.Point]::new(
            [int]($script:windowDragBaseX + ($cp.X - $script:windowDragStartScreenX)),
            [int]($script:windowDragBaseY + ($cp.Y - $script:windowDragStartScreenY))
        )
        return
    }
    $h = ''
    if ($script:closeRect.Contains($e.X,$e.Y)) { $h = 'close' }
    elseif ($script:page -eq 'main' -and $script:maxRect.Contains($e.X,$e.Y)) { $h = 'max' }
    elseif ($script:minRect.Contains($e.X,$e.Y)) { $h = 'min' }
    elseif ($script:page -eq 'license' -and $licenseRect.Contains($e.X,$e.Y)) { $h = 'license' }
    elseif ($script:page -eq 'license' -and $activateRect.Contains($e.X,$e.Y)) { $h = 'activate' }

    $previousMainHover = [string]$script:mainHover
    if ($script:page -eq 'main') {
        if ($h -eq 'max') { $script:mainHover = 'MAXIMIZE' }
        elseif ($h -eq '') { $script:mainHover = [string](Get-HSMainHitTest ([single]$e.X) ([single]$e.Y)) }
        else { $script:mainHover = '' }
    } else { $script:mainHover = '' }

    if ($script:page -eq 'main' -and $previousMainHover -ne [string]$script:mainHover) {
        Set-HSMainNavHoverTarget ([string]$script:mainHover)
    }

    if ($h -ne $script:hover -or $previousMainHover -ne [string]$script:mainHover) {
        $script:hover = $h
        if ($script:page -eq 'main') {
            Invalidate-HSMainSidebar
            if ($h -eq 'close' -or $h -eq 'min' -or $h -eq 'max' -or $previousMainHover -eq 'MAXIMIZE') {
                $form.Invalidate([System.Drawing.Rectangle]::new([int][math]::Max(0, $form.ClientSize.Width - 120), 0, [int][math]::Min(120, $form.ClientSize.Width), 42), $false)
            }
        } else { $form.Invalidate() }
    } else { $script:hover = $h }
    if ($h -eq 'license') {
        $form.Cursor = [System.Windows.Forms.Cursors]::IBeam
    } elseif ($h -eq 'close' -or $h -eq 'min' -or $h -eq 'max' -or $h -eq 'activate' -or -not [string]::IsNullOrEmpty([string]$script:mainHover)) {
        $form.Cursor = [System.Windows.Forms.Cursors]::Hand
    } else {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
    $script:btnTarget = if ($h -eq 'activate') { 1.0 } else { 0.0 }
})
$form.Add_MouseLeave({
    if ($script:page -eq 'main') { Set-HSMainNavHoverTarget '' }
    $script:hover = ''
    $script:mainHover = ''
    $script:btnTarget = 0.0
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    if ($script:page -eq 'main') { Invalidate-HSMainSidebar } else { $form.Invalidate() }
})
$form.Add_MouseDown({
    param($sender,$e)
    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    if ($script:closeRect.Contains($e.X,$e.Y)) { $form.Close(); return }
    if ($script:page -eq 'main' -and $script:maxRect.Contains($e.X,$e.Y)) {
        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) { $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal }
        else { $form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized }
        return
    }
    if ($script:minRect.Contains($e.X,$e.Y)) { $form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized; return }
    if ($script:page -eq 'main') {
        $mainTarget = [string](Get-HSMainHitTest ([single]$e.X) ([single]$e.Y))
        if ($mainTarget.StartsWith('NAV:', [System.StringComparison]::Ordinal)) {
            $nextSection = $mainTarget.Substring(4)
            if ($nextSection -ne $script:mainActiveSection) {
                # Snap the pill's anchor to the clicked row immediately, then spring-pop
                # at that fixed position. A rapid click retargets cleanly without any vertical slide.
                $targetNavTop = [double](Get-HSMainNavVisualTop $nextSection)
                $script:mainNavPillFromY = $targetNavTop
                $script:mainNavPillToY = $targetNavTop
                $script:mainNavPillCurrentY = $targetNavTop
                $script:mainActiveSection = $nextSection
                $animNow = [double]$script:sw.Elapsed.TotalSeconds
                foreach ($navKey in @('HOME','FPS TWEAK','LATENCY','NET','CLEAN UP')) {
                    # Snapshot the last actually-rendered values so rapid clicks never jump to stale spring state.
                    $script:mainNavAnimFrom[$navKey] = [double]$script:mainNavAnim[$navKey]
                    $script:mainNavAnimTarget[$navKey] = [double]($navKey -eq $nextSection)
                }
                $script:mainNavAnimStartTime = $animNow
                $script:mainNavSelectionProgress = 0.0
                $script:mainNavSelectionAnimating = $true
                $script:lastFrameTime = $animNow
                $timer.Interval = 10
                if (-not $timer.Enabled) { $timer.Start() }
            }
            # The page content changes with the selected section, so repaint the canvas as well as the Sidebar.
            $form.Invalidate()
            return
        }
    }
    if ($script:page -eq 'license' -and $licenseRect.Contains($e.X,$e.Y)) {
        $script:licenseFocused = $true
        $script:licenseCaretVisible = $true
        $script:licenseCaretClock = $script:sw.Elapsed.TotalSeconds
        $form.Focus(); $form.Invalidate(); return
    }
    if ($script:page -eq 'license' -and $activateRect.Contains($e.X,$e.Y)) {
        [void](Start-HSActivationSequence); $form.Invalidate(); return
    }
    if ($e.Y -lt 64) {
        $cp = [System.Windows.Forms.Cursor]::Position
        $script:windowDragging = $true
        $script:windowDragStartScreenX = [int]$cp.X
        $script:windowDragStartScreenY = [int]$cp.Y
        $script:windowDragBaseX = [int]$form.Location.X
        $script:windowDragBaseY = [int]$form.Location.Y
        $form.Capture = $true
    }
})
$form.Add_MouseUp({
    if ($script:windowDragging) { $script:windowDragging = $false; $form.Capture = $false }
})
$form.Add_SizeChanged({
    if ($script:page -eq 'main' -and $form.ClientSize.Width -gt 0) {
        $script:closeRect = [System.Drawing.RectangleF]::new(($form.ClientSize.Width - 38.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
        $script:maxRect = [System.Drawing.RectangleF]::new(($form.ClientSize.Width - 70.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
        $script:minRect = [System.Drawing.RectangleF]::new(($form.ClientSize.Width - 102.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
        $form.Invalidate()
    }
})

$timer = New-Object System.Windows.Forms.Timer
# 10 ms UI tick gives active animations headroom above 60 Hz.
# Actual displayed FPS still depends on Windows scheduling, refresh rate, and Paint cost.
$timer.Interval = 10
$timer.Add_Tick({
    $now = $script:sw.Elapsed.TotalSeconds
    $dt = $now - [double]$script:lastFrameTime
    if ($dt -lt 0.0) { $dt = 0.0 }
    if ($dt -gt 0.05) { $dt = 0.05 }
    $script:lastFrameTime = $now
    $script:frameDt = $dt

    $hoverDiff = [double]$script:btnTarget - [double]$script:hoverT
    $script:hoverT = [math]::Max(0.0,[math]::Min(1.0,[double]$script:hoverT + $hoverDiff * [math]::Min(1.0,$dt*12.0)))
    if ($script:licenseFocused -and ($now - $script:licenseCaretClock) -ge 0.48) {
        $script:licenseCaretVisible = -not $script:licenseCaretVisible
        $script:licenseCaretClock = $now
    }

    if ($script:page -eq 'license') {
        try { Update-LightPillarBackgroundFrame $now } catch { }
        $script:shinyPhase = (($now % [double]$script:shinySpeed) / [double]$script:shinySpeed)
        # Keep the title highlight in step with the 10 ms animation pump.
        # Its static text path and brushes are cached, and the light surface is
        # prepared outside Paint, so this no longer needs an artificial 30 FPS cap.
        try { Update-HighXLightFrame } catch { }
    }
    elseif ($script:page -eq 'loading') {
        $script:loadElapsed += $dt
        $script:loadFadeElapsed += $dt
        if ($script:loadElapsed -ge $script:loadDuration) { $script:page = 'drain'; $script:drainElapsed = 0.0 }
    }
    elseif ($script:page -eq 'drain') {
        $script:drainElapsed += $dt
        if ($script:drainElapsed -ge $script:drainDuration) { $script:page = 'check'; $script:checkElapsed = 0.0 }
    }
    elseif ($script:page -eq 'check') {
        $script:checkElapsed += $dt
        if ($script:checkElapsed -ge $script:checkDuration) {
            # Keep the current window instance and switch from Key entry into the landscape Main dashboard.
            # Resize the workspace and re-center it on the same display.
            $script:page = 'main'
            # During active main-page motion, use a short UI tick for 60+ Hz animation headroom.
            # The Sidebar invalidation is clipped to its own region and the timer stops when idle.
            $timer.Interval = 10
            $oldCenterX = [int]($form.Left + ($form.Width / 2.0))
            $oldCenterY = [int]($form.Top + ($form.Height / 2.0))
            $form.ClientSize = [System.Drawing.Size]::new($script:mainPageWidth, $script:mainPageHeight)
            $workArea = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
            $newLeft = [int]($oldCenterX - ($form.Width / 2.0))
            $newTop = [int]($oldCenterY - ($form.Height / 2.0))
            # Keep the larger page visible on shorter/smaller work areas.
            if ($form.Width -le $workArea.Width) {
                $newLeft = [int][math]::Max($workArea.Left, [math]::Min($newLeft, $workArea.Right - $form.Width))
            } else { $newLeft = [int]$workArea.Left }
            if ($form.Height -le $workArea.Height) {
                $newTop = [int][math]::Max($workArea.Top, [math]::Min($newTop, $workArea.Bottom - $form.Height))
            } else { $newTop = [int]$workArea.Top }
            $form.Location = [System.Drawing.Point]::new($newLeft, $newTop)
            $form.BackColor = [System.Drawing.Color]::White
            $script:closeRect = [System.Drawing.RectangleF]::new(($form.ClientSize.Width - 38.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
            $script:maxRect = [System.Drawing.RectangleF]::new(($form.ClientSize.Width - 70.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
            $script:minRect = [System.Drawing.RectangleF]::new(($form.ClientSize.Width - 102.0), $headerCtlY, $headerCtlSize, $headerCtlSize)
            # Rebuild only these small control pens/hover brushes in graphite for the white page.
            foreach ($name in @('closeGlowPen','minGlowPen','closeCorePen','minCorePen','closeHoverBrush','minHoverBrush')) {
                $resource = Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                if ($null -ne $resource) { try { $resource.Dispose() } catch { } }
                Set-Variable -Name $name -Scope Script -Value $null
            }
            $form.Invalidate()
        }
    }
    if ($script:page -eq 'main') {
        $needsPaint = $false
        $navKeys = @('HOME','FPS TWEAK','LATENCY','NET','CLEAN UP')

        if ($script:mainNavSelectionAnimating) {
            $animElapsed = [double]($now - [double]$script:mainNavAnimStartTime)
            $animDuration = [double][math]::Max(0.20, [double]$script:mainNavAnimDuration)
            $animProgress = [math]::Max(0.0, [math]::Min(1.0, ($animElapsed / $animDuration)))
            # The raw timeline drives a local spring-pop and the diagonal liquid reveal.
            # The active pill anchor remains at the destination throughout the animation.
            $animEase = $animProgress * $animProgress * (3.0 - (2.0 * $animProgress))
            $script:mainNavSelectionProgress = $animProgress
            $script:mainNavPillCurrentY = [double]$script:mainNavPillToY

            foreach ($navKey in $navKeys) {
                $from = [double]$script:mainNavAnimFrom[$navKey]
                $target = [double]$script:mainNavAnimTarget[$navKey]
                $script:mainNavAnim[$navKey] = [double]($from + (($target - $from) * $animEase))
            }

            if ($animProgress -lt 1.0) {
                $needsPaint = $true
            } else {
                foreach ($navKey in $navKeys) {
                    $script:mainNavAnim[$navKey] = [double]$script:mainNavAnimTarget[$navKey]
                }
                $script:mainNavSelectionProgress = 1.0
                $script:mainNavPillCurrentY = [double]$script:mainNavPillToY
                $script:mainNavSelectionAnimating = $false
                $needsPaint = $true
            }
        }

        if ($script:mainNavHoverAnimating) {
            $hoverElapsed = [double]($now - [double]$script:mainNavHoverAnimStartTime)
            $hoverDuration = [double][math]::Max(0.16, [double]$script:mainNavHoverAnimDuration)
            $hoverProgress = [math]::Max(0.0, [math]::Min(1.0, ($hoverElapsed / $hoverDuration)))

            foreach ($navKey in $navKeys) {
                $from = [double]$script:mainNavHoverAnimFrom[$navKey]
                $target = [double]$script:mainNavHoverAnimTarget[$navKey]
                if ($target -gt $from) {
                    # Out-back spring feel: a clear lift/pop with a small controlled overshoot.
                    $c1 = 1.70158
                    $c3 = $c1 + 1.0
                    $hoverEase = 1.0 + ($c3 * [math]::Pow($hoverProgress - 1.0, 3.0)) + ($c1 * [math]::Pow($hoverProgress - 1.0, 2.0))
                } else {
                    # Exit smoothly without a rebound when the pointer leaves the item.
                    $hoverEase = 1.0 - [math]::Pow((1.0 - $hoverProgress), 3.0)
                }
                $script:mainNavHoverAnim[$navKey] = [double]($from + (($target - $from) * $hoverEase))
            }

            if ($hoverProgress -lt 1.0) {
                $needsPaint = $true
            } else {
                foreach ($navKey in $navKeys) {
                    $script:mainNavHoverAnim[$navKey] = [double]$script:mainNavHoverAnimTarget[$navKey]
                }
                $script:mainNavHoverAnimating = $false
                $needsPaint = $true
            }
        }

        if ($needsPaint) {
            $timer.Interval = 10
            Invalidate-HSMainSidebar
        }

        # Home hardware counters refresh once per second; keep the idle timer slow to avoid needless repaints.
        if ([string]$script:mainActiveSection -eq 'HOME') {
            $metricsChanged = $false
            try { $metricsChanged = [bool](Update-HSMainHomeMetrics $now) } catch { }
            if ($metricsChanged) { Invalidate-HSHomeDashboard }
            if (-not $needsPaint) { $timer.Interval = 250 }
        } elseif (-not $script:mainNavSelectionAnimating -and -not $script:mainNavHoverAnimating) {
            $timer.Stop()
        }
        return
    }
    $form.Invalidate()
})

$form.Add_Shown({
    $script:sw.Restart()
    $script:lastFrameTime = 0.0
    $timer.Start()
    $form.Invalidate()
})

# Final cold-start warm-up against the actual Form Graphics context. The form handle
# already exists but the window is still hidden, so no warm-up pixels can flash to the user.
# This primes the native GDI+ path used by the first real key paint, before input is possible.
$windowWarmGraphics = $null
$windowWarmBrush = $null
try {
    if ($null -ne $script:keyInputFont -and $null -ne $script:keyInputFormat) {
        $windowWarmGraphics = $form.CreateGraphics()
        $windowWarmGraphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $windowWarmBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $windowWarmRect = [System.Drawing.RectangleF]::new(
            [single]($licenseRect.X + 24.0),
            [single]($licenseRect.Y + 5.0),
            [single](($licenseRect.Right - 18.0) - ($licenseRect.X + 24.0)),
            [single]($licenseRect.Height - 10.0)
        )
        if ($null -ne $script:keyGlyphBitmaps -and $script:keyGlyphBitmaps.ContainsKey([char]'*')) {
            $windowWarmGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $windowWarmGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $windowWarmGlyphBitmap = $script:keyGlyphBitmaps[[char]'*']
            $windowWarmGlyphDest = [System.Drawing.RectangleF]::new(
                0.0, 0.0,
                [single]($windowWarmGlyphBitmap.Width / $script:keyGlyphBitmapScale),
                [single]44.0
            )
            $windowWarmGlyphSource = [System.Drawing.RectangleF]::new(
                [single]0.0, [single]0.0,
                [single]$windowWarmGlyphBitmap.Width, [single]$windowWarmGlyphBitmap.Height
            )
            $windowWarmGraphics.DrawImage(
                $windowWarmGlyphBitmap, $windowWarmGlyphDest, $windowWarmGlyphSource,
                [System.Drawing.GraphicsUnit]::Pixel
            )
        } else {
            $windowWarmGraphics.DrawString('*', $script:keyInputFont, $windowWarmBrush, $windowWarmRect, $script:keyInputFormat)
        }
    }
} catch {
    # The cached asterisk bitmap remains available if window HDC warm-up fails.
} finally {
    if ($null -ne $windowWarmBrush) { try { $windowWarmBrush.Dispose() } catch { } }
    if ($null -ne $windowWarmGraphics) { try { $windowWarmGraphics.Dispose() } catch { } }
}

# Prime the actual non-empty Key Paint branch while the window is still hidden.
# Direct Graphics warm-up above does not execute the Form.Paint event's masked-text,
# clipping, and caret path. Use a disposable off-screen bitmap so the first typed
# character does not have to initialize that path on the interactive UI thread.
$script:keyPaintWarmBitmap = $null
$keyWarmSavedText = [string]$script:licenseText
$keyWarmSavedFocus = [bool]$script:licenseFocused
$keyWarmSavedCaret = [bool]$script:licenseCaretVisible
$keyWarmSavedStatusKind = [string]$script:licenseStatusKind
try {
    if ($script:page -eq 'license' -and $form.ClientSize.Width -gt 0 -and $form.ClientSize.Height -gt 0) {
        $script:keyPaintWarmBitmap = [System.Drawing.Bitmap]::new(
            [int]$form.ClientSize.Width,
            [int]$form.ClientSize.Height,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        $script:licenseText = 'X'
        $script:licenseFocused = $true
        $script:licenseCaretVisible = $true
        $script:licenseStatusKind = 'idle'
        $form.DrawToBitmap(
            $script:keyPaintWarmBitmap,
            [System.Drawing.Rectangle]::new(0, 0, [int]$form.ClientSize.Width, [int]$form.ClientSize.Height)
        )
    }
} catch {
    # Keep startup safe on systems where DrawToBitmap is unsupported for the Form.
} finally {
    $script:licenseText = $keyWarmSavedText
    $script:licenseFocused = $keyWarmSavedFocus
    $script:licenseCaretVisible = $keyWarmSavedCaret
    $script:licenseStatusKind = $keyWarmSavedStatusKind
    if ($null -ne $script:keyPaintWarmBitmap) {
        try { $script:keyPaintWarmBitmap.Dispose() } catch { }
        $script:keyPaintWarmBitmap = $null
    }
}

try {
    [void]$form.ShowDialog()
}
finally {
    if ($null -ne $timer) { try { $timer.Stop(); $timer.Dispose() } catch { } }
    foreach ($counter in @($script:mainHomeGpuCounters)) { if ($null -ne $counter) { try { $counter.Dispose() } catch { } } }
    if ($null -ne $script:mainHomeNvidiaProcess) {
        try { if (-not $script:mainHomeNvidiaProcess.HasExited) { $script:mainHomeNvidiaProcess.Kill() } } catch { }
        try { $script:mainHomeNvidiaProcess.Dispose() } catch { }
    }
    foreach ($counter in @($script:mainHomeCpuCounter, $script:mainHomeMemoryAvailableCounter)) { if ($null -ne $counter) { try { $counter.Dispose() } catch { } } }
    if ($null -ne $script:lightPillarEngine) { try { $script:lightPillarEngine.Dispose() } catch { } }
    foreach ($name in @('lightPillarBitmap','bg','hxGlowBitmap','hxSpotCombinedBitmap')) {
        $obj = Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $obj) { try { $obj.Dispose() } catch { } }
    }
    foreach ($name in @('hxPath','hxHighPath','hxXPath')) {
        $obj = Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $obj) { try { $obj.Dispose() } catch { } }
    }
    if ($null -ne $script:hxLetterPaths) { foreach ($path in $script:hxLetterPaths) { try { $path.Dispose() } catch { } } }
    if ($null -ne $script:keyGlyphBitmaps) {
        foreach ($cachedGlyphBitmap in $script:keyGlyphBitmaps.Values) { try { $cachedGlyphBitmap.Dispose() } catch { } }
        try { $script:keyGlyphBitmaps.Clear() } catch { }
    }
    if ($null -ne $script:keyInputFont) { try { $script:keyInputFont.Dispose() } catch { } }
    if ($null -ne $script:keyInputFormat) { try { $script:keyInputFormat.Dispose() } catch { } }
    foreach ($name in @('activateLabelBitmap','activationHeadingBitmap','footerTaglineBitmap','footerRulePen','ctaArrowPen','hxHighBaseBrush','hxXGradientBrush','hxHighEdgePen','hxXEdgePen','closeGlowPen','minGlowPen','closeCorePen','minCorePen','closeHoverBrush','minHoverBrush')) {
        $obj = Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $obj) { try { $obj.Dispose() } catch { } }
    }
    foreach ($name in @(
        'hxEmbeddedFontFamily','hxXEmbeddedFontFamily','meleteFontFamily','theNeueFontFamily',
        'syneExtraBoldFontFamily','pennaFontFamily','keyFcFridayFontFamily',
        'hxEmbeddedFontCollection','hxXEmbeddedFontCollection','meleteFontCollection',
        'theNeueFontCollection','syneExtraBoldFontCollection','pennaFontCollection','keyFcFridayFontCollection'
    )) {
        $obj = Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $obj) { try { $obj.Dispose() } catch { } }
    }
    if ($null -ne $form) { try { $form.Dispose() } catch { } }
}

# Generates the PetGuardian launcher icon set (pink gradient + white paw).
# Pure GDI+ / System.Drawing: no external tooling required.
# Outputs:
#   assets/icon/app_icon.png            1024x1024 full-bleed (launcher + web)
#   assets/icon/app_icon_foreground.png 1024x1024 paw on transparent bg
#                                       (Android adaptive icon safe zone)
param([int]$Size = 1024)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outDir = Join-Path $PSScriptRoot '..\assets\icon'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-PawGraphics([System.Drawing.Graphics]$g, [int]$canvas, [double]$k = 1.0) {
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $white = [System.Drawing.Brushes]::White

  # All coordinates are designed on a 1024 grid and scaled.
  $s = $canvas / 1024.0

  function Ell([float]$cx, [float]$cy, [float]$w, [float]$h, [float]$rotDeg) {
    # Scale the artwork about the paw's own center (512, 516) in grid space.
    # Scaling via an outer Graphics transform does not work here because the
    # ResetTransform() below would discard it between ellipses.
    $gx = 512 + ($cx - 512) * $k
    $gy = 516 + ($cy - 516) * $k
    $g.ResetTransform()
    $g.TranslateTransform($gx * $s, $gy * $s)
    $g.RotateTransform($rotDeg)
    $rw = ($w * $s * $k) / 2.0
    $rh = ($h * $s * $k) / 2.0
    $g.FillEllipse($white, -($rw), -($rh), $rw * 2, $rh * 2)
    $g.ResetTransform()
  }

  # Four toes: the outer pair tilts outward, the inner pair stands tall.
  Ell 350 430 128 170 -22   # left outer
  Ell 462 348 118 160  -8   # left inner
  Ell 562 348 118 160   8   # right inner
  Ell 674 430 128 170  22   # right outer

  # Main pad: wide, slightly squashed heart of the paw.
  Ell 512 620 360 290 0
}

# ---- full-bleed icon -------------------------------------------------------
$bmp = New-Object System.Drawing.Bitmap($Size, $Size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$rect = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $rect,
  [System.Drawing.Color]::FromArgb(255, 0xF0, 0x62, 0x92),
  [System.Drawing.Color]::FromArgb(255, 0xC2, 0x18, 0x5B),
  90)
$g.FillRectangle($grad, $rect)
# The paw's coordinates span ~48% of the 1024 grid; scale up so the artwork
# fills a launcher-appropriate ~63% of the full-bleed canvas.
New-PawGraphics $g $Size 1.3
$g.Dispose()
$bmp.Save((Join-Path $outDir 'app_icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# ---- adaptive foreground (paw on transparent) ------------------------------
$fg = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gf = [System.Drawing.Graphics]::FromImage($fg)
# flutter_launcher_icons wraps this drawable in android:inset="16%", which
# shrinks its content to ~68% of the 108dp adaptive canvas. The paw's own
# coordinates span ~48% of the grid, so scale by ~1.32 to land the artwork at
# ~64% pre-inset -> ~43% post-inset, comfortably inside the 66dp safe zone.
New-PawGraphics $gf $Size 1.32
$gf.Dispose()
$fg.Save((Join-Path $outDir 'app_icon_foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$fg.Dispose()

Write-Output "icons written to $outDir"

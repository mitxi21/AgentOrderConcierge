# Renders docfiles/order_workflow_diagram.png - the Phase 10 order-workflow diagram.
# The PNG is uploaded as a File on the Knowledge article "How an order moves through Keyburn",
# and the agent's OCC_ExplainOrderWorkflow action sends that File to a multimodal prompt
# template, so the IMAGE is the source of truth, not a text transcription.
#
# Two facts deliberately exist ONLY in this image (no Knowledge article text states them), so an
# eval fails if the agent regresses to text retrieval:
#   - unsubmitted drafts are kept for 30 days, then deleted
#   - an order can be cancelled any time before it ships (from Draft or Processing), not after
# The other timings repeat the published articles (processed within 1 business day; standard
# 5-7 / expedited 2-3 business days; returns within 30 days). Keep them in sync if those change.
#
# Run from the repo root:  powershell -File docfiles\make_order_workflow_diagram.ps1
# ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less UTF-8 as Windows-1252.

Add-Type -AssemblyName System.Drawing
$out = Join-Path $PSScriptRoot 'order_workflow_diagram.png'

$W = 1280; $H = 600
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::White)

$navy  = [System.Drawing.Color]::FromArgb(30, 50, 110)
$red   = [System.Drawing.Color]::FromArgb(170, 40, 40)
$title = New-Object System.Drawing.Font 'Segoe UI', 22, ([System.Drawing.FontStyle]::Bold)
$boxF  = New-Object System.Drawing.Font 'Segoe UI', 17, ([System.Drawing.FontStyle]::Bold)
$lblF  = New-Object System.Drawing.Font 'Segoe UI', 12
$noteF = New-Object System.Drawing.Font 'Segoe UI', 12, ([System.Drawing.FontStyle]::Italic)
$ink   = New-Object System.Drawing.SolidBrush $navy
$redB  = New-Object System.Drawing.SolidBrush $red
$center = New-Object System.Drawing.StringFormat; $center.Alignment = 'Center'; $center.LineAlignment = 'Center'

function Arrow($color, [float]$x1, [float]$y1, [float]$x2, [float]$y2, [bool]$dashed = $false) {
    $p = New-Object System.Drawing.Pen $color, 3
    $p.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap 6, 6
    if ($dashed) { $p.DashStyle = 'Dash' }
    $g.DrawLine($p, $x1, $y1, $x2, $y2); $p.Dispose()
}
function Box([string]$text, [float]$x, [float]$y, [System.Drawing.Color]$fill, [System.Drawing.Color]$edge) {
    $r = New-Object System.Drawing.RectangleF $x, $y, 220, 84
    $b = New-Object System.Drawing.SolidBrush $fill; $g.FillRectangle($b, $r); $b.Dispose()
    $p = New-Object System.Drawing.Pen $edge, 2.5; $g.DrawRectangle($p, $x, $y, 220, 84); $p.Dispose()
    $g.DrawString($text, $boxF, $ink, $r, $center)
}
function Label([string]$text, [float]$cx, [float]$y, $font, $brush) {
    $r = New-Object System.Drawing.RectangleF ($cx - 150), $y, 300, 44
    $g.DrawString($text, $font, $brush, $r, $center)
}

$g.DrawString('How an order moves through Keyburn', $title, $ink, 40, 24)

# Main line: Draft -> Processing -> Shipped -> Delivered
$blue = [System.Drawing.Color]::FromArgb(225, 235, 250)
$xs = 40, 360, 680, 1000; $y = 150
Box 'Draft'      $xs[0] $y $blue $navy
Box 'Processing' $xs[1] $y $blue $navy
Box 'Shipped'    $xs[2] $y $blue $navy
Box 'Delivered'  $xs[3] $y ([System.Drawing.Color]::FromArgb(225, 245, 230)) $navy
for ($i = 0; $i -lt 3; $i++) { Arrow $navy ($xs[$i] + 225) ($y + 42) ($xs[$i + 1] - 5) ($y + 42) }
# Arrow labels sit above the box row: the 100 px gaps between boxes are too narrow for text.
Label 'you submit the order'                  ($xs[0] + 270) ($y - 50) $lblF $ink
Label 'ships within 1 business day'           ($xs[1] + 270) ($y - 50) $lblF $ink
Label "standard 5-7 business days`nexpedited 2-3 business days" ($xs[2] + 270) ($y - 56) $lblF $ink

# Notes under the main boxes
Label "Unsubmitted drafts are kept`nfor 30 days, then deleted" ($xs[0] + 110) ($y + 92) $noteF $ink
Label "Can't be cancelled once shipped" ($xs[2] + 110) ($y + 92) $noteF $redB
Label "Returns: within 30 days`nof delivery" ($xs[3] + 110) ($y + 92) $noteF $ink

# Cancelled branch, reachable only from Draft and Processing
$cx = 200; $cy = 420
Box 'Cancelled' $cx $cy ([System.Drawing.Color]::FromArgb(250, 228, 228)) $red
Arrow $red ($xs[0] + 110) ($y + 140) ($cx + 70)  ($cy - 4) $true
Arrow $red ($xs[1] + 110) ($y + 140) ($cx + 150) ($cy - 4) $true
Label 'cancel any time before it ships' ($cx + 390) ($cy + 20) $lblF $redB

$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Output "Wrote $out"

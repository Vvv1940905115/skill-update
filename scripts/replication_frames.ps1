param(
    [Parameter(Mandatory = $true)]
    [string]$MediaPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [string]$FfmpegPath = "ffmpeg",
    [string]$FfprobePath = "ffprobe",
    [switch]$SkipContactSheets
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $MediaPath -PathType Leaf)) {
    throw "Media file not found: $MediaPath"
}

$mediaFullPath = (Resolve-Path -LiteralPath $MediaPath).Path
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputFullPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
$frameDirectory = Join-Path $outputFullPath "per_second_frames"
New-Item -ItemType Directory -Force -Path $frameDirectory | Out-Null

function Format-SecondCode {
    param([double]$Value)

    $safeValue = [Math]::Max(0, $Value)
    $minutes = [int][Math]::Floor($safeValue / 60)
    $seconds = [int][Math]::Floor($safeValue % 60)
    return ("{0:d2}:{1:d2}" -f $minutes, $seconds)
}

function Format-FractionalSecondCode {
    param([double]$Value)

    $safeValue = [double][Math]::Max([double]0, [double]$Value)
    $minutes = [int][Math]::Floor([double]($safeValue / [double]60))
    $seconds = [double]($safeValue - [double](60 * $minutes))
    $wholeSeconds = [int][Math]::Floor([double]$seconds)
    $milliseconds = [int][Math]::Floor([double]((($seconds - $wholeSeconds) * 1000) + 0.5))
    return ("{0:d2}:{1:d2}.{2:d3}" -f $minutes, $wholeSeconds, $milliseconds)
}

function Get-ToolPath {
    param(
        [string]$RequestedPath,
        [string]$ToolName
    )

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "$ToolName not found at: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $command = Get-Command -Name $RequestedPath -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "$ToolName was not found in PATH. Pass -$ToolName`Path explicitly."
    }
    return $command.Source
}

$ffmpeg = Get-ToolPath -RequestedPath $FfmpegPath -ToolName "ffmpeg"
$ffprobe = Get-ToolPath -RequestedPath $FfprobePath -ToolName "ffprobe"

$probeJson = & $ffprobe -v error -show_entries format=duration -of json -- $mediaFullPath
$probe = $probeJson | ConvertFrom-Json
$duration = [double]$probe.format.duration
$totalSeconds = [int][Math]::Ceiling($duration - 0.000001)

if ($duration -le 0 -or $totalSeconds -lt 1) {
    throw "Could not determine a positive duration for: $mediaFullPath"
}

$framePattern = Join-Path $frameDirectory "sec_%03d.jpg"
& $ffmpeg -hide_banner -loglevel error -y -i $mediaFullPath `
    -vf "fps=1,scale=640:-2" -q:v 3 $framePattern

$presentSeconds = @{}
Get-ChildItem -LiteralPath $frameDirectory -File -Filter "sec_*.jpg" |
    ForEach-Object {
        $presentSeconds[[int]$_.BaseName.Substring(4) - 1] = $true
    }

for ($second = 0; $second -lt $totalSeconds; $second++) {
    if ($presentSeconds.ContainsKey($second)) {
        continue
    }

    $target = Join-Path $frameDirectory ("sec_{0:d3}.jpg" -f ($second + 1))
    & $ffmpeg -hide_banner -loglevel error -y -ss ([string]$second) -i $mediaFullPath `
        -frames:v 1 -q:v 3 $target
}

$frames = @(Get-ChildItem -LiteralPath $frameDirectory -File -Filter "sec_*.jpg")
if ($frames.Count -ne $totalSeconds) {
    throw "Expected $totalSeconds per-second frames but found $($frames.Count)."
}

$secondIndex = @()
for ($second = 0; $second -lt $totalSeconds; $second++) {
    $start = $second
    $end = [Math]::Min([double]$duration, [double]($second + 1))

    if ($end -eq $start + 1) {
        $timecode = "$(Format-SecondCode $start)-$(Format-SecondCode $end)"
    }
    else {
        $timecode = "$(Format-SecondCode $start)-$(Format-FractionalSecondCode $end)"
    }

    $secondIndex += [PSCustomObject]@{
        Second = $second
        Timecode = $timecode
        FrameFile = "sec_{0:d3}.jpg" -f ($second + 1)
    }
}

$secondIndexPath = Join-Path $outputFullPath "per_second_index.csv"
$secondIndex | Export-Csv -LiteralPath $secondIndexPath -NoTypeInformation -Encoding UTF8

$manifest = [PSCustomObject]@{
    MediaPath = $mediaFullPath
    Duration = $duration
    TotalSeconds = $totalSeconds
    FrameCount = $frames.Count
    FrameDirectory = $frameDirectory
    SecondIndex = $secondIndexPath
    ContactSheetDirectory = if ($SkipContactSheets) { $null } else { Join-Path $outputFullPath "contact_10s" }
}

if (-not $SkipContactSheets) {
    $contactDirectory = Join-Path $outputFullPath "contact_10s"
    New-Item -ItemType Directory -Force -Path $contactDirectory | Out-Null
    $inputPattern = Join-Path $frameDirectory "sec_%03d.jpg"
    & $ffmpeg -hide_banner -loglevel error -y -framerate 1 -i $inputPattern `
        -vf "scale=256:-2,tile=5x2:padding=4:margin=8" `
        (Join-Path $contactDirectory "contact_10s_%02d.jpg")
}

$manifest | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $outputFullPath "replication-manifest.json") -Encoding UTF8

Write-Host "Media: $mediaFullPath"
Write-Host "Duration: $duration seconds"
Write-Host "Second buckets: $totalSeconds"
Write-Host "Frames: $($frames.Count)"
Write-Host "Index: $secondIndexPath"

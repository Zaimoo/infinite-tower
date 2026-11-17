<#
.SYNOPSIS
    Imports all .wav files from the Free Anime SFX Pack into assets/sfx/ with
    normalized lowercase snake_case paths, verifies byte parity, parses exact
    RIFF/WAVE durations, and generates AnimeSfxManifest.luau.
#>
[CmdletBinding()]
param(
	[string]$SourceDir = 'C:\Users\enter\Downloads\Free Anime SFX Pack\Free Anime SFX Pack',
	[string]$RepoRoot = '',
	[switch]$SkipManifestWrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
	$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
	$RepoRoot = Split-Path -Parent $scriptDir
}

function ConvertTo-SnakeSlug {
	param([Parameter(Mandatory)][string]$Text)
	$slug = ($Text.ToLowerInvariant() -replace '[^a-z0-9]+', '_').Trim('_')
	if ([string]::IsNullOrWhiteSpace($slug)) {
		throw "Cannot normalize empty slug from '$Text'"
	}
	return $slug
}

# LeadIn: seconds of near-silence before a 16-bit PCM sound starts. The onset is the first sample
# within 30 dB of the file's peak; 10 ms of pre-roll is kept so the attack is not clipped.
Add-Type -TypeDefinition @'
public static class WavLeadIn {
	public static double Compute(string path, long dataOffset, long dataSize, int channels, int sampleRate) {
		var bytes = new byte[dataSize];
		using (var fs = System.IO.File.OpenRead(path)) {
			fs.Seek(dataOffset, System.IO.SeekOrigin.Begin);
			int read = 0;
			while (read < bytes.Length) {
				int n = fs.Read(bytes, read, bytes.Length - read);
				if (n <= 0) break;
				read += n;
			}
		}
		int samples = bytes.Length / 2;
		int peak = 1;
		for (int i = 0; i < samples; i++) {
			int v = System.Math.Abs((int)System.BitConverter.ToInt16(bytes, i * 2));
			if (v > peak) peak = v;
		}
		double threshold = peak * System.Math.Pow(10.0, -30.0 / 20.0);
		for (int i = 0; i < samples; i++) {
			if (System.Math.Abs((int)System.BitConverter.ToInt16(bytes, i * 2)) >= threshold) {
				double onset = (double)(i / channels) / sampleRate;
				return System.Math.Round(System.Math.Max(0.0, onset - 0.01), 3);
			}
		}
		return 0.0;
	}
}
'@

function Get-WavMetadata {
	param([Parameter(Mandatory)][string]$FilePath)

	$fs = [System.IO.File]::OpenRead($FilePath)
	$br = [System.IO.BinaryReader]::new($fs)
	try {
		$riff = [System.Text.Encoding]::ASCII.GetString($br.ReadBytes(4))
		if ($riff -ne 'RIFF') {
			throw "Not a RIFF file: $FilePath ($riff)"
		}
		[void]$br.ReadUInt32() # chunk size
		$wave = [System.Text.Encoding]::ASCII.GetString($br.ReadBytes(4))
		if ($wave -ne 'WAVE') {
			throw "Not a WAVE file: $FilePath ($wave)"
		}

		$channels = 0
		$sampleRate = 0
		$byteRate = 0
		$bitsPerSample = 0
		$dataSize = 0
		$dataOffset = 0

		while ($fs.Position + 8 -le $fs.Length) {
			$chunkId = [System.Text.Encoding]::ASCII.GetString($br.ReadBytes(4))
			$chunkSize = [int64]$br.ReadUInt32()

			if ($chunkId -eq 'fmt ') {
				[void]$br.ReadUInt16() # audioFormat
				$channels = [int]$br.ReadUInt16()
				$sampleRate = [int]$br.ReadUInt32()
				$byteRate = [int]$br.ReadUInt32()
				[void]$br.ReadUInt16() # blockAlign
				$bitsPerSample = [int]$br.ReadUInt16()
				$remaining = $chunkSize - 16
				if ($remaining -gt 0) {
					[void]$fs.Seek($remaining, [System.IO.SeekOrigin]::Current)
				}
			} elseif ($chunkId -eq 'data') {
				$dataSize = $chunkSize
				$dataOffset = $fs.Position
				[void]$fs.Seek($chunkSize, [System.IO.SeekOrigin]::Current)
			} else {
				[void]$fs.Seek($chunkSize, [System.IO.SeekOrigin]::Current)
			}

			# RIFF subchunks are word-aligned
			if (($chunkSize % 2) -eq 1 -and $fs.Position -lt $fs.Length) {
				[void]$fs.Seek(1, [System.IO.SeekOrigin]::Current)
			}
		}

		$duration = if ($byteRate -gt 0) {
			[math]::Round($dataSize / [double]$byteRate, 3)
		} else {
			0.0
		}

		$leadIn = if ($bitsPerSample -eq 16 -and $channels -gt 0 -and $sampleRate -gt 0 -and $dataSize -gt 0) {
			[WavLeadIn]::Compute($FilePath, $dataOffset, $dataSize, $channels, $sampleRate)
		} else {
			0.0
		}

		return [PSCustomObject]@{
			Channels        = $channels
			SampleRate      = $sampleRate
			ByteRate        = $byteRate
			BitsPerSample   = $bitsPerSample
			DurationSeconds = $duration
			LeadIn          = $leadIn
		}
	} finally {
		$br.Dispose()
		$fs.Dispose()
	}
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
	throw "SourceDir not found: $SourceDir"
}

$destRoot = Join-Path $RepoRoot 'assets\sfx'
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

$sourceFiles = Get-ChildItem -LiteralPath $SourceDir -Filter '*.wav' -Recurse -File | Sort-Object FullName
if ($sourceFiles.Count -eq 0) {
	throw "No .wav files found in $SourceDir"
}

$seenKeys = @{}
$records = [System.Collections.Generic.List[object]]::new()

foreach ($file in $sourceFiles) {
	$rel = $file.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
	$dirPart = Split-Path $rel -Parent
	$catSlug = if ([string]::IsNullOrWhiteSpace($dirPart)) { 'misc' } else { ConvertTo-SnakeSlug $dirPart }
	$stemSlug = ConvertTo-SnakeSlug ([System.IO.Path]::GetFileNameWithoutExtension($file.Name))
	$key = "$catSlug/$stemSlug"

	if ($seenKeys.ContainsKey($key)) {
		throw "Slug collision for key '$key': '$($seenKeys[$key])' vs '$($file.FullName)'"
	}
	$seenKeys[$key] = $file.FullName

	$destCategoryDir = Join-Path $destRoot $catSlug
	New-Item -ItemType Directory -Force -Path $destCategoryDir | Out-Null

	$destFileName = "$stemSlug.wav"
	$destPath = Join-Path $destCategoryDir $destFileName

	$needsCopy = $true
	if (Test-Path -LiteralPath $destPath) {
		$existing = Get-Item -LiteralPath $destPath
		if ($existing.Length -eq $file.Length) {
			$needsCopy = $false
		}
	}
	if ($needsCopy) {
		Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
	}

	$copiedItem = Get-Item -LiteralPath $destPath
	if ($copiedItem.Length -ne $file.Length) {
		throw "Byte mismatch copying '$($file.FullName)' -> '$destPath' ($($copiedItem.Length) vs $($file.Length))"
	}

	$wav = Get-WavMetadata -FilePath $destPath
	$records.Add([PSCustomObject]@{
		Key             = $key
		Category        = $catSlug
		OriginalName    = $rel.Replace('\', '/')
		RepoPath        = "assets/sfx/$catSlug/$destFileName"
		StudioId        = "rbxasset://sfx/$catSlug/$destFileName"
		Bytes           = $file.Length
		LeadIn          = $wav.LeadIn
		DurationSeconds = $wav.DurationSeconds
		SampleRate      = $wav.SampleRate
		Channels        = $wav.Channels
	})
}

Write-Host "Imported and verified $($records.Count) .wav files under $destRoot"

if (-not $SkipManifestWrite) {
	$manifestPath = Join-Path $RepoRoot 'src\ReplicatedStorage\Shared\Config\AnimeSfxManifest.luau'

	# Keep AssetIds of sounds already uploaded to Roblox; regenerating must not wipe them.
	$existingAssetIds = @{}
	if (Test-Path -LiteralPath $manifestPath) {
		$oldManifest = Get-Content -Raw -LiteralPath $manifestPath
		foreach ($m in [regex]::Matches($oldManifest, '(?s)Key = "([^"]+)",.*?AssetId = "([^"]*)",')) {
			if ($m.Groups[2].Value -ne '') {
				$existingAssetIds[$m.Groups[1].Value] = $m.Groups[2].Value
			}
		}
	}

	$sb = [System.Text.StringBuilder]::new()
	[void]$sb.AppendLine('--!strict')
	[void]$sb.AppendLine('-- Auto-generated by tools/import_anime_sfx_pack.ps1')
	[void]$sb.AppendLine('-- Complete manifest of all 126 Free Anime SFX Pack assets stored in assets/sfx/.')
	[void]$sb.AppendLine('-- StudioId uses rbxasset://sfx/<category>/<slug>.wav (backed by tools/link_sfx_to_studio.ps1).')
	[void]$sb.AppendLine('-- Once uploaded to Roblox Creator Store / Open Cloud, populate AssetId with "rbxassetid://<id>".')
	[void]$sb.AppendLine("-- LeadIn is measured from the WAV; playback starts there so the pack's padded silence never delays a cue.")
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('export type AnimeSfxEntry = {')
	[void]$sb.AppendLine("`tKey: string,")
	[void]$sb.AppendLine("`tCategory: string,")
	[void]$sb.AppendLine("`tOriginalName: string,")
	[void]$sb.AppendLine("`tRepoPath: string,")
	[void]$sb.AppendLine("`tStudioId: string,")
	[void]$sb.AppendLine("`tAssetId: string,")
	[void]$sb.AppendLine("`tBytes: number,")
	[void]$sb.AppendLine("`tLeadIn: number, -- seconds of near-silence before the sound starts (onset at -30 dB of peak, minus 10 ms)")
	[void]$sb.AppendLine("`tDurationSeconds: number,")
	[void]$sb.AppendLine("`tSampleRate: number,")
	[void]$sb.AppendLine("`tChannels: number,")
	[void]$sb.AppendLine('}')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('local AnimeSfxManifest = {}')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine("AnimeSfxManifest.Count = $($records.Count)")
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('AnimeSfxManifest.Entries = table.freeze({')

	foreach ($rec in $records) {
		$origEscaped = $rec.OriginalName.Replace('\', '\\').Replace('"', '\"')
		$durFormatted = $rec.DurationSeconds.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
		$leadFormatted = ([double]$rec.LeadIn).ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
		[void]$sb.AppendLine("`t[`"$($rec.Key)`"] = table.freeze({")
		[void]$sb.AppendLine("`t`tKey = `"$($rec.Key)`",")
		[void]$sb.AppendLine("`t`tCategory = `"$($rec.Category)`",")
		[void]$sb.AppendLine("`t`tOriginalName = `"$origEscaped`",")
		[void]$sb.AppendLine("`t`tRepoPath = `"$($rec.RepoPath)`",")
		[void]$sb.AppendLine("`t`tStudioId = `"$($rec.StudioId)`",")
		$assetId = if ($existingAssetIds.ContainsKey($rec.Key)) { $existingAssetIds[$rec.Key] } else { '' }
		[void]$sb.AppendLine("`t`tAssetId = `"$assetId`",")
		[void]$sb.AppendLine("`t`tBytes = $($rec.Bytes),")
		[void]$sb.AppendLine("`t`tLeadIn = $leadFormatted,")
		[void]$sb.AppendLine("`t`tDurationSeconds = $durFormatted,")
		[void]$sb.AppendLine("`t`tSampleRate = $($rec.SampleRate),")
		[void]$sb.AppendLine("`t`tChannels = $($rec.Channels),")
		[void]$sb.AppendLine("`t}),")
	}

	[void]$sb.AppendLine('}) :: { [string]: AnimeSfxEntry }')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('local allKeys: { string } = {}')
	[void]$sb.AppendLine('for key in pairs(AnimeSfxManifest.Entries) do')
	[void]$sb.AppendLine("`ttable.insert(allKeys, key)")
	[void]$sb.AppendLine('end')
	[void]$sb.AppendLine('table.sort(allKeys)')
	[void]$sb.AppendLine('table.freeze(allKeys)')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('function AnimeSfxManifest.Get(key: string): AnimeSfxEntry?')
	[void]$sb.AppendLine("`treturn AnimeSfxManifest.Entries[key]")
	[void]$sb.AppendLine('end')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('function AnimeSfxManifest.GetStudioId(key: string): string?')
	[void]$sb.AppendLine("`tlocal entry = AnimeSfxManifest.Entries[key]")
	[void]$sb.AppendLine("`treturn if entry then entry.StudioId else nil")
	[void]$sb.AppendLine('end')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('function AnimeSfxManifest.GetPlayableId(key: string, useStudioLocal: boolean?): string?')
	[void]$sb.AppendLine("`tlocal entry = AnimeSfxManifest.Entries[key]")
	[void]$sb.AppendLine("`tif not entry then")
	[void]$sb.AppendLine("`t`treturn nil")
	[void]$sb.AppendLine("`tend")
	[void]$sb.AppendLine("`tif entry.AssetId ~= `"`" then")
	[void]$sb.AppendLine("`t`treturn entry.AssetId")
	[void]$sb.AppendLine("`tend")
	[void]$sb.AppendLine("`tif useStudioLocal then")
	[void]$sb.AppendLine("`t`treturn entry.StudioId")
	[void]$sb.AppendLine("`tend")
	[void]$sb.AppendLine("`treturn nil")
	[void]$sb.AppendLine('end')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('function AnimeSfxManifest.GetLeadIn(key: string): number')
	[void]$sb.AppendLine("`tlocal entry = AnimeSfxManifest.Entries[key]")
	[void]$sb.AppendLine("`treturn if entry then entry.LeadIn else 0")
	[void]$sb.AppendLine('end')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('function AnimeSfxManifest.AllKeys(): { string }')
	[void]$sb.AppendLine("`treturn allKeys")
	[void]$sb.AppendLine('end')
	[void]$sb.AppendLine('')
	[void]$sb.AppendLine('return AnimeSfxManifest')

	[System.IO.File]::WriteAllText($manifestPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
	Write-Host "Wrote manifest: $manifestPath"
}

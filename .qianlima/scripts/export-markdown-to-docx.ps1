param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [string]$Title = ''
)

$ErrorActionPreference = 'Stop'

function Escape-XmlText {
  param([AllowNull()][string]$Text)
  if ($null -eq $Text) { return '' }
  return [System.Security.SecurityElement]::Escape($Text)
}

function New-RunXml {
  param(
    [string]$Text,
    [switch]$Bold,
    [switch]$Italic,
    [switch]$Code
  )

  $props = ''
  if ($Bold -or $Italic -or $Code) {
    $items = @()
    if ($Bold) { $items += '<w:b/>' }
    if ($Italic) { $items += '<w:i/>' }
    if ($Code) { $items += '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:eastAsia="Microsoft YaHei"/><w:sz w:val="20"/>' }
    $props = '<w:rPr>' + ($items -join '') + '</w:rPr>'
  }

  return '<w:r>' + $props + '<w:t xml:space="preserve">' + (Escape-XmlText $Text) + '</w:t></w:r>'
}

function New-ParagraphXml {
  param(
    [string]$Text,
    [string]$Style = '',
    [switch]$Bullet,
    [switch]$Code
  )

  $pPr = ''
  $styleXml = ''
  if (-not [string]::IsNullOrWhiteSpace($Style)) {
    $styleXml = '<w:pStyle w:val="' + $Style + '"/>'
  }
  if ($Bullet) {
    $styleXml += '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>'
  }
  if (-not [string]::IsNullOrWhiteSpace($styleXml)) {
    $pPr = '<w:pPr>' + $styleXml + '</w:pPr>'
  }

  return '<w:p>' + $pPr + (New-RunXml -Text $Text -Code:$Code) + '</w:p>'
}

function New-TableXml {
  param([string[]]$Rows)

  $xml = '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders></w:tblPr>'
  foreach ($row in $Rows) {
    $trimmed = $row.Trim().Trim('|')
    if ($trimmed -match '^\s*-+\s*(\|\s*-+\s*)+$') { continue }
    $cells = $trimmed -split '\|'
    $xml += '<w:tr>'
    foreach ($cell in $cells) {
      $xml += '<w:tc><w:tcPr><w:tcW w:w="2400" w:type="dxa"/></w:tcPr>' + (New-ParagraphXml -Text $cell.Trim()) + '</w:tc>'
    }
    $xml += '</w:tr>'
  }
  $xml += '</w:tbl>'
  return $xml
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$outputFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$lines = [System.IO.File]::ReadAllLines($resolvedInput, [System.Text.Encoding]::UTF8)
$bodyParts = New-Object System.Collections.Generic.List[string]

if (-not [string]::IsNullOrWhiteSpace($Title)) {
  $bodyParts.Add((New-ParagraphXml -Text $Title -Style 'Title'))
}

$inCode = $false
$tableRows = New-Object System.Collections.Generic.List[string]

function Flush-Table {
  if ($tableRows.Count -gt 0) {
    $bodyParts.Add((New-TableXml -Rows $tableRows.ToArray()))
    $tableRows.Clear()
  }
}

foreach ($line in $lines) {
  if ($line.Trim().StartsWith('```')) {
    Flush-Table
    $inCode = -not $inCode
    continue
  }

  if ($inCode) {
    $bodyParts.Add((New-ParagraphXml -Text $line -Code))
    continue
  }

  if ($line -match '^\s*\|.*\|\s*$') {
    $tableRows.Add($line)
    continue
  } else {
    Flush-Table
  }

  $trimmedLine = $line.TrimEnd()
  if ([string]::IsNullOrWhiteSpace($trimmedLine)) {
    $bodyParts.Add('<w:p/>')
    continue
  }

  if ($trimmedLine -match '^#\s+(.+)$') {
    $bodyParts.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading1'))
  } elseif ($trimmedLine -match '^##\s+(.+)$') {
    $bodyParts.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading2'))
  } elseif ($trimmedLine -match '^###\s+(.+)$') {
    $bodyParts.Add((New-ParagraphXml -Text $Matches[1] -Style 'Heading3'))
  } elseif ($trimmedLine -match '^\s*[-*]\s+(.+)$') {
    $bodyParts.Add((New-ParagraphXml -Text $Matches[1] -Bullet))
  } elseif ($trimmedLine -match '^\s*\d+\.\s+(.+)$') {
    $bodyParts.Add((New-ParagraphXml -Text $trimmedLine))
  } else {
    $clean = $trimmedLine -replace '\*\*', '' -replace '`', ''
    $bodyParts.Add((New-ParagraphXml -Text $clean))
  }
}
Flush-Table

$documentXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:w10="urn:schemas-microsoft-com:office:word" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk" xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" mc:Ignorable="w14 wp14">
<w:body>
'@ + ($bodyParts -join [Environment]::NewLine) + @'
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>
</w:body>
</w:document>
'@

$stylesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Microsoft YaHei"/><w:sz w:val="22"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:pPr><w:jc w:val="center"/></w:pPr><w:rPr><w:b/><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:eastAsia="Microsoft YaHei"/><w:sz w:val="36"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:rPr><w:b/><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:eastAsia="Microsoft YaHei"/><w:sz w:val="32"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:rPr><w:b/><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:eastAsia="Microsoft YaHei"/><w:sz w:val="28"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:rPr><w:b/><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:eastAsia="Microsoft YaHei"/><w:sz w:val="24"/></w:rPr></w:style>
</w:styles>
'@

$numberingXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>
<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>
'@

$contentTypesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
</Types>
'@

$relsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@

$documentRelsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
</Relationships>
'@

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("docx-export-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot '_rels') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'word') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'word\_rels') | Out-Null

[System.IO.File]::WriteAllText((Join-Path $tempRoot '[Content_Types].xml'), $contentTypesXml, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $tempRoot '_rels\.rels'), $relsXml, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'word\document.xml'), $documentXml, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'word\styles.xml'), $stylesXml, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'word\numbering.xml'), $numberingXml, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $tempRoot 'word\_rels\document.xml.rels'), $documentRelsXml, [System.Text.UTF8Encoding]::new($false))

if (Test-Path -LiteralPath $outputFullPath) {
  Remove-Item -LiteralPath $outputFullPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempRoot, $outputFullPath)
Remove-Item -LiteralPath $tempRoot -Recurse -Force

Get-Item -LiteralPath $outputFullPath | Select-Object FullName, Length, LastWriteTime

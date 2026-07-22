<##
.SYNOPSIS
  Generates a governed Enterprise artifact location without creating files.
##>
param(
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9][a-z0-9_-]{1,63}$')][string]$Business,
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9][a-z0-9_-]{1,63}$')][string]$Department,
  [ValidateSet('L0','L1','L2','L3','L4')][string]$RiskLevel,
  [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9._-]{3,100}$')][string]$TaskId,
  [ValidateSet('input_reference','working','outcome','evidence','verification','failure','core_issue','handling','review','lesson_candidate','audit_receipt')][string]$ArtifactType,
  [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$')][string]$FileName,
  [string]$YearMonth='',[switch]$PassThru
)
$ErrorActionPreference='Stop';if([string]::IsNullOrWhiteSpace($YearMonth)){$YearMonth=(Get-Date).ToString('yyyy-MM')};if($YearMonth-notmatch'^20[0-9]{2}-(0[1-9]|1[0-2])$'){throw 'YearMonth must use YYYY-MM.'}
$relative=('.qianlima/local-data/enterprise/artifacts/{0}/{1}/{2}/{3}/{4}/{5}/{6}'-f$Business,$Department,$RiskLevel,$YearMonth,$TaskId,$ArtifactType,$FileName);$result=[PSCustomObject]@{relative_path=$relative;business=$Business;department=$Department;risk_level=$RiskLevel;task_id=$TaskId;artifact_type=$ArtifactType;path_created=$false};if($PassThru){$result|ConvertTo-Json -Depth 5}else{$result|Format-List}

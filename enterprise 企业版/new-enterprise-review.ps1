<##
.SYNOPSIS
  Creates a review and lesson candidate without changing production policy.
##>
param(
  [Parameter(Mandatory=$true)][string]$TaskId,[Parameter(Mandatory=$true)][string]$TraceId,
  [Parameter(Mandatory=$true)][string]$Business,[Parameter(Mandatory=$true)][string]$Department,
  [ValidateSet('L0','L1','L2','L3','L4')][string]$RiskLevel,
  [Parameter(Mandatory=$true)][string]$BusinessExpectation,[Parameter(Mandatory=$true)][string]$ActualOutcome,
  [Parameter(Mandatory=$true)][string]$Symptom,[Parameter(Mandatory=$true)][string]$RootCause,
  [Parameter(Mandatory=$true)][string]$Impact,[Parameter(Mandatory=$true)][string]$Fix,
  [Parameter(Mandatory=$true)][string]$Prevention,[Parameter(Mandatory=$true)][string]$OwnerId,
  [Parameter(Mandatory=$true)][string]$DueAt,[string]$EvidenceRefs='',[string]$TestedWith='unverified',[switch]$PassThru
)
$ErrorActionPreference='Stop';$recurrencePayload=('{0}|{1}|{2}'-f$Business,$Department,$RootCause).ToLowerInvariant();$sha=[Security.Cryptography.SHA256]::Create();try{$recurrenceKey='sha256:'+(($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($recurrencePayload))|ForEach-Object{$_.ToString('x2')})-join'')}finally{$sha.Dispose()}
$review=[ordered]@{schema_version=1;review_id='review-'+[Guid]::NewGuid().ToString('n');task_id=$TaskId;trace_id=$TraceId;business=$Business;department=$Department;risk_level=$RiskLevel;business_expectation=$BusinessExpectation;actual_outcome=$ActualOutcome;failure=[ordered]@{symptom=$Symptom;impact=$Impact};core_issue=[ordered]@{root_cause=$RootCause;recurrence_key=$recurrenceKey};handling=[ordered]@{fix=$Fix;prevention=$Prevention;owner_id=$OwnerId;due_at=$DueAt};evidence_refs=@(($EvidenceRefs-split',')|ForEach-Object{$_.Trim()}|Where-Object{$_});lesson_candidate=[ordered]@{lesson_id='lesson-'+[Guid]::NewGuid().ToString('n');recurrence_key=$recurrenceKey;symptom=$Symptom;root_cause=$RootCause;impact=$Impact;fix=$Fix;prevention=$Prevention;tested_with=$TestedWith;status='candidate';production_authority='none'};created_at=(Get-Date).ToUniversalTime().ToString('o')}
if($PassThru){$review|ConvertTo-Json -Depth 10}else{$review|Format-List}

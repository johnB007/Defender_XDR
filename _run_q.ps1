$ws = "2dde2f51-1428-4f3f-afcb-9aa3e150796e"
$obj = Get-Content "C:\Users\jobarbar\github\Defender_XDR\Dashboards\Network-Security-Operations-Center\Network-Security-Operations-Center.workbook" -Raw | ConvertFrom-Json -Depth 100
function FindByName($n, $name) {
  if ($null -eq $n) { return $null }
  if ($n -is [System.Collections.IEnumerable] -and $n -isnot [string]) { foreach ($c in $n) { $r = FindByName $c $name; if ($r) { return $r } }; return $null }
  if ($n -is [psobject]) {
    if ($n.PSObject.Properties.Name -contains 'name' -and $n.name -eq $name) { return $n }
    foreach ($p in $n.PSObject.Properties) { $r = FindByName $p.Value $name; if ($r) { return $r } }
  }
  return $null
}
$names = @('correlation-kpi-tiles','correlation-ti-ip-matches','correlation-top-clients')
foreach ($nm in $names) {
  Write-Host "=== $nm ==="
  $node = FindByName $obj $nm
  if (-not $node) { Write-Host "  NOT FOUND"; continue }
  $q = $node.content.query
  Write-Host "  query length: $($q.Length)"
  $tmp = "_q_$nm.kql"
  Set-Content -Path $tmp -Value $q -Encoding utf8NoBOM
  $out = az monitor log-analytics query -w $ws --analytics-query "@$tmp" -o json 2>&1
  $exit = $LASTEXITCODE
  if ($exit -eq 0) {
    $j = $out | ConvertFrom-Json
    Write-Host "  OK rows=$($j.Count)"
    if ($j.Count -gt 0) { Write-Host "  sample row:"; $j[0] | Format-List | Out-String | Write-Host }
  } else {
    Write-Host "  FAIL exit=$exit"
    $s = ($out | Out-String)
    Write-Host $s.Substring(0,[Math]::Min(2000,$s.Length))
  }
}

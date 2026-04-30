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
$q = (FindByName $obj 'correlation-kpi-tiles').content.query
Write-Host "LEN=$($q.Length)"
Set-Content -Path .\_kpi.kql -Value $q -Encoding utf8NoBOM
Write-Host "--- FILE ---"
Get-Content .\_kpi.kql -Raw

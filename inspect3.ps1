$f = "Dashboards/Network-Security-Operations-Center/Network-Security-Operations-Center.workbook"
$obj = Get-Content $f -Raw | ConvertFrom-Json -Depth 100
function Walk($n, [scriptblock]$visit) {
  if ($null -eq $n) { return }
  & $visit $n
  if ($n -is [System.Collections.IEnumerable] -and $n -isnot [string]) { foreach ($c in $n) { Walk $c $visit }; return }
  foreach ($p in $n.PSObject.Properties) { if ($p.Value -is [object]) { Walk $p.Value $visit } }
}
Walk $obj { param($n)
  if ($n -is [psobject] -and $n.PSObject.Properties.Name -contains 'conditionalVisibility') {
    $cv = $n.conditionalVisibility
    if ($cv -ne $null -and $cv.PSObject.Properties.Name -contains 'value' -and $cv.value -eq 'Correlation') {
      $title = $null
      if ($n.PSObject.Properties.Name -contains 'content' -and $n.content -ne $null -and $n.content.PSObject.Properties.Name -contains 'title') { $title = $n.content.title }
      $first = $null
      if ($n.PSObject.Properties.Name -contains 'content' -and $n.content -ne $null -and $n.content.PSObject.Properties.Name -contains 'query') { $first = ($n.content.query -split "`n")[0] }
      Write-Host ("type={0} name='{1}' title='{2}' firstKQL='{3}'" -f $n.type,$n.name,$title,$first)
    }
  }
}

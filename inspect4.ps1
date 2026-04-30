$f = "Dashboards/Network-Security-Operations-Center/Network-Security-Operations-Center.workbook"
$obj = Get-Content $f -Raw | ConvertFrom-Json -Depth 100
function Walk($n, [scriptblock]$visit) {
  if ($null -eq $n) { return }
  & $visit $n
  if ($n -is [System.Collections.IEnumerable] -and $n -isnot [string]) { foreach ($c in $n) { Walk $c $visit }; return }
  foreach ($p in $n.PSObject.Properties) { if ($p.Value -is [object]) { Walk $p.Value $visit } }
}
Walk $obj { param($n)
  if ($n -is [psobject] -and $n.PSObject.Properties.Name -contains 'name' -and $n.name -eq 'group-correlation') {
    $items = $n.content.items
    Write-Host ("group-correlation has {0} items" -f $items.Count)
    $idx = 0
    foreach ($it in $items) {
      $title = $null; $first=$null
      if ($it.PSObject.Properties.Name -contains 'content' -and $it.content -ne $null) {
        if ($it.content.PSObject.Properties.Name -contains 'title') { $title = $it.content.title }
        if ($it.content.PSObject.Properties.Name -contains 'query') { $first = ($it.content.query -split "`n")[0] }
        if ($it.content.PSObject.Properties.Name -contains 'json') { $title = '[TEXT] ' + ($it.content.json -split "`n")[0] }
      }
      Write-Host ("  [{0}] type={1} name='{2}' title='{3}'" -f $idx,$it.type,$it.name,$title)
      if ($first) { Write-Host ("       firstKQL: {0}" -f $first) }
      $idx++
    }
  }
}

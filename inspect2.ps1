$f = "Dashboards/Network-Security-Operations-Center/Network-Security-Operations-Center.workbook"
$obj = Get-Content $f -Raw | ConvertFrom-Json -Depth 100
function Walk($n, [scriptblock]$visit) {
  if ($null -eq $n) { return }
  & $visit $n
  if ($n -is [System.Collections.IEnumerable] -and $n -isnot [string]) { foreach ($c in $n) { Walk $c $visit }; return }
  foreach ($p in $n.PSObject.Properties) { if ($p.Value -is [object]) { Walk $p.Value $visit } }
}
$subTarget = $null
Walk $obj { param($n)
  if ($n -is [psobject] -and $n.PSObject.Properties.Name -contains 'linkLabel' -and $n.linkLabel -eq 'Threat Correlation') {
    Write-Host ("Link: subTarget='{0}' linkTarget='{1}'" -f $n.subTarget, $n.linkTarget)
    $script:subTarget = $n.subTarget
  }
}
Write-Host "`nLooking for group with name=$subTarget"
Walk $obj { param($n)
  if ($n -is [psobject] -and $n.PSObject.Properties.Name -contains 'name' -and $n.name -eq $subTarget) {
    Write-Host ("FOUND group name='{0}' type={1}" -f $n.name, $n.type)
    if ($n.PSObject.Properties.Name -contains 'content' -and $n.content.PSObject.Properties.Name -contains 'items') {
      $idx = 0
      foreach ($it in $n.content.items) {
        $title = $null
        if ($it.PSObject.Properties.Name -contains 'content' -and $it.content -ne $null -and $it.content.PSObject.Properties.Name -contains 'title') { $title = $it.content.title }
        Write-Host ("  [{0}] type={1} name='{2}' title='{3}'" -f $idx,$it.type,$it.name,$title)
        $idx++
      }
    }
  }
}

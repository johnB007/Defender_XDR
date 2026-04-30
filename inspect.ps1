$f = "Dashboards/Network-Security-Operations-Center/Network-Security-Operations-Center.workbook"
$obj = Get-Content $f -Raw | ConvertFrom-Json -Depth 100

function Walk($n, [scriptblock]$visit) {
  if ($null -eq $n) { return }
  & $visit $n
  if ($n -is [System.Collections.IEnumerable] -and $n -isnot [string]) { foreach ($c in $n) { Walk $c $visit }; return }
  foreach ($p in $n.PSObject.Properties) { if ($p.Value -is [object]) { Walk $p.Value $visit } }
}

Walk $obj { param($n)
  if ($n -is [psobject] -and $n.PSObject.Properties.Name -contains 'content') {
    $c = $n.content
    if ($c.PSObject.Properties.Name -contains 'query' -and $c.PSObject.Properties.Name -contains 'title' -and $c.title -like 'TI IP Matches*') {
      Write-Host "=== TI IP Matches decoded query ==="
      $i = 1; foreach ($line in ($c.query -split "`n")) { '{0,3}: {1}' -f $i,$line; $i++ }
    }
  }
}

Write-Host "`n=== All TI items (title + first KQL line) ==="
Walk $obj { param($n)
  if ($n -is [psobject] -and $n.PSObject.Properties.Name -contains 'content') {
    $c = $n.content
    if ($c.PSObject.Properties.Name -contains 'title' -and $c.title -like 'TI *' -and $c.PSObject.Properties.Name -contains 'query') {
      $first = ($c.query -split "`n")[0]
      Write-Host ("ITEM: title='{0}'  first KQL line: {1}" -f $c.title, $first)
    }
  }
}

Write-Host "`n=== Threat Correlation group items ==="
Walk $obj { param($n)
  if ($n -is [psobject] -and $n.PSObject.Properties.Name -contains 'content') {
    $c = $n.content
    if ($c.PSObject.Properties.Name -contains 'items' -and $c.PSObject.Properties.Name -contains 'title' -and $c.title -like '*Threat Correlation*') {
      Write-Host ("GROUP title='{0}' name='{1}' items={2}" -f $c.title, $n.name, $c.items.Count)
      $idx = 0
      foreach ($it in $c.items) {
        $t = $it.type
        $title = $null; $nm = $it.name
        if ($it.PSObject.Properties.Name -contains 'content' -and $it.content.PSObject.Properties.Name -contains 'title') { $title = $it.content.title }
        Write-Host ("  [{0}] type={1} name='{2}' title='{3}'" -f $idx,$t,$nm,$title)
        $idx++
      }
    }
  }
}

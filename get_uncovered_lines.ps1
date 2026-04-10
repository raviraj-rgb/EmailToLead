$json = Get-Content "coverage_kun_utf8.json" | Out-String | ConvertFrom-Json

function Find-Refs($o) {
    if ($o -eq $null) { return }
    if ($o.ApexClassOrTrigger) {
        $o
    } else {
        if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) {
            foreach ($i in $o) { Find-Refs $i }
        } elseif ($o.PSObject) {
            foreach ($p in $o.PSObject.Properties) { Find-Refs $p.Value }
        }
    }
}

$res = Find-Refs $json
$target = $res | Where-Object { $_.ApexClassOrTrigger.Name -eq 'EmailToLeadService' }
$target.Coverage.uncoveredLines -join ','

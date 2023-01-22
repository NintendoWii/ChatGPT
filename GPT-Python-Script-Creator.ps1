#input API Key
$api_key= "<Paste API-Key here>"

#define CSV Headers
$csv_header= "Source_IP, Source_Port, Dest_IP, Dest_Port"

#replace headers Just in case Chat GPT keeps track of what exactly you're trying to do
function mangle-headers($csv_header){
    $mangled_headers= @()
    $mangled_headers+= "OriginalHeader,MangledHeader"
    $csv_header= $csv_header.split(',').trimstart().trimend()
    
    foreach ($c in $csv_header){
        $original= $c
        $mangled= $($c.tochararray() | % {$_-replace("$_","$([char]$(65..90 | get-random))")})-join('')
        $mangled_headers+= "$original,$mangled"
    }    
    return $mangled_headers
}

function Question-prompt($mangled_headers){
    clear-host
    Remove-Variable -name actual_question -Scope global -Force -ErrorAction SilentlyContinue
    $q= Read-Host -Prompt "Write me a python script that reads from a .csv with the following headers: $($($($mangled_headers | convertfrom-csv).OriginalHeader)-join(',')) and "
    $q= "Write me a python script that reads from a .csv with the following headers: $($($($mangled_headers | convertfrom-csv).OriginalHeader)-join(',')) and " + $q    
    New-Variable -name actual_question -Value $q -Scope global -Force -ErrorAction SilentlyContinue

    foreach ($m in $($mangled_headers | convertfrom-csv)){
        $q= $q-replace($m.OriginalHeader,$($m.mangledheader))
    }
    return $q
}

function chatGPT($q,$api_key){
    $header= @{"Authorization" = "Bearer $api_key"}
  
$data= @"
{"model": "text-davinci-003",
"prompt": "$q",
"max_tokens": 4000,
"temperature": 1.0
}
"@
    #$header= $header | convertfrom-json | ConvertTo-Json
    $data= $data | convertfrom-json | convertto-json
    $response = Invoke-WebRequest -Method POST -uri "https://api.openai.com/v1/completions" -Headers $header -ContentType "application/json" -Body $data  
    $answer= $($response.content | convertfrom-json).choices.text
    
    return $answer
}

function replace-headers($mangled_headers,$result){
    $mangled_headers= $mangled_headers | convertfrom-csv
    foreach ($m in $mangled_headers){
        $result= $result-replace($m.MangledHeader,$($m.OriginalHeader))
    }
    return $result
}

$mangled_headers= mangle-headers $csv_header
$q= Question-prompt $mangled_headers
$result= chatGPT $q $api_key
$final_result= replace-headers $mangled_headers $result

Write-Output "Actual Question: $actual_question" -
Write-Output "***"
Write-Output "Question passed to GPT: $q"
Write-Output "***"
Write-Output "Results:"
$final_result
pause

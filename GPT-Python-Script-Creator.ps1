<#
Allows for natural langauge creation of python scripts that are needed to analyze .csv data
After defining the headers and specifying the question, the GPT3 will create the script for you.

Example CSV Headers: name, Salary,Position,Tenure
Example question: Write me a python script that reads from a .csv with the following headers: name, Salary,Position,Tenure and...
sorts the data decending by salary and removes all results with a tenure less than 10.

The script will obfuscate the question prior to sending it to GPT
Example question as sent to GPT: Write me a python script that reads from a .csv with the following headers: ZFHDGERLY,XZHUKWUEEUY,OVQLFJT,DFLKZTIYO and...
sorts the data decending by ZFHDGERLY and removes all results with a DFLKZTIYO less than 10.

Once the results are recieved from GPT, the script will de-obfuscate the results by replaceing the random jargon with the original data.

Take-away- You might not want GPT to know that you're asking it to create a solution for business data or PII, so you don't reveal that in your question.
#>

#input API Key
$api_key= "<Paste API-Key here>"

#define CSV Headers
#Ex: $csv_header= "Name,Salary,Position,Tenure"
$csv_header= "<Paste Header Here"
##################################################

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

<#
Disclaimer
The sample scripts are not supported under any Microsoft standard support program or service. The sample scripts
are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, 
without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire
risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event
shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be
liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business
interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use
the sample scripts or documentation, even if Microsoft has been advised of the  possibility of such damages.
#>


$Resources = import-csv -Path '.\resources.csv'
$abbrevFile = '.\resource-abbreviations.md'

$HeaderLineNum = Get-ChildItem $abbrevFile | Select-String -Pattern '## Resource List in Alphabetical Order' | Select-Object -ExpandProperty linenumber
$Header = Get-Content -Path $abbrevFile -TotalCount $HeaderLineNum

$FooterLineNum = Get-ChildItem $abbrevFile | Select-String -Pattern '## Next steps' | Select-Object -ExpandProperty linenumber
$Footer = Get-Content -Path $abbrevFile | Select-Object -Skip ($FooterLineNum-2)


$arrList = @()

Foreach($resource in $Resources){
    #Accomodate for shortnames that are blank or duplicate from previous in spreadsheet
    If(($resource.shortName -ne "") -and ($resource.shortName -ne $prevShortname)){
   
    
        #Write Header on first run
        If($Resources.IndexOf($resource) -eq 0){
            $arrList += "`n| Asset Type | Resource provider namespace/Entity | Abbreviation |  `n|--|--|--|  "}
           
        $strCurrResource = $resource.resource
        #Resource provider asset type | namespace/Entity |  Abbreviation
       If($resource.staticValues -eq ""){
            $arrList += '|' + $resource.assetType + '| ' + $strCurrResource + ' | `' + $resource.shortname + '` |  '
            }
        } #end if
    $prevShortName = $Resource.shortName
    } # End Foreach

$Header + $arrList + $Footer | Out-File -FilePath ".\resource-abbreviations_updatedv6.md"
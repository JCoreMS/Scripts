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

$arrList = @()

$Header = @"
---
title: Recommended abbreviations for Azure resource types
description: Review recommended abbreviations to use for various Azure resource types when naming your resources and assets.
author: BrianBlanchard
ms.author: brblanch
ms.date: 4/14/2021
ms.topic: conceptual
ms.service: cloud-adoption-framework
ms.subservice: ready
ms.custom: internal, readiness, fasttrack-edit
---

# Recommended abbreviations for Azure resource types

Azure workloads are typically composed of multiple resources and services. Including a naming component in your resource names that represents the type of the Azure resource makes it easier to visually recognize application or service components.

This list provides recommended abbreviations for various Azure resource types to include in your naming conventions. These abbreviations are often used as prefixes in resource names, so each abbreviation is shown below followed by a hyphen (`-`), except for resource types that disallow hyphens in the resource name. Your naming convention might place the resource type abbreviation in a different location of the name if it's more suitable for your organization's needs.

<!-- cSpell:ignoreRegExp `[a-z]+-?` -->

## Resource List in Alphabetical Order

"@

Foreach($resource in $Resources){
    #Accomodate for shortnames that are blank or duplicate from previous in spreadsheet
    If(($resource.shortName -ne "") -and ($resource.shortName -ne $prevShortname)){
        #Trim off leading namespace
        $strResource = $resource.resource -split '/'
        $strCurrProvider = $strResource[0]
        $strNextProvider = ($Resources[($Resources.IndexOf($resource)+1)].resource -split '/')[0]
    
        #Write Header on first run
        If($Resources.IndexOf($resource) -eq 0){
            $arrList += "`r`n### $strCurrProvider`r`n`r`n"
            $arrList += "| Resource provider namespace/Entity | Abbreviation |  `r`n|--|--|`r`n"}
    
        $intStart = (($resource.resource).indexof('/')+1)
        $strCurrResource = $resource.resource.Substring($intStart)
    
        #Resource provider namespace/Entity   |     Abbreviation
        $arrList += '| `' + $strCurrResource + '` | `' + $resource.shortname + '` |' + "`r`n"
    
        If(($strCurrProvider -ne $strNextProvider) -and ($strNextProvider -ne "")){
            $arrList += "`r`n### $strNextProvider`r`n"
            $arrList += "`r`n| Resource provider namespace/Entity | Abbreviation |  `r`n|--|--|`r`n"
            } # End if
        } #end if
    $prevShortName = $Resource.shortName
    } # End Foreach

$Footer = @"

## Next steps

Review recommendations for tagging your Azure resources and assets.

> [!div class="nextstepaction"]
> [Define your tagging strategy](./resource-tagging.md)

"@

$Header + $arrList + $Footer | Out-File -FilePath ".\resource-abbreviations_updated.md"
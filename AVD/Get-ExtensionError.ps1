
Function Get-ExtensionError ($logfile) {
    
    $Netsetup = @()
    $Netsetup = Get-Content -Path $logfile

    $length = $Netsetup.Count
    $i = 1
    $LogReverse = 1..$length | ForEach-Object {$Netsetup[-$i]; $i++}

    Foreach($line in $LogReverse){if($line -match "failed"){$DomJoinError = $line}}
    Return $DomJoinError
}

$DomJoinLog = "C:\windows\debug\NetSetup.LOG"
#$DomJoinLog = "C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.JsonADDomainExtension\1.3.6\ADDomainExtension.log"
Get-ExtensionError $DomJoinLog
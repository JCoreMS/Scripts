################################################################################################################
# SCRIPT:  DCPromo_PostTests.ps1
#          After a Domain Controller Promotion Checks
# 
# PURPOSE: This script is meant to be executed on a newly promoted Domain
#          Controller and will do some basic checks to verify it is healthy.
#          Additional monitoring and checks may be necesary depending on the
#          environment.
#          - DCPromo Log contains no errors
#          - Global Catalog checks
#          - Verify SYSVOL/ Netlogon Shared
#          - Verify DFS targets set to use FQDN
#          - DNS Service Running, Forwarders, Root Hints disabled
#          - DNS SRV Records registered
#          - Initial AD replication
#          - DCDIAG
#          - Windows Time
#          - Network Adapter's DNS Suffixes listed
#
#
#   DATE: 1/8/2020
# AUTHOR: Jonathan Core (jcore@microsoft.com)
#  USAGE: DCPromo_PostTests.ps1 (No parameters) 
#           $LogFile - should reflect desired logfile path
#         
# REVISON: 1.1
#          1/8/2020 JCore
#          Added Logging, Timer and header info
#
#  This script is meant to be executed on a newly promoted Domain
#  Controller and will do some basic checks to verify it is healthy.
#  Additional monitoring and checks may be necesary depending on the
#  environment.  
################################################################################################################



Write-Host -ForegroundColor Yellow "This script MUST run ON the DC!"
Pause

$filedate = Get-Date -Format "MM.dd.yyyy_HH.mm"
$LogFile = "C:\temp\DCPromo-PostChecks_$filedate.txt"
$Timer = New-Object -TypeName System.Diagnostics.Stopwatch
$Start = Get-Date

$Error.Clear()

$MesgPass = ".....Passed!"
$MesgSep = "======================================================================="
"==========================| $Start |====================================" | Out-file -FilePath $Logfile -Append

################################################################################################################
# Running Test: DCPromo Log - contains errors?
################################################################################################################
$Timer.Start()

Write-Host $MesgSep 
Write-Host "Running Test: Evaluating DCPromo Log file"
Write-Host $MesgSep

$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Evaluating DCPromo Log file" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append

$DCPromoLog = Select-String -Path C:\Windows\debug\DCPROMO.LOG -Pattern 'error','fail','warning' -Context 4
If($DCPromoLog -ne $null){
    Write-Host ".....FAILED......" -ForegroundColor Red
    Write-Host ".....Review the lines with a '>' in front of them"
    Write-Host $DCPromoLog -ForegroundColor Yellow
    ".....FAILED......"  | Out-File -FilePath $LogFile -Append
    ".....Review the lines with a '>' in front of them" | Out-File -FilePath $LogFile -Append
    $DCPromoLog | Out-File -FilePath $LogFile -Append
    }
Else{
    Write-Host ".....Passed!" -ForegroundColor Green
    $MesgPass | Out-File -FilePath $LogFile -Append
    }


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$Timer.Reset()

################################################################################################################
# DC is a Global Catalog
# - GCTest is looking at DC is configured as GC
# - GCReadyEvent is verifying DC is advertising and ready as GC
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: Checking if Global Catalog"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Checking if Global Catalog" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append

If ((Get-ADDomainController).IsGlobalCatalog){$GCTest = "Passed"} 
Else {$GCTest = "Failed"}
$error.Clear()
Try{
    $GCReadyEvent = Get-WinEvent -FilterHashTable @{ LogName = "Directory Service"; ID = 1119 } -ErrorAction Stop
}

Catch {$GCReadyEvent = $null}

  
If($GCReadyEvent -eq $null){
    Write-Host "  -->Determine why this DC is not advertising as a GC. (Event 1119 not found)" -ForegroundColor Red
    Write-Host "  -->Event Error: $Error" -ForegroundColor Yellow 
    Write-Host "      If event logs have been cleared or rolled since the promotion this error will appear!"
    "  -->Determine why this DC is not advertising as a GC. (Event 1119 not found)" | Out-File -FilePath $LogFile -Append
    "  -->Event Error: $Error" | Out-File -FilePath $LogFile -Append 
    "      If event logs have been cleared or rolled since the promotion this error will appear!" | Out-File -FilePath $LogFile -Append
    } #End If
If($GCTest -eq "Failed"){
    Write-Host "  -->Determine why this DC is not configured as a GC within AD." -ForegroundColor Red
    "  -->Determine why this DC is not configured as a GC within AD." | Out-File -FilePath $LogFile -Append
    }


If(($GCReadyEvent -ne $null) -and ($GCTest -eq "Passed")){
    Write-Host ".....Passed!" -ForegroundColor Green
    $MesgPass | Out-File -FilePath $LogFile -Append
}
$error.clear()


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
#########################################################################################################################
# Verify SYSVOL/ Netlogon Shared
# - Values will be null if NOT shared
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: Verifying Netlogon and SYSVOL shared"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Verifying Netlogon and SYSVOL shared" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append

$SYSVOLShare = Get-SmbShare -Name SYSVOL -ShareState Online -ErrorAction SilentlyContinue
$NetlogonShare = Get-SmbShare -Name NetLogon -ShareState Online -ErrorAction SilentlyContinue

If(($SYSVOLShare -ne $Null) -and ($NetlogonShare -ne $Null)) {
    Write-Host ".....Passed!" -ForegroundColor Green
    $MesgPass | Out-File -Filepath $LogFile -Append
    }   
If($SYSVOLShare -eq $Null){
    Write-Host "  -->Determine why SYSVOL is NOT shared" -ForegroundColor Red
    "  -->Determine why SYSVOL is NOT shared"| Out-File -Filepath $LogFile -Append
    }
If($NetlogonShare -eq $Null){
    Write-Host "  -->Determin why NetLogon is NOT shared" -ForegroundColor Red
    "  -->Determin why NetLogon is NOT shared" | Out-File -Filepath $LogFile -Append
    }


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
#########################################################################################################################
# Verify DFS targets set to use FQDN
# - DFSFQDN variable is pass/fail
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: Ensuring DFS Namespace using FQDN"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Ensuring DFS Namespace using FQDN" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append

$DFSFQDNSetting = (Get-DfsnServerConfiguration -ComputerName $env:COMPUTERNAME).UseFqdn

If (($DFSFQDNSetting -eq $null) -or ($DFSFQDNSetting -eq $false)){
    Write-Host "  -->ERROR: Please run the following to configure DFS to use FQDN:" -ForegroundColor Red
    Write-Host "  -->  Set-DfsnServerConfiguration -ComputerName" $env:COMPUTERNAME '-UseFqdn $True'
    Write-Host "  -->  Be sure to restart the DFS service after the change! (Restart-Service DFS)"
    "  -->ERROR: Please run the following to configure DFS to use FQDN:"| Out-File -FilePath $LogFile -Append
    "  -->  Set-DfsnServerConfiguration -ComputerName " + $env:COMPUTERNAME + ' -UseFqdn $True'| Out-File -FilePath $LogFile -Append
    "  -->  Be sure to restart the DFS service after the change! (Restart-Service DFS)"| Out-File -FilePath $LogFile -Append
    }
Else{
    Write-Host ".....Passed!" -ForegroundColor Green
    $MesgPass | Out-File -FilePath $Logfile -Append
    }


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
#########################################################################################################################
# Verify DFS namespaces and replication
# - 
#########################################################################################################################


#########################################################################################################################
# DNS Service Running
# DNS Forwarder List
# DNS Root Hints disabled
# - Look for event 4 "finished replicating DNS"
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: DNS Service | Forwarders & Root Hint status"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: DNS Service | Forwarders & Root Hint status" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append

$Error.Clear()
$DNSService = (Get-Service -Name DNS).Status
Try{$DNSReadyEvent = Get-WinEvent -FilterHashTable @{ LogName = "DNS Server"; ID = 4 } -ErrorAction Stop}
Catch{$DNSReadyEvent = $null}
Try{$DNSFwd = (Get-DnsServerForwarder -ErrorAction Stop).IPAddress.IPAddressToString}
Catch{
    Write-Host "  -->ERROR:Not found or unable to query!" -ForegroundColor Red
    "  -->ERROR:Not found or unable to query!" | Out-File -FilePath $logFile -Append
    }

If($DNSUseRoot = (Get-DnsServerForwarder).UseRootHint) {
    Write-Host ".....Passed - Root Hints Disabled!" -ForegroundColor Green
    $MesgPass | Out-File -FilePath $LogFile -Append
    }
Else{
    Write-Host "  -->ERROR: DNS Root Hints Enabled!" -ForegroundColor Red
    "  -->ERROR: DNS Root Hints Enabled!" | Out-File -FilePath $LogFile -Append
    }
If($DNSService -eq "Running"){
    Write-Host ".....Passed - DNS Service Running!" -ForegroundColor Green
    ".....Passed - DNS Service Running!" | Out-File $LogFile -Append
    }
Else{
    Write-Host "  -->ERROR: DNS Service is NOT running!" -ForegroundColor Red
    "  -->ERROR: DNS Service is NOT running!" | Out-File -FilePath $LogFile -Append
    }
If($DNSReadyEvent -ne $Null){
    Write-Host ".....Passed - Event 4 for DNS found! (DNS Replication Completed)" -ForegroundColor Green
    ".....Passed - Event 4 for DNS found! (DNS Replication Completed)" | Out-File -FilePath $LogFile -Append
    }
Else{
    Write-Host "  -->ERROR: DNS Event 4 not found! DNS Replication has not completed!" -ForegroundColor Red
    "  -->ERROR: DNS Event 4 not found! DNS Replication has not completed!" | Out-File -FilePath $Logfile -Append
    }

$Error.Clear()


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
#########################################################################################################################
# DNS Records Check
# - Pulls in local DC's Netlogon.DNS 
# - Does DNS name lookup against PDC for each SRV
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: Verifying DNS SRV Records for DC registered"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Verifying DNS SRV Records for DC registered" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append
$Error.Clear()
$FailCount = 0
$SRVRecords = Get-Content "C:\Windows\System32\Config\Netlogon.dns"|?{$_ -match "IN SRV"} 
Foreach($Record in $SRVRecords){
    $Record = $Record -replace " ", ","
    $Record = $Record.Substring(0, $Record.IndexOf(","))
    Try{
        $DNSResolve = Resolve-DnsName -Server (Get-ADDomain).PDCEmulator -Name $Record -ErrorAction Stop
        }
    Catch{
        Write-Host "  -->ERROR: SRV Record not resolving!" -ForegroundColor Red
        Write-Host "  --> $Record" -ForegroundColor Yellow
        "  -->ERROR: SRV Record not resolving!"| Out-File -FilePath $LogFile -Append
        "  --> $Record"| Out-File -FilePath $LogFile -Append
        $FailCount += $FailCount
        }

    }
If($FailCount -eq 0){
    Write-Host ".....Passed - DC's SRV Records resolved!" -ForegroundColor Green
    ".....Passed - DC's SRV Records resolved!" | Out-File -FilePath $Logfile -Append
    }
$DNSErrors = $Error.exception
$Error.Clear()


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
#########################################################################################################################
# Initial AD replication completed
# - If failures capture in $ReplSumFails
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: Getting AD Replication information"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Getting AD Replication information" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append
$ReplSumFails = @()
$ReplSum = Get-ADReplicationPartnerMetadata -Target $env:COMPUTERNAME -Partition * | 
Select-Object Server,Partition,Partner,ConsecutiveReplicationFailures,LastReplicationSuccess,LastRepicationResult 
# - Check for errors in output
Foreach($item in $ReplSum){
    If($item.ConsecutiveReplicationFailures -ne 0){
        $ReplSumFails += $item
        }
}
If($ReplSumFails -ne $Null){
    Write-Host "  -->ERROR: There are AD Replication Failures!" -ForegroundColor Red
    Write-Host "  --> $ReplSumFails" -ForegroundColor Yellow
    "  -->ERROR: There are AD Replication Failures!" | Out-File -FilePath $LogFile -Append
    "  --> $ReplSumFails" | Out-File -FilePath $LogFile -Append
    
    }
Else{
    Write-Host ".....Passed" -ForegroundColor Green
    $MesgPass | Out-File -FilePath $Logfile -Append
    }


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
#########################################################################################################################
# DCDiag Collection and formatting
# - Output put into $Results with each test marked passed or failed
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: Getting DCDIAG information"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Getting DCDIAG information" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append
$DCDiagFailed = @() 
$Dcdiag = (Dcdiag.exe /s:$env:ComputerName) -split ('[\r\n]') 
$DCDIAGResults = New-Object Object 
$DCDIAGResults | Add-Member -Type NoteProperty -Name "ServerName" -Value $env:ComputerName
$Dcdiag | %{ 
    Switch -RegEx ($_) { 
        "Starting"      { $TestName   = ($_ -Replace ".*Starting test: ").Trim() } 
        "passed test|failed test" { 
            If ($_ -Match "passed test") {$TestStatus = "Passed"}  
            Else {$TestStatus = "Failed"}
            }#End If 
     }#End Switch
      
    If ($TestName -ne $Null -And $TestStatus -ne $Null) { 
        $DCDIAGResults | Add-Member -Name $("$TestName".Trim()) -Value $TestStatus -Type NoteProperty -force 
        If($TestStatus -eq "failed"){$DCDiagFailed += ,$TestName}
        $TestName = $Null; $TestStatus = $Null 
    }#End If
}#End Piped ForEach %

If($DCDiagFailed -ne $null){
    Write-Host "  -->ERROR: There are DCDIAG Items below that Failed!" -ForegroundColor Red
    "  -->ERROR: There are DCDIAG Items below that Failed!" | Out-File -FilePath $Logfile -Append
    ForEach ($item in $DCDiagFailed){
        Write-Host "  --> $item" -ForegroundColor Yellow
        "  --> $item" | Out-File -FilePath $Logfile -Append
        }
    }
Else{
    Write-Host ".....Passed" -ForegroundColor Green
    $MesgPass | Out-File -FilePath $LogFile -Append
    }


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
#########################################################################################################################
# Network Adapter DNS Suffix Search Order
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: Getting Adapter DNS Suffix Search Order"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Getting Adapter DNS Suffix Search Order" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append


$AdapterDNS = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName . | Select-Object -Property DNSDomainSuffixSearchOrder -ExcludeProperty IPX*,WINS*
$AdapterDNS = $AdapterDNS.DNSDomainSuffixSearchOrder

Write-Host "  --> The DNS Suffix search order for the enabled adapter is:"
Write-Host "  --> $AdapterDNS" -ForegroundColor Cyan
"  --> The DNS Suffix search order for the enabled adapter is:"| Out-File -FilePath $LogFile -Append
"  --> $AdapterDNS"| Out-File -FilePath $LogFile -Append


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
#########################################################################################################################
# Check Time
# - $WinTime has output in object form
# - checking for Source, Last Success sync, time delta
#########################################################################################################################
$Timer.Start()

Write-Host $MesgSep
Write-Host "Running Test: Verifying Windows Time is in sync"
Write-Host $MesgSep
$MesgSep  | Out-File -FilePath $LogFile -Append
"Running Test: Verifying Windows Time is in sync" | Out-File -FilePath $LogFile -Append
$MesgSep | Out-File -FilePath $LogFile -Append
$WinTime = [pscustomobject]((w32tm /query /status) -replace ': ',',' `
| ConvertFrom-Csv -Header Name,Value)

$WinTime = ((w32tm /query /status) -replace ': ',',') | ConvertFrom-String -PropertyNames Name, Value -Delimiter ","
$LastSync = ($WinTime | Where-Object Name -eq "Last Successful Sync Time").value
$TimeSource = ($WinTime | Where-Object Name -eq "Source").value
$TimeDeltaSec = $WinTime | Where-Object Name -eq "Root Dispersion"
$TimeDeltaSec = $TimeDeltaSec.Value -replace 's',""

$TimeDeltaColor = "White"
$TimeSourceColor = "White"

If(($TimeDeltaSec -gt 300) -or (($TimeSource -eq "VM IC Time Synchronization Provider")-or($TimeSource -eq "Local CMOS Clock"))){
    Write-Host "  --> ERROR: The Windows Time test failed!" -ForegroundColor Red
    "  --> ERROR: The Windows Time test failed!"| Out-File -FilePath $Logfile -Append
    If($TimeDeltaSec -gt 300){$TimeDeltaColor = "Yellow"}
    If(($TimeSource -eq "VM IC Time Synchronization Provider")-or($TimeSource -eq "Local CMOS Clock")) {$TimeSourceColor = "Yellow"}
    }
Else{
    Write-Host ".....Passed" -ForegroundColor Green
    $MesgPass | Out-File -FilePath $Logfile -Append
    }


Write-Host "      Source for time: $TimeSource" -ForegroundColor $TimeSourceColor
Write-Host "      Last Sync:       $LastSync" 
Write-Host "      Delta in Sec:    $TimeDeltaSec" -ForegroundColor $TimeDeltaColor
"      Source for time: $TimeSource"| Out-File -FilePath $Logfile -Append
"      Last Sync:       $LastSync" | Out-File -FilePath $Logfile -Append
"      Delta in Sec:    $TimeDeltaSec"| Out-File -FilePath $Logfile -Append


$ElapsedTime = $Timer.Elapsed
$min = $ElapsedTime.Minutes
$sec = $ElapsedTime.Seconds
Write-Host "======> Completed in $Min min $Sec sec"
"======> Completed in $Min min $Sec sec" | Out-File -FilePath $LogFile -Append
$TImer.Reset()
$Stop = Get-Date
$TimeTotal = New-TimeSpan -Start $Start -End $Stop

$min = $TimeTotal.Minutes
$sec = $TimeTotal.Seconds
Write-Host $MesgSep -ForegroundColor Cyan
Write-Host "      Tests Completed! "-ForegroundColor Cyan
Write-Host "       Time needed to complete: $Min min $Sec sec"
Write-Host $MesgSep -ForegroundColor Cyan
$MesgSep| Out-File -FilePath $LogFile -Append
"      Tests Completed! "| Out-File -FilePath $LogFile -Append
"       Total time needed to complete: $Min min $Sec sec"| Out-File -FilePath $LogFile -Append
$MesgSep| Out-File -FilePath $LogFile -Append
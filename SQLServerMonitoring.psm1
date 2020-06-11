
Function Get-SQLMonitoringEmailHeader
{
$Header = @"
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
.odd  { background-color:#ffffff; }
.even { background-color:#dddddd; }
</style>
<title>
Title of my Report
</title>
"@
return $Header
    REMOVE-VARIABLE Header
}



<#
 .Synopsis
  Returns the Monitoring SQL Server and corresponding Databases.
  The output is a hashtable.

 .Description
  This function returns the monitoring server and databases
 
 .Example
   # Return Monitoring Server and Database names
   $MonitoringDetails  = Get-SQLMonitoringServer
   $MonitoringServer   = $MonitoringDetails.ServerInstance   
   $MonitoringDatabase = $MonitoringDetails.MonitoringDatabase
   $StagingDatabase    = $MonitoringDetails.StagingDatabase
#>

FUNCTION Get-SQLMonitoringServer
    {

        [hashtable]$return = @{}
        $return = @{ServerInstance = "Monitor-03\SQLServer1"; StagingDatabase = "Staging"; MonitoringDatabase = "DatabaseMonitoring"}
        return $return
        REMOVE-VARIABLE return
    }


<#
 .Synopsis
  This function will return all corresponding SQL Server Instances based on the passed parameters

 .Description
  Get-SQLMonitoringServerList returns an object for all corresponding SQL Server instances.

 .Parameter InstanceRole
  Instance role helps to return instances based on their use cases e.g. DEV,TEST,PROD

 .Parameter InstanceType
  Instance type corresponds to the importance it has on business activity

 .Example
   # Show a default display of this month.
   $SQLServerList = Get-SQLMonitoringServerList -InstanceRole 'PROD' -InstanceType 'BUSINESS CRITICAL'
   $SQLServerList.ComputerName 
   $SQLServerList.InstanceName
   $SQLServerList.SqlInstance
#>
FUNCTION Get-SQLMonitoringServerList
    {
        PARAM
            (
                 [Parameter(Mandatory=$True)] [ValidateSet('ALL','DEV','TEST','NONPROD','PROD','STAGING')]     [STRING]  $InstanceRole 
                ,[Parameter(Mandatory=$True)] [ValidateSet('BUSINESS CRITICAL','NOT BUSINESS CRITICAL','ALL')] [STRING]  $InstanceType
            )
           
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName = $MonitoringServerDetails.MonitoringDatabase
        if ($InstanceType -eq "ALL" -and $InstanceRole -eq "ALL")
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1"
            }
        elseif ($InstanceRole -eq "ALL" -and $InstanceType -eq "BUSINESS CRITICAL")
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1 AND InstanceType = 'BUSINESS CRITICAL'"
            }
        elseif ($InstanceRole -eq "PROD" -and $InstanceType -eq "ALL")
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1 AND InstanceRole = 'PROD'"
            }
        elseif ($InstanceRole -eq "PROD" -and $InstanceType -eq "BUSINESS CRITICAL")
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1 AND InstanceRole = 'PROD' AND InstanceType = 'BUSINESS CRITICAL'"
            }
        elseif ($InstanceRole -eq "PROD" -and $InstanceType -ne "BUSINESS CRITICAL")
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1 AND InstanceRole = 'PROD' AND InstanceType <> 'BUSINESS CRITICAL'"
            }
        elseif ($InstanceRole -eq "NONPROD" -and $InstanceType)
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1 AND InstanceRole <> 'PROD'"
            }
        elseif ($InstanceRole -eq "DEV" -and $InstanceType)
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1 AND InstanceRole = 'DEV'"
            }
        elseif ($InstanceRole -eq "TEST" -and $InstanceType)
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1 AND InstanceRole = 'TEST'"
            }
        elseif ($InstanceRole -eq "STAGING" -and $InstanceType)
            {
                $ReturnValue = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT ComputerName, InstanceName, SqlInstance FROM SQLServer.SQLServerList WHERE isActive = 1 AND InstanceRole = 'STAGING'"
            }
        return $ReturnValue
        
        REMOVE-VARIABLE InstanceRole 
        REMOVE-VARIABLE InstanceType
        REMOVE-VARIABLE ReturnValue
 
    }    

<#
 .Synopsis
  Used as part of the monitoring solution, this helps to outline running tasks and maintain a record of how long tasks acutally ran for


 .Description
 This function allows for the monitoring solution to be monitored, this way we can see if a particular process is stuck for a long period of time and also look at altering our monitoring stragies

  
 .Parameter TaskName
 TaskName can be seen as a child task, it allows for more granularity when analsing logging performance

 .Parameter ParentTask
 A task can have children as it can be looping through servers or databases, in providing a parent, it makes it easier to monitor when a full process

 .Parameter ComputerName	
 ComputerName Corresponds to the Computer which the SQLInstance that is having a task run against it is hosted on

 .Parameter SqlInstance
 SQLInstance Corresponds to the SQLInstance that is having a task run against it

 .Parameter Database
 Periodically, tasks will run on a per database level, so by logging at a per database level, we are able to monitor logging performance with more granularity

 .Parameter StartDateTime	
 StartDatetime corresponds to the start of a tasks execution

 .Parameter EndDateTime
 EndDatetime should only be used when closing a task, so without initial log.

 .Parameter InitialLog
 Initial Log is used to write to Logging.ExecutingTasks, so we can see where a process is upto.
 It should be called when starting a new process.

 .Example
 #Sample Execution
 $StartDateTime = get-date
 $EndDateTime = (get-date).AddMinutes(1)
 Write-SQLMonitoringLoggingTable -TaskName "TestTask" -ParentTask "Parent Test" -ComputerName "Monitor-03" -SqlInstance "Monitor-03\SQLServer1" -StartDateTime $StartDateTime -InitialLog
 Write-SQLMonitoringLoggingTable -TaskName "TestTask" -ParentTask "Parent Test" -ComputerName "Monitor-03" -SqlInstance "Monitor-03\SQLServer1" -StartDateTime $StartDateTime -EndDateTime $EndDateTime 

#>
FUNCTION Write-SQLMonitoringLoggingTable
    {
        PARAM
            (
                 [Parameter(Mandatory=$TRUE)]  [STRING]    $TaskName
                ,[Parameter(Mandatory=$TRUE)]  [STRING]    $ParentTask
                ,[Parameter(Mandatory=$FALSE)] [STRING]    $ComputerName	
                ,[Parameter(Mandatory=$FALSE)] [STRING]    $SqlInstance
                ,[Parameter(Mandatory=$FALSE)] [STRING]    $Database
                ,[Parameter(Mandatory=$TRUE)]  [DATETIME]  $StartDateTime	
                ,[Parameter(Mandatory=$FALSE)] [DATETIME]  $EndDateTime
                ,[Parameter(Mandatory=$TRUE)]  [GUID]      $LoggingGUID
                ,[Parameter(Mandatory=$TRUE)]  [BOOLEAN]   $InitialLog
                
            )      
        $MonitoringServerOutput = Get-SQLMonitoringServer
        $TargetServerInstance  = $MonitoringServerOutput.ServerInstance        
        $MonitoringDatabase    = $MonitoringServerOutput.MonitoringDatabase
        $TargetDatabase        = $MonitoringServerOutput.StagingDatabase
        $TargetSchema          = "SQLServer"
        $TargetTable           = "MonitoringExecutingTasks"
        
        if ($ComputerName.Length -eq 0)
            {
                $QueryOutput  = Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $MonitoringDatabase -Query "SELECT  SqlInstance, ComputerName,InstanceName FROM SQLServer.SQLServerList WHERE isActive = 1 AND SQLInstance = '$SQLInstance';"
                $ComputerName = if ($QueryOutput.ComputerName -eq $null) { $SqlInstance } else { $QueryOutput.ComputerName}
                $InstanceName = if ($QueryOutput.InstanceName -eq $null) { $SqlInstance } else { $QueryOutput.InstanceName}
            }
        elseif ($ComputerName.Length -gt 3)
            {
                $InstanceName  = $ComputerName
                $SQLInstance   = $ComputerName
            }
        if ($Database.Length -eq 0)
            {
                $Database = "N/A"
            }
        if ($EndDateTime -eq $null)
            {
                $EndDateTime = (get-date)
            }
        $Output = $TaskName | Select-Object @{Name ="TaskName"; Expression={$TaskName}},@{Name ="ParentTask"; Expression={$ParentTask}},@{Name ="ComputerName"; Expression={$ComputerName}},@{Name ="InstanceName"; Expression={$InstanceName}},@{Name ="SqlInstance"; Expression={$SqlInstance}},@{Name ="DatabaseName"; Expression={$Database}},@{Name ="StartDateTime"; Expression={$StartDateTime}},@{Name ="EndDateTime"; Expression={$EndDateTime}},@{Name ="ExecutionGUID"; Expression={$LoggingGUID.Guid}},@{Name ="InitialLog"; Expression={$InitialLog}}
        $Output | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable -FireTriggers

        REMOVE-VARIABLE TaskName
        REMOVE-VARIABLE ParentTask
        REMOVE-VARIABLE ComputerName
        REMOVE-VARIABLE SqlInstance
        REMOVE-VARIABLE Database
        REMOVE-VARIABLE StartDateTime
        REMOVE-VARIABLE EndDateTime
        REMOVE-VARIABLE LoggingGUID
        REMOVE-VARIABLE InitialLog
        REMOVE-VARIABLE MonitoringServerOutput
        REMOVE-VARIABLE TargetServerInstance  
        REMOVE-VARIABLE TargetDatabase        
        REMOVE-VARIABLE TargetTable
        REMOVE-VARIABLE Output   
        REMOVE-VARIABLE QueryOutput
        REMOVE-VARIABLE MonitoringDatabase                   
    }

    FUNCTION Get-SQLMonitoringMailServer
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.MonitoringDatabase
        return Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT MonitoringValue MailServer FROM SQLServer.MonitoringInformation WHERE MonitoringAttribute = 'Mail Server'"

        REMOVE-VARIABLE MonitoringServerDetails
        REMOVE-VARIABLE MonitoringInstanceName 
        REMOVE-VARIABLE MonitoringDatabaseName 

    }

function Disable-SQLMonitoringSSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    ## We create an instance of TrustAll and attach it to the ServicePointManager
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll

    REMOVE-VARIABLE Provider
    REMOVE-VARIABLE Compiler
    REMOVE-VARIABLE Params
    REMOVE-VARIABLE TASource
    REMOVE-VARIABLE TAResults
    REMOVE-VARIABLE TAAssembly
    REMOVE-VARIABLE TrustAll
}

function Send-SQLMonitoringSQLOutput
    {
        PARAM
            (
                 [STRING] $SQLOutput
                ,[STRING] $SMTPServer
                ,[STRING] $ToEmailAddress
                ,[STRING] $FromEmailAddress
                ,[STRING] $CCEmailAddress
                ,[STRING] $Subject
            )


        Send-MailMessage -to $ToEmailAddress -SmtpServer $SMTPServer -body $SQLOutput -Subject $Subject -From $FromEmailAddress -BodyAsHtml    

        REMOVE-VARIABLE-SQLOutput
        REMOVE-VARIABLE-SMTPServer
        REMOVE-VARIABLE-ToEmailAddress
        REMOVE-VARIABLE-FromEmailAddress
        REMOVE-VARIABLE-CCEmailAddress
        REMOVE-VARIABLE-Subject        
    }


FUNCTION Get-SQLMonitoringAlertDetails
    {  
        PARAM 
        (     
             [STRING]$AlertDetailsAlertName
        )
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.MonitoringDatabase
        $Query = 
        "SELECT 
             AlertID
            ,AlertName			
            ,AlertDescription	
            ,AlertText			
            ,FromEmailAddress	
            ,ToEmailAddress
            ,RepeatFrequencySecs		
        FROM
            Alerting.Alerts
        WHERE
            isActive = 1
        AND
            AlertName = '$AlertDetailsAlertName';
        "
        return Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query $Query
        
        REMOVE-VARIABLE MonitoringServerDetails
        REMOVE-VARIABLE MonitoringInstanceName 
        REMOVE-VARIABLE MonitoringDatabaseName 
        REMOVE-VARIABLE Query 
    }

    FUNCTION Write-SQLMonitoringBackupHistory
    {
        PARAM
            (
                 [STRING] $SQLInstance     
                 ,[INT]   $DaysAway     = -1
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "BackupHistory"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            
            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1
            
            Get-DbaDbBackupHistory -SqlInstance $SQLInstance -Since (get-date).AddDays($DaysAway)| Select-Object ComputerName,InstanceName,SqlInstance, TotalSize, CompressedBackupSize, CompressionRatio, ` 
                @{Name ="DatabaseName" ; Expression={$_.Database}}, UserName, @{Name ="StartDtTime" ; Expression={$_.Start}},@{Name ="EndDtTime" ; Expression={$_.End}},@{Name ="BackupPath" ; Expression={$_.Path}}, `
                @{Name ="BackupType" ; Expression={$_.Type}}, BackupSetId, DeviceType, @{Name ="FullName" ; Expression={$_.FullName[0]}}, Position, FirstLsn, DatabaseBackupLsn,CheckpointLsn, LastLsn, IsCopyOnly, LastRecoveryForkGUID, RecoveryModel `
                | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0
            
            REMOVE-variable MonitoringServerDetails 
            REMOVE-variable TargetServerInstance    
            REMOVE-variable TargetDatabase          
            REMOVE-variable TargetSchema            
            REMOVE-variable TargetTable             
            REMOVE-variable StartDateTime           
            REMOVE-variable TaskName                
            REMOVE-variable ParentTask      
            Remove-Variable LoggingGUID
            REMOVE-VARIABLE SQLInstance
            REMOVE-VARIABLE DaysAway        
    };

FUNCTION Write-SQLMonitoringDatabaseFileInformation
    {
        PARAM
            (
                 [STRING] $SQLInstance      
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.MonitoringDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "DatabaseFiles"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1

            Get-DbaDbFile -SqlInstance $SQLInstance | Select-Object ComputerName, InstanceName, SqlInstance, @{Name ="DatabaseName"; Expression={$_.Database}},FileGroupName, `
                @{Name ="FileID"; Expression={$_.ID}}, TypeDescription, LogicalName , PhysicalName, @{Name ="FileState"; Expression={$_.State}}, MaxSize, NextGrowthEventSize, `
                @{Name ="FileSize"; Expression={$_.Size}}, UsedSpace, AvailableSpace, IsReadOnly, NumberOfDiskWrites, NumberOfDiskReads, ReadFromDisk, WrittenToDisk, VolumeFreeSpace, `
                FileGroupTypeDescription | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                
                
            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (get-date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-Variable MonitoringServerDetails
            REMOVE-Variable TargetServerInstance   
            REMOVE-Variable TargetDatabase         
            REMOVE-Variable TargetSchema           
            REMOVE-Variable TargetTable            
            REMOVE-Variable StartDateTime          
            REMOVE-Variable TaskName               
            REMOVE-Variable ParentTask             
            REMOVE-Variable LoggingGUID             
    };

    FUNCTION Write-SQLMonitoringDatabaseFileIOLatency
    {
        PARAM
            (
                 [STRING] $SQLInstance      
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.MonitoringDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "DatabaseFileIOLatency"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            
            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1

                Get-DbaIoLatency -SQLinstance $SQLInstance | Select-Object ComputerName, InstanceName, SqlInstance, DatabaseName, DatabaseId, @{Name ="DatabaseFileId"; Expression={$_.FileID}}, PhysicalName, `
                NumberOfReads, IoStallRead, NumberOfwrites, IoStallWrite, IoStall, NumberOfBytesRead, NumberOfBytesWritten, SampleMilliseconds, SizeOnDiskBytes, ReadLatency, WriteLatency, Latency, `
                AvgBPerRead, AvgBPerWrite, AvgBPerTransfer | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (get-date) -LoggingGUID $LoggingGUID -InitialLog 0            

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE LoggingGUID
    };    

    FUNCTION Write-SQLMonitoringServerDiskSpace
    {
        PARAM
            (
                 [STRING] $ComputerName        
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "StorageSpace"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1

            get-dbadiskspace -ComputerName $ComputerName | select-object ComputerName,  @{Name ="ServerName" ; Expression={$_.Server}}, @{Name ="DriveName" ; Expression={$_.Name}} `
                , @{Name ="DriveLabel" ; Expression={$_.Label}}, DriveType, SizeInMB, @{Name ="FreeSpaceInMB" ; Expression={$_.FreeInMB}},` 
                @{Name ="DiskBlockSize" ; Expression={$_.BlockSize}}, FileSystem, @{Name ="DiskType" ; Expression={$_.Type}} | `
                Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers

            $LoggingGUID = New-Guid
            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0
            
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask                              
            REMOVE-VARIABLE LoggingGUID
            REMOVE-VARIABLE ComputerName

    };

FUNCTION Write-SQLMonitoringSQLServerList
    {
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "SQLServerList"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1

            Get-SqlInstance -ServerInstance $SQLInstance | Select-Object @{Name ="ComputerName"; Expression={$_.NetName}}, @{Name ="InstanceName"; Expression={$_.ServiceName}},`
                @{Name ="SqlInstance"; Expression={$_.DomainInstanceName}}, `Edition, ServerType, VersionString, BuildClrVersionString, ProductLevel, ServerVersion, HostPlatform, ResourceLastUpdateDateTime, UpdateLevel, `
                OSVersion, Platform, PhysicalMemory, Processors, LoginMode, Collation, ClusterName, ClusterQuorumState, ClusterQuorumType, HadrManagerStatus, IsClustered, IsHadrEnabled, AuditLevel, AvailabilityGroups, `
                DefaultAvailabilityGroupClusterType,@{Name ="isActive"; Expression={1}},@{Name ="AddedDateTime"; Expression={get-date}} `
                | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers
            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask  
            REMOVE-VARIABLE LoggingGUID           

    };


FUNCTION Write-SQLMonitoringStartupServices
    {
        PARAM
            (
                 [STRING] $ComputerName        
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "SQLServices"
            $StartDateTime           = (get-date)
            $TaskName                =   "$SQLInstance - $TargetTable"
            $ParentTask              =   "$TargetTable"

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1

            get-dbaservice -ComputerName $ComputerName | Select-object ComputerName, PSComputerName, DisplayName, ServiceName, InstanceName,StartName, ServiceType, StartMode `
                ,Description, BinaryPath, @{Name ="ServiceState" ; Expression={$_.State}} | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask                              
            REMOVE-VARIABLE ComputerName    
    };

FUNCTION Write-SQLMonitoringAgentJobs
    {
        PARAM
            (
                 [STRING]  $SQLInstance
                 ,[STRING] $JobName
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "AgentJobs"
            $StartDateTime           = (get-date)
            $TaskName                =   "$SQLInstance - $JobName - $TargetTable"
            $ParentTask              =   "$TargetTable"

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1            
            
            if ($JobName -eq $null)
                {
                    Get-DbaAgentJob -SQLinstance $SQLInstance |Select-object ComputerName,InstanceName,SqlInstance,JobID,@{Name ="JobName" ; Expression={$_.Name}}, `
                        @{Name ="JobDescription" ; Expression={$_.Description}},JobType,CreateDate,Category,DateCreated,DateLastModified,OperatorToEmail,OwnerLoginName,StartStepID, `
                        @{Name ="JobSteps" ; Expression={$_.JobSteps.count}},@{Name ="JobSchedules" ; Expression={$_.JobSchedules.count}},EmailLevel,HasSchedule,IsEnabled| Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                
                }
            else
                {
                    Get-DbaAgentJob -SQLinstance $SQLInstance -Job $JobName |Select-object ComputerName,InstanceName,SqlInstance,JobID,@{Name ="JobName" ; Expression={$_.Name}}, `
                        @{Name ="JobDescription" ; Expression={$_.Description}},JobType,CreateDate,Category,DateCreated,DateLastModified,OperatorToEmail,OwnerLoginName,StartStepID, `
                        @{Name ="JobSteps" ; Expression={$_.JobSteps.count}},@{Name ="JobSchedules" ; Expression={$_.JobSchedules.count}},EmailLevel,HasSchedule,IsEnabled| Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                
                }
            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0            
            
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask  
            REMOVE-VARIABLE LoggingGUID            
            REMOVE-VARIABLE SQLInstance
            REMOVE-VARIABLE JobName            

    };
FUNCTION Write-SQLMonitoringAgentJobSteps
    {
        PARAM
            (
                  [STRING] $SQLInstance     
                 ,[STRING] $JobName
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "AgentJobSteps"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $JobName - $TargetTable"
            $ParentTask              = "$TargetTable"

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1

            if ($JobName -eq $null)
                {
                    Get-DbaAgentJobStep -SqlInstance $SQLInstance | Select-Object ComputerName, InstanceName, SqlInstance, AgentJob, @{Name ="JobStepID"; Expression={$_.ID}}, Parent, `
                        Command,  DatabaseName, JobStepFlags, OnFailAction, OnFailStep, OnSuccessAction, OnSuccessStep, ProxyName, RetryAttempts,RetryInterval, SubSystem | `
                        Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                
                }
            else
                {
                    Get-DbaAgentJobStep -SqlInstance $SQLInstance -Job $JobName | Select-Object ComputerName, InstanceName, SqlInstance, AgentJob, @{Name ="JobStepID"; Expression={$_.ID}}, Parent, `
                        Command,  DatabaseName, JobStepFlags, OnFailAction, OnFailStep, OnSuccessAction, OnSuccessStep, ProxyName, RetryAttempts,RetryInterval, SubSystem | `
                        Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                
                }

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0
            
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask 
            REMOVE-VARIABLE LoggingGUID
            REMOVE-VARIABLE SQLInstance
            REMOVE-VARIABLE JobName                            
    };
FUNCTION Write-SQLMonitoringAgentJobHistory
    {
        PARAM
            (
                 [STRING] $SQLInstance     
                 ,[INT]   $HoursAway    = -3
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "AgentJobHistory"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1            

            Get-DbaAgentJobHistory -SqlInstance $SQLInstance -StartDate (get-date).AddHours($HoursAway) |  Select-Object ComputerName, InstanceName, SqlInstance , StepName, JobID, JobName, StepID,InstanceID, StartDate, EndDate, RunDuration,  `
                @{Name ="JobStatus"; Expression={$_.Status}},  @{Name ="JobMessage"; Expression={$_.Message}}, OperatorEmailed, RetriesAttempted `
                | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0
            
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask   
            REMOVE-VARIABLE LoggingGUID
            REMOVE-VARIABLE SQLInstance  
            REMOVE-VARIABLE HoursAway                
    };

FUNCTION Write-SQLMonitoringErrorLog
    {
        PARAM
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "ErrorLog"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $ErrorLogFiles           = 10
            $Counter                 = 0 

            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1            

            $OutputArray =    
            while($true)
                {
                    if ($Counter -eq $ErrorLogFiles)
                        { 
                            break 
                        }
                    Get-DbaAgentLog -SqlInstance $SQLInstance -LogNumber $Counter | Select-Object ComputerName, InstanceName, SQLInstance, LogDate,  Text;
                        $Counter += 1;
                }                
            $OutputArray|Select-Object ComputerName, InstanceName, @{Name ="SQLInstance" ; Expression={$_.SQLInstance}}, LogDate,  @{Name ="ErrorText" ; Expression={$_.Text}} `
                 | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE ErrorLogFiles           
            REMOVE-VARIABLE Counter     
            REMOVE-VARIABLE LoggingGUID            
            REMOVE-VARIABLE SQLInstance  
    };

FUNCTION Write-SQLMonitoringDBTableInformation
    {
        PARAM
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "DBTableInformation"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"

            
            $SQLQuery = 
            "
            SET NOCOUNT ON;
            IF OBJECT_ID('tempdb..#temptable','U') IS NOT NULL DROP TABLE #temptable
            DECLARE @DBID	INT = 0;
            DECLARE @DBNAME NVARCHAR(255) = N'';;
            CREATE TABLE #temptable
                (
                     [ComputerName]            VARCHAR(128)
                    ,[InstanceName]            VARCHAR(128)
                    ,[SQLInstance]             VARCHAR(128)
                    ,[DatabaseName]            VARCHAR(128)
                    ,[TableObjectID]           INT
                    ,[SchemaName]              VARCHAR(128)
                    ,[TableName]               VARCHAR(128)
                    ,[FileGroupName]           VARCHAR(128)
                    ,[CreateDate]              DATETIME
                    ,[DateLastModified]        DATETIME
                    ,[TableRowCount]           BIGINT
                    ,[IndexCount]              INT
                    ,[ColumnCount]             INT
                    ,[TriggerCount]            INT
                    ,[PartitionCount]          INT
                    ,[ForeignKeyCount]         INT
                    ,[TableSizeMB]             DECIMAL(12, 2)
                    ,[TableSpaceUsedMB]        DECIMAL(12, 2)
                    ,[IndexSizeMB]             DECIMAL(12, 2)
                    ,[IndexSpaceUsedMB]        DECIMAL(12, 2)
                    ,[HasClusteredIndex]       INT
                    ,[isChangeTrackingEnabled] BIT
                    ,[isReplicatedf]           BIT
                    ,[NonClusteredIndexCount]  INT
                );
            DECLARE @sql NVARCHAR(MAX) = N'';
            DECLARE @Newsql NVARCHAR(MAX) = N'';
            SET @sql
                = N'
            USE [dbname];
            set transaction isolation level read uncommitted
            ;WITH Cte AS
                    (
                        SELECT
                          T.object_id,
                          P.ROWS AS ROWCOUNTS,
                          (SUM(A.TOTAL_PAGES) * 8)/1024.0 AS  TableSizeMB,
                          (SUM(A.USED_PAGES)  * 8)/1024.0 AS  TableUsedMB
                          ,IndexTOTALSPACEKB /1024.0	      IndexSizeUsedMB
                          ,IndexUSEDSPACEKB/1024.0            IndexSpaceUsedMB
                        FROM
                          sys.TABLES T
                        INNER JOIN
                          sys.INDEXES I ON T.OBJECT_ID = I.OBJECT_ID
                        INNER JOIN
                          sys.PARTITIONS P ON I.OBJECT_ID = P.OBJECT_ID AND I.INDEX_ID = P.INDEX_ID
                        INNER JOIN
                          sys.ALLOCATION_UNITS A ON P.PARTITION_ID = A.CONTAINER_ID
                        LEFT OUTER JOIN
                          sys.SCHEMAS S ON T.SCHEMA_ID = S.SCHEMA_ID
                        LEFT JOIN
	                        (
		                        SELECT
		                          I.OBJECT_ID,
		                          8 * SUM(A.total_PAGES) AS IndexTOTALSPACEKB,
		                          8 * SUM(A.USED_PAGES) AS IndexUSEDSPACEKB
		                        FROM
		                          sys.INDEXES AS I JOIN
		                          sys.PARTITIONS AS P ON P.OBJECT_ID = I.OBJECT_ID AND P.INDEX_ID = I.INDEX_ID JOIN
		                          sys.ALLOCATION_UNITS AS A ON A.CONTAINER_ID = P.PARTITION_ID
		                        WHERE
		                          OBJECT_NAME(I.OBJECT_ID) NOT LIKE ''sys%%''
		                          AND OBJECT_NAME(I.OBJECT_ID) NOT LIKE ''dt%%''
		                          AND OBJECT_NAME(I.OBJECT_ID) NOT LIKE ''filestream%%''
		                          AND OBJECT_NAME(I.OBJECT_ID) NOT LIKE ''filetable%%''
		                          AND OBJECT_NAME(I.OBJECT_ID) NOT LIKE ''plan_%%''
		                          AND OBJECT_NAME(I.OBJECT_ID) NOT LIKE ''queue_%%''
		                          AND OBJECT_NAME(I.OBJECT_ID) NOT LIKE ''sqlagent_%%''
		                          AND
			                        I.index_id > 1                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
		                        GROUP BY
		                          I.OBJECT_ID
	                        )Dt
                        ON
	                        T.object_id = Dt.object_id	
                        WHERE
                          T.NAME NOT LIKE ''dt%''
                          AND T.IS_MS_SHIPPED = 0
                          AND I.OBJECT_ID > 255
                          AND
	                        I.index_id <= 1    
                        GROUP BY
                           T.object_id
                          ,P.ROWS
                          ,IndexTOTALSPACEKB
                          ,IndexUSEDSPACEKB

                    )
                SELECT
                     CAST(SERVERPROPERTY(''MachineName'') AS VARCHAR(255)) ComputerName
                    ,@@SERVICENAME InstanceName
                    ,@@SERVERNAME SQLInstance
                    ,DB_NAME() DatabaseName
                    ,obj.object_id TableObjectID
                    ,UPPER(sch.name) SchemaName
                    ,UPPER(obj.name) TableName
                    ,UPPER(fgs.name) FileGroupName
                    ,obj.create_date CreateDate
                    ,obj.modify_date DateLastModified
                    ,part.rows TableRowCount
                    ,IxsDt.IndexCount 
                    ,Cols.ColumnCount 	
                    ,ISNULL(Trig.TriggerCount,0) TriggerCount
                    ,PartDt.PartitionCount
                    ,ISNULL(FKs.ForeignKeyCount	,0) ForeignKeyCount
                    ,ISNULL(CAST(Cte.TableSizeMB		AS NUMERIC(12,2)),0) TableSizeMB
                    ,ISNULL(CAST(Cte.TableUsedMB	AS NUMERIC(12,2)),0)     TableSpaceUsedMB
                    ,ISNULL(CAST(Cte.IndexSizeUsedMB	AS NUMERIC(12,2)),0) IndexSizeMB
                    ,ISNULL(CAST(Cte.IndexSpaceUsedMB   AS NUMERIC(12,2)),0) IndexSpaceUsedMB
                    ,HasClusteredIndex
                    ,obj.is_tracked_by_cdc isChangeTrackingEnabled
                    ,obj.is_replicated isReplicated
                    ,NonClusteredIndexCount
                FROM
                    sys.tables obj
                JOIN
                    sys.schemas sch
                ON
                    obj.schema_id = sch.schema_id
                LEFT JOIN
                    (
                        SELECT
	                         col.object_id
	                        ,COUNT(*) ColumnCount
                        FROM
	                        sys.columns col
                        GROUP BY
	                        col.object_id
                    )Cols
                ON
                    obj.object_id = Cols.object_id
                LEFT JOIN
                    sys.indexes ixs
                ON	
                    obj.object_id = ixs.object_id
                AND
                    ixs.index_id <= 1
                LEFT JOIN
                    sys.filegroups fgs
                ON
                    ixs.data_space_id = fgs.data_space_id
                LEFT JOIN
                    (
                        SELECT
	                         object_id
	                        ,COUNT(*) IndexCount
	                        ,SUM(CASE WHEN index_id = 1 THEN 1 ELSE 0 END) HasClusteredIndex
	                        ,SUM(CASE WHEN index_id > 1 THEN 1 ELSE 0 END) NonClusteredIndexCount
                        FROM
	                        sys.indexes
                        WHERE
	                        index_id >= 1
                        GROUP BY
	                         object_id
                    )IxsDt
                ON
                    obj.object_id = IxsDt.object_id
                LEFT JOIN
                    sys.partitions part
                ON	
                    obj.object_id = part.object_id
                AND
                    part.index_id <= 1
                LEFT JOIN
                    (
                        SELECT
	                         object_id
	                        ,COUNT(DISTINCT partition_number) PartitionCount
	                        ,MAX(CASE WHEN data_compression > 0 THEN 1 ELSE 0 END) HasCompressedPartitions
                        FROM
	                        sys.partitions
                        GROUP BY
	                        object_id
                    )PartDt
                ON
                    obj.object_id = PartDt.object_id
                --LEFT JOIN
                --	(
                --		SELECT
                --			 object_id
                --			,COUNT(*) ColumnCount
                --		FROM
                --			sys.columns 
                --		GROUP BY
                --			 object_id
                --	)Cols
                --ON
                --	obj.object_id = Cols.object_id
                LEFT JOIN
                    (
                        SELECT
	                         parent_object_id
	                        ,COUNT(*) TriggerCount
                        FROM
	                        sys.objects
                        WHERE
	                        type = ''TR''
                        GROUP BY
	                        parent_object_id
                    )Trig
                ON
                    obj.object_id = Trig.parent_object_id
                LEFT JOIN
                    (
                        SELECT 
	                         referenced_object_id
	                        ,COUNT(*) ForeignKeyCount
                        FROM 
	                        sys.foreign_keys
                        GROUP BY
	                         referenced_object_id
                    )FKs
                ON
                    obj.object_id = FKs.referenced_object_id
                LEFT JOIN
                    Cte
                ON	
                    obj.object_id = cte.object_id
                WHERE
                    obj.type = ''U'';'
            WHILE (1=1)
            BEGIN 
	            SELECT 
		            @DBID = MIN(database_id)
	            FROM
		            sys.databases
	            WHERE
		            database_id > @DBID
	            AND
		            name <> 'tempdb';
	            SELECT @DBNAME = DB_NAME(@DBID) ;
	            SELECT @Newsql = REPLACE(@sql,'DBNAME',@DBNAME)
	            IF (@DBID IS NULL)
		            BEGIN
			            BREAK
		            END
		            INSERT INTO #temptable
			            (
				            ComputerName
				            ,InstanceName
				            ,SQLInstance
				            ,DatabaseName
				            ,TableObjectID
				            ,SchemaName
				            ,TableName
				            ,FileGroupName
				            ,CreateDate
				            ,DateLastModified
				            ,TableRowCount
				            ,IndexCount
				            ,ColumnCount
				            ,TriggerCount
				            ,PartitionCount
				            ,ForeignKeyCount
				            ,TableSizeMB
				            ,TableSpaceUsedMB
				            ,IndexSizeMB
				            ,IndexSpaceUsedMB
				            ,HasClusteredIndex
				            ,isChangeTrackingEnabled
				            ,isReplicatedf
				            ,NonClusteredIndexCount
			            )

		            EXEC sys.sp_executesql @Newsql
	            END
            SELECT
	            ComputerName
               ,InstanceName
               ,SQLInstance
               ,DatabaseName
               ,TableObjectID
               ,SchemaName
               ,TableName
               ,FileGroupName
               ,CreateDate
               ,DateLastModified
               ,TableRowCount
               ,IndexCount
               ,ColumnCount
               ,TriggerCount
               ,PartitionCount
               ,ForeignKeyCount
               ,TableSizeMB
               ,TableSpaceUsedMB
               ,IndexSizeMB
               ,IndexSpaceUsedMB
               ,HasClusteredIndex
               ,isChangeTrackingEnabled
               ,isReplicatedf
               ,NonClusteredIndexCount
            FROM
	            #temptable
            "
            $LoggingGUID = New-Guid
            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1            
               

            $oUT = Invoke-DbaQuery -SqlInstance $SQLInstance -Query $SQLQuery # |  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable   -FireTriggers

            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0            
           
            $oUT |  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable   -FireTriggers
           
            REMOVE-VARIABLE SQLQuery 
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE LoggingGUID

    };

FUNCTION Write-SQLMonitoringIndexInformation
    {
        PARAM
            (
                  [STRING] $SQLInstance   
                 ,[SWITCH] $GetIndexInformation
            )
            
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "IndexUsageStats"
            $StartDateTime           = (get-date)            
            $ParentTask              =   "$TargetTable"
            $Databases               = Get-DbaDatabase -SqlInstance $SQLInstance -ExcludeDatabase tempdb, modeldb |Select-Object Name
            $TaskName                =   "$SQLInstance - Fragmentation - $TargetTable"
            $Query                   = "
                            SET NOCOUNT ON;
                            SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                            DECLARE @IncludeDataTypes BIT = ?;
                            DECLARE @IncludeIndexFragmentation BIT = ? --- here
                            IF OBJECT_ID('TempDB..#IndexUsageStats','U')		IS NOT NULL  DROP TABLE #IndexUsageStats;
                            IF OBJECT_ID('TempDB..#IndexInformation','U')		IS NOT NULL DROP TABLE #IndexInformation;
                            IF OBJECT_ID('TempDB..#StatsInfo','U')				IS NOT NULL  DROP TABLE #StatsInfo;
                            IF OBJECT_ID('TempDB..#StatsInfoSummary','U')		IS NOT NULL  DROP TABLE #StatsInfoSummary;

                            CREATE TABLE #IndexUsageStats
                                (
                                     object_id                     INT
                                    ,index_id                     INT
                                    ,user_scans                   BIGINT
                                    ,user_seeks                   BIGINT
                                    ,user_updates                 BIGINT
                                    ,user_lookups                 BIGINT
                                    ,last_user_lookup             DATETIME2(0)
                                    ,last_user_scan               DATETIME2(0)
                                    ,last_user_seek               DATETIME2(0)
		                            ,last_user_update             DATETIME2(0)
                                    ,avg_fragmentation_in_percent FLOAT
		                            ,ContainsFragmentation			BIT
                                );
                            CREATE TABLE #StatsInfo
                                (
                                     object_id           INT
                                    ,stats_id           INT
                                    ,stats_column_name  NVARCHAR(128)
                                    ,stats_column_id    INT
                                    ,stats_name         NVARCHAR(128)
                                    ,stats_last_updated DATETIME2(0)
                                    ,stats_sampled_rows BIGINT
                                    ,rowmods            BIGINT
                                    ,histogramsteps     INT
                                    ,StatsRows          BIGINT
                                    ,FullObjectName     NVARCHAR(256)
                                );
                            CREATE TABLE #IndexInformation
                                (
                                    [ObjectName]                    NVARCHAR(128)
                                    ,[object_id]                    INT
                                    ,[index_id]                     INT
                                    ,[name]                         NVARCHAR(1055)
                                    ,[index_column_id]              INT
                                    ,[column_id]                    INT
                                    ,[is_included_column]           BIT
                                    ,[ColumnName]                   NVARCHAR(1055)
                                    ,[filter_definition]            NVARCHAR(MAX)
                                    ,[user_scans]                   BIGINT
                                    ,[user_seeks]                   BIGINT
                                    ,[user_updates]                 BIGINT
                                    ,[user_lookups]                 BIGINT
                                    ,[LastLookup]                   DATETIME2(0)
                                    ,[LastScan]                     DATETIME2(0)
                                    ,[LastSeek]                     DATETIME2(0)
		                            ,[LastUpdate]                   DATETIME2(0)
                                    ,[fill_factor]                  TINYINT
                                    ,[is_descending_key]            BIT
                                    ,[data_compression_desc]        NVARCHAR(MAX)
                                    ,[type_desc]                    NVARCHAR(MAX)
                                    ,[is_unique]                    BIT
                                    ,[is_unique_constraint]         BIT
                                    ,[is_primary_key]               BIT
                                    ,[SizeKB]                       BIGINT
                                    ,[IndexRows]                    BIGINT
                                    ,[FullObjectName]               NVARCHAR(MAX)
                                    ,[avg_fragmentation_in_percent] FLOAT(8)
		                            ,ContainsFragmentation			BIT
		
                                );
                            CREATE TABLE #StatsInfoSummary
                                (
                                     [object_id]         INT
                                    ,[stats_id]         INT
                                    ,[stats_name]       NVARCHAR(MAX)
                                    ,[StatsColumns]     NVARCHAR(MAX)
                                    ,[SampleRows]       BIGINT
                                    ,[RowMods]          BIGINT
                                    ,[HistogramSteps]   INT
                                    ,[StatsLastUpdated] DATETIME2(0)
                                    ,[StatsRows]        BIGINT
                                    ,[FullObjectName]   NVARCHAR(256)
                                );

                            IF @IncludeIndexFragmentation = 1
	                            BEGIN
		                            INSERT INTO #IndexUsageStats
			                            (
				                            object_id
				                            ,index_id
				                            ,user_scans
				                            ,user_seeks
				                            ,user_updates
				                            ,user_lookups
				                            ,last_user_lookup
				                            ,last_user_scan
				                            ,last_user_seek
				                            ,last_user_update
				                            ,avg_fragmentation_in_percent
				                            ,ContainsFragmentation
			                            )
		                            SELECT
			                             ustat.object_id
			                            ,ustat.index_id
			                            ,ustat.user_scans
			                            ,ustat.user_seeks
			                            ,ustat.user_updates
			                            ,ustat.user_lookups
			                            ,ustat.last_user_lookup
			                            ,ustat.last_user_scan
			                            ,ustat.last_user_seek
			                            ,ustat.last_user_update
			                            , pstat.avg_fragmentation_in_percent avg_fragmentation_in_percent
			                            ,1 ContainsFragmentation
		                            FROM
			                            sys.dm_db_index_usage_stats ustat
		                              --          LEFT JOIN
		                            --	            sys.indexes pstat
		                            --            ON 
		                            --	            pstat.object_id = ustat.object_id
		                            --            AND 
		                            --	            pstat.index_id = ustat.index_id
		                            LEFT JOIN
			                            sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL , 'detailed') pstat
		                            ON pstat.database_id = ustat.database_id
		                             AND pstat.object_id = ustat.object_id
		                             AND pstat.index_id = ustat.index_id
		                            WHERE
			                            ustat.database_id = DB_ID()
	                            END
                            ELSE                    
	                            BEGIN
		                            INSERT INTO #IndexUsageStats
			                            (
				                            object_id
				                            ,index_id
				                            ,user_scans
				                            ,user_seeks
				                            ,user_updates
				                            ,user_lookups
				                            ,last_user_lookup
				                            ,last_user_scan
				                            ,last_user_seek
				                            ,last_user_update
				                            ,avg_fragmentation_in_percent
				                            ,ContainsFragmentation
			                            )
		                            SELECT
			                             ustat.object_id
			                            ,ustat.index_id
			                            ,ustat.user_scans
			                            ,ustat.user_seeks
			                            ,ustat.user_updates
			                            ,ustat.user_lookups
			                            ,ustat.last_user_lookup
			                            ,ustat.last_user_scan
			                            ,ustat.last_user_seek
			                            ,ustat.last_user_update
			                            , NULL avg_fragmentation_in_percent
			                            ,0 ContainsFragmentation
		                            FROM
			                            sys.dm_db_index_usage_stats ustat
		                                      LEFT JOIN
		                                        sys.indexes pstat
		                                      ON 
		                                        pstat.object_id = ustat.object_id
		                                      AND 
		                                        pstat.index_id = ustat.index_id
		                            WHERE
			                            ustat.database_id = DB_ID()
	                            END
                            ;WITH cteIndexSizes
                            AS ( SELECT   object_id ,
                                            index_id ,
                                            CASE WHEN index_id < 2
                                                THEN ( ( SUM(in_row_data_page_count
                                                            + lob_used_page_count
                                                            + row_overflow_used_page_count)
                                                        * 8192 ) / 1024 )
                                                else ( ( SUM(used_page_count) * 8192 ) / 1024 )
                                            END AS SizeKB
                                FROM     sys.dm_db_partition_stats
                                GROUP BY object_id ,
                                            index_id
                                ),
                            cteRows
                            AS ( SELECT   object_id ,
                                            index_id ,
                                            SUM(rows) AS IndexRows
                                FROM     sys.partitions
                                GROUP BY object_id ,
                                            index_id
                                )
                            INSERT INTO #IndexInformation
                                (
                                    ObjectName
                                    ,object_id
                                    ,index_id
                                    ,name
                                    ,index_column_id
                                    ,column_id
                                    ,is_included_column
                                    ,ColumnName
                                    ,filter_definition
                                    ,user_scans
                                    ,user_seeks
                                    ,user_updates
                                    ,user_lookups
                                    ,LastLookup
                                    ,LastScan
                                    ,LastSeek
		                            ,LastUpdate
                                    ,fill_factor
                                    ,is_descending_key
                                    ,data_compression_desc
                                    ,type_desc
                                    ,is_unique
                                    ,is_unique_constraint
                                    ,is_primary_key
                                    ,SizeKB
                                    ,IndexRows
                                    ,FullObjectName
                                    ,avg_fragmentation_in_percent
		                            ,ContainsFragmentation			
                                )
                            SELECT
                                    OBJECT_NAME(c.object_id)                                          AS ObjectName
                                    ,c.object_id
                                    ,c.index_id
                                    ,i.name COLLATE SQL_Latin1_General_CP1_CI_AS                      AS name
                                    ,c.index_column_id
                                    ,c.column_id
                                    ,c.is_included_column
                                    ,CASE
                                         WHEN @IncludeDataTypes = 0
                                              AND c.is_descending_key = 1
                                             THEN
                                             sc.name + ' DESC'
                                         WHEN @IncludeDataTypes = 0
                                              AND c.is_descending_key = 0
                                             THEN
                                             sc.name
                                         WHEN @IncludeDataTypes = 1
                                              AND c.is_descending_key = 1
                                              AND c.is_included_column = 0
                                             THEN
                                             sc.name + ' DESC (' + t.name + ') '
                                         WHEN @IncludeDataTypes = 1
                                              AND c.is_descending_key = 0
                                              AND c.is_included_column = 0
                                             THEN
                                             sc.name + ' (' + t.name + ')'
                                         ELSE
                                             sc.name
                                     END                                                              AS ColumnName
                                    ,i.filter_definition
                                    ,ISNULL(dd.user_scans, 0)                                         AS user_scans
                                    ,ISNULL(dd.user_seeks, 0)                                         AS user_seeks
                                    ,ISNULL(dd.user_updates, 0)                                       AS user_updates
                                    ,ISNULL(dd.user_lookups, 0)                                       AS user_lookups
                                    ,CONVERT(DATETIME2(0), ISNULL(dd.last_user_lookup, '1901-01-01')) AS LastLookup
                                    ,CONVERT(DATETIME2(0), ISNULL(dd.last_user_scan, '1901-01-01'))   AS LastScan
                                    ,CONVERT(DATETIME2(0), ISNULL(dd.last_user_seek, '1901-01-01'))   AS LastSeek
		                            ,CONVERT(DATETIME2(0), ISNULL(dd.last_user_update, '1901-01-01'))   AS LastUpdate
                                    ,i.fill_factor
                                    ,c.is_descending_key
                                    ,p.data_compression_desc
                                    ,i.type_desc
                                    ,i.is_unique
                                    ,i.is_unique_constraint
                                    ,i.is_primary_key
                                    ,ci.SizeKB
                                    ,cr.IndexRows
                                    ,QUOTENAME(sch.name) + '.' + QUOTENAME(tbl.name)                  AS FullObjectName
                                    ,ISNULL(dd.avg_fragmentation_in_percent, 0)                       AS avg_fragmentation_in_percent
		                            ,ContainsFragmentation		 
                            FROM
                                sys.indexes       i
                            JOIN
                                sys.index_columns c
                                    ON i.object_id = c.object_id
                                       AND i.index_id = c.index_id
                            JOIN
                                sys.columns       sc
                                    ON c.object_id = sc.object_id
                                       AND c.column_id = sc.column_id
                            INNER JOIN
                                sys.tables        tbl
                                    ON c.object_id = tbl.object_id
                            INNER JOIN
                                sys.schemas       sch
                                    ON sch.schema_id = tbl.schema_id
                            LEFT JOIN
                                sys.types         t
                                    ON sc.user_type_id = t.user_type_id
                            LEFT JOIN
                                #IndexUsageStats  dd
                                    ON i.object_id = dd.object_id
                                       AND i.index_id = dd.index_id --and dd.database_id = db_id()
                            JOIN
                                sys.partitions    p
                                    ON i.object_id = p.object_id
                                       AND i.index_id = p.index_id
                            JOIN
                                cteIndexSizes     ci
                                    ON i.object_id = ci.object_id
                                       AND i.index_id = ci.index_id
                            JOIN
                                cteRows           cr
                                    ON i.object_id = cr.object_id
                                       AND i.index_id = cr.index_id;

                            SELECT
                                 DB_NAME() + '.' + ci.FullObjectName  FullObjectName
	                            ,SERVERPROPERTY('MachineName') ComputerName
	                            ,@@SERVICENAME InstanceName
	                            ,@@SERVERNAME SQLInstance       
                                ,DB_NAME() [Database]
	                            --,HASHBYTES('SHA2_256',DB_NAME() + '.' + ci.FullObjectName + CAST(ci.object_id AS VARCHAR))
                                --,
                                ,ci.object_id ObjectID
                                ,MAX(index_id)                                                  AS IndexID
                                ,ci.type_desc + CASE
                                                    WHEN ci.is_primary_key = 1
                                                        THEN
                                                        ' (PRIMARY KEY)'
                                                    WHEN ci.is_unique_constraint = 1
                                                        THEN
                                                        ' (UNIQUE CONSTRAINT)'
                                                    WHEN ci.is_unique = 1
                                                        THEN
                                                        ' (UNIQUE)'
                                                    ELSE
                                                        ''
                                                END                                             AS IndexType
                                ,name                                                           AS IndexName
                                ,STUFF((
                                           SELECT
                                               N', ' + ColumnName
                                           FROM
                                               #IndexInformation ci2
                                           WHERE
                                               ci2.name = ci.name
                                               AND ci2.is_included_column = 0
                                           GROUP BY
                                               ci2.index_column_id
                                               ,ci2.ColumnName
                                           ORDER BY
                                               ci2.index_column_id
                                           FOR XML PATH(N''), TYPE
                                       ).value(N'.[1]', N'nvarchar(1000)'), 1, 2, N''
                                      )                                                         AS KeyColumns
                                ,ISNULL(STUFF((
                                                  SELECT
                                                      N',  ' + ColumnName
                                                  FROM
                                                      #IndexInformation ci3
                                                  WHERE
                                                      ci3.name = ci.name
                                                      AND ci3.is_included_column = 1
                                                  GROUP BY
                                                      ci3.index_column_id
                                                      ,ci3.ColumnName
                                                  ORDER BY
                                                      ci3.index_column_id
                                                  FOR XML PATH(N''), TYPE
                                              ).value(N'.[1]', N'nvarchar(1000)'), 1, 2, N''
                                             ), ''
                                       )                                                        AS IncludeColumns
                                ,ISNULL(filter_definition, '')                                  AS FilterDefinition
                                ,ci.fill_factor FillFactorPerc
                                ,CASE
                                     WHEN ci.data_compression_desc = 'NONE'
                                         THEN
                                         ''
                                     ELSE
                                         ci.data_compression_desc
                                 END                                                            AS DataCompression
	                            ,MAX(ci.user_seeks)	IndexSeeks
	                            ,MAX(ci.user_scans) IndexScans
                                ,MAX(ci.user_lookups)                                           AS IndexLookups
                                ,ci.user_updates                                                AS IndexUpdates
                                ,ci.SizeKB                                                      AS SizeKB
                                ,ci.IndexRows                                                   AS IndexRows
                                ,LastSeek
	                            ,LastScan 
	                            ,LastLookup
	                            ,LastUpdate
                                ,AVG(ci.avg_fragmentation_in_percent)                           FragmentationPercent
	                            ,SYSDATETIME() CollectionDateTime
	                            ,ISNULL(ContainsFragmentation,0)ContainsFragmentation
                            FROM
                                #IndexInformation ci
                            GROUP BY
                                ci.ObjectName
                                ,ci.name
                                ,ci.filter_definition
                                ,ci.object_id
                                ,ci.LastLookup
                                ,ci.LastSeek
                                ,ci.LastScan
                                ,ci.user_updates
                                ,ci.fill_factor
                                ,ci.data_compression_desc
                                ,ci.type_desc
                                ,ci.is_primary_key
                                ,ci.is_unique
                                ,ci.is_unique_constraint
                                ,ci.SizeKB
                                ,ci.IndexRows
                                ,ci.FullObjectName
	                            ,LastUpdate
	                            ,ContainsFragmentation;
            "


            
            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1            
            if ((((get-date).Hour -eq 20) -and ((get-date).minute -le 29)) -or $GetIndexInformation)                
                {
                    $QueryToExecute        =   $Query.Replace("?","1")
                    $InnerTaskName         =   "$SQLInstance - $DB.Name - Fragmentation - $TargetTable"
                }
            else
                {
                    $QueryToExecute        =   $Query.Replace("?","0")
                    $InnerTaskName         =   "$SQLInstance - $DB.Name - No Fragmentation - $TargetTable"
                }
            $Out = 
            foreach ($Db in $Databases)
            {
            $InnerStartDateTime    = (get-date)
            $InnerLoggingGUID      = New-Guid
                        Write-SQLMonitoringLoggingTable   -TaskName $InnerTaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $DB.Name -StartDateTime $InnerStartDateTime  -LoggingGUID $InnerLoggingGUID -InitialLog 1
                        Invoke-DbaQuery -SqlInstance $SQLInstance -Database $Db.name -query $QueryToExecute | Select-Object CollectionDateTime	,ComputerName	,InstanceName	, @{Name ="SqlInstance" ; Expression={$_.SQLInstance}}, @{Name ="DatabaseName" ; Expression={$_.Database}} 	,FullObjectName  ,ObjectID ,IndexID         ,IndexType       ,IndexName       ,KeyColumns      ,IncludeColumns  ,FilterDefinition,FillFactorPerc  ,DataCompression ,IndexSeeks,IndexScans,IndexLookups,IndexUpdates,SizeKB,IndexRows,LastSeek,LastScan,LastLookup,LastUpdate,FragmentationPercent,ContainsFragmentation			
                        Write-SQLMonitoringLoggingTable   -TaskName $InnerTaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $DB.Name -StartDateTime $InnerStartDateTime -EndDateTime (Get-Date) -LoggingGUID $InnerLoggingGUID -InitialLog 0
            }

            
            $Out | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0                            
            Remove-Variable Out
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE Databases    
            REMOVE-VARIABLE TaskName   
            REMOVE-VARIABLE LoggingGUID        
            REMOVE-VARIABLE InnerStartDateTime    
            REMOVE-VARIABLE InnerLoggingGUID
            REMOVE-VARIABLE SQLInstance   
            REMOVE-VARIABLE GetIndexInformation      
            REMOVE-VARIABLE Query
            REMOVE-VARIABLE QueryToExecute
            REMOVE-VARIABLE InnerTaskName 
    };    


FUNCTION Write-SQLMonitoringDatabaseInformation
    {
        PARAM
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "DatabaseInformation"
            $StartDateTime           = (get-date)
            $TaskName                =   "$SQLInstance - $TargetTable"
            $ParentTask              =   "$TargetTable"
            $LoggingGUID             = New-Guid
            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1

            Get-DbaDatabase -SqlInstance $SQLInstance | Select-Object ComputerName, InstanceName, SqlInstance, @{Name ="DatabaseName"; Expression={$_.Name}}, @{Name ="DatabaseID"; Expression={$_.ID}}, CreateDate, DatabaseGuid, RecoveryForkGuid,  @{Name ="DatabaseOwner"; Expression={$_.Owner}}, Collation, CompatibilityLevel, AvailabilityGroupName, `
                UserAccess,LastRead,LastWrite, LastBackupDate, LastDifferentialBackupDate, LastGoodCheckDbTime, PageVerify, RecoveryModel, ReplicationOptions, ContainmentType, TargetRecoveryTime, @{Name ="Certificates"; Expression={$_.Certificates.GetEnumerator()}}, @{Name ="ColumnMasterKeys"; Expression={$_.ColumnMasterKeys.GetEnumerator()}}, @{Name ="ColumnEncryptionKeys"; Expression={$_.ColumnEncryptionKeys.GetEnumerator()}}, @{Name ="SymmetricKeys"; Expression={$_.SymmetricKeys.GetEnumerator()}} `
                , @{Name ="AsymmetricKeys"; Expression={$_.AsymmetricKeys.GetEnumerator()}}, @{Name ="Users"; Expression={$_.Users.GetEnumerator()}}, @{Name ="Schemas"; Expression={$_.Schemas.GetEnumerator()}}, @{Name ="Roles"; Expression={$_.Roles.GetEnumerator()}}, @{Name ="FileGroups"; Expression={$_.FileGroups.GetEnumerator()}} `
                , @{Name ="MasterKey"; Expression={$_.MasterKey.GetEnumerator()}}, @{Name ="Triggers"; Expression={$_.Triggers.GetEnumerator()}},AutoCreateIncrementalStatisticsEnabled, AutoCreateStatisticsEnabled, AutoUpdateStatisticsAsync, AutoUpdateStatisticsEnabled, CaseSensitive, ChangeTrackingEnabled, EncryptionEnabled `
                | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 1

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE LoggingGUID
            REMOVE-VARIABLE SQLInstance             
    };
FUNCTION Write-SQLMonitoringNetworkLatency
    {
        PARAM
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "NetworkLatency"
            $StartDateTime           = (get-date)
            $TaskName                =   "$SQLInstance - $TargetTable"
            $ParentTask              =   "$TargetTable"
            $LoggingGUID             = New-Guid
            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         
         
                 Test-DbaNetworkLatency -SqlInstance $SQLInstance | Select-Object ComputerName ,InstanceName ,SqlInstance , @{Name ="NetworkLatencyCount" ; Expression={$_.Count}}, @{Name ="NetworkLatencyTotal" ; Expression={$_.Total}} , @{Name ="NetworkLatencyAverage" ; Expression={$_.Avg}} ,ExecuteOnlyTotal ,ExecuteOnlyAvg ,NetworkOnlyTotal ,ExecutionCount , @{Name ="AverageLatency" ; Expression={$_.Average}}  ,ExecuteOnlyAverage, @{Name ="AddedDateTime" ; Expression={Get-Date}}	 `
                 | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            Remove-Variable MonitoringServerDetails 
            Remove-Variable TargetServerInstance    
            Remove-Variable TargetDatabase          
            Remove-Variable TargetSchema            
            Remove-Variable TargetTable             
            Remove-Variable StartDateTime           
            Remove-Variable TaskName                
            Remove-Variable ParentTask              
            Remove-Variable LoggingGUID
            Remove-Variable SQLInstance
    };
FUNCTION Write-SQLMonitoringReplicationLatency
    {
        PARAM
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "ReplicationLatency"
            $StartDateTime           = (get-date)
            $TaskName                =   "$SQLInstance - $TargetTable"
            $ParentTask              =   "$TargetTable"
            $LoggingGUID             = New-Guid
            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         
         
            Test-DbaRepLatency -SqlInstance DBS-01 | Select-Object ComputerName, InstanceName, SqlInstance, PublicationServer, PublicationDB, PublicationName, PublicationType, DistributionServer, DistributionDB, SubscriberServer, SubscriberDB, TokenCreateDate, PublisherToDistributorLatency, DistributorToSubscriberLatency, TotalLatency `
                 | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE LoggingGUID
            REMOVE-VARIABLE SQLInstance             
    };

FUNCTION Write-SQLMonitoringConfigurationOptions
    {
        PARAM
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "ConfigurationOptions"
            $StartDateTime           = (get-date)
            $TaskName                =   "$SQLInstance - $TargetTable"
            $ParentTask              =   "$TargetTable"
            $LoggingGUID             = New-Guid

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         

            Get-DbaSpConfigure -SqlInstance $SQLInstance | Select-object ComputerName, InstanceName, SqlInstance, ConfiguredValue, @{Name ="ConfigurationName"; Expression={$_.Name}}, @{Name ="ConfigurationDescription"; Expression={$_.Description}}, DisplayName, IsAdvanced, IsRunningDefaultValue, RunningValue, MaxValue, MinValue, DefaultValue `
            |Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                         

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE LoggingGUID
            REMOVE-VARIABLE SQLInstance
    };

FUNCTION Write-SQLMonitoringComputerList
    {
        PARAM
            (
                 [STRING] $ComputerName     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "ComputerList"
            $StartDateTime           = (get-date)
            $TaskName                =   "$SQLInstance - $TargetTable"
            $ParentTask              =   "$TargetTable"
            $LoggingGUID             = New-Guid

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         

            $ComputerSystem  = Get-DbaComputerSystem  -ComputerName $ComputerName  | Select-object ComputerName, Model, Manufacturer, SystemType, Architecture, @{Name ="VersionNumber" ; Expression={$_.Version}}, OSVersion, ActivePowerPlan, IsHyperThreading, IsSystemManagedPageFile,  @{Name ="TotalPhysicalMemory" ; Expression={$_.TotalPhysicalMemory}}, NumberLogicalProcessors, NumberProcessors, ProcessorCaption, ProcessorName, ProcessorMaxClockSpeed, AddedDateTime				
            $OperatingSystem = Get-DbaOperatingSystem -ComputerName $ComputerName  | Select-object ComputerName, Model, Manufacturer, SystemType, Architecture, @{Name ="VersionNumber" ; Expression={$_.Version}}, OSVersion, ActivePowerPlan, IsHyperThreading, IsSystemManagedPageFile,  @{Name ="TotalPhysicalMemory" ; Expression={$_.TotalPhysicalMemory}}, NumberLogicalProcessors, NumberProcessors, ProcessorCaption, ProcessorName, ProcessorMaxClockSpeed, AddedDateTime				
            $ComputerSystem.Architecture    = $OperatingSystem.Architecture    
            $ComputerSystem.VersionNumber   = $OperatingSystem.VersionNumber   
            $ComputerSystem.OSVersion       = $OperatingSystem.OSVersion       
            $ComputerSystem.ActivePowerPlan = $OperatingSystem.ActivePowerPlan 
            $ComputerSystem.AddedDateTime   = (get-date)
            
            $ComputerSystem |Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers                

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE LoggingGUID
            REMOVE-VARIABLE ComputerName             
    };
FUNCTION Write-SQLMonitoringQueryStats
    {
        PARAM
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "QueryStats"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $LoggingGUID             = New-Guid

            $SQLQuery                = 
            "
                SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
                ;WITH CTE AS
	                (
		                SELECT TOP 100
			                sql_handle              SqlHandle
			                ,statement_start_offset StatementStartOffset
			                ,statement_end_offset   StatementEndOffset
			                ,plan_generation_num    PlanGenerationNum
			                ,plan_handle            PlanHandle
			                ,creation_time          CreationTime
			                ,last_execution_time    LastExecutionTime
			                ,execution_count        ExecutionCount
			                ,total_worker_time      TotalWorkerTime
			                ,last_worker_time       LastWorkerTime
			                ,min_worker_time        MinWorkerTime
			                ,max_worker_time        MaxWorkerTime
			                ,total_physical_reads   TotalPhysicalReads
			                ,last_physical_reads    LastPhysicalReads
			                ,min_physical_reads     MinPhysicalReads
			                ,max_physical_reads     MaxPhysicalReads
			                ,total_logical_writes   TotalLogicalWrites
			                ,last_logical_writes    LastLogicalWrites
			                ,min_logical_writes     MinLogicalWrites
			                ,max_logical_writes     MaxLogicalWrites
			                ,total_logical_reads    TotalLogicalReads
			                ,last_logical_reads     LastLogicalReads
			                ,min_logical_reads      MinLogicalReads
			                ,max_logical_reads      MaxLogicalReads
			                ,total_elapsed_time     TotalElapsedTime
			                ,last_elapsed_time      LastElapsedTime
			                ,min_elapsed_time       MinElapsedTime
			                ,max_elapsed_time       MaxElapsedTime
			                ,query_hash             QueryHash
			                ,query_plan_hash        QueryPlanHash
			                ,total_rows             TotalRows
			                ,last_rows              LastRows
			                ,min_rows               MinRows
			                ,max_rows               MaxRows
			                ,total_dop              TotalDop
			                ,last_dop               LastDop
			                ,min_dop                MinDop
			                ,max_dop                MaxDop
			                ,total_grant_kb         TotalGrantKb
			                ,last_grant_kb          LastGrantKb
			                ,min_grant_kb           MinGrantKb
			                ,max_grant_kb           MaxGrantKb
			                ,total_used_grant_kb    TotalUsedGrantKb
			                ,last_used_grant_kb     LastUsedGrantKb
			                ,min_used_grant_kb      MinUsedGrantKb
			                ,max_used_grant_kb      MaxUsedGrantKb
			                ,total_ideal_grant_kb   TotalIdealGrantKb
			                ,total_used_threads     TotalUsedThreads
			                ,last_used_threads      LastUsedThreads
			                ,min_used_threads       MinUsedThreads
			                ,max_used_threads       MaxUsedThreads
			                ,statement_end_offset
			                ,statement_start_offset
			                ,sql_handle
			                ,plan_handle
		                FROM
			                sys.dm_exec_query_stats
		                ORDER BY 
			                (Total_Worker_Time + Total_Logical_Writes + Total_Logical_Reads) DESC

	                )
                SELECT
	                 SERVERPROPERTY('ComputerNamePhysicalNetBIOS')ComputerName		 
	                ,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName        
	                ,@@SERVERNAME SqlInstance         
	                ,ROW_NUMBER()OVER(ORDER BY (Cte.TotalWorkerTime + Cte.TotalLogicalWrites + Cte.TotalLogicalReads) DESC) ExpensiveQueryNumber
	                ,CreationTime        
	                ,LastExecutionTime   
	                ,ExecutionCount      
	                ,TotalWorkerTime     
	                ,LastWorkerTime      
	                ,MinWorkerTime       
	                ,MaxWorkerTime       
	                ,TotalPhysicalReads  
	                ,LastPhysicalReads   
	                ,MinPhysicalReads    
	                ,MaxPhysicalReads    
	                ,TotalLogicalWrites  
	                ,LastLogicalWrites   
	                ,MinLogicalWrites    
	                ,MaxLogicalWrites    
	                ,TotalLogicalReads   
	                ,LastLogicalReads    
	                ,MinLogicalReads     
	                ,MaxLogicalReads     
	                ,TotalElapsedTime    
	                ,LastElapsedTime     
	                ,MinElapsedTime      
	                ,MaxElapsedTime      
	                ,TotalRows           
	                ,LastRows            
	                ,MinRows             
	                ,MaxRows             
	                ,TotalDop            
	                ,LastDop             
	                ,MinDop              
	                ,MaxDop              
	                ,TotalGrantKb        
	                ,LastGrantKb         
	                ,MinGrantKb          
	                ,MaxGrantKb          
	                ,TotalUsedGrantKb    
	                ,LastUsedGrantKb     
	                ,MinUsedGrantKb      
	                ,MaxUsedGrantKb      
	                ,TotalIdealGrantKb   
	                ,TotalUsedThreads    
	                ,LastUsedThreads     
	                ,MinUsedThreads      
	                ,MaxUsedThreads      
	                ,SYSDATETIME() AddedDateTime		 
	                ,1 isMostCurrent	
	                ,qp.query_plan QueryPlan
	                ,SUBSTRING(qt.text, (Cte.statement_start_offset / 2) + 1, ((CASE Cte.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text) ELSE Cte.statement_end_offset END - Cte.statement_start_offset) / 2) + 1) QueryText
	                ,UPPER(DB_NAME(ProcStats.database_id) + '.' + OBJECT_SCHEMA_NAME(ProcStats.object_id,ProcStats.database_id) + '.' + OBJECT_NAME(ProcStats.object_id,ProcStats.database_id))		  ProcName
                FROM
	                Cte
                LEFT JOIN
	                sys.dm_exec_procedure_stats ProcStats
                ON
	                Cte.sql_handle = ProcStats.sql_handle
                OUTER APPLY 
	                sys.dm_exec_sql_text(Cte.sql_handle) qt
                OUTER APPLY 
	                sys.dm_exec_query_plan(Cte.plan_handle) qp
                ORDER BY 
	                (Cte.TotalWorkerTime + Cte.TotalLogicalWrites + Cte.TotalLogicalReads) DESC
            "

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         

            $Output  = Invoke-DbaQuery -SqlInstance $SQLInstance  -Query $SQLQuery
            $Output |  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable   -FireTriggers

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE LoggingGUID             
            REMOVE-VARIABLE SQLQuery                
            REMOVE-VARIABLE Output
            REMOVE-VARIABLE SQLInstance   
    };
FUNCTION Write-SQLMonitoringExecutingQueries
    {
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "ExecutingQueries"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $List                    = Get-SQLMonitoringServerList -InstanceRole PROD -InstanceType 'ALL' | Select-Object SQLInstance
            $LoggingGUID             = New-Guid
            $SQLQuery                = 
            "
                SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                SELECT
                    SERVERPROPERTY('ComputerNamePhysicalNetBIOS')ComputerName
                   ,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName        
                   ,@@SERVERNAME SqlInstance   		
                   ,req.session_id					SessionID
                   ,req.request_id					RequestID
                   ,Conn.connection_id				ConnectionID
                   ,req.start_time					StartTime
                   ,req.status                      Status
                   ,req.command						Command
                   ,req.user_id						UserID
                   ,req.blocking_session_id			BlockingSessionID
                   ,req.wait_time					WaitTime
                   ,req.wait_type					WaitType
                   ,req.last_wait_type				LastWaitType
                   ,req.open_transaction_count		OpenTransactionCount
                   ,req.percent_complete			PercentComplete
                   ,req.cpu_time					CpuTime
                   ,req.total_elapsed_time			totalElapsedTime
                   ,req.reads						Reads
                   ,req.writes						Writes
                   ,req.logical_reads				LogicalReads
                   ,sess.login_time					LoginTime
                   ,sess.host_name					HostName
                   ,sess.program_name				ProgramName
                   ,sess.host_process_id			HostProcessID
                   ,sess.client_version				ClientVersion
                   ,sess.client_interface_name		ClientInterfaceName
                   ,sess.login_name					LoginName
                   ,sess.nt_domain					ntDomain
                   ,sess.nt_user_name				ntUserName
                   --,CAST(req.query_plan_hash as varchar)	 QueryPlanHash
                   ,SYSDATETIME() CollectionDateTime
                   ,st.text  QueryText
                   ,qp.query_plan QueryPlan
		           ,CASE WHEN st.text       IS NOT NULL THEN CHECKSUM(CAST(st.text       AS VARCHAR(MAX))) ELSE -1854252673 END ChecksumQueryText
		           ,CASE WHEN qp.query_plan IS NOT NULL THEN CHECKSUM(CAST(qp.query_plan AS VARCHAR(MAX))) ELSE -1854252673 END ChecksumQueryPlan
                   ,req.database_id                 Database_ID
                FROM
                       sys.dm_exec_requests req
                JOIN
                       sys.dm_exec_sessions sess
                ON
                       req.session_id = sess.session_id
                OUTER APPLY 
                	sys.dm_exec_sql_text(req.sql_handle) as st 
                OUTER APPLY 
                	sys.dm_exec_query_plan(req.plan_handle)   qp
                LEFT JOIN
                	sys.dm_exec_connections Conn
                ON	
                	req.connection_id = Conn.connection_id
                WHERE 
                       sess.is_user_process = 1;
            "

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "Monitor-03" -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         

            Invoke-DbaQuery -SqlInstance  $List.SqlInstance -Query $SQLQuery|  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable #-FireTriggers
            Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $TargetDatabase -query  "EXEC [Staging].[TR_Staging_ExecutingQueries_Insert] ;"

            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "Monitor-03" -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE List                    
            REMOVE-VARIABLE LoggingGUID             
            REMOVE-VARIABLE SQLQuery                
                            
    };
FUNCTION Write-SQLMonitoringWaitStatistics
    {

        PARAM
            (
                 [STRING] $SQLInstance     
            )

            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "WaitStatistics"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $LoggingGUID             = New-Guid

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         

            Get-dbawaitstatistic -SqlInstance $SQLInstance -Threshold 100 | Where-Object {$_.WaitSeconds -ge 100} | Select-Object  @{Name ="SQLInstance"; Expression={$_.SQLInstance}}, @{Name ="WaitType"; Expression={$_.WaitType}}, @{Name ="ResourceSeconds"; Expression={$_.ResourceSeconds}}, @{Name ="WaitSeconds"; Expression={$_.WaitSeconds}}, @{Name ="SignalSeconds"; Expression={$_.SignalSeconds}}, @{Name ="WaitCount"; Expression={$_.WaitCount}}, @{Name ="CollectionDateTime"; Expression={get-date}} |Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable -FireTriggers

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0
            
            REMOVE-VARIABLE MonitoringServerDetails
            REMOVE-VARIABLE TargetServerInstance   
            REMOVE-VARIABLE TargetDatabase         
            REMOVE-VARIABLE TargetSchema           
            REMOVE-VARIABLE TargetTable            
            REMOVE-VARIABLE StartDateTime          
            REMOVE-VARIABLE TaskName               
            REMOVE-VARIABLE ParentTask             
            REMOVE-VARIABLE LoggingGUID            
    }

function write-SQLMonitoringPRTGData
    {
        PARAM
        (
             [STRING] $URL 
            ,[ARRAY]  $SensorList 
            ,[SWITCH] $HistoricData
        )
        $MonitoringServerDetails  = Get-SQLMonitoringServer
        $TargetServerInstance     = $MonitoringServerDetails.ServerInstance
        $TargetDatabase           = $MonitoringServerDetails.StagingDatabase     

                    
        if ($HistoricData)
            {
                
                
                foreach ($Sensor in $SensorList)
                    {
                            
                            $SensorValue              = $Sensor.SensorID
                            $TableName                = "SensorID_" + $Sensor.SensorID
                            $URLToUse                 = $URL.Replace("id=","id=$SensorValue")
                            $ParentTask               = "PRTG Historical Data"
                            $TaskName                 = "PRTG Historical Data - $SensorValue"
                            $LoggingGUID              = New-Guid
                            $StartDateTime            = (get-date)

                            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         
                            
                            $Output = Invoke-WebRequest $urlTOUSE -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                            $JsonOutput = $Output |convertfrom-json -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                            $JsonOutput.histdata | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema HistoricData -Table $TableName -AutoCreateTable -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

                            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0                            

                            Remove-Variable SensorValue
                            Remove-Variable TableName
                            Remove-Variable Output
                            Remove-Variable JsonOutput
                            Remove-Variable URLToUse 
                            REMOVE-VARIABLE ParentTask    
                            REMOVE-VARIABLE TaskName      
                            REMOVE-VARIABLE LoggingGUID   
                            REMOVE-VARIABLE StartDateTime 
                    }
            }
        else
            { 
            
                $ParentTask               = "PRTG LIVE Data"
                $TaskName                 = "PRTG LIVE Data"
                $LoggingGUID              = New-Guid
                $StartDateTime            = (get-date)

                Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1                     
                $FinalOutput = 
                foreach ($Sensor in $SensorList)
                    {

                            $SensorValue = $Sensor.SensorID
                            $TableName = "SensorID_" + $Sensor.SensorID
                            $URLToUse = $URL.Replace("id=","id=$SensorValue")

                            $Output = Invoke-WebRequest $urlTOUSE -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                            $JsonOutput = $Output |convertfrom-json -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                            $JsonOutput.Channels  | Where-Object {$_.name -ne "Downtime"} | Select-Object @{Name ="CollectionDateTime" ; Expression={$_.datetime}},@{Name ="SensorID" ; Expression={$SensorValue}},@{Name ="ChannelName" ; Expression={$_.name}},@{Name ="CounterValue" ; Expression={$_.lastvalue_raw}} 

                            
                            Remove-Variable SensorValue
                            Remove-Variable TableName
                            Remove-Variable Output
                            Remove-Variable JsonOutput

                    }
                    
                    $FinalOutput    | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema "Staging" -Table "PRTGCounterData" -FireTriggers #-AutoCreateTable
                    
                    Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (get-date) -LoggingGUID $LoggingGUID -InitialLog 0
                            REMOVE-VARIABLE ParentTask    
                            REMOVE-VARIABLE TaskName      
                            REMOVE-VARIABLE LoggingGUID   
                            REMOVE-VARIABLE StartDateTime 
                            REMOVE-VARIABLE FinalOutput 
                                   
            }

        REMOVE-VARIABLE URL 
        REMOVE-VARIABLE List 
        REMOVE-VARIABLE Data
        REMOVE-VARIABLE MonitoringServerDetails
        REMOVE-VARIABLE TargetServerInstance   
        REMOVE-VARIABLE TargetDatabase
        REMOVE-VARIABLE HistoricData
        REMOVE-VARIABLE SensorList              
    }

FUNCTION Write-SQLMonitoringHistoricSensorData 
    {
        $MonitoringServerDetails  = Get-SQLMonitoringServer
        $TargetServerInstance     = $MonitoringServerDetails.ServerInstance
        $TargetDatabase           = $MonitoringServerDetails.StagingDatabase 
        $MonitoringServerDatabase = $MonitoringServerDetails.MonitoringDatabase 
        $DiskSpace                = $false
        $Sensors                  = Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $MonitoringServerDatabase -Query "SELECT SensorID,isDiskSpaceSensor FROM  PRTG.Sensors WHERE ServerTier = 'PROD TIER 1' AND isServiceSensor = 0 GROUP BY SensorID,isDiskSpaceSensor"
        $SensorsToUse             = $Sensors |Where-Object {$_.isDiskSpaceSensor -eq $false} |Select-Object SensorID
        Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $TargetDatabase -Query "EXEC [HistoricData].[usp_HistoricLoadCleanup]"
        
        
        if ((get-date).hour -eq 5)
            {
               $StartDt = (Get-date).adddays(-1).ToString("yyyy-MM-dd-00-00-00")
               $EndDt   = (Get-date).adddays(1).ToString("yyyy-MM-dd-00-05-00")
            }
        else
            {
               $StartDt = (get-date).AddMinutes(- (get-date).Minute % 30).AddMinutes(-30).ToString("yyyy-MM-dd-HH-mm-00")
               $EndDt   = (get-date).AddMinutes(- (get-date).Minute % 30).ToString("yyyy-MM-dd-HH-mm-00")
            }
        $URL = "https://monitor-02/api/historicdata.json?id=$SensorValue&avg=0&sdate=$StartDt&edate=$EndDt&usecaption=1&username=patelk1&passhash=183815319"
        
        write-SQLMonitoringPRTGData -URL $URL -SensorList $SensorsToUse -HistoricData 
        
        $SensorsToUse = $Sensors |Where-Object {$_.isDiskSpaceSensor -eq $True} |Select-Object SensorID
        $URL = "https://monitor-02/api/historicdata.json?id=$SensorValue&avg=1800&sdate=$StartDt&edate=$EndDt&usecaption=1&username=patelk1&passhash=183815319"
        
        write-SQLMonitoringPRTGData -URL $URL -SensorList $SensorsToUse -HistoricData
        Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $TargetDatabase -Query "EXEC HistoricData.usp_HistoricData_StagingHistoricLoads_Insert;"
        Remove-Variable MonitoringServerDetails   
        Remove-Variable TargetServerInstance      
        Remove-Variable TargetDatabase            
        Remove-Variable MonitoringServerDatabase  
        Remove-Variable DiskSpace
        Remove-Variable Sensors
        Remove-Variable SensorsToUse
        Remove-Variable StartDt  
        Remove-Variable EndDt    
        Remove-Variable URL
    }

FUNCTION Write-SQLMonitoringPRTGLiveData
    {
        
        $MonitoringServerDetails  = Get-SQLMonitoringServer
        $TargetServerInstance     = $MonitoringServerDetails.ServerInstance
        $TargetDatabase           = $MonitoringServerDetails.StagingDatabase 
        $MonitoringServerDatabase = $MonitoringServerDetails.MonitoringDatabase 
        $DiskSpace                = $false
        $Sensors                  = Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $MonitoringServerDatabase -Query "SELECT SensorID,isDiskSpaceSensor FROM  PRTG.Sensors WHERE ServerTier = 'PROD TIER 1' AND isServiceSensor = 0 GROUP BY SensorID,isDiskSpaceSensor"
        $SensorsToUse             = $Sensors |Where-Object {$_.isDiskSpaceSensor -eq $false} |Select-Object SensorID
        $URL                      = "https://monitor-02/api/table.json?content=channels&columns=datetime,name,lastvalue_&id=$SensorValue&username=patelk1&passhash=183815319"
        
        if ((((get-date).minute -eq 0) -OR ((get-date).minute -eq 30)) -and ((get-date).second -le 20))
            {
                $SensorsToUse = $Sensors |Where-Object {$_.isDiskSpaceSensor -eq $True} |Select-Object SensorID
                write-SQLMonitoringPRTGData -URL $URL -SensorList $SensorsToUse    
            }
        
        $SensorsToUse = $Sensors |Where-Object {$_.isDiskSpaceSensor -eq $false} |Select-Object SensorID
        
        write-SQLMonitoringPRTGData -URL $URL -SensorList $SensorsToUse    

        Remove-Variable MonitoringServerDetails 
        Remove-Variable TargetServerInstance    
        Remove-Variable TargetDatabase          
        Remove-Variable MonitoringServerDatabase
        Remove-Variable DiskSpace               
        Remove-Variable Sensors               
        Remove-Variable SensorsToUse
        Remove-Variable URL               

    }
FUNCTION Write-SQLMonitoringWaitTypes
    {
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase 
            $TargetSchema            = "Staging"
            $TargetTable             = "WaitTypes"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $LoggingGUID             = New-Guid
            $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'Prod' -InstanceType 'ALL' | Select-Object SQLInstance  


            Get-dbawaitstatistic -SqlInstance $SQLList.SQLInstance -IncludeIgnorable -Threshold 100  | Select-Object ComputerName,InstanceName,@{Name ="SQLInstance" ; Expression={$_.SQLInstance}},WaitType,Category,isIgnorable |Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable # -FireTriggers
            
            REMOVE-VARIABLE MonitoringServerDetails
            REMOVE-VARIABLE TargetServerInstance   
            REMOVE-VARIABLE TargetDatabase         
            REMOVE-VARIABLE TargetSchema           
            REMOVE-VARIABLE TargetTable            
            REMOVE-VARIABLE StartDateTime          
            REMOVE-VARIABLE TaskName               
            REMOVE-VARIABLE ParentTask             
            REMOVE-VARIABLE LoggingGUID
            REMOVE-VARIABLE SQLList            
    }
FUNCTION Write-SQLMonitoringBlockingTasks
    {
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase 
            $TargetSchema            = "Staging"
            $TargetTable             = "BlockingTasks"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $List                    = Get-SQLMonitoringServerList -InstanceRole PROD -InstanceType 'ALL' | Where-Object {$_.SQLInstance -ne "EICC-DBS" -and $_.SQLInstance -ne "EICC-REP"} | Select-Object SQLInstance
            $LoggingGUID             = New-Guid
            $SQLQuery                = 
            "
                IF OBJECT_ID('TempDB..#BlockingTasks','U') IS NOT NULL DROP TABLE #BlockingTasks;
                SET NOCOUNT ON;
                SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                CREATE TABLE #BlockingTasks
                    (
                         [SessionId]                      INT
                        ,[WaitDurationMs]                 BIGINT
                        ,[WaitType]                       NVARCHAR(100)
                        ,[ResourceDatabaseId]             SMALLINT
                        ,[ResourceAssociatedEntityID]     BIGINT
                        ,[ResourceDescription]            VARCHAR(1000)
                        ,[RequestOwnerId]                 BIGINT
                        ,[TranResourceType]               VARCHAR(100)
                    );
                INSERT INTO #BlockingTasks
                	(
                		 [SessionId]                     
                		,[WaitDurationMs]               
                		,[WaitType]                      
                		,[ResourceDatabaseId]           
                		,[ResourceAssociatedEntityID]  
                		,[ResourceDescription]           
                		,[RequestOwnerId]               
                		,[TranResourceType]             
                	)
                SELECT 
                	 DowT.session_id
                	,DowT.wait_duration_ms
                	,DowT.wait_type
                	,TranObj.resource_database_id
                	,TranObj.resource_associated_entity_id
                	,TranResource.resource_description
                	,TranObj.request_owner_id
                	,TranResource.resource_type Tran_resource_type
                FROM 
                	sys.dm_os_waiting_tasks DOWT
                JOIN
                	sys.dm_tran_locks TranObj
                ON
                	DOWT.session_id = TranObj.request_session_id
                AND
                	TranObj.resource_type = 'OBJECT'
                JOIN
                	sys.dm_tran_locks TranResource
                ON
                	DOWT.session_id = TranResource.request_session_id
                JOIN
                	sys.dm_exec_sessions sess
                ON
                	DOWT.session_id = sess.session_id
                AND
                	sess.host_name NOT IN('MONITOR-01','MONITOR-03')
                WHERE
                	DOWT.wait_type LIKE '%lck%'
                GROUP BY
                	 DowT.session_id 
                	,DowT.wait_duration_ms 
                	,DowT.wait_type 
                	,TranObj.resource_database_id 
                	,TranObj.resource_associated_entity_id 
                	,TranResource.resource_description
                	,TranObj.request_owner_id
                	,TranResource.resource_type 
                
                
                ;WITH	Resources AS
                	(
                		SELECT
                			 Cte.[SessionId]                    
                			,Cte.[WaitDurationMs]               
                			,Cte.[WaitType]                     
                			,Cte.[ResourceDatabaseId]           
                			,Cte.[ResourceAssociatedEntityID]  
                			,Cte.[ResourceDescription]          
                			,Cte.[RequestOwnerId]               
                			,Cte.[TranResourceType]             
                		FROM
                			#BlockingTasks Cte
                		WHERE
                			Cte.[TranResourceType] NOT IN('DATABASE','OBJECT')
                	)
                ,	ObjectResources AS
                	(
                		SELECT
                			 Cte.[SessionId]                    
                			,Cte.[WaitDurationMs]               
                			,Cte.[WaitType]                     
                			,Cte.[ResourceDatabaseId]           
                			,Cte.[ResourceAssociatedEntityID]  
                			,Cte.[ResourceDescription]          
                			,Cte.[RequestOwnerId]               
                			,Cte.[TranResourceType]             
                		FROM
                			#BlockingTasks Cte
                		LEFT JOIN
                			Resources
                		ON
                			Cte.[RequestOwnerId] = Resources.[RequestOwnerId]
                		WHERE
                			Cte.[TranResourceType] IN('OBJECT')
                		AND
                			Resources.[RequestOwnerId] IS NULL
                	)
                SELECT
                	 Cte.[SessionId]         
                	,SYSDATETIME() CollectionDateTime
                	,SERVERPROPERTY('ComputerNamePhysicalNetBIOS')ComputerName		 
                	,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName        
                	,@@SERVERNAME SqlInstance  	            
                	,Cte.[WaitDurationMs]               
                	,Cte.[WaitType]                     
                	,Cte.[ResourceDatabaseId]    DatabaseID       
                	,Cte.[ResourceAssociatedEntityID]  ObjectID
                	,Cte.[ResourceDescription]          
                	,Cte.[RequestOwnerId]               
                	,Cte.[TranResourceType]    ResourceType         
                FROM
                	#BlockingTasks Cte
                LEFT JOIN
                	ObjectResources Resources
                ON
                	Cte.[RequestOwnerId] = Resources.[RequestOwnerId]
                WHERE
                	Cte.[TranResourceType] IN('Database')
                AND
                	Resources.[RequestOwnerId] IS NULL
                UNION
                SELECT
                	 Cte.[SessionId]         
                	,SYSDATETIME() CollectionDateTime
                	,SERVERPROPERTY('ComputerNamePhysicalNetBIOS')ComputerName		 
                	,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName        
                	,@@SERVERNAME SqlInstance  	            
                	,Cte.[WaitDurationMs]               
                	,Cte.[WaitType]                     
                	,Cte.[ResourceDatabaseId]    DatabaseID       
                	,Cte.[ResourceAssociatedEntityID]  ObjectID
                	,Cte.[ResourceDescription]          
                	,Cte.[RequestOwnerId]               
                	,Cte.[TranResourceType]    ResourceType         
                FROM
                	Resources Cte
                UNION
                SELECT
                	 Cte.[SessionId]         
                	,SYSDATETIME() CollectionDateTime
                	,SERVERPROPERTY('ComputerNamePhysicalNetBIOS')ComputerName		 
                	,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName        
                	,@@SERVERNAME SqlInstance  	            
                	,Cte.[WaitDurationMs]               
                	,Cte.[WaitType]                     
                	,Cte.[ResourceDatabaseId]    DatabaseID       
                	,Cte.[ResourceAssociatedEntityID]  ObjectID
                	,Cte.[ResourceDescription]          
                	,Cte.[RequestOwnerId]               
                	,Cte.[TranResourceType]    ResourceType         
                FROM
                	ObjectResources Cte;
                
            "

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "Monitor-03" -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         

            Invoke-DbaQuery -SqlInstance  $List.SqlInstance -Query $SQLQuery |  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable  -FireTriggers
            Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $TargetDatabase -Query "EXEC Staging.TR_Staging_BlockingTasks_After_Insert;"
            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "Monitor-03" -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE List                    
            REMOVE-VARIABLE LoggingGUID             
            REMOVE-VARIABLE SQLQuery 
    };

FUNCTION Write-SQLMonitoringStatisticsInformation
    {
        PARAM
            (
                  [STRING] $SQLInstance   
            )
            
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "StatisticsObjects"
            $StartDateTime           = (get-date)            
            $ParentTask              =  "$TargetTable"
            $Databases               =  Get-DbaDatabase -SqlInstance $SQLInstance -ExcludeDatabase tempdb, modeldb |Select-Object Name
            $TaskName                =   "$SQLInstance - Statistics - $TargetTable"
            $Query                   = "
                            SET NOCOUNT ON;
                            SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                            DECLARE @IncludeDataTypes BIT = 0;
                            IF OBJECT_ID('TempDB..#IndexUsageStats', 'U') IS NOT NULL
                                DROP TABLE #IndexUsageStats;
                            IF OBJECT_ID('TempDB..#IndexInformation', 'U') IS NOT NULL
                                DROP TABLE #IndexInformation;
                            IF OBJECT_ID('TempDB..#StatsInfo', 'U') IS NOT NULL
                                DROP TABLE #StatsInfo;
                            IF OBJECT_ID('TempDB..#StatsInfoSummary', 'U') IS NOT NULL
                                DROP TABLE #StatsInfoSummary;

                            CREATE TABLE #IndexUsageStats
                                (
                                    object_id                     INT
                                    ,index_id                     INT
                                    ,user_scans                   BIGINT
                                    ,user_seeks                   BIGINT
                                    ,user_updates                 BIGINT
                                    ,user_lookups                 BIGINT
                                    ,last_user_lookup             DATETIME2(0)
                                    ,last_user_scan               DATETIME2(0)
                                    ,last_user_seek               DATETIME2(0)
                                    ,avg_fragmentation_in_percent FLOAT
                                );
                            CREATE TABLE #StatsInfo
                                (
                                    object_id           INT
                                    ,stats_id           INT
                                    ,stats_column_name  NVARCHAR(128)
                                    ,stats_column_id    INT
                                    ,stats_name         NVARCHAR(128)
                                    ,stats_last_updated DATETIME2(0)
                                    ,stats_sampled_rows BIGINT
                                    ,rowmods            BIGINT
                                    ,histogramsteps     INT
                                    ,StatsRows          BIGINT
                                    ,FullObjectName     NVARCHAR(256)
                                );
                            CREATE TABLE #IndexInformation
                                (
                                    [ObjectName]                    NVARCHAR(128)
                                    ,[object_id]                    INT
                                    ,[index_id]                     INT
                                    ,[name]                         NVARCHAR(1055)
                                    ,[index_column_id]              INT
                                    ,[column_id]                    INT
                                    ,[is_included_column]           BIT
                                    ,[ColumnName]                   NVARCHAR(1055)
                                    ,[filter_definition]            NVARCHAR(MAX)
                                    ,[user_scans]                   BIGINT
                                    ,[user_seeks]                   BIGINT
                                    ,[user_updates]                 BIGINT
                                    ,[user_lookups]                 BIGINT
                                    ,[LastLookup]                   DATETIME2(0)
                                    ,[LastScan]                     DATETIME2(0)
                                    ,[LastSeek]                     DATETIME2(0)
                                    ,[fill_factor]                  TINYINT
                                    ,[is_descending_key]            BIT
                                    ,[data_compression_desc]        NVARCHAR(MAX)
                                    ,[type_desc]                    NVARCHAR(MAX)
                                    ,[is_unique]                    BIT
                                    ,[is_unique_constraint]         BIT
                                    ,[is_primary_key]               BIT
                                    ,[SizeKB]                       BIGINT
                                    ,[IndexRows]                    BIGINT
                                    ,[FullObjectName]               NVARCHAR(MAX)
                                    ,[avg_fragmentation_in_percent] FLOAT(8)
                                );
                            CREATE TABLE #StatsInfoSummary
                                (
                                    [object_id]         INT
                                    ,[stats_id]         INT
                                    ,[stats_name]       NVARCHAR(MAX)
                                    ,[StatsColumns]     NVARCHAR(MAX)
                                    ,[SampleRows]       BIGINT
                                    ,[RowMods]          BIGINT
                                    ,[HistogramSteps]   INT
                                    ,[StatsLastUpdated] DATETIME2(0)
                                    ,[StatsRows]        BIGINT
                                    ,[FullObjectName]   NVARCHAR(256)
                                );


                            INSERT INTO #IndexUsageStats
                                (
                                    object_id
                                    ,index_id
                                    ,user_scans
                                    ,user_seeks
                                    ,user_updates
                                    ,user_lookups
                                    ,last_user_lookup
                                    ,last_user_scan
                                    ,last_user_seek
                                    ,avg_fragmentation_in_percent
                                )
                                        SELECT
                                                ustat.object_id
                                                ,ustat.index_id
                                                ,ustat.user_scans
                                                ,ustat.user_seeks
                                                ,ustat.user_updates
                                                ,ustat.user_lookups
                                                ,ustat.last_user_lookup
                                                ,ustat.last_user_scan
                                                ,ustat.last_user_seek
                                                ,NULL avg_fragmentation_in_percent
                                        FROM
                                                sys.dm_db_index_usage_stats ustat
                                            LEFT JOIN
                                                sys.indexes                 pstat
                                                    ON pstat.object_id = ustat.object_id
                                                       AND pstat.index_id = ustat.index_id
                                        WHERE
                                                ustat.database_id = DB_ID();

                            INSERT INTO #StatsInfo
                                (
                                    object_id
                                    ,stats_id
                                    ,stats_column_name
                                    ,stats_column_id
                                    ,stats_name
                                    ,stats_last_updated
                                    ,stats_sampled_rows
                                    ,rowmods
                                    ,histogramsteps
                                    ,StatsRows
                                    ,FullObjectName
                                )
                                        SELECT
                                                        s.object_id
                                                        ,s.stats_id
                                                        ,c.name
                                                        ,sc.stats_column_id
                                                        ,s.name
                                                        ,sp.last_updated
                                                        ,sp.rows_sampled
                                                        ,sp.modification_counter
                                                        ,sp.steps
                                                        ,sp.rows
                                                        ,QUOTENAME(sch.name) + '.' + QUOTENAME(t.name) AS FullObjectName
                                        FROM
                                                        [sys].[stats]                                               [s]
                                            JOIN
                                                        sys.stats_columns                                           sc
                                                            ON s.stats_id = sc.stats_id
                                                               AND s.object_id = sc.object_id
                                            INNER JOIN
                                                        sys.columns                                                 c
                                                            ON c.object_id = sc.object_id
                                                               AND c.column_id = sc.column_id
                                            INNER JOIN
                                                        sys.tables                                                  t
                                                            ON c.object_id = t.object_id
                                            INNER JOIN
                                                        sys.schemas                                                 sch
                                                            ON sch.schema_id = t.schema_id
                                            OUTER APPLY sys.dm_db_stats_properties([s].[object_id], [s].[stats_id]) AS [sp];
                            ;WITH CTE AS
	                            (
			                            SELECT
				                            object_id
				                            ,si.stats_id
				                            ,si.stats_name
				                            ,STUFF((
						                               SELECT
							                               N', ' + stats_column_name
						                               FROM
							                               #StatsInfo si2
						                               WHERE
							                               si2.object_id = si.object_id
							                               AND si2.stats_id = si.stats_id
						                               ORDER BY
							                               si2.stats_column_id
						                               FOR XML PATH(N''), TYPE
					                               ).value(N'.[1]', N'nvarchar(1000)'), 1, 2, N''
					                              )                     AS StatsColumns
				                            ,MAX(si.stats_sampled_rows) AS SampleRows
				                            ,MAX(si.rowmods)            AS RowMods
				                            ,MAX(si.histogramsteps)     AS HistogramSteps
				                            ,MAX(si.stats_last_updated) AS StatsLastUpdated
				                            ,MAX(si.StatsRows)          AS StatsRows
				                            ,FullObjectName
			                            FROM
				                            #StatsInfo si
			                            GROUP BY
				                            si.object_id
				                            ,si.stats_id
				                            ,si.stats_name
				                            ,si.FullObjectName
	                            )
                            SELECT
                                SERVERPROPERTY('MachineName') ComputerName
                               ,@@SERVICENAME InstanceName
                               ,@@SERVERNAME SQLInstance       
                               ,DB_NAME() [Database]
                               ,CTE.object_id		 ObjectID
                               ,CTE.stats_id		 StatsID
                               ,UPPER(CTE.stats_name	) StatsName
                               ,UPPER(CTE.StatsColumns	) StatsColumn
                               ,QUOTENAME(UPPER(DB_NAME()),'[') + '.' + UPPER(CTE.FullObjectName) ObjectName
                               ,CTE.SampleRows
                               ,CTE.RowMods
                               ,CTE.HistogramSteps
                               ,CTE.StatsLastUpdated
                               ,CTE.StatsRows
                               ,SYSDATETIME() CollectionDateTime
                            FROM
	                            CTE
                            LEFT JOIN
	                            sys.partitions part
                            ON	
	                            cte.object_id = part.object_id
                            AND
	                            part.index_id <= 1
                            WHERE
	                            CTE.StatsRows IS not NULL;

            "


            
            $LoggingGUID = New-Guid
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1            
            $InnerTaskName         =   "$SQLInstance - $DB.Name - $TargetTable"
            $Out = 
            foreach ($Db in $Databases)
            {
                        $InnerStartDateTime    = (get-date)
                        $InnerLoggingGUID      = New-Guid
                        Write-SQLMonitoringLoggingTable   -TaskName $InnerTaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $DB.Name -StartDateTime $InnerStartDateTime  -LoggingGUID $InnerLoggingGUID -InitialLog 1
                        Invoke-DbaQuery -SqlInstance $SQLInstance -Database $Db.name -query $Query | Select-Object ComputerName, InstanceName, @{Name ="SQLInstance" ; Expression={$_.SQLInstance}}, @{Name ="DatabaseName" ; Expression={$_.Database}}, ObjectID, StatsID, StatsName, StatsColumn, ObjectName, SampleRows, RowMods, HistogramSteps, StatsLastUpdated, StatsRows, CollectionDateTime
                        Write-SQLMonitoringLoggingTable   -TaskName $InnerTaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $DB.Name -StartDateTime $InnerStartDateTime -EndDateTime (Get-Date) -LoggingGUID $InnerLoggingGUID -InitialLog 0
            }

            
            $Out   | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable
            Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database  $TargetDatabase -Query "EXEC [Staging].[TR_Staging_StatisticsObjects_AFTERINSERT];"
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $ComputerName -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0                            
            
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE Databases    
            REMOVE-VARIABLE TaskName   
            REMOVE-VARIABLE LoggingGUID        
            REMOVE-VARIABLE InnerStartDateTime    
            REMOVE-VARIABLE InnerLoggingGUID      
            REMOVE-VARIABLE SQLInstance
            REMOVE-VARIABLE Query                   
            REMOVE-VARIABLE Out
            REMOVE-VARIABLE InnerTaskName
    };

FUNCTION  Write-SQLMonitoringCaptureDeadlocks
    {
        PARAM
            (
                 [STRING] $SQLInstance     
            )
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "DeadlockHistory"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $SQLQuery                = 
            "
                SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                SET NOCOUNT ON;
                SET DEADLOCK_PRIORITY LOW;
                IF OBJECT_ID('TempDB..#DeadLockInfo') IS NOT NULL DROP TABLE #DeadLockInfo;
                DECLARE @ErrorLog  VARCHAR(1055) = CAST(SERVERPROPERTY('ErrorLogFileName') AS VARCHAR(1055)), @path VARCHAR(MAX);
	                SELECT 
		                @path= LEFT(@ErrorLog,LEN(@ErrorLog)-CHARINDEX('\',REVERSE(@ErrorLog),1))
                ;WITH Cte AS
	                (
		                SELECT 
		                  CONVERT(xml, event_data).query('/event/data/value/child::*') AS DeadlockReport
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/inputbuf)[1]', 'VARCHAR(MAX)')						    QueryTextVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/inputbuf)[2]', 'VARCHAR(MAX)')						    QueryTextWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@id)[1]', 'VARCHAR(MAX)')							    ProcessIDVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@id)[2]', 'VARCHAR(MAX)')							    ProcessIDWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@waittime)[1]', 'INT')								    WaitTimeVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@waittime)[2]', 'INT')								    WaitTimeWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@spid)[1]', 'INT')									    SpidVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@spid)[1]', 'INT')									    SpidWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@lastbatchstarted)[1]', 'DATETIME2')				    LastBatchStartedVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@lastbatchstarted)[1]', 'DATETIME2')				    LastBatchStartedWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@lastbatchcompleted)[1]', 'DATETIME2')				    LastBatchCompletedVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@lastbatchcompleted)[1]', 'DATETIME2')				    LastBatchCompletedWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@loginname)[1]', 'VARCHAR(255)') 					    LoginVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@loginname)[1]', 'VARCHAR(255)') 					    LoginWinner
		                  ,CONVERT(xml,	 event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@clientapp)[2]', 'VARCHAR(255)') 					    ClientAppVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@clientapp)[2]', 'VARCHAR(255)') 					    ClientAppWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@hostname)[1]', 'VARCHAR(255)') 					    hostnameVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@hostname)[2]', 'VARCHAR(255)') 					    hostnameWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@isolationlevel)[1]', 'VARCHAR(255)') 				    IsolationLevelVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@isolationlevel)[2]', 'VARCHAR(255)') 				    IsolationLevelWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@currentdb)[1]', 'INT') 							    CurrentDBVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@currentdb)[2]', 'INT') 							    CurrentDBWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@xactid)[1]', 'BIGINT')								    TransactionIDVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@xactid)[2]', 'BIGINT')								    TransactionIDWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/executionStack/frame/@procname)[1]', 'VARCHAR(255)')    ProcNameVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/executionStack/frame/@procname)[2]', 'VARCHAR(255)')    ProcNameWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/executionStack/frame/@sqlhandle)[1]', 'NVARCHAR(MAX)')   SQLHandleVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/executionStack/frame/@sqlhandle)[2]', 'NVARCHAR(MAX)')   SQLHandleWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@waitresource)[1]', 'VARCHAR(255)')						WaitResoureVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@waitresource)[2]', 'VARCHAR(255)')						WaitResoureWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/objectlock/@objectname)[1]', 'VARCHAR(255)')					ObjectNameVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/objectlock/@objectname)[2]', 'VARCHAR(255)')					ObjectNameWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/objectlock/@objid)[1]', 'BIGINT')								ObjectResourceVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/objectlock/@objid)[2]', 'BIGINT')								ObjectResourceWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/objectlock/@dbid)[1]', 'BIGINT')								ObjectDBIDVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/objectlock/@dbid)[2]', 'BIGINT')								ObjectDBIDWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/objectlock/@indexname)[1]', 'VARCHAR(255)')					ObjectIndexNameVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/objectlock/@indexname)[2]', 'VARCHAR(255)')					ObjectIndexNameWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/pagelock/@objectname)[1]', 'VARCHAR(255)')						PageObjectNameVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/pagelock/@objectname)[2]', 'VARCHAR(255)')						PageObjectNameWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/pagelock/@associatedObjectId)[1]', 'BIGINT')					PageHoBTIDVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/pagelock/@associatedObjectId)[2]', 'BIGINT')					PageHoBTIDWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/pagelock/@dbid)[1]', 'BIGINT')									PageDBIDVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/pagelock/@dbid)[2]', 'BIGINT')									PageDBIDWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/Pagelock/@indexname)[1]', 'VARCHAR(255)')						PageIndexNameVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/Pagelock/@indexname)[2]', 'VARCHAR(255)')						PageIndexNameWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/keylock/@objectname)[1]', 'VARCHAR(255)')						KeyObjectNameVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/keylock/@objectname)[2]', 'VARCHAR(255)')						KeyObjectNameWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/keylock/@associatedObjectId)[1]', 'BIGINT')					KeyHoBTIDVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/keylock/@associatedObjectId)[2]', 'BIGINT')					KeyHoBTIDWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/keylock/@dbid)[1]', 'BIGINT')									KeyDBIDVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/keylock/@dbid)[2]', 'BIGINT')									KeyDBIDWinner
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/keylock/@indexname)[1]', 'VARCHAR(255)')						KeyIndexNameVictim
		                  ,CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/resource-list/keylock/@indexname)[2]', 'VARCHAR(255)')						KeyIndexNameWinner
		                FROM sys.fn_xe_file_target_read_file(@path + '\system_health*.xel', NULL, NULL, NULL)
		                WHERE 
			                OBJECT_NAME like 'xml_deadlock_report'
		                AND
			                CONVERT(xml, event_data).value('(event[@name=`"xml_deadlock_report`"]/data/value/deadlock/process-list/process/@lastbatchcompleted)[1]', 'DATETIME2') >= DATEADD(MINUTE,-5,SYSDATETIME())
	                )

                SELECT 
			        Cte.DeadlockReport
                   ,Cte.LastBatchStartedVictim	  BatchStartedVictim
                   ,Cte.LastBatchStartedWinner	  BatchStartedWinner
                   ,Cte.LastBatchCompletedVictim  BatchCompletedVictim
                   ,Cte.LastBatchCompletedWinner  BatchCompletedWinner
                   ,Cte.ProcessIDVictim
                   ,Cte.ProcessIDWinner
                   ,Cte.WaitTimeVictim
                   ,Cte.WaitTimeWinner
                   ,Cte.SpidVictim
                   ,Cte.SpidWinner
                   ,Cte.LoginVictim
                   ,Cte.LoginWinner
                   ,Cte.ClientAppVictim
                   ,Cte.ClientAppWinner
                   ,Cte.HostNameVictim
                   ,Cte.HostNameWinner
                   ,Cte.IsolationLevelVictim
                   ,Cte.IsolationLevelWinner
                   ,Cte.CurrentDBWinner
                   ,Cte.CurrentDBVictim
                   ,Cte.TransactionIDVictim
                   ,Cte.TransactionIDWinner
                   ,Cte.ProcNameVictim
                   ,Cte.ProcNameWinner
                   ,Cte.WaitResoureVictim
                   ,Cte.WaitResoureWinner
                   ,COALESCE(Cte.KeyObjectNameVictim ,Cte.PageObjectNameVictim	 ,Cte.ObjectNameVictim		) TableNameVictim		
                   ,COALESCE(Cte.KeyObjectNameWinner ,Cte.PageObjectNameWinner	 ,Cte.ObjectNameWinner		) TableNameWinner		
                   ,COALESCE(Cte.KeyHoBTIDVictim	 ,Cte.PageHoBTIDVictim		 ,Cte.ObjectResourceVictim	) ResourceVictim	
                   ,COALESCE(Cte.KeyHoBTIDWinner	 ,Cte.PageHoBTIDWinner		 ,Cte.ObjectResourceWinner	) ResourceWinner	
                   ,COALESCE(Cte.KeyDBIDVictim		 ,Cte.PageDBIDVictim		 ,Cte.ObjectDBIDVictim		) DBIDVictim		
                   ,COALESCE(Cte.KeyDBIDWinner		 ,Cte.PageDBIDWinner		 ,Cte.ObjectDBIDWinner		) DBIDWinner		
                   ,COALESCE(Cte.KeyIndexNameVictim	 ,Cte.PageIndexNameVictim	 ,Cte.ObjectIndexNameVictim	) IndexNameVictim	
                   ,COALESCE(Cte.KeyIndexNameWinner	 ,Cte.PageIndexNameWinner    ,Cte.ObjectIndexNameWinner	) IndexNameWinner	
                   ,cte.sqlhandleWINNER
                   ,sqlhandleVictim
                   ,Cte.LastBatchStartedVictim
                   ,LastBatchStartedWinner
                   ,Cte.QueryTextVictim
                   ,Cte.QueryTextWinner
                INTO	
	                #DeadLockInfo
                FROM  
	                Cte

                IF (SELECT TOP 1 1 FROM #DeadLockInfo ) IS NOT NULL
	                BEGIN	
			                SELECT 
				                
					                   SERVERPROPERTY('ComputerNamePhysicalNetBIOS') ComputerName
			                          ,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName
			                          ,@@SERVERNAME SQLInstance
                                      ,cte.DeadlockReport
	                                  ,cte.BatchStartedVictim
					                  ,cte.BatchStartedWinner
					                  ,cte.BatchCompletedVictim
					                  ,cte.BatchCompletedWinner
					                  ,cte.ProcessIDVictim
					                  ,cte.ProcessIDWinner
					                  ,cte.WaitTimeVictim
					                  ,cte.WaitTimeWinner
					                  ,cte.SpidVictim
					                  ,cte.SpidWinner
					                  ,cte.LoginVictim
					                  ,cte.LoginWinner
					                  ,cte.ClientAppVictim
					                  ,cte.ClientAppWinner
					                  ,cte.hostnameVictim
					                  ,cte.hostnameWinner
					                  ,cte.IsolationLevelVictim
					                  ,cte.IsolationLevelWinner
					                  ,VictimDB.name VictimDatabaseName
					                  ,WinnerDB.name WinnerDatabaseName
					                  ,cte.TransactionIDVictim
					                  ,cte.TransactionIDWinner
					                  ,cte.ProcNameVictim
					                  ,cte.ProcNameWinner
					                  ,cte.WaitResoureVictim
					                  ,cte.WaitResoureWinner
					                  ,cte.TableNameVictim
					                  ,cte.TableNameWinner
					                  ,cte.ResourceVictim
					                  ,cte.ResourceWinner
					                  ,cte.DBIDVictim
					                  ,cte.DBIDWinner
					                  ,cte.IndexNameVictim
					                  ,cte.IndexNameWinner
					                  ,cte.SQLHandleWinner
					                  ,cte.SQLHandleVictim 
					                  ,Winnerstats.plan_handle	PlanHandleVictim
					                  ,Victimstats.plan_handle PlanHandleWinner
					                  ,Winnerqp.query_plan		QueryPlanVictim
					                  ,Victimqp.query_plan     QueryPlanWinner
					                  ,ISNULL(WinnerQT.text,Cte.QueryTextWinner)    QueryTextWinner
					                  ,ISNULL(VictimQT.text,Cte.QueryTextVictim)    QueryTextVictim
			                FROM  
				                #DeadLockInfo cte
			                OUTER APPLY 
				                sys.dm_exec_sql_text(CONVERT ( varbinary(64), sqlhandleWINNER, 1)) WinnerQT
			                LEFT JOIN
				                sys.dm_exec_query_stats Winnerstats
			                ON
				                CONVERT ( varbinary(64), sqlhandleWINNER, 1) = Winnerstats.sql_handle
			                AND
				                Winnerstats.creation_time = 
				                (
					                SELECT 
						                MAX(creation_time)
					                FROM
						                sys.dm_exec_query_stats
					                WHERE
						                CONVERT ( varbinary(64), sqlhandleWINNER, 1) = sql_handle
					                AND
						                Cte.LastBatchStartedWinner > creation_time
				                )
			                OUTER APPLY
				                sys.dm_exec_query_plan(Winnerstats.plan_handle)  		Winnerqp
			                OUTER APPLY 
				                sys.dm_exec_sql_text(CONVERT ( varbinary(64), sqlhandleVictim, 1)) VictimQT
			                LEFT JOIN
				                sys.dm_exec_query_stats Victimstats
			                ON
				                CONVERT ( varbinary(64), sqlhandleVictim, 1) = Victimstats.sql_handle
			                AND
				                Victimstats.creation_time = 
				                (
					                SELECT 
						                MAX(creation_time)
					                FROM
						                sys.dm_exec_query_stats
					                WHERE
						                CONVERT ( varbinary(64), Cte.SQLHandleVictim, 1) = sql_handle
					                AND
						                Cte.LastBatchStartedVictim > creation_time
				                )
			                OUTER APPLY
				                sys.dm_exec_query_plan(Victimstats.plan_handle) Victimqp
			                LEFT JOIN
				                sys.databases WinnerDB
			                ON
				                Cte.CurrentDBWinner = WinnerDB.database_id
			                LEFT JOIN
				                sys.databases VictimDB
			                ON
				                Cte.CurrentDBVictim = VictimDB.database_id
	                END
            "
            $LoggingGUID = New-Guid
            
            write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $PlaceHolderComputerName -SqlInstance $SqlInstance -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1            
               

            $oUT = Invoke-DbaQuery -SqlInstance $SQLInstance -Query $SQLQuery # |  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable   -FireTriggers

            
            
           


            $oUT |  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable   #-FireTriggers
            Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $TargetDatabase -Query "EXEC Staging.usp_Staging_DeadlockHistory;"


            write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName $PlaceHolderComputerName -SqlInstance $SqlInstance -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0            

            REMOVE-VARIABLE SQLQuery 
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask
            REMOVE-VARIABLE SQLInstance            
            REMOVE-VARIABLE Out
            REMOVE-VARIABLE LoggingGUID
    } 
function write-SQLMonitoringStorageSpace
    {
        Disable-SQLMonitoringSSLCertificates
        $MonitoringServerDetails  = Get-SQLMonitoringServer
        $TargetServerInstance     = $MonitoringServerDetails.ServerInstance
        $TargetDatabase           = $MonitoringServerDetails.StagingDatabase
        $MonitoringServerDatabase = $MonitoringServerDetails.MonitoringDatabase
        $DiskSpace                = $false
        $SensorsToUse             = Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $MonitoringServerDatabase -Query "SELECT SensorID FROM  PRTG.Sensors WHERE isDiskSpaceSensor = 1 GROUP BY SensorID"
        $URL                      = "https://monitor-02/api/table.json?content=channels&columns=datetime,name,lastvalue_&id=&username=patelk1&passhash=183815319"
        $ParentTask               = "Disk Space"
        $TaskName                 = "Disk Space"
        $LoggingGUID              = New-Guid
        $StartDateTime            = (get-date)
        Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1                     
        $FinalOutput = 
        foreach ($Sensor in $SensorsToUse)
            {
        
                    $SensorValue = $Sensor.SensorID
                    $TableName = "SensorID_" + $Sensor.SensorID
                    $URLToUse = $URL.Replace("id=","id=$SensorValue")
        
                    $Output = Invoke-WebRequest $urlTOUSE -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    $JsonOutput = $Output |convertfrom-json -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                    $JsonOutput.Channels  | Where-Object {($_.name -ne "Downtime") -and ($_.name -ne "total")} | Select-Object @{Name ="CollectionDateTime" ; Expression={$_.datetime}},@{Name ="SensorID" ; Expression={$SensorValue}},@{Name ="ChannelName" ; Expression={$_.name}},@{Name ="CounterValue" ; Expression={$_.lastvalue_raw}} 
        
                    
                    Remove-Variable SensorValue
                    Remove-Variable TableName
                    Remove-Variable Output
                    Remove-Variable JsonOutput
        
            }
            
            $FinalOutput    | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema "Staging" -Table "StorageSpace"  -FireTriggers #-AutoCreateTable
            
        
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (get-date) -LoggingGUID $LoggingGUID -InitialLog 0
        write-SQLMonitoringPRTGData -URL $URL -SensorList $SensorsToUse    

        Remove-Variable FinalOutput
        Remove-Variable MonitoringServerDetails 
        Remove-Variable TargetServerInstance    
        Remove-Variable TargetDatabase          
        Remove-Variable MonitoringServerDatabase
        Remove-Variable DiskSpace               
        Remove-Variable SensorsToUse
        Remove-Variable Sensor
        Remove-Variable URL
        Remove-Variable ParentTask    
        Remove-Variable TaskName      
        Remove-Variable LoggingGUID   
        Remove-Variable StartDateTime                

    }
function write-SQLMonitoringSQLErrorLog
    {
        if ((get-date).DayOfWeek -eq "Monday")
            {
                $DaysAway = -3
            }
        else
            {
                $DaysAway = -1
            }
        $SQLInstances             = (Get-SQLMonitoringServerList -InstanceRole PROD -InstanceType ALL | Where-object {$_.SQLInstance -ne "DBS-01"}| Select-Object SQLInstance).SQLInstance
        $MonitoringServerDetails  = Get-SQLMonitoringServer
        $TargetServerInstance     = $MonitoringServerDetails.ServerInstance
        $MonitoringServerDatabase = $MonitoringServerDetails.MonitoringDatabase
        $ParentTask               = "SQL Error Logs"
        $TaskName                 = "SQL Error Logs"
        $LoggingGUID              = New-Guid
        $StartDateTime            = (get-date)
        Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         
        $Out = 
        foreach ($SQLInstance in $SQLInstances )
            {
            for ($i=0; $i -le 10; $i++)
                {
                    Get-DbaErrorLog -SqlInstance $SQLInstance -LogNumber $i  -After (get-date).AddDays($DaysAway) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Select-Object  ComputerName, InstanceName, SqlInstance, @{Name ="ErrorLogSource" ; Expression={$_.Source}}, LogDate, ProcessInfo, @{Name ="ErrorText" ; Expression={$_.Text}}, HasErrors 
                }
            }


        $Out | Select-Object ComputerName, InstanceName, SqlInstance, ErrorLogSource, LogDate, ProcessInfo, ErrorText, HasErrors    | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $MonitoringServerDatabase -Schema "SQLServer" -Table "ErrorLog" -Truncate
        Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (get-date) -LoggingGUID $LoggingGUID -InitialLog 0

        Remove-Variable DaysAway
        Remove-Variable SQLInstances             
        Remove-Variable MonitoringServerDetails  
        Remove-Variable TargetServerInstance     
        Remove-Variable MonitoringServerDatabase 
        Remove-Variable ParentTask               
        Remove-Variable TaskName                 
        Remove-Variable LoggingGUID              
        Remove-Variable StartDateTime 
        Remove-Variable SQLInstances
        Remove-Variable Out                   
    }
function write-SQLMonitoringWindowsLog
    {
        clear-host
        if ((get-date).DayOfWeek -eq "Monday")
            {
                $DaysAway = -3
            }
        else
            {
                $DaysAway = -1
            }
        $ComputerNames            = (Get-SQLMonitoringServerList -InstanceRole PROD -InstanceType ALL | Select-Object ComputerName).ComputerName
        $WindowsLogs              = @("Application","System","Security")
        $MonitoringServerDetails  = Get-SQLMonitoringServer
        $TargetServerInstance     = $MonitoringServerDetails.ServerInstance
        $MonitoringServerDatabase = $MonitoringServerDetails.MonitoringDatabase
        $ParentTask               = "Windows Logs"
        $TaskName                 = "Windows Logs"
        $LoggingGUID              = New-Guid
        $StartDateTime            = (get-date)
        Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1                     

        $Out = 
        foreach ($ComputerName in $ComputerNames)
            {
            foreach ($Log in $WindowsLogs)
                {
                    if ((Get-EventLog -ComputerName $ComputerName -LogName $Log -EntryType Warning,Error -After (get-date).AddDays($DaysAway)  -Newest 1 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Measure-Object | Select-Object count).count -ge 1)
                        {
                            Get-EventLog -ComputerName $ComputerName -LogName $Log -EntryType Warning,Error -After (get-date).AddDays($DaysAway) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Select-Object @{Name ="LogName" ; Expression={$Log}}, @{Name ="ComputerName" ; Expression={$ComputerName}}, EventID, Index, Source, Category, TimeWritten, EntryType, Message           
                        }
                }
        
            }
        $Out | Select-Object LogName, ComputerName, EventID, @{Name ="ErrorLogIndex" ; Expression={$_.Index}}, @{Name ="ErrorLogSource" ; Expression={$_.Source}}, Category, TimeWritten, EntryType,@{Name ="ErrorMessage" ; Expression={$_.Message}}   | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $MonitoringServerDatabase -Schema "SQLServer" -Table "WindowsLogs" -Truncate # -FireTriggers #-AutoCreateTable
         
        Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "MONITOR-03" -SqlInstance $SqlInstance -Database $Database -StartDateTime $StartDateTime -EndDateTime (get-date) -LoggingGUID $LoggingGUID -InitialLog 0
        
        Remove-Variable DaysAway
        Remove-Variable ComputerNames
        Remove-Variable ComputerName
        Remove-Variable Log
        Remove-Variable WindowsLogs
        Remove-Variable MonitoringServerDetails
        Remove-Variable TargetServerInstance
        Remove-Variable MonitoringServerDatabase
        Remove-Variable ParentTask
        Remove-Variable TaskName
        Remove-Variable LoggingGUID
        Remove-Variable StartDateTime
        Remove-Variable Out        
    }

FUNCTION Write-SQLMonitoringBufferPoolUsage
    {

            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.MonitoringDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "BufferPoolUsage"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $List                    = Get-SQLMonitoringServerList -InstanceRole PROD -InstanceType 'ALL' | Select-Object SQLInstance | Where-Object {$_.SQLInstance -ne "TIO-DBS-01"}
            $LoggingGUID             = New-Guid
            $SQLQuery                = 
            "
            SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
            SET NOCOUNT ON;
            IF OBJECT_ID('TempDB..#Objects','U') IS NOT NULL DROP TABLE #Objects;
            CREATE TABLE #Objects
                (
                     ID				  INT IDENTITY(1,1)		NOT NULL PRIMARY KEY CLUSTERED
                    ,AllocationUnitId BIGINT				NOT NULL
                    ,DatabaseName     VARCHAR(258)			NOT NULL
                    ,IndexName        VARCHAR(128)			NOT NULL
                    ,TableName        VARCHAR(517)			NOT NULL
                    ,isHeap			  BIT					NOT NULL
                    ,PartitionNumber  INT					NOT NULL
                    ,IndexRows		  BIGINT				NOT NULL
                    ,TableRows		  BIGINT				NOT NULL
                );
            INSERT INTO #Objects
                (
                     AllocationUnitId
                    ,DatabaseName
                    ,IndexName
                    ,TableName
                    ,isHeap
                    ,PartitionNumber
                    ,IndexRows
                    ,TableRows
                )
            EXEC sys.sp_MSforeachdb '
            SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
            SET NOCOUNT ON;
            USE [?]
            SELECT 
                alu.allocation_unit_id AllocationUnitId
                ,QUOTENAME(DB_NAME(),''['') DatabaseName
                ,ISNULL(ixs.name,''HEAP'') IndexName
                ,QUOTENAME(sch.name,''['') + ''.'' + QUOTENAME(obj.name,''['') TableName
                ,CASE WHEN part1.index_id = 0 THEN 1 ELSE 0 END isHeap
                ,part.partition_number PartitionNumber
                ,part.rows IndexRows
                ,part1.rows TableRows
            FROM  
                sys.allocation_units Alu
            JOIN
                sys.partitions Part
            ON
                Alu.container_id = Part.partition_id
            JOIN
                sys.indexes Ixs
            ON
                Part.index_id = Ixs.index_id
            AND
                Part.object_id = Ixs.object_id
            JOIN
                sys.objects Obj
            ON
                Part.object_id = Obj.object_id
            JOIN
                sys.schemas Sch
            ON	
                Obj.schema_id = Sch.schema_id
            JOIN
                sys.partitions part1
            ON
                part.object_id = Part1.object_id
            AND
                part1.index_id <= 1
            --WHERE
            --	Obj.type = ''U'''
            
            ;WITH Cte AS
                (	 
                    SELECT	 
                         BDS.allocation_unit_id
                         ,BDS.database_id
                        ,CAST(SUM(CAST(BDS.free_space_in_bytes AS FLOAT)/1024/1024/1024) AS NUMERIC(20,4)) FreeSpaceInBytes
                        ,CAST((SUM(CASE WHEN BDS.is_modified = 1 THEN 1 ELSE 0 END) * 8.0)/1024.0/1024.0 AS NUMERIC(20,4))DirtySpaceFB
                        ,CAST((SUM(CASE WHEN BDS.is_modified = 0 THEN 1 ELSE 0 END) * 8.0)/1024.0/1024.0 AS NUMERIC(20,4))CleanSpaceGB
                        ,CAST((COUNT(*) * 8.0)/1024.0/1024.0 AS NUMERIC(20,4))TotalSpaceGB
                        ,(((COUNT(*) * 8.0)/1024.0/1024.0)/SUM((COUNT(*) * 8.0)/1024.0/1024.0)OVER())*100 PerofBufferCache
                    FROM  
                        sys.dm_os_buffer_descriptors BDS
                    --JOIN
                    --	#Objects OS
                    --ON
                    --	BDS.allocation_unit_id = OS.AllocationUnitId
                    --AND
                    --	OS.DatabaseName = QUOTENAME(DB_NAME(BDS.database_id),'[')
                    GROUP BY
                         BDS.allocation_unit_id
                         ,BDS.database_id
                )
            ,	Cte1 AS
                (
                    SELECT 
                         @@SERVERNAME SQLInstance
                        ,DatabaseName
                        ,UPPER(CASE WHEN DatabaseName = '[TempDB]' THEN 'TEMPDBINDEX' ELSE IndexName END) IndexName
                        ,UPPER(CASE WHEN DatabaseName = '[TempDB]' THEN 'TEMPDBTABLE' ELSE TableName END) TableName
                
                        ,MAX(CAST(isHeap AS SMALLINT)) isHeap
                        ,MAX(PartitionNumber)  PartitionNumber
                        ,SUM(IndexRows)		   IndexRows
                        ,SUM(TableRows)		   TableRows
                        ,SUM(FreeSpaceInBytes) FreeSpaceInBytes
                        ,SUM(DirtySpaceFB)	   DirtySpaceFB
                        ,SUM(CleanSpaceGB)	   CleanSpaceGB
                        ,SUM(TotalSpaceGB)	   TotalSpaceGB
                        ,SUM(PerofBufferCache) PerofBufferCache
                    FROM  
                        Cte
                    JOIN
                        #Objects Obj
                    ON
                        QUOTENAME(DB_NAME(Cte.database_id),'[') = Obj.DatabaseName
                    AND
                        Cte.allocation_unit_id = obj.AllocationUnitId
                    GROUP BY
                         DatabaseName
                        ,UPPER(CASE WHEN DatabaseName = '[TempDB]' THEN 'TEMPDBINDEX' ELSE IndexName END) 
                        ,UPPER(CASE WHEN DatabaseName = '[TempDB]' THEN 'TEMPDBTABLE' ELSE TableName END) 
                
                    HAVING
                        SUM(PerofBufferCache) >= 0.01
                )
            SELECT 
                 Cte1.SQLInstance
                ,Cte1.DatabaseName
                ,Cte1.IndexName
                ,Cte1.TableName
                ,CHECKSUM('SHA2_512',@@SERVERNAME + QUOTENAME(DatabaseName,'[') + CASE WHEN DatabaseName = '[TempDB]' THEN 'TEMPDBINDEX' ELSE IndexName END + CASE WHEN DatabaseName = '[TempDB]' THEN 'TEMPDBTABLE' ELSE TableName END + CAST(CAST(isHeap AS SMALLINT) AS CHAR(1))) ObjectChecksum
                ,Cte1.isHeap
                ,Cte1.PartitionNumber
                ,Cte1.IndexRows
                ,Cte1.TableRows
                ,Cte1.FreeSpaceInBytes
                ,Cte1.DirtySpaceFB
                ,Cte1.CleanSpaceGB
                ,Cte1.TotalSpaceGB
                ,Cte1.PerofBufferCache
                ,SYSDATETIME() CollectionDateTime
            FROM  
                Cte1;
            "

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "Monitor-03" -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         
            $Output = Invoke-DbaQuery -SqlInstance  $List.SqlInstance -Query $SQLQuery
            $Output | Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable -FireTriggers
            

            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "Monitor-03" -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE List                    
            REMOVE-VARIABLE LoggingGUID             
            REMOVE-VARIABLE SQLQuery                
            REMOVE-VARIABLE Out                
    };

FUNCTION Write-SQLMonitoringPendingIOs
    {
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.MonitoringDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "PendingIOs"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $List                    = Get-SQLMonitoringServerList -InstanceRole PROD -InstanceType 'ALL' | Select-Object SQLInstance
            $LoggingGUID             = New-Guid
            $SQLQuery                = 
            "
            SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
            SET NOCOUNT ON;
            SELECT
                 @@SERVERNAME SQLInstance
                ,DB_NAME(mf.database_id) DatabaseName
                ,mf.physical_name PhysicalName
                ,CHECKSUM(@@SERVERNAME + DB_NAME(mf.database_id) + mf.physical_name) FileChecksum
                ,Ipir.io_type IOType
                ,SUM(Ipir.io_pending) TotalPendingIOs
                ,SUM(Ipir.io_pending_ms_ticks) TotalPendingMSTicks
                ,SYSDATETIME() CollectionDateTime
            FROM
                sys.dm_io_pending_io_requests Ipir
            JOIN
                sys.dm_io_virtual_file_stats(NULL,NULL) AS Vfs
            ON
                Ipir.io_handle = Vfs.file_handle
            JOIN
                sys.master_files AS mf
            ON
                Vfs.database_id = mf.database_id
            AND
                Vfs.file_id = mf.file_id
            GROUP BY
                 mf.database_id
                ,mf.physical_name
                ,Ipir.io_type;
            
            
            "

            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "Monitor-03" -StartDateTime $StartDateTime -LoggingGUID $LoggingGUID -InitialLog 1         

            Invoke-DbaQuery -SqlInstance  $List.SqlInstance -Query $SQLQuery|  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable -FireTriggers
            

            
            Write-SQLMonitoringLoggingTable   -TaskName $TaskName -ParentTask $ParentTask -ComputerName "Monitor-03" -StartDateTime $StartDateTime -EndDateTime (Get-Date) -LoggingGUID $LoggingGUID -InitialLog 0

            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE List                    
            REMOVE-VARIABLE LoggingGUID             
            REMOVE-VARIABLE SQLQuery                
    };

    function Send-MorningChecksGetMissingBackups
    {
        $SQLInstances = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailOutput  = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_MissingBackups @MorningChecks = 1;"
        $EmailOutput  = $EmailOutput | Sort-Object SQLInstance, LastBackupDtTime, DatabaseName | ConvertTo-HTML -Property SqlInstance, DatabaseName, LastBackupDtTime, LastBackupType -Title "Missing Backups" -PreContent "<h1>Missing Backups</h1>"    
        $EmailHeader  = Get-SQLMonitoringEmailHeader
        
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$EmailOutput " | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Missing Backups" -body $SQLOutput -BodyAsHtml
        Remove-Variable SQLInstances
        Remove-Variable EmailOutput
        Remove-Variable SQLOutput
		REMOVE-VARIABLE EmailHeader
    }        
function Send-MorningChecksGetMissingCheckDBs
    {
        $SQLInstances = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailOutput  = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetMissingCheckDBs;"
        $EmailOutput  = $EmailOutput | Sort-Object SQLInstance, LastGoodCheckDbTime, DatabaseName | ConvertTo-HTML -Property SqlInstance, DatabaseName, LastGoodCheckDbTime -Title "Missing CheckDBs" -PreContent "<h1>Missing CheckDBs</h1>"    
        $EmailHeader  = Get-SQLMonitoringEmailHeader
        
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$EmailOutput " | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Missing CheckDBs" -body $SQLOutput -BodyAsHtml
        Remove-Variable SQLInstances
        Remove-Variable EmailOutput
        Remove-Variable SQLOutput
		REMOVE-VARIABLE EmailHeader
    }
function Send-MorningChecksGetFailedJobs
    {
        $SQLInstances = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailOutput  = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetFailedJobs @MorningChecks = 1;"
        $EmailOutput  = $EmailOutput | Sort-Object SQLInstance, RunDurationInMins, DatabaseName | ConvertTo-HTML -Property SQLInstance, JobName , StepName, StartDate ,EndDate , RunDurationInMins ,OperatorEmailed ,RetriesAttempted  ,JobMessage -Title "Failed Jobs" -PreContent "<h1>Failed Jobs</h1>"    
        $EmailHeader  = Get-SQLMonitoringEmailHeader
        
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$EmailOutput " | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Failed Jobs" -body $SQLOutput -BodyAsHtml
        Remove-Variable SQLInstances
        Remove-Variable EmailOutput
        Remove-Variable SQLOutput
		REMOVE-VARIABLE EmailHeader
    }    
function Send-MorningChecksGetSlowJobs
    {
        $SQLInstances = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailOutput  = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetSlowJobs @MorningChecks = 1;"
        $EmailOutput  = $EmailOutput | Sort-Object PercChange, SQLInstance, RunDuration  | ConvertTo-HTML -Property SQLInstance, JobName, StepName, StartDate, EndDate, RunDuration, NormalRunDuration, PercChange, JobStatus, OperatorEmailed, RetriesAttempted, JobMessage -Title "Slow Jobs" -PreContent "<h1>Slow Jobs</h1>"    
        $EmailHeader  = Get-SQLMonitoringEmailHeader
        
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$EmailOutput " | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Slow Jobs" -body $SQLOutput -BodyAsHtml
        Remove-Variable SQLInstances
        Remove-Variable EmailOutput
        Remove-Variable SQLOutput
		REMOVE-VARIABLE EmailHeader
    }    
function Send-MorningChecksDatabaseGrowths
    {
        $SQLInstances = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailOutput  = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetDBGrowth @MorningChecks = 1;"
        $EmailOutput  = $EmailOutput | Sort-Object SQLInstance, FileSpaceChangeGB -Descending  | ConvertTo-HTML -Property SQLInstance, DatabaseName, TypeDescription, LogicalName, FileState, FileSizeGB, CurrentFileSizeGB, PreviousFileSizeGB, CurrentUsedSpaceGB, PreviousUsedSpaceGB, FileSpaceChangePerc , UsedSpaceChangePerc, FileSpaceChangeGB, UsedSpaceChangeGB -Title "Database Growth" -PreContent "<h1>Database Growth</h1>"    
        $EmailHeader  = Get-SQLMonitoringEmailHeader
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$EmailOutput " | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Slow Jobs" -body $SQLOutput -BodyAsHtml
        Remove-Variable SQLInstances
        Remove-Variable EmailOutput
        Remove-Variable SQLOutput
		REMOVE-VARIABLE EmailHeader
    }
function Send-MorningChecksDiskSpaceDecrease
    {
        $SQLInstances = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailOutput  = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetStorageSpaceDecrease @MorningChecks = 1;"
        $EmailOutput  = $EmailOutput | Sort-Object SQLInstance,  SpacedUsedChange -Descending  | ConvertTo-HTML -Property ServerName, VolumeLabel, CollectionDateTime, PercSpaceFree, SpaceFreeGB, SpaceUsedGB, PreviousSpaceUsedGB, SpacedUsedChange, TotalDiskSpaceGB, PreviousTotalDiskSpaceGB, TotalDiskSpaceChange -Title "Disk Space Decrease" -PreContent "<h1>Disk Space Decrease</h1>"    
        $EmailHeader  = Get-SQLMonitoringEmailHeader
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$EmailOutput " | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Disk Space Decrease" -body $SQLOutput -BodyAsHtml
        Remove-Variable SQLInstances
        Remove-Variable EmailOutput
        Remove-Variable SQLOutput
		REMOVE-VARIABLE EmailHeader
    } 
    function Send-MorningChecksLowDiskSpace
    {
        $SQLInstances = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailOutput  = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetStorageSpaceDecrease @MorningChecks = 1;"
        $EmailOutput  = $EmailOutput | Sort-Object PercSpaceFree -Descending  | ConvertTo-HTML -Property ServerName, VolumeLabel, PercSpaceFree, SpaceFreeGB, SpaceUsedGB, TotalDiskSpaceGB -Title "Low Disk Space" -PreContent "<h1>Low Disk Space</h1>"    
        $EmailHeader  = Get-SQLMonitoringEmailHeader
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$EmailOutput " | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Low Disk Space" -body $SQLOutput -BodyAsHtml
        Remove-Variable SQLInstances
        Remove-Variable EmailOutput
        Remove-Variable SQLOutput
		REMOVE-VARIABLE EmailHeader
    }   
function Send-MorningChecksGetDeadlocks
    {
        $SQLInstances           = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailHeader            = Get-SQLMonitoringEmailHeader
        $DeadlockSummary        = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetDeadlockSummary @MorningChecks = 1;"            | Sort-Object SQLInstance,Deadlocks            | ConvertTo-HTML -Property SQLInstance, Deadlocks, TotalDeadlocks                    -Title "Deadlock Summary" -PreContent "<h1>Deadlock Summary</h1>"    
        $DeadlockClientSummary  = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetDeadlockSummaryByClientApp @MorningChecks = 1;" | Sort-Object Deadlocks -Descending            | ConvertTo-HTML -Property SQLInstance,  VictimClientApp, WinnerClientApp, Deadlocks -Title "Deadlock Client Summary" -PreContent "<h1>Deadlock Client Summary</h1>"    
        $DeadlockTableSummary   = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetDeadlockSummaryByTable @MorningChecks = 1;"     | Sort-Object Deadlocks -Descending            | ConvertTo-HTML -Property SQLInstance,  VictimTable, WinnerTable, Deadlocks         -Title "Deadlock Table Summary" -PreContent "<h1>Deadlock Table Summary</h1>"    
        $DeadlockProcSummary    = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetDeadlockSummaryByProc @MorningChecks = 1;"      | Sort-Object Deadlocks -Descending            | ConvertTo-HTML -Property SQLInstance,  VictimProc, WinnerProc, Deadlocks           -Title "Deadlock Proc Summary" -PreContent "<h1>Deadlock Proc Summary</h1>"    
        $DeadlockOutput         = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetDeadlockOutput @MorningChecks = 1;"             | Sort-Object SQLInstance, VictimDatabaseName  | ConvertTo-HTML -Property SQLInstance , VictimDatabaseName , WinnerDatabaseName , BatchStartedVictim , BatchStartedWinner ProcessIDVictim , ProcessIDWinner , WaitTimeVictim , WaitTimeWinner , LoginVictim , LoginWinner , ClientAppVictim , ClientAppWinner , hostnameVictim , hostnameWinner , ProcNameVictim , ProcNameWinner , WaitResoureVictim , WaitResoureWinner , TableNameVictim , TableNameWinner , IndexNameVictim , IndexNameWinner, wasParrallel  -Title "Deadlock Output" -PreContent "<h1>Deadlock Output</h1>"    
        
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$DeadlockSummary $DeadlockClientSummary $DeadlockTableSummary $DeadlockOutput" | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Deadlock Summary" -body $SQLOutput -BodyAsHtml
		
        Remove-Variable SQLInstances
        Remove-Variable DeadlockSummary
        Remove-Variable SQLOutput
        Remove-Variable DeadlockSummary        
        Remove-Variable DeadlockClientSummary  
        Remove-Variable DeadlockTableSummary   
        Remove-Variable DeadlockProcSummary    
        Remove-Variable DeadlockOutput 
		REMOVE-VARIABLE EmailHeader        
    }   
function Send-MorningChecksGetSQLErrorLog
    {
        $SQLInstances           = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailHeader            = Get-SQLMonitoringEmailHeader
        $SQLOutput              = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetSQLLog;"            | Sort-Object SQLInstance, LogDate  
        $ExportOutputPath                 = "C:\MountPoints\Misc\LOGGING\" + 'SQLErrorLog-{0:yyyy-MM-dd}.csv' -f  (Get-Date)
        $SQLOutput | Export-Csv -LiteralPath $ExportOutputPath -NoTypeInformation
        $SQLOutput              = $SQLOutput | ConvertTo-HTML -Property LogDate, SQLInstance, ErrorLogSource, ProcessInfo, HasErrors, ErrorText   -Title "SQL Error Log Output" -PreContent "<h1>SQL Error Log Output</h1>"    
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$SQLOutput" | Out-String #   | Out-GridView    
        
		Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Error Log Output" -body $SQLOutput -BodyAsHtml -Attachments $ExportOutputPath
        
		Remove-Item $ExportOutputPath
        Remove-Variable SQLInstances
        Remove-Variable SQLOutput
        REMOVE-VARIABLE EmailHeader
        Remove-Variable ExportOutputPath
    }
function Send-MorningChecksGetWindowsLog
    {
        $SQLInstances           = Get-SQLMonitoringServerList  -InstanceRole "Prod" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailHeader            = Get-SQLMonitoringEmailHeader
        $SQLOutput              = Invoke-DbaQuery -SqlInstance  "Monitor-03\SQLServer1" -Database "DatabaseMonitoring" -Query "EXEC MorningChecks.usp_GetErrorLog;"            | Sort-Object SQLInstance, DateTime  
        $ExportOutputPath                 = "C:\MountPoints\Misc\LOGGING\" + 'WindowsLog-{0:yyyy-MM-dd}.csv' -f  (Get-Date)
        $SQLOutput | Export-Csv -LiteralPath $ExportOutputPath -NoTypeInformation
        $SQLOutput              = $SQLOutput | ConvertTo-HTML -Property DateTime, ComputerName, EventID, LogName, Category, EntryText, ErrorMessage   -Title "Windows Log Output" -PreContent "<h1>Windows Log Output</h1>"    
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$SQLOutput" | Out-String #   | Out-GridView    
        
		Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Windows Log Output" -body $SQLOutput -BodyAsHtml -Attachments $ExportOutputPath
        
		Remove-Item $ExportOutputPath
        Remove-Variable SQLInstances
        Remove-Variable SQLOutput
        REMOVE-VARIABLE EmailHeader
        Remove-Variable ExportOutputPath
    }      
function Email-WeeklyChecksGetOutOfDatePatches
    {
        $SQLInstances = Get-SQLMonitoringServerList  -InstanceRole "ALL" -InstanceType "ALL"   | SELECT-object SqlInstance
        $EmailOutput  = Test-DbaBuild -SqlInstance $SQLInstances.SQLInstance -Latest -Update | Where-Object {$_.Compliant -EQ $false} | Select-Object SQLInstance, SupportedUntil, SPLevel, NameLevel, KBLevel, BuildLevel, BuildTarget, Compliant
        $EmailOutput  = $EmailOutput | Sort-Object SupportedUntil, SQLInstance| ConvertTo-HTML -Property SQLInstance, SupportedUntil, SPLevel, NameLevel, KBLevel, BuildLevel, BuildTarget, Compliant -Title "Instances Missing Patches" -PreContent "<h1>Instances Missing Patches</h1>"    
        $EmailHeader  = Get-SQLMonitoringEmailHeader
        
        $SQLOutput    =  ConvertTo-HTML -Head $EmailHeader -Body "$EmailOutput " | Out-String #   | Out-GridView    
        Send-MailMessage -To "Krishn.Patel@verastar.co.uk" -From "SQLMorningChecks@verastar.co.uk" -SMTPServer "Mail-01" -Subject "Instances Missing Patches" -body $SQLOutput -BodyAsHtml
        
		Remove-Variable SQLInstances
        Remove-Variable EmailOutput
        Remove-Variable SQLOutput
    }    

    FUNCTION Get-SQLMonitoringCheckEmailSubmissions
    {   
        PARAM
        (     
             [Parameter(Mandatory=$TRUE)]  [STRING]  $AlertID
            ,[Parameter(Mandatory=$TRUE)]  [ARRAY]   $Results
            ,[Parameter(Mandatory=$TRUE)]  [ARRAY]   $RepeatFrequency
        )
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.MonitoringDatabase
        $ImportGUID              = new-guid
        $DtTimeCollected         = get-date
        $Results | select-object @{Name ="AlertID"; Expression={($AlertID)}}, HashedEmailSubmission, @{Name ="DateTimeSubmitted"; Expression={($DtTimeCollected)}}, @{Name ="RepeatFrequencySecs"; Expression={($RepeatFrequency)}},@{Name ="ImportBatchGUID"; Expression={($ImportGUID)}}  -Unique | Write-DbaDataTable -SqlInstance $MonitoringInstanceName -Database Staging -Schema Staging -Table EmailSubmissions   -FireTriggers
        $HashedEmailSubmissionS = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName  -Query "SELECT HashedEmailSubmission FROM Alerting.EmailSubmissions WHERE isMostCurrent = 1 AND DateTimeSubmitted >= DATEADD(SECOND,-5,SYSDATETIME()) AND AlertID = $AlertID AND ImportBatchGUID = '$ImportGUID'"
        return $Results | Where-Object {$_.HashedEmailSubmission -in $HashedEmailSubmissionS.HashedEmailSubmission}
        
        REMOVE-VARIABLE MonitoringServerDetails
        REMOVE-VARIABLE MonitoringInstanceName
        REMOVE-VARIABLE MonitoringDatabaseName
        REMOVE-VARIABLE ImportGUID
        REMOVE-VARIABLE DtTimeCollected
        REMOVE-VARIABLE Results
        REMOVE-VARIABLE HashedEmailSubmissionS
        REMOVE-VARIABLE AlertID
        REMOVE-VARIABLE Results
        REMOVE-VARIABLE RepeatFrequency    
    }
    
    
    function Send-SQLMonitoringBlockingAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.MonitoringDatabase
        $AlertDetails            = Get-SQLMonitoringAlertDetails "LONG TERM BLOCKING"
        $ToEmailAddress          = $AlertDetails.ToEmailAddress 
        $FromEmailAddress        = $AlertDetails.FromEmailAddress
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "Long Term Blocking"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'Prod' -InstanceType 'ALL' # | Where-Object {$_.SQLInstance -ne "EICC-DBS"}
        $Query = 
        "
        
            SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
            ;WITH Cte AS
            (
                SELECT
                    ROW_NUMBER()OVER(ORDER BY (SELECT 100)) RowNum
                    ,SERVERPROPERTY('ComputerNamePhysicalNetBIOS') ComputerName
                    ,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName
                    ,@@SERVERNAME SQLInstance
                    ,'BLOCKED' isBlocker
                    ,Req.session_id SessionID
                    ,Req.start_time RequestStarttime
                    ,Req.status RequestStatus
                    ,Req.command Command
                    ,DB_NAME(Req.database_id) DatabaseName
                    ,Req.blocking_session_id BlockingSessionID
                    ,NULL SessionBlockedBySPID
                    ,Req.wait_type WaitType
                    ,Req.wait_time WaitTimeMS
                    ,(FLOOR(Req.wait_time / (1000 * 60)) % 60)  WaitTimeinMins
                    ,Req.last_wait_type LastWaitType
                    ,Req.wait_resource WaitResource
                    ,Req.open_transaction_count OpenTransactionCount
                    ,Req.cpu_time CPUTime
                    ,Req.total_elapsed_time TotalElapsedTime
                    ,Req.reads Reads
                    ,Req.writes Writes
                    ,Req.logical_reads LogicalReads
                    ,Sess.host_name HostName
                    ,Sess.program_name ProgramName
                    ,Sess.client_interface_name ClientInterfaceName
                    ,Sess.login_name LoginName
                    ,Sess.nt_domain ntDomain
                    ,Sess.nt_user_name ntUserName
                    ,CHECKSUM('BLOCKING' + CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS')AS VARCHAR) + CAST(ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))AS VARCHAR) + CAST(@@SERVERNAME AS VARCHAR) +  CAST(req.session_id AS VARCHAR(255)) + CAST(req.blocking_session_id AS VARCHAR(255)) + CAST(req.start_time AS VARCHAR(255))) HashedEmailSubmission
                FROM
                    sys.dm_exec_requests req
                JOIN
                    sys.dm_exec_sessions sess
                ON
                    req.session_id = sess.session_id
                LEFT JOIN
                    sys.dm_exec_requests Bloc
                ON
                    req.session_id = Bloc.blocking_session_id
                LEFT JOIN
                    sys.dm_exec_sessions SessBloc
                ON
                    req.blocking_session_id = SessBloc.session_id
                WHERE
                    sess.is_user_process = 1
                AND
                    (
                        req.blocking_session_id > 1 
                AND
                        Req.wait_time > 15000
                    )
                UNION
                SELECT
                    ROW_NUMBER()OVER(ORDER BY (SELECT 100)) RowNum
                    ,SERVERPROPERTY('ComputerNamePhysicalNetBIOS') ComputerName
                    ,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName
                    ,@@SERVERNAME SQLInstance
                    ,'BLOCKER'  isBlocker
                    ,req.session_id SessionID
                    ,Req.start_time RequestStarttime
                    ,Req.status RequestStatus
                    ,Req.command Command
                    ,DB_NAME(Req.database_id) DatabaseName
                    ,NULL BlockingSessionID
                    ,bloc.session_id  SessionBlockedBySPID
                    ,NULL WaitType
                    ,NULL WaitTimeMS
                    ,NULL WaitTimeinMins
                    ,NULL LastWaitType
                    ,NULL WaitResource
                    ,Req.open_transaction_count OpenTransactionCount
                    ,Req.cpu_time CPUTime
                    ,Req.total_elapsed_time TotalElapsedTime
                    ,Req.reads Reads
                    ,Req.writes Writes
                    ,Req.logical_reads LogicalReads
                    ,Sess.host_name HostName
                    ,Sess.program_name ProgramName
                    ,Sess.client_interface_name ClientInterfaceName
                    ,Sess.login_name LoginName
                    ,Sess.nt_domain ntDomain
                    ,Sess.nt_user_name ntUserName
                    ,CHECKSUM( 'BLOCKING' +CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS')AS VARCHAR) + CAST(ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))AS VARCHAR) + CAST(@@SERVERNAME AS VARCHAR) + CAST(bloc.session_id AS VARCHAR(255)) + CAST(req.session_id  AS VARCHAR(255)) + CAST(bloc.start_time AS VARCHAR(255)) )
                FROM
                    sys.dm_exec_requests req
                JOIN
                    sys.dm_exec_sessions sess
                ON
                    req.session_id = sess.session_id
                JOIN
                    sys.dm_exec_requests Bloc
                ON
                    req.session_id = Bloc.blocking_session_id
                LEFT JOIN
                    sys.dm_exec_sessions SessBloc
                ON
                    req.blocking_session_id = SessBloc.session_id
                WHERE
                    sess.is_user_process = 1
                AND
                    (
                        Bloc.session_id IS NOT NULL
                AND
                        Bloc.wait_time > 15000
                    )
                UNION
    
                SELECT
                    ROW_NUMBER()OVER(ORDER BY (SELECT 100)) RowNum
                    ,SERVERPROPERTY('ComputerNamePhysicalNetBIOS') ComputerName
                    ,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName
                    ,@@SERVERNAME SQLInstance
                    ,'BLOCKER' isBlocker
                    ,Sess.session_id SessionID
                    ,sess.last_request_end_time RequestStarttime
                    ,Sess.status RequestStatus
                    ,req.command Command
                    ,DB_NAME(Sess.database_id) DatabaseName
                    ,NULL BlockingSessionID
                    ,req.session_id SessionBlockedBySPID
                    ,NULL WaitType
                    ,NULL WaitTimeMS
                    ,NULL WaitTimeinMins
                    ,NULL LastWaitType
                    ,NULL WaitResource
                    ,Sess.open_transaction_count OpenTransactionCount
                    ,Sess.cpu_time CPUTime
                    ,Sess.total_elapsed_time TotalElapsedTime
                    ,Sess.reads Reads
                    ,Sess.writes Writes
                    ,Sess.logical_reads LogicalReads
                    ,Sess.host_name HostName
                    ,Sess.program_name ProgramName
                    ,Sess.client_interface_name ClientInterfaceName
                    ,Sess.login_name LoginName
                    ,Sess.nt_domain ntDomain
                    ,Sess.nt_user_name ntUserName
                    ,CHECKSUM('BLOCKING' +CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS')AS VARCHAR) + CAST(ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))AS VARCHAR) + CAST(@@SERVERNAME AS VARCHAR) +  CAST(req.session_id AS VARCHAR(255)) + CAST(req.blocking_session_id AS VARCHAR(255)) + CAST(req.start_time AS VARCHAR(255)) ) HashedBlockingSession
                FROM
                    sys.dm_exec_sessions sess
                JOIN
                    sys.dm_exec_requests req
                ON
                    sess.session_id = req.blocking_session_id
                LEFT JOIN
                    sys.dm_exec_requests Sleeping
                ON
                    sess.session_id = Sleeping.session_id
                WHERE
                    sess.is_user_process = 1
                AND
                        req.wait_time > 15000
                AND
                    Sleeping.session_id IS NULL
            )
            SELECT 
            Cte.RowNum
            ,Cte.ComputerName
            ,Cte.InstanceName
            ,Cte.SQLInstance
            ,Cte.DatabaseName
            ,Cte.isBlocker
            ,Cte.SessionID
            ,Cte.RequestStarttime
            ,Cte.RequestStatus
            ,Cte.Command
            ,Cte.BlockingSessionID
            ,Cte.SessionBlockedBySPID
            ,Cte.WaitType
            ,Cte.WaitTimeMS
            ,Cte.WaitTimeinMins
            ,Cte.LastWaitType
            ,Cte.WaitResource
            ,Cte.OpenTransactionCount
            ,Cte.CPUTime
            ,Cte.TotalElapsedTime
            ,Cte.Reads
            ,Cte.Writes
            ,Cte.LogicalReads
            ,Cte.HostName
            ,Cte.ProgramName
            ,Cte.ClientInterfaceName
            ,Cte.LoginName
            ,Cte.ntDomain
            ,Cte.ntUserName
            ,NULL QueryText --st.text QueryText
            ,Cte.HashedEmailSubmission
            FROM  
            Cte
            LEFT JOIN
            sys.dm_exec_requests req
            ON	
            Cte.SessionID = req.session_id
            OUTER APPLY 
            sys.dm_exec_sql_text(req.sql_handle) as st 
            OUTER APPLY 
            sys.dm_exec_query_plan(req.plan_handle)   qp
    
        "
        $Results = 
            foreach ($Inst in $SQLList)
        {
            Invoke-DbaQuery -SqlInstance $Inst.SQLInstance  -Query $Query 
            
        }
        if ($Results.RowNum.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object isBlocker, SessionID, Command, ComputerName, InstanceName, SQLInstance, DatabaseName, RequestStarttime, RequestStatus,  BlockingSessionID, SessionBlockedBySPID, WaitType, WaitTime, WaitTimeinMins, LastWaitType, WaitResource, OpenTransactionCount, CPUTime, TotalElapsedTime, Reads, Writes, LogicalReads, HostName, ProgramName, ClientInterfaceName, LoginName, ntDomain, ntUserName,QueryText|  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.RowNum.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE MonitoringInstanceName  
            REMOVE-VARIABLE MonitoringDatabaseName  
            REMOVE-VARIABLE AlertDetails            
            REMOVE-VARIABLE ToEmailAddress          
            REMOVE-VARIABLE FromEmailAddress        
            REMOVE-VARIABLE RepeatFrequency         
            REMOVE-VARIABLE AlertID                 
            REMOVE-VARIABLE SMTPServer              
            REMOVE-VARIABLE Subject                 
            REMOVE-VARIABLE EmailHeader             
            REMOVE-VARIABLE SQLList                 
            REMOVE-VARIABLE Query   
            REMOVE-VARIABLE Inst
            REMOVE-VARIABLE Results
            REMOVE-VARIABLE SQLOutput
    }
    
    
    function Send-SQLMonitoringLongRunningQueriesAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.MonitoringDatabase
        $MonitoringDBName        = $MonitoringServerDetails.StagingDatabase
        $AlertDetails            = Get-SQLMonitoringAlertDetails "LONG RUNNING QUERIES"
        $ToEmailAddress          = $AlertDetails.ToEmailAddress      # Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT TOP 1 EmailAddress FROM SQLServer.Alerting WHERE isActive = 1 AND AlertDescription = 'DBA'"
        $FromEmailAddress        = $AlertDetails.FromEmailAddress        # Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDatabaseName -Query "SELECT TOP 1 EmailAddress FROM SQLServer.Alerting WHERE isActive = 1 AND AlertDescription = 'DBA'"
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "Long Running Queries"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'Prod' -InstanceType 'All'
        $Query                   = "
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        SELECT
            SERVERPROPERTY('ComputerNamePhysicalNetBIOS')ComputerName
           ,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName        
           ,@@SERVERNAME					SqlInstance   		
           ,req.session_id					SessionID
           ,req.request_id					RequestID
           ,Conn.connection_id				ConnectionID
           ,req.start_time					StartTime
           ,DATEDIFF(SECOND,req.start_time,SYSDATETIME()) DurationinSeconds
           ,req.status                      RequestStatus
           ,req.command						Command
           ,DB_NAME(req.database_id)        DatabaseName
           ,req.user_id						UserID
           ,req.blocking_session_id			BlockingSessionID
           ,req.wait_time					WaitTime
           ,req.wait_type					WaitType
           ,req.last_wait_type				LastWaitType
           ,req.open_transaction_count		OpenTransactionCount
           ,req.percent_complete			PercentComplete
           ,req.cpu_time					CpuTime
           ,req.total_elapsed_time			totalElapsedTime
           ,req.reads						Reads
           ,req.writes						Writes
           ,req.logical_reads				LogicalReads
           ,sess.login_time					LoginTime
           ,sess.host_name					HostName
           ,sess.program_name				ProgramName
           ,sess.host_process_id			HostProcessID
           ,sess.client_version				ClientVersion
           ,sess.client_interface_name		ClientInterfaceName
           ,sess.login_name					LoginName
           ,sess.nt_domain					ntDomain
           ,sess.nt_user_name				ntUserName
           ,SYSDATETIME() CollectionDateTime
           ,CHECKSUM('LONG RUNNING QUERIES' + CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS VARCHAR(255)) + CAST(@@SERVERNAME  AS VARCHAR(255))+  CAST(req.session_id AS VARCHAR(255)) + CAST(req.start_time AS VARCHAR(255))) HashedEmailSubmission
        FROM
               sys.dm_exec_requests req
        JOIN
               sys.dm_exec_sessions sess
        ON
               req.session_id = sess.session_id
        LEFT JOIN
            sys.dm_exec_connections Conn
        ON	
            req.connection_id = Conn.connection_id
        WHERE 
            sess.is_user_process = 1
        AND
            req.cpu_time >= CASE WHEN @@SERVERNAME = 'REP-01' THEN 30000 ELSE 15000 END
        AND 
            Command <> 'Backup Database'
        AND
            UPPER(sess.program_name) NOT LIKE '%PUBLISH%'
        AND
            UPPER(sess.program_name) NOT LIKE '%REPL%'
        AND
            UPPER(sess.program_name) NOT LIKE '%SQLAGENT - TSQL JOBSTEP%';        
        "
        $Results = Invoke-DbaQuery -SqlInstance $SQLList.SQLInstance -Query $Query 
        if ($Results.RowNum.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
    
        $SQLOutput = $Results| Select-Object SqlInstance, SessionID, StartTime, DurationinSeconds, RequestStatus, Command, DatabaseName, WaitTime, WaitType, LastWaitType, OpenTransactionCount, PercentComplete, CpuTime, totalElapsedTime, Reads, Writes, LogicalReads, LoginTime, HostName, ProgramName,  ClientInterfaceName, LoginName, ntDomain, ntUserName, CollectionDateTime, HashedEmailSubmission |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        
        if ($Results.RowNum.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
        REMOVE-VARIABLE MonitoringServerDetails 
        REMOVE-VARIABLE MonitoringInstanceName  
        REMOVE-VARIABLE MonitoringDatabaseName  
        REMOVE-VARIABLE MonitoringDBName        
        REMOVE-VARIABLE AlertDetails            
        REMOVE-VARIABLE ToEmailAddress          
        REMOVE-VARIABLE FromEmailAddress        
        REMOVE-VARIABLE RepeatFrequency         
        REMOVE-VARIABLE AlertID                 
        REMOVE-VARIABLE SMTPServer              
        REMOVE-VARIABLE Subject                 
        REMOVE-VARIABLE EmailHeader             
        REMOVE-VARIABLE SQLList                 
        REMOVE-VARIABLE Query
        REMOVE-VARIABLE Results              
        REMOVE-VARIABLE SQLOutput             
    }
    function Send-SQLMonitoringServicesDownAlert
    {
        Disable-SQLMonitoringSSLCertificates
        $MonitoringServerDetails  = Get-SQLMonitoringServer
        $TargetServerInstance     = $MonitoringServerDetails.ServerInstance
        $TargetDatabase           = $MonitoringServerDetails.StagingDatabase
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertName                = "SERVICES NOT RUNNING"
        $AlertDetails             = Get-SQLMonitoringAlertDetails $AlertName
        $ToEmailAddress           = $AlertDetails.ToEmailAddress      
        $FromEmailAddress         = $AlertDetails.FromEmailAddress        
        $RepeatFrequency          = $AlertDetails.RepeatFrequencySecs
        $AlertID                  = $AlertDetails.AlertID
        $SMTPServer               = "MAIL-01"
        $Subject                  = "SERVICES NOT RUNNING"
        $EmailHeader              = Get-SQLMonitoringEmailHeader
        $SensorList               = Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $MonitoringServerDatabase -Query "SELECT * FROM  PRTG.Sensors WHERE isServiceSensor = 1 AND isActive = 1;"
        $URL                      = "https://monitor-02/api/table.json?content=channels&columns=datetime,name,lastvalue_&id=&username=patelk1&passhash=2884036294"
        
    
    
    
                $FinalOutput = 
                foreach ($Sensor in $SensorList)
                    {
    
                            $SensorValue = $Sensor.SensorID
                            $TableName = "SensorID_" + $Sensor.SensorID
                            $URLToUse = $URL.Replace("id=","id=$SensorValue")
    
                            $Output = Invoke-WebRequest $urlTOUSE -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                            $JsonOutput = $Output |convertfrom-json -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                            $JsonOutput.Channels  | Where-Object {$_.name -eq "Operating State" -and $_.lastvalue_raw -ne "1"} | Select-Object @{Name ="SensorID" ; Expression={$SensorValue}} #@{Name ="CollectionDateTime" ; Expression={$_.datetime}},@{Name ="SensorID" ; Expression={$SensorValue}},@{Name ="ChannelName" ; Expression={$_.name}},@{Name ="CounterValue" ; Expression={$_.lastvalue_raw}} 
    
                            
                            Remove-Variable SensorValue
                            Remove-Variable TableName
                            Remove-Variable Output
                            Remove-Variable JsonOutput
    
                    }        
    
        $Results = $SensorList | Where-Object {$_.SensorID -in $FinalOutput.SensorID} | Select-Object @{Name ="DeviceName" ; Expression={$_.DeviceName}}, @{Name ="SensorName" ; Expression={$_.SensorName}}, @{Name ="PRTGSensorID" ; Expression={$_.PRTGSensorID}},@{Name ="AlertID"; Expression={($AlertID)}}, @{Name ="HashedEmailSubmission"; Expression={($_.PRTGSensorID)}}, @{Name ="DateTimeSubmitted"; Expression={(get-date)}}, @{Name ="RepeatFrequencySecs"; Expression={($RepeatFrequency)}}
    
        
        if ($Results.DeviceName.Count -gt 0)
            {
                $SQLOutput = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
            
        $SQLOutput = $SQLOutput| Select-Object  @{Name ="DeviceName" ; Expression={$_.DeviceName}}, @{Name ="SensorName" ; Expression={$_.SensorName}} |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        
        if ($Results.DeviceName.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
        Remove-Variable FinalOutput
    
        Remove-Variable Results
        Remove-Variable SQLOutput
        REMOVE-VARIABLE MonitoringServerDetails  
        REMOVE-VARIABLE TargetServerInstance     
        REMOVE-VARIABLE TargetDatabase           
        REMOVE-VARIABLE MonitoringServerDatabase 
        REMOVE-VARIABLE AlertName                
        REMOVE-VARIABLE AlertDetails             
        REMOVE-VARIABLE ToEmailAddress           
        REMOVE-VARIABLE FromEmailAddress         
        REMOVE-VARIABLE RepeatFrequency          
        REMOVE-VARIABLE AlertID                  
        REMOVE-VARIABLE SMTPServer               
        REMOVE-VARIABLE Subject                  
        REMOVE-VARIABLE EmailHeader              
        REMOVE-VARIABLE SensorList
        REMOVE-VARIABLE Sensor               
        REMOVE-VARIABLE URL                       
    }
    
    function Send-SQLMonitoringLowDiskSpaceAlert
    {
        Disable-SQLMonitoringSSLCertificates
        $MonitoringServerDetails  = Get-SQLMonitoringServer
        $TargetServerInstance     = $MonitoringServerDetails.ServerInstance
        $TargetDatabase           = $MonitoringServerDetails.StagingDatabase
        $MonitoringServerDatabase = $MonitoringServerDetails.MonitoringDatabase
        $AlertName                = "LOW DISK SPACE"
        $AlertDetails             = Get-SQLMonitoringAlertDetails $AlertName
        $ToEmailAddress           = $AlertDetails.ToEmailAddress      
        $FromEmailAddress         = $AlertDetails.FromEmailAddress        
        $RepeatFrequency          = $AlertDetails.RepeatFrequencySecs
        $AlertID                  = $AlertDetails.AlertID
        $SMTPServer               = "MAIL-01"
        $Subject                  = "LOW DISK SPACE"
        $EmailHeader              = Get-SQLMonitoringEmailHeader
        $SensorList               = Invoke-DbaQuery -SqlInstance $TargetServerInstance -Database $MonitoringServerDatabase -Query "SELECT * FROM  PRTG.Sensors WHERE isDiskSpaceSensor = 1 AND isActive = 1 AND DeviceName <> 'MONITOR-03' AND SensorName <> 'DISK FREE: C:\ LABEL: SERIAL NUMBER EE4A3655';"
        $URL                      = "https://monitor-02/api/table.json?content=channels&columns=datetime,name,lastvalue_&id=&username=patelk1&passhash=2884036294"
        
    
        $FinalOutput = 
                foreach ($Sensor in $SensorList)
                    {
    
                            $SensorValue = $Sensor.SensorID
                            $TableName = "SensorID_" + $Sensor.SensorID
                            $URLToUse = $URL.Replace("id=","id=$SensorValue")
    
                            $Output = Invoke-WebRequest $urlTOUSE -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                            $JsonOutput = $Output |convertfrom-json -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                            $Filter = $JsonOutput.Channels  | Where-Object {$_.name -eq "Free Space" -and $_.lastvalue_raw -le 5} 
                            if($Filter.datetime.count -ge 1)
                                {
                                    #$JsonOutput.Channels  | Where-Object {$_.name -eq "Free Space" -or $_.name -eq "Total" } |Select-Object @{Name ="SensorID" ; Expression={$SensorValue}},@{Name ="DiskSpaceFree" ; Expression={$_.lastvalue}},@{Name ="DeviceName" ; Expression={$Sensor.DeviceName}}, @{Name ="SensorName" ; Expression={$Sensor.SensorName}}, @{Name ="PRTGSensorID" ; Expression={$Sensor.PRTGSensorID}},@{Name ="AlertID"; Expression={($AlertID)}}, @{Name ="HashedEmailSubmission"; Expression={($Sensor.PRTGSensorID)}}, @{Name ="DateTimeSubmitted"; Expression={(get-date)}}, @{Name ="RepeatFrequencySecs"; Expression={($RepeatFrequency)}}
                                    $JsonOutput.Channels  | Where-Object {$_.name -eq "Free Space" -or $_.name -eq "Free Bytes" } |Select-Object @{Name ="SensorID" ; Expression={$SensorValue}},@{Name ="MetricName" ; Expression={$_.name}},@{Name ="MetricValue" ; Expression={$_.lastvalue_raw}},@{Name ="DeviceName" ; Expression={$Sensor.DeviceName}}, @{Name ="SensorName" ; Expression={$Sensor.SensorName}}, @{Name ="PRTGSensorID" ; Expression={$Sensor.PRTGSensorID}},@{Name ="AlertID"; Expression={($AlertID)}}, @{Name ="HashedEmailSubmission"; Expression={($Sensor.PRTGSensorID)}}, @{Name ="DateTimeSubmitted"; Expression={(get-date)}}, @{Name ="RepeatFrequencySecs"; Expression={($RepeatFrequency)}}
                                }
                            Remove-Variable SensorValue
                            Remove-Variable TableName
                            Remove-Variable Output
                            Remove-Variable JsonOutput
    
                    }        
        
        $FreeSpace = $FinalOutput| Where-Object {$_.MetricName -eq "Free Space"}
        $FreeMB    = $FinalOutput| Where-Object {$_.MetricName -eq "Free Bytes"} | Select-Object SensorID,@{Name ="MetricValue"; Expression={($_.MetricValue/1024/1024)}}
        $Results = 
        foreach ($Sensor in $FreeSpace)
            {
                        
                $Sensor | Select-Object SensorID,@{Name ="FreeSpacePerc"; Expression={($_.MetricValue)}},@{Name ="FreeMB"; Expression={($FreeMB | Where-Object {$_.SensorID -eq $Sensor.SensorID} | Select-Object MetricValue).MetricValue}}, DeviceName, SensorName, PRTGSensorID, AlertID, HashedEmailSubmission, DateTimeSubmitted, RepeatFrequencySecs   | select-object SensorID,@{Name ="FreeSpacePerc"; Expression={ [math]::Round($_.FreeSpacePerc,2)}},@{Name ="FreeSpaceMB"; Expression={ [math]::Round($_.FreeMB,2)}},@{Name ="TotalSpaceMB"; Expression={ [math]::Round(($_.FreeMB/$_.FreeSpacePerc)*100,2)}},@{Name ="UsedSpaceMB"; Expression={ [math]::Round((($_.FreeMB/$_.FreeSpacePerc)*100)-$_.FreeMB,2)}}, DeviceName, SensorName, PRTGSensorID, AlertID, HashedEmailSubmission, DateTimeSubmitted, RepeatFrequencySecs   
            }
    
        $Results = $Results|SELECT-object SensorID, FreeSpacePerc, FreeSpaceMB , TotalSpaceMB, UsedSpaceMB,@{Name ="FreeSpaceGB"; Expression={[math]::Round(($_.FreeSpaceMB/1024),2)}},@{Name ="TotalSpaceGB"; Expression={[math]::Round(($_.TotalSpaceMB/1024),2)}},@{Name ="UsedSpaceGB"; Expression={[math]::Round(($_.UsedSpaceMB/1024),2)}}, DeviceName, SensorName, PRTGSensorID, AlertID, HashedEmailSubmission, DateTimeSubmitted, RepeatFrequencySecs   
        $Results = $Results|SELECT-object SensorID, FreeSpacePerc, FreeSpaceMB , TotalSpaceMB, UsedSpaceMB,FreeSpaceGB,TotalSpaceGB,UsedSpaceGB, DeviceName, SensorName, PRTGSensorID, AlertID, HashedEmailSubmission, DateTimeSubmitted, RepeatFrequencySecs   
        
        if ($Results.SensorID.Count -gt 0)
            {
                $SQLOutput = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
            
    
        
        if ($SQLOutput.SensorID.Count -gt 0)
            {
                $SQLOutput = $SQLOutput| Select-Object  SensorID,DeviceName, SensorName, @{Name ="UsedSpaceMB"; Expression={('{0:N0}' -f $_.UsedSpaceMB)}}, @{Name ="FreeSpaceMB"; Expression={('{0:N0}' -f $_.FreeSpaceMB)}}, @{Name ="TotalSpaceMB"; Expression={('{0:N0}' -f $_.TotalSpaceMB)}}, UsedSpaceGB, FreeSpaceGB, TotalSpaceGB, FreeSpacePerc  |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
                Remove-Variable SQLOutput
            }
                    
        Remove-Variable MonitoringServerDetails   
        Remove-Variable TargetServerInstance      
        Remove-Variable TargetDatabase            
        Remove-Variable MonitoringServerDatabase  
        Remove-Variable URL
        Remove-Variable SensorList 
        Remove-Variable Sensor
        Remove-Variable Results
        Remove-Variable SQLOutput
        Remove-Variable FreeSpace 
        Remove-Variable FreeMB    
        REMOVE-VARIABLE AlertName
        REMOVE-VARIABLE AlertDetails
        REMOVE-VARIABLE ToEmailAddress
        REMOVE-VARIABLE FromEmailAddress
        REMOVE-VARIABLE RepeatFrequency
        REMOVE-VARIABLE AlertID
        REMOVE-VARIABLE SMTPServer
        REMOVE-VARIABLE Subject
        REMOVE-VARIABLE EmailHeader
        REMOVE-VARIABLE SensorList
        REMOVE-VARIABLE URL
        REMOVE-VARIABLE FinalOutput    
    }
    FUNCTION Send-SQLMonitoringLongRunningJobsAlert
    {
            $MonitoringServerDetails = Get-SQLMonitoringServer
            $TargetServerInstance    = $MonitoringServerDetails.ServerInstance
            $TargetDatabase          = $MonitoringServerDetails.StagingDatabase
            $TargetSchema            = "Staging"
            $TargetTable             = "LongRunningJobs"
            $StartDateTime           = (get-date)
            $TaskName                = "$SQLInstance - $TargetTable"
            $ParentTask              = "$TargetTable"
            $List                    = Get-SQLMonitoringServerList -InstanceRole PROD -InstanceType 'BUSINESS CRITICAL' | Select-Object SQLInstance
            $AlertName               = "LONG RUNNING JOBS"
            $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName
            $ToEmailAddress          = $AlertDetails.ToEmailAddress      
            $FromEmailAddress        = $AlertDetails.FromEmailAddress        
            $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
            $AlertID                 = $AlertDetails.AlertID
            $SMTPServer              = "MAIL-01"
            $Subject                 = "LONG RUNNING JOBS"
            $EmailHeader             = Get-SQLMonitoringEmailHeader
            $InsertSQLQuery          = 
            "
                SELECT
                     SERVERPROPERTY('ComputerNamePhysicalNetBIOS')ComputerName
                    ,ISNULL(SERVERPROPERTY('InstanceName'),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) InstanceName        
                    ,@@SERVERNAME SqlInstance 
                    ,js.job_id JobID
                    ,js.step_id StepID
                    ,j.name JobName
                    ,js.step_name StepName
                    ,ja.start_execution_date StartExecutionDate
                    ,isnull(last_request_start_time,ja.start_execution_date) StepExecutionStartTime
                    ,DATEDIFF(SECOND, ja.start_execution_date, SYSDATETIME()) JobDurationSeconds
                    ,DATEDIFF(SECOND,isnull(last_request_start_time,ja.start_execution_date), SYSDATETIME())  StepDurationSeconds
                    ,ISNULL(last_executed_step_id, 0) + 1 current_executed_step_id
                    --,cat.name
                FROM
                    msdb.dbo.sysjobactivity ja
                LEFT JOIN
                    msdb.dbo.sysjobhistory  jh
                ON 
                    ja.job_history_id = jh.instance_id
                JOIN
                    msdb.dbo.sysjobs        j
                ON 
                    ja.job_id = j.job_id
                JOIN
                    msdb.dbo.sysjobsteps    js
                ON 
                    ja.job_id = js.job_id
                AND 
                    ISNULL(ja.last_executed_step_id, 0) + 1 = js.step_id
                JOIN
                    msdb.dbo.syscategories  cat
                ON 
                    j.category_id = cat.category_id
                LEFT JOIN
                    sys.dm_exec_sessions 
                ON
                    CONVERT(NVARCHAR(MAX), CONVERT(VARBINARY, ja.job_id), 1) = SUBSTRING(program_name,CHARINDEX('0x', program_name), CHARINDEX(' ', program_name, CHARINDEX('0x', program_name))-CHARINDEX('0x', program_name))
                WHERE
                        ja.session_id =
                    (
                        SELECT TOP 1
                               session_id
                        FROM
                               msdb.dbo.syssessions
                        ORDER BY
                               agent_start_date DESC
                    )
                AND 
                    ja.start_execution_date IS NOT NULL
                AND 
                    ja.stop_execution_date IS NULL
                
                AND
                    ja.start_execution_date > 600
                AND
                    cat.name NOT LIKE 'REPL%'
            "
    $OutputSQLQuery =
            "
                SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
                ;WITH StepCte AS
                    (
                        SELECT
                             AJH.SqlInstance
                            ,AJH.JobID
                            ,AJH.StepID
                            ,AVG(AJH.RunDuration) AvgRunDuration
                        FROM  
                            DatabaseMonitoring.SQLServer.AgentJobHistory AJH
                        WHERE
                            AJH.StartDate >= DATEADD(MONTH,-1,SYSDATETIME())
                        GROUP BY
                             AJH.SqlInstance
                            ,AJH.JobID
                            ,AJH.StepID
                    )
                ,	JobCte AS
                    (
                        SELECT
                             AJH.SqlInstance
                            ,AJH.JobID
                            ,AVG(AJH.RunDuration) AvgRunDuration
                            ,StepID
                        FROM  
                            DatabaseMonitoring.SQLServer.AgentJobHistory AJH
                        WHERE
                            AJH.StepID = (
                                            SELECT
                                                MIN(StepID) StepID
                                            FROM
                                                DatabaseMonitoring.SQLServer.AgentJobHistory 
                                            WHERE
                                                StartDate >= DATEADD(MONTH,-1,SYSDATETIME())
                                            AND
                                                AJH.SqlInstance = SqlInstance
                                            AND
                                                AJH.JobID	    = JobID
                                            AND
                                                StepID <= 1
                                         )
                        AND
                             AJH.StartDate >= DATEADD(MONTH,-1,SYSDATETIME())
                        GROUP BY
                             AJH.SqlInstance
                            ,AJH.JobID
                            ,StepID
                    )
                SELECT
                    LRJ.ComputerName
                   ,LRJ.InstanceName
                   ,LRJ.SqlInstance
                   ,LRJ.JobID
                   ,LRJ.StepID
                   ,LRJ.JobName
                   ,LRJ.StepName
                   ,LRJ.StartExecutionDate
                   ,LRJ.StepExecutionStartTime
                   ,LRJ.JobDurationSeconds
                   ,JobCte.AvgRunDuration AverageJobDurationSeconds
                   ,LRJ.StepDurationSeconds
                   ,StepCte.AvgRunDuration AverageStepDurationSeconds
                   ,LRJ.current_executed_step_id CurrentJobStep
                   ,CASE 
                        WHEN LRJ.JobDurationSeconds >  JobCte.AvgRunDuration  AND LRJ.StepDurationSeconds > StepCte.AvgRunDuration  THEN 'JOB AND STEP OVERRUNNING'
                        WHEN LRJ.JobDurationSeconds >  JobCte.AvgRunDuration  THEN 'JOB OVERRUNNING'
                        WHEN LRJ.StepDurationSeconds > StepCte.AvgRunDuration  THEN 'STEP OVERRUNNING'
                        WHEN Dt.JobID IS NULL THEN 'NEW LONG RUNNING JOB/JOB STEP'
                    END Comment
                    ,CHECKSUM(JobCte.SqlInstance + CAST(LRJ.JobID AS VARCHAR(1055)) + CAST(LRJ.StartExecutionDate AS VARCHAR(50)) ) HashedEmailSubmission
                FROM
                    Staging.LongRunningJobs LRJ
                LEFT JOIN
                    JobCte
                ON
                    LRJ.JobID = JobCte.JobID
                AND
                    LRJ.SqlInstance = JobCte.SqlInstance
                LEFT JOIN
                    StepCte
                ON
                    LRJ.JobID = StepCte.JobID
                AND
                    LRJ.StepID = StepCte.StepID
                AND
                    LRJ.SqlInstance = StepCte.SqlInstance
                LEFT JOIN
                    (
                        SELECT
                             SqlInstance
                            ,JobID
                            ,StepID
                        FROM
                            DatabaseMonitoring.SQLServer.AgentJobHistory 
                        GROUP BY
                             SqlInstance
                            ,JobID
                            ,StepID
                    )Dt
                ON
                    LRJ.JobID = Dt.JobID
                AND
                    LRJ.StepID = Dt.StepID
                AND
                    LRJ.SqlInstance = Dt.SqlInstance	
                WHERE
                    LRJ.JobDurationSeconds >= (JobCte.AvgRunDuration + (JobCte.AvgRunDuration /10))
                OR
                    LRJ.StepDurationSeconds >= (StepCte.AvgRunDuration + (StepCte.AvgRunDuration /10))
                OR
                    Dt.JobID IS NULL;
                TRUNCATE TABLE Staging.LongRunningJobs;
            "            
    
            $Out = Invoke-DbaQuery -SqlInstance  $List.SqlInstance -Query $InsertSQLQuery
            $Out |  Write-DbaDataTable -SqlInstance $TargetServerInstance -Database $TargetDatabase -Schema $TargetSchema -Table $TargetTable #-AutoCreateTable  #-FireTriggers
            
            $Results = Invoke-DbaQuery -SqlInstance  $MonitoringInstanceName -Database $TargetDatabase -Query $OutputSQLQuery 
            $Results  = $Results | Select-Object @{Name ="AlertID"; Expression={($AlertID)}}, @{Name ="DateTimeSubmitted"; Expression={(get-date)}}, @{Name ="RepeatFrequencySecs"; Expression={($RepeatFrequency)}}, ComputerName, InstanceName, SqlInstance, JobID, StepID, JobName, StepName, StartExecutionDate, StepExecutionStartTime, JobDurationSeconds, AverageJobDurationSeconds, StepDurationSeconds, AverageStepDurationSeconds, CurrentJobStep, Comment, HashedEmailSubmission     
    
            
            if ($Results.sqlinstance.Count -gt 0)
                {
                    $SQLOutput = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
                }
                
            $SQLOutput = $SQLOutput| Select-Object  ComputerName, InstanceName, SqlInstance, JobID, StepID, JobName, StepName, StartExecutionDate, StepExecutionStartTime, JobDurationSeconds, AverageJobDurationSeconds, StepDurationSeconds, AverageStepDurationSeconds, CurrentJobStep, Comment, HashedEmailSubmission      |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
                
            
            if ($Results.SensorID.Count -gt 0)
                {
                    Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
                }
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE TargetServerInstance    
            REMOVE-VARIABLE TargetDatabase          
            REMOVE-VARIABLE TargetSchema            
            REMOVE-VARIABLE TargetTable             
            REMOVE-VARIABLE StartDateTime           
            REMOVE-VARIABLE TaskName                
            REMOVE-VARIABLE ParentTask              
            REMOVE-VARIABLE List                    
            REMOVE-VARIABLE AlertName               
            REMOVE-VARIABLE AlertDetails            
            REMOVE-VARIABLE ToEmailAddress          
            REMOVE-VARIABLE FromEmailAddress        
            REMOVE-VARIABLE RepeatFrequency         
            REMOVE-VARIABLE AlertID                 
            REMOVE-VARIABLE SMTPServer              
            REMOVE-VARIABLE Subject                 
            REMOVE-VARIABLE EmailHeader             
            REMOVE-VARIABLE InsertSQLQuery
            REMOVE-VARIABLE OutputSQLQuery
            REMOVE-VARIABLE Out
            REMOVE-VARIABLE Results                              
            REMOVE-VARIABLE SQLOutput
    }
    FUNCTION Send-SQLMonitoringGetFailedJobsAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.StagingDatabase
        $AlertName               = "FAILED JOBS" 
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName               
        $ToEmailAddress          = $AlertDetails.ToEmailAddress      
        $FromEmailAddress        = $AlertDetails.FromEmailAddress    
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "FAILED JOBS"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'ALL' -InstanceType 'ALL'
        $Query                   = 
                    "
                    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                    SET NOCOUNT ON;
                    SELECT
                         @@ServerName SQLInstance
                        ,dbo.agent_datetime(Hist.run_date,Hist.run_time) StartDateTime
                        ,DATEADD(SECOND,((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) ),dbo.agent_datetime(Hist.run_date,Hist.run_time)) EndDateTime
                        ,((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) )  RunDurationSeconds
                        ,((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)  RunDurationMins
                        ,Jobs.name JobName
                        ,Hist.step_name StepName
                        ,Hist.message JobMessage
                        ,CHECKSUM(CAST(@@ServerName AS VARCHAR(20)) + ' FAILED JOBS' + CAST(Hist.instance_id AS VARCHAR(20)) + CAST(Hist.run_date AS VARCHAR(20))  + CAST(Hist.run_time AS VARCHAR(20))  + Jobs.name) HashedEmailSubmission 
    
                    FROM  
                        dbo.sysjobhistory  Hist
                    JOIN
                        dbo.sysjobs Jobs
                    ON	
                        Hist.job_id = Jobs.job_id
                    WHERE
                        run_status = 0
                    AND
                        DATEADD(SECOND,((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) ),dbo.agent_datetime(Hist.run_date,Hist.run_time)) >= DATEADD(MINUTE,-1,SYSDATETIME());
    
                    "
        $Results = Invoke-DbaQuery -SqlInstance $SQLList.SQLInstance -Database msdb  -Query $Query 
        if ($Results.SQLInstance.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object SQLInstance, StartDateTime , EndDateTime, RunDurationSeconds, RunDurationMins, JobName, StepName, JobMessage, HashedEmailSubmission  |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.SQLInstance.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
    
            REMOVE-VARIABLE MonitoringServerDetails 
            REMOVE-VARIABLE MonitoringInstanceName  
            REMOVE-VARIABLE MonitoringDatabaseName  
            REMOVE-VARIABLE AlertName               
            REMOVE-VARIABLE MonitoringDBName        
            REMOVE-VARIABLE AlertDetails            
            REMOVE-VARIABLE ToEmailAddress          
            REMOVE-VARIABLE FromEmailAddress        
            REMOVE-VARIABLE RepeatFrequency         
            REMOVE-VARIABLE AlertID                 
            REMOVE-VARIABLE SMTPServer              
            REMOVE-VARIABLE Subject                 
            REMOVE-VARIABLE EmailHeader             
            REMOVE-VARIABLE SQLList                 
            REMOVE-VARIABLE Query
            REMOVE-VARIABLE Results
            REMOVE-VARIABLE SQLOutput                           
    }
    
    function Send-SQLMonitoringDeadlocksAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.StagingDatabase
        
        $AlertName               = "DEADLOCKS" 
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName               
        $ToEmailAddress          = $AlertDetails.ToEmailAddress
        $FromEmailAddress        = $AlertDetails.FromEmailAddress
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "DEADLOCKS"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'Prod' -InstanceType 'ALL'
        $Query                   = "
                USE DatabaseMonitoring;
                SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                SET NOCOUNT ON;
                 
                SELECT
                     ComputerName             
                    ,InstanceName            
                    ,SQLInstance             
                    ,BatchCompletedVictim 
                    ,BatchCompletedWinner      
                    ,SpidVictim           
                    ,SpidWinner           
                    ,LoginVictim          
                    ,LoginWinner          
                    ,ClientAppVictim      
                    ,ClientAppWinner      
                    ,hostnameVictim       
                    ,hostnameWinner
                    ,VictimDatabaseName   
                    ,WinnerDatabaseName   
                    ,TransactionIDVictim  
                    ,TransactionIDWinner  
                    ,ProcNameVictim       
                    ,ProcNameWinner       
                    ,WaitResoureVictim    
                    ,WaitResoureWinner    
                    ,TableNameVictim      
                    ,TableNameWinner      
                    ,ResourceVictim       
                    ,ResourceWinner       
                    ,IndexNameVictim      
                    ,IndexNameWinner      
                    ,HashedEmailSubmission
                FROM  
                    SQLServer.DeadlockHistory dh
                WHERE 
                    EmailSentTag = 0
                AND
                    ComputerName <> 'EICC-DBS';
    
                    "
        $Results = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDBName  -Query $Query 
        if ($Results.ComputerName.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object ComputerName,InstanceName,SQLInstance,BatchCompletedVictim,BatchCompletedWinner,SpidVictim,SpidWinner,LoginVictim,LoginWinner,ClientAppVictim,ClientAppWinner,hostnameVictim,hostnameWinner,VictimDatabaseName,WinnerDatabaseName,TransactionIDVictim,TransactionIDWinner,ProcNameVictim,ProcNameWinner,WaitResoureVictim,WaitResoureWinner,TableNameVictim,TableNameWinner,ResourceVictim,ResourceWinner,IndexNameVictim,IndexNameWinner -Unique |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.ComputerName.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
                $Results | select-object HashedEmailSubmission| Write-DbaDbTableData -SqlInstance $MonitoringInstanceName -Database "Staging"  -schema "Staging" -Table "DeadlockEmails" -FireTriggers
            }
    
        REMOVE-VARIABLE MonitoringServerDetails 
        REMOVE-VARIABLE MonitoringInstanceName  
        REMOVE-VARIABLE MonitoringDatabaseName  
        REMOVE-VARIABLE AlertName               
        REMOVE-VARIABLE MonitoringDBName        
        REMOVE-VARIABLE AlertDetails            
        REMOVE-VARIABLE ToEmailAddress          
        REMOVE-VARIABLE FromEmailAddress        
        REMOVE-VARIABLE RepeatFrequency         
        REMOVE-VARIABLE AlertID                 
        REMOVE-VARIABLE SMTPServer              
        REMOVE-VARIABLE Subject                 
        REMOVE-VARIABLE EmailHeader             
        REMOVE-VARIABLE SQLList                 
        REMOVE-VARIABLE Query  
        REMOVE-VARIABLE Results
        REMOVE-VARIABLE SQLOutput                         
    }
    
FUNCTION Send-SQLMonitoringGetSleepingTransactionsAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.StagingDatabase
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertName               = "SLEEPING TRANSACTIONS" 
        $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName               
        $ToEmailAddress          = $AlertDetails.ToEmailAddress
        $FromEmailAddress        = $AlertDetails.FromEmailAddress
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "SLEEPING TRANSACTIONS"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'PROD' -InstanceType 'ALL'
        $Query                   = "
                    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                    SET NOCOUNT ON;
                    SELECT 
                         @@SERVERNAME SQLInstance
                        ,session_id	SessionID
                        ,login_time LoginTime
                        ,last_request_start_time  LastRequestStartTime
                        ,last_request_end_time	  LastRequestEndTime
                        ,DATEDIFF(SECOND,last_request_end_time,SYSDATETIME()) TimeSleeping
                        ,status					  RequestStatus
                        ,reads					  Reads
                        ,writes					  Writes
                        ,logical_reads			  LogicalReads
                        ,host_name				  HostName
                        ,program_name			  ProgramName
                        ,client_interface_name	  ClientInterfaceName
                        ,DB_NAME(database_id)	  DatabaseName
                        ,login_name				  LoginName
                        ,cpu_time				  CpuTime
                        ,memory_usage			  MemoryUsage
                        ,total_scheduled_time	  TotalScheduledTime
                        ,total_elapsed_time		  Total_elapsedTime
                        ,open_transaction_count	  OpenTransactionCount
                        ,CHECKSUM(CAST(@@ServerName AS VARCHAR(20)) + '  SLEEPING SESSIONS ' + CAST(session_id AS VARCHAR(20)) + CAST(last_request_start_time AS VARCHAR(20))  + CAST(last_request_end_time AS VARCHAR(20))  + program_name) HashedEmailSubmission 
                    FROM  						   
                        sys.dm_exec_sessions
                    WHERE
                        open_transaction_count > 0
                    AND
                        program_name NOT LIKE 'REPL%'
                    AND
                        program_name <> 'Report Server'
                    AND
                        DATEDIFF(SECOND,last_request_end_time,SYSDATETIME()) > CASE WHEN @@SERVERNAME <> 'WLR3-01' THEN 30 ELSE 60 END
                    AND	
                        status = 'SLEEPING'
                    
                    ;
    
                    "
        $Results = Invoke-DbaQuery -SqlInstance $SQLList.SQLInstance -Database msdb  -Query $Query 
        if ($Results.SQLInstance.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object SQLInstance, SessionID, LoginTime, LastRequestStartTime, LastRequestEndTime, TimeSleeping, RequestStatus, Reads, Writes, LogicalReads, HostName, ProgramName, ClientInterfaceName, DatabaseName, LoginName, CpuTime, MemoryUsage, TotalScheduledTime, Total_elapsedTime, OpenTransactionCount, HashedEmailSubmission  |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.SQLInstance.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
    
        REMOVE-VARIABLE MonitoringServerDetails 
        REMOVE-VARIABLE MonitoringInstanceName  
        REMOVE-VARIABLE MonitoringDatabaseName  
        REMOVE-VARIABLE AlertName               
        REMOVE-VARIABLE MonitoringDBName        
        REMOVE-VARIABLE AlertDetails            
        REMOVE-VARIABLE ToEmailAddress          
        REMOVE-VARIABLE FromEmailAddress        
        REMOVE-VARIABLE RepeatFrequency         
        REMOVE-VARIABLE AlertID                 
        REMOVE-VARIABLE SMTPServer              
        REMOVE-VARIABLE Subject                 
        REMOVE-VARIABLE EmailHeader             
        REMOVE-VARIABLE SQLList                 
        REMOVE-VARIABLE Query
        REMOVE-VARIABLE Results
        REMOVE-VARIABLE SQLOutput                           
    }
FUNCTION Send-SQLMonitoringGetLowLogSpaceAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.StagingDatabase
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertName               = "LOW LOG SPACE" 
        $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName               
        $ToEmailAddress          = $AlertDetails.ToEmailAddress
        $FromEmailAddress        = $AlertDetails.FromEmailAddress
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "LOW LOG SPACE"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'PROD' -InstanceType 'ALL'
        $Query                   = 
            "
                    DECLARE @SQL	 NVARCHAR(MAX)=N'';
                    DECLARE @BaseSQL NVARCHAR(MAX)=N'
                    UNION	
                    SELECT 
                        @@SERVERNAME SQLInstance
                       ,UPPER(DB_NAME(dd.database_id)) COLLATE DATABASE_DEFAULT DatabaseName 
                       ,UPPER(df.name) COLLATE DATABASE_DEFAULT  LogName
                       ,CAST((vs.total_bytes	)*1.0/1024/1024/1024 AS NUMERIC(12,2))   TotalVolumeSpace
                       ,CAST((vs.available_bytes)*1.0/1024/1024/1024 AS NUMERIC(12,2))   AvailableVolumeSpace
                       ,CAST(ROUND((total_log_size_in_bytes)*1.0 /1024.0/1024/1024,2) AS NUMERIC(12,2)) LogSizeGB
                       ,CAST(ROUND((used_log_space_in_bytes)*1.0 /1024.0/1024/1024,2) AS NUMERIC(12,2)) LogSpaceUsedGB
                       ,CAST(ROUND(used_log_space_in_percent,2) AS NUMERIC(12,2)) LogSpaceUsedPerc 
                       ,CHECKSUM(CAST(@@SERVERNAME AS VARCHAR(255)) + ''DATABASE LOG SPACE'' + DB_NAME(dd.database_id)) HashedEmailSubmission
                    FROM 
                        [?].sys.dm_db_log_space_usage dd
                    LEFT JOIN
                        [?].sys.master_files df
                    ON
                        dd.database_id =df.database_id
                    AND
                        df.type = 1
                    OUTER APPLY
                        [?].sys.dm_os_volume_stats(DB_ID(),2) vs
                    WHERE
                        CAST(ROUND(used_log_space_in_percent,2) AS NUMERIC(12,2)) > 90	';
                    SELECT
                        @SQL	  += REPLACE(@BaseSQL,'?',name)
                    FROM
                        sys.databases
                    SELECT @SQL	 = RIGHT(@SQL,LEN(@SQL)-27)
                    SELECT @SQL	 = '
                    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                    SET NOCOUNT ON;'  + @SQL	 
                    EXEC master.sys.sp_executesql @SQL	 
                  "
        $Results = Invoke-DbaQuery -SqlInstance $SQLList.SQLInstance -Query $Query 
        if ($Results.SQLInstance.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object SQLInstance, DatabaseName, LogName,TotalVolumeSpace,AvailableVolumeSpace, LogSizeGB, LogSpaceUsedGB, LogSpaceUsedPerc|  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.SQLInstance.Count -gt 0)                                   
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
    
        REMOVE-VARIABLE MonitoringServerDetails
        REMOVE-VARIABLE MonitoringInstanceName
        REMOVE-VARIABLE MonitoringDatabaseName
        REMOVE-VARIABLE AlertName
        REMOVE-VARIABLE MonitoringDBName
        REMOVE-VARIABLE AlertDetails
        REMOVE-VARIABLE ToEmailAddress
        REMOVE-VARIABLE FromEmailAddress
        REMOVE-VARIABLE RepeatFrequency
        REMOVE-VARIABLE AlertID
        REMOVE-VARIABLE SMTPServer
        REMOVE-VARIABLE Subject
        REMOVE-VARIABLE EmailHeader
        REMOVE-VARIABLE SQLList
        REMOVE-VARIABLE Query
        REMOVE-VARIABLE Results
        REMOVE-VARIABLE SQLOutput        
    }
FUNCTION Send-SQLMonitoringGetLowDatabaseFileSpaceAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.StagingDatabase
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertName               = "LOW DATABASE FILE SPACE" 
        $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName               
        $ToEmailAddress          = $AlertDetails.ToEmailAddress
        $FromEmailAddress        = $AlertDetails.FromEmailAddress
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "LOW DATABASE FILE SPACE"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'PROD' -InstanceType 'ALL'
        $Query                   = 
            "
                    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
                    IF OBJECT_ID('TempDB..#temptable','U') IS NOT NULL DROP TABLE #temptable;
                    CREATE TABLE #temptable
                    (
                        [SqlInstance]            VARCHAR(255)
                        ,[DBName]                VARCHAR(255)
                        ,[FileName]              VARCHAR(255)
                        ,[Filegroup]             VARCHAR(255)
                        ,[PhysicalName]          VARCHAR(1055)
                        ,[UsedSpaceMB]           FLOAT(8)
                        ,[FreeSpaceMB]           FLOAT(8)
                        ,[FileSizeMB]            FLOAT(8)
                        ,[PercentUsed]           FLOAT(8)
                        ,[GrowthMB]              FLOAT(8)
                        ,[GrowthType]            VARCHAR(7)
                        ,TotalVolumeSpace		 INT
                        ,AvailableVolumeSpace	 INT
                        ,[HashedEmailSubmission] INT
                    );
                    DECLARE @BaseSQL NVARCHAR(MAX)=N'
                    USE [?]
                    SELECT 
                        CAST(SERVERPROPERTY(''ServerName'') AS VARCHAR) AS SqlInstance
                        ,UPPER(DB_NAME())		COLLATE DATABASE_DEFAULT AS DBName			
                        ,UPPER(f.name)			COLLATE DATABASE_DEFAULT AS [FileName]
                        ,UPPER(fg.name)			COLLATE DATABASE_DEFAULT AS [Filegroup]
                        ,UPPER(f.physical_name) COLLATE DATABASE_DEFAULT AS [PhysicalName]
                        ,CAST(CAST(FILEPROPERTY(f.name, ''SpaceUsed'') AS int)/128.0 AS FLOAT) as [UsedSpaceMB]
                        ,CAST(f.size/128.0 - CAST(FILEPROPERTY(f.name, ''SpaceUsed'') AS int)/128.0 AS FLOAT) AS [FreeSpaceMB]
                        ,CAST((f.size/128.0) AS FLOAT) AS [FileSizeMB]
                        ,CAST((FILEPROPERTY(f.name, ''SpaceUsed'')/(f.size/1.0)) * 100 as FLOAT) as [PercentUsed]
                        ,CAST((f.growth/128.0) AS FLOAT) AS [GrowthMB]
                        ,CASE is_percent_growth WHEN 1 THEN ''%'' WHEN 0 THEN ''MB'' ELSE ''Unknown'' END AS [GrowthType]
                        ,CAST((vs.total_bytes	)*1.0/1024/1024/1024 AS NUMERIC(12,2))    TotalVolumeSpace
                        ,CAST((vs.available_bytes)*1.0/1024/1024/1024 AS NUMERIC(12,2))   AvailableVolumeSpace
                        ,CHECKSUM(CAST(SERVERPROPERTY(''ServerName'') AS VARCHAR(255)) + UPPER(f.name)) HashedEmailSubmission
                    FROM 
                        sys.database_files   f  
                    LEFT JOIN 
                        sys.filegroups fg 
                    ON 
                        f.data_space_id = fg.data_space_id
                    OUTER APPLY
                        sys.dm_os_volume_stats(DB_ID(),f.file_id) vs
                    WHERE
                        f.type = 0
                    AND
                        CAST((FILEPROPERTY(f.name, ''SpaceUsed'')/(f.size/1.0)) * 100 as FLOAT) > 95	';
                    INSERT INTO #temptable
                    EXEC sys.sp_MSforeachdb @BaseSQL	  
                    SELECT 
                        SqlInstance
                        ,DBName
                        ,FileName
                        ,Filegroup
                        ,PhysicalName
                        ,UsedSpaceMB
                        ,FreeSpaceMB
                        ,FileSizeMB
                        ,PercentUsed
                        ,GrowthMB
                        ,GrowthType
                        ,TotalVolumeSpace
                        ,AvailableVolumeSpace
                        ,HashedEmailSubmission 
                    FROM  
                        #temptable 
                  "
        $Results = Invoke-DbaQuery -SqlInstance $SQLList.SQLInstance -Query $Query 
        if ($Results.SQLInstance.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object SqlInstance ,DBName ,FileName ,Filegroup ,PhysicalName ,UsedSpaceMB ,FreeSpaceMB ,FileSizeMB ,PercentUsed ,GrowthMB ,GrowthType ,TotalVolumeSpace ,AvailableVolumeSpace ,HashedEmailSubmission |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.SQLInstance.Count -gt 0)                                   
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
    
        REMOVE-VARIABLE MonitoringServerDetails
        REMOVE-VARIABLE MonitoringInstanceName
        REMOVE-VARIABLE MonitoringDatabaseName
        REMOVE-VARIABLE AlertName
        REMOVE-VARIABLE MonitoringDBName
        REMOVE-VARIABLE AlertDetails
        REMOVE-VARIABLE ToEmailAddress
        REMOVE-VARIABLE FromEmailAddress
        REMOVE-VARIABLE RepeatFrequency
        REMOVE-VARIABLE AlertID
        REMOVE-VARIABLE SMTPServer
        REMOVE-VARIABLE Subject
        REMOVE-VARIABLE EmailHeader
        REMOVE-VARIABLE SQLList
        REMOVE-VARIABLE Query
        REMOVE-VARIABLE Results
        REMOVE-VARIABLE SQLOutput        
    }
FUNCTION Send-SQLMonitoringGetExceedingCountersAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.StagingDatabase
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertName               = "EXCEEDING PERFMON COUNTERS" 
        $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName               
        $ToEmailAddress          = $AlertDetails.ToEmailAddress
        $FromEmailAddress        = $AlertDetails.FromEmailAddress
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "EXCEEDING PERFMON COUNTERS"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'ALL' -InstanceType 'ALL'
        $Query                   = "EXEC Reporting.usp_GetExceedingPerformanceCounter;"
        $Results                 = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDBName -Query $Query 
        if ($Results.CollectionDateTime.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object CollectionDateTime , DeviceName , SensorName , ChannelName , CounterValue , TargetPredicate , @{Name ="1 Day Away"; Expression={($_.1)}} , @{Name ="7 Days Away"; Expression={($_.7)}} , @{Name ="14 Days Away"; Expression={($_.14)}}, @{Name ="28 Days Away"; Expression={($_.28)}}, @{Name ="30 Days Away"; Expression={($_.30)}}, TargetValue, HashedEmailSubmission |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.CollectionDateTime.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
        REMOVE-VARIABLE MonitoringServerDetails 
        REMOVE-VARIABLE MonitoringInstanceName  
        REMOVE-VARIABLE MonitoringDatabaseName  
        REMOVE-VARIABLE AlertName               
        REMOVE-VARIABLE MonitoringDBName        
        REMOVE-VARIABLE AlertDetails            
        REMOVE-VARIABLE ToEmailAddress          
        REMOVE-VARIABLE FromEmailAddress        
        REMOVE-VARIABLE RepeatFrequency         
        REMOVE-VARIABLE AlertID                 
        REMOVE-VARIABLE SMTPServer              
        REMOVE-VARIABLE Subject                 
        REMOVE-VARIABLE EmailHeader             
        REMOVE-VARIABLE SQLList                 
        REMOVE-VARIABLE Query                   
        REMOVE-VARIABLE Results
        REMOVE-VARIABLE SQLOutput                 
    }
FUNCTION Send-SQLMonitoringGetFileUsageChangeAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.StagingDatabase
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertName               = "FILE SPACE USED" 
        
        $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName               
        $ToEmailAddress          = $AlertDetails.ToEmailAddress
        $FromEmailAddress        = $AlertDetails.FromEmailAddress
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "FILE SPACE USED"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'ALL' -InstanceType 'ALL'
        $Query                   = "EXEC Reporting.usp_Get_FileSpaceChange;"
        $Results                 = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDBName -Query $Query 
        if ($Results.SqlInstance.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object SqlInstance, DatabaseName, FileGroupName, TypeDescription, LogicalName, PhysicalName, FileSizeGB, UsedSpaceGB, AvailableSpaceGB, VolumeFreeSpaceGB, PreviousFileSizeGB, PreviousUsedSpaceGB, PreviousAvailableSpaceGB, PreviousVolumeFreeSpaceGB, FileSizeChange, UsedSizeChange, FileSizeChangePerc, UsedSizeChangePerc       |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.SqlInstance.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
    
        REMOVE-VARIABLE MonitoringServerDetails 
        REMOVE-VARIABLE MonitoringInstanceName  
        REMOVE-VARIABLE MonitoringDatabaseName  
        REMOVE-VARIABLE AlertName               
        REMOVE-VARIABLE MonitoringDBName        
        REMOVE-VARIABLE AlertDetails            
        REMOVE-VARIABLE ToEmailAddress          
        REMOVE-VARIABLE FromEmailAddress        
        REMOVE-VARIABLE RepeatFrequency         
        REMOVE-VARIABLE AlertID                 
        REMOVE-VARIABLE SMTPServer              
        REMOVE-VARIABLE Subject                 
        REMOVE-VARIABLE EmailHeader             
        REMOVE-VARIABLE SQLList                 
        REMOVE-VARIABLE Query                   
        REMOVE-VARIABLE Results
        REMOVE-VARIABLE SQLOutput                         
    }
FUNCTION Send-SQLMonitoringGetExceedingWaitsAlert
    {
        $MonitoringServerDetails = Get-SQLMonitoringServer
        $MonitoringInstanceName  = $MonitoringServerDetails.ServerInstance
        $MonitoringDatabaseName  = $MonitoringServerDetails.StagingDatabase
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertName               = "EXCEEDING WAITS" 
        $MonitoringDBName        = $MonitoringServerDetails.MonitoringDBName
        $AlertDetails            = Get-SQLMonitoringAlertDetails $AlertName               
        $ToEmailAddress          = $AlertDetails.ToEmailAddress
        $FromEmailAddress        = $AlertDetails.FromEmailAddress
        $RepeatFrequency         = $AlertDetails.RepeatFrequencySecs
        $AlertID                 = $AlertDetails.AlertID
        $SMTPServer              = "MAIL-01"
        $Subject                 = "EXCEEDING WAITS"
        $EmailHeader             = Get-SQLMonitoringEmailHeader
        $SQLList                 = Get-SQLMonitoringServerList -InstanceRole 'ALL' -InstanceType 'ALL'
        $Query                   = "EXEC Reporting.usp_GetExceedingWaits;"
        $Results                 = Invoke-DbaQuery -SqlInstance $MonitoringInstanceName -Database $MonitoringDBName -Query $Query 
        if ($Results.SQLInstance.Count -gt 0)
            {
                $Results = Get-SQLMonitoringCheckEmailSubmissions -AlertID $AlertID -Results $Results -RepeatFrequency $RepeatFrequency
            }
        $SQLOutput = $Results| Select-Object SQLInstance , WaitType , Category , CurrentValue , @{Name ="1 Day Away"; Expression={($_.1)}} , @{Name ="7 Days Away"; Expression={($_.7)}} , @{Name ="14 Days Away"; Expression={($_.14)}}, @{Name ="28 Days Away"; Expression={($_.28)}}, @{Name ="30 Days Away"; Expression={($_.30)}}, HashedEmailSubmission |  ConvertTo-HTML -Head $EmailHeader | Out-String #   | Out-GridView    
        if ($Results.SQLInstance.Count -gt 0)
            {
                Send-SQLMonitoringSQLOutput -ToEmailAddress $ToEmailAddress -FromEmailAddress $FromEmailAddress -SMTPServer $SMTPServer -Subject $Subject -SQLOutput $SQLOutput
            }
            
        REMOVE-VARIABLE MonitoringServerDetails 
        REMOVE-VARIABLE MonitoringInstanceName  
        REMOVE-VARIABLE MonitoringDatabaseName  
        REMOVE-VARIABLE MonitoringDBName        
        REMOVE-VARIABLE AlertName               
        REMOVE-VARIABLE MonitoringDBName        
        REMOVE-VARIABLE AlertDetails            
        REMOVE-VARIABLE ToEmailAddress          
        REMOVE-VARIABLE FromEmailAddress        
        REMOVE-VARIABLE RepeatFrequency         
        REMOVE-VARIABLE AlertID                 
        REMOVE-VARIABLE SMTPServer              
        REMOVE-VARIABLE Subject                 
        REMOVE-VARIABLE EmailHeader             
        REMOVE-VARIABLE SQLList                 
        REMOVE-VARIABLE Query                   
        REMOVE-VARIABLE Results                         
        REMOVE-VARIABLE SQLOutput
    }
        
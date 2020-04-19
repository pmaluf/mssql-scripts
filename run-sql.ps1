 <# 
.SYNOPSIS 
Script in PowerShell to execute all the SQL files inside a folder and output then to a CSV or TXT format.

.DESCRIPTION 
All files in -Sqldir folder with .sql extension will be run and output then into a CSV or TXT file format.

.PARAMETER SqlDir 
The full path to the directory where all the sql script files are.

.PARAMETER SQLServer 
Sql Server name that the scripts should be run on. If you have an instance name just use "SqlServer\InstansName". 

.PARAMETER Database 
Database name that the scripts should be run on.

.PARAMETER OutputFormat 
Format of output files. [csv/table]

.PARAMETER SQLAuthentication
Enable SQL Server Authentication

.EXAMPLE 
.\run-sql.ps1 -SqlDir "C:\Temp\sqldir" -SQLServer "SqlServer\InstansName" -Database VDB1

.NOTES 
    File Name  : run-sql.ps1 
    Author     : Paulo Maluf <paulo.maluf@experiortec.com>
#>

param  
(  
    [Parameter( 
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true, 
        ValueFromPipelineByPropertyName=$true) 
    ] 
    [string]$SqlDir,

    [Parameter( 
        Position=1,
        Mandatory=$true, 
        ValueFromPipeline=$false, 
        ValueFromPipelineByPropertyName=$true) 
    ] 
    [string]$SQLServer='$env:computername\MSSQLSERVER' ,

    [Parameter( 
        Position=2,
        Mandatory=$true, 
        ValueFromPipeline=$false, 
        ValueFromPipelineByPropertyName=$true) 
    ] 
    [string]$Database,

    [Parameter( 
        Position=3, 
        Mandatory=$false, 
        ValueFromPipeline=$false, 
        ValueFromPipelineByPropertyName=$true) 
    ]
    [ValidateSet('csv','table')]
    [string]$OutputFormat='csv',

    [Parameter( 
        Position=4,
        Mandatory=$false, 
        ParameterSetName = "SQLAuthentication",
        ValueFromPipeline=$false, 
        ValueFromPipelineByPropertyName=$true) 
    ] 
    [switch]$SQLAuthentication
)

# Function to handler error and exit
function die {
    Write-Error "Error: $($args[0])"
    exit 1
}

function check_snapin {
    # Check and load SQLPS and SnapIns
    if (-not(Get-Module -Name SQLPS) -and (-not(Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -ErrorAction SilentlyContinue))) {
        Write-Verbose -Message 'SQLPS PowerShell module or snapin not currently loaded'
            if (Get-Module -Name SQLPS -ListAvailable) {
                Write-Verbose -Message 'SQLPS PowerShell module found'
                if ((Get-ExecutionPolicy) -ne 'Restricted') {
                    Import-Module -Name SQLPS -DisableNameChecking -Verbose:$false
                    Write-Verbose -Message 'SQLPS PowerShell module successfully imported'
                }
                else{
                    Write-Warning -Message 'The SQLPS PowerShell module cannot be loaded with an execution policy of restricted'
                }
            }
            elseif (Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -Registered -ErrorAction SilentlyContinue) {
                Write-Verbose -Message 'SQL PowerShell snapin found'
                Add-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100
                Write-Verbose -Message 'SQL PowerShell snapin successfully added'
                [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null
                Write-Verbose -Message 'SQL Server Management Objects .NET assembly successfully loaded'
            }
            else {
                die 'SQLPS PowerShell module or snapin not found'
            }
    }
    else {
        Write-Verbose -Message 'SQL PowerShell module or snapin already loaded'
    }
}

function exec_sqlcmd(){
    $SqlParams.Remove('Query')
    foreach ($file in Get-ChildItem -path $SqlDir -Filter *.sql | sort-object -Property fullname)
    {
        if ($OutputFormat -eq "csv")
        {
            $SqlParams.InputFile = $file.fullname
            $Output = join-path -path $Sqldir -childpath  $([System.IO.Path]::ChangeExtension($file.name, ".csv"));
            invoke-sqlcmd @SqlParams | Export-Csv -Path $Output
            Write-Host $Output 
        }
        elseif ($OutputFormat -eq "table")
        {
            $SqlParams.InputFile = $file.fullname
            $Output = join-path -path $SqlDir -childpath  $([System.IO.Path]::ChangeExtension($file.name, ".txt"));
            invoke-sqlcmd @SqlParams | Format-Table | Out-File -FilePath $Output 
            Write-Host $Output 
        }
    }
}

function check_connection(){
    $SqlParams.Add('Query', 'select @@servername')
    try {
        Invoke-Sqlcmd @SqlParams | Out-Null
    }
    Catch {
        die "Failed to estabilished connection on SQLServer. Parameters: $SqlParams"
    }
}

function exec_readhost(){
    Write-host "Would you like to continue? (Default: no)" -ForegroundColor Yellow 
    $Readhost = Read-Host "[yes/no]" 
    Switch ($ReadHost) 
    { 
            yes {Write-host ""} 
             no {Write-Host "" ; exit 0} 
        Default {Write-Host "" ; exit 0 } 
    }
}

function list_files(){
    Get-ChildItem -path $SqlDir -Filter *.sql | sort-object -Property Name | Format-Table -HideTableHeaders -Property Name
}

function main(){
    $SqlParams = [ordered]@{
            'ServerInstance'    = $SQLServer
            'Database'          = $Database
            'OutputSqlErrors'   = $TRUE
            'ErrorAction'       = 'SilentlyContinue'
    }
    if ($SQLAuthentication){
        $Username = Read-Host "Please enter your username"
        $Password = Read-Host -assecurestring "Please enter your password"
        $SqlParams.Add('Username', $Username)
        $SqlParams.Add('Password', $Password) 
               
    }
    
    Write-Host "Parameters:" -Foreground Green  
    Write-Host ($SqlParams | Sort-Object -Property key | Out-String )
    Write-Host "`nScripts:" -Foreground Green -NoNewline
    list_files
    exec_readhost
    check_snapin
    check_connection
    exec_sqlcmd
    Write-Host "Execution completed." -Foreground Green
}

# MAIN
main

param (
    [string]$FileName = (Get-Date -Format "yyyy-MM-dd"),
    [string]$DbHost = "127.0.0.1",
    [string]$DbUser = "root",
    [string]$DbPassword = "root",
    [Parameter(Mandatory=$true)][string]$DbName,
	[Parameter(Mandatory=$true)][string]$GoogleUser,
    [string]$CredentialsPath = "credentials.json",
    [Parameter(Mandatory=$true)][string]$AdminEmail
)

# Clear backups/logs folder
Get-ChildItem -Path ($PSScriptRoot + "\backups") -Include *.sql, *.zip -File -Recurse | foreach { $_.Delete()}
Get-ChildItem -Path ($PSScriptRoot + "\logs") -Include *.log -File -Recurse | foreach { $_.Delete()}

# Executables path
$MySqlDumpPath = $PSScriptRoot + "\bin\mysqldump.exe"
$7zipPath = $PSScriptRoot + "\bin\7za.exe"

# Output files path
$errorLogPath = $PSScriptRoot + "\logs\error.log"
$dumpFilePath = $PSScriptRoot + "\backups\{0}-{1}.sql" -f $DbName, $FileName
$zipFilePath = $PSScriptRoot + "\backups\{0}-{1}.zip" -f $DbName, $FileName

# mysqldump --host=127.0.0.1 --user=root --password=root hollowbills --lock-tables

# Create dump
$processOptions = @{
    FilePath = $MySqlDumpPath
    ArgumentList = "--host={0} --user={1} --password={2} {3} --lock-tables" -f $DbHost, $DbUser, $DbPassword, $DbName
    RedirectStandardOutput = $dumpFilePath
    RedirectStandardError = $errorLogPath
    NoNewWindow = $true
    UseNewEnvironment = $false
    Wait = $true
}
Start-Process @processOptions

# If there's an error then exit:
If (Test-Path -Path $errorLogPath -PathType Leaf) {
    $errors = Get-Content -Path $errorLogPath -Raw
    if ($errors.ToLower().Contains('error')) {
        Write-Output $errors
        exit
    }
}

# If dump file not found then exit
If (-Not (Test-Path -Path $dumpFilePath -PathType Leaf)) {
    Write-Output "SQL Dump file not created"
    exit
}

# 7za a -tzip backups\db.zip backups\db.sql

# Create zip file
$processOptions = @{
    FilePath = $7zipPath
    ArgumentList = 'a -tzip "{0}" "{1}"' -f $zipFilePath, $dumpFilePath
    RedirectStandardOutput = $errorLogPath
    RedirectStandardError = $errorLogPath
    NoNewWindow = $true
    UseNewEnvironment = $false
    Wait = $true
}
Start-Process @processOptions

# If there's an error then exit:
If (Test-Path -Path $errorLogPath -PathType Leaf) {
    $errors = Get-Content -Path $errorLogPath -Raw
    if (-Not $errors.ToLower().Contains('everything is ok')) {
        Write-Output $errors
        exit
    }
}

$ClientSecretsPath = $PSScriptRoot + "\" + $CredentialsPath

$UploadFile = $zipFilePath
 
Set-PSGSuiteConfig -ConfigName HollowBillsConfig -SetAsDefaultConfig -ClientSecretsPath $ClientSecretsPath -AdminEmail $AdminEmail
Start-GSDriveFileUpload -Path $UploadFile -Recurse -Wait -User $GoogleUser
<#
.SYNOPSIS
  Write to Application event Log
.DESCRIPTION
  Write contents of CSV file to eventlog
.INPUTS
  CSV File
.OUTPUTS
  Eventlog entry
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  25/03/2022
  Purpose/Change: Write eventlog from CSV
 .EXAMPLE
  None
#>
﻿# Write EventLog Function
function write-AppEventLog
{
  Param($errorMessage)
  Write-EventLog -LogName $eventLog -EventID $eventID -EntryType $entryType -Source $eventSource -Message $errorMessage
}

# Set Variables
$eventLog = "Application"
$eventSource = "FASCertChecker"
$InputFile = "c:\temp\eventlogentry.csv"

# Check if event source already exists. If not, create it)
If ([System.Diagnostics.EventLog]::SourceExists($eventSource) -eq $False)
{
  New-EventLog -LogName Application -Source $eventSource
}

# check if input CSV file exists
$InputFileExists = Test-Path $InputFile
If ($InFileExists -eq $True)
{
  $EventlogEntry = Import-Csv $InputFile -Delimiter ","
  $eventID = $EventlogEntry.EventID
  $entrytype = $EventlogEntry.EntryType
  $message = $EventlogEntry.Message

  write-AppEventLog $message

  # Remove input CSV file to prevent duplicate entries
  Remove-Item $InputFile
}

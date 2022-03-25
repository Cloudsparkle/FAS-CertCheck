<#
.SYNOPSIS
  Checking Citrix FAS authorization Certificate
.DESCRIPTION
  Check if the Citrix FAS authorization certificate is still valid and alert when renewal is upcoming
.INPUTS
  None
.OUTPUTS
  CSV file for eventlog entry
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  25/03/2022
  Purpose/Change: Check Citrix FAS certificate
  Source used     https://www.ciraltos.com/writing-event-log-powershell/

 .EXAMPLE
  None
#>

function Get-CertificateTemplateName($certificate)
{
  # The template name is stored in the Extension data.
  # If available, the best is the extension named "Certificate Template Name", since it contains the exact name.
  $templateExt = $certificate.Extensions | Where-Object{ ( $_.Oid.FriendlyName -eq 'Certificate Template Name') } | Select-Object -First 1
  if($templateExt)
  {
    return $templateExt.Format(1)
  }
  else
  {
    # Our fallback option is the "Certificate Template Information" extension, it contains the name as part of a string like:
    # "Template=Web Server v2(1.3.6.1.4.1.311.21.8.2499889.12054413.13650051.8431889.13164297.111.14326010.6783216)"
    $templateExt = $certificate.Extensions | Where-Object{ ( $_.Oid.FriendlyName -eq 'Certificate Template Information') } | Select-Object -First 1
    if($templateExt)
    {
      $information = $templateExt.Format(1)

      # Extract just the template name in $Matches[1]
      if($information -match "^Template=(.+)\([0-9\.]+\)")
      {
        return $Matches[1]
      }
      else
      {
        # No regex match, just return the complete information then
        return $information
      }
    }
    else
    {
      # No template name found
      return $null
    }
  }
}

# Initialize variables
$validcertfound = $false
$writetoeventlog = $false
$message = ""

# Prepare for CSV output
$CsvContents = @()
$OutputFile = "c:\temp\eventlogentry.csv"

# Set different date ranges
$date = Get-Date
$date30 = $date.AddDays(30)
$date7 = $date.AddDays(7)
$tomorrow = ($date.AddDays(1)).AddMinutes(1)

# Read all certificates
$usercerts = Get-ChildItem cert:\CurrentUser\My

foreach ($usercert in $usercerts)
{
  $certtemplate = Get-CertificateTemplateName ($usercert)

  # we are only interested in certifictes using this template
  if ($certtemplate -eq "Citrix_RegistrationAuthority")
  {
    # Write-Host "Cert found, checking date"

    if ($date -gt $usercert.notafter)
    {
      # Write-Host "Expired certificate found"
    }
    else
    {
      $validcertfound = $true
      # Check if certificate expires tomorrow
      if ($tomorrow -gt $usercert.notafter)
      {
        # Set up date for eventlog entry
        $message = "Final warning! FAS Certificate will expire tomorrow."
        # Write-Host $message -ForegroundColor Red
        $eventID = 40001
        $entryType = "Error"
        $writetoeventlog = $true
      }
      else
      {
        # Check if certificate expires in the next 7 days
        if ($date7 -gt $usercert.notafter)
        {
          # Set up date for eventlog entry
          $message = "Warning! FAS Certificate will expire in 7 days or less"
          # Write-Host $message -ForegroundColor DarkYellow
          $eventID = 40007
          $entryType = "Error"
          $writetoeventlog = $true
        }
        else
        {
          # Check if certificate expires in the next 30 days
          if ($date30 -gt $usercert.notafter)
          {
            # Set up date for eventlog entry
            $message = "Warning! FAS Certificate will expire in 30 days or less"
            # Write-Host $message -ForegroundColor Yellow
            $eventID = 40030
            $entryType = "Warning"
            $writetoeventlog = $true
          }
        }
      }
    }
  }
}

# If no valid certificates have been foud, they were all expired.
if ($validcertfound -eq $false)
{
  # Set up date for eventlog entry
  $message = "Attention. All certificates have expired. Take action now"
  # Write-Host $message  -ForegroundColor Red
  $eventID = 40000
  $entryType = "Error"
  $writetoeventlog = $true
}

if ($writetoeventlog -eq $true)
{
  $row = New-Object System.Object # Create an object to append to the array
  $row | Add-Member -MemberType NoteProperty -Name "EventID" -Value $eventID
  $row | Add-Member -MemberType NoteProperty -Name "EntryType" -Value $entryType
  $row | Add-Member -MemberType NoteProperty -Name "Message" -Value $message
  $csvContents += $row # append the new data to the array#
  # Write-Host -ForegroundColor Green "Writing outpunt CSV File..."
  $csvContents | Export-CSV -path $OutputFile -NoTypeInformation
}

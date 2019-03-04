# GCE Metadata Watcher for Maintenance events
# 
# based on:
# https://github.com/GoogleCloudPlatform/python-docs-samples/blob/master/compute/metadata/main.py
# https://n3wjack.net/2018/03/14/passing-a-function-as-a-parameter-in-powershell/
# https://stackoverflow.com/questions/32442777/how-to-use-get-method-of-invoke-webrequest-to-build-a-query-string
# https://googlecloudplatform.github.io/google-cloud-powershell/#/google-compute-engine/GceMetadata/Get-GceMetadata

Add-Type -AssemblyName System.Web

Function Start-WaitForMaintenance {
  # TODO specify type
  Param([parameter(Mandatory=$true)] $Callback)

  $metaDataPath = 'instance/maintenance-event'
  $headers = @{
    'Metadata-Flavor' = 'Google'
  }
  $lastMaintenanceEvent = $null
  # [START hanging_get]
  $lastEtag = '0'

:MainLoop While ($True) {
# this fails with GCE Powershell v1.1
#    Try {
#      $response, $newEtag = Get-GceMetadata -Path $metaDataPath -LastETag $lastEtag -AppendETag -WaitUpdate
#    } Catch {
#      # TODO handle 503, sleep then continue
#      # TODO handle other errors
#      Write-Output "Caught $_"
#    }

    $Parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    $Parameters['wait_for_change'] = 1
    $Parameters['last_etag'] = $lastEtag

    $Request = [System.UriBuilder]'http://metadata.google.internal/computeMetadata/v1/instance/maintenance-event'
    $Request.Query = $Parameters.ToString()
    Try {
      $response = Invoke-WebRequest -Uri "$Request" -Header $headers -Method Get -ErrorAction Stop
      $statusCode = $response.StatusCode
      $lastEtag = $response.Headers.ETag
    } Catch [System.Net.WebException] {
      $response = $_.Exception.Response
      $statusCode = $response.StatusCode.Value__
    }
    Switch($statusCode) {
      200 {
        break
      }
      503 {
        # During maintenance the service can return a 503, so these should
        # be retried.
        Start-Sleep 1
        Continue :MainLoop
      }
      default {
        Write-Error "$response"
        Start-Sleep 1
        Continue :MainLoop
      }
    }

    # [END hanging_get]

    If($response.ToString() -eq 'NONE') {
      $maintenanceEvent = $null
    } Else {
      $maintenanceEvent = $response.ToString()
    }

    If($maintenanceEvent -ne $lastMaintenanceEvent) {
      $lastMaintenanceEvent = $maintenanceEvent
      Invoke-Command $Callback -ArgumentList $maintenanceEvent
    }
  }
}

Function Invoke-MaintenanceCallback {
  Param([parameter(Mandatory=$true)] [String] $Event)

  $warningMinutes = 30
  $warningSeconds = $warningMinutes * 60

  If($Event) {
    Write-Output ("Undergoing host maintenance: {0}" -f $Event)
    # & shutdown /i /s /t $warningSeconds /d p:1:1 /c "Host maintainence scheduled, you have $warningMinutes minutes"
  } Else {
    Write-Output "Finished host maintenance"
  }
}

# main
# TODO spawn in the backgrond or a daemon equiv
Start-WaitForMaintenance ${function:Invoke-MaintenanceCallback}

# vim: set ff=dos

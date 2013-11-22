param (
    [Parameter(Position=0, Mandatory=$True)]
    [ValidateSet("Staging", "Production")]
    [string]$Environment,

    [Parameter(Position=1, Mandatory=$True)]
    [string]$ProjectName,

    [Parameter(Position=2, Mandatory=$True)]
    [string]$AzureServiceName,

    [Parameter(Position=3, Mandatory=$True)]
    [string]$AzureSubscriptionName
)

$AzurePackage = "$ProjectName\bin\Release\app.publish\$ProjectName.cspkg"
$ServiceConfig = "$ProjectName\bin\Release\app.publish\ServiceConfiguration.Cloud.cscfg"

if (!(Test-Path "$AzurePackage")) {
	Write-Output "##teamcity[message text='Azure package $AzurePackage not found' status='WARNING']"
	Exit 1
}
if (!(Test-Path "$ServiceConfig")) {
	Write-Output "##teamcity[message text='Service configuration $AzurePackage not found' status='WARNING']"
	Exit 1
}

$DeploymentLabel = "$ProjectName $Environment Deployment %build.number%"

#------------------------------------------------------------------------

Import-Module "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\*.psd1"
Import-AzurePublishSettingsFile "C:\Users\teamcity\OutracksAzure.publishsettings"
Set-AzureSubscription -CurrentStorageAccount "$AzureServiceName" -SubscriptionName "$AzureSubscriptionName"

function AbortDeployment( $message ) {
    Write-Output "##teamcity[buildStatus status='FAILURE' text='{build.status.text} $message']"
    Exit 1
}
 
function Publish()
{
    $deployment = Get-AzureDeployment -ServiceName "$AzureServiceName" -Slot "$Environment" -ErrorVariable a -ErrorAction silentlycontinue 

    if ($deployment.Name -ne $null)
    {
        #Update deployment inplace (usually faster, cheaper, won't destroy VIP)
        UpgradeDeployment
    }
    else
    {
        CreateNewDeployment
    }

    Write-Output "##teamcity[buildStatus status='SUCCESS']"
}

function IsEnvironmentReady()
{
    $status = Get-AzureDeployment -ServiceName "$AzureServiceName" -Slot "$Environment"
    if ( $status -eq $null )
    {
        AbortDeployment("Unable to get information about the current deployment")
    }

    if ( -not $status.RoleInstanceList )
    {
        Write-Output "##teamcity[message text='$Environment environment has no configured instances yet' status='WARNING']"
        return $False
    }

    $notReady = $False

    Foreach ( $roleInstance in $status.RoleInstanceList )
    {
        $instanceName = $roleInstance.InstanceName
        $instanceStatus = $roleInstance.InstanceStatus

        if ( -not $($roleInstance.InstanceStatus -eq "ReadyRole" ))
        {
            Write-Output "##teamcity[message text='$Environment environment instance $instanceName has status $instanceStatus' status='WARNING']"
            $notReady = $True
        }
    }

    if ( $notReady )
    {
        Write-Output "##teamcity[message text='One or more instances is not running' status='WARNING']"
        return $False
    }

    Write-Output "##teamcity[message text='$Environment environment is ready for use']"
    return $True
}

function WaitForEnvironmentToBeReady()
{
    Write-Output "##teamcity[blockOpened name='Waiting for $Environment environment to become ready']"

    $iterations = 0
    while ( -not $(IsEnvironmentReady) )
    {
        $iterations = $iterations + 1
        if ( $iterations -gt 20 ) # Wait up to 5 minutes
        {
            AbortDeployment("Time out while waiting for $Environment environment to become ready")
        }

        Write-Output "##teamcity[message text='Environment is not yet ready, waiting 15 seconds for Azure to spin up instances']"
        Start-Sleep -s 15
    }

    Write-Output "##teamcity[blockClosed name='Waiting for $Environment environment to become ready']"
}

function CreateNewDeployment()
{
    Write-Output "##teamcity[blockOpened name='$Environment Deployment']"
    Write-Output "##teamcity[message text='Creating new deployment for $Environment environment']"
 
    $result = New-AzureDeployment -Slot "$Environment" -Package "$AzurePackage" -Configuration "$ServiceConfiguration" -label "$DeploymentLabel" -ServiceName "$AzureServiceName"
    if ( $result -eq $null )
    {
        AbortDeployment("Unable to create new deployment")
    }

    $completeDeployment = Get-AzureDeployment -ServiceName "$AzureServiceName" -Slot "$Environment"
    $completeDeploymentID = $completeDeployment.deploymentid

    WaitForEnvironmentToBeReady

    Write-Output "##teamcity[message text='Deployment for $Environment environment successfully created']"
    Write-Output "##teamcity[blockClosed name='$Environment Deployment']"
}

function UpgradeDeployment()
{
    Write-Output "##teamcity[blockOpened name='$Environment Deployment']"
    Write-Output "##teamcity[message text='Upgrading existing deployment for $Environment environment']"

    # perform Update-Deployment
    $result = Set-AzureDeployment -Upgrade -Slot "$Environment" -Package "$AzurePAckage" -Configuration "$ServiceConfiguration" -label "$DeploymentLabel" -ServiceName "$AzureServiceName" -Force
    if ( $result -eq $null )
    {
        AbortDeployment("Unable to upgrade deployment")
    }

    $completeDeployment = Get-AzureDeployment -ServiceName "$AzureServiceName" -Slot "$Environment"
    $completeDeploymentID = $completeDeployment.deploymentid

    WaitForEnvironmentToBeReady

    Write-Output "##teamcity[message text='Deployment for $Environment environment successfully upgraded']"
    Write-Output "##teamcity[blockClosed name='$Environment Deployment']"
}
 
 Publish

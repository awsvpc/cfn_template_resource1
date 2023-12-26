# Windows Powershell script to bootstrap AWS CloudFormation:Init
# This can be used from a userdata script (in the <powershell> section)
# * Sets up cfn-hup to automatically run when changes are made to an assoicated LaunchConfiguration
# * Does initial invocation of cfn-init
$instanceId = (Invoke-WebRequest http://169.254.169.254/latest/meta-data/instance-id).Content
$region = (Invoke-WebRequest http://169.254.169.254/latest/meta-data/placement/availability-zone).Content -replace ".$"
$tags = (Get-EC2Instance -InstanceId $instanceId -Region $region).RunningInstance.Tags
$autoscalingGroupName = ($tags | Where-Object {$_.Key -eq "aws:autoscaling:groupName"}).Value
$stackId = ($tags | Where-Object {$_.Key -eq "aws:cloudformation:stack-id"}).Value
$launchConfigurationName = (Get-ASAutoScalingGroup -AutoScalingGroupName $autoscalingGroupName -Region $region).LaunchConfigurationName
$launchConfigurationResource = $launchConfigurationName -split "-" | Select-Object -Last 2 | Select-Object -First 1

if ($region -and $stackId -and $launchConfigurationResource) 
{
  Set-Content -Path "c:\cfn\cfn-hup.conf" -Value "[main]`nstack=$stackId`nregion=$region`ninterval=1"
  Set-Content -Path "c:\cfn\hooks.d\cfn-auto-reloader.conf" -Value "[cfn-auto-reloader-hook]`ntriggers=post.update`npath=Resources.$launchConfigurationResource.Metadata.AWS::CloudFormation::Init`naction=cfn-init.exe -v -s $stackid -r $launchConfigurationResource --region $region"
  
  Set-Service -Name cfn-hup -StartupType Automatic
  Start-Service cfn-hup

  & cfn-init.exe -v -s $stackid -r $launchConfigurationResource --region $region
}

#Powershell script to deploy to any window server. 
#Note: This assumes Ruby is installed and is set in global PATH variables
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -command "& cmd.exe /c 'C:\ADHOC\gsruby-scraper\src\worker\deploy_task.bat'"'

$trigger =  New-ScheduledTaskTrigger -Daily -At 1am

Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Scraper" -Description "Daily web scraper"
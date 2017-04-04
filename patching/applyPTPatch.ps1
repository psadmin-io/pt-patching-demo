Param (
        [string]$patchlevel,
        [string]$database = 'Yes',
        [string]$bootstrap = 'Yes',
        [string]$puppet = 'Yes'
    )

Write-Host "Patch Level: $patchlevel, Patch Database: $database, Run Bootstrap: $bootstrap, Run Puppet: $puppet"
$start_dir = Get-Location
# Get Start Time
$startDTM = (Get-Date)
$computername = $env:computername

# Update Hosts entry for demo network
install-module PsHosts
$fqdn = facter fqdn
$ip = facter ipaddress
add-hostentry $fqdn $ip

# Patch Database?
# --------------
if ($database -eq 'Yes'){

    Write-Host "[${computername}][Task] Patch Database"
    $ca_dir = "C:\Program Files\PeopleSoft\Change Assistant"

    Set-Location $ca_dir
    copy-item -Path $start_dir\changeassistantcfgbak.zip -Destination $ca_dir
    # drop memory to 512m from 1g
    (Get-Content "C:\Program Files\PeopleSoft\Change Assistant\changeassistant.bat").replace('jre\bin\java -Xms512m -Xmx1g com.peoplesoft.pt.changeassistant.client.main.frmMain %*', 'jre\bin\java -Xms256m -Xmx512m com.peoplesoft.pt.changeassistant.client.main.frmMain %*') | Set-Content "C:\Program Files\PeopleSoft\Change Assistant\changeassistant.bat"
    .\changeassistant.bat -MODE UM -ACTION IMPCFG -SETTINGS Y -OVERWRITE Y -CALLBY INSTALLATION -FILE "changeassistantcfgbak.zip"
    .\changeassistant.bat -MODE UM -ACTION PTPAPPLY -TGTENV PSFTDB -UPD PTP${patchlevel} -WARNINGSOK Y -EXONERR N
    # Insert Step in here if there are PeopleTools Retrofits  - use App Designer to copy project from file

    Set-Location $start_dir
    Write-Host "[${computername}][Done] Patch"  -ForegroundColor green
}
$endDatabaseDTM = (Get-Date)

if ($bootstrap -eq 'Yes'){


    # Create Base Folder
    # ------------------
    Write-Host "[${computername}][Task] Create Base Folders"
    if ( -not ( test-path e:\psft ) )        { mkdir e:\psft }
    if ( -not ( test-path e:\psft\cfg ) )    { mkdir e:\psft\cfg }
    if ( -not ( test-path e:\oracle ) )      { mkdir e:\oracle }  
    Write-Host "[${computername}][Done] Create Base Folders" -ForegroundColor green

    # Set up automation options for the bootstrap script
    # -------------------------------------------------
    Write-Host "[${computername}][Task] Update Bootstrap Scripts"
    (Get-Content c:\pt$patchlevel\setup\scripts\psft-setup.ps1).replace('"C:\psft"', '"E:\psft"') | Set-Content c:\pt$patchlevel\setup\scripts\psft-setup.ps1
    (Get-Content c:\pt$patchlevel\setup\scripts\psft-setup.ps1).replace('$global:weblogic_admin_pwd = $Null', '$global:weblogic_admin_pwd = "Passw0rd1"') | Set-Content c:\pt$patchlevel\setup\scripts\psft-setup.ps1
    (Get-Content c:\pt$patchlevel\setup\scripts\psft-setup.ps1).replace('100', '50') | Set-Content c:\pt$patchlevel\setup\scripts\psft-setup.ps1
    Write-Host "[${computername}][Done] Update Bootstrap Scripts" -ForegroundColor green

    # Run Bootstrap Script
    # ------------------------------------
    Write-Host "[${computername}][Task] Run Bootstrap Script"
    Set-Location c:\pt$patchlevel\setup
    .\psft-dpk-setup.ps1 -silent -no_env_setup
    $env:PS_HOME = hiera ps_home_location
    Write-Host "[${computername}][Done] Run Bootstrap Script" -ForegroundColor green
}
$endBootstrapDTM = (Get-Date)

if ($puppet -eq 'Yes'){
    # Pre-populate psft_customizations.yaml
    # -------------------------------------
    Write-Host "[${computername}][Task] Copy psft_customizations.yaml"
    mkdir C:\ProgramData\PuppetLabs\puppet\etc\data
    copy-item c:\vagrant\psft_customizations.yaml C:\ProgramData\PuppetLabs\puppet\etc\data\psft_customizations.yaml -force
    Write-Host "[${computername}][Done] Copy psft_customizations.yaml" -ForegroundColor green

    # Copy io_ DPK code
    # -----------------------------
    Write-Host "[${computername}][Task] Update DPK with IO modules"
    copy-item c:\vagrant\site.pp C:\ProgramData\PuppetLabs\puppet\etc\manifests\site.pp -force
    copy-item c:\vagrant\modules\* C:\ProgramData\PuppetLabs\puppet\etc\modules\ -recurse -force
    Write-Host "[${computername}][Done] Update DPK with IO modules" -ForegroundColor green

    # Fix Tuxedo Features Separator Bug
    # ---------------------------------
    Write-Host "[${computername}][Task] Fix DPK Bugs"
    (Get-Content C:\ProgramData\PuppetLabs\puppet\etc\modules\pt_config\lib\puppet\provider\psftdomain.rb).replace("feature_settings_separator = '#'","feature_settings_separator = '/'") | set-content C:\ProgramData\PuppetLabs\puppet\etc\modules\pt_config\lib\puppet\provider\psftdomain.rb
    Write-Host "[${computername}][Done] Fix DPK Bugs" -ForegroundColor green

    # Install Hiera-eyaml
    # -------------------
    Write-Host "[${computername}][Task] Install Hiera-eyaml"
    copy-item c:\vagrant\RubyGemsRootCA.pem "C:\Program Files\Puppet Labs\Puppet\sys\ruby\lib\ruby\2.0.0\rubygems\ssl_certs\" -force
    $env:PATH += ";C:\Program Files\Puppet Labs\Puppet\sys\ruby\bin"
    gem install hiera-eyaml
    Write-Host "[${computername}][Done] Install Hiera-eyaml" -ForegroundColor green

    # Configure Hiera-eyaml
    # ---------------------
    Write-Host "[${computername}][Task] Configure Hiera-eyaml"
    copy-item c:\vagrant\hiera.yaml C:\ProgramData\PuppetLabs\hiera\etc\hiera.yaml -force
    copy-item c:\vagrant\eyaml.yaml C:\ProgramData\PuppetLabs\hiera\etc\eyaml.yaml -force
    [System.Environment]::SetEnvironmentVariable("EYAML_CONFIG", "C:\ProgramData\PuppetLabs\hiera\etc\eyaml.yaml", "Machine")
    if ( -not ( test-path C:\ProgramData\PuppetLabs\puppet\etc\secure\keys) ) { mkdir C:\ProgramData\PuppetLabs\puppet\etc\secure\keys }
    copy-item c:\vagrant\keys\* C:\ProgramData\PuppetLabs\puppet\etc\secure\keys\ -force
    [System.Environment]::SetEnvironmentVariable("EDITOR", "C:\Program Files\Sublime Text 3\sublime_text.exe -n -w", "Machine")
    Write-Host "[${computername}][Done] Configure Hiera-eyaml" -ForegroundColor green

    # Remove Current Domains
    # ----------------------
    Write-Host "[${computername}][Task] Remove Domains"
    Stop-Service psft*
    stop-service -name "ORACLE ProcMGR V12.1.3.0.0_VS2012"
    Get-Process | Where-Object {$_.Path -like "*8.55*"} | stop-process -force
    if ( test-path C:\Users\SYSTEM\psft\pt\8.55 ) { Remove-Item -recurse -force C:\Users\SYSTEM\psft\pt\8.55 }
    if ( test-path C:\Users\vagrant\psft\pt\8.55 ) { Remove-Item -recurse -force C:\Users\vagrant\psft\pt\8.55 }
    if ( test-path E:\psft\cfg ) { Remove-Item -recurse -force E:\psft\cfg }
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='PsftPIADomainpeoplesoftService'"
    $service.processid | stop-process 
    $service.delete()
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='PsftAppServerDomainAPPDOMService'"
    $service.processid | stop-process 
    $service.delete()
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='PsftPrcsDomainPRCSDOMService'"
    $service.processid | stop-process 
    $service.delete()
    $service = Get-WmiObject -Class Win32_Service -Filter "Name='ORACLE ProcMGR V12.1.3.0.0_VS2012'"
    $service.processid | stop-process 
    Write-Host "[${computername}][Done] Remove Domains" -Foreground green

    # Deploy Server
    # -------------
    Write-Host "[${computername}][Task] Deploy Server"
    $env:PATH += ";C:\Program Files\Puppet Labs\Puppet\bin"
    puppet apply C:\ProgramData\PuppetLabs\puppet\etc\manifests\site.pp
    Write-Host "[${computername}][Done] Deploy Server" -ForegroundColor green

    # Restart Services
    # ----------------
    Write-Host "[${computername}][Task] Restart Services"
    Restart-Service psftApp*
    Restart-Service psftPIA*
    Restart-Service psftPrcs*
    Write-Host "[${computername}][Done] Restart Services" -ForegroundColor green
}
$endPuppetDTM = (Get-Date)

Set-Location $start_dir


Write-Host " "
Write-Host " "
Write-Host " "
Write-Host " "

# Report Times 
$ts = New-TimeSpan -Seconds $(($endDatabaseDTM-$startDTM).totalseconds)
$elapsedTime = '{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds
Write-Host "Database Patch Time: `t${elapsedTime}"

$ts = New-TimeSpan -Seconds $(($endBootstrapDTM-$endDatabaseDTM).totalseconds)
$elapsedTime = '{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds
Write-Host "Bootstrap Time: `t${elapsedTime}"

$ts = New-TimeSpan -Seconds $(($endPuppetDTM-$endBootstrapDTM).totalseconds)
$elapsedTime = '{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds
Write-Host "Puppet Time: `t`t${elapsedTime}"

$endDTM = (Get-Date)
$ts = New-TimeSpan -Seconds $(($endDTM-$startDTM).totalseconds)
$elapsedTime = '{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds
Write-Host "--------------------`t--------"
Write-Host "Total Patch Time: `t${elapsedTime}"
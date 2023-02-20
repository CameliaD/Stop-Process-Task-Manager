<#
-> Running this script with admin rights
#>
<#
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}
#>
<#
-> Reading the User Interface
#>
Add-Type -AssemblyName PresentationFramework
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

$scriptLocationOnThisPC = split-path -parent $MyInvocation.MyCommand.Definition
$configFilesLocationOnThisPC = "$scriptLocationOnThisPC\Config files"
[xml]$xaml = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        Title="Stop Process" Height="660" Width="491" WindowStyle="ToolWindow" ResizeMode="NoResize">
    <Window.Background>
        <ImageBrush ImageSource="$configFilesLocationOnThisPC\bcgrStopProcess.jpg"/>
    </Window.Background>
    <Grid Margin="0,45,0,12">

        <Button Name="btnRefresh" Content="🔃 Refresh" Cursor="Hand" HorizontalAlignment="Left" Height="35" Margin="35,505,0,0" VerticalAlignment="Top" Width="204" FontFamily="Segoe UI Black" Foreground="Black" OpacityMask="#FFAC1313" BorderBrush="#FF94A5AA" FontSize="18">
            <Button.Background>
                <ImageBrush ImageSource="$configFilesLocationOnThisPC\btnStoProcess.jpg"/>
            </Button.Background>
        </Button>
        <Button Name="btnStop" Content="✋ Stop" Cursor="Hand" HorizontalAlignment="Left" Height="35" Margin="245,505,0,0" VerticalAlignment="Top" Width="204" FontFamily="Segoe UI Black" Foreground="Black" OpacityMask="#FFAC1313" BorderBrush="#FF94A5AA" FontSize="18" RenderTransformOrigin="-0.28,0.429">
            <Button.Background>
                <ImageBrush ImageSource="$configFilesLocationOnThisPC\btnStoProcess.jpg"/>
            </Button.Background>
        </Button>
        <Image HorizontalAlignment="Left" Height="135" VerticalAlignment="Top" Width="137" RenderTransformOrigin="4.6,4.75" Margin="350,-75,0,0" Source="$configFilesLocationOnThisPC\Logo 2.jpeg">
            <Image.OpacityMask>
                <ImageBrush ImageSource="$configFilesLocationOnThisPC\Logo 2.jpeg" Stretch="Uniform"/>
            </Image.OpacityMask>
        </Image>
        <ListBox Name="LBProcesses" HorizontalAlignment="Left" Height="455" Margin="35,25,0,0" VerticalAlignment="Top" Width="414">

        </ListBox>
        <Label Name="LTitle" Content="Processes" HorizontalAlignment="Left" Height="60" Margin="35,-35,0,0" VerticalAlignment="Top" Width="414" FontFamily="Segoe UI Black" FontSize="30" Foreground="#FF051A29" Padding="0,5,5,5"/>
    </Grid>
</Window>
"@
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
catch{Write-Host "Unable to load Windows.Markup.XamlReader"; exit}
 
# Store Form Objects In PowerShell
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)}


<#
-> Load XAML elements into a hash table to be able to create the timer object
#>
$script:TEnableStop = [hashtable]::Synchronized(@{})
$TEnableStop.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
    $TEnableStop.$($_.Name) = $TEnableStop.Window.FindName($_.Name)
}

<#
-> Create a timer object to check if the stop button should be enabled
#>
$TEnableStop.Stopwatch = New-Object System.Diagnostics.Stopwatch
$TEnableStop.Timer = New-Object System.Windows.Forms.Timer
$TEnableStop.Timer.Enabled = $true
$TEnableStop.Timer.Interval = 55
$TEnableStop.Stopwatch.Start()
$TEnableStop.Timer.Add_Tick({
if($LBProcesses.SelectedItem -eq $null) {
    $btnStop.IsEnabled = $false
}
else {
    $btnStop.IsEnabled = $true
}
})
$TEnableStop.Timer.Start()

<#
-> Create a timer object to pause the script when the process list blinks green
#>
$Script:TPause = New-Object System.Windows.Forms.Timer
$TPause.Interval = 100
 
Function Timer_Tick
{
    --$Script:CountDown
    If ($Script:CountDown -lt 0) {
        $TPause.Stop(); 
        $LBProcesses.Background = "white"
        $TPause.Dispose();
    } 
}
 
$Script:CountDown = 1
$TPause.Add_Tick({ Timer_Tick})
    


<#
-> Adding a function that lists the running processes on the PC
#>
function List-Processes { 
    $LBProcesses.Items.Clear()  
    $LBProcesses.Background = "#c7ffd8"
    $TPause.Start()   
    Get-Process | ForEach-Object {$LBProcesses.Items.Add($_.ProcessName)}
}


<#
-> Adding click action to Refresh button and Stop button
#>
$btnRefresh.Add_click({
    List-Processes

})

$btnStop.Add_click({
    $a = new-object -comobject wscript.shell 
    $intAnswer = $a.popup("Are you sure that you want to stop $($LBProcesses.SelectedItem)?", 0,"Stop process",4) 
    If ($intAnswer -eq 6) { 
        Stop-Process -Name $LBProcesses.SelectedItem
        Start-Sleep -Seconds 3
        List-Processes
    }
})


List-Processes
$Form.ShowDialog()

# Authors : Samlach22, Mahtwo
# Description : Download a video from darkibox.com without the UI, Browser or 60 seconds limit
# Version : 0.1
# Date : 2024-01-30
# Usage : Run the script with PowerShell 7

#Requires -Version 7
Invoke-Expression "$psscriptroot/libs/yt-dlp -U" # update yt-dlp
function WaitUntilElementExistsAndClick($xpathValue) {
    while($true) {
        try {
            $FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath($xpathValue)).Click()
            break
        }
        catch {
            # do nothing
        }
    }
}

Function Show-Menu () {
    Param(
        [Parameter(Mandatory = $True)][String]$MenuTitle,
        [Parameter(Mandatory = $True)][array]$MenuOptions
    )
    $MaxValue = $MenuOptions.count - 1
    $Selection = 0
    $EnterPressed = $False
    Clear-Host
    While ($EnterPressed -eq $False) {
        Write-Host "$MenuTitle"
        For ($i = 0; $i -le $MaxValue; $i++) {
            If ($i -eq $Selection) {
                Write-Host -BackgroundColor Cyan -ForegroundColor Black "[ $($MenuOptions[$i]) ]"
            }
            Else {
                Write-Host "  $($MenuOptions[$i])  "
            }
        }
        $KeyInput = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown").virtualkeycode
        Switch ($KeyInput) {
            13 {
                $EnterPressed = $True
                Return $Selection
                Clear-Host
                break
            }
            38 {
                If ($Selection -eq 0) {
                    $Selection = $MaxValue
                }
                Else {
                    $Selection -= 1
                }
                Clear-Host
                break
            }
            40 {
                If ($Selection -eq $MaxValue) {
                    $Selection = 0
                }
                Else {
                    $Selection += 1
                }
                Clear-Host
                break
            }
            Default {
                Clear-Host
            }
        }
    }
}

###################
# IMPORT SELENIUM #
###################
Import-Module "$psscriptroot\libs\WebDriver.dll"

#######################
# SETUP CHROME DRIVER #
#######################
$FirefoxDriverPath = "$psscriptroot\libs\geckodriver.exe" # Path to the FirefoxDriver.exe
$uBlockExtensionPath = "$psscriptroot\libs\uBlock0_1.55.1b28.firefox.signed.xpi"

$FirefoxOption = New-Object OpenQA.Selenium.Firefox.FirefoxOptions
$FirefoxOption.AddArguments("--start-maximized")
$FirefoxOption.AddArguments("--hideCommandPromptWindow")
#$FirefoxOption.AddArguments('--headless') # don't open the browser
$FirefoxOption.AcceptInsecureCertificates = $true # Ignore the SSL non secure issue
$FirefoxOption.AddArgument("--user-agent=$userAgent")
$FirefoxOption.BinaryLocation = "$psscriptroot\firefox122\App\Firefox64\firefox.exe"
$FirefoxOption.SetPreference("xpinstall.signatures.required", $false);

$FirefoxDriver = New-Object OpenQA.Selenium.Firefox.FirefoxDriver($FirefoxDriverPath, $FirefoxOption)
$FirefoxDriver.InstallAddOnFromFile($uBlockExtensionPath)

$url = $args[0]

###########
# RESEACH #
###########

# Open the website
$FirefoxDriver.Navigate().GoToUrl("https://catalogue.darkino.pro/")
WaitUntilElementExistsAndClick("/html/body/div[4]/header/nav/div/div[2]/div[1]/button")
# Search the film
$FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/div[4]/div[1]/div[2]/div/form/div/div[1]/div/input")).SendKeys($url)
$FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/div[4]/div[1]/div[2]/div/form/div/div[2]/div/button")).Click()
# Get the table
$tableDiv = $FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/div[4]/div[1]/div[1]/div[1]/div[2]/div[3]/div"))
$resultArray = @()
foreach ($div in $tableDiv.FindElements([OpenQA.Selenium.By]::ClassName("xxl:col-span-3"))) {
    $film = ""
    $category = ""

    $htmlContent = $div.GetAttribute("innerHTML")

    # Use regex to extract film information
    $filmRegex = '<span class="title">([^<]*)</span>'
    $filmMatch = [regex]::Match($htmlContent, $filmRegex)
    if ($filmMatch.Success) {
        $film = $filmMatch.Groups[1].Value.Trim()
    }

    # Use regex to extract category information
    $categoryRegex = '<a href="https://catalogue.darkino.pro\?category=[^"]+" wire:navigate="">([^<]*)</a>'
    $categoryMatch = [regex]::Match($htmlContent, $categoryRegex)
    if ($categoryMatch.Success) {
        $category = $categoryMatch.Groups[1].Value.Trim()
    }

    # Use regex to extract link information
    $linkRegex = '<div class="box-body"><a href="([^<]*)" class="product-image" wire:navigate="">'
    # remove line returns, tabs and spaces from htmlContent
    $htmlContent = $htmlContent -replace "[\r\n\t]", ""
    $htmlContent = $htmlContent -replace "  ", ""
    $linkMatch = [regex]::Match($htmlContent, $linkRegex)
    if ($linkMatch.Success) {
        $link = $linkMatch.Groups[1].Value.Trim()
        $link
    }

    if ($film -ne "" -and $category -ne "") {
        $resultArray += "$category | $film | $link"
    }
}

# remove duplicates
$resultArray = $resultArray | Sort-Object -Unique
# remove empty elements
$resultArray = $resultArray | Where-Object { $_ -ne "" }

# result array without link
$array = $resultArray | ForEach-Object { $_.Split("|")[0..1] -join "|" }

###############
# CREATE MENU #
###############
$title = "******************************************`nHere is your search results. Choose your option:`n******************************************"
$result = Show-Menu -MenuTitle $title -MenuOptions $array
$link = $resultArray[$result].Split("|")[-1].Trim()

$FirefoxDriver.Navigate().GoToUrl($link)
$table = $FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/div[4]/div[1]/div/div[2]/div/div/div/div[2]/div[2]/div/div/div[2]/div[1]/div/div/div/div[2]/table/tbody"))
$filmName = $FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/div[4]/div[1]/div/div[2]/div/div/div/div[1]/div[2]/div[1]/div/div[1]/div[1]/div")).Text
######################
# LIST ALL THE LINKS #
######################
$array = @()
foreach ($tr in $table.FindElements([OpenQA.Selenium.By]::TagName("tr"))) {
    $tds = $tr.FindElements([OpenQA.Selenium.By]::TagName("td"))
    # $id = $tds[0].Text
    $size = $tds[1].Text
    $quality = $tds[2].Text
    $language = $tds[3].Text.Replace("`r`n", " ").Replace("`n", " ") # the second replace is for linux usage
    $subtitle = $tds[4].Text.Replace("`r`n", " ").Replace("`n", " ") # the second replace is for linux usage
    # $uploader = $tds[5].Text
    # $date = $tds[6].Text
    $link = $tds[7].FindElement([OpenQA.Selenium.By]::TagName("a")).GetAttribute("href")
    # Write-Output "id = $id | size = $size | quality = $quality | language = $language | subtitle = $subtitle | uploader = $uploader | date = $date | link = $link"
    $array += "$quality | $size | $language | $subtitle | $link"
}
###############
# CREATE MENU #
###############
$title = "******************************************`nWelcome to DarkiLoader. Choose your option:`n******************************************"
$result = Show-Menu -MenuTitle $title -MenuOptions $array
$link = $array[$result].Split("|")[-1].Trim()
$quality = $array[$result].Split("|")[0].Trim()
Write-Output "******************************************`nStart Downloading files, please wait`n******************************************"
##################
# GET IDENTIFIER #
##################
$FirefoxDriver.Navigate().GoToUrl($link)
WaitUntilElementExistsAndClick("/html/body/div[4]/div[1]/div/div[2]/div/div/div/div[2]/div/div[3]/div/form/button")
WaitUntilElementExistsAndClick("/html/body/div[4]/div[1]/div/div[2]/div/div/div/div[2]/div/a/button")
$FirefoxDriver.SwitchTo().Window($FirefoxDriver.WindowHandles[1]) > $null
# wait 2s
Start-Sleep -Seconds 2
$identifier = $FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/main/section/div/form")).GetAttribute("action")
$identifier = $identifier.Substring($identifier.LastIndexOf("/") + 1)
<# THIS SECTION IS WHEN A DAY, THEY FIX THE IDENTIFIER IN THE BUTTON
while($true) {
    try {
        $FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/main/section/div/form/input[7]")).Click()
        break
    }
    catch {
        # do nothing
    }
    # time to wait for the download
    $time = $FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/main/section/div/form/span")).Text
    Write-Host -NoNewline "$time `r"
}
THIS SECTION IS WHEN A DAY, THEY FIX THE IDENTIFIER IN THE BUTTON #>
######################
# DOWNLOAD M3U8 FILE #
######################
$newUrl = "https://darkibox.com/embed-$identifier.html"
$FirefoxDriver.Navigate().GoToUrl($newUrl)
$scripts = $FirefoxDriver.FindElements([OpenQA.Selenium.By]::TagName("script")) # get last script tag
$script = $scripts[$scripts.Count - 2].GetAttribute("innerHTML")
$downloadLink = $script.Substring($script.IndexOf('"') + 1, $script.IndexOf('"', $script.IndexOf('"') + 1) - $script.IndexOf('"') - 1)
$filename = "$filmName - $quality.mkv"
$downloadLink
$filename
Write-Output "START DOWNLOADING $filename..."
Invoke-Expression "$psscriptroot/libs/yt-dlp.exe -o ""$filename"" --no-warnings --enable-file-urls -q --progress --audio-multistreams --video-multistreams --sub-langs all -f mergeall[ext!*=mhtml] ""$downloadLink"""
Write-Output "END DOWNLOADING $filename"

###############
# END SESSION #
###############
pause
$FirefoxDriver.CloseDevToolsSession()
# Author : Samlach22
# Description : Download a video from darkibox.com without the UI, Browser or 60 seconds limit
# Version : 0.1
# Date : 2024-01-30
# Usage : Run the script with PowerShell 7

#Requires -Version 7

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

###################
# IMPORT SELENIUM #
###################
Import-Module "$psscriptroot\libs\WebDriver.dll"

#######################
# SETUP CHROME DRIVER #
#######################
$FirefoxOption = New-Object OpenQA.Selenium.Firefox.FirefoxOptions
$FirefoxOption.AddArguments("--start-maximized")
$FirefoxOption.AddArguments("--hideCommandPromptWindow")
$FirefoxOption.AddArguments('--headless') # don't open the browser
$FirefoxOption.AcceptInsecureCertificates = $true # Ignore the SSL non secure issue
$FirefoxDriverPath = "$psscriptroot\libs\geckodriver.exe" # Path to the FirefoxDriver.exe
$FirefoxOption.AddArgument("--user-agent=$userAgent")
$FirefoxOption.BinaryLocation = "$psscriptroot\firefox122\App\Firefox64\firefox.exe"
$FirefoxDriver = New-Object OpenQA.Selenium.Firefox.FirefoxDriver($FirefoxDriverPath, $FirefoxOption) # Create a new FirefoxDriver Object instance.
$FirefoxDriver.Manage().Timeouts().ImplicitWait = [TimeSpan]::FromSeconds(10) # change timeouts implicit wait
$url = $args[0]

#################
# START PROCESS #
#################
$FirefoxDriver.Navigate().GoToUrl($url)
$table = $FirefoxDriver.FindElement([OpenQA.Selenium.By]::XPath("/html/body/div[4]/div[1]/div/div[2]/div/div/div/div[2]/div[2]/div/div/div[2]/div[1]/div/div/div/div[2]/table/tbody"))

######################
# LIST ALL THE LINKS #
######################
foreach ($tr in $table.FindElements([OpenQA.Selenium.By]::TagName("tr"))) {
    $tds = $tr.FindElements([OpenQA.Selenium.By]::TagName("td"))
    $id = $tds[0].Text
    $size = $tds[1].Text
    $quality = $tds[2].Text
    $language = $tds[3].Text.Replace("`r`n", " ").Replace("`n", " ") # the second replace is for linux usage
    $subtitle = $tds[4].Text
    $uploader = $tds[5].Text
    $date = $tds[6].Text
    $link = $tds[7].FindElement([OpenQA.Selenium.By]::TagName("a")).GetAttribute("href")
    Write-Output "id = $id | size = $size | quality = $quality | language = $language | subtitle = $subtitle | uploader = $uploader | date = $date | link = $link"
}
# TODO : CREATE MENU TO SELECT THE LINK

##################
# GET IDENTIFIER #
##################
$FirefoxDriver.Navigate().GoToUrl($link)
WaitUntilElementExistsAndClick("/html/body/div[4]/div[1]/div/div[2]/div/div/div/div[2]/div/div[3]/div/form/button")
WaitUntilElementExistsAndClick("/html/body/div[4]/div[1]/div/div[2]/div/div/div/div[2]/div/a/button")
$FirefoxDriver.SwitchTo().Window($FirefoxDriver.WindowHandles[1]) > $null
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
Invoke-WebRequest -Uri $downloadLink -OutFile "$psscriptroot\$identifier.m3u8" # download the file

###############
# END SESSION #
###############
pause
$FirefoxDriver.CloseDevToolsSession()
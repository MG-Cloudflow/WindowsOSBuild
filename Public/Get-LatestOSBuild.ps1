﻿Function Get-LatestOSBuild {
    <#
        .SYNOPSIS
            Gets Windows patch release information (Version, Build, Availability date, Hotpatch, Preview, Out-of-band, Servicing option, KB article, KB URL and Catalog URL) for Windows client and server versions.
            Useful for scripting and automation purposes. Supports Windows 10 and Windows Server 2016 onwards. Supports Hotpatch on Windows Server 2022 Azure Edition.
        .DESCRIPTION
            Patch information retrieved from Microsoft Release Health / Update History (Server 2022 | Server 2022 Hotpatch) pages and outputted in a usable format.
            These sources are updated regularly by Microsoft AFTER new patches are released. This means at times this info may not always be in sync with Windows Update.
        .PARAMETER OSName
            This parameter is optional. OS name you want to check. Default value is Win10. Accepted values:

            Windows Client OS Names                              - Win10, Win11, Win11HotPatch.
            Windows Server OS Names                              - Server2016, Server2019, Server2022, Server2022Hotpatch, Server Semi-annual = ServerSAC.
        .PARAMETER OSVersion
            This parameter is mandatory. OS version number you want to check. Accepted values:

            Windows Client OS Versions:
            CB/CBB/SAC (Semi-Annual Channel)                     - 1507, 1511, 1607, 1703, 1709, 1803, 1809, 1903, 1909, 2004, 20H2, 21H2, 22H2, 23H2, 24H2.
            Win 10 LTSB/LTSC (Long-Term Servicing Build/Channel) - 2015 = 1507, 2016 = 1607, 2019 = 1809, 2021 = 21H2.
            Win 11 LTSC (Long-Term Servicing Channel)            - 2024 = 24H2.

            Window Server OS Versions:
            SAC (Semi-Annual Channel)                            - 1709, 1803, 1809, 1903, 1909, 2004, 20H2.
            LTSB/LTSC (Long-Term Servicing Build/Channel)        - Server 2016 = 1607, Server 2019 = 1809, Server 2022 = 21H2.
        .PARAMETER LatestReleases
            This parameter is optional. Returns last x releases (where x is the number of releases you want to display). Default value is 1.
        .PARAMETER BuildOnly
            This parameter is optional. Returns full build number/s only.
        .PARAMETER ExcludePreview
            This parameter is optional. Excludes preview release/s.
        .PARAMETER ExcludeOutOfBand
            This parameter is optional. Excludes out-of-band release/s.
        .PARAMETER PreviewOnly
            This parameter is optional. Returns preview release/s only.
        .PARAMETER OutOfBandOnly
            This parameter is optional. Returns out-of-band/s only.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2
            Show all information on the latest available OS build for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 -LatestReleases 2
            Show all information on the latest 2 releases of OS builds for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 -ExcludePreview -LatestReleases 2
            Show all information on the latest 2 releases excluding preview of OS builds for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 -ExcludeOutOfBand -LatestReleases 2
            Show all information on the latest 2 releases excluding out-of-band of OS builds for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 -PreviewOnly -LatestReleases 2
            Show all information on the latest 2 preview releases of OS builds for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 -OutOfBandOnly -LatestReleases 2
            Show all information on the latest 2 out-of-band releases of OS builds for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 -BuildOnly
            Show only the latest available OS build for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 -PreviewOnly -BuildOnly
            Show only the latest available preview OS build for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 -OutOfBandOnly -BuildOnly
            Show only the latest available out-of-band OS build for for Windows 10 Version 22H2 in list format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 | ConvertTo-Json
            Show all information on the latest available OS build for Windows 10 Version 22H2 in json format.
        .EXAMPLE
            Get-LatestOSBuild -OSName Win10 -OSVersion 22H2 | ConvertTo-Json | Out-File .\Get-LatestOSBuild.json
            Save the json format to a file on the latest available OS build for Windows 10 Version 22H2.

        .NOTES
            Forked from 'Get-Windows10ReleaseInformation.ps1' created by Fredrik Wall.
            https://github.com/FredrikWall/PowerShell/blob/master/Windows/Get-Windows10ReleaseInformation.ps1
            Uses code adapted from 'Get-CurrentPatchInfo.ps1' created by Trevor Jones.
            https://gist.githubusercontent.com/SMSAgentSoftware/79fb091a4b7806378fc0daa826dbfb47/raw/0f6b52cddf82b2aa836a813cf6bc910a52a48c9f/Get-CurrentPatchInfo.ps1
    #>

        Param(
        [CmdletBinding()]
        [Parameter(Mandatory = $true)]
        [String]$OSVersion,

        [Parameter(Mandatory = $false)]
        [String]$LatestReleases = 1,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Win10','Win11','Win11HotPatch','Server2016','Server2019','Server2022','Server2022Hotpatch','ServerSAC')]
        [String]$OSName = "Win10",

        [Parameter(Mandatory = $false)]
        [Switch]$BuildOnly,

        [Parameter(Mandatory = $false)]
        [Switch]$ExcludePreview,

        [Parameter(Mandatory = $false)]
        [Switch]$ExcludeOutOfBand,

        [Parameter(Mandatory = $false)]
        [Switch]$PreviewOnly,

        [Parameter(Mandatory = $false)]
        [Switch]$OutOfBandOnly
    )

    # Disable progress bar to speed up Invoke-WebRequest calls
    $ProgressPreference = 'SilentlyContinue'

    # Enforce TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Define variables for OSName
    If (($OSName) -eq "Win11") {
        $OSBase = "Windows 11"
        $URL = "https://docs.microsoft.com/en-us/windows/release-health/windows11-release-information"
        $TableNumber = 1
        $AtomFeedUrl = "https://support.microsoft.com/en-us/feed/atom/4ec863cc-2ecd-e187-6cb3-b50c6545db92"
    }
    ElseIf (($OSName) -eq "Win10" -or ($OSName) -eq "Server2016" -or ($OSName) -eq "Server2019" -or ($OSName) -eq "ServerSAC") {
        $OSBase = "Windows 10"
        $URL = "https://docs.microsoft.com/en-us/windows/release-health/release-information"
        $TableNumber = 2
        $AtomFeedUrl = "https://support.microsoft.com/en-us/feed/atom/6ae59d69-36fc-8e4d-23dd-631d98bf74a9"
    }
    elseif ($OSName -eq "Win11HotPatch") {
        # --- NEW: Windows 11 Hotpatch public preview branch ---
        #$OSBase = "Windows 11 Hotpatch"
        $OSVersion = "24H2"  # Force OSVersion for Hotpatch preview
        $URL = "https://support.microsoft.com/en-us/topic/release-notes-for-hotpatch-public-preview-on-windows-11-version-24h2-enterprise-clients-c117ee02-fd35-4612-8ea9-949c5d0ba6d1"
        $AtomFeedUrl = "https://support.microsoft.com/en-us/feed/atom/4ec863cc-2ecd-e187-6cb3-b50c6545db92"
    }
    ElseIf ($OSName -eq "Server2022" -or $OSName -eq "Server2022Hotpatch") {
        # Disabled automatic detection of hotfix as it is not a reliable method of guaranteeing devices are applying hotpatch updates, non-hotpatch updates can still be applied.
        # $HotpatchOS = Get-HotFix -Id KB5003508 -ErrorAction SilentlyContinue
        if ($HotpatchOS -or ($OSName -eq "Server2022Hotpatch")) {
            $URL = "https://support.microsoft.com/en-gb/topic/release-notes-for-hotpatch-in-azure-automanage-for-windows-server-2022-4e234525-5bd5-4171-9886-b475dabe0ce8"
            $AtomFeedUrl = "https://support.microsoft.com/en-us/feed/atom/2d67e9fb-2bd2-6742-08ee-628da707657f"
        }
        Else {
            $URL = "https://support.microsoft.com/en-us/help/5005454"
        }
    }
    Else {
        Throw "Get-LatestOSBuild: Unsupported Operating System"
    }

    # Enforce OSVersion for LTSC Server OSName to prevent incorrect OSVersion input
    If ($OSName -eq "Server2016") {
        $OSVersion = "1607"
    }
    ElseIf ($OSName -eq "Server2019") {
        $OSVersion = "1809"
    }
    ElseIf ($OSName -eq "Server2022" -or $OSName -eq "Server2022Hotpatch") {
        $OSVersion = "21H2"
    }

    # Function used for to convert raw array from support URL to a parsed array (currently used only for Server 2022)
    Function Convert-ParsedArray {
        Param($Array)

        $ArrayList = New-Object System.Collections.ArrayList
        ForEach ($item in $Array) {
            [Void]$ArrayList.Add([PSCustomObject]@{
                Update = $item.outerHTML.Split('>')[1].Replace('</a','').Replace('&#x2014;',' - ')
                KB = "KB" + $item.href.Split('/')[-1]
                InfoURL = "https://support.microsoft.com" + $item.href
                OSBuild = [regex]::Match($item.outerHTML,"Build (.*)\)").Groups[1].Value -as [System.Version]
            })
        }
        Return $ArrayList
    }

    # Obtain data from webpage
    Try {
        If ($OSName -eq "Server2022") {
            $Webpage = Invoke-WebRequest -Uri $URL -UseBasicParsing -ErrorAction Stop
        }
        # Supports Server 2022 Hotpatch
        Else {
            If ($HotpatchOS -or ($OSName -eq "Server2022Hotpatch") -or ($OSName -eq "Win11HotPatch")) {
                $Webpage = Invoke-WebRequest -Uri $URL -UseBasicParsing -ErrorAction Stop
            }
            Else {
                # All other OS
                $Webpage = Invoke-RestMethod -Uri $URL -UseBasicParsing -ErrorAction Stop
            }

            # Fetch the Atom feed content, used to obtain preview and out-of-band data
            $response = Invoke-WebRequest -Uri $AtomFeedUrl -Method Get -UseBasicParsing -ErrorAction Stop

            # Extract raw content from the response
            $feedContent = $response.Content

            # Use regular expressions to extract entries
            $pattern = '<entry>\s*<id>(.*?)<\/id>\s*<title\s+type="text">(.*?)<\/title>\s*<published>(.*?)<\/published>\s*<updated>(.*?)<\/updated>\s*<link\s+rel="alternate"\s+href="(.*?)"\s*\/>\s*<content\s+type="text">(.*?)<\/content>\s*<\/entry>'
            $AtomMatches = [regex]::Matches($feedContent, $pattern)

            If ($AtomMatches.Count -eq 0) {
                Throw "Get-LatestOSBuild: No <entry> elements found in the atom feed."
            }
            Else {
                # Initialize a list to store filtered feed entries
                $feedEntries = New-Object System.Collections.Generic.List[PSObject]

                # Iterate over matched entries
                ForEach ($AtomMatch in $AtomMatches) {
                    $title     = $AtomMatch.Groups[2].Value
                    $link      = $AtomMatch.Groups[5].Value

                    # Filter out entries that do not contain "(OS Build" in the title
                    If ($title -like '*(OS Build*') {
                        # Create a hashtable for the entry
                        $feedEntry = @{
                            Title     = $title
                            Link      = $link
                        }

                        # Add the entry to the list
                        $feedEntries.Add([PSCustomObject]$feedEntry)
                    }
                }
            }
        }
    }
    Catch {
        If ($_.Exception.Message -like '*403*') {
            Throw "Get-LatestOSBuild: Unable to obtain patch release information. Akamai CDN denial-of-service protection active. Error: $($_.Exception.Message)"
        }
        Else {
            Throw "Get-LatestOSBuild: Unable to obtain patch release information. Please check your internet connectivity. Error: $($_.Exception.Message)"
        }
    }

    # Server 2022 and Server 2022 Hotpatch and Windows 11 Hotpatch
    If ($OSName -eq "Server2022" -or $OSName -eq "Server2022Hotpatch" -or $OSName -eq "Win11HotPatch") {
        $Table = @()
        $Table =  @(
            if ($OSName -eq "Server2022" -or $OSName -eq "Server2022Hotpatch") {
                $VersionDataRaw = $Webpage.Links | Where-Object { $_.outerHTML -match "supLeftNavLink" -and ($_.outerHTML -match "KB" -or $_.outerHTML -match "Hotpatch baseline") -and $_.outerHTML -notmatch "25398.|17784.|20348.344|20348.410|KB5010614|KB5004312|April 13, 2021 Hotpatch baseline" } | Sort-Object -Property href -Unique
            }
            else {
                try {
                    # Define marker text (ensure these exactly match part of the outerHTML text)
                    $startMarker = 'Public Preview - Release notes for hotpatch on Windows 11, version 24H2 Enterprise clients'
                    $endMarker   = 'Public Preview - Release notes for hotpatch in Azure Automanage for Windows Server 2022'
                
                    # Ensure the links are stored in an array variable.
                    $links = @($Webpage.Links | Where-Object { $_.outerHTML -match "supLeftNavLink" })
                
                    # Get the first object that matches the start and end markers
                    $startObj = ($links | Where-Object { $_.outerHTML -like "*$startMarker*" })[0]
                    if (-not $startObj) {
                        throw "Start marker not found. Verify the marker text exactly matches part of the outerHTML."
                    }
                    
                    $endObj = ($links | Where-Object { $_.outerHTML -like "*$endMarker*" })[0]
                    if (-not $endObj) {
                        throw "End marker not found. Verify the marker text exactly matches part of the outerHTML."
                    }
                
                    # Find the index positions within the $links array
                    $startIndex = $links.IndexOf($startObj)
                    $endIndex   = $links.IndexOf($endObj)
                
                    if ($startIndex -lt 0) {
                        throw "Start index not found in the links array."
                    }
                    if ($endIndex -lt 0) {
                        throw "End index not found in the links array."
                    }
                
                    # Only slice if both indices are valid
                    if ($startIndex -ge 0 -and $endIndex -ge 0) {
                        $result = $links[$startIndex..$endIndex]
                    }
                    else {
                        throw "Could not extract results because one or both markers were not found in the array."
                    }
                
                    # Filter the results further and sort uniquely
                    $VersionDataRaw = $result | Where-Object { 
                        $_.outerHTML -match "supLeftNavLink" -and 
                        ($_.outerHTML -match "KB" -or $_.outerHTML -match "Hotpatch baseline") -and 
                        $_.outerHTML -match "26100"
                    } | Sort-Object -Property href -Unique
                }
                catch {
                    throw $_
                }             
            }
            $UniqueList =  (Convert-ParsedArray -Array $VersionDataRaw) | Sort-Object OSBuild -Descending
            ForEach ($Update in $UniqueList) {
                $ResultObject = [Ordered] @{}
                # Support for Hotpatch
                If ($null -eq $Update.OSBuild.Major) {
                    $ResultObject["Version"] = "Version $OSVersion (OS build 20348)"
                }
                Else {
                    $ResultObject["Version"] = "Version $OSVersion (OS build $($Update.OSBuild.Major))"
                }
                # Support for Hotpatch - As we are performing matching based on date, this accounts for erroronus spaces in the date.
                If ($null -eq $Update.OSBuild) {
                    $updateDate = ($Update.Update -split ',')[0..1] -join ',' -replace '\s+', ' '
                    $SourceOSBuild = $feedEntries.Title -replace '\s+', ' ' -like "*$updateDate*"
                    $ResultObject["Build"] = [String]$SourceOSBuild -replace '.*OS Build (\d+\.\d+).*', '$1'
                }
                Else {
                    $ResultObject["Build"] = [String]$Update.OSBuild
                }
                $GetDate = [regex]::Match($Update.Update,"(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)\s+\d{1,2},\s+\d{4}").Value
                Try {
                    $ConvertToDate = [Datetime]::ParseExact($GetDate, 'MMMM dd, yyyy', [Globalization.CultureInfo]::CreateSpecificCulture('en-US'))
                }
                Catch {
                    $ConvertToDate = [Datetime]::ParseExact($GetDate, 'MMMM d, yyyy', [Globalization.CultureInfo]::CreateSpecificCulture('en-US'))
                }
                $FormatDate =  Get-Date($ConvertToDate) -Format 'yyyy-MM-dd'
                $ResultObject["Availability date"] = $FormatDate
                If ($HotpatchOS -or ($OSName -eq "Server2022Hotpatch") -or ($OSName -eq "Win11HotPatch")) {
                    If ($Update.Update -match 'Hotpatch baseline') {
                        $ResultObject["Hotpatch"] = "False"
                    }
                    Else {
                        $ResultObject["Hotpatch"] = "True"
                    }
                }
                If ($Update.Update -match 'Preview') {
                    $ResultObject["Preview"] = "True"
                }
                Else {
                    $ResultObject["Preview"] = "False"
                }
                If ($Update.Update -match 'Out-of-band') {
                    $ResultObject["Out-of-band"] = "True"
                }
                Else {
                    $ResultObject["Out-of-band"] = "False"
                }
                $ResultObject["Servicing option"] = "LTSC"
                If ($HotpatchOS -or ($OSName -eq "Server2022Hotpatch") -or ($OSName -eq "Win11HotPatch") -and ($ResultObject.Hotpatch -eq "False")) {
                    $ResultObject["KB source article"] = [regex]::Match($SourceOSBuild, 'KB\d{7}').Value
                    $ResultObject["KB article"] = $Update.KB + " / " + $ResultObject.'KB source article'
                }
                Else {
                    $ResultObject["KB article"] = $Update.KB
                }
                If ($HotpatchOS -or ($OSName -eq "Server2022Hotpatch") -or ($OSName -eq "Win11HotPatch") -and ($ResultObject.Hotpatch -eq "False")) {
                    $ResultObject["KB URL"] = $Update.InfoURL
                    $ResultObject["KB source URL"] = "https://support.microsoft.com/en-gb/help/" + $ResultObject.'KB source article'
                }
                Else {
                    $ResultObject["KB URL"] = $Update.InfoURL
                }
                If (($HotpatchOS -or ($OSName -eq "Server2022Hotpatch") -or ($OSName -eq "Win11HotPatch")) -and ($ResultObject.Hotpatch -eq "True")) {
                    $ResultObject["Catalog URL"] =  "N/A"
                }
                Else {
                    $ResultObject["Catalog URL"] =  "https://www.catalog.update.microsoft.com/Search.aspx?q=" + $ResultObject.'KB source article'
                }
                # Cast hash table to a PSCustomObject
                If ($HotpatchOS -or ($OSName -eq "Server2022Hotpatch") -or ($OSName -eq "Win11HotPatch")) {
                    [PSCustomObject]$ResultObject | Select-Object -Property 'Version', 'Build', 'Availability date', 'Hotpatch', 'Preview', 'Out-of-band', 'Servicing option', 'KB article', 'KB URL', 'Catalog URL'
                }
                Else {
                    [PSCustomObject]$ResultObject | Select-Object -Property 'Version', 'Build', 'Availability date', 'Preview', 'Out-of-band', 'Servicing option', 'KB article', 'KB URL', 'Catalog URL'
                }
            }
        )
        $Server2022RTM = [PsCustomObject]@{
            'Version' = "Version 21H2 (OS build 20348)"
            'Build' = "20348.169"
            'Availability date' = "2021-08-18"
            'Preview' = "False"
            'Out-of-band' = "False"
            'Servicing option' = "LTSC"
            'KB article' = "N/A"
            'KB URL' = "N/A"
            'Catalog URL' = "N/A"
        }

        # Add / Sort Arrays
        If ($HotpatchOS -or ($OSName -eq "Server2022Hotpatch") -or ($OSName -eq "Win11HotPatch")) {
            $Table = $Table | Sort-Object -Property 'Availability date' -Descending
        }
        Else {
            $Table = $Table + $Server2022RTM | Sort-Object -Property 'Availability date' -Descending
        }

    }
    # All other OS
    Else {
        # Create HTML object using HTML Agility Pack
        $HTML = (New-Object HtmlAgilityPack.HtmlWeb).Load($URL)

        # Table Mapping - required to obtain preview and out-of-band information of versions
        $GetVersions = @($HTML.DocumentNode.SelectNodes("//strong"))
        $ReleaseVersions = ($GetVersions.innertext).Substring(0)
        $TableMapping = @()
        $TableMapping = ForEach ($Version in $ReleaseVersions) {
            # Windows 11 Base OS
            If ($OSBase -eq "Windows 11") {
                [PSCustomObject]@{
                    'Base' = $OSBase
                    'Version' = $Version
                    'TableNumber'=  $ReleaseVersions.IndexOf($Version) + 2
                }
            }
            # Windows 10 Base OS
            Else {
                [PSCustomObject]@{
                    'Base' = $OSName
                    'Version' = $Version
                    'TableNumber'=  $ReleaseVersions.IndexOf($Version) + 2
                }
            }
        }

        # Get version and table number to search of $OSVersion variable
        $SearchVersion = ($TableMapping | Where-Object { $_.Version -like "Version $OSVersion*(OS build*)" }).Version
        $SearchTable = ($TableMapping | Where-Object { $_.Version -like "Version $OSVersion*(OS build*)" }).TableNumber

        # Perform search and build table
        $Table = @()
        $Table =  @(
            $Tables = @($HTML.DocumentNode.SelectNodes("//table"))
            Try {
                $Table = $Tables[$SearchTable]
            }
            Catch {
                Throw "Get-LatestOSBuild: Operating system name and version combination not supported. OS Name: $OSname, OS Version: $OSVersion, Error: $($_.Exception.Message)"
            }
            $Titles = @()
            $Rows = @($Table.Descendants("tr"))
            Foreach ($Row in $Rows) {
                # Remove not required row
                If ($Row.InnerText -like "*Servicing option*") {
                    Continue
                }
                $Cells = @($Row.Descendants("td"))

                ## If we've found a table header, remember its titles
                If ($null -ne $Cells[0]) {
                    $Titles = $Cells[0].ParentNode.ParentNode.SelectNodes(".//th").Innertext
                }

                ## If we haven't found any table headers, make up names "P1", "P2", etc.
                If (-not $Titles) {
                    $Titles = @(1..($Cells.Count + 2) | ForEach-Object { "P$_" })
                }

                ## Now go through the cells in the the row. For each, try to find the title that represents that column and create a hash table mapping those titles to content
                $ResultObject = [Ordered] @{}
                For ($Counter = 0; $Counter -lt $Cells.Count; $Counter++) {
                    $ResultObject["Version"] = $SearchVersion
                }
                For ($Counter = 0; $Counter -lt $Cells.Count; $Counter++) {
                    $Title = $Titles[$Counter]
                    If (-not $Title) {
                        Continue
                    }
                    If (![string]::IsNullOrEmpty($ResultObject.'Servicing option')) {
                        # Resolve bullet encoding issue - Windows Terminal
                        If ((Test-Path env:WT_SESSION) -eq "True") {
                            # Directly replace the incorrect sequence with the correct bullet point
                            $ResultObject['Servicing option'] = $ResultObject['Servicing option'].Replace([char]0xE2 + [char]0x80 + [char]0xA2, '•')
                        }
                        # Resolve bullet encoding issue - PowerShell
                        Else {
                            # Directly replace the incorrect sequence with the correct bullet point
                            $ResultObject['Servicing option'] = $ResultObject.'Servicing option' -replace '\s*â¢\s*', ' • '
                        }
                    }
                    $ResultObject[$Title] = ("" + $Cells[$Counter].InnerText).Trim()
                    If ((![string]::IsNullOrEmpty($ResultObject.'KB article')) -and ($ResultObject.'KB article' -ne "N/A")) {
                        $KBURL = "https://support.microsoft.com/help/" + ($ResultObject."KB article").Trim("KB")
                        $ResultObject["KB URL"] = $KBURL
                        $ResultObject["Catalog URL"] =  "https://www.catalog.update.microsoft.com/Search.aspx?q=" + $ResultObject.'KB article'
                        If ($KBURL -ne "https://support.microsoft.com/help/") {
                            If ([string]::IsNullOrEmpty($feedEntries)) {
                                $ResultObject["Preview"] = "Unknown"
                                $ResultObject["Out-of-band"] = "Unknown"
                            }

                            $Item = $feedEntries | Where-Object -Property Title -match $ResultObject."KB article"
                            If (($Item.Title -match ($ResultObject."KB article")) -and ($Item.Title -match 'Preview')) {
                                $ResultObject["Preview"] = "True"
                            }
                            Else {
                                $ResultObject["Preview"] = "False"
                            }
                            If (($Item.Title -match ($ResultObject."KB article")) -and ($Item.Title -match 'Out-of-band')) {
                                $ResultObject["Out-of-band"] = "True"
                            }
                            Else {
                                $ResultObject["Out-of-band"] = "False"
                            }
                        }
                    }
                    Else {
                        $ResultObject["Preview"] = "False"
                        $ResultObject["Out-of-band"] = "False"
                        $ResultObject["KB article"] = "N/A"
                        $ResultObject["KB URL"] = "N/A"
                        $ResultObject["Catalog URL"] = "N/A"
                    }
                }
                # Cast hash table to a PSCustomObject
                [PSCustomObject]$ResultObject | Select-Object -Property 'Version', 'Build', 'Availability date','Preview', 'Out-of-band', 'Servicing option', 'KB article', 'KB URL', 'Catalog URL'
            }
        )
    }

    # Return filtered results based upon parameters
    If ($ExcludePreview -eq $true -and $ExcludeOutOfBand -eq $true -and $BuildOnly -eq $true) {
        # Excluding Preview and Out-of-band - Build
        ($Table | Where-Object { (($_.Preview -eq "False" -or $_.Preview -eq "Unknown") -and  ($_.'Out-of-band' -eq "False" -or $_.'Out-of-band' -eq "Unknown")) } | Select-Object -First $LatestReleases)."Build"
    }
    ElseIf ($ExcludePreview -eq $true -and $ExcludeOutOfBand -eq $false -and $BuildOnly -eq $true) {
        # Excluding Preview - Build
        ($Table | Where-Object { $_.Preview -eq "False" -or $_.Preview -eq "Unknown" } | Select-Object -First $LatestReleases)."Build"
    }
    ElseIf ($ExcludePreview -eq $false -and $ExcludeOutOfBand -eq $true -and $BuildOnly -eq $true) {
        # Excluding Out-of-band - Build
        ($Table | Where-Object { $_.'Out-of-band' -eq "False" -or $_.'Out-of-band' -eq "Unknown" } | Select-Object -First $LatestReleases)."Build"
    }
    ElseIf ($ExcludePreview -eq $true -and $ExcludeOutOfBand -eq $true -and $BuildOnly -eq $false) {
        # Excluding Preview and Out-of-band
        ($Table | Where-Object { (($_.Preview -eq "False" -or $_.Preview -eq "Unknown") -and  ($_.'Out-of-band' -eq "False" -or $_.'Out-of-band' -eq "Unknown")) } | Select-Object -First $LatestReleases)
    }
    ElseIf ($ExcludePreview -eq $true -and $ExcludeOutOfBand -eq $false -and $BuildOnly -eq $false) {
        # Excluding Preview
        ($Table | Where-Object { $_.Preview -eq "False" -or $_.Preview -eq "Unknown" } | Select-Object -First $LatestReleases)
    }
    ElseIf ($ExcludePreview -eq $false -and $ExcludeOutOfBand -eq $true -and $BuildOnly -eq $false) {
        # Excluding Out-of-band
        ($Table | Where-Object { $_.'Out-of-band' -eq "False" -or $_.'Out-of-band' -eq "Unknown" } | Select-Object -First $LatestReleases)
    }
    ElseIf ($PreviewOnly -eq $true -and $BuildOnly -eq $false) {
        # Preview Only
        ($Table | Where-Object { $_.Preview -eq "True" } | Select-Object -First $LatestReleases)
    }
    ElseIf ($PreviewOnly -eq $true -and $BuildOnly -eq $true) {
        # Preview Only - Build
        ($Table | Where-Object { $_.Preview -eq "True" } | Select-Object -First $LatestReleases)."Build"
    }
    ElseIf ($OutOfBandOnly -eq $true -and $BuildOnly -eq $false) {
        # Out-of-band Only
        ($Table | Where-Object { $_.'Out-of-band' -eq "True" } | Select-Object -First $LatestReleases)
    }
    ElseIf ($OutOfBandOnly -eq $true -and $BuildOnly -eq $true) {
        # Out-of-band Only - Build
        ($Table | Where-Object { $_.'Out-of-band' -eq "True" } | Select-Object -First $LatestReleases)."Build"
    }
    ElseIf ($BuildOnly -eq $true) {
        # Build
        ($Table | Select-Object -First $LatestReleases)."Build"
    }
    Else {
        # No parameters
        ($Table | Select-Object -First $LatestReleases)
    }
}
# SIG # Begin signature block
# MIImcgYJKoZIhvcNAQcCoIImYzCCJl8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1/fqrOEf4aAJaafKOWgc0Ldv
# cYOggiAtMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0B
# AQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz
# 7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS
# 5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7
# bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfI
# SKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jH
# trHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14
# Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2
# h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt
# 6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPR
# iQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ER
# ElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4K
# Jpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAd
# BgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SS
# y4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAC
# hjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRV
# HSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyh
# hyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO
# 0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo
# 8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++h
# UD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5x
# aiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGYzCCBEug
# AwIBAgIQeAuTgzemd0ILREkKU+Yq2jANBgkqhkiG9w0BAQsFADBWMQswCQYDVQQG
# EwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQD
# ExtDZXJ0dW0gQ29kZSBTaWduaW5nIDIwMjEgQ0EwHhcNMjQwNDExMDYwMzIxWhcN
# MjUwNDExMDYwMzIwWjCBiDELMAkGA1UEBhMCR0IxDzANBgNVBAgMBkRvcnNldDEU
# MBIGA1UEBwwLQk9VUk5FTU9VVEgxHjAcBgNVBAoMFU9wZW4gU291cmNlIERldmVs
# b3BlcjEyMDAGA1UEAwwpT3BlbiBTb3VyY2UgRGV2ZWxvcGVyLCBBU0hMRVkgTUlD
# SEFFTCBIT1cwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQDpmsgFPzl4
# 7W61kLLEp5ljxHC0ZZDti0+DL2JSAac1+bQW24vSjg4ABHhRB5CDKBuwVe2h0l+G
# mEZHhKc9cz/RB+hUIJycd5Qx6VzsI1KJ0heEECm+oo3rywyqrd9RovkhkU2X29cR
# UAa9SWZJJ2+/ImyzfyxzR+u0DD17BucHXWylQB2HGFCcX3kYUmgyZ/ANrgTvetW+
# n91OLxquC5+Nslh4MhbQAnItX79qrFLODd05S3SpQvdti16WGcRwXka4t5zdAMf6
# v3c8ThHKPm/1TsyWsYAUMYJ9C0sNt+QYKNYHRX7DuA1OJBngAyGggtaXmqEpPBX2
# SkDJ0uOeVDoJEOsxNydGZYPgvkIzsyF8YmEzkPK5x5elglYI0wfGwaMKshVbszj5
# KXIPogeF/0vrEi8iIEd+Ro3ZY8ul+TliYf6P55tl3VCuKHDbzcYCtOXURmAPGwxC
# 9wVvTr946eJr+emejOxg4/BZw5Q5GD6Qr8wwyodqholbzp8bfjTFmC8CAwEAAaOC
# AXgwggF0MAwGA1UdEwEB/wQCMAAwPQYDVR0fBDYwNDAyoDCgLoYsaHR0cDovL2Nj
# c2NhMjAyMS5jcmwuY2VydHVtLnBsL2Njc2NhMjAyMS5jcmwwcwYIKwYBBQUHAQEE
# ZzBlMCwGCCsGAQUFBzABhiBodHRwOi8vY2NzY2EyMDIxLm9jc3AtY2VydHVtLmNv
# bTA1BggrBgEFBQcwAoYpaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2Njc2Nh
# MjAyMS5jZXIwHwYDVR0jBBgwFoAU3XRdTADbe5+gdMqxbvc8wDLAcM0wHQYDVR0O
# BBYEFB7BnDzi+HIrft6IpueXUsx5LcgwMEsGA1UdIAREMEIwCAYGZ4EMAQQBMDYG
# CyqEaAGG9ncCBQEEMCcwJQYIKwYBBQUHAgEWGWh0dHBzOi8vd3d3LmNlcnR1bS5w
# bC9DUFMwEwYDVR0lBAwwCgYIKwYBBQUHAwMwDgYDVR0PAQH/BAQDAgeAMA0GCSqG
# SIb3DQEBCwUAA4ICAQBO5qPmZq+cztnjKtz9DyVBkZGaHj/TmfIZHrYfeQ0zdEVL
# EszgokLuqNDdk0odEUHiockPB2dQn60oE3rNs+Wb1ZLLT18VoQTV0saMD3GiNzil
# ejD4nIrhQ+vt0auxCvzBS8cQd24ePmjTqcIkL/u07xGhtT3LpUHUuHknUcEFjgs0
# bUpGR5bofW8B9ZSC31g2i5PKZH8PUgOrTvg8oaMQYWyduKFnW8JRRGqypjUIFDE0
# N224ox/U6GqqIl2cuC87H7WrHPEO6VjqSOx0PgybhSggGDKRNk9UQN1R45K/NCcw
# 5+sIA1pjTZHnMhIJdxamhXiNq2S0U3LRVLSs1/BuXGENFWUraE4c51kDCiBPpGus
# olI7/LLF3PIyYopyAWOGw0R7snlT+HJbfI7P6ObfYzzmIMdrKSaBkNtautcRYcIT
# HAmbUAVplnpexQXXapSqxUfrPXWZk7xRLSXXqn915NbAoofVrTuLNXbv437KmoaN
# p2J23oE7KzqdkoZ9SO4+8K+XKoEqBrPyxNB/i5UIId1Rsu5GE453usJf7zgsz4Ib
# T8MQXjPq0WageEH3cL3qoPGBVbD++hLCJhqHPFJfM3zqxz4xZIRm7dY7GmcVc3Qq
# H0biPnYkTfe8fwrT/IpEmVPdDnUSM92MhV25HV4CYU5LAISU1B070DMFAGc1uTCC
# Bq4wggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0
# MB4XDTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVz
# dGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD
# 0Z5Mom2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39
# Q7SE2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decf
# BmWNlCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RU
# CyFobjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+x
# tVhNef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OA
# e3VuJyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRA
# KKtzQ87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++b
# Pf4OuGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+
# OcD5sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2Tj
# Y+Cm4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZ
# DNIztM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQW
# BBS6FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/
# 57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYI
# KwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9j
# cmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1Ud
# IAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEA
# fVmOwJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnB
# zx0H6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXO
# lWk/R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBw
# CnzvqLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q
# 6/aesXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJ
# uXdmkfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEh
# QNC3EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo4
# 6Zzh3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3
# v5gA3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHz
# V9m8BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZV
# VCsfgPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwgga5MIIEoaADAgECAhEA
# maOACiZVO2Wr3G6EprPqOTANBgkqhkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwx
# IjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNl
# cnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRy
# dXN0ZWQgTmV0d29yayBDQSAyMB4XDTIxMDUxOTA1MzIxOFoXDTM2MDUxODA1MzIx
# OFowVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMg
# Uy5BLjEkMCIGA1UEAxMbQ2VydHVtIENvZGUgU2lnbmluZyAyMDIxIENBMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnSPPBDAjO8FGLOczcz5jXXp1ur5c
# Tbq96y34vuTmflN4mSAfgLKTvggv24/rWiVGzGxT9YEASVMw1Aj8ewTS4IndU8s7
# VS5+djSoMcbvIKck6+hI1shsylP4JyLvmxwLHtSworV9wmjhNd627h27a8RdrT1P
# H9ud0IF+njvMk2xqbNTIPsnWtw3E7DmDoUmDQiYi/ucJ42fcHqBkbbxYDB7SYOou
# u9Tj1yHIohzuC8KNqfcYf7Z4/iZgkBJ+UFNDcc6zokZ2uJIxWgPWXMEmhu1gMXgv
# 8aGUsRdaCtVD2bSlbfsq7BiqljjaCun+RJgTgFRCtsuAEw0pG9+FA+yQN9n/kZtM
# LK+Wo837Q4QOZgYqVWQ4x6cM7/G0yswg1ElLlJj6NYKLw9EcBXE7TF3HybZtYvj9
# lDV2nT8mFSkcSkAExzd4prHwYjUXTeZIlVXqj+eaYqoMTpMrfh5MCAOIG5knN4Q/
# JHuurfTI5XDYO962WZayx7ACFf5ydJpoEowSP07YaBiQ8nXpDkNrUA9g7qf/rCkK
# bWpQ5boufUnq1UiYPIAHlezf4muJqxqIns/kqld6JVX8cixbd6PzkDpwZo4SlADa
# Ci2JSplKShBSND36E/ENVv8urPS0yOnpG4tIoBGxVCARPCg1BnyMJ4rBJAcOSnAW
# d18Jx5n858JSqPECAwEAAaOCAVUwggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0O
# BBYEFN10XUwA23ufoHTKsW73PMAywHDNMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8
# +tT4HKbROg79MA4GA1UdDwEB/wQEAwIBBjATBgNVHSUEDDAKBggrBgEFBQcDAzAw
# BgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3Js
# MGwGCCsGAQUFBwEBBGAwXjAoBggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3At
# Y2VydHVtLmNvbTAyBggrBgEFBQcwAoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVt
# LnBsL2N0bmNhMi5jZXIwOQYDVR0gBDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEW
# GGh0dHA6Ly93d3cuY2VydHVtLnBsL0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAdYhY
# D+WPUCiaU58Q7EP89DttyZqGYn2XRDhJkL6P+/T0IPZyxfxiXumYlARMgwRzLRUS
# tJl490L94C9LGF3vjzzH8Jq3iR74BRlkO18J3zIdmCKQa5LyZ48IfICJTZVJeChD
# UyuQy6rGDxLUUAsO0eqeLNhLVsgw6/zOfImNlARKn1FP7o0fTbj8ipNGxHBIutiR
# sWrhWM2f8pXdd3x2mbJCKKtl2s42g9KUJHEIiLni9ByoqIUul4GblLQigO0ugh7b
# WRLDm0CdY9rNLqyA3ahe8WlxVWkxyrQLjH8ItI17RdySaYayX3PhRSC4Am1/7mAT
# wZWwSD+B7eMcZNhpn8zJ+6MTyE6YoEBSRVrs0zFFIHUR08Wk0ikSf+lIe5Iv6RY3
# /bFAEloMU+vUBfSouCReZwSLo8WdrDlPXtR0gicDnytO7eZ5827NS2x7gCBibESY
# kOh1/w1tVxTpV2Na3PR7nxYVlPu1JPoRZCbH86gc96UTvuWiOruWmyOEMLOGGniR
# +x+zPF/2DaGgK2W1eEJfo2qyrBNPvF7wuAyQfiFXLwvWHamoYtPZo0LHuH8X3n9C
# +xN4YaNjt2ywzOr+tKyEVAotnyU9vyEVOaIYMk3IeBrmFnn0gbKeTTyYeEEUz/Qw
# t4HOUBCrW602NCmvO1nm+/80nLy5r0AZvCQxaQ4wggbCMIIEqqADAgECAhAFRK/z
# lJ0IOaa/2z9f5WEWMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVTMRcwFQYD
# VQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBH
# NCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjMwNzE0MDAwMDAw
# WhcNMzQxMDEzMjM1OTU5WjBIMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xIDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDIzMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAo1NFhx2DjlusPlSzI+DPn9fl0udd
# oQ4J3C9Io5d6OyqcZ9xiFVjBqZMRp82qsmrdECmKHmJjadNYnDVxvzqX65RQjxwg
# 6seaOy+WZuNp52n+W8PWKyAcwZeUtKVQgfLPywemMGjKg0La/H8JJJSkghraarrY
# O8pd3hkYhftF6g1hbJ3+cV7EBpo88MUueQ8bZlLjyNY+X9pD04T10Mf2SC1eRXWW
# df7dEKEbg8G45lKVtUfXeCk5a+B4WZfjRCtK1ZXO7wgX6oJkTf8j48qG7rSkIWRw
# 69XloNpjsy7pBe6q9iT1HbybHLK3X9/w7nZ9MZllR1WdSiQvrCuXvp/k/XtzPjLu
# UjT71Lvr1KAsNJvj3m5kGQc3AZEPHLVRzapMZoOIaGK7vEEbeBlt5NkP4FhB+9ix
# LOFRr7StFQYU6mIIE9NpHnxkTZ0P387RXoyqq1AVybPKvNfEO2hEo6U7Qv1zfe7d
# Cv95NBB+plwKWEwAPoVpdceDZNZ1zY8SdlalJPrXxGshuugfNJgvOuprAbD3+yqG
# 7HtSOKmYCaFxsmxxrz64b5bV4RAT/mFHCoz+8LbH1cfebCTwv0KCyqBxPZySkwS0
# aXAnDU+3tTbRyV8IpHCj7ArxES5k4MsiK8rxKBMhSVF+BmbTO77665E42FEHypS3
# 4lCh8zrTioPLQHsCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMB
# Af8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91jGogj57I
# bzAdBgNVHQ4EFgQUpbbvE+fvzdBkodVWqWUxo97V40kwWgYDVR0fBFMwUTBPoE2g
# S4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNB
# NDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEEgYMwgYAw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcw
# AoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOC
# AgEAgRrW3qCptZgXvHCNT4o8aJzYJf/LLOTN6l0ikuyMIgKpuM+AqNnn48XtJoKK
# cS8Y3U623mzX4WCcK+3tPUiOuGu6fF29wmE3aEl3o+uQqhLXJ4Xzjh6S2sJAOJ9d
# yKAuJXglnSoFeoQpmLZXeY/bJlYrsPOnvTcM2Jh2T1a5UsK2nTipgedtQVyMadG5
# K8TGe8+c+njikxp2oml101DkRBK+IA2eqUTQ+OVJdwhaIcW0z5iVGlS6ubzBaRm6
# zxbygzc0brBBJt3eWpdPM43UjXd9dUWhpVgmagNF3tlQtVCMr1a9TMXhRsUo063n
# QwBw3syYnhmJA+rUkTfvTVLzyWAhxFZH7doRS4wyw4jmWOK22z75X7BC1o/jF5HR
# qsBV44a/rCcsQdCaM0qoNtS5cpZ+l3k4SF/Kwtw9Mt911jZnWon49qfH5U81PAC9
# vpwqbHkB3NpE5jreODsHXjlY9HxzMVWggBHLFAx+rrz+pOt5Zapo1iLKO+uagjVX
# KBbLafIymrLS2Dq4sUaGa7oX/cR3bBVsrquvczroSUa31X/MtjjA2Owc9bahuEMs
# 305MfR5ocMB3CtQC4Fxguyj/OOVSWtasFyIjTvTs0xf7UGv/B3cfcZdEQcm4RtNs
# MnxYL2dHZeUbc7aZ+WssBkbvQR7w8F/g29mtkIBEr4AQQYoxggWvMIIFqwIBATBq
# MFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMu
# QS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAyMSBDQQIQeAuTgzem
# d0ILREkKU+Yq2jAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKA
# ADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYK
# KwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUHbX81i+MNW1DXvWSXirxPz7+u2Aw
# DQYJKoZIhvcNAQEBBQAEggGAhyHCPu4HS3G4uSocfKAADQQDLvSt6lCBXUCB9VQs
# 5JDJSoVLzHpcABI7w6qQDKkd6l61UuD2VoTGYAktvyMyT5JxGbTe5c5YACg5QIFw
# Cd1c3Uj6Cb8M7fX8w0Dqaiw9/mknTuazjZdbSRuP+e1OySN3bCSnRg6jEHC93+Te
# 8rIeTh5uVI74nMneTRfghgEMxuOKBcAE7twkLbatFH+BB3AvTqa9QSg2WRgobXuh
# nZUHiSFYCYHJMdFo6Is3CTOs/hiMp5K0gE4BUsFgZtkxj5zyZBoy4jxG7brEwwAj
# K7RQywO4+XoDpG7eoe27imJnm4RLvqE7D0KrppVS0IkwNiCmaQtNaxvYuFTzuHsB
# bAIXm4zfZoFrZw4MwPEMch+2aGL4RUGgGI9nlZyP8z5T24UbIRTahWqwpqp5Kl7G
# PowUJL6a5+/Wy3FD41xc5AgRPOMkcaqgjQqdjr7ayutCcQ15aiSIYc6YI5h4uvnh
# iOqIm85yJe8qDmCvlijP6AiNoYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEB
# MHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYD
# VQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFt
# cGluZyBDQQIQBUSv85SdCDmmv9s/X+VhFjANBglghkgBZQMEAgEFAKBpMBgGCSqG
# SIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI0MTAwMzIyMDEx
# OVowLwYJKoZIhvcNAQkEMSIEIIOIM2y23Ml5wlnqkv2FjglfWtKoEpVb9oj0PiYe
# hjrrMA0GCSqGSIb3DQEBAQUABIICAFPOcVDFhZh0sxJtengPXYSZPCZRC3DHeTa8
# LTd3udIrWqgPQ2cyYQneRcNfTf0k9XU7cuO/vnyWPxDoXAkhK6CxOjYE0ewvXNuw
# qHQzCA56eGs60Pne/gqDTEp5TH2aIO9fQLAAHGy3WYgi0t8XCuh76aK92J2nOBut
# wnjnQSycHQP+2AcJ9+IFDWUUaHNlXqaMRtgipetLx4tyki55tMO4q04GmZbhTsa0
# x1Ij5gZhz/qgYXvDLaOW1Fh9k7jqVyIw9oAY/qZJm1/X9BqplZ22hmVCHPP8/19w
# lQf5LSDsqLMr/IbNYJeb40Ak9AotXxonfik1A41pZNsjmj8gmKag9/CaFZfsU9P8
# zE9+1j4SQZ00oeoaa164OJ6bTk27CX2n4FgH8LkzGQqlJcXK8Mjb4VqIT+G12Pe4
# kcZVPfOLR4Os4zwdf4OHJyrQSmkUpUrIjKfRYbCQSHshF/iK0hsCw3P56elG6U5V
# zP8A61xa3Ik6YSLMB0VRjMLaVylY+73USP3kU4IHJAJyyaEFM7yIoM/KbFYAJERp
# XCJ4oFaY0i71BtKcaAe8ODSr5koixNnLn8HQv9Y5iuPLEvaiAXtJVxJzr9NezjMb
# nDXoCCoIgRiNQQCoOvuGIM4QOzK1Wwl+lqojk5sOtLo76HUlcq5XV8m3S/Fr+Hep
# 7whADteo
# SIG # End signature block
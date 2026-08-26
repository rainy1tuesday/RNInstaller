function Raynet_ModifyXML {
<#
.SYNOPSIS
    Defines an XML modification component.

.DESCRIPTION
    Modifies XML elements, attributes or text selected with XPath. Supports Add, SetValue and Delete actions, match selection and namespace mappings.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER FileName
    Path to the target file. For MSP/XML components, relative paths are resolved against the package script directory.

.PARAMETER XMLAction
    XML operation to perform: Add, SetValue, or Delete.

.PARAMETER TargetType
    XML node type to operate on: Element, Attribute, or Text.

.PARAMETER XPath
    XPath expression selecting existing XML nodes.

.PARAMETER ParentXPath
    XPath selecting the parent node when adding an element.

.PARAMETER ElementName
    Name of an XML element to create for Add Element.

.PARAMETER AttributeName
    Name of the XML attribute for attribute operations.

.PARAMETER Value
    Value to add or set. Empty-string values are supported.

.PARAMETER Match
    Controls which XPath matches are processed: All, First, Last, or Index. Default: All.

.PARAMETER Index
    Zero-based match index used when Match is Index. Default: 0.

.PARAMETER Namespaces
    Hashtable mapping XPath prefixes to XML namespace URIs.

.PARAMETER Opt_AllowDuplicate
    Allows Add Element to create another matching element. Default: $false.

.PARAMETER Opt_CreateIfMissing
    Allows creation of a missing attribute during SetValue where supported. Default: $false.

.PARAMETER Opt_Action
    Controls which package action executes this component. 'Default' follows the package Install/Uninstall action; 'Install' or 'Uninstall' overrides it for this component. Default: Default.

.PARAMETER Opt_Critical
    Controls failure handling. When true, a component failure stops package execution. When false, the failure is logged and the package continues. Default: $true.

.PARAMETER Opt_Verify
    Enables post-action verification where supported. Default: $true.

.EXAMPLE
    Raynet_ModifyXML -Name 'Set API hostname' -FileName 'C:\Program Files\MyApp\app.exe.config' -XPath "/configuration/app/parameters/add[@name='APIHostname']" -TargetType Attribute -AttributeName 'value' -XMLAction SetValue -Value 'api.example.com' -Match First

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_ModifyXML -Full for complete native PowerShell help.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][ValidateSet('Add','SetValue','Delete')][string]$XMLAction,
        [Parameter(Mandatory)][ValidateSet('Element','Attribute','Text')][string]$TargetType,
        [string]$XPath,
        [string]$ParentXPath,
        [string]$ElementName,
        [string]$AttributeName,
        [AllowNull()][AllowEmptyString()][string]$Value,
        [ValidateSet('All','First','Last','Index')][string]$Match = 'All',
        [ValidateRange(0,2147483647)][int]$Index = 0,
        [hashtable]$Namespaces,
        [bool]$Opt_AllowDuplicate = $false,
        [bool]$Opt_CreateIfMissing = $false,
        [ValidateSet('Default','Install','Uninstall')][string]$Opt_Action = 'Default',
        [bool]$Opt_Critical = $true,
        [bool]$Opt_Verify = $true
    )

    if ($XMLAction -eq 'Add' -and $TargetType -eq 'Element') {
        if ([string]::IsNullOrWhiteSpace($ParentXPath)) {
            throw '-ParentXPath is required for Add Element.'
        }
        if ([string]::IsNullOrWhiteSpace($ElementName)) {
            throw '-ElementName is required for Add Element.'
        }
    }
    elseif ([string]::IsNullOrWhiteSpace($XPath)) {
        throw '-XPath is required for this XML operation.'
    }

    if ($TargetType -eq 'Attribute' -and [string]::IsNullOrWhiteSpace($AttributeName)) {
        throw '-AttributeName is required for attribute operations.'
    }

    $component = @{
        Type                = 'ModifyXML'
        Name                = $Name
        FileName            = $FileName
        XMLAction           = $XMLAction
        TargetType          = $TargetType
        XPath               = $XPath
        ParentXPath         = $ParentXPath
        ElementName         = $ElementName
        AttributeName       = $AttributeName
        Value               = $Value
        Match               = $Match
        Index               = $Index
        Namespaces          = $Namespaces
        Opt_AllowDuplicate  = $Opt_AllowDuplicate
        Opt_CreateIfMissing = $Opt_CreateIfMissing
        Opt_Action          = $Opt_Action
        Opt_Critical        = $Opt_Critical
        Opt_Verify          = $Opt_Verify
        Opt_TimeoutSeconds  = 0
        Opt_SuccessExitCodes = @(0,3010)
        Opt_RebootExitCodes  = @(3010,1641)
        Opt_Force           = $false
    }

    Add-RaynetComponent -Component $component
}

<#
.SYNOPSIS
    Executes a Raynet ModifyXML component.
.DESCRIPTION
    Uses the .NET XML APIs and XPath to add, change or delete XML elements,
    attributes and text content. Namespace mappings and match selection are
    supported.
#>
function Invoke-RaynetModifyXML {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Component,
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][ValidateSet('Install','Uninstall')][string]$Action
    )

    $logs = Get-RaynetComponentLogs -Component $Component -LogRoot $LogRoot -Action $Action
    $log = $logs.WrapperLog

    try {
        $fileName = [string]$Component.FileName
        if (-not (Test-Path -LiteralPath $fileName -PathType Leaf)) {
            throw "XML file [$fileName] was not found."
        }

        Write-RaynetInstallerLog -LogFile $log -Level INFO `
            -Message "XML operation [$($Component.XMLAction)] on [$fileName], target [$($Component.TargetType)]."

        [xml]$document = Get-Content -LiteralPath $fileName -Raw -ErrorAction Stop
        $namespaceManager = New-Object System.Xml.XmlNamespaceManager($document.NameTable)

        if ($Component.Namespaces) {
            foreach ($prefix in $Component.Namespaces.Keys) {
                $namespaceManager.AddNamespace([string]$prefix, [string]$Component.Namespaces[$prefix])
            }
        }

        function Get-MatchedNodes {
            param([string]$Query)

            if ($Component.Namespaces) {
                $nodes = @($document.SelectNodes($Query, $namespaceManager))
            }
            else {
                $nodes = @($document.SelectNodes($Query))
            }

            if ($nodes.Count -eq 0) {
                return @()
            }

            switch ([string]$Component.Match) {
                'First' { return @($nodes[0]) }
                'Last'  { return @($nodes[$nodes.Count - 1]) }
                'Index' {
                    $selectedIndex = [int]$Component.Index
                    if ($selectedIndex -ge $nodes.Count) {
                        throw "Requested XML match index [$selectedIndex], but only [$($nodes.Count)] node(s) matched."
                    }
                    return @($nodes[$selectedIndex])
                }
                default { return @($nodes) }
            }
        }

        $changed = $false
        $xmlAction = [string]$Component.XMLAction
        $targetType = [string]$Component.TargetType

        if ($xmlAction -eq 'Add' -and $targetType -eq 'Element') {
            $parents = Get-MatchedNodes -Query ([string]$Component.ParentXPath)
            if ($parents.Count -eq 0) {
                throw "No XML parent matched ParentXPath [$($Component.ParentXPath)]."
            }

            foreach ($parent in $parents) {
                $duplicate = $false
                foreach ($child in $parent.ChildNodes) {
                    if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
                    if ($child.Name -ne [string]$Component.ElementName) { continue }
                    if ($child.InnerText -ne [string]$Component.Value) { continue }
                    $duplicate = $true
                    break
                }

                if ($duplicate -and -not [bool]$Component.Opt_AllowDuplicate) {
                    continue
                }

                $newElement = $document.CreateElement([string]$Component.ElementName)
                if ($null -ne $Component.Value) {
                    $newElement.InnerText = [string]$Component.Value
                }
                [void]$parent.AppendChild($newElement)
                $changed = $true
            }
        }
        else {
            $nodes = Get-MatchedNodes -Query ([string]$Component.XPath)

            if ($nodes.Count -eq 0) {
                if ($xmlAction -eq 'Delete') {
                    $summary = "No XML node matched XPath [$($Component.XPath)]; nothing needed to be deleted."
                    Write-RaynetInstallerLog -LogFile $log -Level INFO -Message $summary
                    return New-RaynetComponentResult `
                        -Success $true `
                        -ExitCode 0 `
                        -AlreadyInDesiredState $true `
                        -Data @{ Summary = $summary }
                }
                throw "No XML node matched XPath [$($Component.XPath)]."
            }

            foreach ($node in $nodes) {
                switch ($targetType) {
                    'Element' {
                        if ($xmlAction -eq 'SetValue') {
                            if ($node.InnerText -ne [string]$Component.Value) {
                                $node.InnerText = [string]$Component.Value
                                $changed = $true
                            }
                        }
                        elseif ($xmlAction -eq 'Delete') {
                            [void]$node.ParentNode.RemoveChild($node)
                            $changed = $true
                        }
                    }

                    'Text' {
                        if ($xmlAction -eq 'SetValue') {
                            if ($node.InnerText -ne [string]$Component.Value) {
                                $node.InnerText = [string]$Component.Value
                                $changed = $true
                            }
                        }
                        elseif ($xmlAction -eq 'Delete') {
                            if ($node.InnerText -ne '') {
                                $node.InnerText = ''
                                $changed = $true
                            }
                        }
                        elseif ($xmlAction -eq 'Add') {
                            $node.InnerText = ([string]$node.InnerText) + ([string]$Component.Value)
                            $changed = $true
                        }
                    }

                    'Attribute' {
                        if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) {
                            throw 'Attribute operations require XPath to select element nodes.'
                        }

                        $attribute = $node.Attributes[[string]$Component.AttributeName]

                        if ($xmlAction -eq 'Delete') {
                            if ($attribute) {
                                [void]$node.Attributes.Remove($attribute)
                                $changed = $true
                            }
                        }
                        elseif ($xmlAction -eq 'SetValue') {
                            if (-not $attribute) {
                                if (-not [bool]$Component.Opt_CreateIfMissing) {
                                    throw "Attribute [$($Component.AttributeName)] does not exist."
                                }
                                $node.SetAttribute([string]$Component.AttributeName, [string]$Component.Value)
                                $changed = $true
                            }
                            elseif ($attribute.Value -ne [string]$Component.Value) {
                                $attribute.Value = [string]$Component.Value
                                $changed = $true
                            }
                        }
                        elseif ($xmlAction -eq 'Add') {
                            if ($attribute) {
                                if ($attribute.Value -ne [string]$Component.Value) {
                                    throw "Attribute [$($Component.AttributeName)] already exists with a different value."
                                }
                            }
                            else {
                                $node.SetAttribute([string]$Component.AttributeName, [string]$Component.Value)
                                $changed = $true
                            }
                        }
                    }
                }
            }
        }

        if ($changed) {
            $document.Save($fileName)
            $summary = 'XML modification completed successfully.'
            Write-RaynetInstallerLog -LogFile $log -Level SUCCESS -Message $summary
        }
        else {
            $summary = 'XML already reflects the requested state; no change was necessary.'
            Write-RaynetInstallerLog -LogFile $log -Level INFO -Message $summary
        }

        if ($null -eq $Component.Opt_Verify -or [bool]$Component.Opt_Verify) {
            [xml]$verifiedDocument = Get-Content -LiteralPath $fileName -Raw -ErrorAction Stop
            if ($null -eq $verifiedDocument.DocumentElement) {
                throw 'XML verification failed after writing.'
            }
            Write-RaynetInstallerLog -LogFile $log -Level INFO `
                -Message 'Verification succeeded: XML file is well-formed.'
        }

        return New-RaynetComponentResult `
            -Success $true `
            -ExitCode 0 `
            -AlreadyInDesiredState (-not $changed) `
            -Data @{ Summary = $summary }
    }
    catch {
        $summary = "ModifyXML failed. Reason: $($_.Exception.Message)"
        Write-RaynetInstallerLog -LogFile $log -Level ERROR -Message $summary
        Write-RaynetInstallerLog -LogFile $log -Level DEBUG -Message $_.Exception.ToString()

        return New-RaynetComponentResult `
            -Success $false `
            -ExitCode 1 `
            -Error $_.Exception.Message `
            -ErrorMessage $_.Exception.ToString() `
            -Data @{ Summary = $summary }
    }
}

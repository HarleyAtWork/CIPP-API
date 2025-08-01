function Invoke-CIPPStandardCloudMessageRecall {
    <#
    .FUNCTIONALITY
        Internal
    .COMPONENT
        (APIName) CloudMessageRecall
    .SYNOPSIS
        (Label) Set Cloud Message Recall state
    .DESCRIPTION
        (Helptext) Sets the Cloud Message Recall state for the tenant. This allows users to recall messages from the cloud.
        (DocsDescription) Sets the default state for Cloud Message Recall for the tenant. By default this is enabled. You can read more about the feature [here.](https://techcommunity.microsoft.com/t5/exchange-team-blog/cloud-based-message-recall-in-exchange-online/ba-p/3744714)
    .NOTES
        CAT
            Exchange Standards
        TAG
        ADDEDCOMPONENT
            {"type":"autoComplete","multiple":false,"label":"Select value","name":"standards.CloudMessageRecall.state","options":[{"label":"Enabled","value":"true"},{"label":"Disabled","value":"false"}]}
        IMPACT
            Low Impact
        ADDEDDATE
            2024-05-31
        POWERSHELLEQUIVALENT
            Set-OrganizationConfig -MessageRecallEnabled
        RECOMMENDEDBY
        UPDATECOMMENTBLOCK
            Run the Tools\Update-StandardsComments.ps1 script to update this comment block
    .LINK
        https://docs.cipp.app/user-documentation/tenant/standards/list-standards
    #>

    param($Tenant, $Settings)
    $TestResult = Test-CIPPStandardLicense -StandardName 'CloudMessageRecall' -TenantFilter $Tenant -RequiredCapabilities @('EXCHANGE_S_STANDARD', 'EXCHANGE_S_ENTERPRISE', 'EXCHANGE_LITE') #No Foundation because that does not allow powershell access

    if ($TestResult -eq $false) {
        Write-Host "We're exiting as the correct license is not present for this standard."
        return $true
    } #we're done.
    ##$Rerun -Type Standard -Tenant $Tenant -Settings $Settings 'CloudMessageRecall'

    # Get state value using null-coalescing operator
    $state = $Settings.state.value ?? $Settings.state

    try {
        $CurrentState = (New-ExoRequest -tenantid $Tenant -cmdlet 'Get-OrganizationConfig').MessageRecallEnabled
    }
    catch {
        $ErrorMessage = Get-NormalizedError -Message $_.Exception.Message
        Write-LogMessage -API 'Standards' -Tenant $Tenant -Message "Could not get the CloudMessageRecall state for $Tenant. Error: $ErrorMessage" -Sev Error
        return
    }
    $WantedState = if ($state -eq 'true') { $true } else { $false }
    $StateIsCorrect = if ($CurrentState -eq $WantedState) { $true } else { $false }

    if ($Settings.report -eq $true) {
        # Default is not set, not set means it's enabled
        if ($null -eq $CurrentState ) { $CurrentState = $true }
        Set-CIPPStandardsCompareField -FieldName 'standards.CloudMessageRecall' -FieldValue $StateIsCorrect -TenantFilter $Tenant
        Add-CIPPBPAField -FieldName 'MessageRecall' -FieldValue $CurrentState -StoreAs bool -Tenant $Tenant
    }

    # Input validation
    if (([string]::IsNullOrWhiteSpace($state) -or $state -eq 'Select a value') -and ($Settings.remediate -eq $true -or $Settings.alert -eq $true)) {
        Write-LogMessage -API 'Standards' -tenant $Tenant -message 'CloudMessageRecall: Invalid state parameter set' -sev Error
        return
    }

    if ($Settings.remediate -eq $true) {
        Write-Host 'Time to remediate'
        if ($StateIsCorrect -eq $false) {
            try {
                $null = New-ExoRequest -tenantid $Tenant -cmdlet 'Set-OrganizationConfig' -cmdParams @{ MessageRecallEnabled = $WantedState } -useSystemMailbox $true
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Successfully set the tenant Message Recall state to $state" -sev Info
            } catch {
                $ErrorMessage = Get-CippException -Exception $_
                Write-LogMessage -API 'Standards' -tenant $Tenant -message "Failed to set the tenant Message Recall state to $state. Error: $($ErrorMessage.NormalizedError)" -sev Error -LogData $ErrorMessage
            }
        } else {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "The tenant Message Recall state is already set correctly to $state" -sev Info
        }

    }

    if ($Settings.alert -eq $true) {
        if ($StateIsCorrect -eq $true) {
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "The tenant Message Recall is set correctly to $state" -sev Info
        } else {
            Write-StandardsAlert -message "The tenant Message Recall is not set correctly to $state" -object @{CurrentState = $CurrentState; WantedState = $WantedState } -tenant $Tenant -standardName 'CloudMessageRecall' -standardId $Settings.standardId
            Write-LogMessage -API 'Standards' -tenant $Tenant -message "The tenant Message Recall is not set correctly to $state" -sev Info
        }
    }
}

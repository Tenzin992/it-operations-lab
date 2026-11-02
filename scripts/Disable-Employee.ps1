# Disable-Employee.ps1
# Offboards a LabCorp employee: disables the account, removes group access,
# adds a note, and moves it to the Disabled Users OU.

# ---- Fill this in for the departing employee ----
$Username = "mlee"
# --------------------------------------------------

# Stop if this username doesn't exist
if (-not (Get-ADUser -Filter "SamAccountName -eq '$Username'")) {
    Write-Host "User '$Username' not found. No changes made." -ForegroundColor Red
    exit
}

# Disable the account
Disable-ADAccount -Identity $Username

# Remove all groups except Domain Users
Get-ADPrincipalGroupMembership -Identity $Username |
    Where-Object { $_.Name -ne "Domain Users" } |
    ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $Username -Confirm:$false }

# Add a note with today's date
$Today = Get-Date -Format "yyyy-MM-dd"
Set-ADUser -Identity $Username -Description "Disabled $Today - left company"

# Move the account to the Disabled Users OU
Get-ADUser -Identity $Username | Move-ADObject -TargetPath "OU=Disabled Users,OU=LabCorp,DC=lab,DC=local"

# Success message
Write-Host "Offboarded $Username - disabled, removed from groups, moved to Disabled Users" -ForegroundColor Green

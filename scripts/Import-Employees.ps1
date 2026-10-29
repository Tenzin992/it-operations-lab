# Import-Employees.ps1
# Creates LabCorp employee accounts for every row in a CSV file.

# ---- Runs once, before the loop ----
$NewHires = Import-Csv C:\Scripts\new-hires.csv
$ValidDepartments = "IT", "HR", "Sales", "Finance"

# One temporary password for this batch (users must change it at first sign-in)
$Password = Read-Host -AsSecureString "Temporary password for this batch"

# ---- Runs once per person in the CSV ----
foreach ($person in $NewHires) {
    $FirstName  = $person.FirstName
    $LastName   = $person.LastName
    $Department = $person.Department

    # Skip this person if the department isn't one we have
    if ($Department -notin $ValidDepartments) {
        Write-Host "Skipping $FirstName $LastName - department '$Department' is not valid." -ForegroundColor Red
        continue
    }

    # Work out the logon name, OU, and group
    $Username = ($FirstName.Substring(0,1) + $LastName).ToLower()
    $OUPath   = "OU=$Department,OU=Employees,OU=LabCorp,DC=lab,DC=local"
    $Group    = "$Department-Staff"

    # Skip this person if the username already exists
    if (Get-ADUser -Filter "SamAccountName -eq '$Username'") {
        Write-Host "Skipping $Username - already exists." -ForegroundColor Yellow
        continue
    }

    # Create the account, then add it to the department group
    $UserSettings = @{
        Name                  = "$FirstName $LastName"
        GivenName             = $FirstName
        Surname               = $LastName
        SamAccountName        = $Username
        UserPrincipalName     = "$Username@lab.local"
        Path                  = $OUPath
        AccountPassword       = $Password
        ChangePasswordAtLogon = $true
        Enabled               = $true
    }

    New-ADUser @UserSettings
    Add-ADGroupMember -Identity $Group -Members $Username

    Write-Host "Created $Username in $Department and added to $Group" -ForegroundColor Green
}

# New-Employee.ps1
# Creates a new LabCorp employee account in the right OU and group.

# ---- Fill these in for each new hire ----
$FirstName  = "Alex"
$LastName   = "Peters"
$Department = "IT"        # Must be IT, HR, Sales, or Finance
# ------------------------------------------

# Stop if the department isn't one we have
$ValidDepartments = "IT", "HR", "Sales", "Finance"

if ($Department -notin $ValidDepartments) {
  Write-Host "Department '$Department' is not valid. Use IT, HR, Sales, or Finance." -ForegroundColor Red
  exit
}
# Work out the logon name: first initial + last name, all lowercase
$Username = ($FirstName.Substring(0,1) + $LastName).ToLower()

# Work out the OU and group from the department
$OUPath = "OU=$Department,OU=Employees,OU=LabCorp,DC=lab,DC=local"
$Group  = "$Department-Staff"

# Check if user already exist or not
if (Get-ADUser -Filter "SamAccountName -eq '$Username'") {
 Write-Host "User $Username already exists. No changes made." -ForegroundColor Red
 exit
}
# Ask for a temporary password (hidden while typing)
$Password = Read-Host -AsSecureString "Temporary password for $Username"

# All the account settings, in one list
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

# Create the account, then add it to the department group
New-ADUser @UserSettings
Add-ADGroupMember -Identity $Group -Members $Username

Write-Host "Created $Username in $Department and added to $Group" -ForegroundColor Green

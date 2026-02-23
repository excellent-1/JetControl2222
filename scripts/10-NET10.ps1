@'
{
  "sdk": {
    "version": "10.0.103",
    "rollForward": "latestPatch",
    "allowPrerelease": true
  }
}
'@ | Set-Content -Encoding UTF8 -Path .\global.json

dotnet --list-sdks

dotnet --version



# Delete the bad solution file
Remove-Item .\JetControl.sln -Force

# Recreate solution
dotnet new sln -n JetControl

# Re-add projects
dotnet sln add .\src\JetControl\JetControl.csproj
dotnet sln add .\src\JetControl.Runner\JetControl.Runner.csproj
dotnet sln add .\tests\JetControl.Tests\JetControl.Tests.csproj



#NOW Try
make restore
make build
make test


cd C:\JetControl2222Hz

(Get-Content .\tests\JetControl.Tests\BudgetContractTests.cs -Raw) `
  -replace 'TaskFactory\.CreatePerTickTasks', 'JetControl.TaskFactory.CreatePerTickTasks' |
  Set-Content -Encoding UTF8 .\tests\JetControl.Tests\BudgetContractTests.cs

(Get-Content .\tests\JetControl.Tests\TimingSmokeTests.cs -Raw) `
  -replace 'TaskFactory\.CreatePerTickTasks', 'JetControl.TaskFactory.CreatePerTickTasks' |
  Set-Content -Encoding UTF8 .\tests\JetControl.Tests\TimingSmokeTests.cs
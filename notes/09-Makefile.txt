@'
SOLUTION := JetControl.sln
RUNNER_PROJECT := src/JetControl.Runner/JetControl.Runner.csproj
CONFIG := Debug

# Use ">" instead of TAB for recipe lines (GNU make 4+)
.RECIPEPREFIX := >

.PHONY: restore build test run clean test-timing

restore:
> dotnet restore $(SOLUTION)

build:
> dotnet build $(SOLUTION) -c $(CONFIG) --no-restore

test:
> dotnet test $(SOLUTION) -c $(CONFIG) --no-build

test-timing:
> RUN_TIMING_TESTS=true dotnet test $(SOLUTION) -c $(CONFIG) --no-build

run:
> dotnet run --project $(RUNNER_PROJECT) -c $(CONFIG)

clean:
> dotnet clean $(SOLUTION) -c $(CONFIG)
'@ | Set-Content -Encoding ascii -Path .\Makefile
#JET_PROJECT (class library)
#RUNNER_PROJECT (console app) → depends on JET_PROJECT
#TEST_PROJECT (xUnit) → depends on JET_PROJECT

#This Makefile:
#Restore all three (or at least runner + tests; restoring all is simplest)
#Build the runner and tests (building runner builds the library transitively, but building tests ensures test compilation is validated too)
#Test the test project
#Timing test should run the test project (not the runner)
#Clean should clean each csproj (since you no longer have a .sln)

JET_PROJECT    := src/JetControl/JetControl.csproj
RUNNER_PROJECT := src/JetControl.Runner/JetControl.Runner.csproj
TEST_PROJECT   := tests/JetControl.Tests/JetControl.Tests.csproj
CONFIG         := Debug

# Use ">" instead of TAB for recipe lines (GNU make 4+)
.RECIPEPREFIX := >

.PHONY: restore build build-all test test-timing run clean

restore:
> dotnet restore $(JET_PROJECT)
> dotnet restore $(RUNNER_PROJECT)
> dotnet restore $(TEST_PROJECT)

# Builds what you ship/run locally (runner). This also builds JetControl transitively.
build:
> dotnet build $(RUNNER_PROJECT) -c $(CONFIG) --no-restore

# Builds everything including tests (useful for CI-like local check)
build-all:
> dotnet build $(RUNNER_PROJECT) -c $(CONFIG) --no-restore
> dotnet build $(TEST_PROJECT) -c $(CONFIG) --no-restore

test:
> dotnet test $(TEST_PROJECT) -c $(CONFIG) --no-build

# Timing smoke tests are inside the test project, so run tests with the env var enabled.
test-timing:
> cmd /c "set RUN_TIMING_TESTS=true&& dotnet test $(TEST_PROJECT) -c $(CONFIG) --no-build"
#test-timing:
#> RUN_TIMING_TESTS=true dotnet test $(TEST_PROJECT) -c $(CONFIG) --no-build

run:
> dotnet run --project $(RUNNER_PROJECT) -c $(CONFIG) --no-build

clean:
> dotnet clean $(JET_PROJECT) -c $(CONFIG)
> dotnet clean $(RUNNER_PROJECT) -c $(CONFIG)
> dotnet clean $(TEST_PROJECT) -c $(CONFIG)
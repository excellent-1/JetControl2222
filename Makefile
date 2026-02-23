SOLUTION := JetControl.slnx
RUNNER_PROJECT := src/JetControl.Runner/JetControl.Runner.csproj
CONFIG := Debug

# Use ">" instead of TAB for recipe lines (GNU make 4+)
.RECIPEPREFIX := >

.PHONY: restore build test run clean test-timing

restore:
> dotnet restore $(RUNNER_PROJECT)
#> dotnet restore $(SOLUTION)

build:
> dotnet build $(RUNNER_PROJECT) -c $(CONFIG)
# > dotnet build $(SOLUTION) -c $(CONFIG) --no-restore   >>>  switch to building the runner project directly:

test:
> dotnet test tests/JetControl.Tests/JetControl.Tests.csproj -c $(CONFIG)
# > dotnet test $(SOLUTION) -c $(CONFIG) --no-build

test-timing:
> RUN_TIMING_TESTS=true dotnet test $(RUNNER_PROJECT) -c $(CONFIG) --no-build
#> RUN_TIMING_TESTS=true dotnet test $(SOLUTION) -c $(CONFIG) --no-build

run:
> dotnet run --project $(RUNNER_PROJECT) -c $(CONFIG)

clean:
> dotnet clean $(SOLUTION) -c $(CONFIG)

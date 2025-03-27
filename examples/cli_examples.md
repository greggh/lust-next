# Command Line Interface Examples

This document provides practical examples of using Firmo's command-line interface for running tests and managing test execution.

## Basic Test Execution

### Running All Tests

The simplest way to run all tests in your project:

```bash
# Run all tests in the tests directory
lua test.lua tests/
```

### Running Specific Test Files

```bash
# Run a specific test file
lua test.lua tests/unit/string_utils_test.lua

# Run multiple specific test files
lua test.lua tests/unit/string_utils_test.lua tests/unit/array_utils_test.lua
```

### Running Tests in a Specific Directory

```bash
# Run all tests in a specific directory
lua test.lua tests/unit/

# Run tests in multiple directories
lua test.lua tests/unit/ tests/integration/
```

## Filtering Tests

### Tag-Based Filtering

```bash
# Run only unit tests
lua test.lua --tags unit tests/

# Run tests that are both unit AND fast
lua test.lua --tags unit,fast tests/

# Run tests that are either unit OR integration
lua test.lua --tags unit+integration tests/

# Run unit tests that are NOT slow
lua test.lua --tags unit,-slow tests/
```

### Name-Based Filtering

```bash
# Run tests with "validation" in their name
lua test.lua --filter validation tests/

# Run tests that start with "should"
lua test.lua --filter "^should" tests/

# Run tests that end with "correctly"
lua test.lua --filter "correctly$" tests/

# Run tests with more complex pattern
lua test.lua --filter "validate%s+%w+%s+input" tests/
```

### Combined Filtering

```bash
# Run unit tests with "validation" in their name
lua test.lua --tags unit --filter validation tests/

# Run fast tests that start with "should"
lua test.lua --tags fast --filter "^should" tests/
```

## Output Formatting

### Format Options

```bash
# Use detailed output (default)
lua test.lua --format detailed tests/

# Use compact output
lua test.lua --format compact tests/

# Use dot notation
lua test.lua --format dot tests/

# Show only summary
lua test.lua --format summary tests/

# Use plain text (no colors)
lua test.lua --format plain tests/
```

### Custom Indentation

```bash
# Use 2 spaces for indentation
lua test.lua --indent 2 tests/

# Use 4 spaces for indentation
lua test.lua --indent 4 tests/

# Use tabs for indentation
lua test.lua --indent tabs tests/
```

### Color Control

```bash
# Disable colored output
lua test.lua --no-color tests/

# Enable colored output (default)
lua test.lua --color tests/
```

## Watch Mode

### Basic Watch Mode

```bash
# Run all tests in watch mode
lua test.lua --watch tests/

# Run specific test file in watch mode
lua test.lua --watch tests/unit/calculator_test.lua
```

### Filtered Watch Mode

```bash
# Run unit tests in watch mode
lua test.lua --watch --tags unit tests/

# Run tests with "validation" in their name in watch mode
lua test.lua --watch --filter validation tests/

# Run unit tests with "validation" in their name in watch mode
lua test.lua --watch --tags unit --filter validation tests/
```

### Watch Mode with Output Format

```bash
# Run tests in watch mode with compact output
lua test.lua --watch --format compact tests/

# Run tests in watch mode with dot notation
lua test.lua --watch --format dot tests/
```

## Interactive Mode

### Starting Interactive Mode

```bash
# Start interactive mode
lua test.lua --interactive

# Start interactive mode with specific directory
lua test.lua --interactive tests/unit/
```

### Example Interactive Session Commands

Once in interactive mode, you can use these commands:

```
> help
    Shows available commands

> list
    Lists all available test files

> run
    Runs all tests with current filters

> run tests/unit/calculator_test.lua
    Runs a specific test file

> tags unit
    Sets tag filter to "unit"

> tags unit,fast
    Sets tag filter to tests tagged as both "unit" and "fast"

> tags unit+integration
    Sets tag filter to tests tagged as either "unit" or "integration"

> filter validation
    Sets name filter to tests with "validation" in their name

> format compact
    Sets output format to compact

> watch on
    Enables watch mode

> watch off
    Disables watch mode

> clear
    Clears the screen

> status
    Shows current settings

> exit
    Exits interactive mode
```

## Coverage Tracking

### Basic Coverage Tracking

```bash
# Run tests with coverage tracking
lua test.lua --coverage tests/
```

### Coverage with Report Format

```bash
# Generate HTML coverage report
lua test.lua --coverage --format html tests/

# Generate JSON coverage report
lua test.lua --coverage --format json tests/

# Generate LCOV coverage report
lua test.lua --coverage --format lcov tests/
```

### Coverage with Output File

```bash
# Generate coverage report with custom output file
lua test.lua --coverage --format html --output-file my-coverage-report.html tests/
```

## Quality Validation

### Basic Quality Validation

```bash
# Run tests with quality validation
lua test.lua --quality tests/
```

### Quality Level Setting

```bash
# Run tests with basic quality validation
lua test.lua --quality --quality-level 1 tests/

# Run tests with standard quality validation
lua test.lua --quality --quality-level 2 tests/

# Run tests with strict quality validation
lua test.lua --quality --quality-level 3 tests/
```

## Combined Examples

### Complete Test Suite Execution

```bash
# Run all tests with coverage and HTML report
lua test.lua --coverage --format html tests/

# Run all unit tests with quality validation
lua test.lua --tags unit --quality tests/
```

### CI Pipeline Examples

```bash
# CI job for unit tests
lua test.lua --tags unit --no-color --format plain tests/

# CI job for integration tests
lua test.lua --tags integration --no-color --format plain tests/

# CI job for coverage report
lua test.lua --coverage --format lcov --no-color tests/
```

## Shell Scripts for Common Tasks

### Basic Test Runner

```bash
#!/bin/bash
# run_tests.sh

# Run all unit tests
lua test.lua --tags unit tests/
```

### Environment-Based Runner

```bash
#!/bin/bash
# run_tests.sh

# Get test type from environment variable or default to "unit"
TEST_TYPE=${TEST_TYPE:-unit}

# Run tests with appropriate tags
lua test.lua --tags $TEST_TYPE tests/
```

### Comprehensive Test Runner

```bash
#!/bin/bash
# run_tests.sh

# Process options
COVERAGE=""
FORMAT="detailed"
TAGS=""
FILTER=""
TEST_DIR="tests/"

while [[ $# -gt 0 ]]; do
  case $1 in
    --coverage|-c)
      COVERAGE="--coverage"
      shift
      ;;
    --format|-f)
      FORMAT="$2"
      shift 2
      ;;
    --tags|-t)
      TAGS="--tags $2"
      shift 2
      ;;
    --filter|-F)
      FILTER="--filter $2"
      shift 2
      ;;
    --dir|-d)
      TEST_DIR="$2"
      shift 2
      ;;
    *)
      # Assume it's a test path
      TEST_DIR="$1"
      shift
      ;;
  esac
done

# Build command
CMD="lua test.lua $COVERAGE --format $FORMAT $TAGS $FILTER $TEST_DIR"

# Display and execute command
echo "Running: $CMD"
eval $CMD
```

Usage:
```bash
./run_tests.sh --coverage --format html --tags unit
```

## Conclusion

These examples demonstrate the flexibility and power of Firmo's command-line interface. By combining different options, you can create efficient testing workflows that suit your specific needs, from rapid development to continuous integration and quality assurance.

Key points to remember:

1. Use `--tags` and `--filter` to run specific subsets of tests
2. Use `--format` to control how test results are displayed
3. Use `--watch` for automatic test reruns during development
4. Use `--interactive` for more complex testing workflows
5. Use `--coverage` to track and report code coverage
6. Use `--quality` to validate test quality and best practices

By leveraging these capabilities, you can create a testing workflow that provides fast feedback during development, comprehensive verification before releases, and clear reporting for project stakeholders.
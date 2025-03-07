
# Project: lust-next

## Overview

lust-next is an enhanced Lua testing framework that provides comprehensive testing capabilities for Lua projects. It features BDD-style nested test blocks, assertions with detailed error messages, setup/teardown hooks, advanced mocking, tagging, asynchronous testing, code coverage analysis, and test quality validation.

## Essential Commands

- Run Tests: `env -C /home/gregg/Projects/lust-next lua scripts/run_tests.lua`
- Run Specific Test: `env -C /home/gregg/Projects/lust-next lua scripts/run_tests.lua tests/reporting_test.lua`
- Run Example: `env -C /home/gregg/Projects/lust-next lua examples/report_example.lua`
- Debug Report Generation: `env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --coverage -cf html tests/coverage_tests/coverage_formats_test.lua`
- Test Quality Validation: `env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --quality --quality-level 2 tests/coverage_tests/coverage_quality_integration_test.lua`

## Project Structure

- `/src`: Core modules (coverage.lua, quality.lua, reporting.lua)
- `/tests`: Test files for framework functionality
- `/examples`: Example scripts demonstrating usage
- `/scripts`: Utility scripts for running tests
- `lust-next.lua`: Main framework file
- `lust.lua`: Compatibility layer for original lust

## Current Focus

- Enhancing the modular reporting architecture
- Creating robust test cases for edge cases
- Adding additional output formats
- Improving HTML reports with source highlighting
- Adding configuration for report file naming

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/lust-next-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/lust-next-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`

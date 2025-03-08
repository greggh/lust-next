
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

- `/src`: Core modules (coverage.lua, quality.lua, codefix.lua, reporting.lua)
- `/tests`: Test files for framework functionality
- `/examples`: Example scripts demonstrating usage
- `/scripts`: Utility scripts for running tests
- `lust-next.lua`: Main framework file
- `lust.lua`: Compatibility layer for original lust

## Current Focus - Code Quality Module (Codefix)

Our new top priority was creating a comprehensive Lua code quality module that goes beyond what's possible with existing tools:

- Create codefix.lua module: ✅
  - [x] Core code quality analysis capabilities
  - [x] Integration with StyLua for formatting
  - [x] Integration with Luacheck for linting
  - [x] Custom fixers for issues neither tool handles well
  - [x] API for shell script integration
  - [x] Comprehensive configuration system

- Custom fixers for common issues: ✅
  - [x] Trailing whitespace in multiline strings
  - [x] Proper unused variable handling
  - [x] Type annotation generation
  - [x] String concatenation optimization
  - [x] Lua version compatibility handling
  - [x] Neovim-specific module configuration
  
- Command-line interface: ✅
  - [x] List issues without fixing
  - [x] Fix specific issues
  - [x] Fix all issues
  - [x] Generate reports
  - [x] Integration with hooks-util

See the [Code Quality Plan](/home/gregg/Projects/lua-library/hooks-util/docs/CODE_QUALITY_PLAN.md) for full details.

## Current Focus

We've now fixed the expect assertion system and implemented watch mode for continuous testing:

- Fixed expect assertion system: ✅
  - [x] Fixed issues with expect assertion chains
  - [x] Added proper test coverage for all assertion types
  - [x] Corrected path definitions for assertion methods
  - [x] Ensured reset() function preserves assertion paths
  - [x] Added comprehensive test suite for expect assertions

- Watch mode for continuous testing: ✅
  - [x] Automatic file change detection
  - [x] Continuous test execution
  - [x] Configurable directories to watch
  - [x] Exclusion patterns for ignoring files
  - [x] Debounce mechanism to prevent multiple runs on rapid changes

## Future Focus

- Implementing remaining features from the comprehensive testing plan:
  - Interactive mode for CLI (highest priority)
  - Multiple output format support
  - Advanced mock sequences
  - Full JUnit XML reporting
- Add configuration for report file naming
- Performance optimization for large projects

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/lust-next-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/lust-next-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`

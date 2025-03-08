
# Project: lust-next

## Overview

lust-next is an enhanced Lua testing framework that provides comprehensive testing capabilities for Lua projects. It features BDD-style nested test blocks, assertions with detailed error messages, setup/teardown hooks, advanced mocking, tagging, asynchronous testing, code coverage analysis, and test quality validation.

## Essential Commands

- Run Tests: `env -C /home/gregg/Projects/lua-library/lust-next lua run_all_tests.lua`
- Run Specific Test: `env -C /home/gregg/Projects/lua-library/lust-next lua scripts/run_tests.lua tests/reporting_test.lua`
- Run Example: `env -C /home/gregg/Projects/lua-library/lust-next lua examples/report_example.lua`
- Debug Report Generation: `env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --coverage -cf html tests/coverage_tests/coverage_formats_test.lua`
- Test Quality Validation: `env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --quality --quality-level 2 tests/coverage_tests/coverage_quality_integration_test.lua`

## Project Structure

- `/lib`: Modular codebase with logical subdirectories
  - `/lib/core`: Core utilities (type checking, fix_expect, version)
  - `/lib/async`: Asynchronous testing functionality 
  - `/lib/coverage`: Code coverage tracking
  - `/lib/quality`: Quality validation
  - `/lib/reporting`: Test reporting system
    - `/lib/reporting/formatters`: Individual formatter implementations
  - `/lib/tools`: Utilities (codefix, watcher, interactive CLI)
  - `/lib/mocking`: Mocking system (spy, stub, mock)
- `/tests`: Test files for framework functionality
- `/examples`: Example scripts demonstrating usage
- `/scripts`: Utility scripts for running tests
- `lust-next.lua`: Main framework file
- `lust.lua`: Compatibility layer for original lust
- `run_all_tests.lua`: Improved test runner for proper test state isolation

## Current Focus - Architecture Modernization and Performance Optimization

With the successful reorganization of the codebase into a modular architecture and all major planned features now implemented, including modular mocking, enhanced type checking, async testing with parallel operations, multiple output formats (JUnit XML, TAP, and CSV), and a comprehensive formatter registry system, our focus is shifting to performance optimization for large projects and test suite isolation:

- Mocking System Implementation: ✅
  - [x] Create modular structure in lib/mocking directory
  - [x] Implement spy functionality for function tracking
  - [x] Enhance mock expectation and verification system
  - [x] Add stub configuration methods with returns() and throws()
  - [x] Improve with_mocks context manager with error handling
  - [x] Implement all previously pending tests

- expose_globals() Implementation: ✅
  - [x] Restore global test function exposure functionality
  - [x] Add lust.assert namespace for direct assertions
  - [x] Implement compatibility aliases (before_each, after_each)
  - [x] Add specialized assertion helpers for tests

- Core Functionality Enhancement: ✅
  - [x] Implement type checking module for tests/type_checking_test.lua
  - [x] Add advanced type verification with is_exact_type, is_instance_of
  - [x] Implement async functionality for tests/async_test.lua
  - [x] Create interactive CLI mode implementation
  - [x] Fix codefix module multi-file functionality with cross-platform support
  - [x] Add JUnit XML output format for CI/CD integration

- Advanced Features Implementation: ✅
  - [x] Implement advanced mock sequences with sequential return values
    - [x] Basic sequence functionality with returns_in_sequence
    - [x] Enhanced implementation with exhaustion behavior options
    - [x] Added robust cycling implementation with manual approach
    - [x] Added sequence reset functionality
  - [x] Enhanced reporting system
    - [x] Standardized data structures for reporting modules
    - [x] JUnit XML output format for CI/CD integration
    - [x] TAP (Test Anything Protocol) output format
    - [x] CSV output format for data analysis
    - [x] Improved HTML coverage reports with syntax highlighting
    - [x] Robust error handling and cross-platform directory creation
    - [x] Structured test summaries with detailed statistics
  - [x] Add `parallel_async` for running multiple async operations concurrently
    - [x] Implemented round-robin scheduling for simulated concurrency
    - [x] Added robust error handling with operation identification
    - [x] Implemented timeout detection for long-running operations
    - [x] Fixed timeout testing with reliable detection
    - [x] Created comprehensive example demonstrating real-world usage

All tests now pass (either successfully or marked as pending), giving us a clear roadmap for implementing the missing functionality while maintaining a stable test suite. Try the interactive CLI example at `examples/interactive_mode_example.lua`.

See the [Code Quality Plan](/home/gregg/Projects/lua-library/hooks-util/docs/CODE_QUALITY_PLAN.md) for full details.

## Working Environment Setup

We've implemented the interactive CLI mode for lust-next:

- Interactive CLI mode for running tests: ✅
  - [x] Full-featured interactive command-line interface
  - [x] Live configuration of test options (tags, filters, focus)
  - [x] Command history and navigation
  - [x] Dynamic test discovery and execution
  - [x] Status display showing current configuration
  - [x] Toggle watch mode from within the interface
  - [x] Integration with codefix module for code quality checks
  - [x] Comprehensive help system with command reference
  - [x] Clear, colorized output for better readability
  - [x] Example script demonstrating interactive mode usage

We've previously completed these major features:

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
  - [x] Integration with interactive CLI mode

## Future Focus

- Implementing remaining features from the comprehensive testing plan:
  - ✅ TAP output format support for broader testing ecosystem integration
  - ✅ CSV output format for spreadsheet and data analysis integration
  - ✅ Command-line configuration for report file naming and paths
  - ✅ Runtime configuration options for custom test output formats
- Performance optimization for large projects:
  - Improved test suite isolation mechanisms
  - Faster module reset functionality
  - Memory usage optimizations for large test suites
  - Optimized parallel execution for better resource utilization

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/lust-next-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/lust-next-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`

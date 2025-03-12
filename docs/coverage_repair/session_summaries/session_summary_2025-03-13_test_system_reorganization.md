# Session Summary: Test System Reorganization Plan (2025-03-13)

## Overview

In today's session, we focused on cleaning up temporary test files and developing a comprehensive plan to reorganize the test system in the lust-next project. We identified several issues with the current testing approach, including multiple test runners, inconsistent usage patterns, and a cluttered project root directory.

## Accomplishments

1. **Cleanup of Temporary Test Files**:
   - Removed unnecessary test files from the project root:
     - test-instrumentation.lua
     - test_instrumentation2.lua
     - debug-instrumentation.lua
     - fix_syntax.lua
     - fix_join_paths.lua
     - debug-tracking.lua
     - run-test2.lua
   - Removed temporary directories like test_modules

2. **Developed Test System Reorganization Plan**:
   - Created detailed plan document (test_system_reorganization_plan.md)
   - Identified core principles for the new approach:
     - Framework independence
     - Self-testing
     - Clean separation of concerns
   - Designed a clear implementation plan with 5 phases

3. **Updated Documentation**:
   - Updated phase4_progress.md to include the test system reorganization task
   - Added new section to test_plan.md describing the reorganization initiative
   - Updated testing_guide.md to reference the new standardized approach
   - Updated CLAUDE.md to reflect the transition to the enhanced runner.lua
   - Ensured all references to running tests are consistent across documentation

## Test System Reorganization Plan

The key elements of our test system reorganization plan are:

1. **Enhanced Universal Test Runner**:
   - Improve scripts/runner.lua to handle both file and directory inputs
   - Add support for pattern-based test filtering
   - Standardize command-line arguments across all testing scenarios

2. **Clean Test Organization**:
   - Move special test logic into standard test files
   - Use the proper describe/it pattern consistently
   - Configure coverage and instrumentation within test files using before/after hooks

3. **Standardized Interface**:
   - Create a simple, standard command interface for running tests
   - Eliminate special-purpose test runners
   - Ensure all tests follow the same patterns and practices

4. **Framework Independence**:
   - Make the test running system generic and usable by any project
   - Remove special-case handling for lust-next's internal features

## Implementation Strategy

The implementation will follow a phased approach:

1. **Phase 1**: Enhance scripts/runner.lua with universal capabilities
2. **Phase 2**: Reorganize test content into standard test files
3. **Phase 3**: Standardize runner commands and interfaces
4. **Phase 4**: Clean up redundant runners and special-purpose files
5. **Phase 5**: Verify the unified approach across all test scenarios

This work will be completed after the current module require instrumentation task and before moving on to the error handling implementation.

## Next Steps

1. Complete the current module require instrumentation work
2. Begin implementing the test system reorganization plan:
   - Enhance scripts/runner.lua to support all required functionality
   - Move test logic from special-purpose files into standard test files
   - Create a universal test.lua interface in the project root

3. After the test reorganization, proceed with the error handling implementation

This reorganization will significantly improve the maintainability, clarity, and consistency of the lust-next test system.
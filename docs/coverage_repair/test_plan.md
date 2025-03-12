# Comprehensive Test Plan

This document outlines the test plan for each component of the coverage module, ensuring thorough validation of all functionality.

## Purpose

The purpose of this document is to define a comprehensive test strategy for the coverage module, including unit tests, integration tests, and end-to-end tests. This ensures that each component works correctly in isolation and within the larger system.

## Test Categories

1. **Unit Tests**: Tests for individual components in isolation
2. **Integration Tests**: Tests for component interactions
3. **End-to-End Tests**: Tests for complete workflow scenarios
4. **Performance Tests**: Tests for system performance under various conditions
5. **Edge Case Tests**: Tests for unusual or boundary conditions

## Overall Testing Improvement Plan

As part of our ongoing efforts to enhance the quality and reliability of the coverage module, we've identified the need for a comprehensive testing improvement initiative. This plan includes:

1. **Test Framework Standardization** (Significant Progress 2025-03-11):
   - ✅ Fixed incorrect assertion functions in error_handler.lua
   - ✅ Added is_type_or_nil assertion to lust-next.lua
   - ✅ Created temporary validation functions in module_reset.lua to break circular dependencies
   - ✅ Created plan for extracting assertions to a standalone module
   - Ensuring all tests follow consistent patterns and practices
   - Correcting test framework usage, particularly around lifecycle hooks
   - Removing incorrect patterns like explicit test execution calls
   - Creating a comprehensive test framework guide

2. **Test Completeness Review**:
   - Inventory all existing tests and identify gaps
   - Add missing tests for critical functionality
   - Update outdated tests to reflect current implementation

3. **Test Documentation Enhancement**:
   - Update all testing documentation to reflect correct patterns
   - Provide clear examples of proper test implementation
   - Ensure consistency across all documentation

A detailed implementation plan is available in the [Test Update Plan](./test_update_plan.md) document.

## Test System Reorganization Plan (Added 2025-03-13)

As part of our ongoing effort to improve test quality and organization, we have developed a comprehensive test system reorganization plan. The current test running system has several issues:

1. **Multiple Test Runners**:
   - `run_all_tests.lua` in project root
   - `run-instrumentation-tests.lua` in project root
   - `run-single-test.lua` in project root
   - `scripts/runner.lua` (underutilized)
   - `runner.sh` shell script

2. **Inconsistent Test Patterns**:
   - Different ways of running tests
   - Special-purpose test files in the root directory
   - Configuration spread across different files

Our solution follows these core principles:

1. **Framework Independence**: The framework and its runners should be generic and usable by any project.
2. **Self-Testing**: We should test lust-next using lust-next itself without special cases.
3. **Clean Separation**: Clear separation between framework code, utilities, tests, and examples.

The full implementation plan can be found in [Test System Reorganization Plan](./test_system_reorganization_plan.md).

### Key Changes

1. **Universal Test Runner**: Enhance `scripts/runner.lua` to be a framework-agnostic test runner.
2. **Standard Test Structure**: Move all test logic into proper test files with describe/it blocks.
3. **Configuration in Tests**: Tests that need special setup should do it in before/after hooks.
4. **Clean Project Root**: Remove all special-purpose runners from the project root.

### Implementation Timeline

The test system reorganization will be implemented after the current module require instrumentation work and before moving on to the error handling implementation.

## Upcoming Test Plans

### Instrumentation Module Tests

As part of Phase 4 of the coverage module repair, the following tests will be developed for the instrumentation approach:

1. **Unit Tests**:
   - ✅ Test instrumentation.set_config and instrumentation.get_config functionality
   - ✅ Test instrumentation.instrument_file with various code patterns
   - ✅ Test sourcemap generation and error translation
   - ✅ Test caching system for instrumented files
   - ✅ Test integration with static analyzer
   - ✅ Test file hooking mechanism (loadfile, dofile, load)

2. **Integration Tests**:
   - ✅ Test interaction with the main coverage module
   - ✅ Test seamless switching between debug hook and instrumentation approaches
   - ✅ Compare coverage results between both approaches
   - ⚠️ Test instrumentation of modules loaded with require (partial implementation with known issues)
   - ✅ Test error handling and reporting

3. **Module Require Instrumentation Tests** (Added 2025-03-12):
   - ✅ Created run-instrumentation-tests.lua with tests for basic functionality:
     - ✅ Test 1: Basic line instrumentation
     - ✅ Test 2: Conditional branch instrumentation
     - ✅ Test 3: Table constructor instrumentation
     - ⚠️ Test 4: Module require instrumentation (using manual verification)
   - ✅ Created dedicated test file instrumentation_module_test.lua
   - ✅ Documented requirements for proper fix in instrumentation_module_require_fix_plan.md
   - ⬜ Implement proper engineering solution for module require recursion
   - ⬜ Test with complex module dependencies
   - ⬜ Test with circular dependencies

3. **Performance Tests**:
   - Benchmark instrumentation overhead for various file sizes
   - Compare performance between debug hook and instrumentation approaches
   - Measure memory usage differences
   - Test caching performance improvements

4. **Edge Case Tests**:
   - Test with complex syntax patterns (nested functions, closures)
   - Test with multiline comments and strings
   - Test with Unicode characters
   - Test with very large files
   - Test with syntax errors and partially valid files

### Centralized Configuration System Tests

As part of Phase 4 of the centralized configuration system integration, the following tests will be developed:

1. **Unit Tests**:
   - Test all central_config functions (get, set, delete, on_change, etc.)
   - Test schema validation for various schema types
   - Test change notification system with multiple listeners
   - Test configuration loading and saving

2. **Integration Tests**:
   - Test integration with various modules
   - Test bridge pattern in the legacy config.lua
   - Test backward compatibility with existing code
   - Verify correct schema validation across modules

3. **Edge Case Tests**:
   - Test with missing or invalid configuration
   - Test with complex nested configurations
   - Test change notification with deep changes
   - Test error handling for various error conditions

### Error Handling System Tests (Updated 2025-04-11)

As part of the comprehensive error handling implementation, the following tests will be developed:

1. **Unit Tests**:
   - Test all error_handler functions (create, throw, assert, try, etc.)
   - Test error categorization and severity levels
   - Test error context and propagation
   - Test error formatting and logging integration
   - Test compatibility functions (table.unpack/unpack)

2. **Integration Tests**:
   - Test integration with the coverage module
   - Test error propagation through the call stack
   - Test recovery mechanisms for different error types
   - Verify error handling in all primary components:
     - coverage/init.lua
     - debug_hook.lua
     - file_manager.lua
     - static_analyzer.lua
     - patchup.lua
     - instrumentation.lua

3. **Edge Case Tests**:
   - Test with missing or invalid inputs
   - Test with nested errors (errors during error handling)
   - Test error handling during initialization
   - Test error recovery in critical operations

4. **Implementation Fixes (CRITICAL)** (Substantial progress 2025-03-11):
   - ✅ Remove all fallback code assuming error_handler might not be available (38 instances)
   - ✅ Remove inappropriate assertion functions from error_handler.lua
   - ✅ Enhanced safe_io_operation to properly handle non-error negative results
   - ✅ Fixed inappropriate ERROR logging for missing optional configuration files
   - ✅ Implemented proper semantics for distinguishing errors from normal conditions
   - Fix skipped tests in coverage_error_handling_test.lua
   - Ensure tests are run with runner.lua for proper environment setup
   - Fix global reference issues in tests
   - Implement consistent error handling patterns throughout

### Filesystem Module Error Handling Tests (Added 2025-03-11)

To validate the enhanced error handling in the filesystem module, the following tests will be developed:

1. **Unit Tests**:
   - Test parameter validation for all public functions (read_file, write_file, etc.)
   - Test error generation with proper categorization (IO, VALIDATION)
   - Test error context and information accuracy
   - Test error propagation through nested operations (e.g., copy_file using read_file and write_file)
   - Test proper error chaining with original causes preserved

2. **Error Scenario Tests**:
   - Test with missing files
   - Test with insufficient permissions
   - Test with invalid paths
   - Test with invalid content types
   - Test with read-only destination paths
   - Test with full disks (using mock filesystem)
   - Test with I/O operation timeouts

3. **Recovery Tests**:
   - Test fallback mechanisms (e.g., move_file fallback from rename to copy+delete)
   - Test partial success handling (e.g., copy succeeded but delete failed)
   - Test proper resource cleanup in error scenarios
   - Test error handling during directory operations

These tests will ensure that the filesystem module's error handling is robust, informative, and follows all project-wide error handling standards.

This test plan will be expanded further as the implementation progresses.

## Documentation Status

This document is being updated as new components are implemented and integrated into the system.
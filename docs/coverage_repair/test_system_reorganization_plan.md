# Test System Reorganization Plan

## Core Principles

1. **Framework Independence**: The framework and its runners should be generic and usable by any project.

2. **Self-Testing**: We should test lust-next using lust-next itself without special cases.

3. **Clean Separation**: 
   - `lib/`: The framework core
   - `scripts/`: Utilities for using the framework (like runner.lua)
   - `tests/`: Tests for the framework itself
   - `examples/`: Example usage for users

## Current Issues

1. **Multiple Test Runners**:
   - `run_all_tests.lua` in project root
   - `run-instrumentation-tests.lua` in project root
   - `run-single-test.lua` in project root
   - `scripts/runner.lua` (underutilized)
   - `runner.sh` shell script

2. **Inconsistent Usage**:
   - Different command-line arguments
   - Inconsistent patterns for running tests
   - Bypassing the proper runner infrastructure

3. **Improper Location**:
   - Test runners should not clutter the project root
   - Special-purpose test files should be in the test directory

## Implementation Plan

### Phase 1: Enhance Generic Runner (✅ COMPLETED)

1. **Improve `scripts/runner.lua` as a Universal Tool** ✅:
   - Added support for running a single test file
   - Added support for running all tests in a directory (recursively)
   - Added support for running tests matching a pattern
   - Added comprehensive command-line argument handling
   - Added help and usage information with examples
   - Integrated coverage, quality, and module reset functionality
   - Added proper error handling and exit codes

2. **Create Central CLI in Project Root** ✅:
   ```lua
   -- test.lua (in project root)
   -- Simple redirector to scripts/runner.lua that any project could use
   
   -- Forward all arguments to the proper runner
   local args = table.concat({...}, " ")
   local cmd = "lua scripts/runner.lua " .. args
   local success = os.execute(cmd)
   
   -- Exit with the same status code
   os.exit(success and 0 or 1)
   ```

### Phase 2: Properly Organize Test Content

1. **Move Special Test Logic Into Standard Test Files**:
   - Move instrumentation tests to `tests/coverage/instrumentation_test.lua`
   - Organize tests into logical directories: `tests/coverage/`, `tests/reporting/`, etc.
   - Ensure all test files use the standard describe/it pattern

2. **Move Configuration Into Test Files**:
   - Tests that need coverage should configure it in `before` hooks
   - Tests that need instrumentation should enable it in `before` hooks
   - Example:
   ```lua
   before(function()
     coverage.init({
       use_instrumentation = true,
       -- other configuration...
     })
     coverage.start()
   end)
   ```

3. **Create Comprehensive Test Suite File**:
   - Create `tests/all_tests.lua` that loads all test files
   - Use proper lust-next `describe`/`it` blocks
   - No special execution logic - just standard test patterns

### Phase 3: Standardize Runner Commands

1. **Create Universal Command Interface**:
   - `lua test.lua [path]` runs tests in path
   - `lua test.lua tests/` runs all framework tests
   - `lua test.lua --pattern=coverage tests/` runs coverage-related tests

2. **Update `scripts/runner.lua` for Directory Support**:
   - Add directory scanning that's framework-agnostic
   - Support for nested test directories
   - Consistent handling of test output and results

### Phase 4: Thorough Cleanup

1. **Remove All Special-Purpose Runners**:
   - `run_all_tests.lua` (replaced by standard runner)
   - `run-instrumentation-tests.lua` (logic moved to test files)
   - `run-single-test.lua` (redundant)
   - `test_discover_files.lua` (temporary file)
   - Any shell scripts that duplicate functionality

2. **Update Documentation**:
   - Update CLAUDE.md with clean testing approach
   - Create proper examples of how to run tests
   - Document the standard patterns for test files

3. **Create Examples of Framework Testing**:
   - Add an example showing how to test a project with lust-next
   - Show proper configuration in examples

### Phase 5: Verification

1. **Test the Unified Approach**:
   - Run all tests with the new runner
   - Verify all tests pass with identical results
   - Check coverage functionality still works

2. **Ensure Clear User Experience**:
   - Verify documentation makes sense
   - Ensure examples work correctly

## Expected Benefits

1. **Framework Independence**: The runner doesn't know or care about lust-next internals.

2. **Clean Separation**: Each component has a clear purpose without special cases.

3. **Self-Testing**: We test lust-next with lust-next using standard patterns.

4. **Consistency**: One way to run tests that works for all test scenarios.

## Implementation Timeline and Priority

1. **Phase 1 (Enhance runner.lua)**: 2-3 hours
2. **Phase 2 (Organize test content)**: 3-4 hours
3. **Phase 3 (Standardize commands)**: 1-2 hours
4. **Phase 4 (Cleanup)**: 1 hour
5. **Phase 5 (Verification)**: 2-3 hours

Total estimated time: 9-13 hours

This test system reorganization should be implemented after completing the current module require instrumentation work and before moving on to the error handling implementation.
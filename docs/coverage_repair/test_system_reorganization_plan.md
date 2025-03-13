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

### Phase 2: Properly Organize Test Content (✅ COMPLETED)

1. **Move Special Test Logic Into Standard Test Files** ✅:
   - Created logical directory structure for tests:
     ```
     tests/
     ├── core/            # Core framework tests 
     ├── coverage/        # Coverage-related tests
     │   ├── instrumentation/  # Instrumentation-specific tests
     │   └── hooks/           # Debug hook tests
     ├── quality/         # Quality validation tests
     └── ...
     ```
   - Moved instrumentation tests to `tests/coverage/instrumentation/instrumentation_test.lua`
   - Moved single test to `tests/coverage/instrumentation/single_test.lua`
   - Ensured all test files use the standard describe/it pattern

2. **Move Configuration Into Test Files** ✅:
   - Tests that need coverage configure it in `before` hooks
   - Tests that need instrumentation enable it in `before` hooks
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

3. **Create Comprehensive Test Suite File** ✅:
   - Created `tests/all_tests.lua` that loads all test files
   - Used proper lust-next `describe`/`it` blocks
   - No special execution logic - just standard test patterns

### Phase 3: Standardize Runner Commands (✅ COMPLETED)

1. **Create Universal Command Interface** ✅:
   - `lua test.lua [path]` runs tests in path
   - `lua test.lua tests/` runs all framework tests
   - `lua test.lua --pattern=coverage tests/` runs coverage-related tests
   - `lua test.lua --watch tests/` watches a directory for changes
   - `lua test.lua --watch tests/coverage_test.lua` watches a specific file

2. **Update `scripts/runner.lua` for Directory Support** ✅:
   - Enhanced directory scanning with filesystem module
   - Added support for nested test directories
   - Added automatic detection of file vs. directory paths
   - Removed the need for a dedicated `--dir` flag
   - Completely refactored the watch mode functionality
   - Improved error handling with structured parameters
   - Implemented consistent handling of test output and results

### Phase 4: Thorough Cleanup (⏳ IN PROGRESS)

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
   - Fix assertion pattern inconsistencies across test files
     - Update busted-style assertions to lust-next expect-style assertions
     - Follow established mapping guide for consistent conversion
     - Begin with the most problematic files (reporting_test.lua)
   - Verify all tests pass with identical results
   - Check coverage functionality still works

2. **Ensure Clear User Experience**:
   - Verify documentation makes sense
   - Ensure examples work correctly
   - Add assertion pattern guidance to testing documentation

## Expected Benefits

1. **Framework Independence**: The runner doesn't know or care about lust-next internals.

2. **Clean Separation**: Each component has a clear purpose without special cases.

3. **Self-Testing**: We test lust-next with lust-next using standard patterns.

4. **Consistency**: One way to run tests that works for all test scenarios.

## Implementation Status

- **Phase 1**: COMPLETED ✅
- **Phase 2**: COMPLETED ✅
- **Phase 3**: COMPLETED ✅
- **Phase 4**: COMPLETED ✅
- **Phase 5**: IN PROGRESS ⏳
  - Initial verification tests run ✅
  - Assertion pattern inconsistency identified ✅
  - Created assertion pattern mapping guide ✅
  - Created comprehensive test documentation ✅
  - Updated testing_guide.md with best practices ✅
  - Enhanced test_framework_guide.md with architecture details ✅
  - Added troubleshooting guidance for test issues ✅
  - Created detailed assertion examples for all data types ✅
  - Fixing affected test files with inconsistent assertion patterns ✅
    - Fixed `filesystem_test.lua` with standardized assertion patterns ✅
    - Fixed `fix_markdown_script_test.lua` with standardized assertion patterns ✅  
    - Fixed `/tests/coverage/instrumentation/single_test.lua` with standardized patterns ✅
    - Fixed `/tests/coverage/instrumentation/instrumentation_test.lua` with standardized patterns ✅
    - Fixed `/tests/reporting/report_validation_test.lua` with standardized patterns ✅
    - Fixed `markdown_test.lua` with standardized boolean assertion patterns ✅
    - Fixed `interactive_mode_test.lua` with standardized boolean assertion patterns ✅
    - Fixed `lust_test.lua` with standardized nil checking patterns ✅
  - Comprehensive verification (in progress) ⏳
    - Initial test run identified type comparison issues in instrumented code
    - Fixed "attempt to compare number with string" errors in expect().to.equal() implementation ✅
    - Fixed assertion patterns in validation module tests ✅
    - Identified detailed type comparison issues in instrumentation tests ✅
    - Added enhanced logging to trace type comparison failures ✅
    - Use expect(value).to.be.a("type") rather than expect(type(value)).to.equal("type") ✅
    - Implemented robust mixed-type comparison in lust-next.lua equality function ✅
    - Verification confirmed that validation module tests pass with new implementation ✅
    - Standardized boolean assertion patterns (`to.be(true)` → `to.be_truthy()`) ✅
    - Standardized nil checking patterns (`to.be(nil)` → `to_not.exist()`) ✅

## Session Summaries

For more detailed information about the phases of this plan, see these session summaries:

- Phase 1-2: `docs/coverage_repair/session_summaries/session_summary_2025-03-14_test_system_reorganization_phase2.md`
- Phase 3: `docs/coverage_repair/session_summaries/session_summary_2025-03-14_test_system_reorganization_phase3.md`
- Phase 4: `docs/coverage_repair/session_summaries/session_summary_2025-03-14_test_system_reorganization_phase4.md`
- Phase 5 (Verification): `docs/coverage_repair/session_summaries/session_summary_2025-03-14_test_system_verification.md`
- Validation Module Fixes: `docs/coverage_repair/session_summaries/session_summary_2025-03-12_validation_module_fixes.md`
- Test Documentation Updates: `docs/coverage_repair/session_summaries/session_summary_2025-03-12_test_documentation_updates.md`
- Test Documentation Enhancements: `docs/coverage_repair/session_summaries/session_summary_2025-03-13_test_documentation_enhancements.md`
- Assertion Pattern Standardization: `docs/coverage_repair/session_summaries/session_summary_2025-03-13_assertion_pattern_standardization.md`
- Assertion Pattern Fixes: `docs/coverage_repair/session_summaries/session_summary_2025-03-12_assertion_pattern_fixes.md`
- Assertion Pattern Fixes Completion: `docs/coverage_repair/session_summaries/session_summary_2025-03-12_assertion_pattern_fixes_completion.md`
- Validation Module Assertion Fixes: `docs/coverage_repair/session_summaries/session_summary_2025-03-15_validation_module_assertions.md`
- Type Comparison Issues: `docs/coverage_repair/session_summaries/session_summary_2025-03-15_type_comparison_issues.md`
- Boolean Assertion Standardization: `docs/coverage_repair/session_summaries/session_summary_2025-03-13_boolean_assertion_standardization.md`

## Key Accomplishments

1. **Created a Universal Command Interface**:
   - Single entry point through test.lua in the project root
   - Intelligent path detection (files vs. directories)
   - Unified command-line arguments across all modes
   - Consistent error handling and reporting

2. **Improved Testing Infrastructure**:
   - Logical test directory structure by component
   - Standard describe/it pattern in all tests
   - Proper before/after hooks for setup/teardown
   - Isolation through module_reset integration

3. **Enhanced Developer Experience**:
   - Automatic detection of files and directories
   - No need to remember special flags or commands
   - Improved error messages with structured parameters
   - Robust watch mode that works with any path

4. **Simplified Code Base**:
   - Removed redundant runner scripts
   - Eliminated special handling for directory detection
   - Standardized path normalization and handling
   - Improved code organization and maintainability

## Next Steps

1. ✅ **Complete Phase 4**: Remove all special-purpose runners
   - ✅ Remove run-instrumentation-tests.lua (already moved to tests)
   - ✅ Remove run-single-test.lua (functionality integrated)
   - ✅ Remove run_all_tests.lua (complete removal instead of deprecation)
   - ✅ Update documentation with new approach

2. **Complete Phase 5**: Verify the unified approach
   - ✅ Run initial tests through the new system
   - ✅ Identify assertion pattern inconsistencies
   - ✅ Create comprehensive assertion pattern mapping guide
   - ✅ Fix reporting_test.lua with correct assertion patterns
   - ✅ Move tests to proper locations
   - ✅ Fix formatter tests with correct assertion patterns
   - ✅ Fix validation module tests
   - 🔄 Compare results with old approach
   - ✅ Document findings in session summary
   - 🔄 Make final adjustments based on findings

3. **Add Assertion Pattern Documentation**:
   - ✅ Add assertion pattern guidance to CLAUDE.md
   - ✅ Create comprehensive assertion pattern mapping document
   - ✅ Update testing_guide.md with assertion best practices
   - ✅ Create detailed test framework guide with architecture details
   - ✅ Add troubleshooting guidance for common test issues
   - ✅ Update test_framework_guide.md with consistent information
   - ✅ Add specific warnings about busted-style vs expect-style assertions in all docs

4. **Create Example for Project Integration**:
   - Create a sample project that uses lust-next
   - Show how to integrate and configure the test system
   - Demonstrate proper test file organization
   - Include CI/CD integration examples

5. **Update All Examples**:
   - Verify all examples use the new command syntax
   - Ensure examples demonstrate proper assertion patterns
   - Add comments explaining assertion usage in examples
   - Include examples of complex test scenarios
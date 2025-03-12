# Test File Update Plan

## Overview

This document outlines the plan for reviewing and updating all test files in the lust-next project to ensure they follow consistent patterns and correctly use the testing API. Many tests were written at different times and may contain outdated patterns or incorrect usage of the testing framework.

## Current Issues Identified

1. **Inconsistent Test Execution**: Some tests incorrectly include calls to `lust()` or `lust.run()` at the end of files
2. **Non-existent Lifecycle Functions**: Some tests use `before_all` and `after_all` which don't exist in the framework
3. **Inconsistent Import Patterns**: Varying styles of importing the test framework and functions
4. **Outdated Tests**: Some tests might be testing functionality that has been removed or rewritten
5. **Potentially Incompatible Tests**: Tests written against older versions of the API might not work with current functionality

## Update Process

### Phase 1: Comprehensive Review

For each test file in the `/tests` directory, we will:

1. Check if the file imports the testing framework correctly:
   ```lua
   local lust = require("lust-next")  -- or relative path as needed
   local describe, it, expect = lust.describe, lust.it, lust.expect
   local before, after = lust.before, lust.after  -- correct lifecycle hooks
   ```

2. Check for and remove any explicit test execution calls at the end of the file:
   - Remove `lust()` or `lust.run()` calls
   - Replace with a comment explaining tests are run by the test runner

3. Fix usage of non-existent lifecycle hooks:
   - Replace `before_all` with `before`
   - Replace `after_all` with `after`

4. Check if the test is still relevant:
   - Does it test functionality that still exists?
   - Does it test in a way that's compatible with current API?

### Phase 2: Test Validation & Repairs

For each test file, after making the updates from Phase 1:

1. Run ONLY the individual test file using the runner script:
   ```
   lua scripts/runner.lua tests/your_test_file.lua
   ```

2. If the test fails, analyze whether:
   - The failure is due to a test framework issue that we just fixed
   - The failure is due to a legitimate change in functionality
   - The test is testing something that no longer exists

3. Fix the test if needed:
   - Update assertions to match current API behavior
   - Rewrite tests for significantly changed functionality
   - Mark as pending (using `lust.pending()`) tests that need more investigation

4. After fixing the test, run it again with `scripts/runner.lua` to verify

IMPORTANT: DO NOT run `run_all_tests.lua` until ALL test files have been updated. 
Running the full test suite prematurely will generate many errors from unfixed test files
and make it difficult to identify if your specific fixes are working correctly.

### Phase 3: Documentation Update

1. Update all documentation to reflect correct testing patterns:
   - Update testing_guide.md with correct information
   - Update prompt-session-start.md and prompt-session-end.md
   - Create comprehensive examples of proper testing patterns

2. Add cross-references between documents to ensure consistency

## Test Files to Review

(This is a comprehensive list of all test files to be reviewed and updated)

1. assertions_test.lua
2. async_test.lua
3. async_timeout_test.lua
4. codefix_test.lua
5. config_test.lua
6. coverage_module_test.lua
7. coverage_test_minimal.lua
8. coverage_test_simple.lua
9. discovery_test.lua
10. enhanced_reporting_test.lua
11. expect_assertions_test.lua
12. fallback_heuristic_analysis_test.lua
13. filesystem_test.lua
14. fix_markdown_script_test.lua
15. html_formatter_test.lua
16. instrumentation_test.lua
17. interactive_mode_test.lua
18. large_file_coverage_test.lua
19. large_file_test.lua
20. logging_test.lua
21. lust_test.lua
22. markdown_test.lua
23. mocking_test.lua
24. module_reset_test.lua
25. performance_test.lua
26. quality_test.lua
27. report_validation_test.lua
28. reporting_filesystem_test.lua
29. reporting_test.lua
30. tagging_test.lua
31. tap_csv_format_test.lua
32. truthy_falsey_test.lua
33. type_checking_test.lua
34. watch_mode_test.lua

## Priority and Timeline

**Phase 1 Priority Order**:
1. Core framework tests (lust_test.lua, expect_assertions_test.lua)
2. Coverage system tests (coverage_*_test.lua, instrumentation_test.lua)
3. Reporting system tests (reporting_*.lua, html_formatter_test.lua)
4. Utility tests (filesystem_test.lua, markdown_test.lua)
5. Other functional tests

**Timeline**:
- Complete Phase 1 within 1 week
- Complete Phase 2 within 2 weeks
- Complete Phase 3 within 3 weeks

## Progress Tracking

We'll track progress in this document by adding ✓ marks to completed items and noting any significant findings or issues.

## Already Addressed Tests

The following tests have already been fixed:

1. ✓ fallback_heuristic_analysis_test.lua
2. ✓ instrumentation_test.lua
3. ✓ expect_assertions_test.lua
4. ✓ lust_test.lua
5. ✓ coverage_module_test.lua (also updated to use central_config instead of deprecated config)
6. ✓ coverage_test_minimal.lua (updated to use proper imports, hooks, and central_config)
7. ✓ coverage_test_simple.lua (updated to use proper imports, hooks, and central_config)
8. ✓ reporting_test.lua (removed expose_globals(), added proper imports)
9. ✓ html_formatter_test.lua (updated to use central_config instead of deprecated config)
10. ✓ quality_test.lua (updated to use proper imports, hooks, and central_config)
11. ✓ config_test.lua (already using central_config, updated to add proper logging)
12. ✓ module_reset_test.lua (updated to use filesystem module instead of direct io.* functions)
13. ✓ parallel_test.lua (created new test file for parallel execution module)
14. ✓ fix_markdown_script_test.lua (updated to use proper imports, structured logging, and filesystem module)
15. ✓ assertions_test.lua (fixed import path and removed explicit return)
16. ✓ codefix_test.lua (updated to use filesystem module instead of direct io.* functions, improved structured logging)
17. ✓ discovery_test.lua (removed unnecessary package.path modification)
18. ✓ markdown_test.lua (verified as already following best practices)
19. ✓ async_test.lua (verified as already following best practices)
20. ✓ mocking_test.lua (verified as already following best practices)
21. ✓ tagging_test.lua (verified as already following best practices)
22. ✓ performance_test.lua (updated to use filesystem module instead of direct io.* functions, improved structured logging)
23. ✓ filesystem_test.lua (replaced print statements with structured logging)
24. ✓ truthy_falsey_test.lua (verified as already following best practices)
25. ✓ type_checking_test.lua (verified as already following best practices)
26. ✓ watch_mode_test.lua (replaced print statements with structured logging)
27. ✓ large_file_coverage_test.lua (replaced print statements with structured logging and fixed hardcoded paths)
28. ✓ enhanced_reporting_test.lua (verified as already following best practices)
29. ✓ report_validation_test.lua (verified as already following best practices)
30. ✓ reporting_filesystem_test.lua (verified as already following best practices)
31. ✓ async_timeout_test.lua (verified as already following best practices)
32. ✓ interactive_mode_test.lua (verified as already following best practices)
33. ✓ large_file_test.lua (fixed print statements and hardcoded paths)
34. ✓ tap_csv_format_test.lua (removed unnecessary package.path modification)
35. ✓ logging_test.lua (fixed all print statements and path constructions)

## Critical Fixes

In addition to the test file fixes, we've made the following critical infrastructure improvements:

1. ✓ Fixed lib/tools/logging.lua to use central_config instead of deprecated config module, resolving deprecation warnings in all tests
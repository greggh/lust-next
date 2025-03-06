# Project Information: lust-next

## Project Overview
lust-next is an enhanced Lua testing framework that provides comprehensive testing capabilities for Lua projects, including:
- BDD-style nested test blocks (describe/it)
- Assertions with detailed error messages
- Setup and teardown with before/after hooks
- Advanced mocking and spying system
- Tag-based filtering for selective test execution
- Focus mode for running only specific tests (fdescribe/fit)
- Skip mode for excluding tests (xdescribe/xit)
- Asynchronous testing support
- Code coverage analysis and reporting
- Test quality validation

## Current Focus
- Implementing a modular report generation architecture to:
  - Properly separate concerns between data collection and reporting
  - Centralize file I/O operations
  - Standardize data interfaces between modules
  - Provide consistent error handling and recovery

## Completed Tasks
- Created `src/reporting.lua` for centralized report formatting and file I/O
- Refactored `src/coverage.lua` to return structured data instead of generating reports
- Refactored `src/quality.lua` to follow the same pattern
- Updated `lust-next.lua` to use the reporting module when appropriate
- Implemented comprehensive tests in `tests/reporting_test.lua`
- Created examples in `examples/report_example.lua`
- Maintained backward compatibility for existing APIs

## Files of Interest
- `/home/gregg/Projects/lust-next/src/reporting.lua` - New reporting module
- `/home/gregg/Projects/lust-next/src/coverage.lua` - Coverage module (refactored)
- `/home/gregg/Projects/lust-next/src/quality.lua` - Quality module (refactored)
- `/home/gregg/Projects/lust-next/lust-next.lua` - Main framework file
- `/home/gregg/Projects/lust-next/tests/reporting_test.lua` - Tests for reporting module
- `/home/gregg/Projects/lust-next/examples/report_example.lua` - Example demonstrating reporting

## Next Steps
1. Update the `run_tests.lua` script in lust-next-testbed to take advantage of the new reporting capabilities
2. Create additional examples to demonstrate the new architecture
3. Add documentation for the reporting module in the docs directory
4. Extend the reporting module with additional output formats if needed
5. Consider additional refinements to further improve the separation of concerns

## Common Commands
To run tests for the reporting module:
```bash
cd /home/gregg/Projects/lust-next
lua scripts/run_tests.lua tests/reporting_test.lua
```

To run the example:
```bash
cd /home/gregg/Projects/lust-next
lua examples/report_example.lua
```

To run all tests:
```bash
cd /home/gregg/Projects/lust-next
lua scripts/run_tests.lua
```

## Key Implementation Details
1. The reporting module provides:
   - Standardized data interfaces for modules to use
   - Formatters for different output types (summary, JSON, HTML, LCOV) 
   - File I/O operations with directory creation
   - Centralized error handling
   - Auto-save functionality for multiple reports

2. The updated modules:
   - Return structured data via get_report_data() function
   - Maintain backward compatibility with existing APIs
   - Use the reporting module when available, with fallbacks

3. Backward compatibility is maintained:
   - Old APIs (report(), summary_report(), etc.) still work
   - Legacy file operations are supported as fallbacks
   - Error handling gracefully degrades

4. Test structure:
   - Unit tests for formatters with mock data
   - Tests for file operations with temporary files
   - Integration tests with actual modules
   - Error case handling tests
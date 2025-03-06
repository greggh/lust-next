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
- Fixing and enhancing the modular report generation architecture to:
  - Resolve data flow issues between modules
  - Ensure reliable file operations and directory creation
  - Improve error handling and diagnostic capabilities
  - Fix module loading across different environments
  - Maintain proper separation of concerns

## Completed Tasks
- Created `src/reporting.lua` for centralized report formatting and file I/O
- Refactored `src/coverage.lua` to return structured data instead of generating reports
- Refactored `src/quality.lua` to follow the same pattern
- Updated `lust-next.lua` to use the reporting module when appropriate
- Enhanced `get_report_data()` functions with better diagnostics
- Improved module loading with additional search paths and fallbacks
- Added explicit stats calculation to ensure proper data collection
- Enhanced directory creation and file I/O for more reliable report generation
- Added comprehensive debugging output to diagnose integration issues
- Fixed fallback mechanisms to ensure reports are generated even when debug hooks fail
- Enhanced run_tests.lua in lust-next-testbed with manual dataset creation when needed
- Improved input validation throughout the reporting process
- Added multiple directory creation methods to handle different environments
- Enhanced error handling with detailed diagnostic information
- Implemented robust source file tracking with multiple fallback mechanisms

## Files of Interest
- `/home/gregg/Projects/lust-next/src/reporting.lua` - New reporting module
- `/home/gregg/Projects/lust-next/src/coverage.lua` - Coverage module (refactored)
- `/home/gregg/Projects/lust-next/src/quality.lua` - Quality module (refactored)
- `/home/gregg/Projects/lust-next/lust-next.lua` - Main framework file
- `/home/gregg/Projects/lust-next/tests/reporting_test.lua` - Tests for reporting module
- `/home/gregg/Projects/lust-next/examples/report_example.lua` - Example demonstrating reporting

## Next Steps
1. ✅ Test the fixes with comprehensive coverage and quality validation:
   ```bash
   env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --coverage -cf html tests/coverage_tests/coverage_formats_test.lua
   ```
2. ✅ Complete the update of run_tests.lua in lust-next-testbed with fallback mechanisms
3. ✅ Implement better source tracking for more accurate coverage reporting
4. Create more robust test cases that test the edge cases of the reporting system
5. Enhance reporting module with additional output formats (e.g., Cobertura XML)
6. Add visualization improvements to the HTML report (e.g., source code highlighting)
7. Create a comprehensive validation suite that tests all module interactions
8. Add configuration support for report file naming and location specification

## Common Commands

### Testing and Debugging

To run tests for the reporting module:
```bash
env -C /home/gregg/Projects/lust-next lua scripts/run_tests.lua tests/reporting_test.lua
```

To run the example:
```bash
env -C /home/gregg/Projects/lust-next lua examples/report_example.lua
```

To run all tests:
```bash
env -C /home/gregg/Projects/lust-next lua scripts/run_tests.lua
```

### Debugging Report Generation

To debug report generation with extensive logging:
```bash
env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --coverage -cf html tests/coverage_tests/coverage_formats_test.lua
```

To see quality report generation:
```bash
env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --quality --quality-level 2 tests/coverage_tests/coverage_quality_integration_test.lua
```

To debug coverage source tracking:
```bash
env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --coverage --coverage-include "src/calculator.lua,src/database.lua" tests/coverage_tests/coverage_formats_test.lua
```

To test both coverage and quality together:
```bash
env -C /home/gregg/Projects/lust-next-testbed lua run_tests.lua --coverage -cf html --quality --quality-level 3 tests/coverage_tests/coverage_quality_integration_test.lua
```

## Key Implementation Details
1. The reporting module provides:
   - Standardized data interfaces for modules to use
   - Formatters for different output types (summary, JSON, HTML, LCOV) 
   - File I/O operations with enhanced directory creation
   - Centralized error handling with diagnostics
   - Auto-save functionality for multiple reports
   - Input validation to handle incomplete or missing data
   - Multiple directory creation methods for different environments

2. The updated modules:
   - Return structured data via enhanced get_report_data() function
   - Calculate stats explicitly with coverage.calculate_stats()
   - Include diagnostic output to help with debugging
   - Maintain backward compatibility with existing APIs
   - Use the reporting module when available, with fallbacks
   - Include fallback mechanisms for when debug hooks fail to track files

3. Module loading improvements:
   - Additional search paths for better module discovery
   - Multiple fallback loading mechanisms 
   - Explicit directory creation with error detection
   - Better path handling across environments
   - Comprehensive error reporting
   - Direct loading when module resolution fails

4. Data flow architecture:
   - Coverage/quality modules collect data during test execution
   - Data is processed and structured when get_report_data() is called
   - Reporting module formats the data into requested output format
   - Reporting module handles all file I/O operations
   - Error handling throughout the full process
   - Fallback data generation when collection fails

5. Robust fallback mechanisms:
   - Manual dataset creation when debug hooks fail to track files
   - Multiple directory creation attempts with different methods
   - Pattern-based source file detection and tracking
   - Graceful handling of missing or incomplete data
   - Comprehensive error detection with clear diagnostic output

6. Backward compatibility is maintained:
   - Old APIs (report(), summary_report(), etc.) still work
   - Legacy file operations are supported as fallbacks
   - Error handling gracefully degrades
   - Direct file writing as a last resort
   - Fallback mechanism for module loading
# Project: lust-next

## Overview
lust-next is an enhanced Lua testing framework that provides comprehensive testing capabilities for Lua projects. It features BDD-style nested test blocks, assertions with detailed error messages, setup/teardown hooks, advanced mocking, tagging, asynchronous testing, code coverage analysis with multiline comment support, and test quality validation.

## Essential Commands

### Testing Commands

- Run All Tests: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua tests/`
- Run Specific Test: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua tests/reporting_test.lua`
- Run Tests by Pattern: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --pattern=coverage tests/`
- Run Tests with Coverage: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --coverage tests/`
- Run Tests with Watch Mode: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --watch tests/`
- Run Tests with Quality Validation: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --quality tests/`
- Run Example: `env -C /home/gregg/Projects/lua-library/lust-next lua examples/report_example.lua`

### Test Command Format

The standard test command format follows this pattern:
```
lua test.lua [options] [path]
```

Where:
- `[options]` are command-line flags like `--coverage`, `--watch`, `--pattern=coverage`
- `[path]` is a file or directory path (the system automatically detects which)

Common options include:
- `--coverage`: Enable coverage tracking
- `--quality`: Enable quality validation
- `--pattern=<pattern>`: Filter test files by pattern
- `--watch`: Enable watch mode for continuous testing
- `--verbose`: Show more detailed output
- `--help`: Show all available options

> **Note:** We have completed the transition to a standardized test system where all tests run through the `test.lua` utility in the project root. All special-purpose runners have been removed in favor of this unified approach.

## Important Testing Notes

### Test Implementation Guidelines

- NEVER use `lust.run()` - this function DOES NOT EXIST
- NEVER use `lust()` to run tests - this is not a correct method
- Do not include any calls to `lust()` or `lust.run()` in test files
- Use proper lifecycle hooks: `before`/`after` (NOT `before_all`/`after_all`, which don't exist)
- Import test functions correctly: `local describe, it, expect = lust.describe, lust.it, lust.expect`
- For test lifecycle, use: `local before, after = lust.before, lust.after`

### Assertion Style Guide

lust-next uses expect-style assertions rather than assert-style assertions:

```lua
-- CORRECT: lust-next expect-style assertions
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
expect(value).to.match("pattern")
expect(fn).to.fail()

-- INCORRECT: busted-style assert assertions (don't use these)
assert.is_not_nil(value)         -- wrong
assert.equals(expected, actual)  -- wrong
assert.type_of(value, "string")  -- wrong
assert.is_true(value)            -- wrong
```

Note that the parameter order for equality assertions is the opposite of busted:
- In busted: `assert.equals(expected, actual)`
- In lust-next: `expect(actual).to.equal(expected)`

For negating assertions, use `to_not` rather than separate functions:
```lua
expect(value).to_not.equal(other_value)
expect(value).to_not.be_truthy()
expect(value).to_not.be.a("number")
```

### Common Assertion Mistakes to Avoid

1. **Incorrect negation syntax**:
   ```lua
   -- WRONG:
   expect(value).not_to.equal(other_value)  -- "not_to" is not valid
   
   -- CORRECT:
   expect(value).to_not.equal(other_value)  -- use "to_not" instead
   ```

2. **Incorrect member access syntax**:
   ```lua
   -- WRONG:
   expect(value).to_be(true)  -- "to_be" is not a valid method
   expect(number).to_be_greater_than(5)  -- underscore methods need dot access
   
   -- CORRECT:
   expect(value).to.be(true)  -- use "to.be" not "to_be"
   expect(number).to.be_greater_than(5)  -- this is correct because it's a method
   ```

3. **Inconsistent operator order**:
   ```lua
   -- WRONG:
   expect(expected).to.equal(actual)  -- parameters reversed
   
   -- CORRECT:
   expect(actual).to.equal(expected)  -- what you have, what you expect
   ```

### Complete Assertion Pattern Mapping

If you're coming from a busted-style background, use this mapping to convert assertions:

| busted-style                       | lust-next style                     | Notes                             |
|------------------------------------|-------------------------------------|-----------------------------------|
| `assert.is_not_nil(value)`         | `expect(value).to.exist()`          | Checks if a value is not nil      |
| `assert.is_nil(value)`             | `expect(value).to_not.exist()`      | Checks if a value is nil          |
| `assert.equals(expected, actual)`  | `expect(actual).to.equal(expected)` | Note the reversed parameter order! |
| `assert.is_true(value)`            | `expect(value).to.be_truthy()`      | Checks if a value is truthy       |
| `assert.is_false(value)`           | `expect(value).to_not.be_truthy()`  | Checks if a value is falsey       |
| `assert.type_of(value, "string")`  | `expect(value).to.be.a("string")`   | Checks the type of a value        |
| `assert.is_string(value)`          | `expect(value).to.be.a("string")`   | Type check                        |
| `assert.is_number(value)`          | `expect(value).to.be.a("number")`   | Type check                        |
| `assert.is_table(value)`           | `expect(value).to.be.a("table")`    | Type check                        |
| `assert.same(expected, actual)`    | `expect(actual).to.equal(expected)` | Deep equality check               |
| `assert.matches(pattern, value)`   | `expect(value).to.match(pattern)`   | String pattern matching           |
| `assert.has_error(fn)`             | `expect(fn).to.fail()`              | Checks if a function throws error |

For more comprehensive assertions and detailed examples, see `docs/coverage_repair/assertion_pattern_mapping.md`.

### Test Directory Structure

Tests are organized in a logical directory structure by component:
```
tests/
├── core/            # Core framework tests 
├── coverage/        # Coverage-related tests
│   ├── instrumentation/  # Instrumentation-specific tests
│   └── hooks/           # Debug hook tests
├── quality/         # Quality validation tests
├── reporting/       # Reporting framework tests
│   └── formatters/      # Formatter-specific tests
├── tools/           # Utility module tests
│   ├── filesystem/      # Filesystem module tests
│   ├── logging/         # Logging system tests
│   └── watcher/         # File watcher tests
└── ...
```

### Test Execution

- Tests are run using the standardized command: `lua test.lua [path]`
- For a single test file: `lua test.lua tests/reporting_test.lua`
- For a directory of tests: `lua test.lua tests/coverage/`
- For all tests: `lua test.lua tests/`

### Other Useful Commands

- Fix Markdown Files: `env -C /home/gregg/Projects/lua-library/lust-next lua scripts/fix_markdown.lua docs`
- Fix Specific Markdown Files: `env -C /home/gregg/Projects/lua-library/lust-next lua scripts/fix_markdown.lua README.md CHANGELOG.md`
- Debug Report Generation: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --coverage --format=html tests/reporting_test.lua`
- Test Quality Validation: `env -C /home/gregg/Projects/lua-library/lust-next lua test.lua --quality --quality-level=2 tests/quality_test.lua`

## Project Structure

- `/lib`: Modular codebase with logical subdirectories
  - `/lib/core`: Core utilities (type checking, fix_expect, version)
  - `/lib/async`: Asynchronous testing functionality 
  - `/lib/coverage`: Code coverage tracking
  - `/lib/quality`: Quality validation
  - `/lib/reporting`: Test reporting system
    - `/lib/reporting/formatters`: Individual formatter implementations
  - `/lib/tools`: Utilities (codefix, watcher, interactive CLI, markdown)
  - `/lib/mocking`: Mocking system (spy, stub, mock)
- `/tests`: Test files for framework functionality
- `/examples`: Example scripts demonstrating usage
- `/scripts`: Utility scripts for running tests
- `lust-next.lua`: Main framework file
- `lust.lua`: Compatibility layer for original lust
- `run_all_tests.lua`: Improved test runner for proper test state isolation

## Current Focus - Coverage System Enhancements and Hooks-Util Integration

We've completed the migration of all core files and examples to use our filesystem module instead of direct io.* functions, improving cross-platform compatibility and error handling. Our current focus is on enhancing the coverage system and integrating with the hooks-util project for better pre-commit and CI validation:

1. **Implementation Progress**:
   - ✅ Researched and analyzed five different Lua coverage implementations
   - ✅ Developed comprehensive implementation plan with modular architecture
   - ✅ Created modular architecture with separate components:
     - debug_hook.lua for core line tracking functionality
     - file_manager.lua for file discovery integrated with filesystem module
     - patchup.lua for handling non-executable lines
     - instrumentation.lua for source code transformation approach
   - ✅ Implemented pure Lua implementation (the first tier of our plan)
   - ✅ Created comprehensive test suite with real code execution
   - ✅ Implemented distinction between execution and coverage tracking
   - ✅ Added visualization for "executed but not covered" state

2. **Coverage Module Repair Plan**:
   - ✅ Created comprehensive coverage module repair plan with 4-phase approach
   - ✅ Established documentation framework for tracking repair progress in docs/coverage_repair
   - ✅ Developed initial architecture documentation structure
   - ✅ Created phase-by-phase implementation tracking
   - [ ] Phase 1: Clear Architecture Refinement
     - [ ] Code audit and architecture documentation
     - [ ] Debug code removal
     - [ ] Component isolation
   - [ ] Phase 2: Core Functionality Fixes
     - [ ] Static analyzer improvements
     - [ ] Debug hook enhancements
     - [ ] Data flow correctness
   - [ ] Phase 3: Reporting and Visualization
     - [ ] HTML formatter enhancement
     - [ ] Report validation
     - [ ] User experience improvements
   - [ ] Phase 4: Extended Functionality
     - [ ] Instrumentation approach
     - [ ] C extensions integration
     - [ ] Final integration and documentation

3. **Static Analysis Integration**:
   - ✅ Integrated lua-parser (MIT licensed) for AST generation
   - ✅ Created vendor integration of LPegLabel dependency
   - ✅ Implemented build-on-first-use mechanism for C components
   - ✅ Added fixes from upstream PRs for UTF-8 and table nesting
   - ✅ Created static_analyzer.lua module for code mapping
   - ✅ Implemented executable line identification via AST
   - ✅ Enhanced function detection with parameters and line ranges
   - ✅ Integrated with coverage module for accurate reporting
   - ✅ Fixed infinite recursion issues in line position calculation
   - ✅ Implemented cached line mapping for O(1) lookups
   - ✅ Added adaptive node-to-line mapping strategies based on file size
   - ✅ Added timeout and size limits throughout the codebase
   - ✅ Successfully tested performance with large files (2,000+ lines)
   - ✅ Implemented block-based coverage tracking for branches and loops
   - ✅ Added visualization for blocks in HTML reports
   - ✅ Created weighted coverage metrics combining lines, blocks, and functions
   - ✅ Successfully tested with over 80% block coverage in examples
   - ✅ Fixed data flow between analyzer and debug hook
   - ✅ Added conditional expression tracking for branch coverage
   - ✅ Enhanced HTML visualization with detailed legend for indicators
   - ✅ Improved block boundary detection and styling
   - ✅ Fixed line classification issues for executable vs. non-executable code
   - ✅ Fixed critical bug where executable lines are incorrectly marked as covered
   - ✅ Fixed issues with function tracking showing 0% coverage
   - ✅ Fixed over-reporting issues in certain files
   - ✅ Implemented proper multiline comment detection and handling
   - ✅ Resolved separation of concerns between coverage and reporting modules
   - ✅ Added post-processing verification steps to catch incorrectly marked lines
   - ✅ Updated statistics calculation to only count executable lines in coverage metrics
   - ✅ Fixed comparison against nil threshold values
   - ✅ Removed outdated test files from project root
   - ✅ Implemented distinction between execution and coverage tracking
   - ✅ Added visualization for "executed but not covered" state
   - ✅ Added configuration option for control flow keywords treatment
   - ✅ Implemented significantly improved comment detection
   - ✅ Added comprehensive documentation for control flow keywords option
   - ✅ Created examples demonstrating the impact of different configuration values
   - ✅ Added detailed guide for configuring coverage settings

4. **Centralized Logging System**:
   - ✅ Implemented centralized logging module (lib/tools/logging.lua)
   - ✅ Created robust logging API with multiple severity levels (FATAL, ERROR, WARN, INFO, DEBUG, TRACE)
   - ✅ Added support for module-specific log configurations
   - ✅ Implemented colored output and timestamp formatting
   - ✅ Added file output capabilities for persistent logs
   - ✅ Added `configure_from_options` helper to reduce code duplication
   - ✅ Implemented `configure_from_config` for global config integration
   - ✅ Removed redundant config passing between modules
   - ✅ Created example demonstrating global config-based logging
   - ✅ Converted debug print statements in multiple modules
   - ✅ Added careful wrapper for user-facing debug output
   - ✅ Implemented comprehensive log rotation system
   - ✅ Added configuration for log directory, file size limits and rotation count
   - ✅ Enhanced .gitignore to handle rotated log files
   - ✅ Created filesystem integration for log directory creation
   - ✅ Added logging system to global config defaults
   - ✅ Added detailed documentation for the logging system
   - ✅ Added log rotation system with size-based rotation
   - ✅ Converted print statements to logging in fix_expect, formatters, coverage, and watcher modules
   - ✅ Completely rewrote debug_dump in coverage module to fully use the logging system while preserving console output
   - ✅ Enhanced interactive.lua to use the logging system
   - ✅ Updated codefix module to use centralized logging
   - ✅ Enhanced parser modules to use logging with fallbacks for early loading
   - ✅ Created test case for log rotation system
   - ✅ Added logging configuration section to config template
   - ✅ Updated example to demonstrate config integration with rotation
   - ✅ Created comprehensive logging guide for contributors and users
   - ✅ Converted print statements in all script files to use the logging system:
     - scripts/run_tests.lua, scripts/runner.lua (core test runners)
     - scripts/fix_markdown.lua, scripts/version_check.lua, scripts/version_bump.lua (utility scripts) 
     - scripts/test_parser.lua, scripts/test_static_analyzer.lua, scripts/test_lpeglabel.lua, scripts/test_coverage_static_analysis.lua (test scripts)
   - ✅ Created find_print_statements.lua utility to identify and track remaining print statements
   - ✅ Added proper logging initialization with fallbacks for early module loading
   - ✅ Implemented consistent logging patterns across all script modules
   - ✅ Added logging to core modules including fix_expect, config, coverage, formatters
   - ✅ Created comprehensive logging style guide (docs/api/logging_style_guide.md)
   - ✅ Implemented structured parameter-based logging pattern
   - ✅ Converted key modules to use structured logging:
     - lib/core/config.lua - Configuration module with proper parameter tables
     - lib/coverage/init.lua - Coverage module with detailed structured logging
     - lib/tools/benchmark.lua - Performance benchmarking with structured data
     - lib/tools/parallel.lua - Parallel execution with robust logging
     - lib/tools/codefix.lua - Code quality tools with structured output
     - lib/reporting/init.lua and formatters - All reporting modules
     - lib/quality/init.lua - Quality module with detailed parameter information
     - lib/mocking/* - Complete mocking system (init, spy, stub, mock)
     - lib/tools/markdown.lua - Markdown processing module
     - lib/tools/parser/* - Parser modules (init, grammar, validator)
     - lust-next.lua - Main framework file with structured logging
     - lust.lua - Compatibility layer with structured warnings
     - test files - Primary test files with structured logging
   - ✅ Standardized separation of message content from contextual data
   - ✅ Added detailed parameter information for improved debugging
   - ✅ Implemented consistent logging patterns across all primary modules
   - ✅ Enhanced interactive.lua with improved component-based logging

5. **Quality Validation Enhancements**:
   - ✅ Refactored to use new filesystem module
   - ✅ Increased coverage threshold to 90% from 80%
   - Integrate AST-based complexity metrics
   - Implement test-to-code mapping functionality
   - Add detailed quality recommendations based on AST analysis
   - Create combined coverage/quality HTML reports
   - Run level 5 code quality tests

5. **Documentation Enhancement Plan**:
   - ✅ Create comprehensive documentation for all logging features:
     - ✅ Document log search and query functionality
     - ✅ Document external tool integration for popular platforms
     - ✅ Document test formatter integration
     - ✅ Explain buffering capabilities and configuration
   - ✅ Document all filesystem functions with comprehensive examples
   - ✅ Create usage patterns documentation for common scenarios
   - ✅ Add cross-platform compatibility notes for all functions
   - ✅ Create migration guide for replacing io.* functions
   - Replace io.* functions with filesystem module throughout codebase
   - Update coverage module documentation with new features
   - Create tutorials for common use cases across modules
   - Document test mode feature for coverage module
   - ✅ Update documentation for structured logging implementation across framework
   - ✅ Create logging style guide for consistent implementation

All major filesystem module work is complete with proper integration throughout the codebase. The static analysis integration is now fully implemented with significant performance optimizations. By fixing critical recursive functions and implementing efficient caching strategies, we've reduced processing time for large files from potential infinite loops to just a few seconds. The system can now reliably process files up to 2,000+ lines, making it suitable for real-world Lua codebases. Our current focus is completing the block-based coverage tracking for even more detailed metrics.

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

- All planned features from our testing plan have been implemented:
  - ✅ TAP output format support for broader testing ecosystem integration
  - ✅ CSV output format for spreadsheet and data analysis integration
  - ✅ Command-line configuration for report file naming and paths
  - ✅ Runtime configuration options for custom test output formats
  - ✅ Improved test suite isolation with module reset system
  - ✅ Benchmarking tools for performance analysis
  - ✅ Memory usage tracking and optimization
  - ✅ Parallel test execution across multiple processes
  - ✅ Results aggregation from parallel test runs
  - ✅ Coverage data merging from multiple processes
  - ✅ Configuration file system for customizing defaults (.lust-next-config.lua)
- ✅ Completed comprehensive filesystem module migration:
  - ✅ Created standalone filesystem module with platform-independent operations
  - ✅ Documented all filesystem functions with comprehensive examples
  - ✅ Added cross-platform compatibility notes for all functions
  - ✅ Created detailed implementation plan for filesystem migration
  - ✅ Migrated core modules (codefix.lua, benchmark.lua) to filesystem module
  - ✅ Migrated script files (fix_markdown.lua, version_check.lua, version_bump.lua)
  - ✅ Migrated core framework files to use filesystem module
  - ✅ Updated lust-next.lua (main framework file) to use fs.read_file
  - ✅ Migrated lib/tools/parallel.lua (test execution module)
  - ✅ Updated critical test files (logging_test.lua, quality_test.lua, watch_mode_test.lua)
  - ✅ Migrated all example files to use the filesystem module
  - ✅ Fixed test assertions to match structured logging output
- ✅ Implemented comprehensive centralized logging module:
  - ✅ Added global config integration for logging configuration
  - ✅ Converted debug print statements to standardized logging
  - ✅ Converted all script modules to use the logging system
  - ✅ Created find_print_statements.lua utility for tracking conversion progress
  - ✅ Implemented structured logging formats (JSON) for monitoring tools
  - ✅ Added filtering capabilities by module/level for interactive sessions
  - ✅ Created comprehensive examples for JSON logging and filtering capabilities
  - ✅ Created comprehensive logging style guide (docs/api/logging_style_guide.md)
  - ✅ Implemented structured parameter-based logging pattern
  - ✅ Converted key modules to structured logging (config, coverage, benchmark, codefix)
  - ✅ Converted reporting modules to structured logging 
  - ✅ Enhanced interactive.lua with improved component-based structured logging
- Current Focus - Coverage System Enhancements and Hooks-Util Integration:
  - Create comprehensive documentation for the filesystem module:
    - Document cross-platform testing strategies
    - Create guide for optimizing filesystem operations
    - Document approaches for replacing io.popen calls
    - Create performance benchmarking guide for filesystem operations
  - Enhance AST-based coverage tracking:
    - Integrate AST-based code analysis for quality metrics
    - Add hover tooltips for execution count display
    - Create visualization for block execution frequency
    - Add function complexity metrics to coverage reports
  - Integrate with hooks-util project:
    - Create pre-commit hooks for lust-next projects
    - Implement automated test execution in Git hooks
    - Add filesystem module migration checks to hooks
    - Create CI workflow examples for different platforms
- Potential future enhancements:
  - Additional specialized formatters for specific CI/CD pipelines
  - Stream-based test result processing for extremely large test suites
  - Distributed test execution across multiple machines
  - Fully automated performance benchmarking system

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/lust-next-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/lust-next-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`
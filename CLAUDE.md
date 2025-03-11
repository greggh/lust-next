# Project: lust-next

## Overview
lust-next is an enhanced Lua testing framework that provides comprehensive testing capabilities for Lua projects. It features BDD-style nested test blocks, assertions with detailed error messages, setup/teardown hooks, advanced mocking, tagging, asynchronous testing, code coverage analysis with multiline comment support, and test quality validation.

## Essential Commands

- Run Tests: `env -C /home/gregg/Projects/lua-library/lust-next lua run_all_tests.lua`
- Run Specific Test: `env -C /home/gregg/Projects/lua-library/lust-next lua scripts/run_tests.lua tests/reporting_test.lua`
- Run Example: `env -C /home/gregg/Projects/lua-library/lust-next lua examples/report_example.lua`
- Fix Markdown Files: `env -C /home/gregg/Projects/lua-library/lust-next lua scripts/fix_markdown.lua docs`
- Fix Specific Markdown Files: `env -C /home/gregg/Projects/lua-library/lust-next lua scripts/fix_markdown.lua README.md CHANGELOG.md`
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
  - `/lib/tools`: Utilities (codefix, watcher, interactive CLI, markdown)
  - `/lib/mocking`: Mocking system (spy, stub, mock)
- `/tests`: Test files for framework functionality
- `/examples`: Example scripts demonstrating usage
- `/scripts`: Utility scripts for running tests
- `lust-next.lua`: Main framework file
- `lust.lua`: Compatibility layer for original lust
- `run_all_tests.lua`: Improved test runner for proper test state isolation

## Current Focus - Logging System Documentation and Filesystem Integration

We've completed all features for the comprehensive logging system including advanced capabilities like log search, external tool integration, test formatter integration, and buffering. Our current focus is on creating thorough documentation for all these features and replacing io.* function usage with our filesystem module:

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

2. **Fixed Core Coverage Issues**:
   - ✅ Fixed lust-next assertion chain syntax (to.be_greater_than vs to.be.greater.than)
   - ✅ Removed old coverage_test.lua file that used previous API
   - ✅ Enhanced debugging with detailed output on coverage status
   - ✅ Improved configuration options for source directories and patterns
   - ✅ Fixed path handling and file normalization throughout the module
   - ✅ Fixed configuration integration with core config module
   - ✅ Fixed bug with global normalize_path reference
   - ✅ Fixed function detection in debug hook
   - ✅ Resolved filesystem "Permission denied" errors
   - ✅ Implemented discovery of uncovered files
   - ✅ Improved coverage visualization with dark mode theme
   - ✅ Fixed non-executable lines incorrectly marked as covered
   - ✅ Resolved circular logic in coverage calculation
   - ✅ Improved multiline comment detection

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
   - ✅ Create detailed implementation plan for filesystem migration
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
- Current focus - Logging System Documentation and Filesystem Integration:
  - ✅ Implement comprehensive centralized logging module
  - ✅ Add global config integration for logging configuration
  - ✅ Convert debug print statements to standardized logging
  - ✅ Convert all script modules to use the logging system
  - ✅ Implement static analysis for improved coverage accuracy
  - ✅ Implement block-based coverage tracking
  - ✅ Add configuration option for control flow keywords treatment
  - ✅ Create significantly improved comment detection
  - ✅ Add comprehensive documentation for control flow keywords option
  - ✅ Create examples demonstrating the impact of different configuration values
  - ✅ Create detailed documentation for basic logging system
  - ✅ Create find_print_statements.lua utility for tracking conversion progress
  - ✅ Complete conversion of run_all_tests.lua (function override pattern)
  - ✅ Implement structured logging formats (JSON) for monitoring tools
  - ✅ Add filtering capabilities by module/level for interactive sessions
  - ✅ Create comprehensive examples for JSON logging and filtering capabilities
  - ✅ Create comprehensive logging style guide (docs/api/logging_style_guide.md)
  - ✅ Implement structured parameter-based logging pattern
  - ✅ Convert key modules to structured logging style (config, coverage, benchmark, parallel, codefix)
  - ✅ Convert reporting modules to structured logging 
  - ✅ Convert quality module to structured logging
  - ✅ Convert mocking system to structured logging
  - ✅ Convert parser modules to structured logging
  - ✅ Convert markdown.lua to structured logging
  - ✅ Enhanced interactive.lua with improved component-based structured logging
  - ✅ Add log search and query functionality (search.lua)
  - ✅ Create external tool integration (export.lua)
  - ✅ Add test formatter integration (formatter_integration.lua)
  - ✅ Implement buffering for high-volume logging
  - ✅ Create comprehensive test suite for all logging features
  - [ ] Document log search and query functionality
  - [ ] Document external tool integration for popular platforms
  - [ ] Document test formatter integration
  - [ ] Document buffering capabilities and configuration
  - [ ] Replace io.* functions with filesystem module throughout codebase
  - [ ] Integrate AST-based code analysis for quality metrics
  - [ ] Add hover tooltips for execution count tracking
  - [ ] Test logging system with larger codebases to verify performance
  - [ ] Fully integrate with hooks-util project
- Potential future enhancements:
  - Additional specialized formatters for specific CI/CD pipelines
  - Stream-based test result processing for extremely large test suites
  - Distributed test execution across multiple machines
  - Fully automated performance benchmarking system

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/lust-next-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/lust-next-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`
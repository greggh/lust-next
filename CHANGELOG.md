# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Fork from bjornbytes/lust to enhance functionality
- GitHub Actions CI workflow for testing on multiple Lua versions
- GitHub structure with templates and community health files
- Documentation improvements with modern markdown format
- Test directory with initial test suite
- Examples directory with sample usage
- Enhanced README with new feature descriptions
- Automatic test discovery for finding and running test files
- Test filtering and tagging system:
  - Tag tests with `lust.tags()` function
  - Filter by tag with `lust.only_tags()`
  - Filter by name pattern with `lust.filter()`
  - Command-line filtering with `--tags` and `--filter` flags
  - Skip tracking for filtered tests
- Enhanced reporting with clearer test summaries
- Improved CLI with more flexible options
- Async testing support:
  - `lust.async()` for wrapping async test functions
  - `lust.await()` for waiting in tests
  - `lust.wait_until()` for condition-based waiting
  - `lust.it_async()` for simplified async test declaration
  - Configurable timeouts and error handling
  - Comprehensive examples in examples/async_example.lua
- Comprehensive mocking system:
  - Enhanced spy functionality with call tracking
  - Stub system for replacing functions
  - Mock objects for complete dependency isolation
  - Automatic cleanup through `with_mocks` context
  - Verification of mock expectations
  - Advanced call tracking with argument matching
  - Detailed examples in examples/mocking_example.lua
- Enhanced assertions:
  - Table assertions:
    - Key and value containment checking
    - Subset validation
    - Exact key checking
  - String assertions:
    - Prefix and suffix validation
  - Type assertions:
    - Callable, comparable, and iterable checking
  - Numeric assertions:
    - Greater/less than comparisons
    - Range checking with `be_between`
    - Approximate equality for floating point
  - Error assertions:
    - Enhanced error pattern matching
    - Error type verification
  - Complete validation examples for complex data structures

### Planned
- Enhanced documentation with organized API reference

## [0.2.0] - Original lust

This is where the fork begins. Original [lust project](https://github.com/bjornbytes/lust) features:

### Features
- Nested describe/it blocks
- Before/after handlers
- Expect-style assertions
- Function spies
- Support for console and non-console environments

[Unreleased]: https://github.com/greggh/lust/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bjornbytes/lust/tree/master
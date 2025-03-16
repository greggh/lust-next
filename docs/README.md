# Firmo Documentation

[![Version](https://img.shields.io/badge/Version-0.7.4-blue?style=flat-square)](https://github.com/greggh/firmo/releases/tag/v0.7.4)
Welcome to the Firmo documentation. firmo is a lightweight, powerful testing library for Lua projects, offering a rich set of features while maintaining simplicity and ease of use.

## Latest Updates

### Unreleased

- **Enhanced Modular Reporting Architecture**:
  - Centralized reporting module for all output formats
  - Support for multiple report formats (HTML, JSON, LCOV, Summary)
  - Robust fallback mechanisms for reliable report generation
  - Comprehensive error handling and diagnostics
  - Improved file operations and module loading

### v0.7.4

- **Module Reset Utilities**: New functions for ensuring clean test state:
  - `reset_module()`: Reset and reload modules between tests
  - `with_fresh_module()`: Run tests with a freshly loaded module instance
- **Enhanced Async Testing**:
  - New `parallel_async()` function for running multiple operations concurrently
  - Improved error handling in `wait_until()` for timeout scenarios
  - Better performance when running multiple async tests

## Documentation Structure

- [**API Reference**](api/README.md): Detailed documentation of all available functions and options
  - [Core Functions](api/core.md): Test organization with describe/it blocks
  - [Assertions](api/assertions.md): Rich assertion library
  - [Async Testing](api/async.md): Testing asynchronous code
  - [Mocking](api/mocking.md): Mock and spy functionality
  - [Module Reset](api/module_reset.md): Module management utilities
  - [Coverage](api/coverage.md): Code coverage tracking and reporting
  - [Quality](api/quality.md): Test quality validation
  - [Reporting](api/reporting.md): Report generation and file operations
  - [Test Filtering](api/filtering.md): Running specific test subsets
  - [CLI](api/cli.md): Command-line interface usage
  - [Test Discovery](api/discovery.md): Finding and running tests
- [**Guides**](guides/README.md): How-to guides for common tasks
  - [Getting Started](guides/getting-started.md): Your first tests with firmo
  - [Reporting](guides/reporting.md): Using coverage, quality, and reporting
  - [Migrating from Other Frameworks](guides/migrating.md): Transitioning from other test frameworks
  - [CI Integration](guides/ci_integration.md): Setup for continuous integration

## Quick Links

- [GitHub Repository](https://github.com/greggh/firmo)
- [Issue Tracker](https://github.com/greggh/firmo/issues)
- [Changelog](https://github.com/greggh/firmo/blob/main/CHANGELOG.md)

## Installation

```bash

# Option 1: Copy the single file to your project
curl -o firmo.lua https://raw.githubusercontent.com/greggh/firmo/master/firmo.lua

# Option 2: Use as Git submodule
git submodule add https://github.com/greggh/firmo.git deps/firmo

```

## Basic Usage

```lua
-- Import and expose globals for convenience
local firmo = require('firmo')
firmo.expose_globals()
-- Write your tests
describe("Calculator", function()
  it("adds numbers correctly", function()
    assert.equal(5, 2 + 3)
  end)
  it("subtracts numbers correctly", function()
    assert.equal(5, 8 - 3)
  end)
end)

```

## Contributing

Contributions are welcome! See the [Contributing Guide](https://github.com/greggh/firmo/blob/main/CONTRIBUTING.md) for details on how to get involved.

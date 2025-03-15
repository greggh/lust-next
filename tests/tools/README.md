# Tools Tests

This directory contains tests for the firmo utility tools. These tools provide supporting functionality for the testing framework.

## Directory Contents

- **codefix_test.lua** - Tests for code quality improvement tools
- **fix_markdown_script_test.lua** - Tests for Markdown formatting utilities
- **interactive_mode_test.lua** - Tests for interactive CLI functionality
- **markdown_test.lua** - Tests for Markdown processing utilities

### Subdirectories

- **filesystem/** - Tests for filesystem operations
  - **filesystem_test.lua** - Tests for filesystem module
- **logging/** - Tests for logging system
  - **logging_test.lua** - Tests for logging functionality
- **watcher/** - Tests for file watching system
  - **watch_mode_test.lua** - Tests for watch mode functionality

## Tools Features

The firmo tools provide supporting functionality:

- **Filesystem** - Cross-platform file operations
- **Logging** - Structured logging with levels and filtering
- **Codefix** - Code quality improvement suggestions
- **Interactive CLI** - Command-line interface for running tests
- **Watcher** - File change detection for continuous testing
- **Markdown** - Documentation processing utilities

## Filesystem Features

The filesystem module provides platform-independent file operations:

- File reading and writing
- Directory creation and scanning
- Path manipulation and normalization
- Temporary file management
- Platform detection and adaptation

## Logging System

The logging system provides structured logging capabilities:

- Multiple severity levels (FATAL, ERROR, WARN, INFO, DEBUG, TRACE)
- Module-specific configurations
- Colored console output
- File output with rotation
- Structured data logging
- Integration with test reporting

## Running Tests

To run all tools tests:
```
lua test.lua tests/tools/
```

To run specific tools tests:
```
lua test.lua tests/tools/codefix_test.lua
```

To run filesystem tests:
```
lua test.lua tests/tools/filesystem/
```

See the [Tools API Documentation](/docs/api/tools.md) for more information.
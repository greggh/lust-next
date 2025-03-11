# IO Replacement Plan for lust-next

This document outlines our systematic approach to replacing all `io.*` function calls with our robust `filesystem` module across the lust-next codebase.

## Current Status

Based on our analysis, we have identified approximately 33 files containing direct `io.*` function calls. We need to migrate these to use the filesystem module for improved error handling, cross-platform compatibility, and integration with our logging system.

## Migration Priority

We'll prioritize files in the following order:

1. **Core Libraries and Utilities**
   - Logging module and its submodules (already partially migrated)
   - Reporting formatters (cobertura, html, json, etc.)
   - Core testing utilities

2. **User-Facing Features**
   - Interactive mode
   - Watch mode
   - CLI interface

3. **Examples and Tests**
   - Example files
   - Test files

## File-by-File Migration Plan

### Phase 1: Core Libraries (Weeks 1-2)

#### Logging Subsystem

| File | Status | Description |
|------|--------|-------------|
| `lib/tools/logging.lua` | Pending | Main logging module |
| `lib/tools/logging/search.lua` | Pending | Log search functionality |
| `lib/tools/logging/export.lua` | Pending | Log export functionality |
| `lib/tools/logging/formatter_integration.lua` | Pending | Test formatter integration |

#### Reporting Formatters

| File | Status | Description |
|------|--------|-------------|
| `lib/reporting/formatters/html.lua` | Pending | HTML report generation |
| `lib/reporting/formatters/json.lua` | Pending | JSON report generation |
| `lib/reporting/formatters/cobertura.lua` | Pending | Cobertura XML report generation |
| `lib/reporting/formatters/lcov.lua` | Pending | LCOV report generation |
| `lib/reporting/formatters/junit.lua` | Pending | JUnit XML report generation |
| `lib/reporting/formatters/tap.lua` | Pending | TAP report generation |
| `lib/reporting/formatters/csv.lua` | Pending | CSV report generation |
| `lib/reporting/formatters/summary.lua` | Pending | Summary report generation |

### Phase 2: User-Facing Features (Weeks 3-4)

| File | Status | Description |
|------|--------|-------------|
| `lib/tools/interactive.lua` | Pending | Interactive CLI mode |
| `lib/tools/watcher.lua` | Pending | Watch mode for continuous testing |
| `lib/tools/markdown.lua` | Pending | Markdown processing for docs |
| `lib/tools/codefix.lua` | Pending | Code quality fixing tool |
| `lib/tools/benchmark.lua` | Pending | Performance benchmarking |
| `lib/tools/parallel.lua` | Pending | Parallel test execution |

### Phase 3: Examples and Tests (Weeks 5-6)

| File | Status | Description |
|------|--------|-------------|
| `scripts/discover.lua` | Pending | Test discovery script |
| `scripts/version_check.lua` | Pending | Version checking utility |
| `scripts/fix_markdown.lua` | Pending | Markdown fixing utility |
| `scripts/runner.lua` | Pending | Test runner script |
| `scripts/find_print_statements.lua` | Pending | Print statement finder |
| `scripts/version_bump.lua` | Pending | Version bumping utility |
| `run_all_tests.lua` | Pending | Main test runner |
| `examples/codefix_example.lua` | Pending | Example for code fixing |
| `examples/parallel_execution_example.lua` | Pending | Example for parallel execution |
| `examples/performance_benchmark_example.lua` | Pending | Example for benchmarking |
| `examples/module_reset_example.lua` | Pending | Example for module resetting |

## Implementation Approach

For each file, we'll follow these steps:

1. **Code Audit**: Identify all `io.*` function calls and understand their context
2. **Test Creation**: If not already covered, create tests for the functionality being migrated
3. **Implementation**: Replace `io.*` calls with equivalent `filesystem` module functions
4. **Error Handling**: Enhance error handling to utilize the improved error messages
5. **Logging Integration**: Integrate with the logging system where appropriate
6. **Testing**: Verify the behavior remains the same with comprehensive testing
7. **Documentation**: Update comments and documentation to reflect the changes

## Testing Strategy

To ensure the migration doesn't introduce regressions:

1. **Unit Tests**: Each file should have associated unit tests
2. **Integration Tests**: Test interactions between components
3. **End-to-End Tests**: Verify overall system functionality
4. **Cross-Platform Testing**: Test on Linux, macOS, and Windows
5. **Edge Cases**: Test error conditions, file permission issues, etc.

## Challenges and Mitigations

### Challenge: Line-by-Line Reading

The `filesystem` module currently reads entire files, but some code may need line-by-line processing for efficiency.

**Mitigation**: 
- For most files, convert to full file reads and string splitting
- For very large files, maintain a hybrid approach until we implement streaming reads

### Challenge: Binary Data Handling

Some file operations may involve binary data where text processing isn't appropriate.

**Mitigation**:
- The `filesystem` module already supports binary data correctly
- Verify binary handling for each use case during migration

### Challenge: Temporary Files

The codebase may rely on `os.tmpname()` for temporary file creation.

**Mitigation**:
- Implement a helper function using the filesystem module
- Use consistent temporary directory handling

## Timeline

| Phase | Weeks | Description |
|-------|-------|-------------|
| Planning | 0 | Document creation, code auditing (Complete) |
| Phase 1 | 1-2 | Core Libraries Migration |
| Phase 2 | 3-4 | User-Facing Features Migration |
| Phase 3 | 5-6 | Examples and Tests Migration |
| Testing | 7 | Comprehensive testing across platforms |
| Documentation | 8 | Update all relevant documentation |

## Progress Tracking

We'll track progress using the following metrics:

1. **Files Migrated**: Number of files fully migrated
2. **IO Calls Replaced**: Number of `io.*` function calls replaced
3. **Test Coverage**: Percentage of code covered by tests
4. **Platforms Tested**: Which platforms have been verified

## Success Criteria

The migration will be considered successful when:

1. All `io.*` function calls have been replaced with `filesystem` module functions
2. All tests pass on all target platforms
3. No regressions in functionality or performance
4. Documentation is updated to reflect the changes
5. New file operations use the `filesystem` module by default

## Initial Audit Results

Here's a summary of our initial audit:

- **Total files with io.* usage**: 33
- **Total io.* function calls**: ~150
- **Most common patterns**:
  - `io.open` for reading files (~50 instances)
  - `io.open` for writing files (~40 instances)
  - `io.popen` for executing commands (~20 instances)
  - `io.stdin/stdout/stderr` access (~10 instances)
  - Miscellaneous (`io.lines`, `io.type`, etc.) (~30 instances)

## Getting Started

The first targets for migration are the logging system modules, as they're already partially using the filesystem module and serve as a critical foundation for the rest of the system.

## How to Help

Contributors can help by:

1. Reviewing the migration plan and suggesting improvements
2. Taking ownership of specific files for migration
3. Creating or enhancing tests for files being migrated
4. Testing on different platforms
5. Updating documentation to reflect changes
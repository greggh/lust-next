# Error Suppression System and Test Updates

## Summary

This PR implements a logger-level error suppression system for tests that intentionally trigger errors. It allows tests to be marked with `{ expect_error = true }` to automatically downgrade ERROR/WARNING logs to DEBUG level, maintaining clean test output while preserving error information when needed. The PR also updates several tests to use this system and provides documentation to help other developers adopt it.

## Changes

### Core Error Suppression System
- Added logic to detect tests with `expect_error = true` flag and downgrade logs
- Added `[EXPECTED]` prefix to suppressed errors for clarity
- Implemented debug flag detection to control error visibility
- Created error history registry for programmatic access to expected errors
- Added helper functions to access the error history

### Test Updates
- Updated `tests/tools/filesystem/filesystem_test.lua` to use error suppression for directory deletion tests
- Updated `tests/tools/watcher/watch_mode_test.lua` to use error suppression for module loading and file operations

### Documentation
- Created comprehensive guide at `docs/guides/error_suppression_guide.md`
- Added checklist for updating tests at `docs/guides/error_suppression_checklist.md`
- Documented both logging-level suppression and programmatic error access

## Benefits

- Cleaner test output (ERROR logs only appear for actual test failures)
- Preserved error information (full details available with `--debug` flag)
- Explicit marking of tests that expect errors
- Consistent error handling pattern across test files
- Programmatic access to expected errors for advanced test scenarios

## Testing Done

- Ran updated tests both with and without `--debug` flag to verify suppression
- Confirmed error messages are properly marked with `[EXPECTED]` prefix in debug mode
- Verified core functionality works with existing error handling patterns

## Next Steps

- Update additional test files that would benefit from error suppression
- Add documentation to the main README about the error suppression system
- Consider enhancing the system with more granular control options
# Coverage Module V2 Migration Guide

## Overview

The Firmo coverage system has been fully migrated to version 2.0, which includes significant enhancements and architectural improvements. This document describes the migration process and key changes to help users adapt to the new system.

## Key Improvements in Coverage 2.0

1. **Enhanced Block Relationship Tracking**
   - Automatic repair of inconsistent parent-child relationships
   - Improved algorithm for establishing block hierarchies
   - Better handling of complex nested code structures

2. **Error Line Tracking**
   - Properly tracks lines containing `error()` calls
   - Error lines are now marked as covered when tested with `expect(...).to.fail()`
   - No false negatives for error handling code in coverage reports

3. **Improved Test File Tracking**
   - Test files are now properly tracked for coverage analysis
   - First line of test files (such as `local firmo = require("firmo")`) now shows correct execution count

4. **HTML Report Enhancements**
   - Better visual distinction between covered and uncovered lines
   - More accurate line classification and highlighting
   - Improved readability with consistent coloring

5. **Central Configuration Integration**
   - Complete integration with the central_config system
   - All coverage settings are configurable through `.firmo-config.lua`

6. **Data Structure Standardization**
   - Consistent data structure across all coverage components
   - Normalized handling of line and function tracking data
   - Improved performance and reduced memory usage

## Migration Path

The migration from the previous coverage system to Coverage 2.0 has been implemented with backward compatibility in mind:

1. **API Compatibility**: Coverage 2.0 maintains the same public API as the previous version
2. **Configuration Compatibility**: Existing configuration settings will continue to work
3. **Report Format Compatibility**: Coverage reports maintain the same format and structure

## Using Coverage 2.0

The usage of Coverage 2.0 remains the same as the previous version:

```lua
-- Initialize coverage
local coverage = require("lib.coverage")
coverage.start()

-- Run your code here...

-- Stop coverage and generate reports
coverage.stop()
coverage.generate_reports("./coverage-reports", {"html", "lcov"})
```

### Configuration Options

Coverage 2.0 supports the following configuration options:

```lua
-- In .firmo-config.lua
return {
  coverage = {
    track_all_executed = true,
    include = {"**/*.lua"},
    exclude = {"**/vendor/**/*.lua"},
    auto_fix_block_relationships = true,
    debug = false
  }
}
```

## Migration Status

The migration from coverage v2 to the main coverage system is now complete:

1. **Legacy Coverage Module Removed**:
   - The `lib/coverage/v2` directory has been removed
   - All functionality has been integrated into the main coverage module
   - The main module now implements all v2 features with enhancements

2. **Test Implementation**:
   - Tests in `tests/coverage/v2/` should be migrated to use the main coverage module
   - All new tests should use the main coverage module directly

## Known Issues and Limitations

1. **Deep Nesting**: Very deeply nested code blocks (>10 levels) may still have some relationship tracking issues
2. **Custom Error Mechanisms**: Only standard Lua `error()` calls are tracked; custom error mechanisms may not be properly tracked
3. **Performance Impact**: Error line tracking adds a small overhead to test execution

## Technical Migration Details

For developers working on the coverage system:

1. **Code Migration**: All core functionality has been migrated from `lib/coverage/v2/` to the main coverage module
2. **Formatter Migration**: Formatters have been moved to `lib/reporting/formatters/`
3. **Test Migration**: Tests in `tests/coverage/v2/` should be updated to use the main coverage module
4. **Version Number**: The coverage module version has been updated to 2.0.0
5. **Documentation**: Documentation has been updated to reflect the new architecture

## Future Plans

1. **Complete Removal of V2 Directory**: The `lib/coverage/v2/` directory will be removed in a future version
2. **Performance Optimizations**: Further optimizations to improve performance
3. **Enhanced Report Filtering**: More granular control over what is included in coverage reports
4. **Interactive HTML Reports**: Enhanced HTML reports with interactive features
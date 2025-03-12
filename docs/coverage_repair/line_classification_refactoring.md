# Line Classification Refactoring

## Overview

This document describes the refactoring of line classification responsibility in the coverage module.

## Problem Statement

The responsibility for classifying lines as executable or non-executable was split between two components:

1. **debug_hook.lua**: Contained its own logic to determine if a line is executable, falling back to static_analyzer only in some cases.
2. **static_analyzer.lua**: Had sophisticated line classification but was not the exclusive source of truth.

This duplication created several issues:
- Potential inconsistencies in line classification
- Maintenance burden when fixing bugs or making improvements
- Violation of the Single Responsibility Principle
- Difficulty in understanding the code flow

## Solution Approach

The solution was to consolidate all line classification responsibility into the static_analyzer.lua component and have debug_hook.lua delegate to it. This enforces a clear separation of concerns:

- **static_analyzer.lua**: Responsible for all line classification through AST analysis and code parsing
- **debug_hook.lua**: Responsible for execution tracking but delegates classification decisions

## Implementation Details

### Changes to debug_hook.lua

1. Removed local line classification logic from the `is_line_executable` function
2. Updated the function to delegate all classification to static_analyzer
3. Modified the code to use a new fallback function for cases without a code map
4. Removed direct line classification code in the debug hook function

### Changes to static_analyzer.lua

1. Added a new `classify_line_simple` function that can classify a line without requiring a full code map
2. This function provides consistent classification even when full static analysis is not available
3. Ensures the static_analyzer module is the single source of truth for line classification

### Documentation Updates

1. Updated interfaces.md to document the new `classify_line_simple` function
2. Updated component_responsibilities.md to reflect the consolidated responsibility
3. Updated phase1_progress.md to mark line classification isolation as complete
4. Added this document to provide detailed information about the refactoring

## Benefits

1. **Single Source of Truth**: All line classification logic is now in one place
2. **Improved Maintainability**: Changes to classification only need to be made in static_analyzer.lua
3. **Clearer Responsibilities**: Each component has well-defined responsibilities
4. **Better Interface**: The interface between components is now cleaner and more explicit
5. **Future Extensibility**: Easier to enhance line classification in the future

## Next Steps

With line classification properly isolated to the static_analyzer component, we can now move on to addressing the remaining areas of responsibility overlap:

1. File Data Initialization (coverage init vs debug_hook)
2. Block Tracking (coverage init vs debug_hook)
3. Multiline Comments (patchup vs coverage init)

These improvements will continue the process of creating cleaner component boundaries and more maintainable code.
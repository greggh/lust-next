# Debug Code Inventory

This document provides an inventory of temporary debugging code, development comments, and other artifacts that need to be removed or refactored.

## Purpose

The purpose of this document is to track all instances of temporary debug code, "CRITICAL FIX" comments, print statements, and other development artifacts across the coverage module. This inventory ensures all temporary code is identified and properly addressed during the cleanup phase.

## Inventory by File

### 1. lib/coverage/init.lua

| Line(s)    | Description                                 | Type             | Action                                   |
|------------|---------------------------------------------|------------------|------------------------------------------|
| 336        | Comment: "CRITICAL FIX: Do NOT mark non-executable lines as covered at initialization" | Critical Fix Comment | Keep as documentation but standardize format |
| 919-926    | Debug output for special filenames          | Debug Print      | Replace with structured logging via logger.debug |
| 949-969    | Verbose test file logging block             | Debug Print      | Replace with structured logging via logger.trace |
| 1014       | Comment: "CRITICAL FIX: Only count as executable if it's been marked executable by static analysis" | Critical Fix Comment | Keep as documentation but standardize format |
| 1020       | Comment: "For lines inside multiline comments: CRITICAL FIX: Definitely remove any coverage marking" | Critical Fix Comment | Keep as documentation but standardize format |
| 1332-1339  | Debug printing for test files in verbose mode | Debug Print    | Replace with structured logging via logger.trace |
| 1661-1740  | `debug_dump()` function                      | Debug Function   | Refactor to fully use structured logging with proper context parameters |

### 2. lib/coverage/debug_hook.lua

| Line(s)    | Description                                 | Type             | Action                                   |
|------------|---------------------------------------------|------------------|------------------------------------------|
| 114-122    | Test file verbose logging                   | Debug Print      | Replace with structured logging via logger.verbose |
| 209-212    | Self-tracking debug output                  | Debug Print      | Use structured logging with standardized parameter table |
| 237        | Debug print line for file initialization    | Debug Print      | Replace with structured logging with standardized parameters |
| 259        | Debug print for code map generation         | Debug Print      | Replace with structured logging with standardized parameters |
| 265-267    | Debug file identification                   | Debug Print      | Replace with standardized file pattern filtering and structured logging |
| 270-272    | Verbose test file output                    | Debug Print      | Replace with structured logger.verbose call |
| 310-313    | More verbose conditional logging            | Debug Print      | Replace with structured logging via logger.verbose |
| 324-326    | Another verbose test file output block      | Debug Print      | Replace with structured logging with standardized parameters |
| 335-337    | More verbose debugging for non-executable lines | Debug Print  | Replace with structured logging call |

### 3. lib/coverage/static_analyzer.lua

| Line(s)    | Description                                 | Type             | Action                                   |
|------------|---------------------------------------------|------------------|------------------------------------------|
| 98-101     | Debug print for skipping large files        | Debug Print      | Replace with structured logging with file size parameters |
| 124-126    | Debug print for skipping large content      | Debug Print      | Replace with structured logging with content size parameters |
| 146-149    | Debug print for skipping nested files       | Debug Print      | Replace with structured logging with nesting depth parameter |
| 312-314    | Node limit warning                          | Debug Print      | Replace with structured logging with appropriate context |
| 315-318    | Time limit warning                          | Debug Print      | Replace with structured logging with timing information |
| 924        | Debug error output in collect_nodes         | Debug Print      | Replace with structured logging with error context |
| 928-931    | Debug error output                          | Debug Print      | Replace with structured logging with error context |
| 952-955    | Error in function finding                   | Debug Print      | Replace with structured logging with error context |
| 975-978    | Error in find_blocks                        | Debug Print      | Replace with structured logging with error context |
| 1370-1371  | Debug warning about no executable lines     | Debug Print      | Replace with structured logging with file context |
| 1373-1407  | Emergency fallback code block               | Debug Code       | Refactor into dedicated method with proper error handling and structured logging |
| 1362-1366  | Detailed information logging                | Debug Print      | Replace with structured logging with timing and file parameters |

### 4. lib/coverage/patchup.lua

| Line(s)    | Description                                 | Type             | Action                                   |
|------------|---------------------------------------------|------------------|------------------------------------------|
| 187-192    | Debug trace for removing incorrect coverage | Debug Print      | Replace with structured logging with standardized parameters |
| 334-337    | Trace log for removing coverage             | Debug Print      | Replace with structured logging with standardized parameters |
| 340-345    | Trace log for removing coverage             | Debug Print      | Replace with structured logging with standardized parameters |

### 5. lib/coverage/file_manager.lua

No specific debug code to remove, but could benefit from standardized structured logging patterns.

### 6. lib/coverage/instrumentation.lua

No specific debug code to remove, already using structured logging appropriately.

## Summary of Recommended Actions

1. **Replace Print Statements (Priority: High)**
   - Replace all direct print statements with structured logging
   - Use appropriate log levels (debug, trace, verbose)
   - Include standardized parameter tables for context

2. **Standardize Critical Fix Comments (Priority: Medium)**
   - Keep important implementation notes but standardize format
   - Consider extracting to separate documentation with code references
   - Use consistent annotation style

3. **Refactor Debug Functions (Priority: High)**
   - Completely refactor debug_dump() function to use structured logging
   - Remove direct console output in favor of standardized logging patterns
   - Extract standalone debug blocks into properly documented utility functions

4. **Remove Special Case Debugging (Priority: Medium)**
   - Normalize special filename checks with standard patterns
   - Create consistent conditional logging approach
   - Use standardized parameter tables for all log messages

5. **Improve Error Handling (Priority: High)**
   - Implement consistent error reporting patterns
   - Include appropriate context in all error logging
   - Ensure errors are properly propagated

6. **Extract Emergency Fallback Code (Priority: Medium)**
   - Move emergency fallback code to dedicated, well-documented functions
   - Add comprehensive error handling
   - Use structured logging for fallback path execution

## Progress Tracking

| File                       | Total Items | Completed | Remaining |
|----------------------------|-------------|-----------|-----------|
| init.lua                   | 7           | 7         | 0         |
| debug_hook.lua             | 9           | 9         | 0         |
| static_analyzer.lua        | 12          | 12        | 0         |
| patchup.lua                | 3           | 3         | 0         |
| file_manager.lua           | 0           | 0         | 0         |
| instrumentation.lua        | 0           | 0         | 0         |
| **Total**                  | **31**      | **31**    | **0**     |

Last updated: 2025-04-06

## Completed Items

### init.lua
1. Refactored `debug_dump()` function to use structured logging (lines 1661-1740)
2. Updated verbose test file logging block to use structured logging (lines 949-969)
3. Improved debug output for special filenames using structured parameters (lines 919-926)
4. Enhanced multiline comments debugging to use structured logging (lines 891-898)
5. Updated function debug trace logs to use structured parameters and proper logging checks (lines 1176-1184)
6. Improved file statistics verbose logging to use structured parameters (lines 1295-1320)
7. Standardized "CRITICAL FIX" comments to use "[IMPORTANT]" format with clearer explanations

### debug_hook.lua
1. Updated verbose test file logging to use structured parameters (lines 114-122)
2. Enhanced self-tracking debug output with structured parameters (lines 209-212)
3. Improved file initialization debug message with structured logging (line 237)
4. Enhanced code map generation debug output with detailed parameters (line 259)
5. Improved test file debugging output with structured parameters (lines 283-289)
6. Updated execution tracking logging with structured parameters (lines 325-333)
7. Improved executable/non-executable line debug logging (lines 344-350, 358-366)
8. Enhanced error handling with structured context parameters (lines 621-626, 770-775)
9. Updated function tracking verbose logging with structured parameters (lines 742-750, 761-769)

### static_analyzer.lua
1. Converted file size check debug logging to use structured parameters (lines 98-101)
2. Enhanced content size check debug output with structured parameters (lines 124-126)
3. Improved deeply nested file debug logging with contextual information (lines 146-149)
4. Updated node limit warning with proper parameter structure (lines 312-314)
5. Enhanced time limit warning with detailed timing information (lines 315-318)
6. Converted node collection limit output to use structured logging (lines 468-471)
7. Updated block finding limit messages with contextual parameters (lines 622-625)
8. Improved condition finding debug output with structured parameters (lines 812-815)
9. Refactored error handling in collect_nodes with parameter-based logging (lines 924-928)
10. Enhanced error output in find_functions with proper context (lines 952-955)
11. Improved error reporting in find_blocks with structured parameters (lines 975-978)
12. Extracted emergency fallback code into dedicated function with proper logging (lines 1373-1407)

### patchup.lua
1. Debug trace for removing incorrect coverage already uses proper structured logging with parameter tables (lines 187-192)
2. Trace log for removing coverage from comments uses structured parameters (lines 334-337)
3. Trace log for removing coverage from non-executable structures uses parameter tables (lines 340-345)

### Test Files
1. Fixed all print statements in 35 test files with structured logging using parameter tables (2025-04-05)
2. Fixed file path handling in all test files, replacing direct string concatenation with fs.join_paths (2025-04-05)
3. Added proper error handling with contextual information in all test files (2025-04-05)

### Example Files
1. Updated basic_example.lua to replace print statements with structured logging (2025-04-06)
2. Updated assertions_example.lua to remove print statements and package.path modification (2025-04-06)
3. Fixed watch_mode_example.lua to replace print statements with structured logging and remove hardcoded paths (2025-04-06)

### Documentation
1. Updated getting-started.md to reflect proper test running practices (2025-04-06)
2. Enhanced hook usage documentation to show structured logging for debugging (2025-04-06)
3. Updated command examples for running tests with proper scripts (2025-04-06)
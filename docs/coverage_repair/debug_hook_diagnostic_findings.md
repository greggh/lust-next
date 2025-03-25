# Debug Hook Diagnostic Findings

## Summary of Issues

Our diagnostic testing has revealed several critical issues with the coverage debug hook system:

1. **Line Execution Tracking Failure**: The debug hook is not correctly recording executed lines
2. **Block Structure Detection Failure**: Block structures are not being detected
3. **Empty Data Structures**: Key data structures exist but remain empty

## Detailed Findings

### Line Execution Tracking

* File tracking works correctly (files are added to coverage_data.files)
* Debug hook appears to be registered successfully in 'clr' mode
* No lines are marked as executed despite verified execution
* The _executed_lines table exists but remains empty
* The _execution_counts table exists but remains empty
* The was_line_executed() function always returns false

### Block Structure Detection

* No blocks are detected despite clear block structure in test code
* file_data.blocks appears to be nil or empty
* Static analyzer is being used (use_static_analysis = true) but not detecting blocks

### Data Structure Issues

* Lines data structure appears to be table-based rather than boolean (good)
* However, the lines table is completely empty
* No line information exists at all (tables, counts, etc.)

## Root Causes Analysis

Based on the diagnostic results, the most likely root causes are:

1. **Debug Hook Not Firing**: The debug hook may be registered but not actually firing on line events
2. **Hook Registration Issues**: The hook mode ('clr') may not be correctly set or the hook function isn't called
3. **Path Normalization Conflicts**: File paths may be inconsistent across different modules
4. **Data Structure Initialization**: Data structures are created but never populated

## Recommended Fixes

### Phase 1: Fix Debug Hook Line Tracking (Critical)

1. **Debug Hook Registration Check**:
   ```lua
   -- In debug_hook.lua
   function M.debug_hook_wrapper(event, line)
     -- Add immediate logging on each hook call
     logger.trace("Debug hook fired", {
       event = event,
       line = line,
       info = debug.getinfo(2, "S")
     })
     
     -- Rest of the hook logic
   end
   ```

2. **Line Tracking Fix**:
   ```lua
   -- In debug_hook.lua's debug hook function
   if event == "line" then
     -- Get source information
     local info = debug.getinfo(2, "S")
     if info and info.source and info.source:sub(1, 1) == "@" then
       local file_path = info.source:sub(2)
       
       -- Normalize the path (possible issue point)
       file_path = fs.normalize_path(file_path)
       
       -- Check if we should track this file (add logging)
       logger.trace("Processing line event", {
         file_path = file_path, 
         line = line,
         should_track = M.should_track_file(file_path)
       })
       
       -- Track the line if file should be tracked
       if M.should_track_file(file_path) then
         -- Ensure file data is initialized
         M.initialize_file(file_path)
         
         -- Track the line execution (possible issue point)
         local file_data = coverage_data.files[file_path]
         if file_data then
           -- Ensure _executed_lines exists
           file_data._executed_lines = file_data._executed_lines or {}
           file_data._execution_counts = file_data._execution_counts or {}
           
           -- Mark line as executed
           file_data._executed_lines[line] = true
           
           -- Increment execution count
           file_data._execution_counts[line] = (file_data._execution_counts[line] or 0) + 1
           
           logger.trace("Tracked line execution", {
             file_path = file_path,
             line = line,
             count = file_data._execution_counts[line]
           })
         end
       end
     end
   end
   ```

3. **Explicit Hook Registration Verification**:
   ```lua
   -- After setting the hook, verify it's registered
   function M.start()
     -- Register the debug hook
     debug.sethook(M.debug_hook_wrapper, "clr") 
     
     -- Verify hook registration
     local hook_fn, hook_mask = debug.gethook()
     logger.info("Debug hook registration verified", {
       hook_installed = hook_fn ~= nil,
       hook_mask = hook_mask
     })
     
     -- Set module state
     M._initialized = true
     M._hook_mode = "clr"
   end
   ```

### Phase 2: Fix Block Detection (Important)

1. **Verify Static Analyzer Loading**:
   ```lua
   function M.initialize_file(file_path)
     -- Ensure file path is normalized
     file_path = fs.normalize_path(file_path)
     
     -- Initialize if not already done
     if not coverage_data.files[file_path] then
       coverage_data.files[file_path] = {
         _executed_lines = {},
         _execution_counts = {},
         lines = {},
         blocks = {}
       }
       
       -- Load static analyzer if not already loaded
       if not static_analyzer and config.use_static_analysis then
         local success, module = pcall(require, "lib.coverage.static_analyzer")
         if success then
           static_analyzer = module
           logger.debug("Static analyzer loaded for block detection")
         else
           logger.warn("Failed to load static analyzer", { error = tostring(module) })
         end
       end
       
       -- If static analyzer is available, use it to analyze the file
       if static_analyzer and config.use_static_analysis then
         local file_content = fs.read_file(file_path)
         if file_content then
           -- Add explicit logging for blocks
           logger.debug("Running static analysis for block detection", { file_path = file_path })
           
           local analysis = static_analyzer.analyze_file(file_path, file_content)
           if analysis and analysis.blocks then
             logger.debug("Block analysis complete", { 
               file_path = file_path,
               block_count = #analysis.blocks
             })
             
             -- Store block information
             coverage_data.files[file_path].blocks = analysis.blocks
           else
             logger.warn("No blocks detected in file", { file_path = file_path })
           end
         end
       end
     end
     
     return coverage_data.files[file_path]
   end
   ```

## Implementation Plan

1. **Debug Hook Investigation**:
   - Add comprehensive logging to the debug hook function
   - Verify hook registration and activation
   - Fix the line tracking logic to properly record executions

2. **Static Analyzer Investigation**:
   - Verify the static analyzer is loading correctly
   - Fix block detection in static analyzer
   - Ensure block information is correctly passed to coverage data

3. **Data Structure Consistency**:
   - Ensure consistent line data structure (tables, not booleans)
   - Properly initialize all data structures
   - Fix path normalization issues across modules

4. **Validation**:
   - Create targeted tests for each component
   - Verify line tracking accuracy
   - Validate block structure detection
   - Check data structure consistency

This systematic approach should address the root issues in the coverage system, starting with the most fundamental (line tracking) before moving to more advanced features (block detection).
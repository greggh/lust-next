-- Core debug hook implementation
local M = {}
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
-- Error handler is a required module for proper error handling throughout the codebase
local error_handler = require("lib.tools.error_handler")
local static_analyzer -- Lazily loaded when used
local config = {}
local tracked_files = {}
local active_files = {} -- Keep track of files that should be included in reporting
local processing_hook = false -- Flag to prevent recursive hook calls
local coverage_data = {
  files = {},
  lines = {},
  functions = {},
  blocks = {},      -- Block tracking
  conditions = {}   -- Condition tracking
}

-- Create a logger for this module
local logger = logging.get_logger("CoverageHook")

-- Should we track this file?
function M.should_track_file(file_path)
  -- Safely normalize file path
  local normalized_path, err = error_handler.safe_io_operation(
    function() return fs.normalize_path(file_path) end,
    file_path,
    {operation = "debug_hook.should_track_file"}
  )
  
  if not normalized_path then
    logger.debug("Failed to normalize path: " .. error_handler.format_error(err), {
      file_path = file_path,
      operation = "should_track_file"
    })
    return false
  end
  
  -- Quick lookup for already-decided files
  if tracked_files[normalized_path] ~= nil then
    return tracked_files[normalized_path]
  end
  
  -- Special case for example files (always track them)
  if config.should_track_example_files and normalized_path:match("/examples/") then
    tracked_files[normalized_path] = true
    return true
  end
  
  -- Apply exclude patterns (fast reject) with error handling
  for _, pattern in ipairs(config.exclude or {}) do
    local success, matches, err = error_handler.try(function()
      return fs.matches_pattern(normalized_path, pattern)
    end)
    
    if not success then
      logger.debug("Pattern matching error: " .. error_handler.format_error(matches), {
        file_path = normalized_path,
        pattern = pattern,
        operation = "should_track_file.exclude"
      })
      goto continue_exclude
    end
    
    if matches then
      tracked_files[normalized_path] = false
      return false
    end
    
    ::continue_exclude::
  end
  
  -- Apply include patterns with error handling
  for _, pattern in ipairs(config.include or {}) do
    local success, matches, err = error_handler.try(function()
      return fs.matches_pattern(normalized_path, pattern)
    end)
    
    if not success then
      logger.debug("Pattern matching error: " .. error_handler.format_error(matches), {
        file_path = normalized_path,
        pattern = pattern,
        operation = "should_track_file.include"
      })
      goto continue_include
    end
    
    if matches then
      tracked_files[normalized_path] = true
      return true
    end
    
    ::continue_include::
  end
  
  -- Check source directories
  for _, dir in ipairs(config.source_dirs or {"."}) do
    local normalized_dir = fs.normalize_path(dir)
    if normalized_path:sub(1, #normalized_dir) == normalized_dir then
      tracked_files[normalized_path] = true
      return true
    end
  end
  
  -- Default decision based on file extension
  local is_lua = normalized_path:match("%.lua$") ~= nil
  tracked_files[normalized_path] = is_lua
  return is_lua
end

-- Initialize tracking for a file - exposed as public API for other components to use
function M.initialize_file(file_path, options)
  local normalized_path = fs.normalize_path(file_path)
  options = options or {}
  
  -- Skip if already initialized and not forced
  if coverage_data.files[normalized_path] and not options.force then
    return coverage_data.files[normalized_path]
  end
  
  -- Count lines in file and store them as an array
  local line_count = 0
  local source_text = options.source_text or fs.read_file(file_path)
  local source_lines = {}
  
  if source_text then
    for line in (source_text .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
      line_count = line_count + 1
      source_lines[line_count] = line
    end
  end
  
  -- Create or update file data
  coverage_data.files[normalized_path] = {
    lines = options.lines or {},                      -- Lines validated by tests (covered)
    _executed_lines = options._executed_lines or {},  -- All executed lines (execution tracking)
    functions = options.functions or {},              -- Function execution tracking
    line_count = line_count,
    source = source_lines,
    source_text = source_text,
    executable_lines = options.executable_lines or {}, -- Whether each line is executable
    logical_chunks = options.logical_chunks or {},     -- Store code blocks information
    code_map = options.code_map,                       -- Static analysis code map if available
    ast = options.ast,                                 -- AST if available
    discovered = options.discovered                    -- Whether this file was discovered rather than executed
  }
  
  if logger.is_debug_enabled() then
    logger.debug({
      message = "Initialized file for tracking",
      file_path = normalized_path,
      operation = "initialize_file",
      source = options.source_text and "provided_content" or "filesystem"
    })
  end
  
  return coverage_data.files[normalized_path]
end

-- Private function for internal use that calls the public API
local function initialize_file(file_path)
  return M.initialize_file(file_path)
end

-- Check if a line is executable in a file - delegated to static_analyzer
local function is_line_executable(file_path, line)
  -- Ensure static_analyzer is loaded
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Check if we have static analysis data for this file
  local normalized_path = fs.normalize_path(file_path)
  local file_data = coverage_data.files[normalized_path]
  
  if file_data and file_data.code_map then
    -- Use existing static analysis data
    local is_exec = static_analyzer.is_line_executable(file_data.code_map, line)
    
    -- Verbose output for specific test files
    if config.verbose and file_path:match("examples/minimal_coverage.lua") and logger.is_verbose_enabled() then
      local line_type = "unknown"
      if file_data.code_map.lines and file_data.code_map.lines[line] then
        line_type = file_data.code_map.lines[line].type or "unknown"
      end
      
      logger.verbose("Line classification", {
        file_path = file_path,
        line = line,
        executable = is_exec,
        type = line_type,
        source = "static_analyzer.is_line_executable"
      })
    end
    
    return is_exec
  end
  
  -- If we don't have a code map but we have the source text, try to obtain one
  -- via the static analyzer on-demand
  if file_data and file_data.source_text and not file_data.code_map_attempted then
    file_data.code_map_attempted = true -- Mark that we've tried to get a code map
    
    -- Try to parse the source and get a code map
    local ast, code_map = static_analyzer.parse_content(file_data.source_text, file_path)
    if ast and code_map then
      file_data.code_map = code_map
      file_data.ast = ast
      
      -- Now that we have a code map, we can check if the line is executable
      return static_analyzer.is_line_executable(code_map, line)
    end
  end
  
  -- If we can't generate a code map, ask static_analyzer for a simple line classification
  return static_analyzer.classify_line_simple(file_data and file_data.source[line], config)
end

-- Debug hook function with optimizations
function M.debug_hook(event, line)
  -- Original hook with optimizations
  -- Skip if we're already processing a hook to prevent recursion
  if processing_hook then
    return
  end
  
  -- Skip if the line is missing, negative, or zero (special internal Lua events)
  if not line or line <= 0 then
    return
  end
  
  -- Set flag to prevent recursion
  processing_hook = true
  
  -- Main hook logic with protected call
  local success, result, err = error_handler.try(function()
    if event == "line" then
      local info = debug.getinfo(2, "S")
      if not info or not info.source or info.source:sub(1, 1) ~= "@" then
        processing_hook = false
        return
      end
      
      local file_path = info.source:sub(2)  -- Remove @ prefix
      
      -- Identify coverage module files and test files for special handling
      local is_coverage_file = file_path:find("lib/coverage", 1, true) or 
                              file_path:find("lib/tools/parser", 1, true) or
                              file_path:find("lib/tools/vendor", 1, true)
                              
      -- Identify test files for special handling
      local is_test_file = file_path:match("_test%.lua$") or 
                           file_path:match("_spec%.lua$") or
                           file_path:match("/tests/") or
                           file_path:match("/test/") or
                           file_path:match("test_.*%.lua$")
      
      -- Special handling for coverage module and test files
      if is_coverage_file or is_test_file then
        -- Always record execution data for self-coverage regardless of config
        -- This helps us see what parts of the coverage system itself are running
        local normalized_path = fs.normalize_path(file_path)
        
        -- Initialize file data if not already done
        if not coverage_data.files[normalized_path] then
          initialize_file(file_path)
        end
        
        -- Record raw execution data without counting it for coverage metrics
        if coverage_data.files[normalized_path] then
          -- Track execution for visualization purposes
          coverage_data.files[normalized_path]._executed_lines = coverage_data.files[normalized_path]._executed_lines or {}
          coverage_data.files[normalized_path]._executed_lines[line] = true
          
          -- Mark as executable but not covered (for proper display)
          coverage_data.files[normalized_path].executable_lines = coverage_data.files[normalized_path].executable_lines or {}
          coverage_data.files[normalized_path].executable_lines[line] = true
          
          -- Debug output for specific self-coverage files if debug is enabled
          if file_path:match("examples/execution_vs_coverage") and logger.is_debug_enabled() then
            logger.debug("Self-tracking execution", {
              file = normalized_path:match("([^/]+)$") or normalized_path,
              line = line,
              type = "coverage_module"
            })
          end
        end
        
        -- Don't continue with normal coverage processing to avoid recursion
        processing_hook = false
        return
      end
      
      -- Check cached tracked_files first for performance
      local should_track = tracked_files[file_path]
      
      -- If not in cache, determine if we should track
      if should_track == nil then
        should_track = M.should_track_file(file_path)
      end
      
      if should_track then
        local normalized_path = fs.normalize_path(file_path)
        
        -- Initialize file data if needed - use coverage_data.files directly
        if not coverage_data.files[normalized_path] then
          initialize_file(file_path)
          
          -- Debug output for file initialization 
          logger.debug("Initialized file for tracking", {
            file_path = normalized_path
          })
          
          -- Proactively try to get a code map using the static analyzer
          -- This ensures more accurate line classification early on
          if not static_analyzer then
            static_analyzer = require("lib.coverage.static_analyzer")
          end
          
          if coverage_data.files[normalized_path].source_text then
            local ast, code_map = static_analyzer.parse_content(
              coverage_data.files[normalized_path].source_text, 
              file_path
            )
            
            if ast and code_map then
              coverage_data.files[normalized_path].code_map = code_map
              coverage_data.files[normalized_path].ast = ast
              coverage_data.files[normalized_path].code_map_attempted = true
              
              -- Get executable lines map
              coverage_data.files[normalized_path].executable_lines = 
                static_analyzer.get_executable_lines(code_map)
              
              logger.debug("Generated code map", {
                file_path = normalized_path,
                has_blocks = code_map.blocks ~= nil,
                has_functions = code_map.functions ~= nil
              })
            end
          end
        end
        
        -- Identify special test files that need detailed logging
        local is_debug_file = file_path:match("examples/minimal_coverage.lua") or
                              file_path:match("examples/simple_multiline_comment_test.lua") or
                              file_path:match("validator_coverage_test.lua")
        
        -- Verbose output for test files
        if config.verbose and is_debug_file and logger.is_verbose_enabled() then
          logger.verbose("Line execution detected", {
            file_path = file_path,
            line = line,
            component = "debug_hook"
          })
        end
        
        -- Track line with minimum operations
        if coverage_data.files[normalized_path] then
          -- Initialize lines table if it doesn't exist
          if not coverage_data.files[normalized_path].lines then
            coverage_data.files[normalized_path].lines = {}
          end
          
          -- Initialize executable_lines table if it doesn't exist
          if not coverage_data.files[normalized_path].executable_lines then
            coverage_data.files[normalized_path].executable_lines = {}
          end
          
          -- Check if this line is executable BEFORE marking it as covered
          local is_executable = is_line_executable(file_path, line)
          
          -- Always track all executed lines regardless of executability
          -- This provides a ground truth of which lines were actually executed
          coverage_data.files[normalized_path]._executed_lines = coverage_data.files[normalized_path]._executed_lines or {}
          coverage_data.files[normalized_path]._executed_lines[line] = true
          
          -- Verbose output for execution tracking
          -- Only log for example files or test files
          if config.verbose and (file_path:match("example") or file_path:match("test")) and logger.is_verbose_enabled() then
            logger.verbose("Detected line execution", {
              file_path = normalized_path:match("([^/]+)$") or normalized_path,
              line = line,
              file_type = file_path:match("example") and "example" or "test"
            })
          end
          
          -- Only mark executable lines as covered in the main coverage tracking
          if is_executable then
            -- Mark this line as covered - this is the key line that sets coverage
            coverage_data.files[normalized_path].lines[line] = true
            
            -- Also mark this as executable
            coverage_data.files[normalized_path].executable_lines[line] = true
            
            -- Verbose output for test files
            if config.verbose and is_debug_file and logger.is_verbose_enabled() then
              logger.verbose("Line tracked as covered and executable", {
                file_path = file_path,
                line = line,
                state = "covered_executable"
              })
            end
          else
            -- DO NOT mark non-executable lines as covered
            -- This is key to fixing the coverage issue
            
            -- Make sure to mark it explicitly as non-executable
            coverage_data.files[normalized_path].executable_lines[line] = false
            
            -- Verbose output for non-executable lines
            if config.verbose and is_debug_file and logger.is_verbose_enabled() then
              logger.verbose("Line tracked but not counted", {
                file_path = file_path,
                line = line,
                state = "executed_non_executable",
                reason = "non-executable line"
              })
            end
          end
          
          -- Track in global map for all executed lines when debugging
          if config.debug then
            coverage_data.lines[normalized_path .. ":" .. line] = true
          end
          
          -- Track block coverage if static analyzer is available and tracking is enabled
          if config.track_blocks then
            -- Generate code map on-demand if we don't have one yet
            if not coverage_data.files[normalized_path].code_map and 
               coverage_data.files[normalized_path].source_text and
               not coverage_data.files[normalized_path].code_map_attempted then
              
              -- Lazily load the static analyzer
              if not static_analyzer then
                static_analyzer = require("lib.coverage.static_analyzer")
              end
              
              -- Try to generate code map
              local ast, code_map = static_analyzer.parse_content(
                coverage_data.files[normalized_path].source_text,
                file_path
              )
              
              if ast and code_map then
                coverage_data.files[normalized_path].code_map = code_map
                coverage_data.files[normalized_path].ast = ast
                
                logger.debug("Generated code map on-demand", {
                  file_path = normalized_path,
                  has_blocks = code_map.blocks ~= nil,
                  has_functions = code_map.functions ~= nil
                })
              end
              
              -- Mark that we tried, regardless of success
              coverage_data.files[normalized_path].code_map_attempted = true
            end
            
            -- Only track blocks if we have a code map
            if coverage_data.files[normalized_path].code_map and config.track_blocks then
              -- Use our own public API for tracking blocks
              -- This ensures consistent block tracking logic
              local tracked_blocks = M.track_blocks_for_line(file_path, line)
              
              -- Verbose output for block tracking
              if tracked_blocks and #tracked_blocks > 0 and config.verbose and logger.is_verbose_enabled() then
                logger.verbose("Tracked blocks in debug hook", {
                  count = #tracked_blocks,
                  line = line,
                  file_path = normalized_path,
                  operation = "debug_hook"
                })
              end
            end
            
            -- Legacy code for backward compatibility - TO BE REMOVED
            if false and coverage_data.files[normalized_path].code_map then
              -- Initialize logical_chunks if it doesn't exist
              if not coverage_data.files[normalized_path].logical_chunks then
                coverage_data.files[normalized_path].logical_chunks = {}
              end
              
              -- Mark each block as executed
              for _, block in ipairs({}) do
                -- Get or create block record
                local block_copy = coverage_data.files[normalized_path].logical_chunks[block.id]
                
                if not block_copy then
                  -- Create a new deep copy if this is the first time we've seen this block
                  block_copy = {
                    id = block.id,
                    type = block.type,
                    start_line = block.start_line,
                    end_line = block.end_line,
                    parent_id = block.parent_id,
                    branches = {},
                    executed = true, -- Mark as executed immediately
                    execution_count = 1 -- Track execution count
                  }
                  
                  -- Copy branches array if it exists
                  if block.branches then
                    for _, branch_id in ipairs(block.branches) do
                      table.insert(block_copy.branches, branch_id)
                    end
                  end
                else
                  -- Update existing block record
                  block_copy.executed = true
                  block_copy.execution_count = (block_copy.execution_count or 0) + 1
                end
                
                -- Store the block in our logical_chunks
                coverage_data.files[normalized_path].logical_chunks[block.id] = block_copy
                
                -- Also track the block in the global blocks table for reference
                coverage_data.blocks[normalized_path .. ":" .. block.id] = true
                
                -- Update parent blocks - ensures parent blocks are marked as executed
                if block_copy.parent_id and block_copy.parent_id ~= "root" then
                  local parent_block = coverage_data.files[normalized_path].logical_chunks[block_copy.parent_id]
                  if parent_block then
                    parent_block.executed = true
                    parent_block.execution_count = (parent_block.execution_count or 0) + 1
                  end
                end
                
                -- Verbose output for block execution
                if config.verbose and logger.is_verbose_enabled() then
                  logger.verbose("Executed block", {
                    block_id = block.id,
                    type = block.type,
                    line = line,
                    file_path = normalized_path,
                    execution_count = block_copy.execution_count or 1,
                    parent_id = block.parent_id
                  })
                end
              end
              
              -- Legacy code ends
                
              -- Track condition coverage for this line
              local conditions_for_line = static_analyzer.get_conditions_for_line(
                coverage_data.files[normalized_path].code_map,
                line
              )
              
              -- Initialize logical_conditions if it doesn't exist
              if not coverage_data.files[normalized_path].logical_conditions then
                coverage_data.files[normalized_path].logical_conditions = {}
              end
              
              -- Mark each condition as executed
              for _, condition in ipairs(conditions_for_line) do
                -- Get or create condition record
                local condition_copy = coverage_data.files[normalized_path].logical_conditions[condition.id]
                
                if not condition_copy then
                  condition_copy = {
                    id = condition.id,
                    type = condition.type,
                    start_line = condition.start_line,
                    end_line = condition.end_line,
                    parent_id = condition.parent_id,
                    executed = true,
                    executed_true = false,
                    executed_false = false,
                    execution_count = 1
                  }
                else
                  condition_copy.executed = true
                  condition_copy.execution_count = (condition_copy.execution_count or 0) + 1
                end
                
                -- Improved condition outcome detection
                if condition.type:match("if_condition") or condition.type:match("while_condition") then
                  -- Scan ahead to find the then/else parts
                  local then_body_start = condition.end_line + 1
                  local else_body_start = nil
                  
                  -- Scan a reasonable number of lines forward looking for else
                  local max_scan_lines = 20
                  local in_then_block = true
                  
                  for i = condition.end_line + 1, condition.end_line + max_scan_lines do
                    if coverage_data.files[normalized_path].source and 
                       coverage_data.files[normalized_path].source[i] then
                       
                      local line_text = coverage_data.files[normalized_path].source[i]
                      
                      -- If we find an else, record its position
                      if line_text:match("^%s*else%s*$") or 
                         line_text:match("^%s*elseif%s+") then
                        else_body_start = i + 1
                        in_then_block = false
                        break
                      end
                      
                      -- If we find an end, we've reached the end of the if block
                      if line_text:match("^%s*end%s*$") then
                        break
                      end
                    end
                  end
                  
                  -- Check for then branch execution (true outcome)
                  if coverage_data.files[normalized_path]._executed_lines[then_body_start] then
                    condition_copy.executed_true = true
                  end
                  
                  -- Check for else branch execution (false outcome)
                  if else_body_start and coverage_data.files[normalized_path]._executed_lines[else_body_start] then
                    condition_copy.executed_false = true
                  end
                end
                
                -- For conditions inside loop conditions, check for loop body execution
                if condition.type:match("while_condition") or condition.type:match("for_condition") then
                  local loop_body_start = condition.end_line + 1
                  
                  -- If the loop body is executed, the condition was true at least once
                  if coverage_data.files[normalized_path]._executed_lines[loop_body_start] then
                    condition_copy.executed_true = true
                  end
                  
                  -- Check for lines after the loop body to determine if the condition ever evaluated to false
                  -- This is a heuristic - if execution continues after the loop, the condition was false
                  if coverage_data.files[normalized_path]._executed_lines[condition.end_line + 10] then
                    condition_copy.executed_false = true
                  end
                end
                
                -- Update parent conditions if this is a sub-condition
                if condition.parent_id and condition.parent_id ~= "root" then
                  local parent_condition = coverage_data.files[normalized_path].logical_conditions[condition.parent_id]
                  if parent_condition then
                    parent_condition.executed = true
                    
                    -- If sub-condition was evaluated as true or false, propagate to parent
                    if condition_copy.executed_true then
                      parent_condition.executed_true = true
                    end
                    
                    if condition_copy.executed_false then
                      parent_condition.executed_false = true
                    end
                  end
                end
                
                -- Store the condition in our logical_conditions
                coverage_data.files[normalized_path].logical_conditions[condition.id] = condition_copy
                
                -- Also track in the global conditions table for reference
                coverage_data.conditions[normalized_path .. ":" .. condition.id] = true
                
                -- Verbose output for condition execution
                if config.verbose and logger.is_verbose_enabled() then
                  logger.verbose("Executed condition", {
                    condition_id = condition.id,
                    type = condition.type,
                    line = line,
                    file_path = normalized_path,
                    execution_count = condition_copy.execution_count or 1,
                    executed_true = condition_copy.executed_true or false,
                    executed_false = condition_copy.executed_false or false,
                    parent_id = condition.parent_id
                  })
                end
              end
            end
          end
        end
      end
    end
  end)
  
  -- Clear flag after processing
  processing_hook = false
  
  -- Report errors but don't crash
  if not success then
    logger.debug("Debug hook error", {
      error = error_handler.format_error(result),
      location = "debug_hook.line_hook"
    })
  end
  
  -- Handle call events
  if event == "call" then
    -- Skip if we're already processing a hook to prevent recursion
    if processing_hook then
      return
    end
    
    -- Set flag to prevent recursion
    processing_hook = true
    
    -- Main hook logic with protected call
    local success, result, err = error_handler.try(function()
      local info = debug.getinfo(2, "Sn")
      if not info or not info.source or info.source:sub(1, 1) ~= "@" then
        processing_hook = false
        return
      end
      
      local file_path = info.source:sub(2)
      
      -- Identify coverage module files and test files for special handling
      local is_coverage_file = file_path:find("lib/coverage", 1, true) or 
                              file_path:find("lib/tools/parser", 1, true) or
                              file_path:find("lib/tools/vendor", 1, true)
                              
      -- Identify test files for special handling
      local is_test_file = file_path:match("_test%.lua$") or 
                           file_path:match("_spec%.lua$") or
                           file_path:match("/tests/") or
                           file_path:match("/test/") or
                           file_path:match("test_.*%.lua$")
      
      -- Special handling for coverage module and test files
      if is_coverage_file or is_test_file then
        -- We still want to track function executions for visualization purposes
        local normalized_path = fs.normalize_path(file_path)
        
        -- Initialize file data if not already done
        if not coverage_data.files[normalized_path] then
          initialize_file(file_path)
        end
        
        -- Record function execution data for visualization only
        if coverage_data.files[normalized_path] and info.linedefined and info.linedefined > 0 then
          -- Create unique function key
          local func_key = info.linedefined .. ":function:" .. (info.name or "anonymous")
          local func_name = info.name or ("function_at_line_" .. info.linedefined)
          
          -- Track this function
          coverage_data.files[normalized_path].functions = coverage_data.files[normalized_path].functions or {}
          coverage_data.files[normalized_path].functions[func_key] = {
            name = func_name,
            line = info.linedefined,
            executed = true,
            calls = 1,
            dynamically_detected = true
          }
          
          -- Also mark function's lines as executed
          coverage_data.files[normalized_path]._executed_lines = coverage_data.files[normalized_path]._executed_lines or {}
          coverage_data.files[normalized_path]._executed_lines[info.linedefined] = true
        end
        
        -- Don't continue with normal coverage processing to avoid recursion
        processing_hook = false
        return
      end
      
      if M.should_track_file(file_path) then
        local normalized_path = fs.normalize_path(file_path)
        
        -- Initialize file data if needed
        if not coverage_data.files[normalized_path] then
          initialize_file(file_path)
        end
        
        -- IMPORTANT: Make sure we have a valid line number for the function
        if not info.linedefined or info.linedefined <= 0 then
          processing_hook = false
          return
        end
        
        -- Create unique function key - include explicit type identifier for easier lookup
        local func_key = info.linedefined .. ":function:" .. (info.name or "anonymous")
        local func_name = info.name or ("function_at_line_" .. info.linedefined)
        
        -- Add additional information to help with debugging
        local func_info = {
          name = func_name,
          line = info.linedefined,
          executed = true, -- Mark as executed immediately
          calls = 1,
          dynamically_detected = true,
          name_from_debug = info.name, -- Store original name from debug.getinfo
          what = info.what,            -- Store function type (Lua, C, main)
          source = info.source         -- Store source information
        }
        
        -- Check if this function was already registered by static analysis
        -- More robust matching using line number as the primary key
        local found = false
        for existing_key, func_data in pairs(coverage_data.files[normalized_path].functions) do
          -- Match on line number since that's most reliable
          if func_data.line == info.linedefined then
            -- Function found, mark as executed
            coverage_data.files[normalized_path].functions[existing_key].executed = true
            coverage_data.files[normalized_path].functions[existing_key].calls = 
              (coverage_data.files[normalized_path].functions[existing_key].calls or 0) + 1
            found = true
            
            -- Use the existing key for global tracking
            coverage_data.functions[normalized_path .. ":" .. existing_key] = true
            
            -- Verbose output for function execution
            if config.verbose and logger.is_verbose_enabled() then
              logger.verbose("Executed function", {
                name = coverage_data.files[normalized_path].functions[existing_key].name,
                line = info.linedefined,
                file_path = normalized_path,
                calls = coverage_data.files[normalized_path].functions[existing_key].calls
              })
            end
            
            break
          end
        end
        
        -- If not found in registered functions, add it
        if not found then
          coverage_data.files[normalized_path].functions[func_key] = func_info
          coverage_data.functions[normalized_path .. ":" .. func_key] = true
          
          -- Verbose output for new functions
          if config.verbose and logger.is_verbose_enabled() then
            logger.verbose("Tracked new function", {
              name = func_name,
              line = info.linedefined,
              file_path = normalized_path,
              function_type = info.what or "unknown"
            })
          end
        end
      end
    end)
    
    -- Clear flag after processing
    processing_hook = false
    
    -- Report errors but don't crash
    if not success then
      logger.debug("Debug hook error", {
        error = error_handler.format_error(result),
        location = "debug_hook.call_hook"
      })
    end
  end
end

-- Set configuration
function M.set_config(new_config)
  config = new_config
  tracked_files = {}  -- Reset cached decisions
  
  -- Configure module logging level
  logging.configure_from_config("CoverageHook")
  
  return M
end

-- Coverage Data Accessor Functions --

-- Get entire coverage data (legacy function maintained for backward compatibility)
function M.get_coverage_data()
  return coverage_data
end

-- Get active files list
function M.get_active_files()
  return active_files
end

-- Get all files in coverage data
function M.get_files()
  return coverage_data.files
end

-- Get specific file data
function M.get_file_data(file_path)
  if not file_path then
    return nil
  end
  
  -- Normalize the file path for consistency
  local normalized_path = fs.normalize_path(file_path)
  if not normalized_path then
    normalized_path = file_path:gsub("//", "/"):gsub("\\", "/")
  end
  return coverage_data.files[normalized_path]
end

-- Check if file exists in coverage data
function M.has_file(file_path)
  local normalized_path = fs.normalize_path(file_path)
  return coverage_data.files[normalized_path] ~= nil
end

-- Mark a file as active for reporting
function M.activate_file(file_path)
  if not file_path then
    return false
  end
  
  -- Normalize the file path for consistency
  local normalized_path = fs.normalize_path(file_path)
  if not normalized_path then
    normalized_path = file_path:gsub("//", "/"):gsub("\\", "/")
  end
  
  -- Mark file as active
  active_files[normalized_path] = true
  
  -- Ensure file is initialized
  if not coverage_data.files[normalized_path] then
    M.initialize_file(normalized_path)
  end
  
  -- Mark as discovered
  if coverage_data.files[normalized_path] then
    coverage_data.files[normalized_path].discovered = true
    coverage_data.files[normalized_path].active = true
    
    -- Add debug log output
    logger.debug("File activated for coverage reporting", {
      file_path = normalized_path,
      discovered = true,
      active = true
    })
  end
  
  return true
end

-- Get file's source lines
function M.get_file_source(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil
  end
  return coverage_data.files[normalized_path].source
end

-- Get file's source text
function M.get_file_source_text(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil
  end
  return coverage_data.files[normalized_path].source_text
end

-- Get covered lines for a file
function M.get_file_covered_lines(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].lines or {}
end

-- Get executed lines for a file
function M.get_file_executed_lines(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path]._executed_lines or {}
end

-- Get executable lines for a file
function M.get_file_executable_lines(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].executable_lines or {}
end

-- Get function data for a file
function M.get_file_functions(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].functions or {}
end

-- Get logical chunks (blocks) for a file
function M.get_file_logical_chunks(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].logical_chunks or {}
end

-- Get logical conditions for a file
function M.get_file_logical_conditions(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].logical_conditions or {}
end

-- Get code map for a file
function M.get_file_code_map(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil
  end
  return coverage_data.files[normalized_path].code_map
end

-- Get AST for a file
function M.get_file_ast(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil
  end
  return coverage_data.files[normalized_path].ast
end

-- Get line count for a file
function M.get_file_line_count(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return 0
  end
  return coverage_data.files[normalized_path].line_count or 0
end

-- Set or update a covered line in a file
function M.set_line_covered(file_path, line_num, covered)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure lines table exists
  if not coverage_data.files[normalized_path].lines then
    coverage_data.files[normalized_path].lines = {}
  end
  
  -- Set the line coverage value
  if covered == nil then
    covered = true
  end
  
  coverage_data.files[normalized_path].lines[line_num] = covered
  
  -- Update global tracking
  if covered then
    coverage_data.lines[normalized_path .. ":" .. line_num] = true
  else
    coverage_data.lines[normalized_path .. ":" .. line_num] = nil
  end
  
  return covered
end

-- Set or update an executed line in a file
function M.set_line_executed(file_path, line_num, executed)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure _executed_lines table exists
  if not coverage_data.files[normalized_path]._executed_lines then
    coverage_data.files[normalized_path]._executed_lines = {}
  end
  
  -- Set the line execution value
  if executed == nil then
    executed = true
  end
  
  coverage_data.files[normalized_path]._executed_lines[line_num] = executed
  
  return executed
end

-- Set executable status for a line
function M.set_line_executable(file_path, line_num, executable)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure executable_lines table exists
  if not coverage_data.files[normalized_path].executable_lines then
    coverage_data.files[normalized_path].executable_lines = {}
  end
  
  -- Set the line executability value
  if executable == nil then
    executable = true
  end
  
  coverage_data.files[normalized_path].executable_lines[line_num] = executable
  
  return executable
end

-- Set a function's executed status
function M.set_function_executed(file_path, func_key, executed)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure functions table exists
  if not coverage_data.files[normalized_path].functions then
    coverage_data.files[normalized_path].functions = {}
  end
  
  -- Check if the function exists
  if not coverage_data.files[normalized_path].functions[func_key] then
    return false
  end
  
  -- Set the function execution value
  if executed == nil then
    executed = true
  end
  
  coverage_data.files[normalized_path].functions[func_key].executed = executed
  
  -- Update global tracking
  if executed then
    coverage_data.functions[normalized_path .. ":" .. func_key] = true
  else
    coverage_data.functions[normalized_path .. ":" .. func_key] = nil
  end
  
  return executed
end

-- Add a new function to the coverage data
function M.add_function(file_path, func_key, func_data)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure functions table exists
  if not coverage_data.files[normalized_path].functions then
    coverage_data.files[normalized_path].functions = {}
  end
  
  -- Add the function data
  coverage_data.files[normalized_path].functions[func_key] = func_data
  
  -- Update global tracking if executed
  if func_data.executed then
    coverage_data.functions[normalized_path .. ":" .. func_key] = true
  end
  
  return func_data
end

-- Set a block's executed status
function M.set_block_executed(file_path, block_id, executed)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure logical_chunks table exists
  if not coverage_data.files[normalized_path].logical_chunks then
    coverage_data.files[normalized_path].logical_chunks = {}
  end
  
  -- Check if the block exists
  if not coverage_data.files[normalized_path].logical_chunks[block_id] then
    return false
  end
  
  -- Set the block execution value
  if executed == nil then
    executed = true
  end
  
  coverage_data.files[normalized_path].logical_chunks[block_id].executed = executed
  
  -- Update global tracking
  if executed then
    coverage_data.blocks[normalized_path .. ":" .. block_id] = true
  else
    coverage_data.blocks[normalized_path .. ":" .. block_id] = nil
  end
  
  return executed
end

-- Add a new block to the coverage data
function M.add_block(file_path, block_id, block_data)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure logical_chunks table exists
  if not coverage_data.files[normalized_path].logical_chunks then
    coverage_data.files[normalized_path].logical_chunks = {}
  end
  
  -- Add the block data
  coverage_data.files[normalized_path].logical_chunks[block_id] = block_data
  
  -- Update global tracking if executed
  if block_data.executed then
    coverage_data.blocks[normalized_path .. ":" .. block_id] = true
  end
  
  return block_data
end

-- Check if a specific line was executed (important for fixing incorrectly marked lines)
function M.was_line_executed(file_path, line_num)
  -- Check if we have data for this file
  if not M.has_file(file_path) then
    return false
  end
  
  -- Get executed lines for this file
  local executed_lines = M.get_file_executed_lines(file_path)
  if executed_lines and executed_lines[line_num] then
    return true
  end
  
  -- Fall back to covered lines table if _executed_lines doesn't exist or is empty
  local covered_lines = M.get_file_covered_lines(file_path)
  return covered_lines and covered_lines[line_num] == true
end

-- Track function execution for instrumentation
function M.track_function(file_path, line_num, func_name)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Track function with proper error handling
  local success, err = error_handler.try(function()
    local file_data = coverage_data.files[normalized_path]
    if file_data then
      -- Initialize function tracking
      file_data.functions = file_data.functions or {}
      
      -- Create or update function data
      local func_id = func_name or ("anonymous_" .. line_num)
      file_data.functions[func_id] = file_data.functions[func_id] or {
        name = func_name or "anonymous",
        line = line_num,
        calls = 0,
        executed = false,
        covered = false
      }
      
      -- Increment call count
      file_data.functions[func_id].calls = file_data.functions[func_id].calls + 1
      file_data.functions[func_id].executed = true
      file_data.functions[func_id].covered = true
      
      -- Also track the declaration line
      M.set_line_executed(file_path, line_num, true)
      M.set_line_covered(file_path, line_num, true)
      
      -- Mark line as executable
      M.set_line_executable(file_path, line_num, true)
      
      -- Update global tracking
      coverage_data.functions[normalized_path .. ":" .. func_id] = true
      
      -- Verbose logging
      if config.verbose and logger.is_verbose_enabled() then
        logger.verbose("Function execution tracked", {
          file_path = normalized_path,
          line_num = line_num,
          func_name = func_name or "anonymous",
          calls = file_data.functions[func_id].calls
        })
      end
    end
    
    return true
  end)
  
  if not success then
    logger.debug("Error tracking function execution", {
      file_path = normalized_path,
      line_num = line_num,
      func_name = func_name or "anonymous",
      error = err.message
    })
  end
end

-- Track block execution for instrumentation
function M.track_block(file_path, line_num, block_id, block_type)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Track block with proper error handling
  local success, err = error_handler.try(function()
    local file_data = coverage_data.files[normalized_path]
    if file_data then
      -- Ensure logical_chunks table exists
      if not file_data.logical_chunks then
        file_data.logical_chunks = {}
      end
      
      -- Create or update block data
      local block_key = block_id .. "_" .. line_num
      file_data.logical_chunks[block_key] = file_data.logical_chunks[block_key] or {
        id = block_key,
        type = block_type or "Block",
        start_line = line_num,
        end_line = line_num,
        executed = false,
        execution_count = 0
      }
      
      -- Increment execution count
      file_data.logical_chunks[block_key].execution_count = 
        (file_data.logical_chunks[block_key].execution_count or 0) + 1
      file_data.logical_chunks[block_key].executed = true
      
      -- Also track the declaration line
      M.set_line_executed(file_path, line_num, true)
      M.set_line_covered(file_path, line_num, true)
      
      -- Mark line as executable
      M.set_line_executable(file_path, line_num, true)
      
      -- Update global tracking
      coverage_data.blocks[normalized_path .. ":" .. block_key] = true
      
      -- Verbose logging
      if config.verbose and logger.is_verbose_enabled() then
        logger.verbose("Block execution tracked", {
          file_path = normalized_path,
          line_num = line_num,
          block_id = block_id,
          block_type = block_type or "Block",
          executions = file_data.logical_chunks[block_key].execution_count
        })
      end
    end
    
    return true
  end)
  
  if not success then
    logger.debug("Error tracking block execution", {
      file_path = normalized_path,
      line_num = line_num,
      block_id = block_id,
      block_type = block_type or "Block",
      error = err and err.message or "unknown error"
    })
  end
end

-- Check if a specific line was covered (validated by assertions)
function M.was_line_covered(file_path, line_num)
  -- Check if we have data for this file
  if not M.has_file(file_path) then
    return false
  end
  
  -- Get covered lines for this file (these are validated by test assertions)
  local covered_lines = M.get_file_covered_lines(file_path)
  return covered_lines and covered_lines[line_num] == true
end

-- Track a line execution from instrumentation
function M.track_line(file_path, line_num)
  -- Handle with proper error handling
  local success, err = error_handler.try(function()
    local normalized_path = fs.normalize_path(file_path)
    
    -- Initialize file data if needed
    if not coverage_data.files[normalized_path] then
      M.initialize_file(file_path)
    end
    
    -- Mark this line as executed
    coverage_data.files[normalized_path]._executed_lines = coverage_data.files[normalized_path]._executed_lines or {}
    coverage_data.files[normalized_path]._executed_lines[line_num] = true
    
    -- Mark this line as covered - Properly handle executable vs non-executable lines
    local is_executable = true
    -- Try to determine if this line is executable using static analysis if available
    if static_analyzer and coverage_data.files[normalized_path].code_map then
      is_executable = static_analyzer.is_line_executable(coverage_data.files[normalized_path].code_map, line_num)
    end
    
    -- Only mark executable lines as covered
    if is_executable then
      coverage_data.files[normalized_path].lines = coverage_data.files[normalized_path].lines or {}
      coverage_data.files[normalized_path].lines[line_num] = true
      
      -- Also ensure executable_lines is set properly
      coverage_data.files[normalized_path].executable_lines = coverage_data.files[normalized_path].executable_lines or {}
      coverage_data.files[normalized_path].executable_lines[line_num] = true
    end
    
    return true
  end)
  
  if not success then
    logger.debug("Error tracking line execution", {
      file_path = file_path,
      line_num = line_num,
      error = err and err.message or "unknown error"
    })
  end
end

-- Public API for tracking block execution
-- This centralizes the block tracking logic into debug_hook
function M.track_blocks_for_line(file_path, line_num)
  if not config.track_blocks then
    return nil
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Skip if we don't have file data or code map
  if not M.has_file(file_path) then
    return nil
  end
  
  local code_map = M.get_file_code_map(file_path)
  if not code_map then
    return nil
  end
  
  -- Ensure we have the static analyzer
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Use the static analyzer to find which blocks contain this line
  local blocks_for_line = static_analyzer.get_blocks_for_line(code_map, line_num)
  
  -- Track the blocks that were found
  local tracked_blocks = {}
  
  -- Mark each block as executed
  for _, block in ipairs(blocks_for_line) do
    -- Get current blocks
    local logical_chunks = M.get_file_logical_chunks(file_path)
    
    -- Get or create block record
    local block_copy = logical_chunks[block.id]
    
    if not block_copy then
      -- Create a new deep copy if this is the first time we've seen this block
      block_copy = {
        id = block.id,
        type = block.type,
        start_line = block.start_line,
        end_line = block.end_line,
        parent_id = block.parent_id,
        branches = {},
        executed = true, -- Mark as executed immediately
        execution_count = 1 -- Track execution count
      }
      
      -- Copy branches array if it exists
      if block.branches then
        for _, branch_id in ipairs(block.branches) do
          table.insert(block_copy.branches, branch_id)
        end
      end
    else
      -- Update existing block record
      block_copy.executed = true
      block_copy.execution_count = (block_copy.execution_count or 0) + 1
    end
    
    -- Store the block using the accessor function
    M.add_block(file_path, block.id, block_copy)
    
    -- Update parent blocks - ensures parent blocks are marked as executed
    if block_copy.parent_id and block_copy.parent_id ~= "root" then
      local parent_block = logical_chunks[block_copy.parent_id]
      if parent_block then
        parent_block.executed = true
        parent_block.execution_count = (parent_block.execution_count or 0) + 1
        M.add_block(file_path, block_copy.parent_id, parent_block)
      end
    end
    
    -- Add to tracked_blocks for return value
    table.insert(tracked_blocks, block_copy)
    
    -- Verbose output for block execution
    if config.verbose and logger.is_verbose_enabled() then
      logger.verbose("Executed block", {
        block_id = block.id,
        type = block.type,
        line = line_num,
        file_path = normalized_path,
        execution_count = block_copy.execution_count or 1,
        parent_id = block.parent_id,
        operation = "track_blocks_for_line"
      })
    end
  end
  
  -- Return the blocks that were tracked
  return tracked_blocks
end

-- Reset coverage data
function M.reset()
  coverage_data = {
    files = {},
    lines = {},
    functions = {},
    blocks = {},
    conditions = {}
  }
  tracked_files = {}
  return M
end

return M
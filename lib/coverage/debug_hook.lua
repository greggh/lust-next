-- Core debug hook implementation
local M = {}
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local static_analyzer -- Lazily loaded when used
local config = {}
local tracked_files = {}
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
  local normalized_path = fs.normalize_path(file_path)
  
  -- Quick lookup for already-decided files
  if tracked_files[normalized_path] ~= nil then
    return tracked_files[normalized_path]
  end
  
  -- Special case for example files (always track them)
  if config.should_track_example_files and normalized_path:match("/examples/") then
    tracked_files[normalized_path] = true
    return true
  end
  
  -- Apply exclude patterns (fast reject)
  for _, pattern in ipairs(config.exclude or {}) do
    if fs.matches_pattern(normalized_path, pattern) then
      tracked_files[normalized_path] = false
      return false
    end
  end
  
  -- Apply include patterns
  for _, pattern in ipairs(config.include or {}) do
    if fs.matches_pattern(normalized_path, pattern) then
      tracked_files[normalized_path] = true
      return true
    end
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

-- Initialize tracking for a file
local function initialize_file(file_path)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Skip if already initialized
  if coverage_data.files[normalized_path] then
    return
  end
  
  -- Count lines in file and store them as an array
  local line_count = 0
  local source_text = fs.read_file(file_path)
  local source_lines = {}
  
  if source_text then
    for line in (source_text .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
      line_count = line_count + 1
      source_lines[line_count] = line
    end
  end
  
  coverage_data.files[normalized_path] = {
    lines = {},                 -- Lines validated by tests (covered)
    _executed_lines = {},       -- All executed lines (execution tracking)
    functions = {},             -- Function execution tracking
    line_count = line_count,
    source = source_lines,
    source_text = source_text,
    executable_lines = {},      -- Whether each line is executable
    logical_chunks = {}         -- Store code blocks information
  }
end

-- Check if a line is executable in a file
local function is_line_executable(file_path, line)
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Check if we have static analysis data for this file
  local normalized_path = fs.normalize_path(file_path)
  local file_data = coverage_data.files[normalized_path]
  
  if file_data and file_data.code_map then
    -- Use static analysis data
    local is_exec = static_analyzer.is_line_executable(file_data.code_map, line)
    
    -- Verbose output for specific test files
    if config.verbose and file_path:match("examples/minimal_coverage.lua") then
      local line_type = "unknown"
      if file_data.code_map.lines and file_data.code_map.lines[line] then
        line_type = file_data.code_map.lines[line].type or "unknown"
      end
      
      logger.verbose(string.format("Line %d classification: executable=%s, type=%s", 
        line, tostring(is_exec), line_type))
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
  
  -- Fall back to basic assumption that the line is executable
  -- (the patchup module will fix this later)
  return true
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
  local success, err = pcall(function()
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
          if config.debug and file_path:match("examples/execution_vs_coverage") then
            print(string.format("DEBUG [Coverage Self-tracking] Line %d execution in %s", 
                                line, normalized_path:match("([^/]+)$") or normalized_path))
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
          
          -- Debug output only if needed
          logger.debug("Initialized file: " .. normalized_path)
          
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
              
              logger.debug("Generated code map for " .. normalized_path)
            end
          end
        end
        
        -- Special files for extra verbose output
        local is_debug_file = file_path:match("examples/minimal_coverage.lua") or
                              file_path:match("examples/simple_multiline_comment_test.lua") or
                              file_path:match("validator_coverage_test.lua")
        
        -- Verbose output for test files
        if config.verbose and is_debug_file then
          logger.verbose(string.format("Line %d execution detected in debug hook", line))
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
          local is_executable = true
          
          -- Check if this is a comment line first
          if coverage_data.files[normalized_path].source and 
             coverage_data.files[normalized_path].source[line] then
            local line_text = coverage_data.files[normalized_path].source[line]
            if line_text:match("^%s*%-%-") then
              is_executable = false
            end
          end
          
          -- Use static analysis if available, otherwise default to executable
          if is_executable then
            is_executable = is_line_executable(file_path, line)
          end
          
          -- Always track all executed lines regardless of executability
          -- This provides a ground truth of which lines were actually executed
          coverage_data.files[normalized_path]._executed_lines = coverage_data.files[normalized_path]._executed_lines or {}
          coverage_data.files[normalized_path]._executed_lines[line] = true
          
          -- Verbose output for execution tracking
          -- Only log for example files or test files
          if config.verbose and (file_path:match("example") or file_path:match("test")) then
            logger.verbose(string.format("Detected execution of line %d in %s", 
                             line, normalized_path:match("([^/]+)$") or normalized_path))
          end
          
          -- Only mark executable lines as covered in the main coverage tracking
          if is_executable then
            -- Mark this line as covered - this is the key line that sets coverage
            coverage_data.files[normalized_path].lines[line] = true
            
            -- Also mark this as executable
            coverage_data.files[normalized_path].executable_lines[line] = true
            
            -- Verbose output for test files
            if config.verbose and is_debug_file then
              logger.verbose(string.format("Line %d execution tracked as covered and executable", line))
            end
          else
            -- DO NOT mark non-executable lines as covered
            -- This is key to fixing the coverage issue
            
            -- Make sure to mark it explicitly as non-executable
            coverage_data.files[normalized_path].executable_lines[line] = false
            
            -- Verbose output for non-executable lines
            if config.verbose and is_debug_file then
              logger.verbose(string.format("Line %d execution tracked but not counted (non-executable)", line))
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
                
                logger.debug("Generated code map on-demand for " .. normalized_path)
              end
              
              -- Mark that we tried, regardless of success
              coverage_data.files[normalized_path].code_map_attempted = true
            end
            
            -- Only track blocks if we have a code map
            if coverage_data.files[normalized_path].code_map then
              -- Lazily load the static analyzer
              if not static_analyzer then
                static_analyzer = require("lib.coverage.static_analyzer")
              end
              
              -- Use the static analyzer to find which blocks contain this line
              local blocks_for_line = static_analyzer.get_blocks_for_line(
                coverage_data.files[normalized_path].code_map, 
                line
              )
              
              -- Initialize logical_chunks if it doesn't exist
              if not coverage_data.files[normalized_path].logical_chunks then
                coverage_data.files[normalized_path].logical_chunks = {}
              end
              
              -- Mark each block as executed
              for _, block in ipairs(blocks_for_line) do
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
                if config.verbose then
                  logger.verbose("Executed block " .. block.id .. 
                      " (" .. block.type .. ") at line " .. line .. 
                      " in " .. normalized_path ..
                      " (count: " .. (block_copy.execution_count or 1) .. ")")
                end
              end
              
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
                if config.verbose then
                  local outcomes = ""
                  if condition_copy.executed_true then outcomes = outcomes .. " true" end
                  if condition_copy.executed_false then outcomes = outcomes .. " false" end
                  
                  logger.verbose("Executed condition " .. condition.id .. 
                      " (" .. condition.type .. ") at line " .. line .. 
                      " in " .. normalized_path .. 
                      " (count: " .. (condition_copy.execution_count or 1) ..
                      ", outcomes:" .. outcomes .. ")")
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
    logger.debug("Error: " .. tostring(err))
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
    local success, err = pcall(function()
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
            if config.verbose then
              logger.verbose("Executed function '" .. 
                  coverage_data.files[normalized_path].functions[existing_key].name .. 
                  "' at line " .. info.linedefined .. " in " .. normalized_path)
            end
            
            break
          end
        end
        
        -- If not found in registered functions, add it
        if not found then
          coverage_data.files[normalized_path].functions[func_key] = func_info
          coverage_data.functions[normalized_path .. ":" .. func_key] = true
          
          -- Verbose output for new functions
          if config.verbose then
            logger.verbose("Tracked new function '" .. func_name .. 
                  "' at line " .. info.linedefined .. " in " .. normalized_path)
          end
        end
      end
    end)
    
    -- Clear flag after processing
    processing_hook = false
    
    -- Report errors but don't crash
    if not success then
      logger.debug("Error: " .. tostring(err))
    end
  end
end

-- Set configuration
function M.set_config(new_config)
  config = new_config
  tracked_files = {}  -- Reset cached decisions
  
  -- Configure module logging level
  logging.configure_from_options("CoverageHook", config)
  
  return M
end

-- Get coverage data
function M.get_coverage_data()
  return coverage_data
end

-- Check if a specific line was executed (important for fixing incorrectly marked lines)
function M.was_line_executed(file_path, line_num)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Check if we have data for this file
  if not coverage_data.files[normalized_path] then
    return false
  end
  
  -- FIXED: Always use _executed_lines for actual execution tracking
  -- This is more reliable than using lines, which only tracks covered executable lines
  if coverage_data.files[normalized_path]._executed_lines then
    return coverage_data.files[normalized_path]._executed_lines[line_num] == true
  end
  
  -- Fall back to lines table if _executed_lines doesn't exist
  return coverage_data.files[normalized_path].lines[line_num] == true
end

-- Check if a specific line was covered (validated by assertions)
function M.was_line_covered(file_path, line_num)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Check if we have data for this file
  if not coverage_data.files[normalized_path] then
    return false
  end
  
  -- Only the lines table tracks actual coverage (validation by assertions)
  return coverage_data.files[normalized_path].lines and 
         coverage_data.files[normalized_path].lines[line_num] == true
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
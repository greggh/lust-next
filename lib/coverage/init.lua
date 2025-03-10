-- lust-next code coverage module
local M = {}

-- Import submodules
local debug_hook = require("lib.coverage.debug_hook")
local file_manager = require("lib.coverage.file_manager")
local patchup = require("lib.coverage.patchup")
local static_analyzer = require("lib.coverage.static_analyzer")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Create a logger for this module
local logger = logging.get_logger("Coverage")

-- Initialize static analyzer with our config settings
local function init_static_analyzer()
  static_analyzer.init({
    control_flow_keywords_executable = config and config.control_flow_keywords_executable or true,
    debug = config and config.debug or false,
    verbose = config and config.verbose or false
  })
end

-- Default configuration
local DEFAULT_CONFIG = {
  enabled = false,
  source_dirs = {".", "lib"},
  include = {"*.lua", "**/*.lua"},
  exclude = {
    "*_test.lua", "*_spec.lua", "test_*.lua",
    "tests/**/*.lua", "**/test/**/*.lua", "**/tests/**/*.lua",
    "**/spec/**/*.lua", "**/*.test.lua", "**/*.spec.lua",
    "**/*.min.lua", "**/vendor/**", "**/deps/**", "**/node_modules/**"
  },
  discover_uncovered = true,
  threshold = 90,
  debug = false,
  
  -- Execution vs coverage distinction
  track_self_coverage = true,         -- Record execution of coverage module files themselves
  should_track_example_files = true,  -- Always track example files
  verbose = false,                    -- Enable verbose debugging output
  
  -- Static analysis options
  use_static_analysis = true,   -- Use static analysis when available
  branch_coverage = false,      -- Track branch coverage (not just line coverage)
  cache_parsed_files = true,    -- Cache parsed ASTs for better performance
  track_blocks = true,          -- Track code blocks (not just lines)
  pre_analyze_files = false,    -- Pre-analyze all files before test execution
  control_flow_keywords_executable = true  -- Treat control flow keywords like 'end', 'else' as executable
}

-- Module state
local config = {}
local active = false
local original_hook = nil
local enhanced_mode = false

-- Expose configuration for external access (needed for config_test.lua)
M.config = DEFAULT_CONFIG

-- Track line coverage through instrumentation
-- This tracks actual test coverage (validation) rather than just execution
function M.track_line(file_path, line_num)
  if not active or not config.enabled then
    return
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Ensure coverage_data is properly initialized
  local coverage_data = debug_hook.get_coverage_data()
  
  -- Create files table if it doesn't exist
  if not coverage_data.files then
    coverage_data.files = {}
  end
  
  -- Create lines table if it doesn't exist
  if not coverage_data.lines then
    coverage_data.lines = {}
  end
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    -- Initialize file data
    local line_count = 0
    local source_lines = {}
    local source_text = fs.read_file(file_path)
    
    if source_text then
      for line in (source_text .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
        line_count = line_count + 1
        source_lines[line_count] = line
      end
    end
    
    coverage_data.files[normalized_path] = {
      lines = {},             -- Lines that are covered (validated by tests)
      _executed_lines = {},   -- Lines that were executed (not necessarily validated)
      functions = {},
      line_count = line_count,
      source = source_lines,
      source_text = source_text,
      executable_lines = {}
    }
  end
  
  -- Ensure lines table exists
  if not coverage_data.files[normalized_path].lines then
    coverage_data.files[normalized_path].lines = {}
  end
  
  -- Track line as COVERED (validated by test assertions)
  -- This is separate from execution tracking which is handled by debug_hook
  coverage_data.files[normalized_path].lines[line_num] = true
  coverage_data.lines[normalized_path .. ":" .. line_num] = true
  
  -- Also track as executed (for consistency)
  if not coverage_data.files[normalized_path]._executed_lines then
    coverage_data.files[normalized_path]._executed_lines = {}
  end
  coverage_data.files[normalized_path]._executed_lines[line_num] = true
  
  -- Mark as executable
  if not coverage_data.files[normalized_path].executable_lines then
    coverage_data.files[normalized_path].executable_lines = {}
  end
  coverage_data.files[normalized_path].executable_lines[line_num] = true
end

-- Apply configuration with defaults
function M.init(options)
  -- Start with defaults
  config = {}
  for k, v in pairs(DEFAULT_CONFIG) do
    config[k] = v
  end
  
  -- Apply user options
  if options then
    for k, v in pairs(options) do
      if k == "include" or k == "exclude" then
        if type(v) == "table" then
          config[k] = v
        end
      else
        config[k] = v
      end
    end
  end
  
  -- Update the publicly exposed config
  for k, v in pairs(config) do
    M.config[k] = v
  end
  
  -- Configure module logging level
  logging.configure_from_options("Coverage", config)
  
  -- Reset coverage
  M.reset()
  
  -- Configure debug hook
  debug_hook.set_config(config)
  
  -- Initialize static analyzer if enabled
  if config.use_static_analysis then
    static_analyzer.init({
      cache_files = config.cache_parsed_files,
      control_flow_keywords_executable = config.control_flow_keywords_executable,
      debug = config.debug,
      verbose = config.verbose
    })
    
    -- Pre-analyze files if configured
    if config.pre_analyze_files then
      local found_files = {}
      -- Discover Lua files
      for _, dir in ipairs(config.source_dirs) do
        for _, include_pattern in ipairs(config.include) do
          local matches = fs.glob(dir, include_pattern)
          for _, file_path in ipairs(matches) do
            -- Check if file should be excluded
            local excluded = false
            for _, exclude_pattern in ipairs(config.exclude) do
              if fs.matches_pattern(file_path, exclude_pattern) then
                excluded = true
                break
              end
            end
            
            if not excluded then
              table.insert(found_files, file_path)
            end
          end
        end
      end
      
      -- Pre-analyze all discovered files
      logger.debug("Pre-analyzing " .. #found_files .. " files")
      
      for _, file_path in ipairs(found_files) do
        static_analyzer.parse_file(file_path)
      end
    end
  end
  
  -- Try to load enhanced C extensions
  local has_cluacov = pcall(require, "lib.coverage.vendor.cluacov_hook")
  enhanced_mode = has_cluacov
  
  return M
end

-- Start coverage collection
function M.start(options)
  if not config.enabled then
    return M
  end
  
  if active then
    return M  -- Already running
  end
  
  -- Save original hook
  original_hook = debug.gethook()
  
  -- Set debug hook
  debug.sethook(debug_hook.debug_hook, "cl")
  
  active = true
  
  -- Instead of marking arbitrary initial lines, we'll analyze the code structure
  -- and mark logically connected lines to ensure consistent coverage highlighting
  
  -- Process loaded modules to ensure their module.lua files are tracked
  if package.loaded then
    for module_name, _ in pairs(package.loaded) do
      -- Try to find the module's file path
      local paths_to_check = {}
      
      -- Common module path patterns
      local patterns = {
        module_name:gsub("%.", "/") .. ".lua",                 -- module/name.lua
        module_name:gsub("%.", "/") .. "/init.lua",            -- module/name/init.lua
        "lib/" .. module_name:gsub("%.", "/") .. ".lua",       -- lib/module/name.lua
        "lib/" .. module_name:gsub("%.", "/") .. "/init.lua",  -- lib/module/name/init.lua
      }
      
      for _, pattern in ipairs(patterns) do
        table.insert(paths_to_check, pattern)
      end
      
      -- Try each potential path
      for _, potential_path in ipairs(paths_to_check) do
        if fs.file_exists(potential_path) and debug_hook.should_track_file(potential_path) then
          -- Module file found, process its structure
          process_module_structure(potential_path)
        end
      end
    end
  end
  
  -- Process the currently executing file
  local current_source
  for i = 1, 10 do -- Check several stack levels
    local info = debug.getinfo(i, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
      current_source = info.source:sub(2)
      if debug_hook.should_track_file(current_source) then
        process_module_structure(current_source)
      end
    end
  end
  
  return M
end

-- Process a module's code structure to mark logical execution paths
function process_module_structure(file_path)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data in coverage tracking
  if not debug_hook.get_coverage_data().files[normalized_path] then
    local source = fs.read_file(file_path)
    if not source then return end
    
    -- Split source into lines for analysis
    local lines = {}
    for line in (source .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
      table.insert(lines, line)
    end
    
    -- Initialize file data with basic information
    debug_hook.get_coverage_data().files[normalized_path] = {
      lines = {},
      functions = {},
      line_count = #lines,
      source = lines,
      source_text = source,
      executable_lines = {},
      logical_chunks = {} -- Store related code blocks
    }
    
    -- Apply static analysis immediately if enabled
    if config.use_static_analysis then
      local ast, code_map = static_analyzer.parse_file(file_path)
      
      if ast and code_map then
        logger.debug("Using static analysis for " .. file_path)
        
        -- Store static analysis information
        debug_hook.get_coverage_data().files[normalized_path].code_map = code_map
        debug_hook.get_coverage_data().files[normalized_path].ast = ast
        debug_hook.get_coverage_data().files[normalized_path].executable_lines = 
          static_analyzer.get_executable_lines(code_map)
        
        -- Register functions from static analysis
        for _, func in ipairs(code_map.functions) do
          local start_line = func.start_line
          local func_key = start_line .. ":" .. (func.name or "anonymous_function")
          
          debug_hook.get_coverage_data().files[normalized_path].functions[func_key] = {
            name = func.name or ("function_" .. start_line),
            line = start_line,
            end_line = func.end_line,
            params = func.params or {},
            executed = false
          }
        end
        
        -- CRITICAL FIX: Do NOT mark non-executable lines as covered at initialization
        -- This was causing all comments and non-executable lines to appear covered
        -- Just mark them as non-executable in the executable_lines table
        for line_num = 1, code_map.line_count do
          if not static_analyzer.is_line_executable(code_map, line_num) then
            if debug_hook.get_coverage_data().files[normalized_path].executable_lines then
              debug_hook.get_coverage_data().files[normalized_path].executable_lines[line_num] = false
            end
          end
        end
      else
        -- Static analysis failed, use basic heuristics
        logger.debug("Static analysis failed for " .. file_path .. ", using heuristics")
        fallback_heuristic_analysis(file_path, normalized_path, lines)
      end
    else
      -- Static analysis disabled, use basic heuristics
      fallback_heuristic_analysis(file_path, normalized_path, lines)
    end
  end
end

-- Fallback to basic heuristic analysis when static analysis is not available
function fallback_heuristic_analysis(file_path, normalized_path, lines)
  -- Mark basic imports and requires to ensure some coverage
  local import_section_end = 0
  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed:match("^require") or 
       trimmed:match("^local%s+[%w_]+%s*=%s*require") or
       trimmed:match("^import") then
      -- This is an import/require line
      M.track_line(file_path, i)
      import_section_end = i
    elseif i > 1 and i <= import_section_end + 2 and 
           (trimmed:match("^local%s+[%w_]+") or trimmed == "") then
      -- Variable declarations or blank lines right after imports
      M.track_line(file_path, i)
    elseif i > import_section_end + 2 and trimmed ~= "" and 
           not trimmed:match("^%-%-") then
      -- First non-comment, non-blank line after imports section
      break
    end
  end
  
  -- Simple function detection
  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")
    -- Detect function declarations
    local func_name = trimmed:match("^function%s+([%w_:%.]+)%s*%(")
    if func_name then
      debug_hook.get_coverage_data().files[normalized_path].functions[i .. ":" .. func_name] = {
        name = func_name,
        line = i,
        executed = false
      }
    end
    
    -- Detect local function declarations
    local local_func_name = trimmed:match("^local%s+function%s+([%w_:%.]+)%s*%(")
    if local_func_name then
      debug_hook.get_coverage_data().files[normalized_path].functions[i .. ":" .. local_func_name] = {
        name = local_func_name,
        line = i,
        executed = false
      }
    end
  end
end

-- Apply static analysis to a file with improved protection and timeout handling
local function apply_static_analysis(file_path, file_data)
  if not file_data.needs_static_analysis then
    return 0
  end
  
  -- Skip if the file doesn't exist or can't be read
  if not fs.file_exists(file_path) then
    logger.debug("Skipping static analysis for non-existent file: " .. file_path)
    return 0
  end
  
  -- Skip files over 250KB for performance (INCREASED from 100KB)
  local file_size = fs.get_file_size(file_path)
  if file_size and file_size > 250000 then
    logger.debug("Skipping static analysis for large file: " .. file_path .. 
            " (" .. math.floor(file_size/1024) .. "KB)")
    return 0
  end
  
  -- Skip test files that don't need detailed analysis
  if file_path:match("_test%.lua$") or 
     file_path:match("_spec%.lua$") or
     file_path:match("/tests/") or
     file_path:match("/test/") then
    logger.debug("Skipping static analysis for test file: " .. file_path)
    return 0
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Set up timing with more generous timeout
  local timeout_reached = false
  local start_time = os.clock()
  local MAX_ANALYSIS_TIME = 3.0 -- 3 second timeout (INCREASED from 500ms)
  
  -- Variables for results
  local ast, code_map, improved_lines = nil, nil, 0
  
  -- PHASE 1: Parse file with static analyzer (with protection)
  local phase1_success, phase1_result = pcall(function()
    -- Short-circuit if we're already exceeding time
    if os.clock() - start_time > MAX_ANALYSIS_TIME then
      timeout_reached = true
      return nil, "Initial timeout"
    end
    
    -- Run the parser with all our protection mechanisms
    ast, err = static_analyzer.parse_file(file_path)
    if not ast then
      return nil, "Parse failed: " .. (err or "unknown error")
    end
    
    -- Check for timeout again before code_map access
    if os.clock() - start_time > MAX_ANALYSIS_TIME then
      timeout_reached = true
      return nil, "Timeout after parse"
    end
    
    -- Access code_map safely
    if type(ast) ~= "table" then
      return nil, "Invalid AST (not a table)"
    end
    
    -- Get the code_map from the result
    return ast, nil
  end)
  
  -- Handle errors from phase 1
  if not phase1_success then
    logger.debug("Static analysis phase 1 error: " .. tostring(phase1_result) .. 
         " for file: " .. file_path)
    return 0
  end
  
  -- Check for timeout or missing AST
  if timeout_reached or not ast then
    logger.debug("Static analysis " .. 
          (timeout_reached and "timed out" or "failed") .. 
          " in phase 1 for file: " .. file_path)
    return 0
  end
  
  -- PHASE 2: Get code map and apply it to our data (with protection)
  local phase2_success, phase2_result = pcall(function()
    -- First check if analysis is still within time limit
    if os.clock() - start_time > MAX_ANALYSIS_TIME then
      timeout_reached = true
      return 0, "Phase 2 initial timeout"
    end
    
    -- Try to get the code map from the companion cache
    code_map = ast._code_map -- This may have been attached by parse_file
    
    if not code_map then
      -- If no attached code map, we need to generate one
      local err
      code_map, err = static_analyzer.get_code_map_for_ast(ast, file_path)
      if not code_map then
        return 0, "Failed to get code map: " .. (err or "unknown error")
      end
    end
    
    -- Periodic timeout check
    if os.clock() - start_time > MAX_ANALYSIS_TIME then
      timeout_reached = true
      return 0, "Timeout after code map generation"
    end
    
    -- Apply the code map data to our file_data safely
    file_data.code_map = code_map
    
    -- Get executable lines safely with timeout protection
    local exec_lines_success, exec_lines_result = pcall(function()
      return static_analyzer.get_executable_lines(code_map)
    end)
    
    if not exec_lines_success then
      return 0, "Error getting executable lines: " .. tostring(exec_lines_result)
    end
    
    file_data.executable_lines = exec_lines_result
    file_data.functions_info = code_map.functions or {}
    file_data.branches = code_map.branches or {}
    
    return 1, nil -- Success
  end)
  
  -- Handle errors from phase 2
  if not phase2_success or timeout_reached then
    logger.debug("Static analysis " .. 
          (timeout_reached and "timed out" or "failed") .. 
          " in phase 2 for file: " .. file_path ..
          (not phase2_success and (": " .. tostring(phase2_result)) or ""))
    return 0
  end
  
  -- PHASE 3: Mark non-executable lines (this is the most expensive operation)
  local phase3_success, phase3_result = pcall(function()
    -- Final time check before heavy processing
    if os.clock() - start_time > MAX_ANALYSIS_TIME then
      timeout_reached = true
      return 0, "Phase 3 initial timeout"
    end
    
    local line_improved_count = 0
    local BATCH_SIZE = 100 -- Process in batches for better interrupt handling
    
    -- Process lines in batches to allow for timeout checks
    for batch_start = 1, file_data.line_count, BATCH_SIZE do
      -- Check timeout at the start of each batch
      if os.clock() - start_time > MAX_ANALYSIS_TIME then
        timeout_reached = true
        return line_improved_count, "Timeout during batch processing at line " .. batch_start
      end
      
      local batch_end = math.min(batch_start + BATCH_SIZE - 1, file_data.line_count)
      
      -- Process current batch
      for line_num = batch_start, batch_end do
        -- Use safe function to check if line is executable
        local is_exec_success, is_executable = pcall(function()
          return static_analyzer.is_line_executable(code_map, line_num)
        end)
        
        -- If not executable, mark it in executable_lines table
        if (is_exec_success and not is_executable) then
          -- Store that this line is non-executable in the executable_lines table
          file_data.executable_lines[line_num] = false
          
          -- IMPORTANT: If a non-executable line was incorrectly marked as covered, remove it
          if file_data.lines[line_num] then
            file_data.lines[line_num] = nil
            line_improved_count = line_improved_count + 1
          end
        end
      end
    end
    
    -- Mark functions based on static analysis (quick operation)
    if os.clock() - start_time <= MAX_ANALYSIS_TIME and code_map.functions then
      for _, func in ipairs(code_map.functions) do
        local start_line = func.start_line
        if start_line and start_line > 0 then
          local func_key = start_line .. ":function"
          
          if not file_data.functions[func_key] then
            -- Function is defined but wasn't called during test
            file_data.functions[func_key] = {
              name = func.name or ("function_" .. start_line),
              line = start_line,
              executed = false,
              params = func.params or {}
            }
          end
        end
      end
    end
    
    return line_improved_count, nil
  end)
  
  -- Handle errors from phase 3
  if not phase3_success then
    logger.debug("Static analysis phase 3 error: " .. tostring(phase3_result) .. 
         " for file: " .. file_path)
    return 0
  end
  
  -- If timeout occurred during phase 3, we still return any improvements we made
  if timeout_reached then
    logger.debug("Static analysis timed out in phase 3 for file: " .. file_path ..
        " - partial results used")
  end
  
  -- Return the number of improved lines
  improved_lines = type(phase3_result) == "number" and phase3_result or 0
  
  return improved_lines
end

-- Stop coverage collection
function M.stop()
  if not active then
    return M
  end
  
  -- Restore original hook
  debug.sethook(original_hook)
  
  -- Process coverage data
  if config.discover_uncovered then
    local added = file_manager.add_uncovered_files(
      debug_hook.get_coverage_data(),
      config
    )
    
    logger.debug("Added " .. added .. " discovered files")
  end
  
  -- Apply static analysis if configured
  if config.use_static_analysis then
    local improved_files = 0
    local improved_lines = 0
    
    for file_path, file_data in pairs(debug_hook.get_coverage_data().files) do
      if file_data.needs_static_analysis then
        local lines = apply_static_analysis(file_path, file_data)
        if lines > 0 then
          improved_files = improved_files + 1
          improved_lines = improved_lines + lines
        end
      end
    end
    
    logger.debug("Applied static analysis to " .. improved_files .. 
          " files, improving " .. improved_lines .. " lines")
  end
  
  -- Patch coverage data for non-executable lines, ensuring we're not
  -- incorrectly marking executable lines as covered
  local coverage_data = debug_hook.get_coverage_data()
  
  -- Very important pre-processing step: initialize executable_lines for all files if not present
  for file_path, file_data in pairs(coverage_data.files) do
    if not file_data.executable_lines then
      file_data.executable_lines = {}
    end
  end
  
  -- Now patch with our enhanced logic
  local patched = patchup.patch_all(coverage_data)
  
  -- Post-processing: verify we haven't incorrectly marked executable lines as covered
  local fixed_files = 0
  local fixed_lines = 0
  for file_path, file_data in pairs(coverage_data.files) do
    local file_fixed = false
    -- Check each line
    for line_num, is_covered in pairs(file_data.lines) do
      -- If it's marked covered but it's an executable line and wasn't actually executed
      if is_covered and file_data.executable_lines[line_num] and not debug_hook.was_line_executed(file_path, line_num) then
        -- Fix incorrect coverage
        file_data.lines[line_num] = false
        fixed_lines = fixed_lines + 1
        file_fixed = true
      end
    end
    if file_fixed then
      fixed_files = fixed_files + 1
    end
  end
  
  logger.debug("Patched " .. patched .. " non-executable lines")
  if fixed_lines > 0 then
    logger.debug("Fixed " .. fixed_lines .. " incorrectly marked executable lines in " .. fixed_files .. " files")
  end
  
  active = false
  return M
end

-- Reset coverage data
function M.reset()
  debug_hook.reset()
  return M
end

-- Full reset (clears all data)
function M.full_reset()
  debug_hook.reset()
  return M
end

-- Process multiline comments in a file
local function process_multiline_comments(file_path, file_data)
  -- Skip if no source code available
  if not file_data.source or type(file_data.source) ~= "table" then
    return 0
  end
  
  local fixed = 0
  
  -- Ensure executable_lines table exists
  if not file_data.executable_lines then
    file_data.executable_lines = {}
  end
  
  -- Step 1: First pass to identify all comment lines (including single-line comments)
  local comment_lines = {}
  local in_multiline_comment = false
  
  for i = 1, file_data.line_count or #file_data.source do
    local line = file_data.source[i] or ""
    local trimmed = line:match("^%s*(.-)%s*$") or ""
    
    -- Detect single-line comments
    if trimmed:match("^%-%-") then
      comment_lines[i] = true
    -- Detect multiline comment start --[[
    elseif trimmed:match("^%-%-%[%[") and not trimmed:match("%]%]") then
      in_multiline_comment = true
      comment_lines[i] = true
    -- Detect multiline comment end
    elseif in_multiline_comment then
      comment_lines[i] = true
      if trimmed:match("%]%]") then
        in_multiline_comment = false
      end
    end
  end
  
  -- Step 2: Second pass with more sophisticated multiline comment detection
  in_multiline_comment = false
  local state_stack = {}
  
  for i = 1, file_data.line_count or #file_data.source do
    local line = file_data.source[i] or ""
    
    -- Skip lines already marked as comments
    if comment_lines[i] then
      file_data.executable_lines[i] = false
      if file_data.lines and file_data.lines[i] then
        file_data.lines[i] = nil
        fixed = fixed + 1
      end
      goto continue
    end
    
    -- Track both --[[ and [[ style multiline comments
    local ml_comment_markers = {}
    
    -- Find all multiline comment markers in this line
    local pos = 1
    while pos <= #line do
      local start_pos_dash = line:find("%-%-%[%[", pos)
      local start_pos_bracket = line:find("%[%[", pos)
      local end_pos = line:find("%]%]", pos)
      
      -- Store each marker with its position
      if start_pos_dash and (not start_pos_bracket or start_pos_dash < start_pos_bracket) and 
         (not end_pos or start_pos_dash < end_pos) then
        table.insert(ml_comment_markers, {pos = start_pos_dash, type = "start", style = "dash"})
        pos = start_pos_dash + 4
      elseif start_pos_bracket and (not start_pos_dash or start_pos_bracket < start_pos_dash) and
             (not end_pos or start_pos_bracket < end_pos) and
             -- Only count [[ as comment start if not in a string
             not line:sub(1, start_pos_bracket-1):match("['\"]%s*$") then
        table.insert(ml_comment_markers, {pos = start_pos_bracket, type = "start", style = "bracket"})
        pos = start_pos_bracket + 2
      elseif end_pos then
        table.insert(ml_comment_markers, {pos = end_pos, type = "end"})
        pos = end_pos + 2
      else
        break -- No more markers in this line
      end
    end
    
    -- Sort markers by position
    table.sort(ml_comment_markers, function(a, b) return a.pos < b.pos end)
    
    -- Process markers in order with a state stack for proper nesting
    local was_in_comment = in_multiline_comment
    local changed_in_this_line = false
    
    for _, marker in ipairs(ml_comment_markers) do
      if marker.type == "start" and not in_multiline_comment then
        in_multiline_comment = true
        table.insert(state_stack, marker.style) -- Push style onto stack
        changed_in_this_line = true
      elseif marker.type == "end" and in_multiline_comment then
        -- Only pop if we have items on the stack
        if #state_stack > 0 then
          table.remove(state_stack) -- Pop the stack
          
          -- Only clear in_multiline_comment if stack is empty
          if #state_stack == 0 then
            in_multiline_comment = false
          end
        else
          -- Unmatched end marker, could be end of a string
          -- Do nothing
        end
        changed_in_this_line = true
      end
    end
    
    -- Handle line based on its comment state
    if was_in_comment or in_multiline_comment or changed_in_this_line then
      -- This line is part of or contains a multiline comment
      file_data.executable_lines[i] = false
      comment_lines[i] = true
      
      -- Only remove coverage marking if it wasn't actually executed
      if file_data.lines and file_data.lines[i] then
        file_data.lines[i] = nil
        fixed = fixed + 1
      end
    end
    
    ::continue::
  end
  
  -- Step 3: Post-processing to catch any remaining comment lines that might be misclassified
  for i = 1, file_data.line_count or #file_data.source do
    local line = file_data.source[i] or ""
    local trimmed = line:match("^%s*(.-)%s*$") or ""
    
    -- Aggressive check for lines that look like comments 
    if not comment_lines[i] and (
       trimmed:match("^%-%-") or -- Single line comment
       trimmed:match("^%s*$") or -- Empty line
       trimmed:match("^%-%-%[%[.*%]%]") -- Single-line multiline comment
    ) then
      file_data.executable_lines[i] = false
      
      -- Only remove coverage marking if it wasn't actually executed
      if file_data.lines and file_data.lines[i] then
        file_data.lines[i] = nil
        fixed = fixed + 1
      end
    end
  end
  
  return fixed
end

-- Additional comment line detection function
local function is_comment_line(line)
  if not line then return false end
  
  local trimmed = line:match("^%s*(.-)%s*$") or ""
  
  -- Check for various comment patterns
  return trimmed:match("^%-%-") or                -- Single line comment
         trimmed:match("^%-%-%[%[") or           -- Multiline comment start
         trimmed:match("%]%]$") or               -- Multiline comment end
         trimmed:match("^%s*$") or               -- Empty line
         trimmed:match("^%-%-%[%[.*%]%]") or     -- Single-line multiline comment
         trimmed:match("^%[%[.*%]%]$")           -- Multi-line string on a single line
end

-- Get coverage report data
function M.get_report_data()
  local coverage_data = debug_hook.get_coverage_data()
  
  -- Process multiline comments in all files
  local multiline_fixed = 0
  for file_path, file_data in pairs(coverage_data.files) do
    multiline_fixed = multiline_fixed + process_multiline_comments(file_path, file_data)
  end
  
  if config.debug and multiline_fixed > 0 then
    print("DEBUG [Coverage Report] Fixed " .. multiline_fixed .. " lines in multiline comments")
  end
  
  -- Fix any incorrectly marked lines before generating report
  -- This is a critical final check to ensure we don't over-report coverage
  local fixed_lines = 0
  for file_path, file_data in pairs(coverage_data.files) do
    -- Check each line
    for line_num, is_covered in pairs(file_data.lines) do
      -- Get the source line for comment checking
      local source_line = file_data.source and file_data.source[line_num]
      
      -- Fix cases where:
      -- 1. It's marked covered but it's an executable line and wasn't actually executed, OR
      -- 2. It's a comment line that was incorrectly marked as covered
      if (is_covered and 
          file_data.executable_lines and 
          file_data.executable_lines[line_num] and 
          not debug_hook.was_line_executed(file_path, line_num)) or
         (is_covered and source_line and is_comment_line(source_line)) then
        -- Fix incorrect coverage
        file_data.lines[line_num] = false
        fixed_lines = fixed_lines + 1
      end
    end
  end
  
  if config.debug and fixed_lines > 0 then
    print("DEBUG [Coverage Report] Fixed " .. fixed_lines .. " incorrectly marked executable lines")
  end
  
  -- Calculate statistics
  local stats = {
    total_files = 0,
    covered_files = 0,
    total_lines = 0,
    covered_lines = 0,
    total_functions = 0,
    covered_functions = 0,
    total_blocks = 0,
    covered_blocks = 0,
    files = {}
  }
  
  for file_path, file_data in pairs(coverage_data.files) do
    -- Count covered lines - BUT ONLY COUNT EXECUTABLE LINES!
    local covered_lines = 0
    local total_executable_lines = 0
    
    -- Verbose output when processing our test files
    local is_test_file = file_path:match("examples/minimal_coverage.lua")
    
    if is_test_file then
      logger.verbose(string.format("Counting lines for file: %s", file_path))
      
      -- Print lines data in verbose mode
      if config.verbose then
        local lines_info = "  - file_data.lines table: " .. tostring(file_data.lines ~= nil)
        local exec_info = "  - file_data.executable_lines table: " .. tostring(file_data.executable_lines ~= nil)
        print("[Coverage Verbose] " .. lines_info)
        print("[Coverage Verbose] " .. exec_info)
        
        -- Check some line examples
        for i = 1, 20 do
          local line_covered = file_data.lines and file_data.lines[i]
          local line_executable = file_data.executable_lines and file_data.executable_lines[i]
          local line_info = string.format("  - Line %d: covered=%s, executable=%s", 
            i, tostring(line_covered), tostring(line_executable))
          print("[Coverage Verbose] " .. line_info)
        end
      end
    end
    
    -- Do a thorough pass to ensure multiline comments are properly handled
    process_multiline_comments(file_path, file_data)
    
    -- Use a special counter for executable lines that accounts for multiline comments
    total_executable_lines = 0
    
    -- Make sure we have at least the basic line classifications
    if not file_data.executable_lines then
      file_data.executable_lines = {}
    end
    
    -- Mark all executable lines from actual execution
    for line_num, is_covered in pairs(file_data.lines or {}) do
      if is_covered then
        file_data.executable_lines[line_num] = true
      end
    end
    
    -- Create a list of executable lines accounting for multiline comments
    local in_multiline_comment = false
    
    -- First pass: count executable lines correctly
    if file_data.source then
      for line_num = 1, #file_data.source do
        local line = file_data.source[line_num]
        
        -- Check for multiline comment markers (with nil check)
        local starts_comment = line and line:match("^%s*%-%-%[%[") or false
        local ends_comment = line and line:match("%]%]") or false
        
        -- Update multiline comment state
        if starts_comment and not ends_comment then
          in_multiline_comment = true
        elseif ends_comment and in_multiline_comment then
          in_multiline_comment = false
        end
        
        -- Handle the line based on whether it's in a comment
        if not in_multiline_comment then
          -- CRITICAL FIX: Only count as executable if it's been marked executable by static analysis
          -- and NOT just because it was executed (avoid circular logic)
          if file_data.executable_lines and file_data.executable_lines[line_num] == true then
            total_executable_lines = total_executable_lines + 1
          end
        else
          -- For lines inside multiline comments:
          -- Always mark as non-executable and CRITICAL FIX: Definitely remove any coverage marking
          if file_data.executable_lines then
            file_data.executable_lines[line_num] = false
          end
          if file_data.lines then
            file_data.lines[line_num] = nil
          end
        end
      end
    end
    
    -- CRITICAL FIX: Now count properly covered executable lines
    -- while maintaining the distinction between execution and coverage
    
    -- First ensure we have an _executed_lines table if it doesn't exist
    if not file_data._executed_lines then
      -- If we don't have _executed_lines, create it and add executed lines from lines table
      -- This is a fallback for compatibility with older runs
      file_data._executed_lines = {}
      for line_num, is_covered in pairs(file_data.lines or {}) do
        if is_covered then
          file_data._executed_lines[line_num] = true
        end
      end
      
      if is_test_file then
        logger.verbose("Created missing _executed_lines table from existing covered lines")
      end
    end
    
    -- We do NOT automatically mark executed lines as covered
    -- This is what preserves the distinction between "executed" and "covered"
    -- Lines must be explicitly marked as covered through test assertions
    -- The HTML formatter will use both data points to determine the 
    -- correct state (executed-but-not-covered vs fully covered)
    
    -- Now process all marked lines
    for line_num, is_covered in pairs(file_data.lines or {}) do
      -- Get the source line for additional comment checking
      local source_line = file_data.source and file_data.source[line_num]
      local is_comment = source_line and is_comment_line(source_line)
      
      -- Only count lines that are both covered AND executable AND not a comment
      if is_covered and file_data.executable_lines and file_data.executable_lines[line_num] == true and not is_comment then
        -- This is a valid executable and covered line - count it
        covered_lines = covered_lines + 1
        
        if is_test_file and config.verbose then
          print(string.format("[Coverage Verbose] Counted covered line %d", line_num))
        end
      else
        -- Remove coverage marking from any non-executable line or comment
        if file_data.executable_lines == nil or file_data.executable_lines[line_num] ~= true or is_comment then
          -- This line isn't marked as executable or is a comment but has coverage - remove it
          if is_test_file and config.verbose then
            print(string.format("[Coverage Verbose] Removed invalid coverage for line %d%s", 
                              line_num, is_comment and " (comment line)" or ""))
          end
          file_data.lines[line_num] = nil
        end
      end
    end
    
    -- Count functions (total and covered)
    local total_functions = 0
    local covered_functions = 0
    local functions_info = {}
    
    -- Debug the functions table in verbose mode
    if is_test_file and config.verbose then
      print("[Coverage Verbose] Functions table in file_data:", tostring(file_data.functions ~= nil))
      
      -- More detailed debugging for functions table
      local function_count = 0
      for _, _ in pairs(file_data.functions or {}) do
        function_count = function_count + 1
      end
      print("[Coverage Verbose] Function count:", function_count)
      
      for func_key, func_data in pairs(file_data.functions or {}) do
        print(string.format("[Coverage Verbose] Function %s at line %d: executed=%s, key=%s", 
          func_data.name or "anonymous", 
          func_data.line or 0, 
          tostring(func_data.executed),
          func_key))
      end
    end
    
    -- Fix to properly count and track functions
    -- Using iteration that doesn't depend on numeric indexing
    for func_key, func_data in pairs(file_data.functions or {}) do
      -- Verify this is a valid function entry with required data
      if type(func_data) == "table" and func_data.line and func_data.line > 0 then
        total_functions = total_functions + 1
        
        -- Enhanced debugging for function tracking
        if is_test_file and config.verbose then
          print(string.format("[Coverage Verbose] Processing function: %s at line %d", 
            func_data.name or "anonymous", func_data.line))
          print(string.format("[Coverage Verbose] - executed: %s, calls: %d", 
            tostring(func_data.executed), func_data.calls or 0))
        end
        
        -- Fix function execution check by verifying coverage of function's lines
        -- If any line in the function body is covered, the function was executed
        if not func_data.executed and func_data.line > 0 then
          local start_line = func_data.line
          local end_line = func_data.end_line or (start_line + 20) -- Reasonable default
          
          -- Look for any executed line in the function body
          for i = start_line, end_line do
            if file_data.lines and file_data.lines[i] then
              func_data.executed = true
              if is_test_file and config.verbose then
                print(string.format("[Coverage Verbose] - Function marked as executed based on line %d", i))
              end
              break
            end
          end
        end
        
        -- Add to functions info list
        functions_info[#functions_info + 1] = {
          name = func_data.name or "anonymous",
          line = func_data.line,
          end_line = func_data.end_line,
          calls = func_data.calls or 0,
          executed = func_data.executed == true, -- Ensure boolean value
          params = func_data.params or {}
        }
        
        -- Additional debug for key functions
        if is_test_file and config.verbose then
          print(string.format("[Coverage Verbose] Added function %s to report, executed=%s", 
            func_data.name or "anonymous",
            tostring(func_data.executed == true)))
        end
        
        if func_data.executed == true then
          covered_functions = covered_functions + 1
        end
      end
    end
    
    -- If code has no detected functions (which is rare), assume at least one global chunk
    if total_functions == 0 then
      total_functions = 1
      
      -- Add an implicit "main" function
      functions_info[1] = {
        name = "main",
        line = 1,
        end_line = file_data.line_count,
        calls = covered_lines > 0 and 1 or 0,
        executed = covered_lines > 0,
        params = {}
      }
      
      if covered_lines > 0 then
        covered_functions = 1
      end
    end
    
    -- Process block coverage information
    local total_blocks = 0
    local covered_blocks = 0
    local blocks_info = {}
    
    -- Check if we have logical chunks (blocks) from static analysis
    if file_data.logical_chunks then
      for block_id, block_data in pairs(file_data.logical_chunks) do
        total_blocks = total_blocks + 1
        
        -- Add to blocks info list
        table.insert(blocks_info, {
          id = block_id,
          type = block_data.type,
          start_line = block_data.start_line,
          end_line = block_data.end_line,
          executed = block_data.executed or false,
          parent_id = block_data.parent_id,
          branches = block_data.branches or {}
        })
        
        if block_data.executed then
          covered_blocks = covered_blocks + 1
        end
      end
    end
    
    -- If we have code_map from static analysis but no blocks processed yet,
    -- we need to get block data from the code_map
    if file_data.code_map and file_data.code_map.blocks and 
       (not file_data.logical_chunks or next(file_data.logical_chunks) == nil) then
      -- Ensure static analyzer is loaded
      if not static_analyzer then
        static_analyzer = require("lib.coverage.static_analyzer")
      end
      
      -- Get block data from static analyzer
      local blocks = file_data.code_map.blocks
      total_blocks = #blocks
      
      for _, block in ipairs(blocks) do
        -- Determine if block is executed based on line coverage
        local executed = false
        for line_num = block.start_line, block.end_line do
          if file_data.lines[line_num] then
            executed = true
            break
          end
        end
        
        -- Add to blocks info
        table.insert(blocks_info, {
          id = block.id,
          type = block.type,
          start_line = block.start_line,
          end_line = block.end_line,
          executed = executed,
          parent_id = block.parent_id,
          branches = block.branches or {}
        })
        
        if executed then
          covered_blocks = covered_blocks + 1
        end
      end
    end
    
    -- Calculate percentages - USING EXECUTABLE LINE COUNT, NOT TOTAL LINES
    local line_pct = total_executable_lines > 0 
                     and (covered_lines / total_executable_lines * 100) 
                     or 0
    
    local func_pct = total_functions > 0
                    and (covered_functions / total_functions * 100)
                    or 0
                    
    local block_pct = total_blocks > 0
                    and (covered_blocks / total_blocks * 100)
                    or 0
    
    -- Sort functions and blocks by line number for consistent reporting
    table.sort(functions_info, function(a, b) return a.line < b.line end)
    table.sort(blocks_info, function(a, b) return a.start_line < b.start_line end)
    
    -- Add verbose output to diagnose the coverage statistics
    if is_test_file and config.verbose then
      logger.verbose(string.format("File %s stats:", file_path))
      logger.verbose(string.format("  - Executable lines: %d", total_executable_lines))
      logger.verbose(string.format("  - Covered lines: %d", covered_lines))
      logger.verbose(string.format("  - Line coverage: %.1f%%", line_pct))
      logger.verbose(string.format("  - File data line_count: %s", tostring(file_data.line_count)))
      
      -- Print first 10 covered lines
      local covered_count = 0
      logger.verbose("  - First 10 covered lines:")
      for line_num, is_covered in pairs(file_data.lines) do
        if is_covered and covered_count < 10 then
          covered_count = covered_count + 1
          logger.verbose(string.format("    Line %d: covered", line_num))
        end
      end
      
      if covered_count == 0 then
        logger.verbose("    No covered lines found!")
      end
    end
    
    -- Update file stats - using executable line count, not total line count
    stats.files[file_path] = {
      total_lines = total_executable_lines, -- Use executable line count, not total lines
      covered_lines = covered_lines,
      total_functions = total_functions,
      covered_functions = covered_functions,
      total_blocks = total_blocks,
      covered_blocks = covered_blocks,
      functions = functions_info,
      blocks = blocks_info,
      discovered = file_data.discovered or false,
      line_coverage_percent = line_pct,
      function_coverage_percent = func_pct,
      block_coverage_percent = block_pct,
      passes_threshold = line_pct >= config.threshold,
      uses_static_analysis = file_data.code_map ~= nil
    }
    
    -- Update global block totals
    stats.total_blocks = stats.total_blocks + total_blocks
    stats.covered_blocks = stats.covered_blocks + covered_blocks
    
    -- Update global stats
    stats.total_files = stats.total_files + 1
    local is_covered = covered_lines > 0
    stats.covered_files = stats.covered_files + (is_covered and 1 or 0)
    stats.total_lines = stats.total_lines + total_executable_lines  -- Use executable lines count, not total
    stats.covered_lines = stats.covered_lines + covered_lines
    stats.total_functions = stats.total_functions + total_functions
    stats.covered_functions = stats.covered_functions + covered_functions
    
    if debug_this_file then
      print(string.format("DEBUG [Coverage] Global stats update for file %s:", file_path))
      print(string.format("  - Covered: %s", tostring(is_covered)))
      print(string.format("  - Added %d to total_lines", total_executable_lines))
      print(string.format("  - Added %d to covered_lines", covered_lines))
      print(string.format("  - Added %d to total_functions", total_functions))
      print(string.format("  - Added %d to covered_functions", covered_functions))
    end
  end
  
  -- Calculate overall percentages
  
  -- For line coverage, count only executable lines for more accurate metrics
  local executable_lines = 0
  for file_path, file_data in pairs(coverage_data.files) do
    if file_data.code_map then
      for line_num = 1, file_data.line_count or 0 do
        if static_analyzer.is_line_executable(file_data.code_map, line_num) then
          executable_lines = executable_lines + 1
        end
      end
    else
      -- If no code map, use the total lines as a fallback
      executable_lines = executable_lines + (file_data.line_count or 0)
    end
  end
  
  -- Use executable lines as denominator for more accurate percentage
  local total_lines_for_coverage = executable_lines > 0 and executable_lines or stats.total_lines
  local line_coverage_percent = total_lines_for_coverage > 0 
                              and (stats.covered_lines / total_lines_for_coverage * 100)
                              or 0
                               
  local function_coverage_percent = stats.total_functions > 0
                                   and (stats.covered_functions / stats.total_functions * 100)
                                   or 0
                                   
  local file_coverage_percent = stats.total_files > 0
                               and (stats.covered_files / stats.total_files * 100)
                               or 0
                               
  local block_coverage_percent = stats.total_blocks > 0
                                and (stats.covered_blocks / stats.total_blocks * 100)
                                or 0
  
  -- Calculate overall percentage (weighted) - include block coverage if available
  local overall_percent
  if stats.total_blocks > 0 and config.track_blocks then
    -- If blocks are tracked, give them equal weight with line coverage
    -- This emphasizes conditional execution paths for more accurate coverage metrics
    overall_percent = (line_coverage_percent * 0.35) + 
                      (function_coverage_percent * 0.15) +
                      (block_coverage_percent * 0.5)  -- Give blocks higher weight (50%)
  else
    -- Traditional weighting without block coverage
    overall_percent = (line_coverage_percent * 0.8) + (function_coverage_percent * 0.2)
  end
  
  -- Add summary to stats
  stats.summary = {
    total_files = stats.total_files,
    covered_files = stats.covered_files,
    total_lines = stats.total_lines,
    covered_lines = stats.covered_lines,
    total_functions = stats.total_functions,
    covered_functions = stats.covered_functions,
    total_blocks = stats.total_blocks,
    covered_blocks = stats.covered_blocks,
    line_coverage_percent = line_coverage_percent,
    function_coverage_percent = function_coverage_percent,
    file_coverage_percent = file_coverage_percent,
    block_coverage_percent = block_coverage_percent,
    overall_percent = overall_percent,
    threshold = config.threshold,
    passes_threshold = overall_percent >= (config.threshold or 0),
    using_static_analysis = config.use_static_analysis,
    tracking_blocks = config.track_blocks
  }
  
  -- Pass the original file data for source code display, including execution data
  stats.original_files = {}
  
  -- Copy the files data, ensuring _executed_lines is included for each file
  for file_path, file_data in pairs(coverage_data.files) do
    stats.original_files[file_path] = {
      lines = {},  -- Covered lines
      _executed_lines = {}, -- Just executed (but not necessarily covered) lines
      executable_lines = {},
      source = file_data.source,
      source_text = file_data.source_text,
      line_count = file_data.line_count,
      logical_chunks = file_data.logical_chunks,
      logical_conditions = file_data.logical_conditions
    }
    
    -- Copy line coverage data
    for line_num, is_covered in pairs(file_data.lines or {}) do
      stats.original_files[file_path].lines[line_num] = is_covered
    end
    
    -- Copy executable line data
    for line_num, is_executable in pairs(file_data.executable_lines or {}) do
      stats.original_files[file_path].executable_lines[line_num] = is_executable
    end
    
    -- Copy executed line data - this is crucial for our new distinction
    for line_num, was_executed in pairs(file_data._executed_lines or {}) do
      stats.original_files[file_path]._executed_lines[line_num] = was_executed
    end
  end
  
  -- Add debug flag to stats for HTML formatter
  stats.summary.debug = config.debug
  
  return stats
end

-- Access to raw coverage data for debugging
function M.get_raw_data()
  return debug_hook.get_coverage_data()
end

-- Generate coverage report
function M.report(format)
  -- Use reporting module for formatting
  local reporting = require("lib.reporting")
  
  -- Configure reporting module with our debug settings
  reporting.configure({
    debug = config.debug,
    verbose = config.verbose
  })
  
  -- Set up logging for the reporting module
  logging.configure_from_options("Reporting", config)
  
  local data = M.get_report_data()
  return reporting.format_coverage(data, format or "summary")
end

-- Save coverage report
function M.save_report(file_path, format)
  local reporting = require("lib.reporting")
  
  -- Configure reporting module with our debug settings
  reporting.configure({
    debug = config.debug,
    verbose = config.verbose
  })
  
  -- Set up logging for the reporting module
  logging.configure_from_options("Reporting", config)
  
  local data = M.get_report_data()
  return reporting.save_coverage_report(file_path, data, format or "html")
end

-- Debug dump
-- Check if a specific line was executed (not necessarily covered by tests)
function M.was_line_executed(file_path, line_num)
  return debug_hook.was_line_executed(file_path, line_num)
end

-- Check if a specific line was covered (validated by test assertions)
function M.was_line_covered(file_path, line_num)
  return debug_hook.was_line_covered(file_path, line_num)
end

-- Track line execution only (without marking as covered)
-- This is for manual instrumentation in cases where debug.sethook misses events
function M.track_execution(file_path, line_num)
  if not active or not config.enabled then
    return
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Ensure coverage_data is properly initialized
  local coverage_data = debug_hook.get_coverage_data()
  
  -- Create files table if it doesn't exist
  if not coverage_data.files then
    coverage_data.files = {}
  end
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    -- Initialize file data
    local line_count = 0
    local source_lines = {}
    local source_text = fs.read_file(file_path)
    
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
      executable_lines = {}       -- Whether each line is executable
    }
    
    -- Try to get a code map using the static analyzer during initialization
    if config.use_static_analysis and source_text then
      -- Lazy load the static analyzer
      local static_analyzer = require("lib.coverage.static_analyzer")
      
      -- Try to parse the file and generate a code map
      local ast, code_map = static_analyzer.parse_content(source_text, file_path)
      
      -- If successful, store the AST and code map for later use
      if ast and code_map then
        coverage_data.files[normalized_path].code_map = code_map
        coverage_data.files[normalized_path].ast = ast
        coverage_data.files[normalized_path].code_map_attempted = true
        
        -- Get executable lines map
        coverage_data.files[normalized_path].executable_lines = 
          static_analyzer.get_executable_lines(code_map)
        
        if config.debug then
          print("DEBUG [Coverage Static Analysis] Generated code map for " .. normalized_path .. 
                " during track_execution call")
        end
      end
    end
  end
  
  -- Ensure _executed_lines table exists
  if not coverage_data.files[normalized_path]._executed_lines then
    coverage_data.files[normalized_path]._executed_lines = {}
  end
  
  -- Mark as executed
  coverage_data.files[normalized_path]._executed_lines[line_num] = true
  
  -- Enhance block tracking - try to find which blocks this line belongs to
  if config.track_blocks and coverage_data.files[normalized_path].code_map then
    -- Lazily load the static analyzer
    local static_analyzer = require("lib.coverage.static_analyzer")
    
    -- Use the static analyzer to find which blocks contain this line
    local blocks_for_line = static_analyzer.get_blocks_for_line(
      coverage_data.files[normalized_path].code_map, 
      line_num
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
      
      -- Debug output
      if config.debug and config.verbose then
        print("DEBUG [Manual Block Tracking] Tracked block " .. block.id .. 
              " (" .. block.type .. ") at line " .. line_num .. 
              " in " .. normalized_path)
      end
    end
  end
  
  -- Check if this line is executable and mark it accordingly
  local is_executable = false
  
  -- Check if we have static analysis data to determine executability
  if coverage_data.files[normalized_path].code_map then
    -- Lazily load the static analyzer
    local static_analyzer = require("lib.coverage.static_analyzer")
    
    -- Use static analysis to determine if line is executable
    is_executable = static_analyzer.is_line_executable(
      coverage_data.files[normalized_path].code_map, 
      line_num
    )
  else
    -- Basic check - is this a comment?
    if coverage_data.files[normalized_path].source and 
       coverage_data.files[normalized_path].source[line_num] then
      local line_text = coverage_data.files[normalized_path].source[line_num]
      is_executable = line_text:match("^%s*%-%-") == nil -- Not a comment line
    else
      -- If no data available, assume executable (cautious approach)
      is_executable = true
    end
  end
  
  -- Mark as executable or non-executable
  if not coverage_data.files[normalized_path].executable_lines then
    coverage_data.files[normalized_path].executable_lines = {}
  end
  coverage_data.files[normalized_path].executable_lines[line_num] = is_executable
  
  -- Verbose output for execution tracking
  if config.verbose then
    logger.verbose(string.format("Tracked line %d in %s (executable=%s)", 
                   line_num, normalized_path, tostring(is_executable)))
  end
end

function M.debug_dump()
  local data = debug_hook.get_coverage_data()
  local stats = M.get_report_data().summary
  
  print("=== COVERAGE MODULE DEBUG DUMP ===")
  print("Mode: " .. (enhanced_mode and "Enhanced (C extensions)" or "Standard (Pure Lua)"))
  print("Active: " .. tostring(active))
  print("Configuration:")
  for k, v in pairs(config) do
    if type(v) == "table" then
      print("  " .. k .. ": " .. #v .. " items")
    else
      print("  " .. k .. ": " .. tostring(v))
    end
  end
  
  print("\nCoverage Stats:")
  print("  Files: " .. stats.covered_files .. "/" .. stats.total_files .. 
        " (" .. string.format("%.2f%%", stats.file_coverage_percent) .. ")")
  print("  Lines: " .. stats.covered_lines .. "/" .. stats.total_lines .. 
        " (" .. string.format("%.2f%%", stats.line_coverage_percent) .. ")")
  print("  Functions: " .. stats.covered_functions .. "/" .. stats.total_functions .. 
        " (" .. string.format("%.2f%%", stats.function_coverage_percent) .. ")")
  
  -- Show block coverage if available
  if stats.total_blocks > 0 then
    print("  Blocks: " .. stats.covered_blocks .. "/" .. stats.total_blocks .. 
          " (" .. string.format("%.2f%%", stats.block_coverage_percent) .. ")")
  end
  
  print("  Overall: " .. string.format("%.2f%%", stats.overall_percent))
  
  print("\nTracked Files (first 5):")
  local count = 0
  for file_path, file_data in pairs(data.files) do
    if count < 5 then
      local covered = 0
      for _ in pairs(file_data.lines) do covered = covered + 1 end
      
      print("  " .. file_path)
      print("    Lines: " .. covered .. "/" .. (file_data.line_count or 0))
      print("    Discovered: " .. tostring(file_data.discovered or false))
      
      count = count + 1
    else
      break
    end
  end
  
  if count == 5 and stats.total_files > 5 then
    print("  ... and " .. (stats.total_files - 5) .. " more files")
  end
  
  print("=== END DEBUG DUMP ===")
  return M
end

return M
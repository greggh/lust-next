--[[
Static analyzer for coverage module.
This module parses Lua code using our parser and generates code maps
that identify executable lines, functions, and code blocks.
]]

local M = {}

local parser = require("lib.tools.parser")
local filesystem = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Cache of parsed files to avoid reparsing
local file_cache = {}

-- Cache for multiline comment detection results
local multiline_comment_cache = {}

-- Line classification types
M.LINE_TYPES = {
  EXECUTABLE = "executable",  -- Line contains executable code
  NON_EXECUTABLE = "non_executable",  -- Line is non-executable (comments, whitespace, end keywords, etc.)
  FUNCTION = "function",  -- Line contains a function definition
  BRANCH = "branch",      -- Line contains a branch (if, while, etc.)
  END_BLOCK = "end_block" -- Line contains an end keyword for a block
}

-- Module configuration
local config = {
  control_flow_keywords_executable = true, -- Default to strict coverage
  debug = false,
  verbose = false
}

-- Create a logger for this module
local logger = logging.get_logger("StaticAnalyzer")

-- Initializes the static analyzer
function M.init(options)
  options = options or {}
  file_cache = {}
  
  -- Update config from options
  if options.control_flow_keywords_executable ~= nil then
    config.control_flow_keywords_executable = options.control_flow_keywords_executable
  end
  
  -- Propagate debug settings
  if options.debug ~= nil then
    config.debug = options.debug
  end
  
  if options.verbose ~= nil then
    config.verbose = options.verbose
  end
  
  -- Configure module logging level
  logging.configure_from_config("StaticAnalyzer")
  
  return M
end

-- Clear the file cache and multiline comment cache
function M.clear_cache()
  file_cache = {}
  multiline_comment_cache = {}
end

-- Multiline comment detection API
-- This centralizes the previously duplicated comment detection logic

-- Create a context for comment tracking
function M.create_multiline_comment_context()
  return {
    in_comment = false,
    state_stack = {},
    line_status = {} -- Map of line numbers to comment status
  }
end

-- Process a content string to find all multiline comments
function M.find_multiline_comments(content)
  -- Quick exit for empty content
  if not content or content == "" then
    return {}
  end

  -- Create a fresh context
  local context = M.create_multiline_comment_context()
  
  -- Split content into lines for processing
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  -- Process each line to mark comment status
  for i, line_text in ipairs(lines) do
    M.process_line_for_comments(line_text, i, context)
  end
  
  return context.line_status
end

-- Process a single line to determine if it's part of a multiline comment
-- This is the core function of the multiline comment detection system
function M.process_line_for_comments(line_text, line_num, context)
  -- Handle case where context isn't provided
  if not context then
    context = M.create_multiline_comment_context()
  end
  
  -- Track if this line was initially in a comment
  local was_in_comment = context.in_comment
  
  -- Find all comment markers in this line
  local comment_markers = {}
  
  -- Look for --[[ style comment starts
  local pos = 1
  while true do
    local start_pos = line_text:find("%-%-%[%[", pos)
    if not start_pos then break end
    table.insert(comment_markers, {pos = start_pos, type = "start", style = "dash"})
    pos = start_pos + 4
  end
  
  -- Look for [[ style markers (only if not in string context)
  -- Note: This is simplified and doesn't handle string context perfectly
  pos = 1
  while true do
    local start_pos = line_text:find("%[%[", pos)
    if not start_pos then break end
    
    -- Check if this is likely a string rather than comment
    -- (very basic heuristic - could be improved)
    local prefix = line_text:sub(1, start_pos-1)
    if not prefix:match("['\"]%s*$") and 
       not prefix:match("=%s*$") and 
       not prefix:match("return%s+$") then
      table.insert(comment_markers, {pos = start_pos, type = "start", style = "bracket"})
    end
    pos = start_pos + 2
  end
  
  -- Look for ]] markers
  pos = 1
  while true do
    local end_pos = line_text:find("%]%]", pos)
    if not end_pos then break end
    table.insert(comment_markers, {pos = end_pos, type = "end"})
    pos = end_pos + 2
  end
  
  -- Sort markers by position to process them in order
  table.sort(comment_markers, function(a, b) return a.pos < b.pos end)
  
  -- Process markers in order with proper nesting
  local changed_in_this_line = false
  
  for _, marker in ipairs(comment_markers) do
    if marker.type == "start" and not context.in_comment then
      context.in_comment = true
      table.insert(context.state_stack, marker.style) -- Push style onto stack
      changed_in_this_line = true
    elseif marker.type == "end" and context.in_comment then
      -- Only pop if we have items on the stack
      if #context.state_stack > 0 then
        table.remove(context.state_stack) -- Pop the stack
        
        -- Only clear in_comment flag if stack is empty
        if #context.state_stack == 0 then
          context.in_comment = false
        end
      end
      changed_in_this_line = true
    end
  end
  
  -- Determine if this line is a comment based on its state
  local is_comment_line = was_in_comment or context.in_comment
  
  -- Also check for single-line comments (--) if not already marked as comment
  if not is_comment_line then
    -- Check for single line comments, but ignore any code before the comment
    local comment_pos = line_text:find("%-%-")
    if comment_pos then
      -- Check if this is a multiline comment start (--[[)
      local ml_start = line_text:match("^%s*%-%-%[%[", comment_pos)
      if not ml_start then
        -- This is a regular single-line comment
        is_comment_line = true
      end
    end
    
    -- Also check for empty lines
    if not is_comment_line and line_text:match("^%s*$") then
      is_comment_line = true
    end
  end
  
  -- Store the result in the context
  context.line_status[line_num] = is_comment_line
  
  return is_comment_line
end

-- Update the multiline comment cache for a file
function M.update_multiline_comment_cache(file_path)
  if not file_path then
    logger.debug("Missing file path for multiline comment detection")
    return false
  end

  -- Normalize the path with proper error handling
  local normalized_path, norm_err = error_handler.safe_io_operation(
    function() return filesystem.normalize_path(file_path) end,
    file_path,
    {operation = "update_multiline_comment_cache"}
  )
  
  if not normalized_path then
    logger.debug("Failed to normalize path: " .. error_handler.format_error(norm_err))
    return false
  end
  
  -- Skip if the file doesn't exist
  local file_exists, exists_err = error_handler.safe_io_operation(
    function() return filesystem.file_exists(normalized_path) end,
    normalized_path,
    {operation = "update_multiline_comment_cache"}
  )
  
  if not file_exists then
    return false
  end
  
  -- Read the file content with proper error handling
  local content, read_err = error_handler.safe_io_operation(
    function() return filesystem.read_file(normalized_path) end,
    normalized_path,
    {operation = "update_multiline_comment_cache"}
  )
  
  if not content then
    logger.debug({
      message = "Failed to read file for multiline comment detection",
      file_path = normalized_path,
      error = error_handler.format_error(read_err)
    })
    return false
  end
  
  -- Process the content to find multiline comments with proper error handling
  local comment_status, comment_err = error_handler.try(function()
    return M.find_multiline_comments(content)
  end)
  
  if not comment_status then
    logger.debug({
      message = "Failed to process multiline comments",
      file_path = normalized_path,
      error = error_handler.format_error(comment_err)
    })
    return false
  end
  
  -- Cache the results
  multiline_comment_cache[normalized_path] = comment_status
  
  return true
end

-- Check if a specific line is in a multiline comment
function M.is_in_multiline_comment(file_path, line_num, content)
  -- Handle case where content is provided directly (for AST-based analysis)
  if content and line_num and line_num > 0 then
    -- Process content directly to find multiline comments
    local context = M.create_multiline_comment_context()
    
    -- Split content into lines for processing
    local lines = {}
    for line in (content .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
      table.insert(lines, line)
    end
    
    -- Process each line to mark comment status up to our target line
    for i = 1, math.min(line_num, #lines) do
      M.process_line_for_comments(lines[i], i, context)
    end
    
    -- Return the status for our target line
    return context.line_status[line_num] or false
  end
  
  -- Traditional file-based approach
  -- Validate inputs
  if not file_path or not line_num or line_num <= 0 then
    return false
  end
  
  -- Normalize the path with proper error handling
  local normalized_path, norm_err = error_handler.safe_io_operation(
    function() return filesystem.normalize_path(file_path) end,
    file_path,
    {operation = "is_in_multiline_comment"}
  )
  
  if not normalized_path then
    logger.debug("Failed to normalize path: " .. error_handler.format_error(norm_err))
    return false
  end
  
  -- Check if we have cached results
  if not multiline_comment_cache[normalized_path] then
    -- Update the cache if needed
    local success, update_err = error_handler.try(function()
      return M.update_multiline_comment_cache(normalized_path)
    end)
    
    if not success or not update_err then
      return false
    end
  end
  
  -- Check the cached status with type safety
  if multiline_comment_cache[normalized_path] and 
     type(multiline_comment_cache[normalized_path]) == "table" and
     multiline_comment_cache[normalized_path][line_num] ~= nil then
    return multiline_comment_cache[normalized_path][line_num]
  end
  
  -- Default to false if no status found
  return false
end

-- Parse a Lua file and return its AST with enhanced protection
function M.parse_file(file_path)
  -- Check cache first for quick return
  if file_cache[file_path] then
    return file_cache[file_path].ast, file_cache[file_path].code_map
  end

  -- Verify file exists
  if not filesystem.file_exists(file_path) then
    local err = error_handler.io_error(
      "File not found: " .. file_path,
      {
        file_path = file_path,
        operation = "parse_file"
      }
    )
    logger.debug("File not found: " .. error_handler.format_error(err))
    return nil, err
  end

  -- Skip testing-related files to improve performance
  if file_path:match("_test%.lua$") or 
     file_path:match("_spec%.lua$") or
     file_path:match("/tests/") or
     file_path:match("/test/") or
     file_path:match("/specs/") or
     file_path:match("/spec/") then
    return nil, error_handler.validation_error(
      "Test file excluded from static analysis",
      {
        file_path = file_path,
        operation = "parse_file",
        reason = "performance optimization"
      }
    )
  end
  
  -- Skip already known problematic file types
  if file_path:match("%.min%.lua$") or
     file_path:match("/vendor/") or
     file_path:match("/deps/") or
     file_path:match("/node_modules/") then
    return nil, error_handler.validation_error(
      "Excluded dependency from static analysis",
      {
        file_path = file_path,
        operation = "parse_file",
        reason = "excluded dependency"
      }
    )
  end
  
  -- Check file size before parsing - INCREASED the limit to 1MB
  -- This ensures we can handle reasonable-sized source files
  local file_size, file_size_err = error_handler.safe_io_operation(
    function() return filesystem.get_file_size(file_path) end,
    file_path,
    {operation = "parse_file"}
  )
  
  if not file_size then
    logger.debug("Failed to get file size: " .. error_handler.format_error(file_size_err))
    return nil, file_size_err
  end
  
  if file_size > 1024000 then -- 1MB size limit
    logger.debug({
      message = "Skipping static analysis for large file",
      file_path = file_path,
      file_size_kb = math.floor(file_size/1024),
      limit_kb = 1024
    })
    
    return nil, error_handler.validation_error(
      "File too large for analysis: " .. file_path,
      {
        file_path = file_path,
        file_size = file_size,
        limit = 1024000,
        operation = "parse_file"
      }
    )
  end

  -- Read the file content with proper error handling
  local content, read_err = error_handler.safe_io_operation(
    function() return filesystem.read_file(file_path) end,
    file_path,
    {operation = "parse_file"}
  )
  
  if not content then
    logger.debug("Failed to read file: " .. error_handler.format_error(read_err))
    return nil, read_err
  end

  -- Skip if content is too large (use smaller limit for safety)
  if #content > 200000 then -- 200KB content limit - reduced from 500KB
    logger.debug({
      message = "Skipping static analysis for large content",
      file_path = file_path,
      content_size_kb = math.floor(#content/1024),
      limit_kb = 200,
      operation = "parse_file"
    })
    
    return nil, error_handler.validation_error(
      "File content too large for analysis",
      {
        file_path = file_path,
        content_size = #content,
        limit = 200000,
        operation = "parse_file"
      }
    )
  end
  
  -- Quick check for deeply nested structures 
  local max_depth, current_depth = 0, 0
  
  local success, depth_result = error_handler.try(function()
    for i = 1, #content do
      local c = content:sub(i, i)
      if c == "{" or c == "(" or c == "[" then
        current_depth = current_depth + 1
        if current_depth > max_depth then
          max_depth = current_depth
        end
      elseif c == "}" or c == ")" or c == "]" then
        current_depth = math.max(0, current_depth - 1)
      end
    end
    return max_depth
  end)
  
  if not success then
    return nil, error_handler.runtime_error(
      "Error checking nesting depth",
      {
        file_path = file_path,
        operation = "parse_file"
      },
      depth_result
    )
  end
  
  max_depth = depth_result
  
  -- Skip files with excessively deep nesting
  if max_depth > 100 then
    logger.debug({
      message = "Skipping static analysis for deeply nested file",
      file_path = file_path,
      nesting_depth = max_depth,
      depth_limit = 100,
      operation = "parse_file"
    })
    
    return nil, error_handler.validation_error(
      "File has too deeply nested structures",
      {
        file_path = file_path,
        nesting_depth = max_depth,
        limit = 100,
        operation = "parse_file"
      }
    )
  end

  -- Finally parse the content with all our protections in place
  return M.parse_content(content, file_path)
end

-- Count lines in the content
local function count_lines(content)
  local count = 1
  for _ in content:gmatch("\n") do
    count = count + 1
  end
  return count
end

-- Create efficient line mappings once instead of repeatedly traversing content
local line_position_cache = {}

-- Pre-process content into line mappings for O(1) lookups
local function build_line_mappings(content)
  -- Check if we've already processed this content
  local content_hash = tostring(#content) -- Use content length as simple hash
  if line_position_cache[content_hash] then
    return line_position_cache[content_hash]
  end
  
  -- Build the mappings in one pass
  local mappings = {
    line_starts = {1}, -- First line always starts at position 1
    line_ends = {},
    pos_to_line = {} -- LUT for faster position to line lookups
  }
  
  -- Process the content in one pass
  local line_count = 1
  for i = 1, #content do
    -- Create a sparse position-to-line lookup table (every 100 chars)
    if i % 100 == 0 then
      mappings.pos_to_line[i] = line_count
    end
    
    if content:sub(i, i) == "\n" then
      -- Record end of current line
      mappings.line_ends[line_count] = i - 1 -- Exclude the newline
      
      -- Record start of next line
      line_count = line_count + 1
      mappings.line_starts[line_count] = i + 1
    end
  end
  
  -- Handle the last line
  if not mappings.line_ends[line_count] then
    mappings.line_ends[line_count] = #content
  end
  
  -- Store in cache
  line_position_cache[content_hash] = mappings
  return mappings
end

-- Get the line number for a position in the content - using cached mappings
local function get_line_for_position(content, pos)
  -- Build mappings if needed
  local mappings = build_line_mappings(content)
  
  -- Use pos_to_line LUT for quick estimation
  local start_line = 1
  for check_pos, line in pairs(mappings.pos_to_line) do
    if check_pos <= pos then
      start_line = line
    else
      break
    end
  end
  
  -- Linear search only from the estimated line
  for line = start_line, #mappings.line_starts do
    local line_start = mappings.line_starts[line]
    local line_end = mappings.line_ends[line] or #content
    
    if line_start <= pos and pos <= line_end + 1 then
      return line
    elseif line_start > pos then
      -- We've gone past the position, return the previous line
      return line - 1
    end
  end
  
  -- Fallback
  return #mappings.line_starts
end

-- Get the start position of a line in the content - O(1) using cached mappings
local function getLineStartPos(content, line_num)
  -- Build mappings if needed
  local mappings = build_line_mappings(content)
  
  -- Direct lookup
  return mappings.line_starts[line_num] or (#content + 1)
end

-- Get the end position of a line in the content - O(1) using cached mappings
local function getLineEndPos(content, line_num)
  -- Build mappings if needed
  local mappings = build_line_mappings(content)
  
  -- Direct lookup
  return mappings.line_ends[line_num] or #content
end

-- Create lookup tables for tag checking (much faster than iterating arrays)
local EXECUTABLE_TAGS = {
  Call = true, Invoke = true, Set = true, Local = true, Return = true,
  If = true, While = true, Repeat = true, Fornum = true, Forin = true,
  Break = true, Goto = true
}

local NON_EXECUTABLE_TAGS = {
  Block = true, Label = true, NameList = true, VarList = true, ExpList = true,
  Table = true, Pair = true, Id = true, String = true, Number = true,
  Boolean = true, Nil = true, Dots = true
}

-- Simple classification for when full AST analysis isn't available
function M.classify_line_simple(line_text, options)
  -- Handle nil input
  if not line_text then
    return false
  end
  
  options = options or {}
  
  -- Strip whitespace for easier pattern matching
  local trimmed = line_text:match("^%s*(.-)%s*$") or ""
  
  -- Empty lines are not executable
  if trimmed == "" then
    return false
  end
  
  -- Check for comments (entire line is comment)
  if trimmed:match("^%-%-") then
    return false
  end
  
  -- Check for multi-line string content (not the declaration line)
  -- This is a simplistic check - AST-based analysis is more accurate
  if not trimmed:match("^[\"'%[]") and not trimmed:match("[\"'%]]%s*$") and 
     not trimmed:match("=") and not trimmed:match("%(") and not trimmed:match("%)") then
    -- Might be content of a multi-line string
    return false
  end
  
  -- Control flow keywords
  local is_control_flow_keyword = false
  for _, pattern in ipairs({
    "^end%s*$",       -- Standalone end keyword
    "^end[,)]",       -- End followed by comma or closing parenthesis
    "^else%s*$",      -- Standalone else keyword
    "^until%s",       -- until lines
    "^[]}]%s*$",      -- Closing brackets/braces
    "^then%s*$",      -- Standalone then keyword
    "^do%s*$",        -- Standalone do keyword
    "^repeat%s*$",    -- Standalone repeat keyword
    "^elseif%s*$"     -- Standalone elseif keyword
  }) do
    if trimmed:match(pattern) then
      is_control_flow_keyword = true
      break
    end
  end
  
  if is_control_flow_keyword then
    -- Use the configuration to decide if control flow keywords are executable
    local use_config = options.control_flow_keywords_executable
    if use_config == nil then
      -- Default to the module config if not specified in options
      use_config = config.control_flow_keywords_executable
    end
    return use_config
  end
  
  -- Common executable line patterns
  for _, pattern in ipairs({
    "=",                 -- Assignment
    "local%s+",          -- Local declaration
    "function",          -- Function declaration
    "return",            -- Return statement
    "if%s+",             -- If statement
    "for%s+",            -- For loop
    "while%s+",          -- While loop
    "repeat%s+",         -- Repeat loop
    "%w+%s*%(.-%)%s*$",  -- Function call end
    "%w+[%.:]%w+",       -- Method/property access
    "break",             -- Break statement
    "goto%s+",           -- Goto statement
    "require%s*%("       -- Require statement
  }) do
    if trimmed:match(pattern) then
      return true
    end
  end
  
  -- Default to true for anything else - we assume it's executable unless proven otherwise
  -- This is a conservative approach to avoid missing coverage
  return true
end

-- Determine if a line is executable based on AST nodes that intersect with it
-- With optimized lookup tables and time limit
local function is_line_executable(nodes, line_num, content)
  -- Quick check for empty or nil content
  if not content or #content == 0 then
    return false
  end
  
  -- Get the actual line text
  local line_text = nil
  local line_mapping = build_line_mappings(content)
  if line_mapping and line_mapping.line_starts[line_num] and line_mapping.line_ends[line_num] then
    local start_pos = line_mapping.line_starts[line_num]
    local end_pos = line_mapping.line_ends[line_num]
    if start_pos and end_pos and start_pos <= #content and end_pos <= #content then
      line_text = content:sub(start_pos, end_pos)
    end
  end
  
  -- If we couldn't extract the line text properly, use the content:match approach
  if not line_text then
    local all_lines = {}
    for l in (content .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
      table.insert(all_lines, l)
    end
    line_text = all_lines[line_num] or ""
  end
  
  -- Check if line is inside a multiline comment
  if M.is_in_multiline_comment(nil, line_num, content) then
    return false
  end
  
  -- Check for single-line comments or empty lines
  if line_text:match("^%s*$") or line_text:match("^%s*%-%-") then
    return false
  end
  
  -- Check for lines that only have comments
  local code_part = line_text:match("^(.-)%s*%-%-%s")
  if code_part and code_part:match("^%s*$") then
    return false
  end
  
  -- Check if this is a control flow keyword that should be executable
  if config.control_flow_keywords_executable then
    local trimmed = line_text:match("^%s*(.-)%s*$") or ""
    
    -- Check if this line matches a control flow keyword pattern
    for _, pattern in ipairs({
      "^%s*end%s*$",      -- Standalone end keyword
      "^%s*end[,%)]",     -- End followed by comma or closing parenthesis
      "^%s*end.*%-%-%s+", -- End followed by comment
      "^%s*else%s*$",     -- Standalone else keyword
      "^%s*until%s",      -- until lines (the condition is executable, not the keyword)
      "^%s*[%]}]%s*$",    -- Closing brackets/braces
      "^%s*then%s*$",     -- Standalone then keyword
      "^%s*do%s*$",       -- Standalone do keyword
      "^%s*repeat%s*$",   -- Standalone repeat keyword
      "^%s*elseif%s*$"    -- Standalone elseif keyword
    }) do
      if trimmed:match(pattern) then
        -- This is a control flow keyword and config says they're executable
        return true
      end
    end
  end
  
  -- Multi-line string detection
  -- Check if we're in a multi-line string (not the declaration line)
  local in_multiline_string = false
  for i = 1, line_num - 1 do
    local prev_line = content:match("[^\r\n]*", i) or ""
    if prev_line:match("%[%[") and not prev_line:match("%]%]") then
      -- A multi-line string started and didn't end
      in_multiline_string = true
    elseif prev_line:match("%]%]") and in_multiline_string then
      -- The multi-line string ended
      in_multiline_string = false
    end
  end
  
  if in_multiline_string and not line_text:match("%]%]") then
    -- Line is inside a multi-line string and doesn't end it
    return false
  elseif in_multiline_string and line_text:match("%]%]") then
    -- Line ends a multi-line string
    local after_closing = line_text:match("%]%](.*)$")
    return after_closing and not after_closing:match("^%s*$") and not after_closing:match("^%s*%-%-")
  end
  
  -- Add time limit protection
  local start_time = os.clock()
  local MAX_ANALYSIS_TIME = 0.5 -- 500ms max for this function
  local node_count = 0
  local MAX_NODES = 10000 -- Maximum number of nodes to process
  
  for _, node in ipairs(nodes) do
    -- Check processing limits
    node_count = node_count + 1
    if node_count > MAX_NODES then
      if logger.is_debug_enabled() then
        logger.debug({
          message = "Node limit reached in is_line_executable",
          node_count = node_count,
          max_nodes = MAX_NODES,
          operation = "is_line_executable"
        })
      end
      return false
    end
    
    if node_count % 1000 == 0 and os.clock() - start_time > MAX_ANALYSIS_TIME then
      if logger.is_debug_enabled() then
        logger.debug({
          message = "Time limit reached in is_line_executable",
          elapsed_time = os.clock() - start_time,
          max_time = MAX_ANALYSIS_TIME,
          operation = "is_line_executable",
          node_count = node_count
        })
      end
      return false
    end
    
    -- Skip nodes without position info
    if not node.pos or not node.end_pos then
      goto continue
    end

    -- Fast lookups using tables instead of loops
    local is_executable = EXECUTABLE_TAGS[node.tag] or false
    local is_non_executable = NON_EXECUTABLE_TAGS[node.tag] or false
    
    -- Skip explicit non-executable nodes
    if is_non_executable and not is_executable then
      goto continue
    end
    
    -- Function definitions are special - they're executable at the definition line
    if node.tag == "Function" then
      local node_start_line = get_line_for_position(content, node.pos)
      if node_start_line == line_num then
        return true
      end
      goto continue
    end
    
    -- Function declarations (local function name() or function name()) are executable
    if node.tag == "Localrec" or node.tag == "Set" then
      local node_start_line = get_line_for_position(content, node.pos)
      if node_start_line == line_num then
        -- Check if this is a function assignment
        if node[2] and node[2].tag == "Function" then
          return true
        end
      end
    end

    -- Check if this node spans the line
    local node_start_line = get_line_for_position(content, node.pos)
    local node_end_line = get_line_for_position(content, node.end_pos)
    
    if node_start_line <= line_num and node_end_line >= line_num then
      -- Check for nodes that might contain non-executable parts
      if node.tag == "String" then
        -- Multi-line strings - only the declaration line is executable
        if node_start_line < line_num and node_end_line > line_num then
          return false
        end
      end
      return true
    end

    ::continue::
  end
  
  return false
end

-- Parse Lua code and return its AST with improved timeout protection
function M.parse_content(content, file_path)
  -- Use cache if available
  if file_path and file_cache[file_path] then
    return file_cache[file_path].ast, file_cache[file_path].code_map
  end

  -- Safety limit for content size
  if #content > 600000 then -- 600KB limit (increased from 300KB)
    return nil, error_handler.validation_error(
      "Content too large for parse_content: " .. (#content/1024) .. "KB",
      {
        content_size = #content,
        limit = 600000,
        file_path = file_path or "inline",
        operation = "parse_content"
      }
    )
  end
  
  -- Start timing
  local start_time = os.clock()
  local MAX_PARSE_TIME = 60.0 -- 60 second total parse time limit (increased from 1 second)
  
  -- Run parsing with proper error handling
  local ast, parse_err
  local success, result = error_handler.try(function()
    local ast_result, err = parser.parse(content, file_path or "inline")
    
    if os.clock() - start_time > MAX_PARSE_TIME then
      return nil, error_handler.timeout_error(
        "Parse time limit exceeded",
        {
          max_time = MAX_PARSE_TIME,
          elapsed_time = os.clock() - start_time,
          file_path = file_path or "inline",
          operation = "parse_content"
        }
      )
    end
    
    if not ast_result then
      return nil, error_handler.parse_error(
        "Parse error: " .. (err or "unknown error"),
        {
          file_path = file_path or "inline",
          operation = "parse_content"
        },
        err
      )
    end
    
    return ast_result
  end)
  
  -- Handle errors from try
  if not success then
    logger.debug("Parser exception: " .. error_handler.format_error(result))
    return nil, result
  end
  
  ast = result
  
  -- Generate code map from the AST with time limit
  local code_map
  success, result = error_handler.try(function()
    -- Check time again before code map generation
    if os.clock() - start_time > MAX_PARSE_TIME then
      return nil, error_handler.timeout_error(
        "Code map time limit exceeded",
        {
          max_time = MAX_PARSE_TIME,
          elapsed_time = os.clock() - start_time,
          file_path = file_path or "inline",
          operation = "generate_code_map"
        }
      )
    end
    
    local map_result = M.generate_code_map(ast, content)
    if not map_result then
      return nil, error_handler.runtime_error(
        "Code map generation failed",
        {
          file_path = file_path or "inline",
          operation = "generate_code_map"
        }
      )
    end
    
    return map_result
  end)
  
  -- Handle errors from code map generation
  if not success then
    logger.debug("Code map exception: " .. error_handler.format_error(result))
    return nil, result
  end
  
  code_map = result
  
  -- Cache the results if we have a path
  if file_path then
    file_cache[file_path] = {
      ast = ast,
      code_map = code_map
    }
  end

  return ast, code_map
end

-- Collect all AST nodes in a table with optimization to avoid deep recursion
local function collect_nodes(ast, nodes)
  nodes = nodes or {}
  local to_process = {ast}
  local processed = 0
  
  while #to_process > 0 do
    local current = table.remove(to_process)
    processed = processed + 1
    
    if type(current) == "table" then
      if current.tag then
        table.insert(nodes, current)
      end
      
      -- Add numerical children to processing queue
      for k, v in pairs(current) do
        if type(k) == "number" then
          table.insert(to_process, v)
        end
      end
    end
    
    -- Performance safety - if we've processed too many nodes, break
    if processed > 100000 then
      if logger.is_debug_enabled() then
        logger.debug({
          message = "Node collection limit reached",
          processed_nodes = processed,
          limit = 100000,
          operation = "collect_nodes"
        })
      end
      break
    end
  end
  
  return nodes
end

-- Extract full identifier from an Index node, handling nested table access
local function extract_full_identifier(node)
  if not node or type(node) ~= "table" then
    return nil
  end
  
  -- Handle direct identifiers
  if node.tag == "Id" then
    return node[1]
  end
  
  -- Handle table indexes (a.b)
  if node.tag == "Index" then
    local base_name = extract_full_identifier(node[1])
    if not base_name then return nil end
    
    -- Handle string keys 
    if node[2].tag == "String" then
      -- Check if this is a method call (using colon syntax)
      if node.is_method then
        return base_name .. ":" .. node[2][1]
      else
        return base_name .. "." .. node[2][1]
      end
    end
    
    -- Handle other key types (less common)
    if node[2].tag == "Id" then
      return base_name .. "." .. node[2][1]
    end
  end
  
  return nil
end

-- Extract full identifier from an Index node
local function extract_full_identifier(node)
  if not node or type(node) ~= "table" then
    return nil
  end
  
  -- Handle direct identifiers
  if node.tag == "Id" then
    return node[1]
  end
  
  -- Handle table indexes (a.b)
  if node.tag == "Index" then
    local base_name
    
    -- Check if base is an identifier or another index
    if node[1].tag == "Id" then
      base_name = node[1][1]
    else
      base_name = extract_full_identifier(node[1])
    end
    
    if not base_name then return nil end
    
    -- Handle string keys 
    if node[2].tag == "String" then
      -- Check if this is a method (with colon)
      local method_name = node[2][1]
      
      -- Check for explicitly marked method node or colon in the name
      if node.is_method or method_name:find(":", 1, true) then
        return base_name .. ":" .. method_name:gsub(":", "")
      else
        return base_name .. "." .. method_name
      end
    end
    
    -- Handle other key types (less common)
    if node[2].tag == "Id" then
      return base_name .. "." .. node[2][1]
    end
  end
  
  return nil
end

-- Detect method declarations in the AST 
local function detect_method_declarations(ast)
  if type(ast) ~= "table" then 
    return 
  end
  
  local to_process = {ast}
  local processed = 0
  
  while #to_process > 0 do
    local current = table.remove(to_process)
    processed = processed + 1
    
    if type(current) == "table" then
      -- Look for common method declaration patterns
      
      -- Pattern 1: function obj:method()
      if current.tag == "Set" and current[1].tag == "VarList" and current[2].tag == "ExpList" then
        for i, var in ipairs(current[1]) do
          if var.tag == "Index" and var[1].tag == "Id" and var[2].tag == "String" then
            -- Check for colon in method name or if first parameter is 'self'
            local method_name = var[2][1]
            if method_name:find(":", 1, true) or
               (current[2][i] and current[2][i].tag == "Function" and 
                current[2][i][1] and current[2][i][1].tag == "ParList" and
                current[2][i][1][1] and current[2][i][1][1].tag == "Id" and
                current[2][i][1][1][1] == "self") then
              
              -- Mark this as a method declaration
              var.is_method = true
              
              -- If there's a colon in name, clean it
              if method_name:find(":", 1, true) then
                var[2][1] = method_name:gsub(":", "")
              end
            end
          end
        end
      end
      
      -- Add children to processing queue
      for k, v in pairs(current) do
        if type(k) == "number" then
          table.insert(to_process, v)
        end
      end
    end
    
    -- Safety check
    if processed > 100000 then break end
  end
end

-- Find all function definitions in the AST using non-recursive approach
local function find_functions(ast, functions, context)
  functions = functions or {}
  context = context or {}
  
  -- Pre-process to detect method declarations 
  detect_method_declarations(ast)
  
  local to_process = {ast}
  local processed = 0
  local function_count = 0
  
  while #to_process > 0 do
    local current = table.remove(to_process)
    processed = processed + 1
    
    if type(current) == "table" then
      -- Special handling for function definitions with name extraction
      if current.tag == "Set" and #current >= 2 and current[1].tag == "VarList" and current[2].tag == "ExpList" then
        -- Check if the right side contains function definition(s)
        for i, expr in ipairs(current[2]) do
          if expr.tag == "Function" then
            -- Get function name from the left side
            if current[1][i] and current[1][i].tag == "Id" then
              -- Simple variable assignment (e.g., `foo = function()`)
              expr.name = current[1][i][1]
              expr.type = "global" -- Global function
            elseif current[1][i] and current[1][i].tag == "Index" then
              -- Handle complex name extraction (table.field, module.function, obj:method)
              local full_name = extract_full_identifier(current[1][i])
              
              -- Check for method syntax (obj:method)
              if full_name and full_name:find(":", 1, true) then
                expr.name = full_name
                expr.type = "method" -- Method definition
              elseif full_name then
                expr.name = full_name
                expr.type = "module" -- Module/table field
              else
                -- Fallback for complex cases
                expr.name = "anonymous_" .. function_count
              end
            else
              -- Unknown pattern, create a generic name
              expr.name = "anonymous_" .. function_count
            end
            
            function_count = function_count + 1
            
            -- Extract parameter information
            if expr[1] and expr[1].tag == "ParList" then
              expr.params = {}
              expr.has_varargs = false
              
              for p = 1, #expr[1] do
                if expr[1][p] == "..." then
                  table.insert(expr.params, "...")
                  expr.has_varargs = true
                elseif expr[1][p].tag == "Id" then
                  table.insert(expr.params, expr[1][p][1])
                end
              end
            end
            
            -- Try to extract function positions
            if expr.pos and expr.endpos then
              -- If we have line mapping, convert positions to line numbers
              if context and context.lines then
                -- Look for line mapping
                local line_start, line_end
                
                -- Try direct line mapping first
                if context.pos_to_line and context.pos_to_line[expr.pos] then
                  line_start = context.pos_to_line[expr.pos]
                end
                
                if context.pos_to_line and context.pos_to_line[expr.endpos] then
                  line_end = context.pos_to_line[expr.endpos]
                end
                
                -- Fallback to computing line numbers from content
                if not line_start or not line_end then
                  if context.content then
                    line_start = get_line_for_position(context.content, expr.pos)
                    line_end = get_line_for_position(context.content, expr.endpos)
                  end
                end
                
                -- Store the line positions
                if line_start then
                  expr.line_start = line_start
                end
                
                if line_end then
                  expr.line_end = line_end
                end
              end
            end
            
            table.insert(functions, expr)
          end
        end
      elseif current.tag == "Localrec" and #current >= 2 and current[1].tag == "Id" and current[2].tag == "Function" then
        -- Handle local function definition (e.g., `local function foo()`)
        current[2].name = current[1][1]  -- Copy the name to the function
        current[2].type = "local" -- Local function
        
        -- Extract parameter information
        if current[2][1] and current[2][1].tag == "ParList" then
          current[2].params = {}
          current[2].has_varargs = false
          
          for p = 1, #current[2][1] do
            if current[2][1][p] == "..." then
              table.insert(current[2].params, "...")
              current[2].has_varargs = true
            elseif current[2][1][p].tag == "Id" then
              table.insert(current[2].params, current[2][1][p][1])
            end
          end
        end
        
        -- Try to extract function end position
        if current[2].pos and current[2].endpos then
          -- Convert pos/endpos to line numbers if available
          local pos_to_line = context.pos_to_line
          if pos_to_line then
            current[2].line_start = pos_to_line[current[2].pos]
            current[2].line_end = pos_to_line[current[2].endpos]
          end
        end
        
        table.insert(functions, current[2])
        function_count = function_count + 1
      elseif current.tag == "Function" then
        -- Standalone function (e.g., anonymous, or already part of a larger structure)
        if not current.name then
          current.name = "<anonymous>"
        end
        
        -- Extract parameter information (if not already extracted)
        if not current.params and current[1] and current[1].tag == "ParList" then
          current.params = {}
          current.has_varargs = false
          
          for p = 1, #current[1] do
            if current[1][p] == "..." then
              table.insert(current.params, "...")
              current.has_varargs = true
            elseif current[1][p].tag == "Id" then
              table.insert(current.params, current[1][p][1])
            end
          end
        end
        
        -- Try to extract function end position (if not already extracted)
        if not current.line_end and current.pos and current.endpos then
          -- Convert pos/endpos to line numbers if available
          local pos_to_line = context.pos_to_line
          if pos_to_line then
            current.line_start = pos_to_line[current.pos]
            current.line_end = pos_to_line[current.endpos]
          end
        end
        
        table.insert(functions, current)
        function_count = function_count + 1
      end
      
      -- Add numerical children to processing queue
      for k, v in pairs(current) do
        if type(k) == "number" then
          table.insert(to_process, v)
        end
      end
    end
    
    -- Performance safety - if we've processed too many nodes, break
    if processed > 100000 then
      logger.debug("Function finding limit reached (100,000 nodes)")
      break
    end
  end
  
  return functions
end

-- Define branch node tags for block detection
local BRANCH_TAGS = {
  If = true,     -- if statements
  While = true,  -- while loops
  Repeat = true, -- repeat-until loops
  Fornum = true, -- for i=1,10 loops
  Forin = true   -- for k,v in pairs() loops
}

-- Tags that indicate code blocks
local BLOCK_TAGS = {
  Block = true,  -- explicit blocks
  Function = true, -- function bodies
  If = true,     -- if blocks
  While = true,  -- while blocks 
  Repeat = true, -- repeat blocks
  Fornum = true, -- for blocks
  Forin = true,  -- for-in blocks
}

-- Tags that represent conditional expressions
local CONDITION_TAGS = {
  Op = true,     -- Binary operators (like and/or)
  Not = true,    -- Not operator
  Call = true,   -- Function calls that return booleans
  Compare = true, -- Comparison operators
  Nil = true,    -- Nil values in conditions
  Boolean = true, -- Boolean literals
}

-- Public wrapper for is_line_executable to expose it in the module API
function M.is_line_executable(code_map, line_num)
  if not code_map or not line_num then
    return false
  end
  
  -- Make sure we have content and AST nodes
  local content = code_map.content
  local nodes = code_map.nodes
  
  if not content or not nodes then
    return false
  end
  
  -- Delegate to the internal implementation
  return is_line_executable(nodes, line_num, content)
end

-- Get all executable lines for a file based on its code map
function M.get_executable_lines(code_map)
  if not code_map or not code_map.content then
    return {}
  end
  
  local content = code_map.content
  local nodes = code_map.nodes
  
  if not nodes then
    return {}
  end
  
  -- Count the number of lines in the content
  local line_count = 0
  for _ in (content .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
    line_count = line_count + 1
  end
  
  -- Check each line and build a map of executable lines
  local executable_lines = {}
  for line_num = 1, line_count do
    executable_lines[line_num] = is_line_executable(nodes, line_num, content)
  end
  
  return executable_lines
end

-- Extract conditional expressions from a node
local function extract_conditions(node, conditions, content, parent_id)
  conditions = conditions or {}
  local condition_id_counter = 0
  
  -- Process node if it's a conditional operation
  if node and node.tag and CONDITION_TAGS[node.tag] then
    if node.pos and node.end_pos then
      condition_id_counter = condition_id_counter + 1
      local condition_id = node.tag .. "_condition_" .. condition_id_counter
      local start_line = get_line_for_position(content, node.pos)
      local end_line = get_line_for_position(content, node.end_pos)
      
      -- Only add if it's a valid range
      if start_line < end_line then
        table.insert(conditions, {
          id = condition_id,
          type = node.tag,
          start_line = start_line,
          end_line = end_line,
          parent_id = parent_id,
          executed = false,
          executed_true = false,
          executed_false = false
        })
      end
    end
    
    -- For binary operations, add the left and right sides as separate conditions
    if node.tag == "Op" and node[1] and node[2] then
      extract_conditions(node[1], conditions, content, parent_id)
      extract_conditions(node[2], conditions, content, parent_id)
    end
    
    -- For Not operations, add the operand as a separate condition
    if node.tag == "Not" and node[1] then
      extract_conditions(node[1], conditions, content, parent_id)
    end
  end
  
  return conditions
end

-- Find all blocks in the AST 
local function find_blocks(ast, blocks, content, parent_id)
  blocks = blocks or {}
  parent_id = parent_id or "root"
  
  -- Process the AST using the same iterative approach as in collect_nodes
  local to_process = {{node = ast, parent_id = parent_id}}
  local processed = 0
  local block_id_counter = 0
  
  while #to_process > 0 do
    local current = table.remove(to_process)
    local node = current.node
    local parent = current.parent_id
    
    processed = processed + 1
    
    -- Safety limit
    if processed > 100000 then
      if logger.is_debug_enabled() then
        logger.debug({
          message = "Block finding limit reached",
          processed_nodes = processed,
          limit = 100000,
          operation = "find_blocks"
        })
      end
      break
    end
    
    if type(node) == "table" and node.tag then
      -- Handle different block types
      if BLOCK_TAGS[node.tag] then
        -- This is a block node, create a block for it
        block_id_counter = block_id_counter + 1
        local block_id = node.tag .. "_" .. block_id_counter
        
        -- Get block position
        if node.pos and node.end_pos then
          local start_line = get_line_for_position(content, node.pos)
          local end_line = get_line_for_position(content, node.end_pos)
          
          -- Skip invalid blocks (where start_line equals end_line)
          if start_line < end_line then
            -- Create block entry
            local block = {
              id = block_id,
              type = node.tag,
              start_line = start_line,
              end_line = end_line,
              parent_id = parent,
              branches = {},
              executed = false
            }
            
            -- If it's a branch condition, add special handling
            if BRANCH_TAGS[node.tag] then
              -- For If nodes, we want to handle the branches
              if node.tag == "If" and node[2] and node[3] then
                -- Node structure: If[condition, then_block, else_block]
                -- Get conditional expression position
                if node[1] and node[1].pos and node[1].end_pos then
                  block_id_counter = block_id_counter + 1
                  local cond_id = "condition_" .. block_id_counter
                  local cond_start = get_line_for_position(content, node[1].pos)
                  local cond_end = get_line_for_position(content, node[1].end_pos)
                  
                  -- Only add if it's a valid range
                  if cond_start < cond_end then
                    table.insert(blocks, {
                      id = cond_id,
                      type = "condition",
                      start_line = cond_start,
                      end_line = cond_end,
                      parent_id = block_id,
                      executed = false
                    })
                    
                    table.insert(block.branches, cond_id)
                  end
                end
                
                -- Create sub-blocks for then and else parts
                if node[2].pos and node[2].end_pos then
                  block_id_counter = block_id_counter + 1
                  local then_id = "then_" .. block_id_counter
                  local then_start = get_line_for_position(content, node[2].pos)
                  local then_end = get_line_for_position(content, node[2].end_pos)
                  
                  -- Only add if it's a valid range
                  if then_start < then_end then
                    table.insert(blocks, {
                      id = then_id,
                      type = "then_block",
                      start_line = then_start,
                      end_line = then_end,
                      parent_id = block_id,
                      executed = false
                    })
                    
                    table.insert(block.branches, then_id)
                  end
                end
                
                if node[3].pos and node[3].end_pos then
                  block_id_counter = block_id_counter + 1
                  local else_id = "else_" .. block_id_counter
                  local else_start = get_line_for_position(content, node[3].pos)
                  local else_end = get_line_for_position(content, node[3].end_pos)
                  
                  -- Only add if it's a valid range
                  if else_start < else_end then
                    table.insert(blocks, {
                      id = else_id,
                      type = "else_block",
                      start_line = else_start,
                      end_line = else_end,
                      parent_id = block_id,
                      executed = false
                    })
                    
                    table.insert(block.branches, else_id)
                  end
                end
              elseif node.tag == "While" and node[1] and node[2] then
                -- Add condition for while loops
                if node[1].pos and node[1].end_pos then
                  block_id_counter = block_id_counter + 1
                  local cond_id = "while_condition_" .. block_id_counter
                  local cond_start = get_line_for_position(content, node[1].pos)
                  local cond_end = get_line_for_position(content, node[1].end_pos)
                  
                  -- Only add if it's a valid range
                  if cond_start < cond_end then
                    table.insert(blocks, {
                      id = cond_id,
                      type = "while_condition",
                      start_line = cond_start,
                      end_line = cond_end,
                      parent_id = block_id,
                      executed = false
                    })
                    
                    table.insert(block.branches, cond_id)
                  end
                end
                
                -- Add body for while loops
                if node[2].pos and node[2].end_pos then
                  block_id_counter = block_id_counter + 1
                  local body_id = "while_body_" .. block_id_counter
                  local body_start = get_line_for_position(content, node[2].pos)
                  local body_end = get_line_for_position(content, node[2].end_pos)
                  
                  -- Only add if it's a valid range
                  if body_start < body_end then
                    table.insert(blocks, {
                      id = body_id,
                      type = "while_body",
                      start_line = body_start,
                      end_line = body_end,
                      parent_id = block_id,
                      executed = false
                    })
                    
                    table.insert(block.branches, body_id)
                  end
                end
              end
            end
            
            -- Add the block to our list
            table.insert(blocks, block)
            
            -- Process child nodes with this block as the parent
            for k, v in pairs(node) do
              if type(k) == "number" then
                table.insert(to_process, {node = v, parent_id = block_id})
              end
            end
          end
        end
      else
        -- Not a block node, just process children
        for k, v in pairs(node) do
          if type(k) == "number" then
            table.insert(to_process, {node = v, parent_id = parent})
          end
        end
      end
    end
  end
  
  return blocks
end

-- Find all conditional expressions in the AST
local function find_conditions(ast, conditions, content)
  conditions = conditions or {}
  
  -- Process the AST using the same iterative approach as in collect_nodes
  local to_process = {{node = ast, parent_id = "root"}}
  local processed = 0
  local condition_id_counter = 0
  
  while #to_process > 0 do
    local current = table.remove(to_process)
    local node = current.node
    local parent = current.parent_id
    
    processed = processed + 1
    
    -- Safety limit
    if processed > 100000 then
      if logger.is_debug_enabled() then
        logger.debug({
          message = "Condition finding limit reached",
          processed_nodes = processed,
          limit = 100000,
          operation = "find_conditions"
        })
      end
      break
    end
    
    -- For branch nodes, extract conditional expressions
    if type(node) == "table" and node.tag then
      if BRANCH_TAGS[node.tag] then
        -- Extract conditions from branch conditions
        if node.tag == "If" and node[1] then
          -- If condition
          if node[1].pos and node[1].end_pos then
            condition_id_counter = condition_id_counter + 1
            local cond_id = "if_condition_" .. condition_id_counter
            local cond_start = get_line_for_position(content, node[1].pos)
            local cond_end = get_line_for_position(content, node[1].end_pos)
            
            if cond_start < cond_end then
              table.insert(conditions, {
                id = cond_id,
                type = "if_condition",
                start_line = cond_start,
                end_line = cond_end,
                parent_id = parent,
                executed = false,
                executed_true = false,  -- Condition evaluated to true
                executed_false = false  -- Condition evaluated to false
              })
              
              -- Extract sub-conditions recursively
              local sub_conditions = extract_conditions(node[1], {}, content, cond_id)
              for _, sub_cond in ipairs(sub_conditions) do
                table.insert(conditions, sub_cond)
              end
            end
          end
        elseif node.tag == "While" and node[1] then
          -- While condition
          if node[1].pos and node[1].end_pos then
            condition_id_counter = condition_id_counter + 1
            local cond_id = "while_condition_" .. condition_id_counter
            local cond_start = get_line_for_position(content, node[1].pos)
            local cond_end = get_line_for_position(content, node[1].end_pos)
            
            if cond_start < cond_end then
              table.insert(conditions, {
                id = cond_id,
                type = "while_condition",
                start_line = cond_start,
                end_line = cond_end,
                parent_id = parent,
                executed = false,
                executed_true = false,
                executed_false = false
              })
              
              -- Extract sub-conditions recursively
              local sub_conditions = extract_conditions(node[1], {}, content, cond_id)
              for _, sub_cond in ipairs(sub_conditions) do
                table.insert(conditions, sub_cond)
              end
            end
          end
        end
      end
      
      -- Process child nodes
      for k, v in pairs(node) do
        if type(k) == "number" then
          table.insert(to_process, {node = v, parent_id = parent})
        end
      end
    end
  end
  
  return conditions
end

-- Generate a code map from the AST and content with timing protection
function M.generate_code_map(ast, content)
  -- Start timing with reasonable timeout
  local start_time = os.clock()
  local MAX_CODEMAP_TIME = 120.0 -- 120 second time limit for code map generation
  
  local code_map = {
    lines = {},           -- Information about each line
    functions = {},       -- Function definitions with line ranges
    branches = {},        -- Branch points (if/else, loops)
    blocks = {},          -- Code blocks for block-based coverage
    content = content,    -- Store the content for line classification
    nodes = {},           -- Store the AST nodes for line classification
    conditions = {},      -- Conditional expressions for condition coverage
    line_count = count_lines(content)
  }
  
  -- Set a reasonable upper limit for line count to prevent DOS
  if code_map.line_count > 10000 then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "File too large for code mapping",
        line_count = code_map.line_count,
        max_lines = 10000,
        operation = "generate_code_map"
      })
    end
    return nil
  end
  
  -- Collect all nodes with time check
  local all_nodes
  local success, result = pcall(function()
    all_nodes = collect_nodes(ast)
    
    -- Check for timeout
    if os.clock() - start_time > MAX_CODEMAP_TIME then
      return nil, "Node collection timeout"
    end
    
    return all_nodes, nil
  end)
  
  if not success then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "Error in collect_nodes",
        error = tostring(result),
        operation = "generate_code_map"
      })
    end
    return nil
  end
  
  if not all_nodes then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "Node collection failed",
        error = result or "Unknown error",
        operation = "generate_code_map"
      })
    end
    return nil
  end
  
  -- Store the AST nodes in the code map for line classification
  code_map.nodes = all_nodes
  
  -- Add size limit for node collection
  if #all_nodes > 50000 then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "AST too complex for analysis",
        node_count = #all_nodes,
        max_nodes = 50000,
        operation = "generate_code_map"
      })
    end
    return nil
  end
  
  -- Collect all functions with time check
  local functions
  success, result = pcall(function()
    -- Create a context for function finding with content for line mapping
    local function_context = {
      content = content,
      lines = content and content:gmatch("[^\n]*\n?"),
      pos_to_line = {}
    }
    
    -- Build basic position-to-line mapping for key points
    if content then
      local line = 1
      local pos = 1
      for current_line in content:gmatch("([^\n]*)\n?") do
        function_context.pos_to_line[pos] = line
        pos = pos + #current_line + 1
        line = line + 1
      end
    end
    
    functions = find_functions(ast, nil, function_context)
    
    -- Check for timeout
    if os.clock() - start_time > MAX_CODEMAP_TIME then
      return nil, "Function finding timeout"
    end
    
    return functions, nil
  end)
  
  if not success then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "Error in find_functions",
        error = tostring(result),
        operation = "generate_code_map"
      })
    end
    return nil
  end
  
  if not functions then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "Function finding failed",
        error = result or "Unknown error",
        operation = "generate_code_map"
      })
    end
    return nil
  end
  
  -- Collect all code blocks with time check
  local blocks
  success, result = pcall(function()
    blocks = find_blocks(ast, nil, content)
    
    -- Check for timeout
    if os.clock() - start_time > MAX_CODEMAP_TIME then
      return nil, "Block finding timeout"
    end
    
    return blocks, nil
  end)
  
  if not success then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "Error in find_blocks",
        error = tostring(result),
        operation = "generate_code_map"
      })
    end
    return nil
  end
  
  if blocks then
    code_map.blocks = blocks
  end
  
  -- Collect all conditional expressions with time check
  local conditions
  success, result = pcall(function()
    conditions = find_conditions(ast, nil, content)
    
    -- Check for timeout
    if os.clock() - start_time > MAX_CODEMAP_TIME then
      return nil, "Condition finding timeout"
    end
    
    return conditions, nil
  end)
  
  if not success then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "Error in find_conditions",
        error = tostring(result),
        operation = "generate_code_map",
        note = "Continuing without conditions"
      })
    end
    -- Don't return, we can still continue without conditions
  elseif conditions then
    code_map.conditions = conditions
  end
  
  -- Create function map with time checks
  for i, func in ipairs(functions) do
    -- Periodic time checks
    if i % 100 == 0 and os.clock() - start_time > MAX_CODEMAP_TIME then
      if logger.is_debug_enabled() then
        logger.debug({
          message = "Function map timeout",
          functions_processed = i,
          elapsed_time = os.clock() - start_time,
          max_time = MAX_CODEMAP_TIME,
          operation = "generate_code_map"
        })
      end
      break
    end
    
    -- Get function start line - prefer pre-computed value if available
    local func_start_line = func.line_start
    if not func_start_line and func.pos then
      func_start_line = get_line_for_position(content, func.pos)
    end
    
    -- Get function end line - prefer pre-computed value if available
    local func_end_line = func.line_end
    if not func_end_line and func.endpos then
      func_end_line = get_line_for_position(content, func.endpos)
    end
    
    -- Get function parameters - prefer pre-computed values if available
    local params = func.params or {}
    if #params == 0 and func[1] and type(func[1]) == "table" then
      for _, param in ipairs(func[1]) do
        if param.tag == "Id" then
          table.insert(params, param[1])
        elseif param.tag == "Dots" then
          table.insert(params, "...")
        end
      end
    end
    
    -- Extract function name and type information
    local func_name = func.name 
    local func_type = func.type or "unknown"
    
    -- If no explicit name, generate a default anonymous name
    if not func_name then
      func_name = "anonymous_" .. i
    end
    
    -- Create the function record with enhanced information
    local function_record = {
      start_line = func_start_line,
      end_line = func_end_line,
      name = func_name,
      params = params,
      type = func_type,
      has_varargs = func.has_varargs or false
    }
    
    -- Copy method information if available
    if func.method_class then
      function_record.method_class = func.method_class
    end
    
    if func.method_name then
      function_record.method_name = func.method_name
    end
    
    table.insert(code_map.functions, function_record)
  end
  
  -- Completely optimized line analysis - faster and more reliable
  -- Rather than trying to analyze each line in detail which is causing timeouts,
  -- we'll use a much simpler approach with fewer computations
  
  -- First, determine number of lines to process - increased from 500 to 5000
  local MAX_LINES = 5000 -- Higher limit for real files
  local line_count = math.min(code_map.line_count, MAX_LINES)
  
  -- Pre-allocate executable lines lookup table
  code_map._executable_lines_lookup = {}
  
  -- Pre-process the content into lines all at once
  -- This is MUCH faster than calling getLineStartPos/getLineEndPos repeatedly
  local lines = {}
  if content then
    -- Split content into lines (fast one-pass approach)
    local line_start = 1
    for i = 1, #content do
      local c = content:sub(i, i)
      if c == '\n' then
        table.insert(lines, content:sub(line_start, i-1))
        line_start = i + 1
      end
    end
    -- Add the last line if any
    if line_start <= #content then
      table.insert(lines, content:sub(line_start))
    end
  end
  
  -- Pre-process nodes once to create a node-to-line mapping
  -- This is much faster than checking each node for each line
  -- Use a smarter approach for large files
  local lines_with_nodes = {}
  
  -- We'll build the mapping differently based on file size
  if #all_nodes < 5000 and line_count < 2000 then
    -- For smaller files, use comprehensive mapping
    -- Process all nodes once
    for _, node in ipairs(all_nodes) do
      if node and node.pos and node.end_pos then
        local node_start_line = get_line_for_position(content, node.pos)
        local node_end_line = get_line_for_position(content, node.end_pos)
        
        -- For smaller spans, add to each line
        if node_end_line - node_start_line < 10 then
          -- Add node to all lines it spans
          for line_num = node_start_line, math.min(node_end_line, line_count) do
            if not lines_with_nodes[line_num] then
              lines_with_nodes[line_num] = {}
            end
            table.insert(lines_with_nodes[line_num], node)
          end
        else
          -- For larger spans, just mark start and end lines
          -- Start line
          if not lines_with_nodes[node_start_line] then
            lines_with_nodes[node_start_line] = {}
          end
          table.insert(lines_with_nodes[node_start_line], node)
          
          -- End line
          if not lines_with_nodes[node_end_line] then
            lines_with_nodes[node_end_line] = {}
          end
          table.insert(lines_with_nodes[node_end_line], node)
        end
      end
    end
  else
    -- For larger files, use a more efficient node mapping strategy
    -- First, find executable nodes
    local executable_nodes = {}
    for _, node in ipairs(all_nodes) do
      if node and node.pos and node.end_pos and EXECUTABLE_TAGS[node.tag] then
        table.insert(executable_nodes, node)
      end
    end
    
    -- Then map only executable nodes to their start lines
    for _, node in ipairs(executable_nodes) do
      local node_start_line = get_line_for_position(content, node.pos)
      if not lines_with_nodes[node_start_line] then
        lines_with_nodes[node_start_line] = {}
      end
      table.insert(lines_with_nodes[node_start_line], node)
    end
  end
  
  -- Process lines in larger batches for better performance
  local BATCH_SIZE = 250 -- Larger batch size to reduce the number of timeout checks
  local executable_count = 0
  local non_executable_count = 0
  
  for batch_start = 1, line_count, BATCH_SIZE do
    -- Check time only once per batch
    if os.clock() - start_time > MAX_CODEMAP_TIME then
      break
    end
    
    local batch_end = math.min(batch_start + BATCH_SIZE - 1, line_count)
    
    for line_num = batch_start, batch_end do
      -- Get the line text
      local line_text = lines[line_num] or ""
      
      -- Default to non-executable
      local is_exec = false
      local line_type = M.LINE_TYPES.NON_EXECUTABLE
      
      -- Initialize multiline comment tracking if needed
      if not code_map._in_multiline_comment then
        code_map._in_multiline_comment = false
      end
      
      -- First check if we're in a multiline comment or this line starts/ends one
      local is_comment_line = false
      
      -- Check for multiline comment markers
      local comment_start = line_text and line_text:match("^%s*%-%-%[%[")
      local comment_end = line_text and line_text:match("%]%]")
      
      -- Determine if this line is part of a multiline comment
      if comment_start and not comment_end then
        -- Start of multiline comment
        code_map._in_multiline_comment = true
        is_comment_line = true
      elseif comment_end and code_map._in_multiline_comment then
        -- End of multiline comment
        is_comment_line = true
        code_map._in_multiline_comment = false
      elseif code_map._in_multiline_comment then
        -- Inside multiline comment
        is_comment_line = true
      end
      
      -- If this is a comment line, mark it non-executable immediately
      if is_comment_line then
        is_exec = false
        line_type = M.LINE_TYPES.NON_EXECUTABLE
      -- Otherwise proceed with normal line analysis
      elseif line_text and #line_text > 0 then
        -- Trim whitespace
        line_text = line_text:match("^%s*(.-)%s*$") or ""
        
        -- Always non-executable patterns regardless of config
        local always_non_executable_patterns = {
          "^%s*%-%-",         -- Single-line comments with optional leading whitespace
          "^%s*$",            -- Blank lines
          "^%[%[",            -- Start of multi-line string
          "^%]%]",            -- End of multi-line string
          "^.*%[%[.-$",       -- Line containing multi-line string start
          "^.*%]%]$"          -- Line containing multi-line string end
        }
        
        -- Control flow keywords patterns - only non-executable if config says so
        local control_flow_keywords_patterns = {
          "^%s*end%s*$",      -- Standalone end keyword
          "^%s*end[,%)]",     -- End followed by comma or closing parenthesis
          "^%s*end.*%-%-%s+", -- End followed by comment
          "^%s*else%s*$",     -- Standalone else keyword
          "^%s*until%s",      -- until lines (the condition is executable, not the keyword)
          "^%s*[%]}]%s*$",    -- Closing brackets/braces
          "^%s*then%s*$",     -- Standalone then keyword
          "^%s*do%s*$",       -- Standalone do keyword
          "^%s*repeat%s*$",   -- Standalone repeat keyword
          "^%s*elseif%s*$"    -- Standalone elseif keyword
        }
        
        -- Start with empty non_executable_patterns
        local non_executable_patterns = {}
        
        -- Add always non-executable patterns
        for _, pattern in ipairs(always_non_executable_patterns) do
          table.insert(non_executable_patterns, pattern)
        end
        
        -- Add control flow keywords if config says they're non-executable
        if not config.control_flow_keywords_executable then
          for _, pattern in ipairs(control_flow_keywords_patterns) do
            table.insert(non_executable_patterns, pattern)
          end
        end
        
        -- Check for non-executable patterns
        local is_non_executable = false
        for _, pattern in ipairs(non_executable_patterns) do
          if line_text:match(pattern) then
            is_exec = false
            line_type = M.LINE_TYPES.NON_EXECUTABLE
            is_non_executable = true
            break
          end
        end
        
        -- If control flow keywords are executable, check if this is a control flow keyword
        -- and override is_non_executable if needed
        if is_non_executable and config.control_flow_keywords_executable then
          for _, pattern in ipairs(control_flow_keywords_patterns) do
            if line_text:match(pattern) then
              is_exec = true
              line_type = M.LINE_TYPES.EXECUTABLE
              is_non_executable = false
              break
            end
          end
        end
        
        if not is_non_executable then
          -- Check for branch-related keywords that should be marked as branch points
          local branch_patterns = {
            "^%s*if%s",         -- If statements
            "^%s*elseif%s",     -- Elseif statements
            "^%s*while%s",      -- While loops
            "^%s*for%s",        -- For loops
            "^%s*repeat%s"      -- Repeat-until loops
          }
          
          local is_branch = false
          for _, pattern in ipairs(branch_patterns) do
            if line_text:match(pattern) then
              is_exec = true
              line_type = M.LINE_TYPES.BRANCH
              is_branch = true
              break
            end
          end
          
          if not is_branch then
            -- Check for function definitions (which should be marked as functions)
            if line_text:match("function") then
              is_exec = true
              line_type = M.LINE_TYPES.FUNCTION
            else
              -- Check for other executable patterns
              local executable_patterns = {
                "=",                -- Assignments
                "return",           -- Return statements
                "local%s",          -- Local variables
                "[%w_]+%(",         -- Function calls
                "%:%w+%(",          -- Method calls
                "break",            -- Break statements
                "goto%s",           -- Goto statements
                "%{",               -- Table creation
                "%[",               -- Table access or creation
                "%+%=",             -- Compound operators
                "%-%=",
                "%*%=",
                "%/%="
              }
              
              for _, pattern in ipairs(executable_patterns) do
                if line_text:match(pattern) then
                  is_exec = true
                  line_type = M.LINE_TYPES.EXECUTABLE
                  break
                end
              end
            end
          end
        end
      else
        -- Empty lines are explicitly non-executable
        is_exec = false
        line_type = M.LINE_TYPES.NON_EXECUTABLE
      end
      
      -- For small files, check the pre-computed node mapping as well
      if not is_exec and lines_with_nodes[line_num] then
        -- Check if any node at this line is executable
        for _, node in ipairs(lines_with_nodes[line_num]) do
          if EXECUTABLE_TAGS[node.tag] then
            is_exec = true
            line_type = M.LINE_TYPES.EXECUTABLE
            break
          end
          
          -- Special case for function definition nodes
          if node.tag == "Function" then
            -- Only mark the start line as a function
            local node_start_line = get_line_for_position(content, node.pos)
            if node_start_line == line_num then
              is_exec = true
              line_type = M.LINE_TYPES.FUNCTION
              break
            end
          end
        end
      end
      
      -- Store the result
      code_map.lines[line_num] = {
        line = line_num,
        executable = is_exec,
        type = line_type
      }
      
      -- Also store in fast lookup table
      code_map._executable_lines_lookup[line_num] = is_exec
      
      -- Track counts for debugging
      if is_exec then
        executable_count = executable_count + 1
      else
        non_executable_count = non_executable_count + 1
      end
    end
  end
  
  -- Final time check and report with file info
  local total_time = os.clock() - start_time
  
  -- Always print detailed information for debugging using structured logging
  if logger.is_verbose_enabled() then
    logger.verbose({
      message = "Code map generation completed",
      elapsed_time_sec = string.format("%.2f", total_time),
      file_path = file_path or "unknown",
      line_count = code_map.line_count or 0,
      node_count = #all_nodes or 0,
      executable_lines = executable_count,
      non_executable_lines = non_executable_count,
      operation = "generate_code_map"
    })
  end
  
  -- Verify we have executable lines
  if executable_count == 0 then
    if logger.is_debug_enabled() then
      logger.debug({
        message = "No executable lines found in file",
        file_path = file_path or "unknown",
        warning = "This will cause incorrect coverage reporting",
        operation = "generate_code_map"
      })
    end
    
    -- Apply emergency fallback for important coverage module files
    if file_path and (file_path:match("lib/coverage/init.lua") or file_path:match("lib/coverage/debug_hook.lua")) then
      -- Extract this emergency fallback code into a dedicated function for better organization
      executable_count = M.apply_emergency_fallback(code_map, file_path, content)
    end
  end
  
  return code_map
end

-- Apply emergency fallback classification for critical files
-- This function is extracted from the emergency fallback code block for better organization
function M.apply_emergency_fallback(code_map, file_path, content)
  logger.debug({
    message = "Applying emergency fallback for critical file",
    file_path = file_path,
    operation = "apply_emergency_fallback"
  })
  
  -- Parameter validation with error handler
  if not code_map then
    return 0, error_handler.validation_error(
      "Missing code map for emergency fallback",
      {
        file_path = file_path,
        operation = "apply_emergency_fallback"
      }
    )
  end
  
  -- If content is available, quickly classify lines based on simple patterns
  if content and type(content) == "string" then
    -- Process lines with proper error handling
    local success, result = error_handler.try(function()
      local lines = {}
      for line in (content .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
        table.insert(lines, line)
      end
      
      local fallback_executable = 0
      
      for i, line in ipairs(lines) do
        -- Skip empty lines and comment lines
        if line:match("^%s*$") or line:match("^%s*%-%-") or line:match("^%s*%-%-%[%[") then
          code_map.lines[i] = {
            line = i,
            executable = false,
            type = M.LINE_TYPES.NON_EXECUTABLE
          }
          code_map._executable_lines_lookup[i] = false
        else
          -- Mark most other lines as executable
          code_map.lines[i] = {
            line = i,
            executable = true,
            type = M.LINE_TYPES.EXECUTABLE
          }
          code_map._executable_lines_lookup[i] = true
          fallback_executable = fallback_executable + 1
        end
      end
      
      logger.debug({
        message = "Emergency fallback classification complete",
        executable_lines = fallback_executable,
        total_lines = #lines,
        file_path = file_path,
        operation = "apply_emergency_fallback"
      })
      
      return fallback_executable
    end)
    
    if not success then
      logger.error("Emergency fallback failed: " .. error_handler.format_error(result), {
        file_path = file_path,
        operation = "apply_emergency_fallback"
      })
      return 0
    end
    
    return result
  end
  
  return 0
end

-- Get the executable lines from a code map
function M.get_executable_lines(code_map)
  if not code_map or not code_map.lines then
    return {}
  end
  
  local executable_lines = {}
  
  for line_num, line_info in pairs(code_map.lines) do
    if line_info.executable then
      executable_lines[line_num] = true  -- Use hash table for O(1) lookups
    end
  end
  
  return executable_lines
end

-- Helper function to get or create a code map from an AST
function M.get_code_map_for_ast(ast, file_path)
  if not ast then
    return nil, error_handler.validation_error(
      "AST is nil",
      {
        operation = "get_code_map_for_ast"
      }
    )
  end
  
  -- If the AST already has an attached code map, use it
  if ast._code_map then
    return ast._code_map
  end
  
  -- Get the file content
  local content, read_err
  if file_path then
    content, read_err = error_handler.safe_io_operation(
      function() return filesystem.read_file(file_path) end,
      file_path,
      {operation = "get_code_map_for_ast"}
    )
    
    if not content then
      return nil, read_err
    end
  else
    return nil, error_handler.validation_error(
      "No file path provided for code map generation",
      {
        operation = "get_code_map_for_ast"
      }
    )
  end
  
  -- Generate the code map with time limit
  local start_time = os.clock()
  local MAX_TIME = 1.0 -- 1 second limit
  
  -- Use error handler's try for map generation
  local success, result = error_handler.try(function()
    local code_map = M.generate_code_map(ast, content) 
    
    -- Attach the code map to the AST for future reference
    if code_map then
      ast._code_map = code_map
    end
    
    -- Check for timeout
    if os.clock() - start_time > MAX_TIME then
      return nil, error_handler.timeout_error(
        "Timeout generating code map",
        {
          max_time = MAX_TIME,
          elapsed_time = os.clock() - start_time,
          file_path = file_path,
          operation = "get_code_map_for_ast"
        }
      )
    end
    
    return code_map
  end)
  
  if not success then
    logger.debug("Error generating code map: " .. error_handler.format_error(result))
    return nil, result
  end
  
  return result
end

-- Fast lookup table for checking if a line is executable according to the code map
function M.is_line_executable(code_map, line_num)
  -- Quick safety checks
  if not code_map then 
    return false 
  end
  
  -- Export config value for external use
  M.config = config
  
  -- If the line is already marked executable in lookup table, return true
  if code_map._executable_lines_lookup and code_map._executable_lines_lookup[line_num] == true then
    return true
  end
  
  -- Special check for control flow keywords
  if config.control_flow_keywords_executable and code_map.source then
    local line_text = code_map.source[line_num] or ""
    line_text = line_text:match("^%s*(.-)%s*$") or ""
    
    -- Check if this line matches a control flow keyword pattern
    for _, pattern in ipairs({
      "^%s*end%s*$",      -- Standalone end keyword
      "^%s*end[,%)]",     -- End followed by comma or closing parenthesis
      "^%s*end.*%-%-%s+", -- End followed by comment
      "^%s*else%s*$",     -- Standalone else keyword
      "^%s*until%s",      -- until lines (the condition is executable, not the keyword)
      "^%s*[%]}]%s*$",    -- Closing brackets/braces
      "^%s*then%s*$",     -- Standalone then keyword
      "^%s*do%s*$",       -- Standalone do keyword
      "^%s*repeat%s*$",   -- Standalone repeat keyword
      "^%s*elseif%s*$"    -- Standalone elseif keyword
    }) do
      if line_text:match(pattern) then
        -- Only check for comment patterns
        for _, comment_pattern in ipairs({
          "^%s*%-%-",      -- Single line comment
          "^%s*$",         -- Empty line
          "^%[%[",         -- Start of multi-line string
          "^%]%]",         -- End of multi-line string
        }) do
          if line_text:match(comment_pattern) then
            return false   -- It's a comment or empty line, not executable
          end
        end
        -- This is a control flow keyword and config says they're executable
        return true
      end
    end
  end
  
  -- Check if we have a precomputed executable_lines_lookup table
  if not code_map._executable_lines_lookup then
    -- If code_map.lines is available, create a lookup table for O(1) access
    if code_map.lines then
      code_map._executable_lines_lookup = {}
      
      -- Build lookup table with a reasonable upper limit
      local processed = 0
      for ln, line_info in pairs(code_map.lines) do
        processed = processed + 1
        if processed > 100000 then
          -- Too many lines, abort lookup table creation
          break
        end
        code_map._executable_lines_lookup[ln] = line_info.executable or false
      end
    else
      -- If no lines data, create empty lookup
      code_map._executable_lines_lookup = {}
    end
  end
  
  -- Use the lookup table for O(1) access
  return code_map._executable_lines_lookup[line_num] or false
end

-- Return functions defined in the code
function M.get_functions(code_map)
  return code_map.functions
end

-- Get blocks defined in the code
function M.get_blocks(code_map)
  return code_map.blocks or {}
end

-- Get blocks containing a specific line
function M.get_blocks_for_line(code_map, line_num)
  if not code_map or not code_map.blocks then
    return {}
  end
  
  local blocks = {}
  for _, block in ipairs(code_map.blocks) do
    if block.start_line <= line_num and block.end_line >= line_num then
      table.insert(blocks, block)
    end
  end
  
  return blocks
end

-- Get conditional expressions defined in the code
function M.get_conditions(code_map)
  return code_map.conditions or {}
end

-- Get conditions containing a specific line
function M.get_conditions_for_line(code_map, line_num)
  if not code_map or not code_map.conditions then
    return {}
  end
  
  local conditions = {}
  for _, condition in ipairs(code_map.conditions) do
    if condition.start_line <= line_num and condition.end_line >= line_num then
      table.insert(conditions, condition)
    end
  end
  
  return conditions
end

-- Calculate condition coverage statistics
function M.calculate_condition_coverage(code_map)
  if not code_map or not code_map.conditions then
    return {
      total_conditions = 0,
      executed_conditions = 0,
      fully_covered_conditions = 0,  -- Both true and false outcomes
      coverage_percent = 0,
      outcome_coverage_percent = 0   -- Percentage of all possible outcomes covered
    }
  end
  
  local total_conditions = #code_map.conditions
  local executed_conditions = 0
  local fully_covered_conditions = 0
  
  for _, condition in ipairs(code_map.conditions) do
    if condition.executed then
      executed_conditions = executed_conditions + 1
      
      if condition.executed_true and condition.executed_false then
        fully_covered_conditions = fully_covered_conditions + 1
      end
    end
  end
  
  return {
    total_conditions = total_conditions,
    executed_conditions = executed_conditions,
    fully_covered_conditions = fully_covered_conditions,
    coverage_percent = total_conditions > 0 and (executed_conditions / total_conditions * 100) or 0,
    outcome_coverage_percent = total_conditions > 0 and (fully_covered_conditions / total_conditions * 100) or 0
  }
end

-- Find a block by ID
function M.get_block_by_id(code_map, block_id)
  if not code_map or not code_map.blocks then
    return nil
  end
  
  for _, block in ipairs(code_map.blocks) do
    if block.id == block_id then
      return block
    end
  end
  
  return nil
end

-- Calculate block coverage statistics
function M.calculate_block_coverage(code_map)
  if not code_map or not code_map.blocks then
    return {
      total_blocks = 0,
      executed_blocks = 0,
      coverage_percent = 0
    }
  end
  
  local total_blocks = #code_map.blocks
  local executed_blocks = 0
  
  for _, block in ipairs(code_map.blocks) do
    if block.executed then
      executed_blocks = executed_blocks + 1
    end
  end
  
  return {
    total_blocks = total_blocks,
    executed_blocks = executed_blocks,
    coverage_percent = total_blocks > 0 and (executed_blocks / total_blocks * 100) or 0
  }
end

-- Simple line classification without requiring a full code map
-- This is used as the fallback when no code map is available
function M.classify_line_simple(line_text, configuration)
  -- If no line text, it's not executable
  if not line_text then
    return false
  end
  
  -- Handle config parameter
  local cfg = configuration or config
  
  -- Trimmed line text
  local trimmed = line_text:match("^%s*(.-)%s*$") or ""
  
  -- Common non-executable patterns
  if trimmed == "" or                     -- Empty lines
     trimmed:match("^%-%-") or           -- Single-line comments
     trimmed:match("^%-%-%[%[") or       -- Start of multiline comment
     trimmed:match("%]%]") then          -- End of multiline comment
    return false
  end
  
  -- Control flow keywords - executability depends on configuration
  local control_flow_patterns = {
    "^end%s*$",      -- Standalone end keyword
    "^end[,%)]",     -- End followed by comma or closing parenthesis
    "^end.*%-%-%s+", -- End followed by comment
    "^else%s*$",     -- Standalone else keyword
    "^until%s",      -- until lines
    "^[%]}]%s*$",    -- Closing brackets/braces
    "^then%s*$",     -- Standalone then keyword
    "^do%s*$",       -- Standalone do keyword
    "^repeat%s*$",   -- Standalone repeat keyword
    "^elseif%s*$"    -- Standalone elseif keyword
  }
  
  for _, pattern in ipairs(control_flow_patterns) do
    if trimmed:match(pattern) then
      -- Control flow keywords are executable if configured that way
      return cfg.control_flow_keywords_executable == true
    end
  end
  
  -- If we get here, assume the line is executable
  -- This matches the original fallback behavior
  return true
end

return M
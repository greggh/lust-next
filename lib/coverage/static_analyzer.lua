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
  
  -- Update the context with the comment status for this line
  context.line_status[line_num] = is_comment_line
  
  return is_comment_line
end

-- Handles single-line comment detection
local function is_single_line_comment(line)
  if not line or line == "" then
    return true -- Empty lines are treated as comments
  end
  
  -- Check for single line comments (--), but be careful about multiline comments
  local comment_pos = line:find("%-%-")
  if comment_pos then
    -- Check if this is a multiline comment start (--[[)
    local ml_start = line:match("^%s*%-%-%[%[", comment_pos)
    if not ml_start then
      -- Check for any non-whitespace before the comment
      local prefix = line:sub(1, comment_pos - 1)
      if prefix:match("^%s*$") then
        return true -- Nothing but whitespace before comment, so whole line is comment
      end
    end
  end
  
  return false
end

-- Get AST for a given file, using cache if available
local function get_ast(file_path)
  -- Check if we already have it in the cache
  if file_cache[file_path] and file_cache[file_path].ast then
    return file_cache[file_path].ast, nil
  end
  
  -- Read the file
  local content, err = error_handler.safe_io_operation(
    function() return filesystem.read_file(file_path) end,
    file_path, 
    {operation = "read_file"}
  )
  
  if not content then
    return nil, err
  end
  
  -- Parse the content
  local success, ast_or_err = error_handler.try(function()
    return parser.parse(content)
  end)
  
  if not success then
    return nil, ast_or_err
  end
  
  -- Cache the result
  file_cache[file_path] = file_cache[file_path] or {}
  file_cache[file_path].ast = ast_or_err
  file_cache[file_path].content = content
  
  return ast_or_err, nil
end

-- Determine line type from AST and content
local function determine_line_type(ast, content, line_num)
  -- Default to non-executable
  local line_type = M.LINE_TYPES.NON_EXECUTABLE
  
  -- Get the line text
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  -- Line might be out of range
  if line_num > #lines then
    return line_type
  end
  
  local line_text = lines[line_num]
  
  -- Check if it's a comment
  if is_single_line_comment(line_text) then
    return line_type
  end
  
  -- Check if this line is part of a multiline comment
  local comment_map = M.find_multiline_comments(content)
  if comment_map[line_num] then
    return line_type
  end
  
  -- Check for end or else keywords
  if line_text:match("^%s*end%s*$") or
     line_text:match("^%s*else%s*$") or
     line_text:match("^%s*elseif%s*") then
    
    if config.control_flow_keywords_executable then
      return M.LINE_TYPES.EXECUTABLE
    else
      return M.LINE_TYPES.END_BLOCK
    end
  end
  
  -- Check for function headers or block starters
  if line_text:match("^%s*function%s+") or
     line_text:match("^%s*local%s+function%s+") or
     line_text:match("^%s*if%s+") or
     line_text:match("^%s*else%s*") or
     line_text:match("^%s*elseif%s+") or
     line_text:match("^%s*for%s+") or
     line_text:match("^%s*while%s+") or
     line_text:match("^%s*repeat%s*$") or
     line_text:match("^%s*until%s+") then
    
    if line_text:match("^%s*function%s+") or
       line_text:match("^%s*local%s+function%s+") then
      return M.LINE_TYPES.FUNCTION
    elseif line_text:match("^%s*if%s+") or
           line_text:match("^%s*elseif%s+") or
           line_text:match("^%s*for%s+") or
           line_text:match("^%s*while%s+") or
           line_text:match("^%s*until%s+") then
      return M.LINE_TYPES.BRANCH
    elseif config.control_flow_keywords_executable then
      return M.LINE_TYPES.EXECUTABLE
    else
      return M.LINE_TYPES.BRANCH
    end
  end
  
  -- If we get here, check if the line has any actual code (not just whitespace)
  if not line_text:match("^%s*$") then
    return M.LINE_TYPES.EXECUTABLE
  end
  
  return line_type
end

-- Classify a single line using AST and content
function M.classify_line(file_path, line_num)
  -- Get AST and content
  local ast, err = get_ast(file_path)
  if not ast then
    -- Fall back to simpler classification if AST not available
    return M.classify_line_simple(file_path, line_num)
  end
  
  -- Get content from cache
  local content = file_cache[file_path].content
  
  -- Perform classification
  return determine_line_type(ast, content, line_num)
end

-- Simpler line classification that doesn't require AST
function M.classify_line_simple(file_path, line_num)
  -- Read file if needed
  local content, err = error_handler.safe_io_operation(
    function() return filesystem.read_file(file_path) end,
    file_path,
    {operation = "classify_line_simple"}
  )
  
  if not content then
    return M.LINE_TYPES.NON_EXECUTABLE
  end
  
  -- Split into lines
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  -- Line might be out of range
  if line_num > #lines then
    return M.LINE_TYPES.NON_EXECUTABLE
  end
  
  local line_text = lines[line_num]
  
  -- Check for comments and empty lines
  if is_single_line_comment(line_text) or line_text:match("^%s*$") then
    return M.LINE_TYPES.NON_EXECUTABLE
  end
  
  -- Check multiline comments
  local in_multiline_comment = false
  local comment_level = 0
  
  for i = 1, line_num do
    local curr_line = lines[i]
    
    -- Look for multiline comment starts
    local comment_starts = 0
    for _ in curr_line:gmatch("%-%-%[%[") do
      comment_starts = comment_starts + 1
    end
    
    -- Look for non-commented [[ starts
    -- This is a simplification - perfect solution would
    -- need full lexer/parser
    if not in_multiline_comment then
      for _ in curr_line:gmatch("[^-]%[%[") do
        comment_starts = comment_starts + 1
      end
    end
    
    -- Look for comment ends
    local comment_ends = 0
    for _ in curr_line:gmatch("%]%]") do
      comment_ends = comment_ends + 1
    end
    
    -- Update comment_level
    comment_level = comment_level + comment_starts - comment_ends
    in_multiline_comment = comment_level > 0
    
    -- If we're at our target line and in a comment, return non-executable
    if i == line_num and in_multiline_comment then
      return M.LINE_TYPES.NON_EXECUTABLE
    end
  end
  
  -- Check for specific line types
  if line_text:match("^%s*function%s+") or
     line_text:match("^%s*local%s+function%s+") then
    return M.LINE_TYPES.FUNCTION
  elseif line_text:match("^%s*if%s+") or
         line_text:match("^%s*elseif%s+") or
         line_text:match("^%s*for%s+") or
         line_text:match("^%s*while%s+") or
         line_text:match("^%s*until%s+") then
    return M.LINE_TYPES.BRANCH
  elseif line_text:match("^%s*end%s*$") or
         line_text:match("^%s*else%s*$") then
    if config.control_flow_keywords_executable then
      return M.LINE_TYPES.EXECUTABLE
    else
      return M.LINE_TYPES.END_BLOCK
    end
  end
  
  -- Default to executable for any line with actual code
  return M.LINE_TYPES.EXECUTABLE
end

-- Check if a line is executable
function M.is_line_executable(file_path, line_num)
  -- Try to use AST-based classification first
  local line_type = M.classify_line(file_path, line_num)
  
  -- For most types, the answer is clear
  if line_type == M.LINE_TYPES.EXECUTABLE or 
     line_type == M.LINE_TYPES.FUNCTION or 
     line_type == M.LINE_TYPES.BRANCH then
    return true
  elseif line_type == M.LINE_TYPES.NON_EXECUTABLE then
    return false
  end
  
  -- For END_BLOCK, it depends on configuration
  if line_type == M.LINE_TYPES.END_BLOCK then
    return config.control_flow_keywords_executable
  end
  
  -- Default to non-executable for any unclassified line
  return false
end

-- Get all executable lines in a file
function M.get_executable_lines(file_path)
  local executable_lines = {}
  
  -- Try to get content from cache
  local content
  if file_cache[file_path] and file_cache[file_path].content then
    content = file_cache[file_path].content
  else
    local err
    content, err = error_handler.safe_io_operation(
      function() return filesystem.read_file(file_path) end,
      file_path,
      {operation = "get_executable_lines"}
    )
    
    if not content then
      return {}
    end
  end
  
  -- Count lines
  local line_count = 0
  for _ in content:gmatch("[^\r\n]+") do
    line_count = line_count + 1
  end
  
  -- Check each line
  for i = 1, line_count do
    if M.is_line_executable(file_path, i) then
      table.insert(executable_lines, i)
    end
  end
  
  return executable_lines
end

-- Get line number for a given position in content
local function get_line_for_position(content, pos)
  if not content or not pos then
    return nil
  end
  
  local line = 1
  local current_pos = 1
  
  while current_pos <= pos do
    local newline_pos = content:find("\n", current_pos)
    if not newline_pos or newline_pos > pos then
      -- Position is on the current line
      break
    end
    
    line = line + 1
    current_pos = newline_pos + 1
  end
  
  return line
end

-- Tags that indicate code blocks
local BLOCK_TAGS = {
  Block = true,    -- explicit blocks
  Function = true, -- function bodies
  If = true,       -- if blocks
  While = true,    -- while blocks 
  Repeat = true,   -- repeat blocks
  Fornum = true,   -- for blocks
  Forin = true,    -- for-in blocks
  Localrec = true, -- local function declarations
  Set = true,      -- assignments that might contain functions
}

-- Tags that indicate condition expressions
local CONDITION_TAGS = {
  Op = true,       -- operators like >, <, ==, ~=, and, or
  Not = true,      -- logical not
  Nil = true,      -- nil checks
  True = true,     -- boolean literal true
  False = true,    -- boolean literal false
  Number = true,   -- number literals in conditions
  String = true,   -- string literals in conditions
  Table = true,    -- table literals in conditions
  Dots = true,     -- vararg expressions
  Id = true,       -- identifiers
  Call = true,     -- function calls
  Invoke = true,   -- method calls
  Index = true,    -- table indexing
  Paren = true,    -- parenthesized expressions
}

-- Enhanced condition extraction with compound condition support
local function extract_conditions(node, conditions, content, parent_id, is_child)
  conditions = conditions or {}
  parent_id = parent_id or "root"
  local condition_id

  -- Process node if it's a conditional operation
  if node and node.tag and CONDITION_TAGS[node.tag] then
    if node.pos and node.end_pos then
      -- Create a unique ID for this condition
      local condition_type = node.tag:lower()
      condition_id = condition_type .. "_" .. (#conditions + 1)
      
      -- Get line boundaries for the condition
      local start_line = get_line_for_position(content, node.pos)
      local end_line = get_line_for_position(content, node.end_pos)
      
      -- Only add valid conditions
      if start_line and end_line and start_line <= end_line then
        -- Create the condition entry
        local condition = {
          id = condition_id,
          type = condition_type,
          parent_id = parent_id,
          start_line = start_line,
          end_line = end_line,
          is_compound = (node.tag == "Op" and (node[1] == "and" or node[1] == "or")),
          operator = node.tag == "Op" and node[1] or nil,
          components = {},
          executed = false,
          executed_true = false,
          executed_false = false,
          execution_count = 0,
          metadata = {
            ast_pos = node.pos,
            ast_end_pos = node.end_pos
          }
        }
        
        -- Add the condition to our collection
        table.insert(conditions, condition)
        
        -- For binary operations like AND/OR, add the left and right components
        if node.tag == "Op" and (node[1] == "and" or node[1] == "or") then
          -- Extract left operand conditions
          local left_id = extract_conditions(node[2], conditions, content, condition_id, true)
          if left_id then
            table.insert(condition.components, left_id)
          end
          
          -- Extract right operand conditions
          local right_id = extract_conditions(node[3], conditions, content, condition_id, true)
          if right_id then
            table.insert(condition.components, right_id)
          end
        end
        
        -- For NOT operations, extract the negated condition
        if node.tag == "Not" then
          local comp_id = extract_conditions(node[1], conditions, content, condition_id, true)
          if comp_id then
            table.insert(condition.components, comp_id)
          end
        end
        
        -- Return the condition ID for parent linkage
        if not is_child then
          return conditions
        else
          return condition_id
        end
      end
    end
  end
  
  -- If no condition was extracted but the node has children, process them
  if not condition_id and node then
    for i = 1, #node do
      if type(node[i]) == "table" then
        -- Only process AST nodes, not scalar values
        extract_conditions(node[i], conditions, content, parent_id, false)
      end
    end
  end
  
  if not is_child then
    return conditions
  else
    return nil
  end
end

-- Connect blocks with their conditions
local function link_blocks_with_conditions(blocks, conditions)
  if not blocks or not conditions then
    return
  end
  
  -- Create a block map for faster lookup
  local block_map = {}
  for _, block in ipairs(blocks) do
    block_map[block.id] = block
  end
  
  -- Assign conditions to their parent blocks
  for _, condition in ipairs(conditions) do
    if condition.parent_id and condition.parent_id ~= "root" and block_map[condition.parent_id] then
      local parent_block = block_map[condition.parent_id]
      
      -- Initialize conditions array if not exists
      parent_block.conditions = parent_block.conditions or {}
      
      -- Add condition ID to the block
      table.insert(parent_block.conditions, condition.id)
    end
  end
end

-- Enhanced function to process If blocks with condition tracking
local function process_if_block(blocks, parent_block, node, content, block_id_counter, parent_id)
  local condition_id, then_id, else_id
  
  -- Process condition expression
  if node[1] then
    -- Extract all conditions in the expression
    local conditions = extract_conditions(node[1], {}, content, parent_id, false)
    
    -- Link conditions to the parent block
    for _, condition in ipairs(conditions) do
      if condition.parent_id == parent_id then
        table.insert(parent_block.conditions, condition.id)
      end
    end
    
    -- Add all extracted conditions to the blocks array
    for _, condition in ipairs(conditions) do
      table.insert(blocks, condition)
    end
  end
  
  -- Process then branch
  if node[2] and node[2].pos and node[2].end_pos then
    block_id_counter = block_id_counter + 1
    then_id = "then_" .. block_id_counter
    local then_start = get_line_for_position(content, node[2].pos)
    local then_end = get_line_for_position(content, node[2].end_pos)
    
    if then_start and then_end and then_start <= then_end then
      table.insert(blocks, {
        id = then_id,
        type = "then_block",
        start_line = then_start,
        end_line = then_end,
        parent_id = parent_id,
        executed = false,
        children = {},
        branches = {},
        conditions = {},
      })
      
      table.insert(parent_block.branches, then_id)
    end
  end
  
  -- Process else branch
  if node[3] and node[3].pos and node[3].end_pos then
    block_id_counter = block_id_counter + 1
    else_id = "else_" .. block_id_counter
    local else_start = get_line_for_position(content, node[3].pos)
    local else_end = get_line_for_position(content, node[3].end_pos)
    
    if else_start and else_end and else_start <= else_end then
      table.insert(blocks, {
        id = else_id,
        type = "else_block",
        start_line = else_start,
        end_line = else_end,
        parent_id = parent_id,
        executed = false,
        children = {},
        branches = {},
        conditions = {},
      })
      
      table.insert(parent_block.branches, else_id)
    end
  end
  
  return block_id_counter
end

-- Enhanced function to process While blocks with condition tracking
local function process_while_block(blocks, parent_block, node, content, block_id_counter, parent_id)
  local body_id
  
  -- Process condition expression
  if node[1] then
    -- Extract all conditions in the expression
    local conditions = extract_conditions(node[1], {}, content, parent_id, false)
    
    -- Link conditions to the parent block
    for _, condition in ipairs(conditions) do
      if condition.parent_id == parent_id then
        table.insert(parent_block.conditions, condition.id)
      end
    end
    
    -- Add all extracted conditions to the blocks array
    for _, condition in ipairs(conditions) do
      table.insert(blocks, condition)
    end
  end
  
  -- Process body
  if node[2] and node[2].pos and node[2].end_pos then
    block_id_counter = block_id_counter + 1
    body_id = "while_body_" .. block_id_counter
    local body_start = get_line_for_position(content, node[2].pos)
    local body_end = get_line_for_position(content, node[2].end_pos)
    
    if body_start and body_end and body_start <= body_end then
      table.insert(blocks, {
        id = body_id,
        type = "while_body",
        start_line = body_start,
        end_line = body_end,
        parent_id = parent_id,
        executed = false,
        children = {},
        branches = {},
        conditions = {},
      })
      
      table.insert(parent_block.branches, body_id)
    end
  end
  
  return block_id_counter
end

-- Enhanced function to process Repeat blocks with condition tracking
local function process_repeat_block(blocks, parent_block, node, content, block_id_counter, parent_id)
  local body_id
  
  -- Process body
  if node[1] and node[1].pos and node[1].end_pos then
    block_id_counter = block_id_counter + 1
    body_id = "repeat_body_" .. block_id_counter
    local body_start = get_line_for_position(content, node[1].pos)
    local body_end = get_line_for_position(content, node[1].end_pos)
    
    if body_start and body_end and body_start <= body_end then
      table.insert(blocks, {
        id = body_id,
        type = "repeat_body",
        start_line = body_start,
        end_line = body_end,
        parent_id = parent_id,
        executed = false,
        children = {},
        branches = {},
        conditions = {},
      })
      
      table.insert(parent_block.branches, body_id)
    end
  end
  
  -- Process until condition
  if node[2] then
    -- Extract all conditions in the expression
    local conditions = extract_conditions(node[2], {}, content, parent_id, false)
    
    -- Link conditions to the parent block
    for _, condition in ipairs(conditions) do
      if condition.parent_id == parent_id then
        table.insert(parent_block.conditions, condition.id)
      end
    end
    
    -- Add all extracted conditions to the blocks array
    for _, condition in ipairs(conditions) do
      table.insert(blocks, condition)
    end
  end
  
  return block_id_counter
end

-- Enhanced function to process For blocks
local function process_for_block(blocks, parent_block, node, content, block_id_counter, parent_id)
  local range_id, body_id
  
  -- Process range/iterator
  if node[1] and node[1].pos and node[1].end_pos then
    block_id_counter = block_id_counter + 1
    range_id = "for_range_" .. block_id_counter
    local range_start = get_line_for_position(content, node[1].pos)
    local range_end = get_line_for_position(content, node[1].end_pos)
    
    if range_start and range_end and range_start <= range_end then
      table.insert(blocks, {
        id = range_id,
        type = "for_range",
        subtype = node.tag == "Fornum" and "numeric" or "iterator",
        start_line = range_start,
        end_line = range_end,
        parent_id = parent_id,
        executed = false,
        children = {},
        branches = {},
        conditions = {},
      })
      
      table.insert(parent_block.branches, range_id)
    end
  end
  
  -- Process body
  if node[2] and node[2].pos and node[2].end_pos then
    block_id_counter = block_id_counter + 1
    body_id = "for_body_" .. block_id_counter
    local body_start = get_line_for_position(content, node[2].pos)
    local body_end = get_line_for_position(content, node[2].end_pos)
    
    if body_start and body_end and body_start <= body_end then
      table.insert(blocks, {
        id = body_id,
        type = "for_body",
        start_line = body_start,
        end_line = body_end,
        parent_id = parent_id,
        executed = false,
        children = {},
        branches = {},
        conditions = {},
      })
      
      table.insert(parent_block.branches, body_id)
    end
  end
  
  return block_id_counter
end

-- Process function metadata
local function process_function_block(block, node)
  -- Add function metadata
  block.metadata = block.metadata or {}
  block.metadata.is_method = false
  block.metadata.parameters = {}
  
  -- Extract parameter names
  if node.tag == "Function" and node[1] then
    for _, param in ipairs(node[1]) do
      if type(param) == "table" and param.tag == "Id" then
        table.insert(block.metadata.parameters, param[1])
      elseif type(param) == "string" then
        table.insert(block.metadata.parameters, param)
      end
    end
    
    -- Check if the first parameter is "self" (method)
    if #block.metadata.parameters > 0 and block.metadata.parameters[1] == "self" then
      block.metadata.is_method = true
    end
  end
end

-- Enhanced stack-based block finding implementation with nested AST support
local function find_blocks(ast, blocks, content, parent_id)
  -- Debug logging if enabled
  if logger.is_debug_enabled() then
    logger.debug({
      message = "find_blocks called with AST=" .. tostring(ast),
      blocks = tostring(blocks),
      content_length = content and #content or 0,
      parent_id = tostring(parent_id),
      operation = "find_blocks"
    })
  end
  
  blocks = blocks or {}
  parent_id = parent_id or "root"
  
  -- Stack for tracking parent nodes and context
  local block_stack = {}
  local block_id_counter = 0
  
  -- Block type name mapping for more readable ids
  local type_names = {
    If = "if",
    While = "while",
    Repeat = "repeat",
    Fornum = "for_num",
    Forin = "for_in",
    Function = "function",
    Block = "do_block",
    Localrec = "local_func"
  }
  
  -- Enhanced node processing function to handle various node types
  local function process_node(node, parent_id, depth, is_function_child)
    if not node or type(node) ~= "table" then
      return block_id_counter
    end
    
    -- Add a block for this node if it's a block type
    if node.tag and BLOCK_TAGS[node.tag] and node.pos and node.end_pos then
      block_id_counter = block_id_counter + 1
      local type_name = type_names[node.tag] or node.tag:lower()
      local block_id = type_name .. "_" .. block_id_counter
      
      -- Get line boundaries
      local start_line = get_line_for_position(content, node.pos)
      local end_line = get_line_for_position(content, node.end_pos)
      
      -- Only add valid blocks
      if start_line and end_line and start_line <= end_line then
        -- Create the block entry
        local block = {
          id = block_id,
          type = node.tag,
          start_line = start_line,
          end_line = end_line,
          parent_id = parent_id,
          depth = depth,
          children = {},
          branches = {},
          conditions = {},
          metadata = {
            ast_pos = node.pos,
            ast_end_pos = node.end_pos,
            node_type = node.tag
          },
          executed = false
        }
        
        -- Special handling for different block types
        if node.tag == "If" then
          -- If-then-else structure - add condition, then, and else blocks
          block_id_counter = process_if_block(blocks, block, node, content, block_id_counter, block_id)
        elseif node.tag == "While" then
          -- While loop - add condition and body
          block_id_counter = process_while_block(blocks, block, node, content, block_id_counter, block_id)
        elseif node.tag == "Repeat" then
          -- Repeat-until loop - add body and condition
          block_id_counter = process_repeat_block(blocks, block, node, content, block_id_counter, block_id)
        elseif node.tag == "Fornum" or node.tag == "Forin" then
          -- For loops - add range/iterator and body
          block_id_counter = process_for_block(blocks, block, node, content, block_id_counter, block_id)
        elseif node.tag == "Function" then
          -- Function blocks - add parameter and body metadata
          process_function_block(block, node)
        end
        
        -- Add the block to our collection
        table.insert(blocks, block)
        
        -- Process children of this block with the block as parent
        for i = 1, #node do
          if type(node[i]) == "table" then
            block_id_counter = process_node(node[i], block_id, depth + 1, node.tag == "Function")
          end
        end
      end
    elseif node.tag == "Localrec" then
      -- Special case for 'local function' declarations
      -- The function is usually the second child
      if node[2] and node[2].tag == "Function" then
        -- Process the function node with current parent
        block_id_counter = process_node(node[2], parent_id, depth, false)
      end
      
      -- Also process other children
      for i = 1, #node do
        if type(node[i]) == "table" and i ~= 2 then -- Skip the function we already processed
          block_id_counter = process_node(node[i], parent_id, depth, false)
        end
      end
    elseif node.tag == "Set" and node[2] and node[2].tag == "ExpList" then
      -- Special case for function assignments like 'foo = function()'
      for i, expr in ipairs(node[2]) do
        if expr.tag == "Function" then
          -- Process the function node with current parent
          block_id_counter = process_node(expr, parent_id, depth, false)
        end
      end
      
      -- Also process other children
      for i = 1, #node do
        if type(node[i]) == "table" and node[i].tag ~= "ExpList" then
          block_id_counter = process_node(node[i], parent_id, depth, false)
        end
      end
    else
      -- For non-block nodes, process all children
      for i = 1, #node do
        if type(node[i]) == "table" then
          block_id_counter = process_node(node[i], parent_id, depth, is_function_child)
        end
      end
    end
    
    return block_id_counter
  end
  
  -- Start processing with the root AST node
  if ast.tag == "Block" then
    -- Add a block for the root node
    block_id_counter = block_id_counter + 1
    local block_id = "do_block_" .. block_id_counter
    
    -- Get line boundaries
    local start_line = get_line_for_position(content, ast.pos)
    local end_line = get_line_for_position(content, ast.end_pos)
    
    -- Create the root block
    local root_block = {
      id = block_id,
      type = "Block",
      start_line = start_line,
      end_line = end_line,
      parent_id = parent_id,
      depth = 0,
      children = {},
      branches = {},
      conditions = {},
      metadata = {
        ast_pos = ast.pos,
        ast_end_pos = ast.end_pos,
        node_type = ast.tag
      },
      executed = false
    }
    
    -- Add the root block
    table.insert(blocks, root_block)
    
    -- Process all children of the root block
    for i = 1, #ast do
      block_id_counter = process_node(ast[i], block_id, 1, false)
    end
  end
  
  -- Post-processing: establish proper parent-child relationships
  local block_map = {}
  for _, block in ipairs(blocks) do
    block_map[block.id] = block
  end
  
  -- Build the hierarchy
  for _, block in ipairs(blocks) do
    if block.parent_id ~= "root" and block_map[block.parent_id] then
      local parent_block = block_map[block.parent_id]
      table.insert(parent_block.children, block.id)
    end
  end
  
  -- Debug logging if enabled
  if logger.is_debug_enabled() then
    logger.debug({
      message = "find_blocks completed with " .. #blocks .. " blocks",
      block_count = #blocks,
      operation = "find_blocks"
    })
    
    for i, block in ipairs(blocks) do
      logger.debug({
        message = "Block details",
        index = i,
        type = block.type or "unknown",
        id = block.id or "unknown",
        start_line = block.start_line or 0,
        end_line = block.end_line or 0,
        parent_id = block.parent_id or "none",
        operation = "find_blocks"
      })
    end
  end
  
  return blocks
end

-- Get all conditions in a file
local function find_conditions(code_map)
  -- Ensure we have a valid code map with AST
  if not code_map or not code_map.ast or not code_map.content then
    return {}
  end
  
  -- Extract all conditions from the AST
  local conditions = extract_conditions(code_map.ast, {}, code_map.content, "root", false)
  
  -- Debug logging if enabled
  if logger.is_debug_enabled() then
    logger.debug({
      message = "Found " .. #conditions .. " conditions in file",
      file = code_map.file_path,
      condition_count = #conditions,
      operation = "find_conditions"
    })
  end
  
  return conditions
end

-- Find code blocks in a given AST
function M.find_blocks(code_map)
  if not code_map or not code_map.ast or not code_map.content then
    return {}
  end
  
  -- Use the enhanced block finding implementation
  local blocks = find_blocks(code_map.ast, nil, code_map.content)
  
  -- Debug logging if enabled
  if logger.is_debug_enabled() then
    logger.debug({
      message = "Found " .. #blocks .. " blocks in file",
      file = code_map.file_path,
      block_count = #blocks,
      operation = "find_blocks"
    })
  end
  
  return blocks
end

-- Find and extract all conditions from a file
function M.find_conditions(code_map)
  return find_conditions(code_map)
end

-- Generate a code map for a file
function M.generate_code_map(file_path, ast, content)
  -- Check if we need to load the AST
  if not ast then
    local err
    ast, err = get_ast(file_path)
    if not ast then
      return nil, err
    end
  end
  
  -- Check if we need to load the content
  if not content then
    if file_cache[file_path] and file_cache[file_path].content then
      content = file_cache[file_path].content
    else
      local err
      content, err = error_handler.safe_io_operation(
        function() return filesystem.read_file(file_path) end,
        file_path,
        {operation = "generate_code_map"}
      )
      
      if not content then
        return nil, err
      end
    end
  end
  
  -- Create a code map object
  local code_map = {
    file_path = file_path,
    ast = ast,
    content = content,
    functions = {},
    blocks = {},
    conditions = {},
    lines = {},
    executable_lines = {}
  }
  
  -- Get line stats
  local line_count = 0
  for _ in content:gmatch("[^\r\n]+") do
    line_count = line_count + 1
  end
  code_map.line_count = line_count
  
  -- Find functions in the AST
  code_map.functions = M.find_functions(code_map)
  
  -- Find blocks in the AST
  code_map.blocks = M.find_blocks(code_map)
  
  -- Find conditions in the AST
  code_map.conditions = M.find_conditions(code_map)
  
  -- Link blocks with conditions
  link_blocks_with_conditions(code_map.blocks, code_map.conditions)
  
  -- Get executable lines
  code_map.executable_lines = M.get_executable_lines(file_path)
  
  -- Cache the code map
  file_cache[file_path] = file_cache[file_path] or {}
  file_cache[file_path].code_map = code_map
  
  return code_map
end

-- Analyze a file, generating a code map
function M.analyze_file(file_path)
  -- Validate input
  if type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {
        provided_type = type(file_path),
        operation = "analyze_file"
      }
    )
  end
  
  -- Check if file exists
  local exists, err = error_handler.safe_io_operation(
    function() return filesystem.exists(file_path) end,
    file_path,
    {operation = "analyze_file.exists"}
  )
  
  if not exists then
    return nil, error_handler.io_error(
      "File does not exist",
      {
        file_path = file_path,
        operation = "analyze_file"
      }
    )
  end
  
  -- Check if we already have this in cache
  if file_cache[file_path] and file_cache[file_path].code_map then
    return file_cache[file_path].code_map
  end
  
  -- Generate a new code map
  local code_map, err = M.generate_code_map(file_path)
  if not code_map then
    return nil, err
  end
  
  return code_map
end

-- Extract function information from AST
local function process_function_nodes(ast, functions, content, parent_name)
  functions = functions or {}
  local func_info = {}
  
  -- Handle different function definition patterns
  local function extract_function_name(node, parent_name)
    -- Simple named function
    if node.tag == "Function" then
      if node.name then
        return node.name
      else
        return parent_name and (parent_name .. ".<anonymous>") or "<anonymous>"
      end
    
    -- Function name from assignment: x = function()
    elseif node.tag == "Set" then
      local name = nil
      
      -- The left side has the name
      if node[1] and node[1].tag == "VarList" and node[1][1] then
        if node[1][1].tag == "Id" then
          name = node[1][1][1]
        elseif node[1][1].tag == "Index" then
          -- Handle table indexing: t.x = function()
          if node[1][1][1].tag == "Id" and node[1][1][2].tag == "String" then
            name = node[1][1][1][1] .. "." .. node[1][1][2][1]
          end
        end
      end
      
      -- Return with fallback
      return name or (parent_name and (parent_name .. ".<anonymous>") or "<anonymous>")
    
    -- Local function name
    elseif node.tag == "Localrec" then
      if node[1] and node[1].tag == "VarList" and node[1][1] and node[1][1].tag == "Id" then
        return node[1][1][1]
      else
        return parent_name and (parent_name .. ".<anonymous>") or "<anonymous>"
      end
    
    -- Method name from colon syntax: t:method()
    elseif node.tag == "Method" then
      if node[1] and node[1].tag == "Id" and node[2] and node[2].tag == "String" then
        return node[1][1] .. ":" .. node[2][1]
      else
        return parent_name and (parent_name .. ".<method>") or "<method>"
      end
    
    -- Fallback
    else
      return parent_name and (parent_name .. ".<unknown>") or "<unknown>"
    end
  end
  
  -- Process node based on type
  if ast.tag == "Function" then
    -- Basic function node
    local func_name = extract_function_name(ast, parent_name)
    
    -- Get position information
    local start_line = get_line_for_position(content, ast.pos)
    local end_line = get_line_for_position(content, ast.end_pos)
    
    -- Create function info
    if start_line and end_line and start_line <= end_line then
      table.insert(functions, {
        name = func_name,
        start_line = start_line,
        end_line = end_line,
        type = "function",
        is_method = func_name:find(":") ~= nil,
        parameters = ast[1] or {},
        body = ast[2] or {}
      })
    end
  
  elseif ast.tag == "Set" then
    -- Assignment with function: x = function()
    if ast[2] and ast[2].tag == "ExpList" then
      for _, expr in ipairs(ast[2]) do
        if expr.tag == "Function" then
          local func_name = extract_function_name(ast, parent_name)
          
          -- Get position information
          local start_line = get_line_for_position(content, expr.pos)
          local end_line = get_line_for_position(content, expr.end_pos)
          
          -- Create function info
          if start_line and end_line and start_line <= end_line then
            table.insert(functions, {
              name = func_name,
              start_line = start_line,
              end_line = end_line,
              type = "function_assignment",
              is_method = func_name:find(":") ~= nil,
              parameters = expr[1] or {},
              body = expr[2] or {}
            })
          end
        end
      end
    end
  
  elseif ast.tag == "Localrec" then
    -- Local function definition
    if ast[2] and ast[2].tag == "Function" then
      local func_name = extract_function_name(ast, parent_name)
      
      -- Get position information
      local start_line = get_line_for_position(content, ast[2].pos)
      local end_line = get_line_for_position(content, ast[2].end_pos)
      
      -- Create function info
      if start_line and end_line and start_line <= end_line then
        table.insert(functions, {
          name = func_name,
          start_line = start_line,
          end_line = end_line,
          type = "local_function",
          is_method = func_name:find(":") ~= nil,
          parameters = ast[2][1] or {},
          body = ast[2][2] or {}
        })
      end
    end
  
  elseif ast.tag == "Method" then
    -- Method definition with colon syntax
    if ast[3] and ast[3].tag == "Function" then
      local func_name = extract_function_name(ast, parent_name)
      
      -- Get position information
      local start_line = get_line_for_position(content, ast[3].pos)
      local end_line = get_line_for_position(content, ast[3].end_pos)
      
      -- Create function info
      if start_line and end_line and start_line <= end_line then
        -- Ensure the first parameter is "self"
        local params = ast[3][1] or {}
        if #params == 0 or params[1] ~= "self" then
          -- Prepend "self" if not already there
          table.insert(params, 1, "self")
        end
        
        table.insert(functions, {
          name = func_name,
          start_line = start_line,
          end_line = end_line,
          type = "method",
          is_method = true,
          parameters = params,
          body = ast[3][2] or {}
        })
      end
    end
  end
  
  -- Recursively process all children
  for i = 1, #ast do
    if type(ast[i]) == "table" then
      -- Get a function name for this context
      local context_name = parent_name
      if ast.tag == "Function" then
        context_name = extract_function_name(ast, parent_name)
      end
      
      -- Process child nodes
      process_function_nodes(ast[i], functions, content, context_name)
    end
  end
  
  return functions
end

-- Find all functions in a file
function M.find_functions(code_map)
  if not code_map or not code_map.ast or not code_map.content then
    return {}
  end
  
  -- Process all function definitions in the AST
  local functions = process_function_nodes(code_map.ast, {}, code_map.content)
  
  -- Debug logging if enabled
  if logger.is_debug_enabled() then
    logger.debug({
      message = "Found " .. #functions .. " functions in file",
      file = code_map.file_path,
      function_count = #functions,
      operation = "find_functions"
    })
  end
  
  return functions
end

-- Get functions defined in the code
function M.get_functions(code_map)
  return code_map.functions or {}
end

-- Get functions containing a specific line
function M.get_functions_for_line(code_map, line_num)
  if not code_map or not code_map.functions then
    return {}
  end
  
  local functions = {}
  for _, func in ipairs(code_map.functions) do
    if func.start_line <= line_num and func.end_line >= line_num then
      table.insert(functions, func)
    end
  end
  
  return functions
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

-- Get composite condition information
function M.get_condition_components(code_map, condition_id)
  if not code_map or not code_map.conditions then
    return {}
  end
  
  -- Find the specified condition
  local target_condition
  for _, condition in ipairs(code_map.conditions) do
    if condition.id == condition_id then
      target_condition = condition
      break
    end
  end
  
  if not target_condition or not target_condition.components then
    return {}
  end
  
  -- Get component details
  local components = {}
  for _, comp_id in ipairs(target_condition.components) do
    for _, condition in ipairs(code_map.conditions) do
      if condition.id == comp_id then
        table.insert(components, condition)
        break
      end
    end
  end
  
  return components
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

-- Calculate detailed condition coverage metrics
function M.calculate_detailed_condition_coverage(code_map)
  if not code_map or not code_map.conditions then
    return {
      total_conditions = 0,
      executed_conditions = 0,
      fully_covered_conditions = 0,
      compound_conditions = 0,
      simple_conditions = 0,
      coverage_by_type = {},
      coverage_percent = 0,
      outcome_coverage_percent = 0
    }
  end
  
  local metrics = {
    total_conditions = #code_map.conditions,
    executed_conditions = 0,
    fully_covered_conditions = 0,
    compound_conditions = 0,
    simple_conditions = 0,
    coverage_by_type = {},
    coverage_percent = 0,
    outcome_coverage_percent = 0
  }
  
  -- Count condition types
  for _, condition in ipairs(code_map.conditions) do
    -- Track by condition type
    if not metrics.coverage_by_type[condition.type] then
      metrics.coverage_by_type[condition.type] = {
        total = 0,
        executed = 0,
        fully_covered = 0
      }
    end
    
    metrics.coverage_by_type[condition.type].total = 
      metrics.coverage_by_type[condition.type].total + 1
      
    -- Count simple vs compound conditions
    if condition.is_compound then
      metrics.compound_conditions = metrics.compound_conditions + 1
    else
      metrics.simple_conditions = metrics.simple_conditions + 1
    end
    
    -- Track execution
    if condition.executed then
      metrics.executed_conditions = metrics.executed_conditions + 1
      metrics.coverage_by_type[condition.type].executed = 
        metrics.coverage_by_type[condition.type].executed + 1
        
      -- Track full coverage (both true and false outcomes)
      if condition.executed_true and condition.executed_false then
        metrics.fully_covered_conditions = metrics.fully_covered_conditions + 1
        metrics.coverage_by_type[condition.type].fully_covered = 
          metrics.coverage_by_type[condition.type].fully_covered + 1
      end
    end
  end
  
  -- Calculate percentages
  if metrics.total_conditions > 0 then
    metrics.coverage_percent = (metrics.executed_conditions / metrics.total_conditions) * 100
    metrics.outcome_coverage_percent = (metrics.fully_covered_conditions / metrics.total_conditions) * 100
  end
  
  return metrics
end

-- Update the code map with new coverage data
function M.update_code_map(code_map, coverage_data)
  if not code_map or not coverage_data then
    return code_map
  end
  
  -- Update function execution information
  if code_map.functions and coverage_data.functions then
    for _, func in ipairs(code_map.functions) do
      local key = func.name .. ":" .. func.start_line .. "-" .. func.end_line
      if coverage_data.functions[key] then
        func.executed = true
        func.execution_count = coverage_data.functions[key].count or 0
      end
    end
  end
  
  -- Update block execution information
  if code_map.blocks and coverage_data.blocks then
    for _, block in ipairs(code_map.blocks) do
      local key = block.type .. ":" .. block.start_line .. "-" .. block.end_line
      if coverage_data.blocks[key] then
        block.executed = true
        block.execution_count = coverage_data.blocks[key].count or 0
      end
    end
  end
  
  -- Update condition execution information
  if code_map.conditions and coverage_data.conditions then
    for _, condition in ipairs(code_map.conditions) do
      local key = condition.type .. ":" .. condition.start_line .. "-" .. condition.end_line
      if coverage_data.conditions[key] then
        condition.executed = true
        condition.execution_count = coverage_data.conditions[key].count or 0
        condition.executed_true = coverage_data.conditions[key].result_true or false
        condition.executed_false = coverage_data.conditions[key].result_false or false
      end
    end
  end
  
  return code_map
end

-- Determine if a given line is executable
function M.is_executable_line(code_map, line_num)
  if not code_map or not code_map.executable_lines then
    return false
  end
  
  for _, exec_line in ipairs(code_map.executable_lines) do
    if exec_line == line_num then
      return true
    end
  end
  
  return false
end

-- Calculate function coverage statistics
function M.calculate_function_coverage(code_map)
  if not code_map or not code_map.functions then
    return {
      total_functions = 0,
      executed_functions = 0,
      coverage_percent = 0
    }
  end
  
  local total_functions = #code_map.functions
  local executed_functions = 0
  
  for _, func in ipairs(code_map.functions) do
    if func.executed then
      executed_functions = executed_functions + 1
    end
  end
  
  return {
    total_functions = total_functions,
    executed_functions = executed_functions,
    coverage_percent = total_functions > 0 and (executed_functions / total_functions * 100) or 0
  }
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

-- Calculate line coverage statistics
function M.calculate_line_coverage(code_map, exec_lines)
  if not code_map then
    return {
      total_lines = 0,
      executable_lines = 0,
      executed_lines = 0,
      coverage_percent = 0
    }
  end
  
  local total_lines = code_map.line_count or 0
  local executable_lines = #(code_map.executable_lines or {})
  local executed_lines = 0
  
  -- Count executed lines
  if exec_lines then
    for line, _ in pairs(exec_lines) do
      if M.is_executable_line(code_map, tonumber(line)) then
        executed_lines = executed_lines + 1
      end
    end
  end
  
  return {
    total_lines = total_lines,
    executable_lines = executable_lines,
    executed_lines = executed_lines,
    coverage_percent = executable_lines > 0 and (executed_lines / executable_lines * 100) or 0
  }
end

-- Calculate overall coverage statistics
function M.calculate_coverage(code_map, exec_lines)
  if not code_map then
    return {
      line_coverage = M.calculate_line_coverage(nil),
      function_coverage = M.calculate_function_coverage(nil),
      block_coverage = M.calculate_block_coverage(nil),
      condition_coverage = M.calculate_condition_coverage(nil)
    }
  end
  
  return {
    line_coverage = M.calculate_line_coverage(code_map, exec_lines),
    function_coverage = M.calculate_function_coverage(code_map),
    block_coverage = M.calculate_block_coverage(code_map),
    condition_coverage = M.calculate_condition_coverage(code_map)
  }
end

return M
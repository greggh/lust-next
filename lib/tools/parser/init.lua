-- lust-next parser module
-- Based on lua-parser (https://github.com/andremm/lua-parser)
-- MIT License

local M = {}
local fs = require("lib.tools.filesystem")

-- Load LPegLabel first to ensure it's available
local has_lpeglabel, lpeg = pcall(require, "lib.tools.vendor.lpeglabel")
if not has_lpeglabel then
  error("LPegLabel is required for the parser module")
end

-- Import parser components
local parser = require("lib.tools.parser.grammar")
local pp = require("lib.tools.parser.pp")
local validator = require("lib.tools.parser.validator")

-- Utility functions for scope and position tracking
local scope_util = {
  -- Calculate line number and column from position in a string
  lineno = function(subject, pos)
    if not subject or pos > #subject then pos = #subject or 0 end
    local line, col = 1, 1
    for i = 1, pos do
      if subject:sub(i, i) == '\n' then
        line = line + 1
        col = 1
      else
        col = col + 1
      end
    end
    return line, col
  end
}

-- Parse a Lua source string into an AST with improved protection
-- @param source (string) The Lua source code to parse
-- @param name (string, optional) Name to use in error messages
-- @return (table) The AST representing the Lua code, or nil if there was an error
-- @return (string) Error message in case of failure
function M.parse(source, name)
  name = name or "input"
  
  if type(source) ~= "string" then
    return nil, "Expected string source, got " .. type(source)
  end
  
  -- Safety limit for source size INCREASED to 1MB
  if #source > 1024000 then -- 1MB limit
    return nil, "Source too large for parsing: " .. (#source/1024) .. "KB"
  end
  
  -- Add timeout protection with INCREASED limits
  local start_time = os.clock()
  local MAX_PARSE_TIME = 10.0 -- 10 second timeout for parsing
  
  -- Create a thread to handle parsing with timeout
  local co = coroutine.create(function()
    return parser.parse(source, name)
  end)
  
  -- Run the coroutine with timeout checks
  local status, result, error_msg
  
  while coroutine.status(co) ~= "dead" do
    -- Check if we've exceeded the time limit
    if os.clock() - start_time > MAX_PARSE_TIME then
      return nil, "Parse timeout exceeded (" .. MAX_PARSE_TIME .. "s)"
    end
    
    -- Resume the coroutine for a bit
    status, result, error_msg = coroutine.resume(co)
    
    -- If coroutine failed, return the error
    if not status then
      return nil, "Parser error: " .. tostring(result)
    end
    
    -- Brief yield to allow other processes
    if coroutine.status(co) ~= "dead" then
      coroutine.yield()
    end
  end
  
  -- Check the parse result
  local ast = result
  if not ast then
    return nil, error_msg or "Parse error"
  end
  
  -- Verify the AST is a valid table to avoid crashes
  if type(ast) ~= "table" then
    return nil, "Invalid AST returned (not a table)"
  end
  
  return ast
end

-- Parse a Lua source file into an AST
-- @param file_path (string) Path to the Lua file
-- @return (table) The AST representing the Lua code, or nil if there was an error
-- @return (string) Error message in case of failure
function M.parse_file(file_path)
  if not fs.file_exists(file_path) then
    return nil, "File not found: " .. file_path
  end
  
  local source = fs.read_file(file_path)
  if not source then
    return nil, "Failed to read file: " .. file_path
  end
  
  return M.parse(source, file_path)
end

-- Pretty print an AST
-- @param ast (table) The AST to print
-- @return (string) Pretty-printed representation of the AST
function M.pretty_print(ast)
  if type(ast) ~= "table" then
    return "Not a valid AST"
  end
  
  return pp.tostring(ast)
end

-- Validate an AST for semantic correctness
-- @param ast (table) The AST to validate
-- @return (boolean) True if the AST is valid, false otherwise
-- @return (string) Error message in case of failure
function M.validate(ast)
  if type(ast) ~= "table" then
    return false, "Not a valid AST"
  end
  
  local ok, err = validator.validate(ast)
  return ok, err
end

-- Helper function to determine if a node is executable
local function is_executable_node(tag)
  -- Control flow statements and structural elements are not directly executable
  local non_executable = {
    ["If"] = true,
    ["Block"] = true,
    ["While"] = true,
    ["Repeat"] = true,
    ["Fornum"] = true,
    ["Forin"] = true,
    ["Function"] = true,
    ["Label"] = true
  }
  
  return not non_executable[tag]
end

-- Process node recursively to find executable lines
local function process_node_for_lines(node, lines, source_lines)
  if not node or type(node) ~= "table" then return end
  
  local tag = node.tag
  if not tag then return end
  
  -- Record the position of this node if it has one
  if node.pos and node.end_pos and is_executable_node(tag) then
    local start_line, _ = scope_util.lineno(source_lines, node.pos)
    local end_line, _ = scope_util.lineno(source_lines, node.end_pos)
    
    for line = start_line, end_line do
      lines[line] = true
    end
  end
  
  -- Process child nodes
  for i, child in ipairs(node) do
    if type(child) == "table" then
      process_node_for_lines(child, lines, source_lines)
    end
  end
end

-- Extract executable lines from an AST
-- @param ast (table) The AST to analyze
-- @param source (string) Optional source code for more precise line mapping
-- @return (table) Map of line numbers to executable status (true if executable)
function M.get_executable_lines(ast, source)
  if type(ast) ~= "table" then
    return {}
  end
  
  local lines = {}
  process_node_for_lines(ast, lines, source or "")
  
  return lines
end

-- Helper to determine function node from AST
local function is_function_node(node)
  return node and node.tag == "Function"
end

-- Extract function info from a function node
local function get_function_info(node, source, parent_name)
  if not is_function_node(node) then return nil end
  
  local func_info = {
    pos = node.pos,
    end_pos = node.end_pos,
    name = parent_name or "anonymous",
    is_method = false,
    params = {},
    is_vararg = false,
    line_start = 0,
    line_end = 0
  }
  
  -- Get line range
  if source and node.pos then
    func_info.line_start, _ = scope_util.lineno(source, node.pos)
    func_info.line_end, _ = scope_util.lineno(source, node.end_pos)
  end
  
  -- Process parameter list
  if node[1] then
    for i, param in ipairs(node[1]) do
      if param.tag == "Id" then
        table.insert(func_info.params, param[1])
      elseif param.tag == "Dots" then
        func_info.is_vararg = true
      end
    end
  end
  
  return func_info
end

-- Process node recursively to find function definitions
local function process_node_for_functions(node, functions, source, parent_name)
  if not node or type(node) ~= "table" then return end
  
  local tag = node.tag
  if not tag then return end
  
  -- Handle function definitions
  if tag == "Function" then
    local func_info = get_function_info(node, source, parent_name)
    if func_info then
      table.insert(functions, func_info)
    end
  elseif tag == "Localrec" and node[2] and node[2][1] and node[2][1].tag == "Function" then
    -- Handle local function declaration: local function foo()
    local name = node[1][1][1]  -- Extract name from the Id node
    local func_info = get_function_info(node[2][1], source, name)
    if func_info then
      table.insert(functions, func_info)
    end
  elseif tag == "Set" and node[2] and node[2][1] and node[2][1].tag == "Function" then
    -- Handle global/table function assignment: function foo() or t.foo = function()
    local name = "anonymous"
    if node[1] and node[1][1] then
      if node[1][1].tag == "Id" then
        name = node[1][1][1]
      elseif node[1][1].tag == "Index" then
        -- Handle table function assignment
        local t_name = node[1][1][1][1] or "table"
        local f_name = node[1][1][2][1] or "method"
        name = t_name .. "." .. f_name
      end
    end
    local func_info = get_function_info(node[2][1], source, name)
    if func_info then
      table.insert(functions, func_info)
    end
  end
  
  -- Process child nodes
  for i, child in ipairs(node) do
    if type(child) == "table" then
      process_node_for_functions(child, functions, source, parent_name)
    end
  end
end

-- Extract function definitions from an AST
-- @param ast (table) The AST to analyze
-- @param source (string) Optional source code for more precise line mapping
-- @return (table) List of function definitions with their line ranges
function M.get_functions(ast, source)
  if type(ast) ~= "table" then
    return {}
  end
  
  local functions = {}
  process_node_for_functions(ast, functions, source or "")
  
  return functions
end

-- Create a code map with detailed information about the source
-- @param source (string) The Lua source code
-- @param name (string, optional) Name to use in error messages
-- @return (table) Code map with detailed information
function M.create_code_map(source, name)
  name = name or "input"
  
  -- Parse the source
  local ast, err = M.parse(source, name)
  if not ast then
    return {
      error = err,
      source = source,
      lines = {},
      functions = {},
      valid = false
    }
  end
  
  -- Split source into lines
  local lines = {}
  for line in source:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  -- Build the code map
  local code_map = {
    source = source,
    ast = ast,
    lines = lines,
    source_lines = #lines,
    executable_lines = M.get_executable_lines(ast),
    functions = M.get_functions(ast),
    valid = true
  }
  
  return code_map
end

-- Create a code map from a file
-- @param file_path (string) Path to the Lua file
-- @return (table) Code map with detailed information
function M.create_code_map_from_file(file_path)
  if not fs.file_exists(file_path) then
    return {
      error = "File not found: " .. file_path,
      valid = false
    }
  end
  
  local source = fs.read_file(file_path)
  if not source then
    return {
      error = "Failed to read file: " .. file_path,
      valid = false
    }
  end
  
  return M.create_code_map(source, file_path)
end

return M
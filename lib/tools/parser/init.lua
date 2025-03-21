-- firmo parser module
-- Based on lua-parser (https://github.com/andremm/lua-parser)
-- MIT License

---@class parser_module
---@field _VERSION string Module version
---@field parse fun(input: string, options?: {annotate_positions?: boolean, label_errors?: boolean, extract_comments?: boolean, syntax_level?: number}): table|nil, table? Parse Lua code into an abstract syntax tree
---@field parse_file fun(file_path: string, options?: {annotate_positions?: boolean, label_errors?: boolean, extract_comments?: boolean, syntax_level?: number}): table|nil, table? Parse a Lua file into an abstract syntax tree
---@field validate fun(ast: table, options?: {detailed?: boolean, check_scope?: boolean, check_references?: boolean}): boolean, table? Check if an AST is valid
---@field to_string fun(ast: table, options?: {indentation?: number, line_length?: number, preserve_comments?: boolean}): string Convert an AST back to Lua code
---@field AST table<string, fun(...): table> AST node constructors for building syntax trees
---@field analyze fun(ast: table, options?: {count_nodes?: boolean, calculate_metrics?: boolean, detect_patterns?: boolean}): {node_count: table<string, number>, metrics: table, patterns: table} Analyze a Lua AST for metrics and statistics
---@field format fun(input: string, options?: {indentation?: number, line_length?: number, preserve_comments?: boolean}): string|nil, string? Format Lua code
---@field get_line_info fun(subject: string, pos: number): {line: number, col: number} Get line and column info for a position in code
---@field extract_comments fun(subject: string): table<number, {line: number, text: string, type: string}> Extract comments from Lua source code
---@field get_grammar fun(): table Get the Lua grammar definition
---@field tokenize fun(subject: string): table<number, {type: string, value: string, line: number, col: number}> Split Lua code into tokens
---@field find_syntax_errors fun(subject: string): table<number, {message: string, line: number, col: number}> Find syntax errors in Lua code
---@field get_node_at_position fun(ast: table, line: number, col: number): table|nil Find AST node at a specific position in the code
---@field parse_expression fun(expression: string): table|nil, table? Parse a Lua expression (not a full chunk)
---@field check_lua_syntax fun(subject: string): boolean, string? Check if a string is valid Lua syntax

local M = {
  -- Module version
  _VERSION = "1.0.0"
}

local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("parser")
logging.configure_from_config("parser")

-- Load LPegLabel first to ensure it's available
local has_lpeglabel, lpeg = pcall(require, "lib.tools.vendor.lpeglabel")
if not has_lpeglabel then
  logger.error("Failed to load required dependency", {
    module = "LPegLabel",
    error = tostring(lpeg)
  })
  error("LPegLabel is required for the parser module")
end

logger.debug("LPegLabel loaded successfully", {
  module = "parser"
})

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
--- Parse Lua code into an abstract syntax tree
---@param source string The Lua source code to parse
---@param name? string Optional name for the source (for error messages)
---@return table|nil ast The abstract syntax tree, or nil on error
---@return table? error_info Error information if parsing failed
function M.parse(source, name)
  name = name or "input"
  
  logger.debug("Parsing Lua source", {
    source_name = name,
    source_length = source and #source or 0
  })
  
  if type(source) ~= "string" then
    local error_msg = "Expected string source, got " .. type(source)
    logger.error("Invalid source type", {
      expected = "string",
      actual = type(source)
    })
    return nil, error_msg
  end
  
  -- Safety limit for source size INCREASED to 1MB
  if #source > 1024000 then -- 1MB limit
    local error_msg = "Source too large for parsing: " .. (#source/1024) .. "KB"
    logger.error("Source size limit exceeded", {
      size_kb = (#source/1024),
      limit_kb = 1024,
      source_name = name
    })
    return nil, error_msg
  end
  
  -- Add timeout protection with INCREASED limits
  local start_time = os.clock()
  local MAX_PARSE_TIME = 10.0 -- 10 second timeout for parsing
  
  logger.debug("Starting parse with timeout protection", {
    timeout_seconds = MAX_PARSE_TIME,
    source_name = name
  })
  
  -- Create a thread to handle parsing with timeout
  local co = coroutine.create(function()
    return parser.parse(source, name)
  end)
  
  -- Run the coroutine with timeout checks
  local status, result, error_msg
  
  while coroutine.status(co) ~= "dead" do
    -- Check if we've exceeded the time limit
    if os.clock() - start_time > MAX_PARSE_TIME then
      local timeout_error = "Parse timeout exceeded (" .. MAX_PARSE_TIME .. "s)"
      logger.error("Parse timeout", {
        timeout_seconds = MAX_PARSE_TIME,
        source_name = name,
        elapsed = os.clock() - start_time
      })
      return nil, timeout_error
    end
    
    -- Resume the coroutine for a bit
    status, result, error_msg = coroutine.resume(co)
    
    -- If coroutine failed, return the error
    if not status then
      local parse_error = "Parser error: " .. tostring(result)
      logger.error("Parser coroutine failed", {
        error = tostring(result),
        source_name = name
      })
      return nil, parse_error
    end
    
    -- Brief yield to allow other processes
    if coroutine.status(co) ~= "dead" then
      coroutine.yield()
    end
  end
  
  -- Check the parse result
  local ast = result
  if not ast then
    logger.error("Parse returned no AST", {
      error = error_msg or "Unknown parse error",
      source_name = name
    })
    return nil, error_msg or "Parse error"
  end
  
  -- Verify the AST is a valid table to avoid crashes
  if type(ast) ~= "table" then
    logger.error("Invalid AST type", {
      expected = "table",
      actual = type(ast),
      source_name = name
    })
    return nil, "Invalid AST returned (not a table)"
  end
  
  logger.debug("Successfully parsed Lua source", {
    source_name = name,
    parse_time = os.clock() - start_time
  })
  
  return ast
end

-- Parse a Lua source file into an AST
-- @param file_path (string) Path to the Lua file
-- @return (table) The AST representing the Lua code, or nil if there was an error
-- @return (string) Error message in case of failure
--- Parse a Lua file into an abstract syntax tree
---@param file_path string Path to the Lua file to parse
---@return table|nil ast The abstract syntax tree, or nil on error
---@return table? error_info Error information if parsing failed
function M.parse_file(file_path)
  logger.debug("Parsing Lua file", {
    file_path = file_path
  })
  
  if not fs.file_exists(file_path) then
    logger.error("File not found for parsing", {
      file_path = file_path
    })
    return nil, "File not found: " .. file_path
  end
  
  local source, read_error = fs.read_file(file_path)
  if not source then
    logger.error("Failed to read file for parsing", {
      file_path = file_path,
      error = read_error or "Unknown read error"
    })
    return nil, "Failed to read file: " .. file_path
  end
  
  logger.debug("File read successfully for parsing", {
    file_path = file_path,
    source_length = #source
  })
  
  return M.parse(source, file_path)
end

-- Pretty print an AST
-- @param ast (table) The AST to print
-- @return (string) Pretty-printed representation of the AST
--- Convert an AST to a human-readable string representation
---@param ast table The abstract syntax tree to print
---@return string representation String representation of the AST
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
--- Validate that an AST is properly structured
---@param ast table The abstract syntax tree to validate
---@return boolean is_valid Whether the AST is valid
---@return table? error_info Error information if validation failed
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
--- Get a list of executable lines from a Lua AST
---@param ast table The abstract syntax tree 
---@param source string The original source code
---@return table executable_lines Table mapping line numbers to executability status
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
--- Get a list of functions and their positions from a Lua AST
---@param ast table The abstract syntax tree
---@param source string The original source code
---@return table functions List of functions with their line numbers and names
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
--- Create a detailed map of a Lua source code file including AST, executable lines, and functions
---@param source string The Lua source code
---@param name? string Optional name for the source (for error messages)
---@return table|nil code_map The code map containing AST and analysis, or nil on error
---@return table? error_info Error information if mapping failed
function M.create_code_map(source, name)
  name = name or "input"
  
  logger.debug("Creating code map from source", {
    source_name = name,
    source_length = source and #source or 0
  })
  
  -- Parse the source
  local ast, err = M.parse(source, name)
  if not ast then
    logger.error("Failed to parse source for code map", {
      source_name = name,
      error = err
    })
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
  
  logger.debug("Source split into lines", {
    source_name = name,
    line_count = #lines
  })
  
  -- Get executable lines
  local executable_lines = M.get_executable_lines(ast, source)
  
  -- Count executable lines for logging
  local executable_count = 0
  for _ in pairs(executable_lines) do
    executable_count = executable_count + 1
  end
  
  -- Get functions
  local functions = M.get_functions(ast, source)
  
  logger.debug("Code analysis complete", {
    source_name = name,
    executable_lines = executable_count,
    function_count = #functions
  })
  
  -- Build the code map
  local code_map = {
    source = source,
    ast = ast,
    lines = lines,
    source_lines = #lines,
    executable_lines = executable_lines,
    functions = functions,
    valid = true
  }
  
  return code_map
end

-- Create a code map from a file
-- @param file_path (string) Path to the Lua file
-- @return (table) Code map with detailed information
--- Create a detailed map of a Lua file including AST, executable lines, and functions
---@param file_path string Path to the Lua file
---@return table|nil code_map The code map containing AST and analysis, or nil on error
---@return table? error_info Error information if mapping failed
function M.create_code_map_from_file(file_path)
  logger.debug("Creating code map from file", {
    file_path = file_path
  })
  
  if not fs.file_exists(file_path) then
    logger.error("File not found for code map creation", {
      file_path = file_path
    })
    return {
      error = "File not found: " .. file_path,
      valid = false
    }
  end
  
  local source, read_error = fs.read_file(file_path)
  if not source then
    logger.error("Failed to read file for code map creation", {
      file_path = file_path,
      error = read_error or "Unknown read error"
    })
    return {
      error = "Failed to read file: " .. file_path,
      valid = false
    }
  end
  
  logger.debug("File read successfully for code map creation", {
    file_path = file_path,
    source_length = #source
  })
  
  local code_map = M.create_code_map(source, file_path)
  
  logger.debug("Code map created", {
    file_path = file_path,
    valid = code_map.valid,
    executable_lines = code_map.executable_lines and table.concat(
      (function()
        local keys = {}
        for k, _ in pairs(code_map.executable_lines) do
          table.insert(keys, tostring(k))
        end
        return keys
      end)(), ","
    ),
    function_count = code_map.functions and #code_map.functions or 0
  })
  
  return code_map
end

return M

-- Assertion analyzer for mapping assertions to covered code
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config")
local parser = require("lib.tools.parser.grammar")
local transformer = require("lib.coverage.v3.instrumentation.transformer")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.assertion.analyzer")

---@class coverage_v3_assertion_analyzer
---@field analyze_assertion fun(assertion_node: table): table|nil Analyze an assertion to determine what code it verifies
---@field analyze_test_file fun(file_path: string): table|nil Analyze a test file to map assertions to code
---@field track_assertion fun(file: string, line: number, value: any) Track an assertion and what it verifies
---@field get_assertion_mappings fun(file: string): table Get mappings between assertions and covered code
---@field reset fun() Reset all assertion mappings
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Store assertion mappings
local assertion_mappings = {}

-- Reset all assertion mappings
function M.reset()
  assertion_mappings = {}
  logger.debug("Reset assertion mappings")
end

-- Helper to create a new mapping entry
local function create_mapping_entry(file, line)
  local entry = {
    file = file,
    line = line,
    lines = {},
    functions = {},
    properties = {},
    timestamp = os.time()
  }
  
  if not assertion_mappings[file] then
    assertion_mappings[file] = {}
  end
  
  table.insert(assertion_mappings[file], entry)
  return entry
end

-- Helper to find mapping entry
local function find_mapping_entry(file, line)
  if not assertion_mappings[file] then
    return nil
  end
  
  for _, entry in ipairs(assertion_mappings[file]) do
    if entry.line == line then
      return entry
    end
  end
  
  return nil
end

-- Track an assertion and what it verifies
function M.track_assertion(file, line, value)
  -- Get or create mapping entry
  local entry = find_mapping_entry(file, line) or create_mapping_entry(file, line)
  
  -- Track lines
  if type(value) == "function" then
    -- Get function source
    local source = string.dump(value)
    if source then
      -- Parse function source
      local ast, err = parser.parse(source, file)
      if ast then
        -- Transform AST to find executable lines
        local transformed, source_map = transformer.transform(ast)
        if transformed and source_map then
          -- Add all executable lines to mapping
          for _, line_info in ipairs(source_map) do
            table.insert(entry.lines, line_info.line)
          end
          table.insert(entry.functions, value)
        end
      end
    end
  elseif type(value) == "table" then
    -- Track table properties
    for k, v in pairs(value) do
      if type(v) == "function" then
        table.insert(entry.properties, k)
        M.track_assertion(file, line, v)
      end
    end
  end
end

-- Get mappings between assertions and covered code
function M.get_assertion_mappings(file)
  return assertion_mappings[file] or {}
end

-- Helper to analyze an assertion expression
local function analyze_assertion_expr(expr)
  -- Skip if not an expression
  if not expr or type(expr) ~= "table" then
    return {}
  end
  
  -- Track verified code
  local verified = {}
  
  -- Handle different types of assertions
  if expr.tag == "Call" then
    -- Function call - track the function and its arguments
    if expr[1] and expr[1].tag == "Id" then
      verified[#verified + 1] = {
        type = "function",
        name = expr[1][1]
      }
    end
    
    -- Track arguments
    if expr[2] and expr[2].tag == "ExpList" then
      for _, arg in ipairs(expr[2]) do
        if arg.tag == "Id" then
          verified[#verified + 1] = {
            type = "variable",
            name = arg[1]
          }
        elseif arg.tag == "Index" then
          verified[#verified + 1] = {
            type = "property",
            object = arg[1][1],
            property = arg[2][1]
          }
        end
      end
    end
  elseif expr.tag == "Index" then
    -- Property access - track the object and property
    verified[#verified + 1] = {
      type = "property",
      object = expr[1][1],
      property = expr[2][1]
    }
  end
  
  return verified
end

-- Analyze an assertion to determine what code it verifies
function M.analyze_assertion(assertion_node)
  if not assertion_node or type(assertion_node) ~= "table" then
    return nil, "Invalid assertion node"
  end
  
  -- Get assertion information
  local info = {
    type = assertion_node.tag,
    line = assertion_node.line,
    verified_code = {}
  }
  
  -- Analyze the assertion expression
  local verified = analyze_assertion_expr(assertion_node)
  for _, v in ipairs(verified) do
    table.insert(info.verified_code, v)
  end
  
  return info
end

-- Analyze a test file to map assertions to code
function M.analyze_test_file(file_path)
  -- Read the file
  local file = io.open(file_path)
  if not file then
    return nil, "Cannot open file: " .. file_path
  end
  
  local source = file:read("*a")
  file:close()
  
  -- Parse the file
  local ast, err = parser.parse(source, file_path)
  if not ast then
    return nil, err
  end
  
  -- Find all assertions
  local assertions = {}
  
  -- Helper to find assertions in a node
  local function find_assertions(node)
    if not node or type(node) ~= "table" then
      return
    end
    
    -- Check if this is an assertion
    if node.tag == "Call" and node[1] and node[1].tag == "Id" and
       (node[1][1] == "expect" or node[1][1] == "assert") then
      -- Analyze the assertion
      local info = M.analyze_assertion(node)
      if info then
        table.insert(assertions, info)
      end
    end
    
    -- Recursively check child nodes
    for _, child in ipairs(node) do
      find_assertions(child)
    end
  end
  
  -- Find all assertions in the AST
  find_assertions(ast)
  
  return assertions
end

return M
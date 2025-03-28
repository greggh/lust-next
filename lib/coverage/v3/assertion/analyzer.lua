-- Assertion analyzer for mapping assertions to covered code
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config")
local parser = require("lib.tools.parser.grammar")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.assertion.analyzer")

---@class coverage_v3_assertion_analyzer
---@field analyze_assertion fun(assertion_node: table): table|nil Analyze an assertion to determine what code it verifies
---@field analyze_test_file fun(file_path: string): table|nil Analyze a test file to map assertions to code
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

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
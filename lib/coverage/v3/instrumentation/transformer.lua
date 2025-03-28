-- V3 Coverage Transformer
-- Transforms Lua source code to add coverage tracking

local parser = require("lib.tools.parser")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.transformer")

local M = {
  _VERSION = "3.0.0"
}

-- Map operator names to symbols
local op_symbols = {
  add = "+",
  sub = "-",
  mul = "*",
  div = "/",
  idiv = "//",
  mod = "%",
  pow = "^",
  concat = "..",
  eq = "==",
  ne = "~=",
  lt = "<",
  le = "<=",
  gt = ">",
  ge = ">=",
  and_ = "and",
  or_ = "or",
  not_ = "not",
  len = "#",
  unm = "-",
  bnot = "~",
  band = "&",
  bor = "|",
  bxor = "~",
  shl = "<<",
  shr = ">>"
}

-- Convert AST back to Lua code
local function ast_to_string(ast)
  if not ast then return "" end
  
  local function indent(level)
    return string.rep("  ", level)
  end
  
  local function visit(node, level)
    level = level or 0
    if type(node) ~= "table" then return tostring(node) end
    
    local result = {}
    if node.tag == "Block" then
      for _, stmt in ipairs(node) do
        table.insert(result, indent(level) .. visit(stmt, level))
      end
      return table.concat(result, "\n")
    
    elseif node.tag == "Call" then
      local func = visit(node[1])
      local args = {}
      for i=2, #node do
        table.insert(args, visit(node[i]))
      end
      return func .. "(" .. table.concat(args, ", ") .. ")"
    
    elseif node.tag == "Id" then
      return node[1]
    
    elseif node.tag == "String" then
      return string.format("%q", node[1])
    
    elseif node.tag == "Number" then
      return tostring(node[1])
    
    elseif node.tag == "Function" then
      local params = {}
      for _, param in ipairs(node[1]) do
        table.insert(params, visit(param))
      end
      return "function(" .. table.concat(params, ", ") .. ")\n" ..
             visit(node[2], level + 1) .. "\n" ..
             indent(level) .. "end"
    
    elseif node.tag == "Local" then
      local names = {}
      for _, name in ipairs(node[1]) do
        table.insert(names, visit(name))
      end
      local values = {}
      if node[2] then
        for _, value in ipairs(node[2]) do
          table.insert(values, visit(value))
        end
      end
      if #values > 0 then
        return "local " .. table.concat(names, ", ") .. " = " .. table.concat(values, ", ")
      else
        return "local " .. table.concat(names, ", ")
      end
    
    elseif node.tag == "Set" then
      local vars = {}
      for _, var in ipairs(node[1]) do
        table.insert(vars, visit(var))
      end
      local values = {}
      for _, value in ipairs(node[2]) do
        table.insert(values, visit(value))
      end
      return table.concat(vars, ", ") .. " = " .. table.concat(values, ", ")
    
    elseif node.tag == "Return" then
      local values = {}
      for _, value in ipairs(node) do
        table.insert(values, visit(value))
      end
      return "return " .. table.concat(values, ", ")
    
    elseif node.tag == "If" then
      local result = "if " .. visit(node[1]) .. " then\n"
      result = result .. visit(node[2], level + 1) .. "\n"
      result = result .. indent(level) .. "end"
      return result
    
    elseif node.tag == "Index" then
      -- Handle both string and identifier indices
      local base = visit(node[1])
      local index = node[2]
      if index.tag == "String" then
        -- For string indices, use dot notation if possible
        if index[1]:match("^[%a_][%w_]*$") then
          return base .. "." .. index[1]
        else
          return base .. "[" .. visit(index) .. "]"
        end
      else
        return base .. "." .. visit(index)
      end
    
    elseif node.tag == "Op" then
      if #node == 2 then
        -- Unary operator
        local op = op_symbols[node[1]] or node[1]
        return op .. visit(node[2])
      else
        -- Binary operator
        local op = op_symbols[node[1]] or node[1]
        return visit(node[2]) .. " " .. op .. " " .. visit(node[3])
      end
    end
    
    return ""
  end
  
  return visit(ast)
end

-- Get line number from AST node
local function get_line(node)
  if type(node) ~= "table" then return 0 end
  if type(node.line) == "number" then return node.line end
  if type(node.pos) == "table" and type(node.pos.line) == "number" then return node.pos.line end
  return 0
end

-- Track function calls and assertions
local function add_tracking_calls(ast, filename)
  if not ast or type(ast) ~= "table" then return ast end
  
  -- Handle function definitions
  if ast.tag == "Function" then
    -- Add tracking to function body
    local body = ast[2]
    local tracking = {
      tag = "Call",
      [1] = {
        tag = "Id",
        [1] = "__firmo_v3_track_function_entry"
      },
      [2] = {
        tag = "String",
        [1] = filename
      },
      [3] = {
        tag = "Number",
        [1] = get_line(ast)
      }
    }
    
    -- Insert tracking at start of function body
    table.insert(body, 1, tracking)
  end
  
  -- Handle function calls
  if ast.tag == "Call" then
    local func = ast[1]
    if func.tag == "Id" and func[1] == "expect" then
      -- Add assertion tracking
      local cleanup_var = "__firmo_v3_cleanup_" .. tostring({}):match("table: (.+)")
      local tracking = {
        tag = "Local",
        [1] = {{
          tag = "Id",
          [1] = cleanup_var
        }},
        [2] = {{
          tag = "Call",
          [1] = {
            tag = "Id",
            [1] = "__firmo_v3_track_assertion"
          },
          [2] = {
            tag = "String",
            [1] = filename
          },
          [3] = {
            tag = "Number",
            [1] = get_line(ast)
          }
        }}
      }
      
      -- Add cleanup call after assertion
      local cleanup = {
        tag = "Call",
        [1] = {
          tag = "Id",
          [1] = cleanup_var
        }
      }
      
      return {
        tag = "Block",
        tracking,
        ast,
        cleanup
      }
    else
      -- Add line tracking before call
      local tracking = {
        tag = "Call",
        [1] = {
          tag = "Id",
          [1] = "__firmo_v3_track_line"
        },
        [2] = {
          tag = "String",
          [1] = filename
        },
        [3] = {
          tag = "Number",
          [1] = get_line(ast)
        }
      }
      
      return {
        tag = "Block",
        tracking,
        ast
      }
    end
  end
  
  -- Recursively process child nodes
  for i, child in ipairs(ast) do
    if type(child) == "table" then
      ast[i] = add_tracking_calls(child, filename)
    end
  end
  
  return ast
end

-- Transform source code by adding coverage tracking
function M.transform(source, filename)
  logger.debug("Transforming source", {
    filename = filename,
    source_length = #source
  })
  
  -- Parse source into AST
  local ast, err = parser.parse(source, filename)
  if not ast then
    logger.error("Failed to parse source", {
      filename = filename,
      error = err
    })
    return nil, err
  end
  
  -- Add tracking calls
  local instrumented_ast = add_tracking_calls(ast, filename)
  
  -- Convert back to source
  local result = ast_to_string(instrumented_ast)
  
  logger.debug("Source transformation complete", {
    filename = filename,
    original_size = #source,
    instrumented_size = #result
  })
  
  return result
end

return M
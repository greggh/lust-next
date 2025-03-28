-- AST transformer for adding coverage instrumentation
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local central_config = require("lib.core.central_config")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.instrumentation.transformer")

---@class coverage_v3_instrumentation_transformer
---@field transform fun(ast: table): table|nil, table? Transform AST to add coverage tracking
---@field generate fun(ast: table): string|nil Generate code from AST
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Helper to create a tracking call node
local function create_tracking_call(line, type)
  return {
    tag = "Call",
    pos = 0,
    end_pos = 0,
    [1] = {
      tag = "Index",
      pos = 0,
      end_pos = 0,
      [1] = {
        tag = "Id",
        pos = 0,
        end_pos = 0,
        [1] = "_firmo_coverage"
      },
      [2] = {
        tag = "String",
        pos = 0,
        end_pos = 0,
        [1] = "track"
      }
    },
    [2] = {
      tag = "ExpList",
      pos = 0,
      end_pos = 0,
      [1] = {
        tag = "Number",
        pos = 0,
        end_pos = 0,
        [1] = line
      },
      [2] = {
        tag = "String",
        pos = 0,
        end_pos = 0,
        [1] = type
      }
    }
  }
end

-- Helper to insert tracking before a node
local function insert_tracking(node, tracking)
  if node.tag == "Block" then
    table.insert(node, 1, tracking)
  else
    -- Wrap in a block
    local block = {
      tag = "Block",
      pos = node.pos,
      end_pos = node.end_pos,
      tracking,
      node
    }
    for k, v in pairs(node) do
      if type(k) ~= "number" then
        block[k] = v
      end
    end
    return block
  end
  return node
end

-- Transform AST to add coverage tracking
function M.transform(ast)
  -- Create source map
  local source_map = {}
  
  -- Add coverage tracking to executable nodes
  local function transform_node(node)
    if not node or type(node) ~= "table" then
      return node
    end
    
    -- Skip non-executable nodes
    if not node.tag then
      return node
    end
    
    -- Record source map entry
    if node.pos and node.end_pos then
      source_map[#source_map + 1] = {
        start = node.pos,
        finish = node.end_pos,
        line = node.line
      }
    end
    
    -- Add tracking based on node type
    local tracking
    if node.tag == "Function" then
      tracking = create_tracking_call(node.line, "function")
    elseif node.tag == "Call" then
      tracking = create_tracking_call(node.line, "call") 
    elseif node.tag == "Return" then
      tracking = create_tracking_call(node.line, "return")
    elseif node.tag == "If" or node.tag == "While" or node.tag == "Repeat" then
      tracking = create_tracking_call(node.line, "branch")
    end
    
    -- Transform child nodes
    for i, child in ipairs(node) do
      node[i] = transform_node(child)
    end
    
    -- Insert tracking if needed
    if tracking then
      node = insert_tracking(node, tracking)
    end
    
    return node
  end
  
  -- Transform the AST
  local transformed = transform_node(ast)
  if not transformed then
    return nil, "Failed to transform AST"
  end
  
  return transformed, source_map
end

-- Generate code from AST
function M.generate(ast)
  -- TODO: Implement code generation
  -- For now just return dummy code
  return "-- TODO: Generate real code"
end

return M
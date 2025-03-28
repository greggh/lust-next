-- firmo v3 coverage parser module
local grammar = require("lib.tools.parser.grammar")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.parser")

---@class coverage_v3_parser
---@field parse fun(source: string): table|nil, table? Parse Lua source code into an AST
---@field _VERSION string Module version
local M = {
  _VERSION = "3.0.0"
}

-- Extract comments from source code
---@param source string The source code to extract comments from
---@return table comments List of comments with line numbers
local function extract_comments(source)
  local comments = {}
  local line = 1

  -- Helper to count newlines in text
  local function count_newlines(text)
    local count = 0
    for _ in text:gmatch("\n") do
      count = count + 1
    end
    return count
  end

  -- Process source line by line
  local pos = 1
  while pos <= #source do
    -- Find next comment
    local comment_start = source:find("%-%-", pos)
    if not comment_start then
      -- Count remaining newlines
      line = line + count_newlines(source:sub(pos))
      break
    end

    -- Count lines up to comment
    line = line + count_newlines(source:sub(pos, comment_start - 1))

    -- Check if it's a long comment
    local long_comment = source:match("^%-%-%[(=*)%[", comment_start)
    if long_comment then
      -- Find matching end
      local pattern = "%]" .. string.rep("=", #long_comment) .. "%]"
      local comment_end = source:find(pattern, comment_start)
      if comment_end then
        local text = source:sub(comment_start, comment_end + #pattern - 1)
        table.insert(comments, {
          line = line,
          text = text,
          type = "long"
        })
        pos = comment_end + #pattern
        line = line + count_newlines(text)
      else
        -- Unclosed long comment, treat as line comment
        local text = source:sub(comment_start)
        local newline = text:find("\n")
        if newline then
          text = text:sub(1, newline - 1)
        end
        table.insert(comments, {
          line = line,
          text = text,
          type = "line"
        })
        pos = comment_start + #text
      end
    else
      -- Line comment
      local text = source:sub(comment_start)
      local newline = text:find("\n")
      if newline then
        text = text:sub(1, newline - 1)
      end
      table.insert(comments, {
        line = line,
        text = text,
        type = "line"
      })
      pos = comment_start + #text
    end

    -- Move past any newline
    local next_pos = source:find("\n", pos)
    if next_pos then
      pos = next_pos + 1
      line = line + 1
    else
      pos = #source + 1
    end
  end

  return comments
end

-- Calculate line number for a position in source
---@param source string The source code
---@param pos number The position to get line number for
---@return number line The line number
local function get_line_number(source, pos)
  local line = 1
  local current_pos = 1
  while current_pos < pos do
    local newline = source:find("\n", current_pos)
    if not newline or newline >= pos then
      break
    end
    line = line + 1
    current_pos = newline + 1
  end
  return line
end

-- Add line numbers to AST nodes
---@param node table The AST node to add line numbers to
---@param source string The source code
local function add_line_numbers(node, source)
  if not node or type(node) ~= "table" then
    return
  end

  -- Add line number if node has position
  if node.pos then
    node.line = get_line_number(source, node.pos)
  end

  -- Process child nodes
  for _, child in ipairs(node) do
    if type(child) == "table" then
      add_line_numbers(child, source)
    end
  end
end

-- Parse Lua source code into an AST with source mapping
---@param source string The Lua source code to parse
---@return table|nil ast The abstract syntax tree, or nil on error
---@return table? error Error information if parsing failed
function M.parse(source)
  if type(source) ~= "string" then
    return nil, error_handler.validation_error(
      "Source must be a string",
      {provided_type = type(source)}
    )
  end

  logger.debug("Parsing source code", {
    source_length = #source
  })

  -- Extract comments first
  local comments = extract_comments(source)

  -- Parse using our existing grammar
  local ast, err = grammar.parse(source)
  if not ast then
    return nil, error_handler.validation_error(
      "Syntax error in source code",
      {error = err}
    )
  end

  -- Add line numbers to AST nodes
  add_line_numbers(ast, source)

  -- Add comments to AST
  ast.comments = comments

  -- Add source to AST for reference
  ast.source = source

  return ast
end

return M
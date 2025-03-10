--[[
Static analyzer for coverage module.
This module parses Lua code using our parser and generates code maps
that identify executable lines, functions, and code blocks.
]]

local M = {}

local parser = require("lib.tools.parser")
local filesystem = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Cache of parsed files to avoid reparsing
local file_cache = {}

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

-- Clear the file cache
function M.clear_cache()
  file_cache = {}
end

-- Parse a Lua file and return its AST with enhanced protection
function M.parse_file(file_path)
  -- Check cache first for quick return
  if file_cache[file_path] then
    return file_cache[file_path].ast, file_cache[file_path].code_map
  end

  -- Verify file exists
  if not filesystem.file_exists(file_path) then
    return nil, "File not found: " .. file_path
  end

  -- Skip testing-related files to improve performance
  if file_path:match("_test%.lua$") or 
     file_path:match("_spec%.lua$") or
     file_path:match("/tests/") or
     file_path:match("/test/") or
     file_path:match("/specs/") or
     file_path:match("/spec/") then
    return nil, "Test file excluded from static analysis"
  end
  
  -- Skip already known problematic file types
  if file_path:match("%.min%.lua$") or
     file_path:match("/vendor/") or
     file_path:match("/deps/") or
     file_path:match("/node_modules/") then
    return nil, "Excluded dependency from static analysis"
  end
  
  -- Check file size before parsing - INCREASED the limit to 1MB
  -- This ensures we can handle reasonable-sized source files
  local file_size = filesystem.get_file_size(file_path)
  if file_size and file_size > 1024000 then -- 1MB size limit
    logger.debug("Skipping static analysis for large file: " .. file_path .. 
        " (" .. math.floor(file_size/1024) .. "KB)")
    return nil, "File too large for analysis: " .. file_path
  end

  -- Read the file content with protection
  local content, err
  local success, result = pcall(function()
    content, err = filesystem.read_file(file_path)
    if not content then
      return nil, "Failed to read file: " .. tostring(err)
    end
    return content, nil
  end)
  
  if not success then
    return nil, "Exception reading file: " .. tostring(result)
  end
  
  if not content then
    return nil, err or "Unknown error reading file"
  end

  -- Skip if content is too large (use smaller limit for safety)
  if #content > 200000 then -- 200KB content limit - reduced from 500KB
    logger.debug("Skipping static analysis for large content: " .. file_path .. 
        " (" .. math.floor(#content/1024) .. "KB)")
    return nil, "File content too large for analysis"
  end
  
  -- Quick check for deeply nested structures 
  local max_depth = 0
  local current_depth = 0
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
  
  -- Skip files with excessively deep nesting
  if max_depth > 100 then
    logger.debug("Skipping static analysis for deeply nested file: " .. file_path .. 
        " (depth " .. max_depth .. ")")
    return nil, "File has too deeply nested structures"
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

-- Determine if a line is executable based on AST nodes that intersect with it
-- With optimized lookup tables and time limit
local function is_line_executable(nodes, line_num, content)
  -- First check if this is a control flow keyword that should be executable
  if config.control_flow_keywords_executable and content then
    local line = content:match("[^\n]*", line_num) or ""
    local line_text = line:match("^%s*(.-)%s*$") or ""
    
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
        -- This is a control flow keyword and config says they're executable
        return true
      end
    end
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
      logger.debug("Node limit reached in is_line_executable")
      return false
    end
    
    if node_count % 1000 == 0 and os.clock() - start_time > MAX_ANALYSIS_TIME then
      logger.debug("Time limit reached in is_line_executable")
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
    return nil, "Content too large for parse_content: " .. (#content/1024) .. "KB"
  end
  
  -- Start timing
  local start_time = os.clock()
  local MAX_PARSE_TIME = 60.0 -- 60 second total parse time limit (increased from 1 second)
  
  -- Run parsing with protection
  local ast, err
  local success, result = pcall(function()
    ast, err = parser.parse(content, file_path or "inline")
    
    if os.clock() - start_time > MAX_PARSE_TIME then
      return nil, "Parse time limit exceeded"
    end
    
    if not ast then
      return nil, "Parse error: " .. (err or "unknown error")
    end
    
    return ast, nil
  end)
  
  -- Handle errors from pcall
  if not success then
    return nil, "Parser exception: " .. tostring(result)
  end
  
  -- Handle errors from parse
  if not ast then
    return nil, err or "Unknown parse error"
  end
  
  -- Generate code map from the AST with time limit
  local code_map
  success, result = pcall(function()
    -- Check time again before code map generation
    if os.clock() - start_time > MAX_PARSE_TIME then
      return nil, "Code map time limit exceeded"
    end
    
    code_map = M.generate_code_map(ast, content)
    return code_map, nil
  end)
  
  -- Handle errors from code map generation
  if not success then
    return nil, "Code map exception: " .. tostring(result)
  end
  
  if not code_map then
    return nil, result or "Code map generation failed"
  end
  
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
      logger.debug("Node collection limit reached (100,000 nodes)")
      break
    end
  end
  
  return nodes
end

-- Find all function definitions in the AST using non-recursive approach
local function find_functions(ast, functions, context)
  functions = functions or {}
  context = context or {}
  
  local to_process = {ast}
  local processed = 0
  
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
              expr.name = current[1][i][1]
            elseif current[1][i] and current[1][i].tag == "Index" then
              -- Handle module.function or table.key style
              if current[1][i][1].tag == "Id" and current[1][i][2].tag == "String" then
                expr.name = current[1][i][1][1] .. "." .. current[1][i][2][1]
              end
            end
            table.insert(functions, expr)
          end
        end
      elseif current.tag == "Localrec" and #current >= 2 and current[1].tag == "Id" and current[2].tag == "Function" then
        -- Handle local function definition
        current[2].name = current[1][1]  -- Copy the name to the function
        table.insert(functions, current[2])
      elseif current.tag == "Function" then
        -- Standalone function (e.g., anonymous, or already part of a larger structure)
        table.insert(functions, current)
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
      logger.debug("Block finding limit reached (100,000 nodes)")
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
      logger.debug("Condition finding limit reached (100,000 nodes)")
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
    conditions = {},      -- Conditional expressions for condition coverage
    line_count = count_lines(content)
  }
  
  -- Set a reasonable upper limit for line count to prevent DOS
  if code_map.line_count > 10000 then
    logger.debug("File too large for code mapping: " .. code_map.line_count .. " lines")
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
    logger.debug("ERROR in collect_nodes: " .. tostring(result))
    return nil
  end
  
  if not all_nodes then
    logger.debug("ERROR: " .. (result or "Node collection failed"))
    return nil
  end
  
  -- Add size limit for node collection
  if #all_nodes > 50000 then
    logger.debug("AST too complex for analysis: " .. #all_nodes .. " nodes")
    return nil
  end
  
  -- Collect all functions with time check
  local functions
  success, result = pcall(function()
    functions = find_functions(ast)
    
    -- Check for timeout
    if os.clock() - start_time > MAX_CODEMAP_TIME then
      return nil, "Function finding timeout"
    end
    
    return functions, nil
  end)
  
  if not success then
    logger.debug("ERROR in find_functions: " .. tostring(result))
    return nil
  end
  
  if not functions then
    logger.debug("ERROR: " .. (result or "Function finding failed"))
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
    logger.debug("ERROR in find_blocks: " .. tostring(result))
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
    logger.debug("ERROR in find_conditions: " .. tostring(result))
    -- Don't return, we can still continue without conditions
  elseif conditions then
    code_map.conditions = conditions
  end
  
  -- Create function map with time checks
  for i, func in ipairs(functions) do
    -- Periodic time checks
    if i % 100 == 0 and os.clock() - start_time > MAX_CODEMAP_TIME then
      logger.debug("Function map timeout after " .. i .. " functions")
      break
    end
    
    local func_start_line = get_line_for_position(content, func.pos)
    local func_end_line = get_line_for_position(content, func.end_pos)
    
    -- Get function parameters
    local params = {}
    if func[1] and type(func[1]) == "table" then
      for _, param in ipairs(func[1]) do
        if param.tag == "Id" then
          table.insert(params, param[1])
        elseif param.tag == "Dots" then
          table.insert(params, "...")
        end
      end
    end
    
    -- Extract function name (if available)
    local func_name = func.name 
    
    -- If no explicit name, check for function declaration patterns
    if not func_name then
      -- We can use a simpler approach here for performance
      func_name = "anonymous_" .. func_start_line
    end
    
    table.insert(code_map.functions, {
      start_line = func_start_line,
      end_line = func_end_line,
      name = func_name,
      params = params
    })
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
  
  -- Always print detailed information for debugging
  local file_info = ""
  if file_path then
    file_info = " for " .. file_path
  end
  
  logger.verbose(string.format("Code map generation took %.2f seconds%s (%d lines, %d nodes)", 
    total_time, 
    file_info,
    code_map.line_count or 0, 
    #all_nodes or 0))
  
  -- Verify we have executable lines
  if executable_count == 0 then
    logger.debug("No executable lines found in file! This will cause incorrect coverage reporting.")
    
    -- Apply emergency fallback for important coverage module files
    if file_path and (file_path:match("lib/coverage/init.lua") or file_path:match("lib/coverage/debug_hook.lua")) then
      logger.debug("FALLBACK: Applying emergency fallback for critical file: " .. file_path)
      
      -- If content is available, quickly classify lines based on simple patterns
      if content and type(content) == "string" then
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
        
        logger.debug(string.format("FALLBACK: Marked %d lines as executable with fallback mechanism", fallback_executable))
        executable_count = fallback_executable
      end
    end
  end
  
  return code_map
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
    return nil, "AST is nil"
  end
  
  -- If the AST already has an attached code map, use it
  if ast._code_map then
    return ast._code_map
  end
  
  -- Get the file content
  local content
  if file_path then
    content = filesystem.read_file(file_path)
    if not content then
      return nil, "Could not read file: " .. file_path
    end
  else
    return nil, "No file path provided for code map generation"
  end
  
  -- Generate the code map with time limit
  local start_time = os.clock()
  local MAX_TIME = 1.0 -- 1 second limit
  
  -- Use protected call for map generation
  local success, result = pcall(function()
    local code_map = M.generate_code_map(ast, content) 
    
    -- Attach the code map to the AST for future reference
    if code_map then
      ast._code_map = code_map
    end
    
    -- Check for timeout
    if os.clock() - start_time > MAX_TIME then
      return nil, "Timeout generating code map"
    end
    
    return code_map
  end)
  
  if not success then
    return nil, "Error generating code map: " .. tostring(result)
  end
  
  -- Check if timeout occurred inside the pcall
  if type(result) == "string" then
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

return M
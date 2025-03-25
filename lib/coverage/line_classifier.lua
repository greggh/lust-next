---@class CoverageLineClassifier
---@field classify_lines fun(coverage_data: table, file_path: string): boolean Classifies lines in a file
---@field classify_line fun(line_content: string): string Classifies a single line of code
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local data_structure = require("lib.coverage.data_structure")

-- Version
M._VERSION = "0.1.0"

-- Patterns for different line types
local PATTERNS = {
  BLANK = "^%s*$",
  COMMENT_SINGLE = "^%s*%-%-",
  COMMENT_START = "^%s*%-%-%[=*%[",
  COMMENT_END = "%]=*%]%s*$",
  STRUCTURE_END = "^%s*end%s*$",
  STRUCTURE_ELSE = "^%s*else%s*$",
  STRUCTURE_ELSEIF = "^%s*elseif",
  STRUCTURE_UNTIL = "^%s*until%s*",
  -- Additional patterns for non-executable lines
  FUNCTION_DEF = "^%s*function%s+[%w_:%.]+%s*%(.-%)%s*$", -- Function definition line
  LOCAL_FUNCTION_DEF = "^%s*local%s+function%s+[%w_:%.]+%s*%(.-%)%s*$", -- Local function definition
  TABLE_DEF = "^%s*local%s+[%w_]+%s*=%s*{%s*$", -- Table definition start
  RETURN_TABLE = "^%s*return%s+{%s*$", -- Return table start
  RETURN_VALUE = "^%s*return%s+[%w_\"'%[%]%.]+%s*$", -- Simple return statement
  MULTILINE_STRING_START = "%[=*%[", -- Start of multiline string
  MULTILINE_STRING_END = "%]=*%]", -- End of multiline string
  DO_BLOCK = "^%s*do%s*$", -- Do block
  WHILE_LOOP = "^%s*while.+do%s*$", -- While loop
  FOR_LOOP = "^%s*for.+do%s*$", -- For loop
  REPEAT_LOOP = "^%s*repeat%s*$", -- Repeat loop
  IF_STATEMENT = "^%s*if.+then%s*$" -- If statement
}

-- State for multiline comment tracking
local in_multiline_comment = false

--- Classifies a single line of Lua code
---@param line_content string The line content to classify
---@return string classification The line classification (code, comment, blank, structure)
function M.classify_line(line_content)
  -- Handle multiline comment tracking
  if in_multiline_comment then
    -- Check for end of multiline comment
    if line_content:match(PATTERNS.COMMENT_END) then
      in_multiline_comment = false
    end
    return data_structure.LINE_TYPES.COMMENT
  end
  
  -- Check for blank line
  if line_content:match(PATTERNS.BLANK) then
    return data_structure.LINE_TYPES.BLANK
  end
  
  -- Check for single-line comment
  if line_content:match(PATTERNS.COMMENT_SINGLE) then
    -- Check for start of multiline comment
    if line_content:match(PATTERNS.COMMENT_START) and not line_content:match(PATTERNS.COMMENT_END) then
      in_multiline_comment = true
    end
    return data_structure.LINE_TYPES.COMMENT
  end
  
  -- Check for start of multiline comment (not preceded by single comment markers)
  if line_content:match(PATTERNS.COMMENT_START) and not line_content:match(PATTERNS.COMMENT_END) then
    in_multiline_comment = true
    return data_structure.LINE_TYPES.COMMENT
  end
  
  -- Check for structural elements
  if line_content:match(PATTERNS.STRUCTURE_END) or
     line_content:match(PATTERNS.STRUCTURE_ELSE) or
     line_content:match(PATTERNS.STRUCTURE_ELSEIF) or
     line_content:match(PATTERNS.STRUCTURE_UNTIL) then
    return data_structure.LINE_TYPES.STRUCTURE
  end
  
  -- For all other lines, treat them as executable code
  return data_structure.LINE_TYPES.CODE
end

--- Classifies all lines in a file
---@param coverage_data table The coverage data structure
---@param file_path string The path to the file to classify
---@return boolean success Whether classification succeeded
function M.classify_lines(coverage_data, file_path)
  -- Parameter validation
  error_handler.assert(type(coverage_data) == "table", "coverage_data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Normalize the path
  local normalized_path = data_structure.normalize_path(file_path)
  
  -- Get the file data
  local file_data = data_structure.get_file_data(coverage_data, normalized_path)
  if not file_data then
    logger.warn("Cannot classify lines for a file not in the coverage data", {
      file_path = normalized_path
    })
    return false
  end
  
  -- Reset multiline comment state for this file
  in_multiline_comment = false
  
  -- Create a debug log for classification
  local debug_file = io.open("line_classifier_debug.log", "a")
  if debug_file then
    debug_file:write("\n\nClassifying lines for file: " .. normalized_path .. "\n")
    debug_file:write("===============================================\n")
    debug_file:close()
  end
  
  -- Get line numbers and sort them to process in order
  local line_numbers = {}
  for line_num, _ in pairs(file_data.lines) do
    table.insert(line_numbers, line_num)
  end
  table.sort(line_numbers)
  
  -- Process each line in order
  for _, line_num in ipairs(line_numbers) do
    local line_data = file_data.lines[line_num]
    local line_content = line_data.content
    
    -- Use the simpler classify_line function to determine line type
    local classification = M.classify_line(line_content)
    
    -- General rule: Any line that is not a comment or blank is executable code
    if classification ~= data_structure.LINE_TYPES.COMMENT and 
       classification ~= data_structure.LINE_TYPES.BLANK then
      classification = data_structure.LINE_TYPES.CODE
    end
    
    -- Log to debug file
    local debug_file = io.open("line_classifier_debug.log", "a")
    if debug_file then
      debug_file:write(string.format("Line %d: [%s] %s\n", 
        line_num, 
        classification, 
        line_content:sub(1, 60) .. (line_content:len() > 60 and "..." or "")
      ))
      debug_file:close()
    end
    
    -- Update the line classification
    data_structure.set_line_classification(coverage_data, normalized_path, line_num, classification)
  end
  
  return true
end

return M
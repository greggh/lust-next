local M = {}
local fs = require("lib.tools.filesystem")
local static_analyzer = require("lib.coverage.static_analyzer")

-- Is this line a comment or blank?
local function is_comment_or_blank(line)
  -- Remove trailing single-line comment
  local code = line:gsub("%-%-.*$", "")
  -- Remove whitespace
  code = code:gsub("%s+", "")
  -- Check if anything remains
  return code == ""
end

-- Track multi-line comment state
local in_multiline_comment = false

-- Check if line is inside a multi-line comment
local function is_in_multiline_comment(line, file_path, line_num, file_data)
  -- If we don't have previous lines to check, do pattern-based detection
  if not file_data or not file_data.source then
    -- Look for comment start/end markers
    local starts = line:find("%-%-%[%[")
    local ends = line:find("%]%]%-?%-?")
    
    -- Check for comment start
    if starts and not ends then
      in_multiline_comment = true
      return true
    -- Check for comment end
    elseif not starts and ends and in_multiline_comment then
      in_multiline_comment = false
      return true
    -- Continue existing comment state
    elseif in_multiline_comment then
      return true
    end
    
    return false
  end
  
  -- More accurate approach - scan from the beginning of the file
  -- to determine multi-line comment state
  local in_comment = false
  
  -- Find both standard [[ ]] and --[[ ]] multiline comments
  for i = 1, line_num do
    local current_line = file_data.source[i] or ""
    
    -- Look for comment markers
    local comment_starts = {}
    local comment_ends = {}
    
    -- Find all comment start markers (both --[[ and [[ patterns)
    local pos = 1
    while true do
      local ml_start = current_line:find("%-%-%[%[", pos)
      if not ml_start then break end
      table.insert(comment_starts, ml_start)
      pos = ml_start + 4
    end
    
    -- Find all comment end markers
    pos = 1
    while true do
      local end_pos = current_line:find("%]%]", pos)
      if not end_pos then break end
      table.insert(comment_ends, end_pos)
      pos = end_pos + 2
    end
    
    -- Process markers in the order they appear in the line
    -- First collect all markers with their positions
    local all_markers = {}
    for _, start_pos in ipairs(comment_starts) do
      table.insert(all_markers, {pos = start_pos, type = "start"})
    end
    for _, end_pos in ipairs(comment_ends) do
      table.insert(all_markers, {pos = end_pos, type = "end"})
    end
    
    -- Sort markers by position
    table.sort(all_markers, function(a, b) return a.pos < b.pos end)
    
    -- Process markers in order
    for _, marker in ipairs(all_markers) do
      if marker.type == "start" and not in_comment then
        in_comment = true
      elseif marker.type == "end" and in_comment then
        in_comment = false
      end
    end
    
    -- If this is our target line, return the current comment state
    if i == line_num then
      return in_comment
    end
  end
  
  return false
end

-- Is this a non-executable line that should be patched?
local function is_patchable_line(line_text)
  -- Standalone structural keywords
  if line_text:match("^%s*end%s*$") or
     line_text:match("^%s*else%s*$") or
     line_text:match("^%s*until%s*$") or
     line_text:match("^%s*elseif%s+.+then%s*$") or
     line_text:match("^%s*then%s*$") or
     line_text:match("^%s*do%s*$") or
     line_text:match("^%s*repeat%s*$") then
    return true
  end
  
  -- Function declarations
  if line_text:match("^%s*local%s+function%s+") or 
     line_text:match("^%s*function%s+[%w_:%.]+%s*%(") then
    return true
  end
  
  -- Closing brackets, braces, parentheses on their own lines
  if line_text:match("^%s*[%]})%)]%s*$") then
    return true
  end
  
  -- Variable declarations without assignments
  if line_text:match("^%s*local%s+[%w_,]+%s*$") then
    return true
  end
  
  -- Empty tables or empty blocks
  if line_text:match("^%s*[%w_]+%s*=%s*{%s*}%s*,?%s*$") or
     line_text:match("^%s*{%s*}%s*,?%s*$") then
    return true
  end
  
  -- Module returns without expressions
  if line_text:match("^%s*return%s+[%w_%.]+%s*$") then
    return true
  end
  
  -- Not a patchable line
  return false
end

-- Patch coverage data for a file
function M.patch_file(file_path, file_data)
  -- Check if we have static analysis information
  if file_data.code_map then
    -- Use static analysis information to patch coverage data
    local patched = 0
    
    for i = 1, file_data.line_count do
      local line_info = file_data.code_map.lines[i]
      
      if line_info and not line_info.executable then
        -- This is a non-executable line (comment, blank line, etc.)
        
        -- Mark as non-executable in executable_lines table
        file_data.executable_lines[i] = false
        
        -- CRITICAL FIX: Remove coverage from non-executable lines
        -- This is the most important step - non-executable lines should NEVER be covered
        file_data.lines[i] = nil  -- Explicitly remove coverage marking from non-executable lines
        patched = patched + 1
      elseif line_info and line_info.executable then
        -- This is an executable line - keep its actual execution status
        file_data.executable_lines[i] = true
        
        -- CRITICAL FIX: Keep executable line status without additional checks
        -- Just maintain the actual execution status - don't add extra validation
        -- that might cause errors with the _executed_lines field that may not exist
        -- Allow the actual coverage tracking to determine if lines were covered
      end
    end
    
    return patched
  end
  
  -- No static analysis info available, fall back to heuristic approach
  -- Make sure we have source code
  local lines
  if type(file_data.source) == "table" then
    -- Source is already an array of lines
    lines = file_data.source
  elseif type(file_data.source) == "string" then
    -- Source is a string, parse into lines
    lines = {}
    for line in file_data.source:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  else
    -- No source available, try to read from file
    local source_text = fs.read_file(file_path)
    if not source_text then
      return false
    end
    
    lines = {}
    for line in source_text:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    -- Store the parsed lines in the file_data
    file_data.source = lines
  end
  
  -- Update line_count if needed
  if not file_data.line_count or file_data.line_count == 0 then
    file_data.line_count = #lines
  end
  
  -- Initialize executable_lines table if not present
  file_data.executable_lines = file_data.executable_lines or {}
  
  -- Reset multi-line comment tracking state for this file
  in_multiline_comment = false
  
  -- Process each line
  local patched = 0
  for i, line_text in ipairs(lines) do
    -- First check if line is in a multi-line comment block
    if is_in_multiline_comment(line_text, file_path, i, file_data) then
      -- Multi-line comment lines are non-executable
      file_data.executable_lines[i] = false
      file_data.lines[i] = nil  -- Remove any coverage marking
      patched = patched + 1
    -- Then check if it's a single-line comment or blank
    elseif is_comment_or_blank(line_text) then
      -- Comments and blank lines are non-executable
      file_data.executable_lines[i] = false
      
      -- IMPORTANT: Never mark non-executable lines as covered if they weren't executed
      -- (this was causing the bug where comments appeared green in HTML reports)
      file_data.lines[i] = nil  -- Explicitly remove any coverage marking
      patched = patched + 1
    elseif is_patchable_line(line_text) then
      -- Non-executable code structure lines
      file_data.executable_lines[i] = false
      
      -- IMPORTANT: Never mark non-executable lines as covered if they weren't executed
      -- This is the same fix as above, for structured code elements (end, else, etc.)
      file_data.lines[i] = nil  -- Explicitly remove any coverage marking
      patched = patched + 1
    else
      -- Potentially executable line
      file_data.executable_lines[i] = true
      
      -- IMPORTANT: Do NOT mark executable lines as covered if they weren't actually hit!
      -- Only leave lines as covered if they were already marked as such by the debug hook
      -- We don't touch potentially executable lines that weren't covered
    end
  end
  
  return patched
end

-- Patch all files in coverage data
function M.patch_all(coverage_data)
  local total_patched = 0
  
  for file_path, file_data in pairs(coverage_data.files) do
    local patched = M.patch_file(file_path, file_data)
    total_patched = total_patched + patched
  end
  
  return total_patched
end

return M
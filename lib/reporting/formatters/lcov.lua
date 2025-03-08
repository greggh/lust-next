-- LCOV formatter for coverage reports
local M = {}

-- Generate an LCOV format coverage report (used by many CI tools)
function M.format_coverage(coverage_data)
  -- Validate the input data to prevent runtime errors
  if not coverage_data or not coverage_data.files then
    return ""
  end
  
  local lcov_lines = {}
  
  -- Process each file
  for filename, file_data in pairs(coverage_data.files) do
    -- Add file record
    table.insert(lcov_lines, "SF:" .. filename)
    
    -- Add function records (if available)
    if file_data.functions then
      local fn_idx = 1
      for fn_name, is_covered in pairs(file_data.functions) do
        -- FN:<line>,<function name>
        table.insert(lcov_lines, "FN:1," .. fn_name) -- Line number not always available
        
        -- FNDA:<execution count>,<function name>
        if is_covered then
          table.insert(lcov_lines, "FNDA:1," .. fn_name)
        else
          table.insert(lcov_lines, "FNDA:0," .. fn_name)
        end
        
        fn_idx = fn_idx + 1
      end
      
      -- FNF:<number of functions found>
      local fn_count = 0
      for _ in pairs(file_data.functions) do fn_count = fn_count + 1 end
      table.insert(lcov_lines, "FNF:" .. fn_count)
      
      -- FNH:<number of functions hit>
      local fn_hit = 0
      for _, is_covered in pairs(file_data.functions) do
        if is_covered then fn_hit = fn_hit + 1 end
      end
      table.insert(lcov_lines, "FNH:" .. fn_hit)
    end
    
    -- Add line records
    if file_data.lines then
      for line_num, is_covered in pairs(file_data.lines) do
        if type(line_num) == "number" then
          -- DA:<line number>,<execution count>[,<checksum>]
          table.insert(lcov_lines, "DA:" .. line_num .. "," .. (is_covered and "1" or "0"))
        end
      end
      
      -- LF:<number of lines found>
      local line_count = 0
      for k, _ in pairs(file_data.lines) do
        if type(k) == "number" then line_count = line_count + 1 end
      end
      table.insert(lcov_lines, "LF:" .. line_count)
      
      -- LH:<number of lines hit>
      local line_hit = 0
      for k, is_covered in pairs(file_data.lines) do
        if type(k) == "number" and is_covered then line_hit = line_hit + 1 end
      end
      table.insert(lcov_lines, "LH:" .. line_hit)
    end
    
    -- End of record
    table.insert(lcov_lines, "end_of_record")
  end
  
  return table.concat(lcov_lines, "\n")
end

-- Register formatter
return function(formatters)
  formatters.coverage.lcov = M.format_coverage
end
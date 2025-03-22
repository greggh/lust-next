--[[
  Enhanced Line Classification Example

  This example demonstrates the enhanced line classification functionality
  in the Firmo coverage module. It shows how to enable the enhanced features
  and visualize line classification for better debugging of coverage issues.
]]

local firmo = require("firmo")
local fs = require("lib.tools.filesystem")
local static_analyzer = require("lib.coverage.static_analyzer")
local debug_hook = require("lib.coverage.debug_hook")

-- Create a temporary file with various code constructs
local function create_test_file()
  local tmp_dir = os.getenv("TMPDIR") or "/tmp"
  local file_path = fs.join_paths(tmp_dir, "line_classification_example_" .. os.time() .. ".lua")
  
  local content = [==[
-- Single line comment
local simple_var = "simple string"

--[[ 
  Multiline comment
  that spans
  multiple lines
]]

local multiline_string = [[
  This is a multiline string
  that also spans multiple lines
  and should be handled properly
]]

-- Function with branches for testing
local function test_branches(x)
  local result
  
  if x > 10 then
    result = "large"
  elseif x == 0 then
    result = "zero" 
  else
    result = "small"
  end
  
  return result
end

-- Mixed constructs
local mixed_constructs = function()
  -- Single line comment inside function
  local comment = "comment string"
  
  local str = [[
    String with -- comment inside
  ]]
  
  return comment, str
end

-- Mixed code and comments on same line
local mixed = "string" -- Comment after code

return {
  test_branches = test_branches,
  mixed_constructs = mixed_constructs,
  mixed = mixed
}
]==]

  -- Write the test file
  local success, err = fs.write_file(file_path, content)
  if not success then
    print("Error creating test file: " .. tostring(err))
    return nil
  end
  
  return file_path
end

-- Visualize line classification
local function visualize_classification(file_path)
  -- First initialize file in debug hook
  debug_hook.initialize_file(file_path)
  
  -- Execute example code to track lines
  local module_to_test, err = loadfile(file_path)
  if not module_to_test then
    print("Error loading module: " .. tostring(err))
    return
  end
  
  -- Run the module to execute its code
  local success, result = pcall(module_to_test)
  if not success then
    print("Error running module: " .. tostring(result))
    return
  end
  
  -- Call some functions to ensure they're executed
  if result and result.test_branches then
    result.test_branches(15) -- large branch
    result.test_branches(0)  -- zero branch
    result.test_branches(5)  -- small branch
  end
  
  if result and result.mixed_constructs then
    result.mixed_constructs()
  end
  
  -- Get visualization data
  local visualization = debug_hook.visualize_line_classification(file_path)
  if not visualization then
    print("Error generating visualization")
    return
  end
  
  -- Display the visualization
  print("\n=== Line Classification Visualization ===\n")
  print(string.format("%-5s %-15s %-10s %-10s %-20s %s", 
    "Line", "Status", "Executed", "Covered", "Classification", "Source"))
  print(string.rep("-", 100))
  
  for _, line_data in ipairs(visualization) do
    -- Format coverage status with colors
    local status = line_data.coverage_status or "unknown"
    local status_formatted = status
    
    -- Use simple ANSI colors for terminal output
    if status == "covered" then
      status_formatted = "\27[32m" .. status .. "\27[0m" -- Green
    elseif status == "executed_not_covered" then
      status_formatted = "\27[33m" .. status .. "\27[0m" -- Yellow
    elseif status == "not_executed" then
      status_formatted = "\27[31m" .. status .. "\27[0m" -- Red
    elseif status == "non_executable" then
      status_formatted = "\27[90m" .. status .. "\27[0m" -- Gray
    end
    
    -- Print line information
    print(string.format("%-5d %-15s %-10s %-10s %-20s %s",
      line_data.line_num,
      status_formatted,
      line_data.executed and "Yes" or "No",
      line_data.covered and "Yes" or "No",
      line_data.classification or "unknown",
      line_data.source or ""
    ))
  end
end

-- Demonstrate enhanced classification with context
local function show_enhanced_classification(file_path)
  print("\n=== Enhanced Line Classification with Context ===\n")
  
  -- Create a table of interesting line numbers to examine
  local lines_to_check = {
    { num = 1, desc = "Single line comment" },
    { num = 2, desc = "Variable assignment" },
    { num = 5, desc = "Inside multiline comment" },
    { num = 10, desc = "Multiline string declaration" },
    { num = 11, desc = "Inside multiline string" },
    { num = 19, desc = "If statement" },
    { num = 21, desc = "Elseif statement" },
    { num = 23, desc = "Else statement" },
    { num = 26, desc = "Function return statement" },
    { num = 34, desc = "String with comment inside" },
    { num = 40, desc = "Mixed code and comment" }
  }
  
  -- Check classification for each line
  local file_content, err = fs.read_file(file_path)
  if not file_content then
    print("Error reading file: " .. tostring(err))
    return
  end
  
  -- Split file content into lines
  local lines = {}
  for line in (file_content .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
    table.insert(lines, line)
  end
  
  -- Build multiline context for accurate classification
  local multiline_context = static_analyzer.create_multiline_comment_context()
  for i, line in ipairs(lines) do
    static_analyzer.process_line_for_comments(line, i, multiline_context)
  end
  
  -- Check each interesting line
  print(string.format("%-5s %-25s %-15s %-25s %s", 
    "Line", "Description", "Type", "Content Type", "Reasons"))
  print(string.rep("-", 100))
  
  for _, line_info in ipairs(lines_to_check) do
    local line_num = line_info.num
    local description = line_info.desc
    
    -- Get line classification with context
    local source_line = lines[line_num]
    local line_type, context = static_analyzer.classify_line_simple_with_context(
      file_path,
      line_num,
      source_line,
      {
        track_multiline_context = true,
        multiline_state = multiline_context
      }
    )
    
    -- Format type as a string
    local type_str = "unknown"
    if line_type == static_analyzer.LINE_TYPES.EXECUTABLE then
      type_str = "EXECUTABLE"
    elseif line_type == static_analyzer.LINE_TYPES.NON_EXECUTABLE then
      type_str = "NON_EXECUTABLE"
    elseif line_type == static_analyzer.LINE_TYPES.FUNCTION then
      type_str = "FUNCTION"
    elseif line_type == static_analyzer.LINE_TYPES.BRANCH then
      type_str = "BRANCH"
    end
    
    -- Format reasons as a string
    local reasons = ""
    if context and context.reasons then
      reasons = table.concat(context.reasons, ", ")
    end
    
    -- Print classification info
    print(string.format("%-5d %-25s %-15s %-25s %s",
      line_num,
      description,
      type_str,
      context and context.content_type or "unknown",
      reasons
    ))
  end
end

-- Demonstrate running tests with enhanced line classification
local function run_tests_with_enhanced_classification()
  print("\n=== Running Tests with Enhanced Line Classification ===\n")
  
  -- Create a sample test file
  local test_file_path = create_test_file()
  if not test_file_path then
    print("Failed to create test file")
    return
  end
  
  print("Created test file: " .. test_file_path)
  
  -- Let's use the coverage module directly instead
  local coverage = require("lib.coverage")
  
  -- Start coverage with enhanced options
  coverage.start({
    use_enhanced_classification = true,
    track_multiline_context = true
  })
  
  -- Create a simple test using the test file
  local module_to_test = loadfile(test_file_path)
  if not module_to_test then
    print("Error loading module")
    return
  end
  
  -- Run the test file directly
  local success, result = pcall(module_to_test)
  if not success then
    print("Error running test file: " .. tostring(result))
    return
  end
  
  -- Test each function to ensure code execution is tracked
  if result.test_branches then
    print("Running test_branches...")
    result.test_branches(15) -- large branch
    result.test_branches(0)  -- zero branch
    result.test_branches(5)  -- small branch
  end
  
  if result.mixed_constructs then
    print("Running mixed_constructs...")
    local comment, str = result.mixed_constructs()
    print("- Comment: " .. comment)
    print("- String: " .. str:sub(1, 20) .. "...")
  end
  
  -- Stop coverage
  coverage.stop()
  
  -- Show visualization
  visualize_classification(test_file_path)
  
  -- Show enhanced classification
  show_enhanced_classification(test_file_path)
  
  -- Clean up test file
  os.remove(test_file_path)
  print("\nTest file removed: " .. test_file_path)
end

-- Run the example
run_tests_with_enhanced_classification()
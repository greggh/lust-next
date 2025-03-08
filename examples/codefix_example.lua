-- Example demonstrating the enhanced codefix module in lust-next
local lust = require("lust-next")

print("This example demonstrates the enhanced codefix module in lust-next")
print("The codefix module can be used to fix common Lua code quality issues across multiple files")

-- Create a directory with example files
local function create_example_files()
  -- Create directory
  local dirname = "codefix_examples"
  os.execute("mkdir -p " .. dirname)
  print("Created example directory: " .. dirname)
  
  -- Create multiple files with different quality issues
  local files = {}
  
  -- File 1: Unused variables and arguments
  local filename1 = dirname .. "/unused_vars.lua"
  local content1 = [[
-- Example file with unused variables and arguments

local function test_function(param1, param2, param3)
  local unused_local = "test"
  local another_unused = 42
  return param1 + 10
end

local function another_test(a, b, c, d)
  local result = a * b
  return result
end

return {
  test_function = test_function,
  another_test = another_test
}
]]
  
  local file1 = io.open(filename1, "w")
  if file1 then
    file1:write(content1)
    file1:close()
    table.insert(files, filename1)
    print("Created: " .. filename1)
  end
  
  -- File 2: Trailing whitespace in multiline strings
  local filename2 = dirname .. "/whitespace.lua"
  local content2 = [=[
-- Example file with trailing whitespace issues

local function get_multiline_text()
  local text = [[
    This string has trailing whitespace   
    on multiple lines   
    that should be fixed   
  ]]
  return text
end

local function get_another_text()
  return [[
    Another string with    
    trailing whitespace    
  ]]
end

return {
  get_multiline_text = get_multiline_text,
  get_another_text = get_another_text
}
]=]
  
  local file2 = io.open(filename2, "w")
  if file2 then
    file2:write(content2)
    file2:close()
    table.insert(files, filename2)
    print("Created: " .. filename2)
  end
  
  -- File 3: String concatenation issues
  local filename3 = dirname .. "/string_concat.lua"
  local content3 = [[
-- Example file with string concatenation issues

local function build_message(name, age)
  local greeting = "Hello " .. "there " .. name .. "!"
  local age_text = "You are " .. age .. " " .. "years " .. "old."
  return greeting .. " " .. age_text
end

local function build_html()
  return "<div>" .. "<h1>" .. "Title" .. "</h1>" .. "<p>" .. "Content" .. "</p>" .. "</div>"
end

return {
  build_message = build_message,
  build_html = build_html
}
]]
  
  local file3 = io.open(filename3, "w")
  if file3 then
    file3:write(content3)
    file3:close()
    table.insert(files, filename3)
    print("Created: " .. filename3)
  end
  
  return dirname, files
end

-- Run codefix on multiple files
local function run_multi_file_codefix(dirname, files)
  print("\nRunning enhanced codefix on multiple files")
  print(string.rep("-", 60))
  
  -- Check if codefix module is available
  if not lust.codefix then
    print("Error: Enhanced codefix module not found")
    return
  end
  
  -- Enable codefix
  lust.codefix.config.enabled = true
  lust.codefix.config.verbose = true
  
  -- 1. First, demonstrate the find functionality
  print("\n1. Finding Lua files in the directory:")
  local cli_result = lust.codefix.run_cli({"find", dirname, "--include", "%.lua$"})
  
  -- 2. Demonstrate running codefix on multiple files
  print("\n2. Running codefix on all files:")
  print(string.rep("-", 60))
  
  local success, results = lust.codefix.fix_files(files)
  
  if success then
    print("✅ All files fixed successfully")
  else
    print("⚠️ Some files had issues")
  end
  
  -- 3. Demonstrate directory-based fixing with options
  print("\n3. Running codefix on directory with options:")
  print(string.rep("-", 60))
  
  local options = {
    sort_by_mtime = true,
    generate_report = true,
    report_file = "codefix_report.json"
  }
  
  success, results = lust.codefix.fix_lua_files(dirname, options)
  
  -- 4. Show results of fixes
  print("\n4. Results of fixed files:")
  print(string.rep("-", 60))
  
  for _, filename in ipairs(files) do
    print("\nFile: " .. filename)
    print(string.rep("-", 40))
    local file = io.open(filename, "r")
    if file then
      print(file:read("*a"))
      file:close()
    end
  end
  
  -- 5. If a report was generated, show it
  if options.generate_report and options.report_file then
    print("\n5. Generated report:")
    print(string.rep("-", 60))
    local report_file = io.open(options.report_file, "r")
    if report_file then
      print(report_file:read("*a"))
      report_file:close()
    else
      print("Report file not found")
    end
  end
end

-- Clean up after the example
local function cleanup(dirname, files)
  print("\nCleaning up...")
  
  -- Remove the example files
  for _, filename in ipairs(files) do
    os.remove(filename)
    os.remove(filename .. ".bak")
  end
  
  -- Remove the directory
  os.execute("rm -rf " .. dirname)
  
  -- Remove report file
  os.remove("codefix_report.json")
  
  print("Removed example files and directory")
end

-- Run the example
local dirname, files = create_example_files()
if dirname and #files > 0 then
  run_multi_file_codefix(dirname, files)
  cleanup(dirname, files)
end

print("\nExample complete")
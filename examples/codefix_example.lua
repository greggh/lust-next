-- Example demonstrating the enhanced codefix module in firmo
local firmo = require("firmo")

print("This example demonstrates the enhanced codefix module in firmo")
print("The codefix module can be used to fix common Lua code quality issues across multiple files")

-- Load the filesystem module
local fs = require("lib.tools.filesystem")

-- Create a directory with example files
local function create_example_files()
  -- Create directory
  local dirname = "codefix_examples"
  fs.ensure_directory_exists(dirname)
  print("Created example directory: " .. dirname)
  
  -- Create multiple files with different quality issues
  local files = {}
  
  -- File 1: Unused variables and arguments
  local filename1 = fs.join_paths(dirname, "unused_vars.lua")
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
  
  local success, err = fs.write_file(filename1, content1)
  if success then
    table.insert(files, filename1)
    print("Created: " .. filename1)
  else
    print("Error creating file: " .. (err or "unknown error"))
  end
  
  -- File 2: Trailing whitespace in multiline strings
  local filename2 = fs.join_paths(dirname, "whitespace.lua")
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
  
  local success, err = fs.write_file(filename2, content2)
  if success then
    table.insert(files, filename2)
    print("Created: " .. filename2)
  else
    print("Error creating file: " .. (err or "unknown error"))
  end
  
  -- File 3: String concatenation issues
  local filename3 = fs.join_paths(dirname, "string_concat.lua")
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
  
  local success, err = fs.write_file(filename3, content3)
  if success then
    table.insert(files, filename3)
    print("Created: " .. filename3)
  else
    print("Error creating file: " .. (err or "unknown error"))
  end
  
  return dirname, files
end

-- Run codefix on multiple files
local function run_multi_file_codefix(dirname, files)
  print("\nRunning enhanced codefix on multiple files")
  print(string.rep("-", 60))
  
  -- Check if codefix module is available
  if not firmo.codefix then
    print("Error: Enhanced codefix module not found")
    return
  end
  
  -- Enable codefix
  firmo.codefix.config.enabled = true
  firmo.codefix.config.verbose = true
  
  -- 1. First, demonstrate the find functionality
  print("\n1. Finding Lua files in the directory:")
  local cli_result = firmo.codefix.run_cli({"find", dirname, "--include", "%.lua$"})
  
  -- 2. Demonstrate running codefix on multiple files
  print("\n2. Running codefix on all files:")
  print(string.rep("-", 60))
  
  local success, results = firmo.codefix.fix_files(files)
  
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
  
  success, results = firmo.codefix.fix_lua_files(dirname, options)
  
  -- 4. Show results of fixes
  print("\n4. Results of fixed files:")
  print(string.rep("-", 60))
  
  for _, filename in ipairs(files) do
    print("\nFile: " .. filename)
    print(string.rep("-", 40))
    local content, err = fs.read_file(filename)
    if content then
      print(content)
    else
      print("Error reading file: " .. (err or "unknown error"))
    end
  end
  
  -- 5. If a report was generated, show it
  if options.generate_report and options.report_file then
    print("\n5. Generated report:")
    print(string.rep("-", 60))
    local report_content, err = fs.read_file(options.report_file)
    if report_content then
      print(report_content)
    else
      print("Error reading report file: " .. (err or "unknown error"))
    end
  end
end

-- Clean up after the example
local function cleanup(dirname, files)
  print("\nCleaning up...")
  
  -- Remove the example files
  for _, filename in ipairs(files) do
    fs.delete_file(filename)
    fs.delete_file(filename .. ".bak")
  end
  
  -- Remove the directory
  fs.delete_directory(dirname, true)  -- true for recursive deletion
  
  -- Remove report file
  fs.delete_file("codefix_report.json")
  
  print("Removed example files and directory")
end

-- Run the example
local dirname, files = create_example_files()
if dirname and #files > 0 then
  run_multi_file_codefix(dirname, files)
  cleanup(dirname, files)
end

print("\nExample complete")

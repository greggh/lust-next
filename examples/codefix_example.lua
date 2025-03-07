-- Example demonstrating the codefix module in lust-next
local lust = require("lust-next")

print("This example demonstrates the codefix module in lust-next")
print("The codefix module can be used to fix common Lua code quality issues")

-- Create a file with common Lua code quality issues to fix
local function create_example_file()
  local filename = "codefix_example_file.lua"
  local content = [[
-- Example file with common Lua code quality issues

local function unused_args_example(a, b, c)
  -- Unused arguments
  return a + 5
end

local function trailing_whitespace_example()  
  local multiline_string = [[
    This string has trailing whitespace   
    on multiple lines   
  ]]
  return multiline_string
end

local function string_concat_example()
  local name = "John"
  local greeting = "Hello " .. "there " .. name .. "!"
  return greeting
end

-- Calculate something
local function calculate(x, y)
  -- Missing type annotations
  return x * y
end

return {
  unused_args_example = unused_args_example,
  trailing_whitespace_example = trailing_whitespace_example,
  string_concat_example = string_concat_example,
  calculate = calculate
}
]]

  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
    print("Created example file: " .. filename)
    return filename
  else
    print("Failed to create example file")
    return nil
  end
end

-- Run codefix on the example file
local function run_codefix(filename)
  if not filename then return end
  
  print("\nRunning codefix on " .. filename)
  print(string.rep("-", 60))
  
  -- Check if codefix module is available
  if not lust.codefix_options then
    print("Error: Codefix module not found")
    return
  end
  
  -- Enable codefix
  lust.codefix_options.enabled = true
  lust.codefix_options.verbose = true
  lust.codefix_options.debug = true
  
  -- Run codefix on the file
  if lust.fix_file then
    local success = lust.fix_file(filename)
    if success then
      print("✅ Codefix succeeded")
    else
      print("❌ Codefix failed")
    end
  else
    print("Error: lust.fix_file function not found")
  end
  
  -- Show the fixed file
  print("\nFixed file content:")
  print(string.rep("-", 60))
  local file = io.open(filename, "r")
  if file then
    print(file:read("*a"))
    file:close()
  end
end

-- Clean up after the example
local function cleanup(filename)
  if not filename then return end
  
  print("\nCleaning up...")
  local backup_file = filename .. ".bak"
  
  -- Remove the example files
  os.remove(filename)
  os.remove(backup_file)
  
  print("Removed example files")
end

-- Run the example
local filename = create_example_file()
if filename then
  run_codefix(filename)
  cleanup(filename)
end

print("\nExample complete")
-- Hash module example
local hash = require("lib.tools.hash")
local test_helper = require("lib.tools.test_helper")

-- Create a test directory
local test_dir = test_helper.create_temp_test_directory()

-- Example 1: Basic string hashing
print("\nExample 1: Basic String Hashing")
print("-------------------------------")

local str = "Hello, world!"
local str_hash = hash.hash_string(str)
print("String:", str)
print("Hash:", str_hash)

-- Example 2: File hashing
print("\nExample 2: File Hashing")
print("----------------------")

-- Create a test file
local file_content = [[
This is a test file
with multiple lines
of content.
]]
test_dir.create_file("test.txt", file_content)

-- Hash the file
local file_hash = hash.hash_file(test_dir.path .. "/test.txt")
print("File content:", file_content:gsub("\n", "\\n"))
print("File hash:", file_hash)

-- Example 3: Change detection
print("\nExample 3: Change Detection")
print("-------------------------")

-- Create a file
local original_content = "Original content"
local file_path = test_dir.path .. "/watched.txt"
test_dir.create_file("watched.txt", original_content)

-- Get original hash
local original_hash = hash.hash_file(file_path)
print("Original content:", original_content)
print("Original hash:", original_hash)

-- Modify the file
local new_content = "Modified content"
test_dir.write_file("watched.txt", new_content)

-- Get new hash
local new_hash = hash.hash_file(file_path)
print("Modified content:", new_content)
print("Modified hash:", new_hash)
print("File changed:", original_hash ~= new_hash)

-- Example 4: Simple caching system
print("\nExample 4: Simple Caching System")
print("------------------------------")

-- Create a simple cache
local cache = {}

local function compute_expensive_result(input)
  -- Simulate expensive computation
  local result = 0
  for i = 1, 1000000 do
    result = result + i
  end
  return result + #input
end

local function get_cached_result(input)
  local input_hash = hash.hash_string(input)
  if not cache[input_hash] then
    print("Cache miss for:", input)
    cache[input_hash] = compute_expensive_result(input)
  else
    print("Cache hit for:", input)
  end
  return cache[input_hash]
end

-- First call (cache miss)
local result1 = get_cached_result("test input")
print("Result:", result1)

-- Second call (cache hit)
local result2 = get_cached_result("test input")
print("Result:", result2)

-- Different input (cache miss)
local result3 = get_cached_result("different input")
print("Result:", result3)

print("\nHash module example completed successfully.")
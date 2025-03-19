-- Simple Temporary File Management Example
--
-- This is a simplified version to test core functionality without timeouts

-- Load firmo
package.path = "../?.lua;../lib/?.lua;" .. package.path
local firmo = require("firmo")

-- Import necessary modules
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Create a simple test context
_G.firmo._current_test_context = "_simple_example_"

print("Creating temporary file...")
local file_path, err = temp_file.create_with_content("test content", "txt")
if err then
  print("Error creating file: " .. tostring(err))
  os.exit(1)
end

print("File created: " .. file_path)

-- Verify file exists
if fs.file_exists(file_path) then
  print("File exists on disk")
else
  print("ERROR: File does not exist")
  os.exit(1)
end

-- Clean up the file
print("Cleaning up...")
local success, errors = temp_file.cleanup_all()
if success then
  print("Cleanup successful")
else
  print("Cleanup had errors: " .. tostring(#errors) .. " errors")
end

-- Verify file was cleaned up
if fs.file_exists(file_path) then
  print("ERROR: File still exists after cleanup")
else
  print("File successfully removed")
end

print("Example completed!")
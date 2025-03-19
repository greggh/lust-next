-- Direct test of temp_file module without using firmo

package.path = "./?.lua;./lib/?.lua;" .. package.path
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

print("Testing temp_file module directly...")

-- Create temp file
print("Creating temp file...")
local file_path = temp_file.generate_temp_path("txt")
print("Generated path: " .. file_path)

-- Write to file manually
local f = io.open(file_path, "w")
f:write("Test content")
f:close()

-- Register the file
print("Registering file...")
temp_file.register_file(file_path)

-- Get stats
local stats = temp_file.get_stats()
print("Registered files: " .. stats.files)

-- Clean up
print("Cleaning up...")
local success, errors = temp_file.cleanup_all()
print("Cleanup success: " .. tostring(success))

-- Verify cleanup
local exists = fs.file_exists(file_path)
print("File still exists: " .. tostring(exists))

print("Test completed")
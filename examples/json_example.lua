-- JSON module example
local json = require("lib.tools.json")
local test_helper = require("lib.tools.test_helper")
local logging = require("lib.tools.logging")

-- Example 1: Basic encoding and decoding
print("\nExample 1: Basic Encoding/Decoding")
print("----------------------------------")

local data = {
  name = "test",
  values = {1, 2, 3},
  enabled = true
}

local json_str = json.encode(data)
print("Original data:", logging.format_value(data))
print("JSON string:", json_str)

local decoded = json.decode(json_str)
print("Decoded data:", logging.format_value(decoded))

-- Example 2: Working with files
print("\nExample 2: Working with Files")
print("--------------------------")

-- Create a test directory
local test_dir = test_helper.create_temp_test_directory()

-- Create a configuration object
local config = {
  server = {
    host = "localhost",
    port = 8080
  },
  database = {
    url = "postgres://localhost/test",
    pool = {
      min = 1,
      max = 10
    }
  },
  features = {
    logging = true,
    metrics = false
  }
}

-- Save to file
print("Saving configuration to file...")
test_dir.create_file("config.json", json.encode(config))

-- Read from file
print("Reading configuration from file...")
local content = test_dir.read_file("config.json")
local loaded_config = json.decode(content)

print("Loaded config:", logging.format_value(loaded_config))

-- Example 3: Error Handling
print("\nExample 3: Error Handling")
print("----------------------")

-- Try to encode an invalid value
local result, err = json.encode(function() end)
print("Trying to encode a function:")
print("Result:", result)
print("Error:", err and err.message or "no error")

-- Try to decode invalid JSON
result, err = json.decode("invalid json")
print("\nTrying to decode invalid JSON:")
print("Result:", result)
print("Error:", err and err.message or "no error")

-- Example 4: Special Cases
print("\nExample 4: Special Cases")
print("---------------------")

-- Special numbers
print("Encoding special numbers:")
print("NaN:", json.encode(0/0))
print("Infinity:", json.encode(math.huge))
print("-Infinity:", json.encode(-math.huge))

-- Escaped strings
print("\nEncoding escaped strings:")
print("Newline:", json.encode("hello\nworld"))
print("Quote:", json.encode("quote\"here"))
print("Tab:", json.encode("tab\there"))

-- Arrays vs Objects
print("\nArrays vs Objects:")
print("Array:", json.encode({1, 2, 3}))
print("Object:", json.encode({x = 1, y = 2}))
print("Mixed:", json.encode({1, 2, x = 3}))

-- Example 5: Schema Validation
print("\nExample 5: Schema Validation")
print("-------------------------")

-- Define a schema validator
local function validate_user(user)
  if type(user) ~= "table" then return false end
  if type(user.name) ~= "string" then return false end
  if type(user.age) ~= "number" then return false end
  return true
end

-- Valid user
local valid_user = {
  name = "John",
  age = 30
}

print("Valid user:")
local json_user = json.encode(valid_user)
print("JSON:", json_user)

local decoded_user = json.decode(json_user)
print("Valid?", validate_user(decoded_user))

-- Invalid user
local invalid_user = {
  name = 123,  -- Wrong type
  age = "30"   -- Wrong type
}

print("\nInvalid user:")
json_user = json.encode(invalid_user)
print("JSON:", json_user)

decoded_user = json.decode(json_user)
print("Valid?", validate_user(decoded_user))

print("\nJSON module example completed successfully.")
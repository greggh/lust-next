-- Example demonstrating formatter configuration options
local lust = require("lust-next")
local central_config = require("lib.core.central_config")
local reporting = require("lib.reporting")

print("Formatter Configuration Example")
print("===============================")
print("This example demonstrates how to configure formatters using the central configuration system")

-- Configure HTML formatter
print("\n1. Configuring HTML formatter with light theme:")
reporting.configure_formatter("html", {
  theme = "light",                -- Light theme (default is dark)
  show_line_numbers = true,       -- Show line numbers in source view
  collapsible_sections = true,    -- Allow sections to be collapsed
  highlight_syntax = true,        -- Apply syntax highlighting
  include_legend = true           -- Show legend explaining colors
})

-- Get HTML formatter configuration
local html_config = reporting.get_formatter_config("html")
print("HTML formatter configuration:")
for k, v in pairs(html_config) do
  print(string.format("  %s = %s", k, tostring(v)))
end

-- Configure JSON formatter
print("\n2. Configuring JSON formatter:")
reporting.configure_formatter("json", {
  pretty = true,                -- Pretty-print JSON (indented)
  schema_version = "1.1"        -- Schema version to include
})

-- Get JSON formatter configuration
local json_config = reporting.get_formatter_config("json")
print("JSON formatter configuration:")
for k, v in pairs(json_config) do
  print(string.format("  %s = %s", k, tostring(v)))
end

-- Configure multiple formatters at once
print("\n3. Configuring multiple formatters at once:")
reporting.configure_formatters({
  summary = {
    detailed = true,            -- Show detailed summary output
    show_files = true,          -- Include file information
    colorize = true             -- Use colorized output when available
  },
  csv = {
    delimiter = ",",
    quote = "\"",
    include_header = true
  }
})

-- Verify configuration using central_config directly
print("\n4. Verifying configuration using central_config:")
local formatter_config = central_config.get("reporting.formatters")
print("All formatter configurations from central_config:")
for formatter, config in pairs(formatter_config) do
  print("- " .. formatter .. ":")
  for k, v in pairs(config) do
    print(string.format("  %s = %s", k, tostring(v)))
  end
end

print("\n5. Running a simple test with configured formatters:")
-- Write a simple test
lust.describe("Basic test", function()
  lust.it("should pass", function()
    lust.expect(true).to.be.truthy()
  end)
  
  lust.it("should have proper equality", function()
    lust.expect({1, 2, 3}).to.equal({1, 2, 3})
  end)
end)

-- Run the test
lust.run()

print("\nTo see HTML output with configured light theme, use:")
print("lua run_tests.lua --coverage -cf html examples/formatter_config_example.lua")
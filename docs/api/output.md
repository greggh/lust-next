# Output Formatting API
This document describes the output formatting capabilities provided by Lust-Next, allowing you to customize how test results are displayed.

## Overview
Lust-Next provides a flexible output formatting system that allows you to customize how test results are presented. This includes options for colors, indentation, verbosity levels, and specialized output formats.
The output formatting options can dramatically improve the readability of your test output, especially when running large test suites.

## Formatting Functions

### lust.format(options)
Configures the output formatting options.
**Parameters:**

- `options` (table): A table of formatting options (see formatting options table below)
**Returns:**

- The lust object (for chaining)
**Example:**

```lua
-- Configure output formatting
lust.format({
  use_color = true,
  indent_char = '  ',
  indent_size = 2,
  compact = true
})

```text

### lust.nocolor()
Disables colored output. This is a shorthand for `lust.format({ use_color = false })`.
**Returns:**

- The lust object (for chaining)
**Example:**

```lua
-- Disable colored output
lust.nocolor()

```text

## Formatting Options
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `use_color` | boolean | `true` | Whether to use ANSI color codes in output |
| `indent_char` | string | `'\t'` | Character to use for indentation (tab or spaces) |
| `indent_size` | number | `1` | How many indent_chars to use per level |
| `show_trace` | boolean | `false` | Whether to show stack traces for errors |
| `show_success_detail` | boolean | `true` | Whether to show details for successful tests |
| `compact` | boolean | `false` | Use compact output format (less verbose) |
| `dot_mode` | boolean | `false` | Use dot mode (. for pass, F for fail) |
| `summary_only` | boolean | `false` | Show only summary, not individual tests |

## Examples

### Basic Configuration

```lua
local lust = require('lust-next')
-- Set up formatting before running tests
lust.format({
  use_color = true,
  indent_char = '  ',
  indent_size = 2,
  show_trace = true
})
-- Your tests here
describe("My feature", function()
  it("works correctly", function()
    expect(1 + 1).to.equal(2)
  end)
end)

```text

### Different Output Styles

#### Standard Output (Default)

```lua
lust.format({
  use_color = true,
  show_success_detail = true,
  compact = false
})

```text
This produces verbose output with colors:

```text
My feature
  PASS Test works correctly

```text

#### Compact Output

```lua
lust.format({
  compact = true,
  show_success_detail = false
})

```text
This produces less verbose output:

```text
My feature
  .

```text

#### Dot Mode

```lua
lust.format({
  dot_mode = true
})

```text
This produces minimal output with dots for passing tests and 'F' for failing tests:

```text
...F..

```text

#### Summary Only

```lua
lust.format({
  summary_only = true
})

```text
This only shows the final summary:

```text
5 passes, 1 failure

```text

#### Plain Text (No Colors)

```lua
lust.format({
  use_color = false
})

```text
or simply:

```lua
lust.nocolor()

```text
This disables ANSI color codes, useful for environments that don't support them.

### Custom Indentation

```lua
-- Using spaces for indentation
lust.format({
  indent_char = ' ',
  indent_size = 2
})
-- Using tabs for indentation
lust.format({
  indent_char = '\t',
  indent_size = 1
})

```text

### Showing Stack Traces

```lua
lust.format({
  show_trace = true
})

```text
This shows full stack traces for errors:

```text
FAIL Test that will fail
  stack traceback:
    test.lua:10: in function 'fn'
    lust-next.lua:283: in upvalue 'subject'
    lust-next.lua:289: in function <lust-next.lua:278>

```text

## Command Line Integration
When running tests via the command line, you can use the `--format` option to specify a predefined format.

```bash

# Run tests with dot mode
lua lust-next.lua --format dot

# Run tests with compact mode
lua lust-next.lua --format compact

# Run tests with summary only
lua lust-next.lua --format summary

# Run tests with detailed output
lua lust-next.lua --format detailed

# Run tests with plain text (no colors)
lua lust-next.lua --format plain

```text
You can also customize indentation from the command line:

```bash

# Use spaces for indentation
lua lust-next.lua --indent spaces

# Use 4 spaces for indentation
lua lust-next.lua --indent 4

# Use tabs for indentation
lua lust-next.lua --indent tabs

```text

## Best Practices

1. **Choose the right format for the context**:
   - Use detailed output during development for clarity
   - Use dot mode or compact mode for large test suites
   - Use summary only for CI systems
1. **Consider the environment**:
   - Disable colors for environments that don't support ANSI color codes
   - Use plain text output for logs that will be stored
1. **Adjust verbosity for test size**:
   - For large test suites, use compact or dot mode
   - For focused testing, use detailed output with stack traces
1. **Consistent configuration**:
   - Set up standard formatting in project init files
   - Document formatting conventions for your team
1. **Configure for maximum readability**:
   - Use indentation that matches your code style
   - Use colors when supported to highlight important information

## Examples in Context

### Error Handling
With detailed error output:

```lua
-- Enable detailed error output
lust.format({
  show_trace = true,
  show_success_detail = true
})
describe("Error handling", function()
  it("provides helpful error messages", function()
    local function will_error()
      error("Something went wrong")
    end
    -- This will fail and show detailed error information
    will_error()
  end)
end)

```text

### CI Integration
For CI environments, you might want summary-only output for logs:

```lua
-- Check if we're running in a CI environment
local in_ci = os.getenv("CI") == "true"
if in_ci then
  -- Use summary only mode for CI
  lust.format({
    summary_only = true,
    use_color = false  -- Many CI log systems don't support color
  })
else
  -- Use detailed mode for local development
  lust.format({
    show_trace = true,
    compact = false
  })
end

```text

### Large Test Suites
For large test suites, dot mode can provide a compact overview:

```lua
lust.format({
  dot_mode = true
})
-- When many tests run, you'll see something like:
-- .........................F...........
-- 
-- Followed by details on the single failure

```text


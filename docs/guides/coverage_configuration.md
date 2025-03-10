# Configuring Code Coverage in lust-next

This guide explains the various coverage configuration options in lust-next and when to use them to get the most accurate and useful coverage results.

## Basic Coverage Configuration

lust-next provides a robust code coverage module with numerous configuration options. The most basic configuration looks like this:

```lua
lust.coverage_options = {
  enabled = true,                  -- Enable coverage tracking
  threshold = 90,                  -- Minimum coverage percentage (default: 90%)
  format = "html",                 -- Output format (summary, html, json, lcov)
  output = "./coverage/report.html" -- Output file path
}
```

## Coverage Source Directories and Patterns

You can control which files are included in coverage analysis:

```lua
lust.coverage_options = {
  enabled = true,
  source_dirs = {"src", "lib"},    -- Directories to scan for source files
  include = {"**/*.lua"},          -- Patterns of files to include
  exclude = {"**/*_test.lua"},     -- Patterns of files to exclude
  use_default_patterns = true      -- Whether to use default include/exclude patterns
}
```

## Advanced Coverage Options

lust-next provides several advanced coverage options to fine-tune the analysis:

```lua
lust.coverage_options = {
  enabled = true,
  track_blocks = true,             -- Track code blocks (if/else, loops)
  use_static_analysis = true,      -- Use static analysis for improved accuracy
  control_flow_keywords_executable = true, -- Treat control flow keywords as executable
  discover_uncovered = true,       -- Discover files not executed by tests
  debug = false                    -- Enable debug output
}
```

## Understanding Control Flow Keywords Configuration

The `control_flow_keywords_executable` option controls how lust-next treats control flow keywords like `end`, `else`, `until`, etc. in coverage calculations.

### When control_flow_keywords_executable = true (default)

This is the stricter setting:
- Keywords like `end`, `else`, `until`, etc. are considered executable lines
- This requires these lines to be "covered" during test execution
- It typically results in lower coverage percentages
- It's more thorough but may require more testing effort

Example of what's considered executable:
```lua
if value > 0 then    -- Executable
  -- code           
else                 -- Executable (with this setting)
  -- code
end                  -- Executable (with this setting)
```

### When control_flow_keywords_executable = false

This is the more lenient setting:
- Keywords like `end`, `else`, `until`, etc. are considered non-executable
- These lines don't need to be "covered" during test execution
- It typically results in higher coverage percentages
- It focuses coverage on actual logic rather than syntax

Example of what's considered executable:
```lua
if value > 0 then    -- Executable
  -- code           
else                 -- NOT executable (with this setting)
  -- code
end                  -- NOT executable (with this setting)
```

## When to Use Each Setting

### Use control_flow_keywords_executable = true when:

- You want the most rigorous coverage requirements
- You're building critical systems that need thorough testing
- Your team has agreed on a high coverage standard
- You want to ensure all code paths are fully exercised

### Use control_flow_keywords_executable = false when:

- You want to focus coverage on actual logic rather than syntax
- You're dealing with complex code with many nested blocks
- You're starting a new project and want to gradually build up coverage
- You're more concerned with functional coverage than syntax coverage

## Combining with Block Coverage

For the most comprehensive coverage analysis, combine control flow keyword settings with block coverage:

```lua
lust.coverage_options = {
  enabled = true,
  track_blocks = true,
  use_static_analysis = true,
  control_flow_keywords_executable = true
}
```

This will provide detailed analysis of:
- Line coverage (which lines were executed)
- Block coverage (which code blocks were executed)
- Branch coverage (which branches were taken)

## Examples

See the `examples/coverage_keywords_example.lua` file for a demonstration of how the different settings affect coverage calculation and visualization.

## Best Practices

1. **Be consistent**: Choose a setting and use it consistently across your project
2. **Document your choice**: Add a comment in your config explaining why you chose a particular setting
3. **Consider project phase**: Use more lenient settings early in development, stricter settings as you mature
4. **Balance with other metrics**: Consider complementing with block coverage and other quality metrics
5. **Visualize differences**: Generate reports with both settings to understand the impact

## Impact on Coverage Thresholds

If you switch from `control_flow_keywords_executable = true` to `false`, you may see a significant increase in your coverage percentage. Consider adjusting your coverage threshold accordingly to maintain the same level of testing rigor.
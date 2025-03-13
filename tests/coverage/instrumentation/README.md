# Instrumentation Tests

This directory contains tests for the lust-next code instrumentation system. The instrumentation module provides an alternative approach to code coverage through source code transformation.

## Directory Contents

- **instrumentation_module_test.lua** - Tests for the instrumentation module
- **instrumentation_test.lua** - Tests for instrumentation techniques
- **single_test.lua** - Standalone test for instrumentation verification

## Instrumentation Features

The lust-next instrumentation module provides:

- **Source code transformation** - Modify code to add coverage tracking
- **Line tracking** - Insert tracking code for each executable line
- **Branch tracking** - Insert tracking for conditional branches
- **Function tracking** - Insert tracking for function entries and exits
- **Error handling** - Gracefully handle errors during instrumentation
- **Performance optimization** - Efficient instrumentation strategies
- **AST-based parsing** - Use abstract syntax trees for accurate transformation
- **Source mapping** - Map instrumented code back to original source
- **Caching** - Cache instrumented files for performance

## Instrumentation vs. Debug Hooks

The coverage system provides two approaches:

1. **Debug Hooks** - Uses Lua's debug library to track line execution
   - Pros: No code modification, works with any Lua code
   - Cons: Performance impact, limited granularity
  
2. **Instrumentation** - Transforms code to include tracking
   - Pros: Better performance, finer granularity, branch coverage
   - Cons: Requires code transformation, potential AST limitations

## Instrumentation Process

The instrumentation process follows these steps:

1. Parse source code into an abstract syntax tree (AST)
2. Analyze the AST to identify executable lines, branches, and functions
3. Transform the AST to insert tracking calls
4. Generate instrumented source code
5. Load the instrumented code instead of the original
6. Collect and analyze coverage data during execution

## Running Tests

To run all instrumentation tests:
```
lua test.lua tests/coverage/instrumentation/
```

To run a specific instrumentation test:
```
lua test.lua tests/coverage/instrumentation/instrumentation_test.lua
```

See the [Coverage API Documentation](/docs/api/coverage.md) for more information.
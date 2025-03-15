# Debug Hook Tests

This directory contains tests for the firmo debug hook system. The debug hook module provides core line tracking functionality using Lua's debug hooks.

## Debug Hook Features

The firmo debug hook module provides:

- **Line execution tracking** - Track which lines are executed
- **Function call tracking** - Track which functions are called
- **Return tracking** - Track function returns
- **Count tracking** - Track how many times each line executes
- **Call stack tracking** - Track the current call stack
- **Conditional tracking** - Track conditional branches
- **Loop tracking** - Track loop iterations
- **Error handling** - Handle errors during hook execution
- **Performance optimization** - Efficient line tracking

## Debug Hook Architecture

The debug hook system uses Lua's built-in debug library to:

1. Register a hook function to be called on each line execution
2. Track which lines have been executed in each file
3. Store execution counts for statistical analysis
4. Identify code blocks and their execution patterns
5. Determine coverage metrics based on execution data

## Performance Considerations

Debug hooks have performance implications:

- Adding hooks slows down execution
- Optimizations are in place to minimize impact
- File-based enable/disable mechanisms control overhead
- Cache mechanisms prevent redundant operations
- Size limits prevent processing extremely large files

## Running Tests

To run all debug hook tests:
```
lua test.lua tests/coverage/hooks/
```

To run a specific debug hook test:
```
lua test.lua tests/coverage/hooks/debug_hook_test.lua
```

See the [Coverage API Documentation](/docs/api/coverage.md) for more information.
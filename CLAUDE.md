# Lust-Next Development Guide

## Hooks-Util Integration

Lust-Next is now integrated with the [hooks-util](https://github.com/greggh/hooks-util) framework as the primary testing framework. This integration allows hooks-util users to:

- Set up standard test directories with `lust_next.setup_project()`
- Generate CI workflows with `lust_next.generate_workflow()`
- Run tests with proper filtering with `lust_next.run_tests()`
- Add lust-next as a dependency with `lust_next.add_as_dependency()`

The integration is implemented in `/home/gregg/Projects/hooks-util/lua/hooks-util/lust-next.lua` and provides helpers to create standardized test environments across different project types.

When making changes to lust-next, consider the impact on the hooks-util integration, especially regarding:
- Path handling and module discovery
- Cross-platform compatibility
- Feature addition that might be useful in the hooks-util context

## Useful Commands

### Build and Test
- Run all tests: `lua lust-next.lua --dir ./tests`
- Run specific test: `lua lust-next.lua --file tests/specific_test.lua`
- Run with tags: `lua lust-next.lua --tags unit,fast`
- Run with format: `lua lust-next.lua --format dot`
- Check focused tests example: `lua lust-next.lua examples/focused_tests_example.lua`
- Run mocking example: `lua lust-next.lua examples/mocking_example.lua`

### Git Commands
- `git -C /home/gregg/Projects/lust-next status` - Check current status
- `git -C /home/gregg/Projects/lust-next add .` - Stage all changes
- `git -C /home/gregg/Projects/lust-next commit -m "message"` - Commit changes
- `git -C /home/gregg/Projects/lust-next push` - Push changes
- `git -C /home/gregg/Projects/lust-next tag -a vX.Y.Z -m "Version X.Y.Z"` - Create a new version tag

### Code Style Preferences
- 2-space indentation throughout the codebase
- Local function declarations preferred over table assignments when appropriate
- Comments use --- style for documentation
- Error messages should be consistent and informative
- Tests should follow AAA pattern (Arrange, Act, Assert)
- Example files should be well-commented with clear explanations

### Repository Structure
- Core file: `lust-next.lua` - Main module with all functionality
- Examples: `examples/` - Well-commented examples of features
- Tests: `tests/` - Tests for all framework features
- Docs: `docs/` - Documentation for the framework
  - API reference: `docs/api/` - Detailed API documentation
  - Guides: `docs/guides/` - User guides and tutorials

## Features

### Core Testing Features
- Nested describe/it blocks for test organization
- before/after hooks for setup and teardown
- expect-style assertions with detailed error messages
- Focused testing with fdescribe/fit
- Excluded testing with xdescribe/xit
- Test tagging and filtering

### Advanced Features
- Async testing with coroutine-based support
- Comprehensive mocking system with:
  - Spies for call tracking
  - Mocks for object simulation
  - Stubs for function replacement
  - Argument matchers for verification
  - Call sequence verification

### Planned Features - Test Quality Validation
- Test coverage analysis (Phase 1):
  - Line, function, and branch coverage tracking
  - Multiple report formats (console, JSON, HTML)
  - Coverage thresholds configuration
  - Filtering for included/excluded files

- Test quality validation (Phase 2):
  - Five-level quality system (Basic to Complete)
  - Assertion analysis and recommendations
  - Test structure and organization validation
  - Quality reports with improvement suggestions

### CLI Options
- `--format [dot|compact|summary|detailed]` - Output format
- `--indent [space|tab|NUMBER]` - Indentation style
- `--no-color` - Disable colored output
- `--filter PATTERN` - Filter tests by name
- `--tags TAG1,TAG2` - Filter tests by tags

## Version Management
- Current version: v0.7.0
- All releases are tagged in git with vX.Y.Z format

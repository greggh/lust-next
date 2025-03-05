# Lust-Next Development Guide

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

### CLI Options
- `--format [dot|compact|summary|detailed]` - Output format
- `--indent [space|tab|NUMBER]` - Indentation style
- `--no-color` - Disable colored output
- `--filter PATTERN` - Filter tests by name
- `--tags TAG1,TAG2` - Filter tests by tags

## Version Management
- Current version: v0.7.0
- All releases are tagged in git with vX.Y.Z format

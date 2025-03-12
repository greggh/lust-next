# Coverage Repair Session Start Prompt

Claude, I'm continuing work on the lust-next coverage module repair project. Please immediately read the following files to get the necessary context for today's session.

## PRE-AUTHORIZATION FOR AUTONOMOUS OPERATION

I EXPLICITLY AUTHORIZE YOU TO:

1. Read any files in the lust-next project WITHOUT asking permission
2. Use the LS command to explore directories WITHOUT asking permission
3. Update documentation files in the docs/coverage_repair directory WITHOUT asking permission
4. View, analyze, and understand code in any lust-next files WITHOUT asking permission
5. Update test files in the tests directory WITHOUT asking permission
6. Run lua commands in this project directory WITHOUT asking permission
7. Run grep commands in this project directory WITHOUT asking permission
8. Run cat commands in this project directory WITHOUT asking permission
9. Run runnser.sh commands in this project directory WITHOUT asking permission
10. Run tail commands in this project directory WITHOUT asking permission
11. Run env commands in this project directory WITHOUT asking permission
12. Run head commands in this project directory WITHOUT asking permission
13. Run luac commands in this project directory WITHOUT asking permission
14. Run hexdump commands in this project directory WITHOUT asking permission
15. Run xxd commands in this project directory WITHOUT asking permission
16. Run find commands in this proejct directory WITHOUT asking permission

This authorization remains valid throughout our entire conversation, even after compacting. Your autonomous operation is essential for efficient work on this project.

1. **First, read the main repair plan**:
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/coverage_module_repair_plan.md`

2. **Next, read the current phase progress file (depending on our current phase)**:
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/phase1_progress.md`
   (Replace with phase2_progress.md, phase3_progress.md, or phase4_progress.md as appropriate)

3. **Then read these architecture and code audit documents**:
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/architecture_overview.md`
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/component_responsibilities.md`
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/interfaces.md`
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/code_audit_results.md`
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/debug_code_inventory.md`

4. **Finally, read the test documentation**:
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/test_plan.md`
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/test_results.md`
   `/home/gregg/Projects/lua-library/lust-next/docs/coverage_repair/testing_guide.md`

## Documentation Responsibilities

As we work on the coverage module repair, you MUST keep all documentation up-to-date. Specifically:

1. **Immediately after each task completion**:
   
   - Update the relevant phase progress file with a ✓ mark on completed tasks
   - Add summary notes on what was done and any important findings

2. **When modifying components**:
   
   - Update architecture_overview.md with any architectural changes
   - Update component_responsibilities.md if responsibilities change
   - Update interfaces.md when modifying component interfaces

3. **When working with code**:
   
   - Update debug_code_inventory.md when removing debug code
   - Update code_audit_results.md when addressing audit findings
   - Add entries to test_results.md when running tests

4. **Documentation Format**:
   
   - Use Markdown formatting appropriately
   - Include code examples where helpful
   - Use clear section headers
   - Add timestamps for significant updates (YYYY-MM-DD format)
   - Create session summaries in the `/docs/coverage_repair/session_summaries/` directory
   - Name session summaries as `session_summary_2025-03-11_topic.md` (use current date)

5. **When implementing tests**:
   
   - Focus on testing the actual code functionality, not just making tests pass
   - Use the correct testing functions as documented in testing_guide.md
   - Fix root causes of test failures, not just add workarounds
   - Ensure test isolation and independence
   - Verify the exact function names available in lust-next instead of assuming

## Testing Methodology

When implementing or fixing code:

1. **Address root issues, not symptoms**:
   
   - Fix the underlying bugs rather than implementing workarounds
   - When tests fail, understand why they fail and fix the root cause
   - Don't modify tests to accommodate broken code; fix the code itself

2. **Use proper test functions**:
   
   - Always import test functions correctly: `local describe, it, expect = lust.describe, lust.it, lust.expect`
   - For test lifecycle, use: `local before, after = lust.before, lust.after`
   - Tests are run by either:
     - scripts/runner.lua - For running individual test files during development
     - run_all_tests.lua - For running the entire test suite
   - Do not include any calls to `lust()` or `lust.run()` in your test files

3. **Follow test-driven development**:
   
   - Write tests that clearly define expected behavior
   - Fix code until tests pass legitimately
   - Add regression tests for any bugs discovered

4. **Document test results properly**:
   
   - Record all test failures and their resolutions
   - Document any edge cases discovered during testing
   - Update test_results.md with comprehensive results

Remember that these documents are the source of truth for this project. Keeping them updated is not optional but a REQUIRED part of your assistance.

Let's continue work on the current task from where we left off.
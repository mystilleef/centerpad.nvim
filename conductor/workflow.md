# Project workflow

## Guiding principles

1. **Plan as source of truth**: Track all work in `plan.md`.
2. **Deliberate tech stack**: Document changes in `tech-stack.md` before
   implementation.
3. **Test-driven development**: Write unit tests before implementing
   functionality.
4. **High code coverage**: Maintain >80% code coverage for all modules.
5. **User experience priority**: Focus on user experience in every
   decision.
6. **Non-interactive & CI-aware**: Use non-interactive commands and
   `CI=true` for tools.

## Task lifecycle

### Standard task workflow

1. **Select**: Choose the next sequential task from `plan.md`.
2. **Initialize**: Change task status from `[ ]` to `[~]` in `plan.md`.
3. **Red phase**:
   - Create/update test files.
   - Write unit tests defining expected behavior.
   - Execute tests; confirm failure.
4. **Green phase**:
   - Write least code to pass tests.
   - Execute tests; confirm success.
5. **Refactor**:
   - Improve code clarity and performance without changing behavior.
   - Rerun tests to ensure integrity.
6. **Verify**: Run coverage reports (for example, `make test` or
   `busted`). Target >80%.
7. **Document**: Update `tech-stack.md` if implementation deviates from
   design.
8. **Finalize**: Update `plan.md` status to `[x]`.

### Phase completion & `checkpointing`

**Trigger**: execute upon completing a task that concludes a phase.

1. **Scope analysis**:
   - Identify the previous checkpoint `SHA` from `plan.md`.
   - List modified files: `git diff --name-only <prev_sha> HEAD`.
2. **Test verification**:
   - Ensure corresponding test files exist for all modified code files.
   - Analyze existing tests for naming and style conventions before
     creating new ones.
3. **Automated execution**:
   - Execute the full test suite.
   - Debug failures (at most two attempts) before seeking user guidance.
4. **Manual verification**:
   - Propose a step-by-step manual verification plan based on
     `product.md` and `plan.md`.
   - Await explicit user confirmation before proceeding.
5. **`Checkpointing`**:
   - Stage all changes.
   - Create a checkpoint commit:
     `conductor(checkpoint): End of Phase <Name>`.
   - Record the 7-character `SHA` in `plan.md`: `[checkpoint: <sha7>]`.

## Task completion checklist

Verify these criteria before marking any task as done:

- [ ] All automated tests pass.
- [ ] Code coverage meets or exceeds 80%.
- [ ] Code adheres to `conductor/code_styleguides/`.
- [ ] Public functions and methods contain documentation.
- [ ] Implementation avoids linting and static analysis errors.
- [ ] `plan.md` contains relevant implementation notes.
- [ ] Logic introduces no security vulnerabilities.

## Development commands

### Environment setup

```bash
# Install dependencies (for example, via luarocks or system package manager)
# make setup
```

### Daily workflow

```bash
# Run tests
make test
# Lint code
make lint
# Format code
make format
# Check formatting
make check
```

## Standards & guidelines

### Commits

Follow `kbase/git-commit-guide.md`. Use the following project-specific
types:

- `conductor`: Changes to project management files (for example,
  `plan.md`, `tracks.md`).

### Testing

- Maintain one-to-one mapping between modules and test files.
- Use `busted` for unit and integration testing.
- Mock external Neovim API calls where appropriate.

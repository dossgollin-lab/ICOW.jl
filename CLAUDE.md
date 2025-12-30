# Development Guidelines

## The "Golden Rules" (Project Specific)

1. First think through the problem, read the codebase for relevant files, and write a plan to file (either `tasks/phase_X_plan.md` or generic `tasks/todo.md`).
2. The plan should have a list of todo items that you can check off as you complete them.
3. Before you begin working, check in with me and I will verify the plan.
4. Then, begin working on the todo items, marking them as complete as you go.
5. Please every step of the way just give me a high level explanation of what changes you made
6. Make every task and code change you do as simple as possible. We want to avoid making any massive or complex changes. Every change should impact as little code as possible. Everything is about simplicity. If you are writing code from scratch, simplicity is still king -- always look for the simpler approach over an over-engineered one.
7. Finally, add a review section to the too.nd file with a summary of the changes you made and any other relevant information.
8. DO NOT BE LAZY. NEVER BE LAZY. IF THERE IS A BUG FIND THE ROOT CAUSE AND FIX IT. NO TEMPORARY FIXES. YOU ARE A SENIOR DEVELOPER. NEVER BE LAZY.
9. MAKE ALL FIXES AND CODE CHANGES AS SIMPLE AS HUMANLY POSSIBLE. THEY SHOULD ONLY IMPACT NECESSARY CODE RELEVANT TO THE TASK AND NOTHING ELSE. IT SHOULD IMPACT AS LITTLE CODE AS POSSIBLE. YOUR GOAL IS TO NOT INTRODUCE ANY BUGS. IT'S ALL ABOUT SIMPLICITY.

### Source of Truth

- **docs/equations.md**: The definitive mathematical reference.
  Contains all equations, parameters, zone definitions, and implementation guidance (paper vs C++ discrepancies).
- **docs/roadmap/**: The implementation plan.
  The master overview is in `README.md`.
  Each phase has its own detailed file (`phase01_*.md`, `phase02_*.md`, etc.).
  **Keep it high-level, conceptual, and strategic.**
  Note key considerations and dependencies, but do not include code snippets or work out implementation details.
  Details belong in the source files and their tests.
- **C++ Reference**: The original implementation is at [rceres/ICOW](https://github.com/rceres/ICOW/blob/master/src/iCOW_2018_06_11.cpp).
  Download locally to `docs/` for reference (file is in .gitignore and cannot be redistributed).
  Except for a few errors identified in `docs/equations.md`, this is a source of truth.

### Mathematical Fidelity

**CRITICAL**: The Julia implementation MUST match the C++ math exactly.

- No "simplified" formulas that approximate the C++ behavior.
- No shortcuts that change numerical results.
- The code can be cleaner/more readable, but the math must be identical.
- Only exception: bugs explicitly identified in `docs/equations.md` should be fixed.
- If you find the C++ formula complex, implement it faithfully anyway.
- Document any C++ bugs you fix in `docs/equations.md`.

## Code Quality & Style

- Physics functions (geometry.jl, costs.jl) must be pure (no side effects).
- State is managed only inside the state `struct`.
- The simulate function runs millions of times. Zero allocations inside the loop. Use scalar math or StaticArrays or a custom `struct`.
- Use parametric structs `struct MyStruct{T<:Real}` to avoid repetitive Float64 declarations.
  - Ensure these are instantiated with concrete types (e.g., Float64) during simulation to maintain type stability.
- Use snake_case for functions, CamelCase for types.

## Docstrings

Keep docstrings minimal and reference `docs/equations.md` for formulas.

- **Format**: Signature + one-sentence description + equation reference
- **No duplication**: Don't repeat equations from equations.md
- **No verbose sections**: Omit Arguments/Returns/Notes unless truly necessary
- **No examples**: Tests serve that purpose

Example:

```julia
"""
    calculate_dike_volume(city::CityParameters, D) -> volume

Calculate dike material volume (Equation 6). See docs/equations.md.
"""
```

## Julia Best Practices

### Structs

Use `Base.@kwdef` for parameter structs with defaults.
Prefer `immutable struct` over `mutable struct` unless state modification is strictly required.

### Assertions

Use `@assert` aggressively in constructors to enforce physical bounds (e.g., $W \le B$).

### Dependencies

- Approved: Distributions, DataFrames, YAXArrays, NetCDF, Metaheuristics, StaticArrays, Statistics, Random, Test.
- **Strict Rule**: If you need to add any other package, you must ASK PERMISSION from the user first. Do not add it to Project.toml without explicit approval.

### Package Management

- **Never** manually edit Project.toml or Manifest.toml files.
- **Never** run Pkg commands directly (e.g., `Pkg.add()`, `Pkg.generate()`, `Pkg.develop()`).
- **Always** ask the human to run package management commands manually. For example: "Please run `julia --project -e 'using Pkg; Pkg.add("PackageName")'`"

## Workflow (Strict)

### Phase Planning Workflow

Before implementing any phase:

1. Read the phase detail file in `docs/roadmap/phaseNN_*.md`
2. Resolve all open questions with the user
3. Get user approval on the approach
4. Mark the phase as "In Progress" in `docs/roadmap/README.md`

### Phase Completion Workflow

After completing each phase:

1. **STOP** and run the tests: `julia --project test/runtests.jl`
2. **REPORT** what was implemented and any discrepancies with the paper.
3. Update the phase status to "Completed" in `docs/roadmap/README.md`
4. **WAIT** for human feedback before proceeding to the next phase.

### Git Commits

**Never** create a commit from scratch. Always tell the user "this is ready to be committed".

## Testing Strategy

**Keep tests minimal.** Only test key invariants, not every possible case.

### What to Test

- **Zero/edge cases**: If inputs are 0, output should be 0 (or baseline)
- **Monotonicity**: Increasing defenses must always increase cost
- **Component sums**: Verify that parts add up to totals
- **Key constraints**: One test per constraint category, not per parameter
- **Type stability**: One test per file, not per function

### What NOT to Test

- Every default parameter value (test a few key ones)
- Every boundary condition (test the important ones)
- Redundant cases (if monotonicity passes, don't also test "values differ")
- Verbose type stability checks for every function

**Always** include explanatory comments for test groups that clarify the physical or logical reasoning.

For constraint validation tests, use the format:

```julia
# constraint inequality; brief explanation of why this matters physically/logically
@test_throws AssertionError function_call(invalid_value)
```

**Good examples:**

```julia
# total_value > 0; negative values are physically meaningless
@test_throws AssertionError validate_parameters(CityParameters(total_value = -1000.0))

# W ≤ B; cannot withdraw from areas above the dike base (they're protected)
@test_throws AssertionError Levers(5.0, 0, 0, 5.0, 2.0)
```

Group related tests under a single comment when they test the same constraint:

```julia
# 0 ≤ P ≤ 1; resistance percentage must be a valid fraction
@test_throws AssertionError Levers(0, 0, 1.5, 0, 0)
@test_throws AssertionError Levers(0, 0, -0.1, 0, 0)
```

This makes tests self-documenting and helps future developers understand the domain logic.

## Markdown Style

### Headers

- No numbers in headings (use descriptive names instead).
- Always include blank lines after headers.

### Formatting

- Use subsections (###) instead of bold text for structural elements.
- One sentence per line for better version control and diff readability.
- Always use LaTeX math (`$...$`) for equations and inequalities, never unicode math symbols (e.g., use `$\leq$` not `≤`).

### Lists

- Always include blank lines before and after lists.
- Use consistent list markers (prefer `-` for unordered lists).

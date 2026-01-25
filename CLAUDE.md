# Development Guidelines

## The "Golden Rules" (Project Specific)

1. First think through the problem, read the codebase for relevant files. Check `ROADMAP.md` for current progress.
2. Before you begin working, check in with me and I will verify the approach.
3. Then, begin working, marking items complete in `ROADMAP.md` as you go.
4. Please every step of the way just give me a high level explanation of what changes you made.
5. Make every task and code change you do as simple as possible. We want to avoid making any massive or complex changes. Every change should impact as little code as possible. Everything is about simplicity. If you are writing code from scratch, simplicity is still king -- always look for the simpler approach over an over-engineered one.
6. DO NOT BE LAZY. NEVER BE LAZY. IF THERE IS A BUG FIND THE ROOT CAUSE AND FIX IT. NO TEMPORARY FIXES. YOU ARE A SENIOR DEVELOPER. NEVER BE LAZY.
7. MAKE ALL FIXES AND CODE CHANGES AS SIMPLE AS HUMANLY POSSIBLE. THEY SHOULD ONLY IMPACT NECESSARY CODE RELEVANT TO THE TASK AND NOTHING ELSE. IT SHOULD IMPACT AS LITTLE CODE AS POSSIBLE. YOUR GOAL IS TO NOT INTRODUCE ANY BUGS. IT'S ALL ABOUT SIMPLICITY.

### Source of Truth

- **_background/equations.md**: The definitive mathematical reference.
  Contains all equations, parameters, zone definitions, and implementation guidance (paper vs C++ discrepancies).
  **All bugs found in the C++ reference are documented here** (7 total as of Jan 2026).
- **ROADMAP.md**: The implementation plan with checklist items.
  Mark items complete with `[x]` as you finish them.
  **Update CLAUDE.md at the end of each phase** to reflect architectural changes.
- **C++ Reference**: The original implementation is at [rceres/ICOW](https://github.com/rceres/ICOW/blob/master/src/iCOW_2018_06_11.cpp).
  Download locally to `_background/iCOW_2018_06_11.cpp` for reference (file is in .gitignore and cannot be redistributed).
  **Contains 7 bugs** - see `_background/equations.md` for complete documentation.

### Current Architecture

```
src/
├── ICOW.jl          # Main module: types subtyping SimOptDecisions abstracts
├── types.jl         # FloodDefenses, CityParameters (no SimOptDecisions dependency)
├── simulation.jl    # SimOptDecisions integration (initialize, run_timestep, etc.)
└── Core/            # Pure numeric functions (no structs, validated against C++)
    ├── Core.jl
    ├── geometry.jl  # dike_volume
    ├── costs.jl     # withdrawal_cost, resistance_cost, dike_cost, etc.
    ├── zones.jl     # zone_boundaries, zone_values
    └── damage.jl    # base_zone_damage, zone_damage, total_event_damage, etc.
```

**SimOptDecisions Integration:**

Types subtype SimOptDecisions abstracts:

- `Config <: AbstractConfig` - wraps CityParameters
- `Scenario <: AbstractScenario` - surges + discount_rate
- `State <: AbstractState` - holds `defenses::FloodDefenses{Float64}`
- `StaticPolicy{T} <: AbstractPolicy` - holds 5 floats (W, R, P, D, B)
- `Outcome <: AbstractOutcome` - investment + damage

SimOptDecisions methods in `simulation.jl`:

- `initialize(config, scenario, rng)` → State
- `time_axis(config, scenario)` → 1:n_years
- `get_action(policy, state, t, scenario)` → FloodDefenses
- `run_timestep(state, action, t, config, scenario, rng)` → (State, StepRecord)
- `compute_outcome(step_records, config, scenario)` → Outcome

Usage: `simulate(config, scenario, policy)` (SimOptDecisions dispatches on our types)

### Zero Backwards Compatibility

**CRITICAL**: This is a first-draft package with zero users.
Make breaking changes freely.
Delete deprecated code immediately.
No compatibility shims, no `@deprecate`, no `# removed` comments.
If something is unused, delete it completely.

### Mathematical Fidelity

**CRITICAL**: The Julia implementation MUST match the **paper formulas** exactly, not the buggy C++ code.

- The Julia code fixes all documented C++ bugs to match the paper.
- No "simplified" formulas that approximate the correct behavior.
- No shortcuts that change numerical results.
- The code can be cleaner/more readable, but the math must match the paper.
- All C++ bugs are documented in `_background/equations.md` with detailed explanations.
- If you find new C++ bugs, document them in `_background/equations.md` immediately.

### C++ Reference Validation

**Location:** `test/validation/cpp_reference/`

A debugged version of the C++ code is maintained for validation purposes:

- **icow_debugged.cpp**: C++ code with all 7 bugs fixed to match paper formulas
- **compile.sh**: Build script (requires Homebrew g++-15 on macOS)
- **outputs/**: Reference test outputs generated from debugged C++
- **validate_cpp_outputs.jl**: Julia script to validate implementation matches C++

**Purpose:**

1. **Validation**: Ensures Julia implementation matches corrected C++ math (within floating-point precision)
2. **Regression Testing**: Prevents introduction of bugs during refactoring
3. **Documentation**: Provides executable examples of correct calculations

**Usage:**

```bash
cd test/validation/cpp_reference
./compile.sh              # Compile debugged C++
./icow_test               # Generate reference outputs
cd ../../..
julia --project test/validation/cpp_reference/validate_cpp_outputs.jl  # Validate Julia
```

**What's tested:**

- 8 test cases covering edge cases (zero levers, R $\geq$ B, high surge, etc.)
- Withdrawal and resistance cost calculations
- Zone boundaries and values
- Validation tolerance: rtol=1e-10 (floating-point precision)

**Not tested:** Dike cost (Julia uses a corrected geometric formula; see `_background/equations.md` Equation 6).

**Maintenance:**

- When adding new physics functions, add corresponding test cases to the C++ harness
- Re-run validation after any changes to `src/Core/` files
- If validation fails, check `_background/equations.md` to determine which is correct

## Code Quality & Style

- Physics functions (geometry.jl, costs.jl) must be pure (no side effects).
- State is managed only inside the state `struct`.
- The simulate function runs millions of times. Zero allocations inside the loop. Use scalar math or StaticArrays or a custom `struct`.
- Use parametric structs `struct MyStruct{T<:Real}` to avoid repetitive Float64 declarations.
  - Ensure these are instantiated with concrete types (e.g., Float64) during simulation to maintain type stability.
- Use snake_case for functions, CamelCase for types.

## Docstrings

Keep docstrings minimal and reference `_background/equations.md` for formulas.

- **Format**: Signature + one-sentence description + equation reference
- **No duplication**: Don't repeat equations from equations.md
- **No verbose sections**: Omit Arguments/Returns/Notes unless truly necessary
- **No examples**: Tests serve that purpose

Example:

```julia
"""
    calculate_dike_volume(city::CityParameters, D) -> volume

Calculate dike material volume (Equation 6). See _background/equations.md.
"""
```

## Julia Best Practices

### Structs

Use `Base.@kwdef` for parameter structs with defaults.
Prefer `immutable struct` over `mutable struct` unless state modification is strictly required.

### Assertions

Use `@assert` aggressively in constructors to enforce physical bounds (e.g., $W \le B$).

### Dependencies

- Approved: Distributions, DataFrames, YAXArrays, NetCDF, Metaheuristics, StaticArrays, Statistics, Random, Test, SimOptDecisions, CairoMakie.
- **Strict Rule**: If you need to add any other package, you must ASK PERMISSION from the user first. Do not add it to Project.toml without explicit approval.

### Package Management

- **Never** manually edit Project.toml or Manifest.toml files.
- **Never** run Pkg commands directly (e.g., `Pkg.add()`, `Pkg.generate()`, `Pkg.develop()`).
- **Always** ask the human to run package management commands manually. For example: "Please run `julia --project -e 'using Pkg; Pkg.add("PackageName")'`"

## Workflow (Strict)

### Task Workflow

1. Check `ROADMAP.md` for current progress and next tasks
2. Resolve all open questions with the user
3. Get user approval on the approach
4. Implement, marking items complete in `ROADMAP.md` as you go
5. **STOP** and run the tests: `julia --project test/runtests.jl`
6. **REPORT** what was implemented
7. **WAIT** for human feedback before proceeding

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
@test_throws AssertionError FloodDefenses(5.0, 0, 0, 5.0, 2.0)
```

Group related tests under a single comment when they test the same constraint:

```julia
# 0 ≤ P ≤ 1; resistance percentage must be a valid fraction
@test_throws AssertionError FloodDefenses(0, 0, 1.5, 0, 0)
@test_throws AssertionError FloodDefenses(0, 0, -0.1, 0, 0)
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

### Citations

- Use Quarto's author-year citation format with `@citekey` syntax (e.g., `@ceres_cityonawedge:2019`).
- Never use inline markdown links for references (e.g., `[Author (Year)](url)`).
- Add references to `docs/references.bib` and include `bibliography: references.bib` in the YAML front matter.
- End documents with a `## References` section (Quarto auto-populates it).

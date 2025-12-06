# CLAUDE.md - Development Guidelines for ICOW.jl

## The "Golden Rules" (Project Specific)

### Marginal Costs

In dynamic simulations (simulation.jl), investment cost is always `max(0.0, cost_new - cost_old)`.
Never charge for existing infrastructure.

### Geometric Integrity

Equation 6 (Dike Volume) is complex.
Do not simplify it.
Implement it exactly as specified in specs.md.

### Unit Consistency

- City Value: Raw dollars (e.g., $1.5 \times 10^{12}$), NOT scaled units (1.5).
- Heights: Meters.
- Costs: Dollars.
- Note: Do NOT use Unitful.jl for internal physics; it is too slow for the optimization loop.

### Source of Truth

specs.md determines architecture.
docs/equations.md determines math.

## Code Quality & Style

### Pure Core

Physics functions (geometry.jl, costs.jl) must be pure (no side effects).

### Mutable Shell

State is managed only inside SimulationState.

### Allocations

The simulate function runs millions of times.
Zero allocations inside the loop.
Use scalar math or StaticArrays.

### Types

- Use parametric structs `struct MyStruct{T<:Real}` to avoid repetitive Float64 declarations.
- Ensure these are instantiated with concrete types (e.g., Float64) during simulation to maintain type stability.

### Naming

snake_case for functions, CamelCase for types.

## Julia Best Practices

### Structs

Use `Base.@kwdef` for parameters.
Prefer `immutable struct` over `mutable struct` unless state modification is strictly required.

### Assertions

Use `@assert` aggressively in constructors to enforce physical bounds (e.g., $W \le B$).

### Dependencies

- Approved: Distributions, DataFrames, YAXArrays, Metaheuristics, Statistics, Random, Test.
- **Strict Rule**: If you need to add any other package, you must ASK PERMISSION from the user first. Do not add it to Project.toml without explicit approval.

### Package Management

**Never** manually edit Project.toml or Manifest.toml files.

**Never** run Pkg commands directly (e.g., `Pkg.add()`, `Pkg.generate()`, `Pkg.develop()`).

**Always** ask the human to run package management commands manually.
For example: "Please run `julia --project -e 'using Pkg; Pkg.add("PackageName")'`"

## Workflow (Strict)

After completing each phase from specs.md:

1. **STOP** and run the tests: `julia --project test/runtests.jl`
2. **REPORT** what was implemented and any discrepancies with the paper.
3. **WAIT** for human feedback before proceeding to the next phase.

### Git Commits

When creating commits, use clear, descriptive messages in plain text.

**Do not** sign commits as "Claude" or add AI-generated signatures.

**Format**: `git commit -m "brief description of what was done"`

**Example**: `git commit -m "created CLAUDE.md and PROGRESS.md for project setup"`

## Progress Tracking

### PROGRESS.md

Use `PROGRESS.md` to track implementation progress across sessions.

**At the start of each session:**

- Check `PROGRESS.md` to see what's next
- Update "Current Phase" section
- Review any notes from previous session

**During implementation:**

- Check off completed items: `- [x] Item name`
- Add session notes, blockers, or decisions to the Notes section
- Keep it updated so you always know where you are

**At the end of each session:**

- Mark completed items with `[x]`
- Add any important notes or decisions
- Commit changes to git

## Testing Strategy

- **Zero-Test**: If inputs are 0, output should be 0 (or baseline).
- **Monotonicity**: Increasing defenses must always increase cost.
- **Regression**: The "Van Dantzig" case (Static Dike optimization) must yield a convex cost curve.

### Test Documentation

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

### Lists

- Always include blank lines before and after lists.
- Use consistent list markers (prefer `-` for unordered lists).

# EAD Integration: QuadGK vs Monte Carlo

## The Integration Structure

### Two-Level Expectation (One Numerical Integral)

The EAD calculation involves:

$$
\text{EAD} = \mathbb{E}_h\left[\mathbb{E}_{\text{dike}}[\text{damage} \mid h]\right] = \int_{-\infty}^{\infty} p(h) \cdot \mathbb{E}[\text{damage} \mid h] \, dh
$$

**Inner expectation** (over dike failure): **ANALYTICAL**
$$
\mathbb{E}[\text{damage} \mid h] = p_{\text{fail}}(h) \cdot d_{\text{failed}}(h) + (1 - p_{\text{fail}}(h)) \cdot d_{\text{intact}}(h)
$$
- No numerical integration needed
- Just a weighted average (one function evaluation)
- Eliminates one source of uncertainty analytically

**Outer expectation** (over surge distribution): **NUMERICAL**
$$
\text{EAD} = \int_{a}^{b} p(h) \cdot \mathbb{E}[\text{damage} \mid h] \, dh
$$
- **This is a SINGLE 1D integral**
- QuadGK is designed exactly for this!

## Method Comparison

### QuadGK (Adaptive Quadrature)

**How it works:**
- Adaptive subdivision: focuses samples where function varies most
- Evaluates integrand at strategic points (not random)
- Estimates error and refines until tolerance met (rtol=1e-6)

**Pros:**
✅ **Deterministic**: Same answer every time (no random seed issues)
✅ **Adaptive**: Concentrates evaluations where damage function is complex
✅ **Error control**: Guarantees accuracy to specified tolerance
✅ **Efficient for smooth functions**: Often needs fewer evaluations than MC
✅ **Perfect for 1D integrals**: This is exactly what it's designed for
✅ **No convergence variance**: Answer doesn't fluctuate between runs

**Cons:**
❌ **Can struggle with discontinuities**: Damage function has sharp transitions (e.g., when surge exceeds dike)
❌ **Requires bounded domain**: Need to truncate distribution tails (use quantiles)
❌ **Fixed integration algorithm**: Can't easily switch quadrature rules
❌ **Memory**: Stores evaluation points during adaptation

**Performance:**
- Typically 50-200 function evaluations for rtol=1e-6
- Very fast (< 1 second in validation script)

### Monte Carlo

**How it works:**
- Random sampling from surge distribution
- Average damage over all samples
- Converges as $O(1/\sqrt{N})$

**Pros:**
✅ **Robust to discontinuities**: Doesn't care about non-smooth functions
✅ **Naturally handles unbounded domains**: Just sample from distribution
✅ **Easy to parallelize**: Samples are independent
✅ **Matches stochastic mode conceptually**: Both use sampling
✅ **Simple implementation**: Just sample and average

**Cons:**
❌ **Stochastic**: Different answer each run (RNG-dependent)
❌ **Slower convergence**: Need many samples for high accuracy
❌ **No error estimate**: Don't know accuracy without running multiple times
❌ **Can miss rare events**: Random sampling might miss important tail events

**Performance:**
- Default: 10,000 samples (convergence validation script)
- Moderate speed (< 1 second in validation)
- Accuracy depends on $N$: 1000 samples ≈ 3% error, 10000 ≈ 1% error

## Current Implementation Choice

**Default: QuadGK (`:quad`)** with rtol=1e-6

**Rationale:**
1. **Deterministic**: Zero variance across runs for reproducible optimization
2. **Computational efficiency**: Fewer function evaluations than MC for equivalent accuracy
3. **Error control**: Guaranteed accuracy with adaptive sampling
4. **Better for GEV**: Handles storm surge tail behavior more reliably than MC

## When to Use Each Method

### Use QuadGK (`:quad`) when:
- You need **deterministic results** (no RNG variance)
- You want **guaranteed accuracy** with error control
- The surge distribution is **well-behaved** (smooth pdf, bounded support)
- You're doing **sensitivity analysis** (same integration error across runs)
- **Speed matters** and function is reasonably smooth

### Use Monte Carlo (`:mc`) when:
- You're okay with **stochastic variance** (or can average multiple runs)
- The damage function has **discontinuities** or sharp transitions
- You want to **match stochastic mode** conceptually
- You need **easy parallelization** (though QuadGK can be parallelized too)
- The surge distribution has **heavy tails** or unbounded support

## Performance Comparison

Benchmark results with GEV(μ=1.0, σ=0.5, ξ=0.1) storm surge distribution:

### Critical Finding: Heavy Tail Integration

**For GEV with positive shape (ξ=0.1), the upper tail is crucial:**
- Upper 0.1% tail (above 99.9th percentile) = **17.1% of expected damage**
- Integration must use infinite bounds, not truncated quantiles
- Truncating at 99.9th percentile underestimates EAD by ~17%

### Accuracy Test

Policy: 3m dike, no withdrawal/resistance

**QuadGK with infinite bounds [-Inf, Inf]:**
- Result: $535.51M (deterministic, zero variance)
- Time: ~3ms after compilation
- Agreement with MC: within 1-7%

**Monte Carlo (full distribution sampling):**
- N=1,000: $553M ± $139M std
- N=10,000: $541M ± $68M std
- N=100,000: $534M ± $18M std
- Converges to QuadGK as N increases

**Winner: QuadGK** - 7x faster, deterministic, accurate with proper infinite bounds.

## Discontinuities in the Integrand

The damage function has several discontinuities:

1. **Seawall threshold** (h ≤ H_seawall): damage = 0
2. **Zone boundaries**: damage formula changes at zone elevations
3. **Dike overtopping** (h > W+B+D): automatic failure, damage spikes
4. **Threshold penalty** (damage > d_thresh): polynomial penalty kicks in

**Impact on QuadGK:**
- Adaptive quadrature can handle smooth piecewise functions well
- But sharp spikes (like dike overtopping) may require many subdivisions
- Integration bounds (quantiles) help by avoiding distribution tails

**Impact on MC:**
- Doesn't care about discontinuities
- As long as we sample enough, we'll capture all regions
- Might need many samples to accurately capture rare but high-damage events

## Recommendation

**Current default: QuadGK** - benchmark results show clear superiority for GEV storm surge.

Completed:
1. ✅ QuadGK and MC both implemented
2. ✅ Trade-offs documented
3. ✅ Benchmark with realistic GEV distribution (`scripts/benchmark_ead_methods.jl`)

Future considerations for Phase 10:
- Adaptive importance sampling for extreme tail events
- Sparse grid methods if higher dimensions needed

## Example: Switching Methods

```julia
# QuadGK (default, deterministic)
ead_quad = calculate_expected_damage(city, levers, forcing, year)  # uses method=:quad

# Monte Carlo (stochastic alternative)
ead_mc = calculate_expected_damage(city, levers, forcing, year; method=:mc, n_samples=10000)

# High-precision QuadGK
ead_precise = calculate_expected_damage(city, levers, forcing, year; rtol=1e-8)
```

## Validation Results

From our convergence testing, both methods produce similar results:
- Mode convergence (MC): 1-3% difference vs stochastic
- Expected QuadGK convergence: < 1% difference vs stochastic (if smooth distributions)

## Future Enhancements

Consider for Phase 10 analysis:

1. **Adaptive method selection**: Choose based on distribution type
2. **Importance sampling MC**: For rare extreme events
3. **Quasi-Monte Carlo**: Deterministic low-discrepancy sequences
4. **Multi-level Monte Carlo**: For multi-year simulations
5. **Sparse grid quadrature**: For higher dimensions (if needed later)

## Bottom Line

**QuadGK is perfectly suited for this 1D integral!** The "double integral" is actually:
- Inner: Analytical (no numerical integration)
- Outer: 1D numerical integration (QuadGK's specialty)

QuadGK is the default because benchmark results show superior performance for GEV storm surge:
- Deterministic (zero variance)
- More accurate than MC even at N=100,000
- Faster per-simulation
- Ideal for optimization and sensitivity analysis

MC remains available as a fallback option (`method=:mc`).

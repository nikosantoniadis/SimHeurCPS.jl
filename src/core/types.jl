# ---- Abstract contracts (core knows NOTHING about specific algorithms) ----

"""
    AbstractProblem

Abstract supertype for all optimization problems in SimHeurCPS.

# Arguments
This is an abstract type with no fields. Concrete problem types must subtype
either `HasInitialSolution` (when a deterministic baseline is available) or
`BlackBoxProblem` (when no baseline exists).

# Examples
```julia
# Define a new problem with a known initial solution
struct MyProblem <: HasInitialSolution
    data::Matrix{Float64}
end

# Define a black-box problem
struct MyBlackBox <: BlackBoxProblem
    bounds::Vector{Tuple{Float64,Float64}}
end
```
"""
abstract type AbstractProblem end

"""
    HasInitialSolution <: AbstractProblem

Abstract type for problems that provide a known feasible starting point and
a deterministic baseline usable for variance reduction via control variates.

# Arguments
No fields — this is an abstract type. Subtypes must implement
`initial_solution(prob)` and `control_variate_baseline(prob, x)`.

# Examples
```julia
struct OPPProblem <: HasInitialSolution
    n_buses::Int
    miqcp_objective::Float64
end

prob = OPPProblem(100, 42.0)
x0 = initial_solution(prob)     # returns feasible starting point
cv  = control_variate_baseline(prob, x0)  # deterministic MIQCP value
```
"""
abstract type HasInitialSolution <: AbstractProblem end

"""
    BlackBoxProblem <: AbstractProblem

Abstract type for problems that lack a deterministic baseline. Evaluation
relies purely on stochastic sampling with no control-variate adjustment.

# Arguments
No fields — this is an abstract type. Subtypes must implement
`random_candidate(prob)` and `evaluate_stochastic(prob, x, rng; antithetic)`.

# Examples
```julia
struct MedicalCPS <: BlackBoxProblem
    param_bounds::Vector{Tuple{Float64,Float64}}
end

prob = MedicalCPS([(0.0, 1.0), (-5.0, 5.0)])
x = random_candidate(prob)      # random feasible candidate
```
"""
abstract type BlackBoxProblem <: AbstractProblem end

"""
    AbstractEvaluator

Abstract supertype for all evaluation strategies (Monte Carlo, surrogate,
etc.). Concrete evaluators implement `evaluate(ev, prob, x)` and return
`(estimated_mean, standard_error, evaluations_consumed)`.

# Arguments
No fields — this is an abstract type.

# Examples
```julia
# Monte Carlo evaluator (built-in)
ev = MCEvaluator(100, 10_000, 0.05, true, true, MersenneTwister(42))

# Future surrogate evaluator
struct SurrogateEvaluator <: AbstractEvaluator
    model::Any
end
```
"""
abstract type AbstractEvaluator end

"""
    AbstractMetaheuristic

Abstract supertype for all metaheuristic search algorithms. Every algorithm
implements `step!(alg, prob, ev, x, fx)` to propose the next candidate.

# Arguments
No fields — this is an abstract type.

# Examples
```julia
# Built-in RVNS
alg = RVNS([SwapNeighborhood(1, 2), SwapNeighborhood(3, 4)], 2)

# Future simulated annealing
struct SimulatedAnnealing <: AbstractMetaheuristic
    T0::Float64
    cooling_rate::Float64
end
```
"""
abstract type AbstractMetaheuristic end

"""
    MCEvaluator <: AbstractEvaluator

Adaptive Monte Carlo evaluator with optional variance-reduction techniques.

# Arguments
- `n_min::Int`: Minimum number of Monte Carlo replications before checking convergence.
- `n_max::Int`: Maximum number of replications (hard budget per evaluation).
- `cv_target::Float64`: Target coefficient of variation for adaptive stopping.
- `antithetic::Bool`: Whether to use antithetic variates (paired negative correlation).
- `control_variate::Bool`: Whether to apply control-variate adjustment (requires `HasInitialSolution`).
- `rng::Random.AbstractRNG`: Random number generator for reproducible CRN streams.

# Examples
```julia
rng = MersenneTwister(42)
ev = MCEvaluator(100, 10_000, 0.05, true, true, rng)

# Evaluate an OPP solution (HasInitialSolution → full variance reduction)
mean_val, se, reps = evaluate(ev, opp_prob, x)

# Evaluate a black-box solution (no control variates)
mean_val, se, reps = evaluate(ev, bb_prob, x)
```
"""
struct MCEvaluator <: AbstractEvaluator
    n_min::Int
    n_max::Int
    cv_target::Float64
    antithetic::Bool
    control_variate::Bool
    rng::Random.AbstractRNG
end
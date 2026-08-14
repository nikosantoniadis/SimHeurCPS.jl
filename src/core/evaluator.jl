using Statistics, Random, Base.Threads

# ---- Generic evaluate interface ----

"""
    evaluate(ev::AbstractEvaluator, prob::AbstractProblem, x)

Estimate the objective value at solution `x` using the evaluator's strategy.
Returns (estimated_mean, standard_error, evaluations_consumed).

Concrete evaluators dispatch on `prob`'s type to determine whether
variance-reduction techniques like control variates are applicable.

# Evaluation paths
- HasInitialSolution + MCEvaluator → full machinery: control variates,
  antithetic variates, adaptive stopping, @threads parallelism.
- BlackBoxProblem + MCEvaluator → plain MCS with antithetic variates
  and @threads, no control variates (no deterministic baseline exists).
- Future: surrogate evaluators will dispatch here as well.
"""
function evaluate(ev::AbstractEvaluator, prob::AbstractProblem, x)
    error("evaluate not implemented for $(typeof(ev)) and $(typeof(prob))")
end

#--- Problem interface functions (to be defined in problems/) ----

"""
    control_variate_baseline(prob, x)

Return the deterministic baseline at solution `x`.
Used as the control variate: the stochastic estimator becomes
    estimator = stochastic_value - control_variate + deterministic_mean
where deterministic_mean is pre-computed from historical runs or known
closed forms. Only defined for HasInitialSolution problems.

Example (ITOR 2022 OPP): the MIQCP deterministic objective value.
"""
function control_variate_baseline end

"""
    evaluate_stochastic(prob, x, rng; antithetic=false)

A single replication of the stochastic simulation at `x`.
The problem defines the uncertainty model (loads, disturbances,
physiological noise).

If antithetic=true, the problem should mirror its internal random
draws to produce a negatively correlated replication partner.
"""
function evaluate_stochastic end
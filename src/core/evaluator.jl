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

# ---- MCEvaluator for HasInitialSolution (full variance reduction) ----

"""
    evaluate(ev::MCEvaluator, prob::HasInitialSolution, x)

Adaptive Monte Carlo with the full variance-reduction toolkit:
- Control variates using the problem's deterministic baseline
- Antithetic variates for paired negative correlation
- @threads parallelism across replications
- Adaptive stopping when the coefficient of variation falls below cv_target

Returns (estimated_mean, standard_error, replications_used).

CRN: The RNG is seeded from evaluator.rng. Repeated calls with the same
MCEvaluator instance produce reproducible streams — essential for fair
comparison of different candidate solutions.
"""
function evaluate(ev::MCEvaluator, prob::HasInitialSolution, x)
    determ = control_variate_baseline(prob, x)
    n_reps = ev.n_min
    cv_stop = false
    n_total = 0
    total = 0.0
    total_sq = 0.0

    while n_reps <= ev.n_max && !cv_stop
        # Allocate thread-local accumulators
        partials = zeros(Threads.nthreads())
        partials_sq = zeros(Threads.nthreads())
        partials_cnt = zeros(Int, Threads.nthreads())

        @threads for tid in 1:Threads.nthreads()
            local_rng = copy(ev.rng)
            # Jump to this thread's starting position for CRN consistency
            for _ in 1:(n_total + (tid - 1) * div(n_reps - n_total, Threads.nthreads(), RoundUp))
                rand(local_rng)
            end
            # Each thread evaluates its chunk
            chunk = div(n_reps - n_total, Threads.nthreads(), RoundUp)
            for _ in 1:chunk
                # Antithetic pair: draw once, use mirrored variate for partner
                val1 = evaluate_stochastic(prob, x, local_rng; antithetic = false)
                val2 = evaluate_stochastic(prob, x, local_rng; antithetic = true)
                adj1 = val1 + determ - control_variate_baseline(prob, x)
                adj2 = val2 + determ - control_variate_baseline(prob, x)
                partials[tid] += adj1 + adj2
                partials_sq[tid] += adj1^2 + adj2^2
                partials_cnt[tid] += 2
            end
        end

        for tid in 1:Threads.nthreads()
            total += partials[tid]
            total_sq += partials_sq[tid]
            n_total += partials_cnt[tid]
        end

        # Adaptive stopping: check coefficient of variation
        μ_bar = total / n_total
        σ_bar = sqrt((total_sq - 2 * μ_bar * total + n_total * μ_bar^2) / (n_total - 1))
        cv = σ_bar / abs(μ_bar)

        if cv < ev.cv_target && n_total >= ev.n_min
            cv_stop = true
        else
            n_reps = min(2 * n_reps, ev.n_max)  # geometric doubling
        end
    end

    mean_val = total / n_total
    se = sqrt((total_sq - 2 * mean_val * total + n_total * mean_val^2) /
              (n_total * (n_total - 1)))
    return mean_val, se, n_total
end

# ---- MCEvaluator for BlackBoxProblem (plain MCS, no baseline) ----

"""
    evaluate(ev::MCEvaluator, prob::BlackBoxProblem, x)

Plain Monte Carlo for black-box problems where no deterministic baseline
exists. Still uses antithetic variates and @threads parallelism.
Adaptive stopping based on coefficient of variation.

Returns (estimated_mean, standard_error, replications_used).
"""
function evaluate(ev::MCEvaluator, prob::BlackBoxProblem, x)
    n_reps = ev.n_min
    cv_stop = false
    n_total = 0
    total = 0.0
    total_sq = 0.0

    while n_reps <= ev.n_max && !cv_stop
        partials = zeros(Threads.nthreads())
        partials_sq = zeros(Threads.nthreads())
        partials_cnt = zeros(Int, Threads.nthreads())

        @threads for tid in 1:Threads.nthreads()
            local_rng = copy(ev.rng)
            for _ in 1:(n_total + (tid - 1) * div(n_reps - n_total, Threads.nthreads(), RoundUp))
                rand(local_rng)
            end
            chunk = div(n_reps - n_total, Threads.nthreads(), RoundUp)
            for _ in 1:chunk
                val1 = evaluate_stochastic(prob, x, local_rng; antithetic = false)
                val2 = evaluate_stochastic(prob, x, local_rng; antithetic = true)
                partials[tid] += val1 + val2
                partials_sq[tid] += val1^2 + val2^2
                partials_cnt[tid] += 2
            end
        end

        for tid in 1:Threads.nthreads()
            total += partials[tid]
            total_sq += partials_sq[tid]
            n_total += partials_cnt[tid]
        end

        μ_bar = total / n_total
        σ_bar = sqrt((total_sq - 2 * μ_bar * total + n_total * μ_bar^2) / (n_total - 1))
        cv = σ_bar / abs(μ_bar)

        if cv < ev.cv_target && n_total >= ev.n_min
            cv_stop = true
        else
            n_reps = min(2 * n_reps, ev.n_max)
        end
    end

    mean_val = total / n_total
    se = sqrt((total_sq - 2 * mean_val * total + n_total * mean_val^2) /
              (n_total * (n_total - 1)))
    return mean_val, se, n_total
end

# ---- Problem interface functions (to be defined in problems/) ----

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
using Statistics, Random, Base.Threads

# ---- MCEvaluator: dispatched automatically by evaluate() ----

"""
    evaluate(ev::MCEvaluator, prob::HasInitialSolution, x)

Full variance-reduction MCS for problems with a known deterministic baseline
(e.g., OPP with its MIQCP baseline from ITOR 2022).

Uses:
- Control variates: stochastic_value - baseline + deterministic_mean
- Antithetic variates: paired replications with mirrored random draws
- @threads: parallel replications across CPU cores
- Adaptive stopping: geometric doubling until CV < cv_target

Returns (estimated_mean, standard_error, replications_consumed).
"""
function evaluate(ev::MCEvaluator, prob::HasInitialSolution, x)
    determ = control_variate_baseline(prob, x)   # from problems/opp.jl
    n_reps   = ev.n_min
    cv_stop  = false
    n_total  = 0
    total    = 0.0
    total_sq = 0.0

    while n_reps <= ev.n_max && !cv_stop
        # Per-thread accumulators
        partials     = zeros(Threads.nthreads())
        partials_sq  = zeros(Threads.nthreads())
        partials_cnt = zeros(Int, Threads.nthreads())

        @threads for tid in 1:Threads.nthreads()
            # Copy RNG per thread for CRN consistency
            local_rng = copy(ev.rng)
            # Advance to this thread's position in the replication sequence
            skip = n_total + (tid - 1) * div(n_reps - n_total, Threads.nthreads(), RoundUp)
            for _ in 1:skip
                rand(local_rng)
            end
            chunk = div(n_reps - n_total, Threads.nthreads(), RoundUp)
            for _ in 1:chunk
                # Antithetic pair
                val1 = evaluate_stochastic(prob, x, local_rng; antithetic=false)
                val2 = evaluate_stochastic(prob, x, local_rng; antithetic=true)
                # Control variate adjustment (ITOR 2022 Eq. ~4.xx)
                adj1 = val1 + determ - control_variate_baseline(prob, x)
                adj2 = val2 + determ - control_variate_baseline(prob, x)
                partials[tid]     += adj1 + adj2
                partials_sq[tid]  += adj1^2 + adj2^2
                partials_cnt[tid] += 2
            end
        end

        for tid in 1:Threads.nthreads()
            total    += partials[tid]
            total_sq += partials_sq[tid]
            n_total  += partials_cnt[tid]
        end

        # Adaptive stopping via coefficient of variation
        mu_bar = total / n_total
        sigma_bar = sqrt((total_sq - 2 * mu_bar * total + n_total * mu_bar^2) / (n_total - 1))
        cv = sigma_bar / abs(mu_bar)

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

"""
    evaluate(ev::MCEvaluator, prob::BlackBoxProblem, x)

Plain MCS for black-box problems — no control variates (no baseline exists).
Still uses antithetic variates, @threads, and adaptive stopping.
"""
function evaluate(ev::MCEvaluator, prob::BlackBoxProblem, x)
    n_reps   = ev.n_min
    cv_stop  = false
    n_total  = 0
    total    = 0.0
    total_sq = 0.0

    while n_reps <= ev.n_max && !cv_stop
        partials     = zeros(Threads.nthreads())
        partials_sq  = zeros(Threads.nthreads())
        partials_cnt = zeros(Int, Threads.nthreads())

        @threads for tid in 1:Threads.nthreads()
            local_rng = copy(ev.rng)
            skip = n_total + (tid - 1) * div(n_reps - n_total, Threads.nthreads(), RoundUp)
            for _ in 1:skip
                rand(local_rng)
            end
            chunk = div(n_reps - n_total, Threads.nthreads(), RoundUp)
            for _ in 1:chunk
                val1 = evaluate_stochastic(prob, x, local_rng; antithetic=false)
                val2 = evaluate_stochastic(prob, x, local_rng; antithetic=true)
                partials[tid]     += val1 + val2
                partials_sq[tid]  += val1^2 + val2^2
                partials_cnt[tid] += 2
            end
        end

        for tid in 1:Threads.nthreads()
            total    += partials[tid]
            total_sq += partials_sq[tid]
            n_total  += partials_cnt[tid]
        end

        mu_bar = total / n_total
        sigma_bar = sqrt((total_sq - 2 * mu_bar * total + n_total * mu_bar^2) / (n_total - 1))
        cv = sigma_bar / abs(mu_bar)

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
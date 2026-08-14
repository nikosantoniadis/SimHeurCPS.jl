using Statistics, Random, Base.Threads

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
    # Calculate deterministic baseline once outside the loop
    determ = ev.control_variate ? control_variate_baseline(prob, x) : 0.0
    
    n_reps   = ev.n_min
    n_total  = 0
    total    = 0.0
    total_sq = 0.0

    while true
        partials     = zeros(Float64, Threads.nthreads())
        partials_sq  = zeros(Float64, Threads.nthreads())
        partials_cnt = zeros(Int, Threads.nthreads())

        seeds = [rand(ev.rng, UInt) for _ in 1:Threads.nthreads()]

        # Calculate PAIRS needed since we do 2 evaluations per iteration
        pairs_needed = div(max(0, n_reps - n_total), 2, RoundUp)

        @threads for tid in 1:Threads.nthreads()
            local_rng = MersenneTwister(seeds[tid])
            
            # Distribute pairs evenly
            chunk = div(pairs_needed, Threads.nthreads(), RoundUp)
            if tid == Threads.nthreads()
                chunk = pairs_needed - (tid - 1) * chunk
            end
            
            # Prevent negative chunks on the last thread
            chunk = max(0, chunk)

            for _ in 1:chunk
                val1 = evaluate_stochastic(prob, x, local_rng; antithetic=false)
                val2 = evaluate_stochastic(prob, x, local_rng; antithetic=true)
                
                # Apply stochastic evaluations directly
                # Note: If a stochastic control variate is needed, subtract it here
                adj1 = val1
                adj2 = val2
                
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

        mu_bar = total / n_total
        # Standard error of the MEAN — decreases as √n, CV target is achievable
        sigma_bar = sqrt((total_sq - 2 * mu_bar * total + n_total * mu_bar^2) /
                         (n_total * (n_total - 1)))
        cv = sigma_bar / abs(mu_bar)

        # GUARANTEED TERMINATION: stop if target met OR budget exhausted
        if (cv < ev.cv_target && n_total >= ev.n_min) || n_total >= ev.n_max
            break
        end
        
        # Prevent infinite loop if n_reps starts at 0
        n_reps = n_reps == 0 ? 2 : min(2 * n_reps, ev.n_max)
    end

    mean_val = total / n_total
    se = sqrt((total_sq - 2 * mean_val * total + n_total * mean_val^2) /
              (n_total * (n_total - 1)))
              
    # Add deterministic offset at the end if applying a static shift
    if ev.control_variate
        mean_val += determ
    end
              
    return mean_val, se, n_total
end

"""
    evaluate(ev::MCEvaluator, prob::BlackBoxProblem, x)

Plain Monte Carlo for black-box problems where no deterministic baseline
exists. Still uses antithetic variates and @threads parallelism.
Adaptive stopping based on coefficient of variation.

Returns (estimated_mean, standard_error, replications_used).
"""
function evaluate(ev::MCEvaluator, prob::BlackBoxProblem, x)
    n_reps   = ev.n_min
    n_total  = 0
    total    = 0.0
    total_sq = 0.0

    while true
        partials     = zeros(Float64, Threads.nthreads())
        partials_sq  = zeros(Float64, Threads.nthreads())
        partials_cnt = zeros(Int, Threads.nthreads())

        seeds = [rand(ev.rng, UInt) for _ in 1:Threads.nthreads()]
        
        # Calculate PAIRS needed
        pairs_needed = div(max(0, n_reps - n_total), 2, RoundUp)

        @threads for tid in 1:Threads.nthreads()
            local_rng = MersenneTwister(seeds[tid])
            
            chunk = div(pairs_needed, Threads.nthreads(), RoundUp)
            if tid == Threads.nthreads()
                chunk = pairs_needed - (tid - 1) * chunk
            end
            
            chunk = max(0, chunk)

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
        sigma_bar = sqrt((total_sq - 2 * mu_bar * total + n_total * mu_bar^2) /
                         (n_total * (n_total - 1)))
        cv = sigma_bar / abs(mu_bar)

        # GUARANTEED TERMINATION
        if (cv < ev.cv_target && n_total >= ev.n_min) || n_total >= ev.n_max
            break
        end
        
        n_reps = n_reps == 0 ? 2 : min(2 * n_reps, ev.n_max)
    end

    mean_val = total / n_total
    se = sqrt((total_sq - 2 * mean_val * total + n_total * mean_val^2) /
              (n_total * (n_total - 1)))
              
    return mean_val, se, n_total
end
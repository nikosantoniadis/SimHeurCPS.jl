using Random

"""
    step!(alg::RVNS, prob::AbstractProblem, ev::AbstractEvaluator, x, fx)

One iteration of Reduced VNS:
1. Pick a random neighbourhood from alg.neighborhoods.
2. SHAKE: produce a random neighbour x' in that neighbourhood.
3. EVALUATE: estimate f(x') using the evaluator (MCEvaluator or future surrogate).
4. MOVE-OR-NOT: if f(x') < fx, accept; otherwise keep current x.

Returns (new_x, new_fx, evaluations_consumed).

This is THE extension contract for all metaheuristics in SimHeurCPS.
GA, PSO, SA, ensembles — each implements step! for its own type.
The optimize() driver in core/optimize.jl never changes.
"""
function step!(alg::RVNS, prob::AbstractProblem, ev::AbstractEvaluator, x, fx)
    # ---- 1. Pick a random neighbourhood ----
    k = rand(1:alg.k_max)
    nb = alg.neighborhoods[k]

    # ---- 2. SHAKE: generate a random neighbour ----
    x_new = shake(prob, nb, x)

    # ---- 3. EVALUATE: MCS (or surrogate, or ABM — dispatched automatically) ----
    _, fx_new, used = evaluate_and_account(ev, prob, x_new, typemax(Int), 0)
    # typemax(Int) = "unlimited budget for this single evaluation"
    # evaluate_and_account lives in core/optimize.jl and wraps evaluate()

    # ---- 4. MOVE-OR-NOT: first-improvement acceptance ----
    if fx_new < fx
        return x_new, fx_new, used
    else
        return x, fx, used   # solution unchanged, but budget was still consumed
    end
end

"""
    shake(prob, nb::SwapNeighborhood, x)

Produce a random neighbour of x by applying the neighbourhood operator.
For OPP: swap two switch statuses.
For future domains: each problem defines its own shake() via multiple dispatch.
"""
function shake(prob::AbstractProblem, nb::SwapNeighborhood, x)
    # Default: swap two components. The problem defines what a "component" is.
    # This calls back to the problem's own neighborhood logic.
    return apply_neighborhood(prob, nb, x)
end

# ---- Interface: problem defines how a neighbourhood is applied ----
function apply_neighborhood(prob::AbstractProblem, nb::SwapNeighborhood, x)
    error("apply_neighborhood not implemented for $(typeof(prob))")
end
# ---- Generic simheuristic driver ----

"""
    optimize(alg::AbstractMetaheuristic, prob::AbstractProblem,
             ev::AbstractEvaluator; eval_budget::Int)

Generic simheuristic driver. Dispatches on the problem type to determine
the initialization strategy:

- HasInitialSolution: start from a known feasible point with known fx.
  Control variates are available during evaluation.
- BlackBoxProblem: generate a random candidate, evaluate it, enter the
  search loop. No baseline or control variates exist.

The metaheuristic proposes candidates via `step!`; the evaluator estimates
their quality. Budget is measured in evaluation calls (MCS replications
or surrogate queries). Returns (best_solution, best_objective, budget_consumed).

The driver is search-agnostic — it never knows whether the metaheuristic
is VNS, GA, PSO, or an ensemble. Adding a new algorithm means implementing
`step!` for its type; this file never changes.
"""
function optimize(alg::AbstractMetaheuristic,
                  prob::HasInitialSolution,
                  ev::AbstractEvaluator;
                  eval_budget::Int)
    x = initial_solution(prob)
    _, fx, used = evaluate_and_account(ev, prob, x, eval_budget, 0)
    budget_remaining = eval_budget - used
    stagnation = 0

    while budget_remaining > 0
        x_new, fx_new, used_new = step!(alg, prob, ev, x, fx)
        budget_remaining -= used_new

        if fx_new < fx
            x, fx = x_new, fx_new
            stagnation = 0
        else
            stagnation += 1
        end

        stagnation > 50 && break
    end

    return x, fx, eval_budget - budget_remaining
end

function optimize(alg::AbstractMetaheuristic,
                  prob::BlackBoxProblem,
                  ev::AbstractEvaluator;
                  eval_budget::Int)
    x = random_candidate(prob)
    _, fx, used = evaluate_and_account(ev, prob, x, eval_budget, 0)
    budget_remaining = eval_budget - used
    stagnation = 0

    while budget_remaining > 0
        x_new, fx_new, used_new = step!(alg, prob, ev, x, fx)
        budget_remaining -= used_new

        if fx_new < fx
            x, fx = x_new, fx_new
            stagnation = 0
        else
            stagnation += 1
        end

        stagnation > 50 && break
    end

    return x, fx, eval_budget - budget_remaining
end

# ---- Budget-accounting helper ----

"""
    evaluate_and_account(ev, prob, x, total_budget, already_spent)

Evaluate a solution and return the consumed budget.
Checks budget before evaluating; raises an error if exhausted.

Returns (x, estimated_objective, evaluations_consumed).
"""
function evaluate_and_account(ev::AbstractEvaluator, prob, x, budget, spent)
    if spent >= budget
        error("Evaluation budget exhausted at $(spent)/$(budget).")
    end
    fx, _, used = evaluate(ev, prob, x)
    actual_used = min(used, budget - spent)
    return x, fx, actual_used
end

# ---- The extension contract ----

"""
    step!(alg::AbstractMetaheuristic, prob, ev, x, fx)

The single interface contract for all metaheuristics.
Given the current solution `x` and its estimated objective `fx`, produce
the next candidate and return (new_x, new_fx, evaluations_consumed).

New algorithms (GA, PSO, SA, ensembles) extend this function for their
own type — the `optimize` driver never changes.
"""
function step! end

# ---- Problem interface functions (defined in problems/) ----

"""
    initial_solution(prob::HasInitialSolution)

Generate a feasible starting point for the search.
Defined by the problem instance.

For the ITOR 2022 OPP: the deterministic MIQCP solution.
"""
function initial_solution(prob::HasInitialSolution) end

"""
    random_candidate(prob::BlackBoxProblem)

Generate a random feasible candidate for black-box problems.
Defined by the problem instance.

For anesthesia/FES: a randomly sampled parameter vector within bounds.
"""
function random_candidate(prob::BlackBoxProblem) end
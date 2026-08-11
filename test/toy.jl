using SimHeurCPS
using Random

# A toy problem: minimize f(x) = sum((x .- 0.5).^2) on [0,1]^n, with noise
struct ToyProblem <: HasInitialSolution
    n::Int
    noise_std::Float64
end

# A toy evaluator: plain MCS, fixed reps, no variance reduction
struct ToyEvaluator <: AbstractEvaluator
    n_reps::Int
    rng::Random.AbstractRNG
end

function SimHeurCPS.evaluate(ev::ToyEvaluator, prob::ToyProblem, x)
    total = 0.0
    for _ in 1:ev.n_reps
        noise = randn(ev.rng) * prob.noise_std
        total += sum((x .- 0.5).^2) + noise
    end
    return total / ev.n_reps, 0.0, ev.n_reps
end

function SimHeurCPS.initial_solution(prob::ToyProblem)
    return rand(prob.n)
end

# Toy RVNS: shake = random perturbation, step! = accept if better
struct ToyRVNS <: AbstractMetaheuristic
    step_size::Float64
    rng::Random.AbstractRNG
end

function SimHeurCPS.step!(alg::ToyRVNS, prob, ev, x, fx)
    x_new = x .+ (rand(alg.rng, length(x)) .- 0.5) .* alg.step_size
    x_new = clamp.(x_new, 0.0, 1.0)
    _, fx_new, used = SimHeurCPS.evaluate_and_account(ev, prob, x_new, typemax(Int), 0)
    if fx_new < fx
        return x_new, fx_new, used
    else
        return x, fx, used
    end
end

# ---- RUN ----
prob = ToyProblem(5, 0.01)
ev = ToyEvaluator(100, Random.MersenneTwister(42))
alg = ToyRVNS(0.1, Random.MersenneTwister(123))

x_best, fx_best, budget = SimHeurCPS.optimize(alg, prob, ev; eval_budget=1000)
println("Best: f(x) ≈ $fx_best at x ≈ $(round.(x_best, digits=3))")
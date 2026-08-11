# ---- Abstract contracts (core knows NOTHING about specific algorithms) ----

abstract type AbstractProblem end
abstract type HasInitialSolution <: AbstractProblem end
abstract type BlackBoxProblem <: AbstractProblem end

abstract type AbstractEvaluator end
abstract type AbstractMetaheuristic end

struct MCEvaluator <: AbstractEvaluator
    n_min::Int
    n_max::Int
    cv_target::Float64
    antithetic::Bool
    control_variate::Bool
    rng::Random.AbstractRNG
end
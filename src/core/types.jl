# ---- Abstract contracts (core knows NOTHING about specific algorithms) ----

abstract type AbstractProblem end
abstract type HasInitialSolution <: AbstractProblem end
abstract type BlackBoxProblem <: AbstractProblem end

abstract type AbstractEvaluator end
abstract type AbstractMetaheuristic end
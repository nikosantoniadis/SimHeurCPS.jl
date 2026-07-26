# SimHeurCPS.jl

A simheuristic framework for robust, explainable optimisation of safety-critical cyber-physical systems.

SimHeurCPS couples metaheuristic search with adaptive Monte Carlo simulation — including control variates and antithetic variates for variance reduction — to solve stochastic combinatorial optimisation problems under uncertainty. The architecture is modular and algorithm-agnostic: RVNS is the first search engine, with GA, PSO, and ensemble metaheuristics arriving via multiple dispatch. 
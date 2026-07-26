# ---- Concrete VNS types (defined HERE, not in core) ----
# The core knows nothing about neighborhoods, shaking, or k_max.
# These are VNS-internal concerns.

"""
    SwapNeighborhood
A neighbourhood defined by swapping two components of the solution.
For OPP: swapping the status (open/closed) of two switches.
Other problems define their own neighbourhoods.
"""
struct SwapNeighborhood
    # Problem-specific parameters live here.
    # For OPP: the two switch indices to swap.
    i::Int
    j::Int
end

"""
    RVNS <: AbstractMetaheuristic
Reduced Variable Neighborhood Search.
- Shakes the current solution in a *random* neighbourhood at each iteration.
- Accepts only improvements (first-improvement not best-improvement).
- k_max is the number of available neighbourhoods (not a classic VNS k_max —
  classic RVNS has no k_max; this parameter bounds the shaking radius).

Implements the `step!` contract: given (x, fx), produce (x_new, fx_new, evaluations_consumed).
"""
struct RVNS <: AbstractMetaheuristic
    neighborhoods::Vector{SwapNeighborhood}
    k_max::Int   # number of neighbourhoods available (shaking picks one at random)
end
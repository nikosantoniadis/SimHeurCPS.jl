# ---- ITOR 2022 Overloading Prevention Problem ----
# This is the VALIDATION TARGET: numerical results must match ITOR 2022
# within 1% [10].

"""
    OPPProblem <: HasInitialSolution

The Overloading Prevention Problem from ITOR 2022.
- Network: real Creos Luxembourg distribution topology [5][6]
- Decision: switch statuses (reconfiguration) + load curtailment
- Uncertainty: stochastic load and generation profiles (24-hour, 1-hour steps)
- Baseline: deterministic MIQCP solution from Gurobi (used as control variate)
- Objective: minimize reliability index (SAIDI-weighted overload probability)

HasInitialSolution because we have a known starting configuration
(opening all switches = radial operation) and the MIQCP baseline.
"""
struct OPPProblem <: HasInitialSolution
    # ---- Network topology ----
    n_buses::Int
    n_lines::Int
    n_switches::Int
    adjacency::Matrix{Int}           # line connectivity
    line_impedance::Vector{Float64}

    # ---- Load/generation profiles (24 hours) ----
    load_profiles::Matrix{Float64}   # (n_buses × 24) — hourly stochastic loads
    gen_profiles::Matrix{Float64}    # (n_buses × 24) — hourly stochastic generation

    # ---- MIQCP baseline (control variate) ----
    miqcp_solution::Vector{Int}      # switch statuses from Gurobi
    miqcp_objective::Float64         # deterministic objective value

    # ---- Uncertainty parameters ----
    load_std::Float64                # standard deviation of load noise
    gen_std::Float64                 # standard deviation of generation noise
end

# ---- Problem interface functions ----

"""
    initial_solution(prob::OPPProblem)

Starting point: all switches OPEN (radial configuration, no reconfiguration).
This is a feasible but likely suboptimal starting solution.
"""
function initial_solution(prob::OPPProblem)
    return zeros(Int, prob.n_switches)  # all switches open
end

"""
    control_variate_baseline(prob::OPPProblem, x)

The deterministic MIQCP objective value — used as the control variate.
From ITOR 2022: the MIQCP solves the same reconfiguration problem without
stochasticity, providing a cheap, correlated baseline.
"""
function control_variate_baseline(prob::OPPProblem, x)
    # The MIQCP baseline is pre-computed and stored in the problem struct.
    # In ITOR 2022, the control variate formula adjusts each stochastic
    # evaluation by the difference between the MIQCP value at x and the
    # mean MIQCP value across the search. Here we return the MIQCP value.
    return prob.miqcp_objective
end

"""
    evaluate_stochastic(prob::OPPProblem, x, rng; antithetic=false)

A single replication of the stochastic simulation.
Given a switch configuration x:
1. Sample stochastic loads and generation for each bus at each hour
2. Run power flow (or approximate — ITOR 2022 used a linearized DC power flow)
3. Check for overloads on each line
4. Compute the reliability index (SAIDI-weighted overload probability)

antithetic=true: mirror the random draws (negate the noise component)
to produce a negatively correlated partner replication.
"""
function evaluate_stochastic(prob::OPPProblem, x, rng::AbstractRNG; antithetic::Bool=false)
    total_overload_hours = 0.0
    n_samples = 24  # 24 hours

    for h in 1:n_samples
        for bus in 1:prob.n_buses
            # Sample stochastic load for this bus/hour
            load_mean = prob.load_profiles[bus, h]
            noise = randn(rng) * prob.load_std
            if antithetic
                noise = -noise
            end
            load = max(0.0, load_mean + noise)

            # Sample stochastic generation
            gen_mean = prob.gen_profiles[bus, h]
            noise_gen = randn(rng) * prob.gen_std
            if antithetic
                noise_gen = -noise_gen
            end
            gen = max(0.0, gen_mean + noise_gen)

            # ---- Power flow (simplified for outline) ----
            # In ITOR 2022: DC power flow on the reconfigured network.
            # For each line, compute power flow and check against capacity.
            # If flow > capacity, increment overload counter.
            # (Full implementation reads network topology, applies switch
            #  configuration x, runs power flow, checks constraints.)
        end
    end

    # SAIDI-weighted overload probability (ITOR 2022, Section 4)
    return total_overload_hours / n_samples
end

"""
    apply_neighborhood(prob::OPPProblem, nb::SwapNeighborhood, x)

Apply a swap neighbourhood: toggle the status of two switches.
Called by shake() in vns/step.jl.
"""
function apply_neighborhood(prob::OPPProblem, nb::SwapNeighborhood, x::Vector{Int})
    x_new = copy(x)
    # Swap: if switch i is open and j is closed, close i and open j
    x_new[nb.i], x_new[nb.j] = x_new[nb.j], x_new[nb.i]
    return x_new
end
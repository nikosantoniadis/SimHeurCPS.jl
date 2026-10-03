# SimHeurCPS.jl — Archived

This repository was an early exploration of the SimHeurCPS architecture in Julia.

**The actively maintained, peer-reviewed version is implemented in C++20:**

→ [github.com/nikosantoniadis/SimHeurCPS](https://github.com/nikosantoniadis/SimHeurCPS) *(will be public upon paper acceptance)*

The C++ version retains the same modular architecture, adds deterministic timing, OpenMP parallelism, and static memory allocation for safety-critical CPS deployment.

**Why the language change?** Safety-critical cyber-physical systems require deterministic execution and a regulatory certification path — constraints that Julia's JIT compiler cannot satisfy. C++20 resolves this while maintaining high-level expressiveness through compile-time polymorphism.

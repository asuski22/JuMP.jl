#  Copyright 2017, Iain Dunning, Joey Huchette, Miles Lubin, and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

# These methods directly map to CachingOptimizer methods.
# They cannot be called in Direct mode.
function MOIU.resetoptimizer!(model::Model, optimizer::MOI.AbstractOptimizer)
    @assert mode(model) != Direct
    MOIU.resetoptimizer!(caching_optimizer(model), optimizer)
end

function MOIU.resetoptimizer!(model::Model)
    @assert mode(model) != Direct
    MOIU.resetoptimizer!(caching_optimizer(model))
end

function MOIU.dropoptimizer!(model::Model)
    @assert mode(model) != Direct
    MOIU.dropoptimizer!(caching_optimizer(model))
end

function MOIU.attachoptimizer!(model::Model)
    @assert mode(model) != Direct
    MOIU.attachoptimizer!(caching_optimizer(model))
end


"""
    optimize!(model::Model,
              optimizer_factory::Union{Nothing, OptimizerFactory}=nothing;
              ignore_optimize_hook=(model.optimize_hook === nothing))

Optimize the model. If `optimizer_factory` is not `nothing`, it first sets the
optimizer to a new one created using the optimizer factory. The factory can be
created using the [`with_optimizer`](@ref) function.

## Examples

```julia
model = Model()
# ...fill model with variables, constraints and objectives...
# Solve the model with GLPK
JuMP.optimize!(model, with_optimizer(GLPK.Optimizer))
# Solve the model with Clp
JuMP.optimize!(model, with_optimizer(Clp.Optimizer))
```
"""
function optimize!(model::Model,
                   optimizer_factory::Union{Nothing, OptimizerFactory}=nothing;
                   ignore_optimize_hook=(model.optimize_hook === nothing))
    # The nlp_data is not kept in sync, so re-set it here.
    # TODO: Consider how to handle incremental solves.
    if model.nlp_data !== nothing
        MOI.set(model, MOI.NLPBlock(), create_nlp_block_data(model))
        empty!(model.nlp_data.nlconstr_duals)
    end

    if optimizer_factory !== nothing
        if mode(model) == Direct
            error("An optimizer factory cannot be provided at the `optimize` call in Direct mode.")
        end
        if MOIU.state(caching_optimizer(model)) != MOIU.NoOptimizer
            error("An optimizer factory cannot both be provided in the `Model` constructor and at the `optimize` call.")
        end
        optimizer = optimizer_factory()
        MOIU.resetoptimizer!(model, optimizer)
        MOIU.attachoptimizer!(model)
    end

    # If the user or an extension has provided an optimize hook, call
    # that instead of solving the model ourselves
    if !ignore_optimize_hook
        return model.optimize_hook(model)
    end

    MOI.optimize!(model.moi_backend)

    return
end

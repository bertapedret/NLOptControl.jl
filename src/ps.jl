"""
n = DMatrix!(n)
n = DMatrix!(n, (:mode=>:symbolic))
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 1/15/2017, Last Modified: 12/06/2019 \n
--------------------------------------------------------------------------------------\n
"""
function DMatrix!(n::NLOpt, kwargs...)         #TODO make IMatrix and option

    kw = Dict(kwargs)

    if !haskey(kw,:mode)
        mode = :defaut
    else
        mode = get(kw,:mode,0)
    end

    if mode == :defaut

        check_ts = maximum.(n.ocp.ts)

        if maximum(check_ts) < 10 * eps()
            error("""
                ts is full of zeros: make sure that you call create_intervals() first to calculate ts!
                NOTE: This may have occured because  (:finalTimeDV => true) and the final time dv is not working properly!!
                """)
        end

        D = [ zeros((n.ocp.Nck[int]+1),(n.ocp.Nck[int]+1)) for int in 1:n.ocp.Ni ]

        for int in 1:n.ocp.Ni
            D[int] = polyDiff(n.ocp.ts[int]) # +1 is already appended onto ts
        end

        n.ocp.DMatrix = [zeros((n.ocp.Nck[int]),(n.ocp.Nck[int]+1)) for int in 1:n.ocp.Ni]
        DM = [zeros((n.ocp.Nck[int]),(n.ocp.Nck[int])) for int in 1:n.ocp.Ni]
        n.ocp.IMatrix = [zeros((n.ocp.Nck[int]),(n.ocp.Nck[int]+1)) for int in 1:n.ocp.Ni]

        for int in 1:n.ocp.Ni
            n.ocp.DMatrix[int] = D[int][1:end-1,:]      # [Nck]X[Nck+1]
            if n.s.ocp.integrationScheme == :lgrImplicit
                DM[int] = n.ocp.DMatrix[int][:,2:end]   # [Nck]X[Nck]
                n.ocp.IMatrix[int] = inv(DM[int])       # I = inv(D[:,2:N_k+1])
            end
        end

    elseif mode == :symbolic # for validation only, too slow otherwise
        error("""
            Cannot precompile with SymPy
            so this fucntion was turned off for typical use!!
            -> do a (using SymPy) in NLOptControl.jl then remove this error message and rerun
            """)
        Dsym = [Array{Any}(undef, n.ocp.Nck[int],n.ocp.Nck[int]+1) for int in 1:n.ocp.Ni];
        n.ocp.DMatrix = [Array{Any}(undef, n.ocp.Nck[int],n.ocp.Nck[int]+1) for int in 1:n.ocp.Ni]
        test = [Array{Any}(undef, n.ocp.Nck[int]+1) for int in 1:n.ocp.Ni];
        val = 1; # since this is always = 1 this funtion is useful for testing, without scaling the problem from [-1,1] this was useful becuase tf was a design variable
        tf = Sym("tf")
        createIntervals!(n, tf); # gives symbolic expression
        for int in 1:n.ocp.Ni
            for i in 1:n.ocp.Nck[int]+1
                test[int][i] =  n.ocp.ts[int][i](tf=>val)
            end
        end
        for int in 1:n.ocp.Ni
            for idx in 1:n.ocp.Nck[int]+1
                for j in 1:n.ocp.Nck[int]
                    f = lagrange_basis_poly(tf, test[int], idx)
                    Dsym[int][j,idx] = diff(f,tf) # symbolic differentiation --> slow but useful # TODO include this in test functions
                    n.ocp.DMatrix[int][j,idx] = Dsym[int][j,idx](tf=>test[int][j])
                end
            end
        end
    end
    nothing
end



"""
n = create_intervals(n)
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 12/23/2017, Last Modified: 12/06/2019 \n
--------------------------------------------------------------------------------------\n
"""
function createIntervals!(n::NLOpt)
    tm = range(-1,1;length=n.ocp.Ni+1)     # create mesh points
    di = 2/n.ocp.Ni                           # interval size
    # go through each mesh interval creating time intervals; map [tm[i-1],tm[i]] --> [-1,1]
    n.ocp.ts = hcat([ [ scale_tau(n.ocp.tau[int],tm[int],tm[int+1]) ; di*int-1 ] for int in 1:n.ocp.Ni ]...)
    n.ocp.ws = hcat([ scale_w(n.ocp.w[int],tm[int],tm[int+1]) for int in 1:n.ocp.Ni ]...)
    return nothing
end


# NOTE this function was used for testing, but is currently depreciated. When it is used again figure out why and explain why
# di = (tf + 1).n.ocp.Ni
function createIntervals!(n::NLOpt, tf)
    tm = range(-1,1; length=n.ocp.Ni+1)       # create mesh points
    di = (tf + 1)/n.ocp.Ni                      # interval size
    # go through each mesh interval creating time intervals; map [tm[i-1],tm[i]] --> [-1,1]
    n.ocp.ts = hcat([ [scale_tau(n.ocp.tau[int],tm[int],tm[int+1]) ; di*int-1 ] for int in 1:n.ocp.Ni]...)
    n.ocp.ws = hcat([ scale_w(n.ocp.w[int],tm[int],tm[int+1]) for int in 1:n.ocp.Ni]...)
    return nothing
end



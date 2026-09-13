module FixtureModule

export interface_function, interface_only, overloaded, passthrough, transform_data, type_marker, undocumented
public public_function

"""
    transform_data(data::Vector{Float64}, scale::Real=1.0; quiet=false, label="", required)

Scale the supplied data and attach caller-controlled metadata.

# Arguments

- `data`: Numeric values to transform.
- `scale`: Multiplicative scale applied to each value.

# Keywords

- `quiet`: Whether to suppress progress output.
- `label`: Label associated with the transformed values.
- `required`: Required caller-provided metadata.
- `kwargs`: Additional metadata forwarded by the operation.

# Returns

A scaled vector.
"""
function transform_data(
	data::Vector{Float64},
	scale::Real=1.0;
	quiet::Bool=false,
	label::AbstractString="",
	required,
	kwargs...,
)::Vector{Float64}
	quiet
	label
	required
	kwargs
	return data .* scale
end

passthrough(values::T...; limit::Int=2) where {T<:Real} = values[1:min(end, limit)]

"""
Return a value after dispatching on its anonymous type marker.

# Arguments

- `value`: Value to return.

# Returns

The supplied value.
"""
type_marker(::Type{T}, value::T)::T where {T} = value

undocumented(x, y=2; flag, mode::Symbol=:fast) = flag ? (x, y, mode) : nothing

"""
Return an integer value.

# Arguments

- `value`: Integer value to return.

# Returns

The supplied integer.
"""
overloaded(value::Int)::Int = value

"""
Return a string with caller-selected handling.

# Arguments

- `value`: String value to return.

# Keywords

- `mode`: Required handling mode.

# Returns

The supplied string.
"""
overloaded(value::AbstractString; mode)::String = String(value)

"""
    interface_function(value)

Return a value through an extensible interface.

# Arguments

- `value`: Value to return.

# Returns

The supplied value.
"""
function interface_function end

interface_function(value::Int)::Int = value

"""
    interface_only

Declare a methodless extension point.

# Returns

A generic function to which downstream packages may add methods.
"""
function interface_only end

"""
Return the supplied integer.
"""
function public_function(value::Int)::Int
	return value
end

module NestedA

export repeated

repeated(value::Int)::Int = value

end


module NestedB

repeated(value::AbstractString)::String = String(value)

end

end

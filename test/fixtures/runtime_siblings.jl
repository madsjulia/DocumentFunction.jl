module ScanSiblingA

foo(value::Int)::Int = value

end


module ScanSiblingB

foo(value::AbstractString)::String = String(value)

end

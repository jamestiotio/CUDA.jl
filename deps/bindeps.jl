# discovering binary CUDA dependencies

using CompilerSupportLibraries_jll
using LazyArtifacts
import Libdl

const dependency_lock = ReentrantLock()

# lazily initialize a Ref containing a path to a library.
# the arguments to this macro is the name of the ref, an expression to populate it
# (possibly returning `nothing` if the library wasn't found), and an optional initialization
# hook to be executed after successfully discovering the library and setting the ref.
macro initialize_ref(ref, ex, hook=:())
    quote
        ref = $ref

        # test and test-and-set
        if !isassigned(ref)
            Base.@lock dependency_lock begin
                if !isassigned(ref)
                    val = $ex
                    if val === nothing && !(eltype($ref) <: Union{Nothing,<:Any})
                        error($"Could not find a required library")
                    end
                    $ref[] = val
                    if val !== nothing
                        $hook
                    end
                end
            end
        end

        $ref[]
    end
end


#
# CUDA toolkit
#

export toolkit

abstract type AbstractToolkit end

struct ArtifactToolkit <: AbstractToolkit
    release::VersionNumber
    artifact::String
end

struct LocalToolkit <: AbstractToolkit
    release::VersionNumber  # approximate, from `ptxas --version`
    dirs::Vector{String}
end

const __toolkit = Ref{AbstractToolkit}()

function toolkit()
    @initialize_ref __toolkit begin
        toolkit = nothing

        # CI runs in a well-defined environment, so prefer a local CUDA installation there
        if getenv("CI", false) && !haskey(ENV, "JULIA_CUDA_USE_BINARYBUILDER")
            toolkit = find_local_cuda()
        end

        if toolkit === nothing && getenv("JULIA_CUDA_USE_BINARYBUILDER", true)
            toolkit = find_artifact_cuda()
        end

        # if the user didn't specifically request an artifact version, look for a local installation
        if toolkit === nothing && !haskey(ENV, "JULIA_CUDA_VERSION")
            toolkit = find_local_cuda()
        end

        if toolkit === nothing
            error("Could not find a suitable CUDA installation")
        end

        toolkit
    end CUDA.__init_toolkit__()
    __toolkit[]::Union{ArtifactToolkit,LocalToolkit}
end

# workaround @artifact_str eagerness on unsupported platforms by passing a variable
function cuda_artifact(id, cuda::VersionNumber)
    platform = Base.BinaryPlatforms.HostPlatform()
    platform.tags["cuda"] = "$(cuda.major).$(cuda.minor)"

    dir = try
        @artifact_str(id, platform)
    catch ex
        @debug "Could not load artifact '$id' for CUDA $(cuda.release)" exception=(ex,catch_backtrace())
        return nothing
    end

    # sometimes artifact downloads fail (e.g. JuliaGPU/CUDA.jl#1003)
    if isempty(readdir(dir))
        error("""The artifact at $dir is empty.
                 This is probably caused by a failed download. Remove the directory and try again.""")
    end

    return dir
end

# NOTE: we don't use autogenerated JLLs, because we have multiple artifacts and need to
#       decide at run time (i.e. not via package dependencies) which one to use.
const cuda_toolkits = [
    (release=v"11.4", preferred=true),
    (release=v"11.3", preferred=true),
    (release=v"11.2", preferred=true),
    (release=v"11.1", preferred=true),
    (release=v"11.0", preferred=true),
    (release=v"10.2", preferred=true),
    (release=v"10.1", preferred=true),
    (release=v"10.0", preferred=true),
    (release=v"9.0",  preferred=true),
    (release=v"9.2",  preferred=true),
]

function find_artifact_cuda()
    @debug "Trying to use artifacts..."

    # select compatible artifacts
    if haskey(ENV, "JULIA_CUDA_VERSION")
        wanted = VersionNumber(ENV["JULIA_CUDA_VERSION"])   # misnomer: actually the release
        @debug "Selecting artifacts based on requested $wanted"
        candidate_toolkits = filter(cuda_toolkits) do toolkit
            toolkit.release == wanted
        end
        isempty(candidate_toolkits) && @debug "Requested CUDA release $wanted is not provided by any artifact"
    else
        driver_release = CUDA.release()
        @debug "Selecting artifacts based on driver compatibility $driver_release"
        candidate_toolkits = filter(cuda_toolkits) do toolkit
            toolkit.preferred &&
                (toolkit.release <= driver_release ||
                 # CUDA 11: Enhanced Compatibility (aka. semver)
                 (driver_release >= v"11" &&
                  toolkit.release.major <= driver_release.major))
        end
        isempty(candidate_toolkits) && @debug "CUDA driver compatibility $driver_release is not compatible with any artifact"
    end

    # download and install
    artifact = nothing
    for cuda in sort(candidate_toolkits; rev=true, by=toolkit->toolkit.release)
        dir = cuda_artifact("CUDA", cuda.release)
        if dir !== nothing
            artifact = (release=cuda.release, dir)
            break
        end
    end
    if artifact == nothing
        @debug "Could not find a compatible artifact."
        return nothing
    end

    @debug "Using CUDA $(artifact.release) from an artifact at $(artifact.dir)"
    return ArtifactToolkit(artifact.release, artifact.dir)
end

function find_local_cuda()
    @debug "Trying to use local installation..."

    dirs = find_toolkit()

    let path = find_cuda_binary("nvdisasm", dirs)
        if path === nothing
            @debug "Could not find nvdisasm"
            return nothing
        end
        __nvdisasm[] = path
    end

    let path = find_cuda_binary("ptxas", dirs)
        if path === nothing
            @debug "Could not find ptxas"
            return nothing
        end
        __ptxas[] = path
    end

    release = parse_toolkit_release("ptxas", __ptxas[])
    if release === nothing
        @debug "Could not parse the CUDA release number from the ptxas version output"
        return nothing
    end

    @debug "Found local CUDA $(release) at $(join(dirs, ", "))"
    return LocalToolkit(release, dirs)
end


## properties

export toolkit_origin, toolkit_release

"""
    toolkit_origin()

Returns the origin of the CUDA toolkit in use (either :artifact, or :local).
"""
toolkit_origin() = toolkit_origin(toolkit())::Symbol
toolkit_origin(::ArtifactToolkit) = :artifact
toolkit_origin(::LocalToolkit) = :local

"""
    toolkit_release()

Returns the CUDA release version of the toolkit in use.
"""
toolkit_release() = toolkit().release::VersionNumber


## binaries

export ptxas, nvlink, nvdisasm, compute_sanitizer, has_compute_sanitizer

# pxtas: used for compiling PTX to SASS
const __ptxas = Ref{String}()
function ptxas()
    @initialize_ref __ptxas begin
        find_binary(toolkit(), "ptxas")
    end
end

# nvlink: used for linking additional libraries
const __nvlink = Ref{String}()
function nvlink()
    @initialize_ref __nvlink begin
        find_binary(toolkit(), "nvlink")
    end
end

# nvdisasm: used for reflection (decompiling SASS code)
const __nvdisasm = Ref{String}()
function nvdisasm()
    @initialize_ref __nvdisasm begin
        find_binary(toolkit(), "nvdisasm")
    end
end

# compute-santizer: used by the test suite
const __compute_sanitizer = Ref{Union{Nothing,String}}()
function compute_sanitizer(throw_error::Bool=true)
    path = @initialize_ref __compute_sanitizer begin
        if toolkit_release() < v"11.0"
            nothing
        else
            find_binary(toolkit(), "compute-sanitizer"; optional=true)
        end
    end
    if path === nothing && throw_error
        error("This functionality is unavailabe as compute_sanitizer is missing.")
    end
    path
end
has_compute_sanitizer() = compute_sanitizer(throw_error=false) !== nothing

function artifact_binary(artifact_dir, name)
    path = joinpath(artifact_dir, "bin", Sys.iswindows() ? "$name.exe" : name)
    if !ispath(path)
        error("""Could not find binary '$name' in $artifact_dir!
                 This is a bug; please file an issue with a verbose directory listing of $artifact_dir
                 If this directory is empty, delete it and try again.""")
    end
    return path
end

function find_binary(cuda::ArtifactToolkit, name; optional=false)
    # NOTE: optional is ignored, and we'll error if not found
    artifact_binary(cuda.artifact, name)
end

function find_binary(cuda::LocalToolkit, name; optional=false)
    path = find_cuda_binary(name, cuda.dirs)
    if path !== nothing
        return path
    else
        optional || error("Could not find binary '$name' in your local CUDA installation.")
        return nothing
    end
end


## libraries

# XXX: we don't correctly model the dependencies of these libraries, and hack around them
#      by loading libcublasLt before libcublas, or CUDNN's sublibraries before libcudnn.
#      this is necessary (even if the dependent libraries are in the same directory)
#      to avoid a local toolkit from messing with our artifacts (JuliaGPU/CUDA.jl#609).

export libcublas, libcusparse, libcufft, libcurand, libcusolver,
       libcusolvermg, has_cusolvermg, libcupti, has_cupti, libnvtx, has_nvtx

const __libcublaslt = Ref{String}()
function libcublaslt()
    @initialize_ref __libcublaslt begin
        if toolkit_release() < v"10.1"
            nothing
        else
            find_library(toolkit(), "cublasLt")
        end
    end
end

const __libcublas = Ref{String}()
function libcublas()
    @initialize_ref __libcublas begin
        libcublaslt()
        find_library(toolkit(), "cublas")
    end CUDA.CUBLAS.__runtime_init__()
end

const __libcusparse = Ref{String}()
function libcusparse()
    @initialize_ref __libcusparse begin
        find_library(toolkit(), "cusparse")
    end
end

const __libcufft = Ref{String}()
function libcufft()
    @initialize_ref __libcufft begin
        find_library(toolkit(), "cufft")
    end
end

const __libcurand = Ref{String}()
function libcurand()
    @initialize_ref __libcurand begin
        find_library(toolkit(), "curand")
    end
end

const __libcusolver = Ref{String}()
function libcusolver()
    @initialize_ref __libcusolver begin
        find_library(toolkit(), "cusolver")
    end
end

const __libcusolverMg = Ref{Union{String,Nothing}}()
function libcusolvermg(; throw_error::Bool=true)
     path = @initialize_ref __libcusolverMg begin
        if toolkit_release() < v"10.1"
            nothing
        else
            find_library(toolkit(), "cusolverMg"; optional=true)
        end
    end
    if path === nothing && throw_error
        error("This functionality is unavailabe as cuSolverMg is missing.")
    end
    path
end
has_cusolvermg() = libcusolvermg(throw_error=false) !== nothing

const __libcupti = Ref{Union{String,Nothing}}()
function libcupti(; throw_error::Bool=true)
    path = @initialize_ref __libcupti begin
        find_library(toolkit(), "cupti"; optional=true)
    end
    if path === nothing && throw_error
        error("This functionality is unavailabe as CUPTI is missing.")
    end
    path
end
has_cupti() = libcupti(throw_error=false) !== nothing

const __libnvtx = Ref{Union{String,Nothing}}()
function libnvtx(; throw_error::Bool=true)
    path = @initialize_ref __libnvtx begin
        find_library(toolkit(), "nvtx"; optional=true)
    end
    if path === nothing && throw_error
        error("This functionality is unavailabe as NVTX is missing.")
    end
    path
end
has_nvtx() = libnvtx(throw_error=false) !== nothing

function artifact_library(artifact, name)
    # XXX: we don't want to consider multiple library names based on all candidate versions,
    #      since all that is known when building the artifact, but not saved anywhere.
    dir = joinpath(artifact, Sys.iswindows() ? "bin" : "lib")
    all_names = library_versioned_names(name)
    for name in all_names
        path = joinpath(dir, name)
        ispath(path) && return path
    end

    # we should _always_ find libraries in artifacts
    error("""Could not find library '$name' in $artifact
             This is a bug; please file an issue with a verbose directory listing of $dir
             If this directory is empty, delete it and try again.""")
end

function artifact_cuda_library(artifact, library, toolkit_release)
    name = get(cuda_library_names, library, library)
    artifact_library(artifact, name)
end

function find_library(cuda::ArtifactToolkit, name; optional=false)
    # NOTE: optional is ignored, and we'll error if not found
    path = artifact_cuda_library(cuda.artifact, name, cuda.release)
    Libdl.dlopen(path)
    return path
end

function find_library(cuda::LocalToolkit, name; optional=false)
    path = find_cuda_library(name, cuda.dirs)
    if path !== nothing
        Libdl.dlopen(path)
        return path
    else
        optional || error("Could not find library '$name' in your local CUDA installation.")
        return nothing
    end
end


## other

export libdevice, libcudadevrt

const __libdevice = Ref{String}()
function libdevice()
    @initialize_ref __libdevice begin
        find_libdevice(toolkit())
    end
end

function artifact_file(artifact_dir, name)
    path = joinpath(artifact_dir, name)
    if !ispath(path)
        error("""Could not find '$name' in $artifact_dir!
                 This is a bug; please file an issue with a verbose directory listing of $artifact_dir
                 If this directory is empty, delete it and try again.""")
    end
    return path
end

function find_libdevice(cuda::ArtifactToolkit)
    path = artifact_file(cuda.artifact, joinpath("share", "libdevice", "libdevice.10.bc"))
    if isfile(path)
        return path
    else
    end
end

function find_libdevice(cuda::LocalToolkit)
    path = find_libdevice(cuda.dirs)
    if path !== nothing
        return path
    else
        error("Could not find libdevice in your local CUDA installation.")
    end
end

const __libcudadevrt = Ref{String}()
function libcudadevrt()
    @initialize_ref __libcudadevrt begin
        find_libcudadevrt(toolkit())
    end
end

function artifact_static_library(artifact_dir, name)
    path = joinpath(artifact_dir, "lib", Sys.iswindows() ? "$name.lib" : "lib$name.a")
    if !ispath(path)
        error("""Could not find static library '$name' in $artifact_dir
                 This is a bug; please file an issue with a verbose directory listing of $artifact_dir
                 If this directory is empty, delete it and try again.""")
    end
    return path
end

find_libcudadevrt(cuda::ArtifactToolkit) = artifact_static_library(cuda.artifact, "cudadevrt")

function find_libcudadevrt(cuda::LocalToolkit)
    path = find_libcudadevrt(cuda.dirs)
    if path !== nothing
        return path
    else
        error("Could not find libcudadevrt in your local CUDA installation.")
    end
end


#
# CUDNN
#

export libcudnn, has_cudnn

const __libcudnn = Ref{Union{String,Nothing}}()
function libcudnn(; throw_error::Bool=true)
    path = @initialize_ref __libcudnn begin
        find_cudnn(toolkit())
        # TODO: verify v8?
    end CUDA.CUDNN.__runtime_init__()
    if path === nothing && throw_error
        error("This functionality is unavailabe as CUDNN is missing.")
    end
    path
end
has_cudnn() = libcudnn(throw_error=false) !== nothing

function find_cudnn(cuda::ArtifactToolkit)
    artifact_dir = cuda_artifact("CUDNN", cuda.release)
    if artifact_dir === nothing
        return nothing
    end
    path = artifact_library(artifact_dir, "cudnn")

    # HACK: eagerly open CUDNN sublibraries to avoid dlopen discoverability issues
    for sublibrary in ("ops_infer", "ops_train",
                       "cnn_infer", "cnn_train",
                       "adv_infer", "adv_train")
        sublibrary_path = artifact_library(artifact_dir, "cudnn_$(sublibrary)")
        Libdl.dlopen(sublibrary_path)
    end

    @debug "Using CUDNN from an artifact at $(artifact_dir)"
    Libdl.dlopen(path)
    return path
end

function find_cudnn(cuda::LocalToolkit)
    path = find_library("cudnn"; locations=cuda.dirs)
    if path === nothing
        return nothing
    end

    # HACK: eagerly open CUDNN sublibraries to avoid dlopen discoverability issues
    for sublibrary in ("ops_infer", "ops_train",
                       "cnn_infer", "cnn_train",
                       "adv_infer", "adv_train")
        sublibrary_path = find_library("cudnn_$(sublibrary)"; locations=cuda.dirs)
        sublibrary_path === nothing && error("Could not find local CUDNN sublibrary $sublibrary")
        Libdl.dlopen(sublibrary_path)
    end

    @debug "Using local CUDNN at $(path)"
    Libdl.dlopen(path)
    return path
end


#
# CUTENSOR
#

export libcutensor, has_cutensor

const __libcutensor = Ref{Union{String,Nothing}}()
function libcutensor(; throw_error::Bool=true)
    path = @initialize_ref __libcutensor begin
        # CUTENSOR depends on CUBLAS and CUBLASlt to be discoverable by the linker
        libcublas()

        find_cutensor(toolkit())
    end
    if path === nothing && throw_error
        error("This functionality is unavailabe as CUTENSOR is missing.")
    end
    path
end
has_cutensor() = libcutensor(throw_error=false) !== nothing

function find_cutensor(cuda::ArtifactToolkit)
    artifact_dir = cuda_artifact("CUTENSOR", cuda.release)
    if artifact_dir === nothing
        return nothing
    end
    path = artifact_library(artifact_dir, "cutensor")

    @debug "Using CUTENSOR from an artifact at $(artifact_dir)"
    Libdl.dlopen(path)
    return path
end

function find_cutensor(cuda::LocalToolkit)
    path = find_library("cutensor"; locations=cuda.dirs)
    if path === nothing
        path = find_library("cutensor"; locations=cuda.dirs)
    end
    if path === nothing
        return nothing
    end

    @debug "Using local CUTENSOR at $(path)"
    Libdl.dlopen(path)
    return path
end

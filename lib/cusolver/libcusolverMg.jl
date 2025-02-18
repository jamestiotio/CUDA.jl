using CEnum

mutable struct cusolverMgContext end

const cusolverMgHandle_t = Ptr{cusolverMgContext}

@cenum cusolverMgGridMapping_t::UInt32 begin
    CUDALIBMG_GRID_MAPPING_ROW_MAJOR = 1
    CUDALIBMG_GRID_MAPPING_COL_MAJOR = 0
end

const cudaLibMgGrid_t = Ptr{Cvoid}

const cudaLibMgMatrixDesc_t = Ptr{Cvoid}

@checked function cusolverMgCreate(handle)
    initialize_context()
    @ccall libcusolverMg.cusolverMgCreate(handle::Ptr{cusolverMgHandle_t})::cusolverStatus_t
end

@checked function cusolverMgDestroy(handle)
    initialize_context()
    @ccall libcusolverMg.cusolverMgDestroy(handle::cusolverMgHandle_t)::cusolverStatus_t
end

@checked function cusolverMgDeviceSelect(handle, nbDevices, deviceId)
    initialize_context()
    @ccall libcusolverMg.cusolverMgDeviceSelect(handle::cusolverMgHandle_t, nbDevices::Cint,
                                                deviceId::Ptr{Cint})::cusolverStatus_t
end

@checked function cusolverMgCreateDeviceGrid(grid, numRowDevices, numColDevices, deviceId,
                                             mapping)
    initialize_context()
    @ccall libcusolverMg.cusolverMgCreateDeviceGrid(grid::Ptr{cudaLibMgGrid_t},
                                                    numRowDevices::Int32,
                                                    numColDevices::Int32,
                                                    deviceId::Ptr{Int32},
                                                    mapping::cusolverMgGridMapping_t)::cusolverStatus_t
end

@checked function cusolverMgDestroyGrid(grid)
    initialize_context()
    @ccall libcusolverMg.cusolverMgDestroyGrid(grid::cudaLibMgGrid_t)::cusolverStatus_t
end

@checked function cusolverMgCreateMatrixDesc(desc, numRows, numCols, rowBlockSize,
                                             colBlockSize, dataType, grid)
    initialize_context()
    @ccall libcusolverMg.cusolverMgCreateMatrixDesc(desc::Ptr{cudaLibMgMatrixDesc_t},
                                                    numRows::Int64, numCols::Int64,
                                                    rowBlockSize::Int64,
                                                    colBlockSize::Int64,
                                                    dataType::cudaDataType,
                                                    grid::cudaLibMgGrid_t)::cusolverStatus_t
end

@checked function cusolverMgDestroyMatrixDesc(desc)
    initialize_context()
    @ccall libcusolverMg.cusolverMgDestroyMatrixDesc(desc::cudaLibMgMatrixDesc_t)::cusolverStatus_t
end

@checked function cusolverMgSyevd_bufferSize(handle, jobz, uplo, N, array_d_A, IA, JA,
                                             descrA, W, dataTypeW, computeType, lwork)
    initialize_context()
    @ccall libcusolverMg.cusolverMgSyevd_bufferSize(handle::cusolverMgHandle_t,
                                                    jobz::cusolverEigMode_t,
                                                    uplo::cublasFillMode_t, N::Cint,
                                                    array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint,
                                                    JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                                    W::Ptr{Cvoid}, dataTypeW::cudaDataType,
                                                    computeType::cudaDataType,
                                                    lwork::Ptr{Int64})::cusolverStatus_t
end

@checked function cusolverMgSyevd(handle, jobz, uplo, N, array_d_A, IA, JA, descrA, W,
                                  dataTypeW, computeType, array_d_work, lwork, info)
    initialize_context()
    @ccall libcusolverMg.cusolverMgSyevd(handle::cusolverMgHandle_t,
                                         jobz::cusolverEigMode_t, uplo::cublasFillMode_t,
                                         N::Cint, array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint,
                                         JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                         W::Ptr{Cvoid}, dataTypeW::cudaDataType,
                                         computeType::cudaDataType,
                                         array_d_work::Ptr{CuPtr{Cvoid}}, lwork::Int64,
                                         info::Ptr{Cint})::cusolverStatus_t
end

@checked function cusolverMgGetrf_bufferSize(handle, M, N, array_d_A, IA, JA, descrA,
                                             array_d_IPIV, computeType, lwork)
    initialize_context()
    @ccall libcusolverMg.cusolverMgGetrf_bufferSize(handle::cusolverMgHandle_t, M::Cint,
                                                    N::Cint, array_d_A::Ptr{CuPtr{Cvoid}},
                                                    IA::Cint, JA::Cint,
                                                    descrA::cudaLibMgMatrixDesc_t,
                                                    array_d_IPIV::Ptr{CuPtr{Cint}},
                                                    computeType::cudaDataType,
                                                    lwork::Ptr{Int64})::cusolverStatus_t
end

@checked function cusolverMgGetrf(handle, M, N, array_d_A, IA, JA, descrA, array_d_IPIV,
                                  computeType, array_d_work, lwork, info)
    initialize_context()
    @ccall libcusolverMg.cusolverMgGetrf(handle::cusolverMgHandle_t, M::Cint, N::Cint,
                                         array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint, JA::Cint,
                                         descrA::cudaLibMgMatrixDesc_t,
                                         array_d_IPIV::Ptr{CuPtr{Cint}},
                                         computeType::cudaDataType,
                                         array_d_work::Ptr{CuPtr{Cvoid}}, lwork::Int64,
                                         info::Ptr{Cint})::cusolverStatus_t
end

@checked function cusolverMgGetrs_bufferSize(handle, TRANS, N, NRHS, array_d_A, IA, JA,
                                             descrA, array_d_IPIV, array_d_B, IB, JB,
                                             descrB, computeType, lwork)
    initialize_context()
    @ccall libcusolverMg.cusolverMgGetrs_bufferSize(handle::cusolverMgHandle_t,
                                                    TRANS::cublasOperation_t, N::Cint,
                                                    NRHS::Cint,
                                                    array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint,
                                                    JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                                    array_d_IPIV::Ptr{CuPtr{Cint}},
                                                    array_d_B::Ptr{CuPtr{Cvoid}}, IB::Cint,
                                                    JB::Cint, descrB::cudaLibMgMatrixDesc_t,
                                                    computeType::cudaDataType,
                                                    lwork::Ptr{Int64})::cusolverStatus_t
end

@checked function cusolverMgGetrs(handle, TRANS, N, NRHS, array_d_A, IA, JA, descrA,
                                  array_d_IPIV, array_d_B, IB, JB, descrB, computeType,
                                  array_d_work, lwork, info)
    initialize_context()
    @ccall libcusolverMg.cusolverMgGetrs(handle::cusolverMgHandle_t,
                                         TRANS::cublasOperation_t, N::Cint, NRHS::Cint,
                                         array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint, JA::Cint,
                                         descrA::cudaLibMgMatrixDesc_t,
                                         array_d_IPIV::Ptr{CuPtr{Cint}},
                                         array_d_B::Ptr{CuPtr{Cvoid}}, IB::Cint, JB::Cint,
                                         descrB::cudaLibMgMatrixDesc_t,
                                         computeType::cudaDataType,
                                         array_d_work::Ptr{CuPtr{Cvoid}}, lwork::Int64,
                                         info::Ptr{Cint})::cusolverStatus_t
end

@checked function cusolverMgPotrf_bufferSize(handle, uplo, N, array_d_A, IA, JA, descrA,
                                             computeType, lwork)
    initialize_context()
    @ccall libcusolverMg.cusolverMgPotrf_bufferSize(handle::cusolverMgHandle_t,
                                                    uplo::cublasFillMode_t, N::Cint,
                                                    array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint,
                                                    JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                                    computeType::cudaDataType,
                                                    lwork::Ptr{Int64})::cusolverStatus_t
end

@checked function cusolverMgPotrf(handle, uplo, N, array_d_A, IA, JA, descrA, computeType,
                                  array_d_work, lwork, h_info)
    initialize_context()
    @ccall libcusolverMg.cusolverMgPotrf(handle::cusolverMgHandle_t, uplo::cublasFillMode_t,
                                         N::Cint, array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint,
                                         JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                         computeType::cudaDataType,
                                         array_d_work::Ptr{CuPtr{Cvoid}}, lwork::Int64,
                                         h_info::Ptr{Cint})::cusolverStatus_t
end

@checked function cusolverMgPotrs_bufferSize(handle, uplo, n, nrhs, array_d_A, IA, JA,
                                             descrA, array_d_B, IB, JB, descrB, computeType,
                                             lwork)
    initialize_context()
    @ccall libcusolverMg.cusolverMgPotrs_bufferSize(handle::cusolverMgHandle_t,
                                                    uplo::cublasFillMode_t, n::Cint,
                                                    nrhs::Cint,
                                                    array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint,
                                                    JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                                    array_d_B::Ptr{CuPtr{Cvoid}}, IB::Cint,
                                                    JB::Cint, descrB::cudaLibMgMatrixDesc_t,
                                                    computeType::cudaDataType,
                                                    lwork::Ptr{Int64})::cusolverStatus_t
end

@checked function cusolverMgPotrs(handle, uplo, n, nrhs, array_d_A, IA, JA, descrA,
                                  array_d_B, IB, JB, descrB, computeType, array_d_work,
                                  lwork, h_info)
    initialize_context()
    @ccall libcusolverMg.cusolverMgPotrs(handle::cusolverMgHandle_t, uplo::cublasFillMode_t,
                                         n::Cint, nrhs::Cint, array_d_A::Ptr{CuPtr{Cvoid}},
                                         IA::Cint, JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                         array_d_B::Ptr{CuPtr{Cvoid}}, IB::Cint, JB::Cint,
                                         descrB::cudaLibMgMatrixDesc_t,
                                         computeType::cudaDataType,
                                         array_d_work::Ptr{CuPtr{Cvoid}}, lwork::Int64,
                                         h_info::Ptr{Cint})::cusolverStatus_t
end

@checked function cusolverMgPotri_bufferSize(handle, uplo, N, array_d_A, IA, JA, descrA,
                                             computeType, lwork)
    initialize_context()
    @ccall libcusolverMg.cusolverMgPotri_bufferSize(handle::cusolverMgHandle_t,
                                                    uplo::cublasFillMode_t, N::Cint,
                                                    array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint,
                                                    JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                                    computeType::cudaDataType,
                                                    lwork::Ptr{Int64})::cusolverStatus_t
end

@checked function cusolverMgPotri(handle, uplo, N, array_d_A, IA, JA, descrA, computeType,
                                  array_d_work, lwork, h_info)
    initialize_context()
    @ccall libcusolverMg.cusolverMgPotri(handle::cusolverMgHandle_t, uplo::cublasFillMode_t,
                                         N::Cint, array_d_A::Ptr{CuPtr{Cvoid}}, IA::Cint,
                                         JA::Cint, descrA::cudaLibMgMatrixDesc_t,
                                         computeType::cudaDataType,
                                         array_d_work::Ptr{CuPtr{Cvoid}}, lwork::Int64,
                                         h_info::Ptr{Cint})::cusolverStatus_t
end

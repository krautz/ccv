extern "C" {
#include "ccv_nnc_compat.h"
}
#include "ccv_nnc_cmd.h"

void* cumalloc(int device, size_t size)
{
	void* ptr = 0;
	cudaSetDevice(device);
	cudaMalloc(&ptr, size);
	return ptr;
}

void cufree(int device, void* ptr)
{
	cudaSetDevice(device);
	cudaFree(ptr);
}

typedef struct {
	int type; // Kept the type specifier.
	cudaStream_t stream;
	cublasHandle_t cublas;
#ifdef HAVE_CUDNN
	cudnnHandle_t cudnn;
#endif
} ccv_nnc_stream_context_compat_t;

ccv_nnc_stream_context_t* ccv_nnc_init_stream_context(ccv_nnc_stream_context_t* stream_context)
{
	assert(CCV_STREAM_GET_CONTEXT(((int*)stream_context)[0]) == CCV_STREAM_CONTEXT_GPU);
	ccv_nnc_stream_context_compat_t* stream_compat = (ccv_nnc_stream_context_compat_t*)ccrealloc(stream_context, sizeof(ccv_nnc_stream_context_compat_t));
	int device = CCV_STREAM_GET_DEVICE_ID(stream_compat->type);
	cudaSetDevice(device);
	cudaStreamCreate(&stream_compat->stream);
	stream_compat->cublas = 0;
#ifdef HAVE_CUDNN
	stream_compat->cudnn = 0;
#endif
	return (ccv_nnc_stream_context_t*)stream_compat;
}

void ccv_nnc_synchronize_stream_context(const ccv_nnc_stream_context_t* stream_context)
{
	ccv_nnc_stream_context_compat_t* stream_compat = (ccv_nnc_stream_context_compat_t*)stream_context;
	int device = CCV_STREAM_GET_DEVICE_ID(stream_compat->type);
	cudaSetDevice(device);
	cudaStreamSynchronize(stream_compat->stream);
}

void ccv_nnc_deinit_stream_context(ccv_nnc_stream_context_t* stream_context)
{
	ccv_nnc_stream_context_compat_t* stream_compat = (ccv_nnc_stream_context_compat_t*)stream_context;
	int device = CCV_STREAM_GET_DEVICE_ID(stream_compat->type);
	cudaSetDevice(device);
	cudaStreamDestroy(stream_compat->stream);
	if (stream_compat->cublas)
		cublasDestroy(stream_compat->cublas);
#ifdef HAVE_CUDNN
	if (stream_compat->cudnn)
		cudnnDestroy(stream_compat->cudnn);
#endif
}

int ccv_nnc_stream_context_get_device(const ccv_nnc_stream_context_t* stream_context)
{
	ccv_nnc_stream_context_compat_t* stream_compat = (ccv_nnc_stream_context_compat_t*)stream_context;
	return CCV_STREAM_GET_DEVICE_ID(stream_compat->type);
}

cudaStream_t ccv_nnc_stream_context_get_stream(const ccv_nnc_stream_context_t* stream_context)
{
	ccv_nnc_stream_context_compat_t* stream_compat = (ccv_nnc_stream_context_compat_t*)stream_context;
	return stream_compat->stream;
}

cublasHandle_t ccv_nnc_stream_context_get_cublas(const ccv_nnc_stream_context_t* stream_context)
{
	ccv_nnc_stream_context_compat_t* stream_compat = (ccv_nnc_stream_context_compat_t*)stream_context;
	if (!stream_compat->cublas)
	{
		int device = CCV_STREAM_GET_DEVICE_ID(stream_compat->type);
		cudaSetDevice(device);
		cublasCreate(&stream_compat->cublas);
		cublasSetStream(stream_compat->cublas, stream_compat->stream);
	}
	return stream_compat->cublas;
}

#ifdef HAVE_CUDNN
cudnnHandle_t ccv_nnc_stream_context_get_cudnn(const ccv_nnc_stream_context_t* stream_context)
{
	ccv_nnc_stream_context_compat_t* stream_compat = (ccv_nnc_stream_context_compat_t*)stream_context;
	if (!stream_compat->cudnn)
	{
		int device = CCV_STREAM_GET_DEVICE_ID(stream_compat->type);
		cudaSetDevice(device);
		cudnnCreate(&stream_compat->cudnn);
		cudnnSetStream(stream_compat->cudnn, stream_compat->stream);
	}
	return stream_compat->cudnn;
}

cudnnConvolutionDescriptor_t ccv_nnc_stream_context_get_convolution_descriptor(const ccv_nnc_stream_context_t* stream_context)
{
	cudnnConvolutionDescriptor_t desc;
	cudnnCreateConvolutionDescriptor(&desc);
	return desc;
}

cudnnTensorDescriptor_t ccv_nnc_stream_context_get_tensor_descriptor(const ccv_nnc_stream_context_t* stream_context)
{
	cudnnTensorDescriptor_t desc;
	cudnnCreateTensorDescriptor(&desc);
	return desc;
}

cudnnFilterDescriptor_t ccv_nnc_stream_context_get_filter_descriptor(const ccv_nnc_stream_context_t* stream_context)
{
	cudnnFilterDescriptor_t desc;
	cudnnCreateFilterDescriptor(&desc);
	return desc;
}

void ccv_nnc_stream_context_return_convolution_descriptor(const ccv_nnc_stream_context_t* stream_context, cudnnConvolutionDescriptor_t convolution_descriptor)
{
	cudnnDestroyConvolutionDescriptor(convolution_descriptor);
}

void ccv_nnc_stream_context_return_tensor_descriptor(const ccv_nnc_stream_context_t* stream_context, cudnnTensorDescriptor_t tensor_descriptor)
{
	cudnnDestroyTensorDescriptor(tensor_descriptor);
}

void ccv_nnc_stream_context_return_filter_descriptor(const ccv_nnc_stream_context_t* stream_context, cudnnFilterDescriptor_t filter_descriptor)
{
	cudnnDestroyFilterDescriptor(filter_descriptor);
}
#endif

static void _ccv_nnc_cufree_stream_callback(cudaStream_t stream, cudaError_t status, void* ptr)
{
	cudaFree(ptr);
}

void cudaFreeAsync(void* ptr, cudaStream_t stream)
{
	cudaStreamAddCallback(stream, _ccv_nnc_cufree_stream_callback, ptr, 0);
}
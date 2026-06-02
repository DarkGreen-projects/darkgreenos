; DarkMind-Q fixed header offsets

%ifndef DARKMIND_LLM_FORMAT_INC
%define DARKMIND_LLM_FORMAT_INC

%define DMQ_MAGIC_OFF          0
%define DMQ_VERSION_OFF        4
%define DMQ_HEADER_BYTES_OFF   8
%define DMQ_MODEL_CLASS_OFF    12
%define DMQ_QUANT_BITS_OFF     16
%define DMQ_CTX_TOKENS_OFF     20
%define DMQ_VOCAB_SIZE_OFF     24
%define DMQ_LAYER_COUNT_OFF    28
%define DMQ_HIDDEN_SIZE_OFF    32
%define DMQ_HEAD_COUNT_OFF     36
%define DMQ_KV_HEAD_COUNT_OFF  40
%define DMQ_HEAD_DIM_OFF       44
%define DMQ_TENSOR_COUNT_OFF   48
%define DMQ_TOKENIZER_OFF      52
%define DMQ_TOKENIZER_SIZE_OFF 56
%define DMQ_TENSOR_DIR_OFF     60
%define DMQ_TENSOR_DIR_SIZE_OFF 64
%define DMQ_CRC32_OFF          68
%define DMQ2_INTERMEDIATE_OFF  72
%define DMQ2_ROPE_THETA_OFF    76
%define DMQ2_TOKENIZER_KIND_OFF 80
%define DMQ2_ARCH_ID_OFF       84
%define DMQ2_TENSOR_BYTES_OFF  88
%define DMQ2_FLAGS_OFF         92
%define DMQ_HEADER_BYTES       128

%define DMQ_TENSOR_NAME_BYTES  32
%define DMQ_TENSOR_DTYPE_OFF   32
%define DMQ_TENSOR_RANK_OFF    36
%define DMQ_TENSOR_DIM0_OFF    40
%define DMQ_TENSOR_DIM1_OFF    44
%define DMQ_TENSOR_DIM2_OFF    48
%define DMQ_TENSOR_OFFSET_OFF  52
%define DMQ_TENSOR_SIZE_OFF    56
%define DMQ_TENSOR_BYTES       64

%define DMQ2_TENSOR_NAME_BYTES 56
%define DMQ2_TENSOR_DTYPE_OFF  56
%define DMQ2_TENSOR_RANK_OFF   60
%define DMQ2_TENSOR_DIM0_OFF   64
%define DMQ2_TENSOR_DIM1_OFF   68
%define DMQ2_TENSOR_DIM2_OFF   72
%define DMQ2_TENSOR_DIM3_OFF   76
%define DMQ2_TENSOR_OFFSET_OFF 80
%define DMQ2_TENSOR_SIZE_OFF   88
%define DMQ2_TENSOR_BYTES      96

%define DMQ_VERSION            1
%define DMQ2_VERSION           2
%define DMQ_MODEL_CLASS_1B     1000
%define DMQ_MODEL_CLASS_QWEN25_05B 525
%define DMQ_QUANT_Q4           4
%define DMQ_BYTE_VOCAB_SIZE    256
%define DMQ_DTYPE_Q4_0         4
%define DMQ_DTYPE_I16          16
%define DMQ_DTYPE_F16          16
%define DMQ_ARCH_QWEN2         2
%define DMQ_TOKENIZER_QWEN_BPE 2

%define DMQ_QWEN_LAYERS        24
%define DMQ_QWEN_HIDDEN        896
%define DMQ_QWEN_HEADS         14
%define DMQ_QWEN_KV_HEADS      2
%define DMQ_QWEN_HEAD_DIM      64
%define DMQ_QWEN_INTERMEDIATE  4864
%define DMQ_QWEN_MIN_VOCAB     100000
%define DMQ_QWEN_MIN_TENSORS   200

; Minimum shape expected before enabling real autoregressive decoding.
%define DMQ_REAL_MIN_BYTES     0x10000000
%define DMQ_REAL_MIN_LAYERS    16
%define DMQ_REAL_MIN_TENSORS   64

%endif

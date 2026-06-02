; DarkMind persistent memory image (DMEM1)

%ifndef DARKMIND_MEMORY_FORMAT_INC
%define DARKMIND_MEMORY_FORMAT_INC

%define DMEM_MAGIC_OFF          0
%define DMEM_VERSION_OFF        4
%define DMEM_HEADER_BYTES_OFF   8
%define DMEM_CAPACITY_OFF       12
%define DMEM_RECORD_COUNT_OFF   16
%define DMEM_WRITE_OFF          20
%define DMEM_CRC32_OFF          24
%define DMEM_HEADER_BYTES       64

%define DMEM_RECORD_TYPE_OFF    0
%define DMEM_RECORD_FLAGS_OFF   4
%define DMEM_RECORD_TEXT_LEN_OFF 8
%define DMEM_RECORD_BYTES       16

%define DMEM_VERSION            1
%define DMEM_TYPE_PERSONA       1
%define DMEM_TYPE_MACHINE       2
%define DMEM_TYPE_PREFERENCE    3
%define DMEM_TYPE_CONVERSATION  4
%define DMEM_TYPE_SUMMARY       5

%define DMEM_QUERY_BYTES        512
%define DMEM_APPEND_BYTES       384

%endif

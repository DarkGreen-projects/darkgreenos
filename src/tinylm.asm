; DarkgreenOS - bridge to DarkMind resource orchestrator (no generative LLM)

%include "constants.inc"

extern darkmind_start
extern darkmind_step
extern darkmind_busy

global tinylm_start
global tinylm_step
global tinylm_busy

section .bss
tinylm_busy: resd 1

section .text
tinylm_start:
    mov dword [tinylm_busy], 1
    call darkmind_start
    ret

tinylm_step:
    call darkmind_step
    ret

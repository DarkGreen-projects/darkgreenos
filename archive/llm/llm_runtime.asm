; DarkgreenOS - cooperative DarkMind runtime baseline

%include "constants.inc"

%define LLM_PROMPT_BYTES 2048

extern gui_log_line
extern brain_ctx
extern timer_ticks
extern llm_init
extern llm_model_ready
extern llm_model_real
extern llm_status_ptr
extern pmm_llm_arena_kb
extern pmm_model_kb
extern llm_tokenize_prompt
extern llm_detokenize_byte
extern llm_detokenize_token
extern llm_detok_chunk_ptr
extern llm_detok_chunk_len
extern llm_prompt_tokens
extern llm_q4_gemv_probe
extern llm_probe_score
extern llm_sample_greedy
extern llm_route
extern llm_kv_init
extern llm_decode_begin
extern llm_decode_step
extern llm_decode_done
extern llm_decode_real_ready
extern llm_decode_token_id
extern llm_layer0_verified
extern llm_tensor_init
extern llm_tokenizer_init
extern llm_memory_init
extern llm_memory_query
extern llm_memory_append_interaction

global llm_start
global llm_step
global llm_busy

section .bss
llm_busy:       resd 1
llm_phase:      resd 1
llm_last_tick:  resd 1
llm_prompt:     resb BRAIN_QUERY_MAX
llm_prompt_full: resb LLM_PROMPT_BYTES
llm_line:       resb 128
llm_reply_ptr:  resd 1
llm_line_len:   resd 1
llm_memory_ctx_ptr: resd 1

section .rodata
msg_start: db "[DarkMind-1B] decoder transformer cooperativo: tokenizer, KV, norm, RoPE, Q4, attention, MLP, logits.", 0
msg_low:   db "[DarkMind-1B] modello non validato: continuo in decode dinamico diagnostico senza bloccare GUI/input.", 0
msg_ctx:   db "[DarkMind-1B] contesto live:", 0
msg_prompt: db "[DarkMind-1B] domanda ricevuta:", 0
msg_need_weights_1: db "[DarkMind-Q] Non genero token casuali: il blob attuale non contiene pesi transformer Qwen reali.", 0
msg_need_weights_2: db "Per risposte da vero LLM serve sostituire model/darkmind-q4.bin con un DarkMind-Q2 Qwen Q4 reale: tokenizer, tensor directory completa e centinaia di MB di pesi.", 0
msg_need_weights_3: db "Finche' il blob resta quello di test, posso solo validare loader, memoria e GUI; non posso produrre semantica da un modello inesistente.", 0
msg_qwen_pending_1: db "[DarkMind-Q2] Qwen reale validato, ma decode transformer reale non ancora collegato ai tensori.", 0
msg_qwen_pending_2: db "Non genero token pseudo-casuali: prossimo passo e' collegare tokenizer, GEMV Q4, attention, MLP e logits ai pesi DMQ2.", 0
msg_layer0_ok: db "[DarkMind-Q2] layer 0 reale verificato: embedding, RMSNorm, GEMV Q4, RoPE, GQA attention e MLP hanno letto i tensori DMQ2.", 0
msg_layer0_wait: db "[DarkMind-Q2] layer 0 reale non verificato in questo avvio: resto sul responder memoria/contesto.", 0
msg_decode_ready: db "[DarkMind-Q2] decode generativo abilitato: token Qwen a 32 bit, KV cache, logits top-k e detokenizer runtime.", 0
msg_system: db "<|im_start|>system", 10, "Sei DarkMind Mini, IA locale personale di DarkgreenOS. Rispondi sempre in italiano e usa prima contesto macchina e memoria evolutiva.", 10, 0
msg_ctx_label: db "<|contesto_macchina|>", 10, 0
msg_mem_label: db 10, "<|memoria_evolutiva|>", 10, 0
msg_user_label: db 10, "<|im_end|>", 10, "<|im_start|>user", 10, 0
msg_assistant_label: db 10, "<|im_end|>", 10, "<|im_start|>assistant", 10, 0
msg_real_answer_1: db "[DarkMind Mini] Risposta locale evolutiva:", 0
msg_real_answer_2: db "Ho letto la tua domanda:", 0
msg_real_answer_3: db "In questo avvio vedo davvero questa macchina:", 0
msg_real_answer_4: db "La mia memoria personale attiva contiene:", 0
msg_real_answer_5: db "Risposta: sono la IA interna di DarkgreenOS; uso questi dati per rispondere in italiano sul sistema reale, non su un profilo generico.", 0
msg_real_answer_6: db "Evoluzione: salvo questa interazione nella memoria RAM DMEM1; le prossime risposte includeranno anche cio' che mi hai appena chiesto.", 0
ans_general: db "Risposta: ho letto la domanda, ma il decode generativo Qwen e' ancora disattivato per evitare testo falso. Posso rispondere in modo affidabile su DarkgreenOS, boot, GUI, input, memoria, modello, kernel e stato macchina; per domande libere serve completare tokenizer, logits e detokenizer Qwen reali.", 0
ans_hello: db "Risposta: ciao, sono DarkMind Mini. Sono dentro DarkgreenOS, leggo lo stato macchina corrente e mantengo una memoria locale DMEM1 per adattarmi durante la sessione.", 0
ans_help: db "Risposta: puoi chiedermi stato, memoria, GUI, mouse, tastiera, boot, modello, file/kernel o cosa ricordo. Rispondo usando il contesto reale mostrato sotto, non un profilo generico.", 0
ans_identity: db "Risposta: sono la IA locale di DarkgreenOS. La mia identita e' vincolata a questa macchina: boot GRUB Multiboot2, GUI framebuffer, input PS/2, modello Qwen DMQ2 e memoria evolutiva DMEM1.", 0
ans_model: db "Risposta: il modello caricato e' DarkMind-Q2 derivato da Qwen2.5-0.5B-Instruct quantizzato Q4. Il blob contiene tokenizer, profilo macchina e tensori; il kernel valida i tensori prima di tentare il decode.", 0
ans_memory: db "Risposta: la memoria evolutiva e' DMEM1. All'avvio contiene identita, profilo macchina e regole; durante la sessione aggiungo nuove interazioni in RAM per usarle nelle risposte successive.", 0
ans_gui: db "Risposta: la GUI e' framebuffer 1024x768x32 con area centrale DarkMind, barra input chat, pannello risorse e statusbar. Uso questi dati dal contesto live quando rispondo.", 0
ans_mouse: db "Risposta: il mouse e' PS/2 in polling, con coordinate e pulsanti sincronizzati in sysres. Il cursore e' disegnato nel framebuffer e il suo stato entra nel contesto macchina.", 0
ans_keyboard: db "Risposta: la tastiera e' PS/2 in polling. Il kernel traduce gli scancode e passa il testo alla barra chat; io ricevo quel prompt e lo unisco a memoria e stato OS.", 0
ans_boot: db "Risposta: DarkgreenOS parte da GRUB Multiboot2. GRUB carica kernel, modello DMQ2 e memoria DMEM1; il parser MB2 separa i moduli darkmind.model e darkmind.memory.", 0
ans_files: db "Risposta: al momento non c'e' un filesystem generale; kernel, modello e memoria sono moduli/immagini caricati da GRUB. Posso descrivere sezioni kernel e moduli presenti in RAM.", 0
ans_scan: db "Risposta: lo scan aggiorna brain_ctx: RAM, regioni, kernel_bytes, mapped_mb, framebuffer, mouse, GUI, boot, modello e serial companion. Uso quel risultato come base della risposta.", 0

section .text
llm_start:
    pusha
    mov edi, llm_prompt
    mov ecx, BRAIN_QUERY_MAX - 1
.copy:
    lodsb
    test al, al
    jz .copied
    stosb
    loop .copy
.copied:
    mov byte [edi], 0
    call llm_init
    call llm_memory_init
    call llm_build_prompt
    cmp dword [llm_model_ready], 0
    jne .ready
    call llm_emit_memory_answer
    mov dword [llm_busy], 0
    popa
    ret
.ready:
    call llm_tensor_init
    call llm_tokenizer_init
    mov esi, [llm_status_ptr]
    call gui_log_line
    cmp dword [llm_model_real], 0
    jne .real_weights_pending
.missing_real_weights:
    call llm_emit_memory_answer
    mov dword [llm_busy], 0
    popa
    ret
.real_weights_pending:
    mov esi, msg_start
    call gui_log_line
    mov esi, msg_ctx
    call gui_log_line
    mov esi, brain_ctx
    call gui_log_line
    mov esi, msg_prompt
    call gui_log_line
    mov esi, llm_prompt
    call gui_log_line
    mov esi, llm_prompt_full
    call llm_tokenize_prompt
    call llm_kv_init
    mov esi, llm_prompt_full
    call llm_decode_begin
    cmp dword [llm_decode_real_ready], 0
    jne .real_decode_ready
    mov esi, msg_qwen_pending_1
    call gui_log_line
    mov esi, msg_qwen_pending_2
    call gui_log_line
    cmp dword [llm_layer0_verified], 0
    je .layer0_wait
    mov esi, msg_layer0_ok
    call gui_log_line
    jmp .after_layer0_diag
.layer0_wait:
    mov esi, msg_layer0_wait
    call gui_log_line
.after_layer0_diag:
    call llm_emit_memory_answer
    mov dword [llm_busy], 0
    popa
    ret
.real_decode_ready:
    mov esi, msg_decode_ready
    call gui_log_line
    mov dword [llm_phase], 0
    mov dword [llm_last_tick], 0
    mov dword [llm_line_len], 0
    mov dword [llm_busy], 1
    popa
    ret

llm_step:
    pusha
    cmp dword [llm_busy], 0
    je .out
    mov eax, [timer_ticks]
    cmp eax, [llm_last_tick]
    je .out
    mov [llm_last_tick], eax
    call emit_token
.out:
    popa
    ret

emit_token:
    call llm_decode_step
    mov eax, [llm_decode_token_id]
    test eax, eax
    jz .finish
    call llm_detokenize_token
    test al, al
    jz .finish
    cmp dword [llm_detok_chunk_ptr], 0
    jne .chunk
    mov ecx, [llm_line_len]
    cmp ecx, 96
    jae .flush_keep
    mov [llm_line + ecx], al
    inc ecx
    mov [llm_line_len], ecx
    cmp al, '.'
    je .flush
    cmp al, '?'
    je .flush
    cmp al, '!'
    je .flush
    cmp dword [llm_decode_done], 0
    jne .flush
    ret
.chunk:
    call append_detok_chunk
    cmp dword [llm_decode_done], 0
    jne .flush
    ret
.flush_keep:
    call flush_line
    ret
.flush:
    call flush_line
    cmp dword [llm_decode_done], 0
    jne .finish
    ret
.finish:
    cmp dword [llm_line_len], 0
    je .done
    call flush_line
.done:
    mov dword [llm_busy], 0
    ret

append_detok_chunk:
    push eax
    push ebx
    push ecx
    push esi
    mov esi, [llm_detok_chunk_ptr]
    mov ebx, [llm_detok_chunk_len]
.copy:
    test ebx, ebx
    jz .done
    mov ecx, [llm_line_len]
    cmp ecx, 96
    jae .flush_and_continue
    lodsb
    test al, al
    jz .done
    mov [llm_line + ecx], al
    inc ecx
    mov [llm_line_len], ecx
    dec ebx
    cmp al, '.'
    je .flush_and_continue
    cmp al, '?'
    je .flush_and_continue
    cmp al, '!'
    je .flush_and_continue
    jmp .copy
.flush_and_continue:
    call flush_line
    jmp .copy
.done:
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

flush_line:
    push eax
    push ecx
    mov ecx, [llm_line_len]
    mov byte [llm_line + ecx], 0
    mov esi, llm_line
    call gui_log_line
    mov esi, llm_prompt
    mov edi, llm_line
    call llm_memory_append_interaction
    mov dword [llm_line_len], 0
    pop ecx
    pop eax
    ret

llm_build_prompt:
    push eax
    push ecx
    push esi
    push edi
    mov edi, llm_prompt_full
    mov ecx, LLM_PROMPT_BYTES
    xor al, al
    rep stosb
    mov esi, llm_prompt
    call llm_memory_query
    mov [llm_memory_ctx_ptr], eax
    mov edi, llm_prompt_full
    mov esi, msg_system
    call append_prompt
    mov esi, msg_ctx_label
    call append_prompt
    mov esi, brain_ctx
    call append_prompt
    mov esi, msg_mem_label
    call append_prompt
    mov esi, eax
    call append_prompt
    mov esi, msg_user_label
    call append_prompt
    mov esi, llm_prompt
    call append_prompt
    mov esi, msg_assistant_label
    call append_prompt
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

append_prompt:
    push eax
.loop:
    cmp edi, llm_prompt_full + LLM_PROMPT_BYTES - 2
    jae .done
    lodsb
    test al, al
    jz .done
    stosb
    jmp .loop
.done:
    mov byte [edi], 0
    pop eax
    ret

llm_emit_memory_answer:
    push esi
    push edi
    mov esi, msg_real_answer_1
    call gui_log_line
    mov esi, msg_real_answer_2
    call gui_log_line
    mov esi, llm_prompt
    call gui_log_line
    mov esi, llm_prompt
    call llm_sample_greedy
    call llm_emit_route_answer
    mov esi, llm_prompt
    mov edi, ans_general
    call llm_memory_append_interaction
    pop edi
    pop esi
    ret

llm_emit_route_answer:
    cmp eax, 1
    je .model
    cmp eax, 2
    je .memory
    cmp eax, 3
    je .gui
    cmp eax, 4
    je .mouse
    cmp eax, 5
    je .keyboard
    cmp eax, 6
    je .boot
    cmp eax, 7
    je .hello
    cmp eax, 8
    je .help
    cmp eax, 9
    je .identity
    cmp eax, 10
    je .files
    cmp eax, 11
    je .scan
    mov esi, ans_general
    jmp .emit
.model:
    mov esi, ans_model
    jmp .emit
.memory:
    mov esi, ans_memory
    jmp .emit
.gui:
    mov esi, ans_gui
    jmp .emit
.mouse:
    mov esi, ans_mouse
    jmp .emit
.keyboard:
    mov esi, ans_keyboard
    jmp .emit
.boot:
    mov esi, ans_boot
    jmp .emit
.hello:
    mov esi, ans_hello
    jmp .emit
.help:
    mov esi, ans_help
    jmp .emit
.identity:
    mov esi, ans_identity
    jmp .emit
.files:
    mov esi, ans_files
    jmp .emit
.scan:
    mov esi, ans_scan
.emit:
    call gui_log_line
    ret

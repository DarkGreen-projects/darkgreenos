# Kernel classico vs Orchestrator-Native

DarkgreenOS non compete con Linux su driver, rete o ecosistema applicativo. Punta a un modello **Orchestrator-Native**: RMGR/DarkMind come sistema nervoso centrale sempre attivo, con policy adattiva integrata nel path critico di ogni operazione costosa.

## Kernel classico (baseline)

Un kernel general-purpose (Linux, BSD, Windows NT semplificato) è costruito attorno a:

- **Processi** con spazi di indirizzamento separati (ring 0 / ring 3)
- **Syscall** come unica porta user→kernel
- **Scheduler preemptivo** con time-slicing e priorità
- **PMM** con free-list di frame fisici + **VMM** dinamico (demand paging, COW)
- **VFS + block driver** per persistenza
- **Policy reattiva**: OOM killer, nice/cgroups aggiunti *dopo* anni di evoluzione
- **Osservabilità** esterna (perf, eBPF, cgroups) — non nel path critico di ogni operazione

## Matrice comparativa

| Dimensione | Kernel classico | DarkGreenOS | Direzione |
|------------|-----------------|-------------|-----------|
| Filosofia | General-purpose | **RMGR-first** | Orchestrator-native |
| Esecuzione | Multi-processo, preempt | Scheduler RMGR-aware | Coop → preempt |
| User/kernel | Ring 3 + syscall | `syscall.asm` + hook RMGR | Instrumentazione totale |
| Memoria fisica | Free-list per pagina | PMM free-list + budget | Deny sotto pressione |
| Memoria virtuale | Mappe dinamiche | Identity → mappe per-task | Fault recovery RMGR |
| Persistenza | FS su disco | DMTP + FS minimale | Audit/profile export |
| Policy | cgroup/nice (add-on) | Budget, throttle, deny, defer | Continua + IRQ rebalance |
| Apprendimento | Nessuno in kernel | EMA + DMTP cross-boot | Predizione carico |
| Audit | Log esterni | Ring 32 + `snapshot` | Per-task + host |
| LLM | Userspace | **Fuori ring 0** | `companion_agent.py` |
| Dimensione | MB–GB | Kernel ~64 KB, ISO ~5 MB | Target &lt; 80 KB |

## Vantaggi unici DarkGreenOS

### Hook universale

Ogni azione costosa passa da `rmgr_hook_enter` / `rmgr_hook_leave` con snapshot 16×dword → Δfree_kb, Δticks → audit.

| Azione | ID | Modulo |
|--------|-----|--------|
| USER_QUERY | 1 | `darkmind.asm` |
| PERIODIC | 2 | `rmgr_profile.asm` |
| IRQ timer | 4 | `kernel.asm` |
| IRQ kbd/mouse | 5/6 | `kernel.asm` |
| GUI redraw/log | 7/8 | `gui.asm` |
| OSView scan | 9 | `osview.asm` |
| Companion | 10 | `companion.asm` |
| PMM alloc/free | 11/14 | `pmm_alloc.asm` |
| Page fault / GPF | 12/13 | `pagefault.asm`, `gpfault.asm` |
| Syscall | 15 | `syscall.asm` |
| Task switch | 16 | `scheduler.asm` |
| FS read | 17 | `fs_dgfs.asm` |
| FS write | 18 | `fs_dgfs.asm` |

### Policy host (POLICY_SET)

Companion seriale: `policy set thr=<1-16>`, `policy set budget_gui=<n>` — validato in kernel, audit act=10.

### Fase D (v0.7–0.9)

| Feature | Stato |
|---------|-------|
| Context switch kernel-thread | ✅ v0.7a |
| Ring-3 + CR3 per-task | ✅ v0.7b base |
| DGFS RO/RW + GRUB module | ✅ v0.8 |
| Predizione EMA (`rmgr_predict`) | ✅ v0.9 base |
| POLICY_SET host | ✅ companion + agent |
| Benchmark `scripts/benchmark_rmgr.py` | ✅ thr=1 vs 16 |
| DGFS write/sync reale | ✅ v0.10 |
| Error ring + `errors` | ✅ v0.10 |
| SYS_ALLOC user VA | ✅ v0.10 |

### Policy adattiva (non solo logging)

- **THROTTLE** — RAM bassa → meno emissione GUI/chat
- **SAVE_FB** — defer redraw
- **SKIP_SCAN** — cooldown scan OSView
- **BUDGET_DENY** — blocca azioni oltre EMA dTicks per classe

### Profilo cross-boot (DMTP)

Blob `darkmind.memory` persiste `thr`, `score`, `free_min_kb` tra boot.

## Visione Orchestrator-Native

RMGR è **sempre attivo**:

1. **Periodic tick** (~3 s) — campionamento IRQ, tune thresholds
2. **Budget per classe** — deny proattivo prima del lavoro costoso
3. **Learn loop** — EMA su delta → adatta soglie
4. **Scheduler RMGR-aware** — quantum e priorità da `rmgr_throttle_div`
5. **Fault recovery** — page fault/GPF: log + kill task invece di halt cieco

### Guadagno prestazioni misurabile

| Meccanismo | Effetto |
|------------|---------|
| Skip scan / defer redraw | Meno Δticks su carico ripetuto |
| Budget deny | Evita picchi RAM/ticks |
| Profilo DMTP | Pre-throttle al boot successivo |
| Priorità dinamiche | Input/GUI > background scan |
| IRQ budget | Throttle mouse burst sotto RAM bassa |

Metrica: riduzione **Δticks** e **Δfree_kb** negativi in `scripts/qemu_rmgr_regress.py`.

## Roadmap

| Fase | Contenuto |
|------|-----------|
| **A** (completa) | Hook RMGR, audit, DMTP, DarkMind cooperativo |
| **B** | Syscall, scheduler preempt, PMM free-list, FS minimale |
| **C** | Fault recovery, priorità dinamiche, IRQ budget path critico |
| **D** | Predizione carico, contract host `POLICY_SET`, benchmark pubblico |

## Vincoli

- No LLM generativo in ring 0
- No `darkmind-q4.bin` in ISO
- LLM solo host: [LLM host](LLM-host-e-futuro)

Vedi anche: [RMGR orchestratore](RMGR-orchestratore), [Architettura generale](Architettura-generale), [docs/rmgr-superiority.md](../rmgr-superiority.md).

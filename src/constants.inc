; DarkgreenOS - shared constants (NASM)

%ifndef DARKGREEN_CONSTANTS_INC
%define DARKGREEN_CONSTANTS_INC

; Multiboot 1 (legacy fallback se GRUB non passa MB2)
%define MULTIBOOT_MAGIC           0x1BADB002
%define MULTIBOOT_FLAG_ALIGN      0x00000001
%define MULTIBOOT_FLAG_MEMINFO    0x00000002
%define MULTIBOOT_FLAG_MMAP       0x00000040
%define MULTIBOOT_FLAGS           (MULTIBOOT_FLAG_ALIGN | MULTIBOOT_FLAG_MEMINFO)

; Multiboot 2 — framebuffer + info tags
%define MB2_LOADER_MAGIC          0x36D76289
%define MB2_HEADER_MAGIC          0xE85250D6
%define MB2_ARCH_I386             0
%define MB2_TAG_END               0
%define MB2_TAG_MODULE            3
%define MB2_TAG_FRAMEBUFFER       5
%define MB2_TAG_MMAP              6
%define MB2_TAG_BASIC_MEM         4
%define MB2_TAG_FB_INFO           8
%define FB_DEFAULT_WIDTH          1024
%define FB_DEFAULT_HEIGHT         768
%define FB_DEFAULT_BPP            32

; Framebuffer colors (0x00RRGGBB)
%define FB_COL_BG                 0x00080810
%define FB_COL_PANEL              0x00101814
%define FB_COL_BORDER             0x0000AA44
%define FB_COL_TEXT               0x00C0FFC0
%define FB_COL_TITLE              0x0000FF66
%define FB_COL_CURSOR             0x00FFFFFF
%define FB_COL_CHAT               0x00E0FFE0

; GUI layout (pixels)
%define GUI_MARGIN                8
%define GUI_TITLE_H               28
%define GUI_STATUS_H              24
%define GUI_PANEL_W               320
%define GUI_LOG_LINES             14
%define GUI_LOG_COLS              56

; Mouse / IRQ
%define IRQ_MOUSE                 12
%define MOUSE_PORT_DATA            0x60
%define MOUSE_PORT_STATUS          0x64
%define MOUSE_STATUS_AUX           0x20

; GDT segment selectors (flat model)
%define GDT_NULL_SEG              0x00
%define GDT_CODE_SEG              0x08
%define GDT_DATA_SEG              0x10

; Paging (i386, 4 KiB pages)
%define PAGE_SIZE                 0x1000
%define PAGE_PRESENT              0x001
%define PAGE_WRITE                0x002
%define PAGE_USER                 0x004
%define PTE_KERNEL_RW             (PAGE_PRESENT | PAGE_WRITE)
%define CR0_PG                    0x80000000
%define CR4_PSE                   0x00000010
%define PDE_PS_4MB                0x00000080
%define PDE_KERNEL_RW_4MB         (PAGE_PRESENT | PAGE_WRITE | PDE_PS_4MB)

; Identity-map full 32-bit space (1024 x 4 MiB PSE). QEMU_MEM = physical RAM only.
%define IDENTITY_MAP_MB           4096
%define QEMU_DEFAULT_MEM_MB       2048
%define KERNEL_STACK_BYTES        65536

; CPU exceptions
%define INT_INVALID_OPCODE        6
%define INT_GENERAL_PROTECTION    13
%define INT_PAGE_FAULT            14

; VGA text mode (80x25 @ 0xB8000)
%define VGA_MEM                   0xB8000
%define VGA_WIDTH                 80
%define VGA_HEIGHT                25

; Color: bright green on black (DarkgreenOS theme)
%define COLOR_DARKGREEN           0x0A
%define COLOR_DIM_GREEN           0x02
%define COLOR_WHITE               0x0F
%define COLOR_RED                 0x0C

; PIC
%define PIC1_COMMAND              0x20
%define PIC1_DATA                 0x21
%define PIC2_COMMAND              0xA0
%define PIC2_DATA                 0xA1
%define PIC_EOI                   0x20

%define INT_IRQ0                  32
%define IRQ_TIMER                 0
%define IRQ_KEYBOARD              1

; COM1 (QEMU -serial stdio / tcp)
%define SERIAL_COM1               0x3F8
%define SERIAL_LCR                0x3FB
%define SERIAL_LSR                0x3FD
%define SERIAL_LSR_DATA_READY     0x01
%define SERIAL_LSR_TX_EMPTY       0x20

; Companion protocol
%define COMPANION_CMD_MAX         256
%define COMPANION_PERSONA_MAX     128
%define COMPANION_NAME_MAX        32

; Multiboot info offsets
%define MB_FLAGS                  0
%define MB_MEM_LOWER              4
%define MB_MEM_UPPER              8
%define MB_MODS_COUNT             20
%define MB_MODS_ADDR              24
%define MB_MMAP_LENGTH            44
%define MB_MMAP_ADDR              48
%define MB_FLAG_MMAP              0x40
%define MB_FLAG_MODS              0x08
%define MMAP_TYPE_RAM             1

; OS view / internal brain
%define OSVIEW_DUMP_LINES         8
%define OSVIEW_DUMP_LINE_BYTES    16
%define BRAIN_CTX_SIZE            1024
%define BRAIN_QUERY_MAX           128
%define MEM_SCAN_MAX_HITS         8

; DarkMind 1B runtime path
%define MB2_MMAP_MAX_ENTRIES      32
%define DARKMIND_Q_MAGIC          0x31514D44
%define DARKMIND_Q2_MAGIC         0x32514D44
%define DARKMIND_MEM_MAGIC        0x4D454D44
%define LLM_MIN_ARENA_KB          32768
%define LLM_TARGET_ARENA_KB       131072
%define LLM_STEP_BUDGET_OPS       96

; Resource manager / DarkMind context
%define SYSRES_CTX_EXTRA          128

; DarkMind resource orchestrator (rmgr)
%define RMGR_SNAP_WORDS           16
%define RMGR_SNAP_RAM_TOTAL       0
%define RMGR_SNAP_RAM_FREE        4
%define RMGR_SNAP_KERNEL_KB       8
%define RMGR_SNAP_REGIONS         12
%define RMGR_SNAP_MAPPED_MB       16
%define RMGR_SNAP_MODEL_KB        20
%define RMGR_SNAP_FB_ON           24
%define RMGR_SNAP_FB_W            28
%define RMGR_SNAP_FB_H            32
%define RMGR_SNAP_FB_BPP          36
%define RMGR_SNAP_FB_EST_KB       40
%define RMGR_SNAP_GUI_ON          44
%define RMGR_SNAP_MOUSE_X         48
%define RMGR_SNAP_MOUSE_Y         52
%define RMGR_SNAP_TICKS           56
%define RMGR_SNAP_ACTION          60

%define RMGR_ACTION_USER_QUERY    1
%define RMGR_ACTION_PERIODIC      2
%define RMGR_ACTION_COMPANION     3
%define RMGR_ACT_IRQ_TIMER        4
%define RMGR_ACT_IRQ_KEYBOARD     5
%define RMGR_ACT_IRQ_MOUSE        6
%define RMGR_ACT_GUI_REDRAW       7
%define RMGR_ACT_GUI_LOG          8
%define RMGR_ACT_OSVIEW_SCAN      9
%define RMGR_ACT_COMPANION_CMD    10
%define RMGR_ACT_PMM_ALLOC        11
%define RMGR_ACT_PAGE_FAULT       12
%define RMGR_ACT_GPF              13
%define RMGR_ACT_PMM_FREE         14
%define RMGR_ACT_SYSCALL          15
%define RMGR_ACT_TASK_SWITCH      16
%define RMGR_ACT_FS_READ          17
%define RMGR_ACT_FS_WRITE         18
%define RMGR_ACT_ERR_LOG          19

%define DGFS_HDR_FLAGS            20

%define ERR_NONE                  0
%define ERR_PF_USER               1
%define ERR_PF_KERNEL             2
%define ERR_GPF_USER              3
%define ERR_GPF_KERNEL            4
%define ERR_SYSCALL_DENY          5
%define ERR_BAD_PTR               6
%define ERR_INVALID_OP            7

%define ERR_RING_ENTRIES          16
%define ERR_ENTRY_BYTES           16

%define USER_VA_BASE              0x08000000
%define USER_VA_SIZE              0x04000000
%define USER_STACK_TOP            0x0BFFFF000
%define SCH_BG_PRIO_THRESH        128

%define DGFS_HEADER_BYTES         32
%define DGFS_ENTRY_BYTES          44
%define DGFS_BLOCK_SIZE           512
%define DGFS_MAX_SIZE             131072
%define DGFS_FLAG_READONLY        1
%define DGFS_FLAG_DIRTY           2
%define DGFS_AUDIT_TAIL_BYTES     512
%define DGFS_AUDIT_TAIL_HEAD      0
%define DGFS_AUDIT_TAIL_DATA      4
%define DGFS_AUDIT_TAIL_ROOM      508

%define RMGR_BUDGET_FS            300

%define GDT_USER_CODE_SEG         0x18
%define GDT_USER_DATA_SEG         0x20
%define GDT_TSS_SEG               0x28

%define INT_SYSCALL               0x80

%define SYS_EXIT                  1
%define SYS_YIELD                 2
%define SYS_WRITE                 3
%define SYS_READ                  4
%define SYS_OPEN                  5
%define SYS_ALLOC                 6
%define SYS_FREE                  7

%define SCH_MAX_TASKS             4
%define SCH_STACK_SIZE            4096
%define SCH_STATE_DEAD            0
%define SCH_STATE_READY           1
%define SCH_STATE_RUNNING         2

%define FS_MAX_FILES              4
%define FS_NAME_MAX               32
%define FS_MAX_OPEN               4

%define DGFS_MAGIC                0x53464744

%define RMGR_REASON_OK            0
%define RMGR_REASON_BUDGET_DENY   1
%define RMGR_REASON_LOW_RAM       2
%define RMGR_REASON_SKIP_SCAN     3
%define RMGR_REASON_DEFER_REDRAW  4

%define RMGR_AUDIT_ENTRIES        32
%define RMGR_AUDIT_ENTRY_BYTES    24
%define RMGR_AUDIT_SERIAL_MAX     8

%define RMGR_BUDGET_IRQ           80
%define RMGR_BUDGET_GUI           400
%define RMGR_BUDGET_SCAN          600
%define RMGR_BUDGET_CHAT          800
%define RMGR_BUDGET_COMP          400
%define RMGR_BUDGET_PMM           200

%define PMM_ARENA_BASE            0x00200000
%define PMM_ARENA_BYTES           4194304

%define RMGR_DEC_BALANCE          0
%define RMGR_DEC_THROTTLE         1
%define RMGR_DEC_CAUTELA          2
%define RMGR_DEC_SAVE_FB          3
%define RMGR_DEC_EXPLAIN          4

%define RMGR_FREE_RAM_MIN_KB      32768
%define RMGR_FREE_RAM_PCT         25
%define RMGR_PANEL_BYTES          256
%define RMGR_SNAPSHOT_BYTES       256
%define RMGR_STATUS_BYTES         96
%define RMGR_REPORT_LINES         8
%define RMGR_REPORT_LINE_BYTES    128
%define DARKMIND_QUERY_MAX        128
%define DARKMIND_ANSWER_MAX       1024

; Adaptive profile (DMTP blob, 64 bytes)
%define DMTP_MAGIC                0x50544D44
%define RMGR_PROFILE_BYTES        64
%define RMGR_PROFILE_WORDS        16
%define RMGR_PROF_UPTIME          0
%define RMGR_PROF_ACTIONS         4
%define RMGR_PROF_EMA_FREE        8
%define RMGR_PROF_EMA_DFREE       12
%define RMGR_PROF_EMA_DTICKS      16
%define RMGR_PROF_CNT_IDLE        20
%define RMGR_PROF_CNT_CHAT        24
%define RMGR_PROF_CNT_MEM         28
%define RMGR_PROF_CNT_GUI         32
%define RMGR_PROF_CNT_COMP        36
%define RMGR_PROF_THROTTLE        40
%define RMGR_PROF_FREE_MIN        44
%define RMGR_PROF_FREE_PCT        48
%define RMGR_PROF_SCORE           52
%define RMGR_PROF_STREAK_OK       56
%define RMGR_PROF_STREAK_BAD      60

%define RMGR_CLASS_IDLE           0
%define RMGR_CLASS_USER_CHAT      1
%define RMGR_CLASS_MEM_SCAN       2
%define RMGR_CLASS_GUI_PAINT      3
%define RMGR_CLASS_COMPANION      4

%define RMGR_PERIODIC_INTERVAL    300
%define RMGR_SCAN_COOLDOWN_TICKS  150
%define RMGR_TICK_BUDGET          500
%define RMGR_PERIODIC_DFREE_THRESH 64
%define RMGR_THROTTLE_MIN         1
%define RMGR_THROTTLE_MAX         16
%define RMGR_SCORE_MAX            255
%define RMGR_SCORE_INIT           128

%endif

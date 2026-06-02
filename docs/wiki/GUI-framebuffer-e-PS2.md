# GUI, framebuffer e PS/2

## Framebuffer (`framebuffer.asm`)

| Simbolo | Descrizione |
|---------|-------------|
| `fb_init_from_mb2` | Addr, width, height, pitch, bpp da Multiboot2 |
| `fb_put_pixel` / `fb_xor_pixel` | Pixel singolo |
| `fb_fill_rect` | Rettangolo pieno (stack: color, h, w, y, x) |
| `fb_clear` | Sfondo `FB_COL_BG` |

## GFX (`gfx.asm`, `font8.asm`)

| Simbolo | Descrizione |
|---------|-------------|
| `font8_table` | Glyph 8×8 |
| `gfx_draw_char` | Un carattere (32–126) |
| `gfx_draw_string_at` | Stringa a (x,y) colore |

## GUI (`gui.asm`)

Layout: titolo, pannello log, pannello DarkMind, barra input (y≈4–24), status in basso.

| Funzione | Descrizione |
|----------|-------------|
| `gui_init` | Buffer linee AI, `gui_input_active=1` |
| `gui_poll` | Sync mouse, click, wheel, caret, redraw se `gui_dirty` |
| `gui_redraw` | Full redraw con hook RMGR act 7 |
| `gui_handle_key(al=char)` | Barra chat: char, backspace, tab→spazio, enter→`brain_think` |
| `gui_handle_click` | Click su barra → attiva input |
| `gui_log_line(esi)` | Aggiunge riga al log AI (wrap) |
| `gui_draw_input_bar` | Disegna `> ` + `gui_input` |
| `gui_format_kbd_dbg` | Riga debug `KBD sc=.. ch=.. n=..` |

### Debug tastiera

In status bar: ultimo scancode, carattere mappato, `keyboard_rx_count`. Se `n` non sale, QEMU non invia PS/2 (focus finestra).

## PS/2 (`keyboard.asm`, `mouse.asm`)

### `ps2_poll` (in `keyboard.asm`)

Drain porta `0x60`:

- Bit **AUX** in status → `mouse_scancode`
- Altrimenti → `keyboard_scancode`
- Mid-packet mouse interrotto da byte kbd → reset `mouse_packet_idx`

### Tastiera

| Funzione | Descrizione |
|----------|-------------|
| `keyboard_init` | Drain, config i8042 (translate+IRQ), `0xAE` enable |
| `keyboard_scancode` | Set1 + fallback `scancode_map_set2` |
| `keyboard_poll` | `ps2_poll` + dequeue buffer anello 128 |
| `keyboard_may_type` | Sempre 1 (legacy) |

### Mouse

| Funzione | Descrizione |
|----------|-------------|
| `mouse_init` | Solo `0xA8` AUX + F6/F4 (no rewrite config KB) |
| `mouse_scancode` | Pacchetto 3 byte, sync bit 3 |
| `mouse_x` / `mouse_y` / `mouse_buttons` / `mouse_wheel_delta` | Stato |

## Flusso kernel GUI

```
ps2_poll → keyboard_poll → (se char) gui_handle_key → gui_poll → companion_poll → brain_step → hlt
```

**Nota:** `gui_handle_key` riceve `al` **prima** di `gui_poll` (evita clobber di `al`).

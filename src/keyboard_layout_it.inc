; Italian (IT) PS/2 set-1 scancode maps — physical key positions
; Latin-1 bytes for àèéìòùç£§ (drawn via gfx_draw_char extended glyphs)

%define KBD_IT_AGRAVE   0xE0
%define KBD_IT_EGRAVE   0xE8
%define KBD_IT_EACUTE   0xE9
%define KBD_IT_IGRAVE   0xEC
%define KBD_IT_OGRAVE   0xF2
%define KBD_IT_UGRAVE   0xF9
%define KBD_IT_CCEDIL   0xE7
%define KBD_IT_POUND    0xA3
%define KBD_IT_SECTION  0xA7

scancode_map:
    db 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 39, KBD_IT_IGRAVE, 8
    db 9, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', KBD_IT_EGRAVE, '+', 10
    db 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', KBD_IT_OGRAVE, KBD_IT_AGRAVE, '\', 0
    db KBD_IT_UGRAVE, 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '-', 0, '*', 0
    db ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

scancode_map_shift:
    db 0, 27, '!', '"', KBD_IT_POUND, '$', '%', '&', '/', '(', ')', '=', '?', '^', 8
    db 9, 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', KBD_IT_EACUTE, '*', 10
    db 0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', KBD_IT_CCEDIL, KBD_IT_UGRAVE, '~', 0
    db KBD_IT_SECTION, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ';', ':', '_', 0, '*', 0
    db ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

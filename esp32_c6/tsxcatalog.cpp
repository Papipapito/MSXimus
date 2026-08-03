// tsxcatalog.cpp - ver tsxcatalog.h. DFA byte a byte, sin memoria dinamica.
#include "tsxcatalog.h"

#include <string.h>

namespace {
// claves hasta los dos puntos (el JSON real lleva espacio tras ':'; el estado
// await_q tolera cualquier separacion hasta la comilla de apertura del valor)
const char KEY_FS[] = "\"fileSize\":";
const char KEY_NM[] = "\"TOSEC.NAME\":";
const char KEY_LD[] = "\"TSX.LOAD\":";
const char KEY_SC[] = "\"sectionCount\":";

// avanza el contador de match de una clave con el byte c
inline void advance(uint8_t& m, const char* key, uint8_t c) {
    if ((char)c == key[m]) m++;
    else m = ((char)c == key[0]) ? 1 : 0;
}

// codifica un codepoint BMP como UTF-8 en buf (respetando el tope cap)
void put_utf8(char* buf, uint16_t* len, uint16_t cap, uint16_t cp) {
    if (cp < 0x80) {
        if (*len < cap) buf[(*len)++] = (char)cp;
    } else if (cp < 0x800) {
        if (*len < cap) buf[(*len)++] = (char)(0xC0 | (cp >> 6));
        if (*len < cap) buf[(*len)++] = (char)(0x80 | (cp & 0x3F));
    } else {
        if (*len < cap) buf[(*len)++] = (char)(0xE0 | (cp >> 12));
        if (*len < cap) buf[(*len)++] = (char)(0x80 | ((cp >> 6) & 0x3F));
        if (*len < cap) buf[(*len)++] = (char)(0x80 | (cp & 0x3F));
    }
}

inline int hexval(uint8_t c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return 0;
}

void classify_load(CatScanner* s, CatEntry* out) {
    // NUL-terminar a la longitud LOGICA: el cierre normal ('"') ya lo hace, pero
    // si el stream se corta dentro del valor TSX.LOAD (descarga truncada) ese
    // cierre no llega y load[llen..] conservaria texto rancio de la entrada
    // anterior -> strstr clasificaria mal. llen<=sizeof(load)-1, indice valido.
    s->load[s->llen] = 0;
    if (s->llen == 0) { out->loadcmd = 2; return; }
    if (strstr(s->load, "BLOAD") != nullptr) out->loadcmd = 1;
    else if (strstr(s->load, "RUN") != nullptr) out->loadcmd = 0;
    else out->loadcmd = 2;
}

// vuelca la entrada en construccion a *out (si esta completa)
int emit(CatScanner* s, CatEntry* out) {
    if (!s->have_size || !s->have_name) return 0;
    memcpy(out->name, s->name, CAT_NAME_MAX);
    out->name[CAT_NAME_MAX - 1] = 0;
    out->sizeBytes = s->size;
    classify_load(s, out);
    s->have_size = s->have_name = 0;
    s->nlen = 0; s->llen = 0; s->size = 0;
    s->load[0] = 0; s->name[0] = 0;
    return 1;
}
}  // namespace

void cat_reset(CatScanner* s) {
    memset(s, 0, sizeof(*s));
}

int cat_feed(CatScanner* s, uint8_t c, CatEntry* out) {
    int emitted = 0;

    switch (s->field) {
    case 0:                            // buscando la proxima clave
        // sectionCount (numero, sin comillas): digitos tras la clave
        if (s->sc_digits) {
            if (c >= '0' && c <= '9') { s->section = s->section * 10 + (c - '0'); break; }
            if (c == ' ') break;       // tolera espacios tras ':'
            s->sc_digits = 0;          // fin del numero: siguen las claves
        }
        advance(s->m_fs, KEY_FS, c);
        advance(s->m_nm, KEY_NM, c);
        advance(s->m_ld, KEY_LD, c);
        advance(s->m_sc, KEY_SC, c);
        if (s->m_sc == sizeof(KEY_SC) - 1) {
            s->m_fs = s->m_nm = s->m_ld = s->m_sc = 0;
            s->section = 0; s->sc_digits = 1;
        } else if (s->m_fs == sizeof(KEY_FS) - 1) {
            // empieza el fileSize de la SIGUIENTE entrada -> emite la anterior
            emitted = emit(s, out);
            s->m_fs = s->m_nm = s->m_ld = s->m_sc = 0;
            s->field = 1; s->size = 0; s->await_q = 1;
        } else if (s->m_nm == sizeof(KEY_NM) - 1) {
            s->m_fs = s->m_nm = s->m_ld = s->m_sc = 0;
            s->field = 2; s->nlen = 0; s->esc = 0; s->uskip = 0; s->await_q = 1;
        } else if (s->m_ld == sizeof(KEY_LD) - 1) {
            s->m_fs = s->m_nm = s->m_ld = s->m_sc = 0;
            s->field = 3; s->llen = 0; s->esc = 0; s->uskip = 0; s->await_q = 1;
        }
        break;

    case 1:                            // valor de fileSize: digitos (ignora '.')
        if (s->await_q) { if (c == '"') s->await_q = 0; break; }
        if (c >= '0' && c <= '9') s->size = s->size * 10u + (c - '0');
        else if (c == '"') { s->have_size = 1; s->field = 0; }
        // '.' (miles) y cualquier otra cosa se ignoran
        break;

    case 2:                            // valor de TOSEC.NAME (con escapes JSON)
        if (s->await_q) { if (c == '"') s->await_q = 0; break; }
        if (s->uskip) {                             // \uXXXX -> UTF-8 EXACTO (el
            s->uhex = (uint16_t)(s->uhex << 4) | hexval(c);   // nombre se reusa
            if (--s->uskip == 0)                    // para la URL de descarga)
                put_utf8(s->name, &s->nlen, CAT_NAME_MAX - 1, s->uhex);
            break;
        }
        if (s->esc) {
            s->esc = 0;
            if (c == 'u') { s->uskip = 4; s->uhex = 0; break; }
            if (s->nlen < CAT_NAME_MAX - 1) s->name[s->nlen++] = (char)c;
        } else if (c == '\\') {
            s->esc = 1;
        } else if (c == '"') {                      // fin del valor
            s->name[s->nlen] = 0;
            s->have_name = 1;
            s->field = 0;
        } else {
            if (s->nlen < CAT_NAME_MAX - 1) s->name[s->nlen++] = (char)c;
        }
        break;

    case 3: {                          // valor de TSX.LOAD (con escapes JSON)
        if (s->await_q) { if (c == '"') s->await_q = 0; break; }
        if (s->uskip) {                             // en LOAD los \uXXXX no
            if (--s->uskip == 0) {}                 // importan: se descartan
            break;
        }
        uint16_t ll = s->llen;
        if (s->esc) {
            s->esc = 0;
            if (c == 'u') { s->uskip = 4; break; }
            if (ll < sizeof(s->load) - 1) s->load[ll++] = (char)c;
        } else if (c == '\\') {
            s->esc = 1;
        } else if (c == '"') {
            s->load[ll] = 0;
            s->field = 0;
        } else {
            if (ll < sizeof(s->load) - 1) s->load[ll++] = (char)c;
        }
        s->llen = (uint8_t)ll;
        break; }
    }
    return emitted;
}

int cat_end(CatScanner* s, CatEntry* out) {
    return emit(s, out);
}

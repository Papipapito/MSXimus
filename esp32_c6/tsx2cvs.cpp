// tsx2cvs.cpp - ver tsx2cvs.h. Port fiel de tsx2rom (Python); cada seccion
// referencia la funcion Python equivalente. Con chequeo de limites ESTRICTO
// (esto corre en un ESP: nada de leer fuera del buffer con cintas corruptas).
//
// SEGURIDAD DE ENTEROS: size_t en el ESP32 es de 32 bits. Los campos de
// longitud DWORD (bloques 0x4B y 0x35) los controla el fichero, que viene de
// internet. Nunca los validamos como "o + K + ln > n" (esa suma envuelve
// mod 2^32 si ln es enorme y omite la cota), sino como "ln > n - (o + K)":
// la guarda previa garantiza o+K <= n, asi que la resta no desborda por abajo
// y la comparacion es exacta. El Python original usa enteros de precision
// arbitraria y no tiene este problema; esta es la unica divergencia necesaria.
#include "tsx2cvs.h"

#include <string.h>

namespace {

// cabecera de sincronismo del CAS (tsxcore.SYNC)
const uint8_t SYNC[8] = {0x1F, 0xA6, 0xDE, 0xBA, 0xCC, 0x13, 0x7D, 0x74};

struct Blk { size_t off; size_t len; };   // payload = in[off .. off+len)

inline uint16_t u16(const uint8_t* d, size_t o) {
    return (uint16_t)(d[o] | (d[o + 1] << 8));
}
inline uint32_t u24(const uint8_t* d, size_t o) {
    return (uint32_t)d[o] | ((uint32_t)d[o + 1] << 8) | ((uint32_t)d[o + 2] << 16);
}
inline uint32_t u32(const uint8_t* d, size_t o) {
    return (uint32_t)d[o] | ((uint32_t)d[o + 1] << 8) |
           ((uint32_t)d[o + 2] << 16) | ((uint32_t)d[o + 3] << 24);
}

// tape_image._is_header_block: >=10 bytes, primer byte D3/D0/EA repetido x10
bool is_header_block(const uint8_t* p, size_t len) {
    if (len < 10) return false;
    uint8_t m = p[0];
    if (m != 0xD3 && m != 0xD0 && m != 0xEA) return false;
    for (int i = 1; i < 10; i++)
        if (p[i] != m) return false;
    return true;
}

// tsxcore.parse_tsx: recorre los bloques TZX y recoge los que llevan bytes
// (#10/#11/#14/#4B). #15 = error (audio directo). Devuelve nullptr si OK.
const char* parse_tsx(const uint8_t* d, size_t n, std::vector<Blk>& blocks) {
    size_t o = 10;                        // tras "ZXTape!\x1a" + version (2)
    while (o < n) {
        uint8_t bid = d[o];
        switch (bid) {
        case 0x10: {                      // standard speed data
            if (o + 5 > n) return "TSX truncado (bloque 10)";
            size_t ln = u16(d, o + 3);
            if (o + 5 + ln > n) return "TSX truncado (payload 10)";
            blocks.push_back({o + 5, ln});
            o += 5 + ln;
            break; }
        case 0x11: {                      // turbo speed data
            if (o + 19 > n) return "TSX truncado (bloque 11)";
            size_t ln = u24(d, o + 16);
            if (o + 19 + ln > n) return "TSX truncado (payload 11)";
            blocks.push_back({o + 19, ln});
            o += 19 + ln;
            break; }
        case 0x12: o += 5; break;         // pure tone
        case 0x13:                        // pulse sequence
            if (o + 2 > n) return "TSX truncado (bloque 13)";
            o += 2 + 2 * (size_t)d[o + 1];
            break;
        case 0x14: {                      // pure data
            if (o + 11 > n) return "TSX truncado (bloque 14)";
            size_t ln = u24(d, o + 8);
            if (o + 11 + ln > n) return "TSX truncado (payload 14)";
            blocks.push_back({o + 11, ln});
            o += 11 + ln;
            break; }
        case 0x15:                        // direct recording
            return "bloque #15 (audio directo): cinta no convertible a bytes";
        case 0x20: o += 3; break;         // pause / stop
        case 0x21:                        // group start
            if (o + 2 > n) return "TSX truncado (bloque 21)";
            o += 2 + (size_t)d[o + 1];
            break;
        case 0x22: o += 1; break;         // group end
        case 0x24: o += 3; break;         // loop start
        case 0x25: o += 1; break;         // loop end
        case 0x30:                        // text description
            if (o + 2 > n) return "TSX truncado (bloque 30)";
            o += 2 + (size_t)d[o + 1];
            break;
        case 0x31:                        // message
            if (o + 3 > n) return "TSX truncado (bloque 31)";
            o += 3 + (size_t)d[o + 2];
            break;
        case 0x32:                        // archive info
            if (o + 3 > n) return "TSX truncado (bloque 32)";
            o += 3 + (size_t)u16(d, o + 1);
            break;
        case 0x33:                        // hardware type
            if (o + 2 > n) return "TSX truncado (bloque 33)";
            o += 2 + 3 * (size_t)d[o + 1];
            break;
        case 0x35: {                      // custom info
            if (o + 0x15 > n) return "TSX truncado (bloque 35)";
            size_t ln = u32(d, o + 0x11);              // DWORD del fichero (u32)
            if (ln > n - (o + 0x15))                   // resta: no desborda (32b)
                return "TSX truncado (payload 35)";
            o += 0x15 + ln;
            break; }
        case 0x4B: {                      // MSX KCS (el importante)
            if (o + 17 > n) return "TSX truncado (bloque 4B)";
            size_t ln = u32(d, o + 1);    // longitud (u32) desde o+5, incluye
                                          // 12 bytes de params antes del payload
            if (ln < 12) return "bloque 4B invalido (len<12)";
            if (ln > n - (o + 5))         // resta: no desborda (ver cabecera)
                return "TSX truncado (payload 4B)";
            blocks.push_back({o + 17, ln - 12});   // payload = o+17 .. o+5+ln
            o += 5 + ln;
            break; }
        case 0x5A: o += 10; break;        // glue block
        default:
            return "bloque TZX desconocido";
        }
    }
    if (blocks.empty()) return "sin bloques de datos en el TSX";
    return nullptr;
}

// tsxcore.parse_cas: trocea por la cabecera SYNC. El ULTIMO bloque pierde el
// padding de ceros del final (fidelidad con payload.rstrip(b"\x00")).
const char* parse_cas(const uint8_t* d, size_t n, std::vector<Blk>& blocks) {
    // find(SYNC)
    size_t i = (size_t)-1;
    for (size_t k = 0; k + 8 <= n; k++)
        if (memcmp(d + k, SYNC, 8) == 0) { i = k; break; }
    if (i == (size_t)-1) return "no es un CAS valido (sin cabecera de sync)";
    while (i != (size_t)-1) {
        size_t j = (size_t)-1;
        for (size_t k = i + 8; k + 8 <= n; k++)
            if (memcmp(d + k, SYNC, 8) == 0) { j = k; break; }
        size_t end = (j != (size_t)-1) ? j : n;
        size_t len = end - (i + 8);
        if (j == (size_t)-1)              // ultimo bloque: rstrip de ceros
            while (len > 0 && d[i + 8 + len - 1] == 0x00) len--;
        blocks.push_back({i + 8, len});
        i = j;
    }
    return nullptr;
}

}  // namespace

// tape_image.build + mkstream: emite el CVS1 (descriptores INLINE)
const char* tsx2cvs(const uint8_t* in, size_t in_len, std::vector<uint8_t>& out) {
    if (in == nullptr || in_len < 8) return "fichero vacio o demasiado corto";
    std::vector<Blk> blocks;
    const char* err;
    if (memcmp(in, "ZXTape!\x1a", 8) == 0) {
        err = parse_tsx(in, in_len, blocks);
    } else {
        // load_tape: si hay SYNC en los primeros 16 bytes -> CAS; si no, CAS
        // igualmente como respaldo (la extension no llega hasta aqui)
        err = parse_cas(in, in_len, blocks);
    }
    if (err) return err;
    if (blocks.size() > 0xFFFF) return "demasiados bloques";

    out.clear();
    size_t total = 6;
    for (size_t i = 0; i < blocks.size(); i++) total += 4 + blocks[i].len;
    out.reserve(total);
    out.push_back('C'); out.push_back('V'); out.push_back('S'); out.push_back('1');
    out.push_back((uint8_t)(blocks.size() & 0xFF));
    out.push_back((uint8_t)(blocks.size() >> 8));
    for (size_t i = 0; i < blocks.size(); i++) {
        const Blk& b = blocks[i];
        if (b.len > 0xFFFF) return "bloque de mas de 64KB";
        uint8_t pilot = (i == 0 || is_header_block(in + b.off, b.len)) ? 1 : 0;
        out.push_back((uint8_t)(b.len & 0xFF));
        out.push_back((uint8_t)(b.len >> 8));
        out.push_back(pilot);
        out.push_back(0);
        out.insert(out.end(), in + b.off, in + b.off + b.len);
    }
    return nullptr;
}

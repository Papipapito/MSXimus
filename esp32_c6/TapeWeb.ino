/*
 * TapeWeb.ino - Comandos UNAPI custom de CINTA para el MSXnano/MSXimus.
 * Une el catalogo web (tsxcatalog), el conversor (tsx2cvs) y el streaming
 * (Tape.ino). Protocolo del MSX (opcode + tam(2B BE) + payload, respuestas
 * SendResponse/SendQuickResponse como el resto del firmware ducasp):
 *
 *  'L' TSX_LIST   {letra, pag_servidor, offset}  -> lista para el navegador:
 *        resp: [total_letra u16 LE][pag_count u8][n u8] + n x entrada
 *              entrada = {idx u8, sizeKB u16 LE, loadcmd u8, nombre ASCIIZ<=48}
 *        (nombres transliterados a ASCII para la pantalla del MSX; el nombre
 *         EXACTO UTF-8 vive en la cache del C6 y se usa para la URL)
 *  'K' TSX_PLAY   {letra, pag_servidor, idx} -> descarga el .tsx del catalogo
 *        y lo reproduce (tapePlay). Payload vacio = STOP.
 *        resp: QuickResponse OK/error (puede tardar 2-5s: descarga+conversion;
 *        el MSX debe usar timeout generoso, como en UPDATE_FW)
 *  'k' TSX_STATUS {} -> resp 6 bytes: {busy u8, err u8,
 *        sentPag u16 LE, totalPag u16 LE}  (paginas de 256 bytes del stream)
 *  'X' TSX_UPLOAD  {size u32 LE} -> prepara subida desde el MSX (modo SD
 *        offline: el menu lee el .tsx/.cas de la SD y lo sube por aqui)
 *  'x' TSX_UPBLOCK {chunk <=2048B} -> anexa; al completar size convierte y
 *        reproduce. resp de cada bloque: OK; del ultimo: OK/error conversion.
 */

#include "tsxcatalog.h"
#include "tsx2cvs.h"
#include <vector>
#include <functional>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include "UNAPIESP.h"

#define TSX_HOST      "tsx.eslamejor.com"
#define TSX_REFERER   "https://tsx.eslamejor.com/"
#define TSX_UA        "MSXnano-tape/1.0"
#define TSX_WINDOW    16      // entradas max por respuesta LIST
#define TSX_PAGE_MAX  50      // entradas por pagina del servidor
#define TSX_NAME_TX   48      // nombre (ASCII) enviado al MSX
#define TSX_MAX_FILE  (256u*1024u)   // .tsx mas grande aceptado

// ---- cache de la ultima pagina del catalogo pedida ----
static CatEntry g_cat[TSX_PAGE_MAX];
static int      g_catN      = -1;    // -1 = vacia
static uint16_t g_catTotal  = 0;     // sectionCount de la letra
static char     g_catLetter = 0;
static uint8_t  g_catPage   = 0xFF;
static uint8_t  g_tsxErr    = 0;     // ultimo error (para STATUS)

// ---- subida desde el MSX (modo SD offline) ----
static std::vector<uint8_t> g_upBuf;
static uint32_t g_upExpected = 0;

// del firmware base / otros .ino
extern bool loadCACertForClient(WiFiClientSecure *client);

// ============================================================
// HTTP GET por streaming: entrega el cuerpo byte a byte a un callback.
// devuelve UNAPI_ERR_*. (std::function y NO template: el generador de
// prototipos del IDE Arduino se atraganta con templates en .ino)
// ============================================================
static uint8_t tsxHttpGetStream(const String& url,
                                std::function<void(uint8_t)> onByte) {
    if (WiFi.status() != WL_CONNECTED) return UNAPI_ERR_NO_NETWORK;
    WiFiClientSecure cli;
    if (!loadCACertForClient(&cli))
        cli.setInsecure();            // sin bundle de certs: seguir igualmente
    cli.setTimeout(15000);
    HTTPClient http;
    http.setUserAgent(TSX_UA);
    if (!http.begin(cli, url)) return UNAPI_ERR_NO_CONN;
    http.addHeader("Referer", TSX_REFERER);
    int code = http.GET();
    if (code != HTTP_CODE_OK) { http.end(); return UNAPI_ERR_NO_DATA; }
    int remaining = http.getSize();   // -1 = chunked / Content-Length ausente
    WiFiClient* st = http.getStreamPtr();
    unsigned long idle = millis();
    bool stalled = false;             // salimos por timeout de datos (no fin limpio)
    while (http.connected() && (remaining > 0 || remaining == -1)) {
        int av = st->available();
        if (av <= 0) {
            if (millis() - idle > 15000) { stalled = true; break; }
            delay(1);
            continue;
        }
        idle = millis();
        while (av--) {
            int b = st->read();
            if (b < 0) break;
            onByte((uint8_t)b);
            if (remaining > 0 && --remaining == 0) break;
        }
    }
    http.end();
    // Con Content-Length: remaining>0 = truncado. Sin el (remaining==-1) no
    // podemos verificar la longitud, pero SI detectamos el estancamiento: un
    // corte a mitad se va por el timeout de datos -> error, no OK silencioso.
    return (remaining > 0 || stalled) ? UNAPI_ERR_NO_DATA : UNAPI_ERR_OK;
}

// letra del MSX -> idx del catalogo ('A'..'Z' tal cual; otro = "0-9")
static String tsxIdxOf(char letter) {
    if (letter >= 'a' && letter <= 'z') letter -= 32;
    if (letter >= 'A' && letter <= 'Z') return String(letter);
    return String("0-9");
}

// asegura la pagina (letra, pag) en la cache. devuelve UNAPI_ERR_*.
static uint8_t tsxEnsurePage(char letter, uint8_t page) {
    if (g_catN >= 0 && g_catLetter == letter && g_catPage == page)
        return UNAPI_ERR_OK;
    g_catN = -1;
    static CatScanner sc;             // grande: fuera de la pila
    cat_reset(&sc);
    int n = 0;
    String url = String("https://") + TSX_HOST + "/index_back.php?page=" +
                 String((int)page) + "&idx=" + tsxIdxOf(letter);
    CatEntry e;
    uint8_t err = tsxHttpGetStream(url, [&](uint8_t b) {
        if (n < TSX_PAGE_MAX && cat_feed(&sc, b, &e)) g_cat[n++] = e;
    });
    if (err != UNAPI_ERR_OK) return err;
    if (n < TSX_PAGE_MAX && cat_end(&sc, &e)) g_cat[n++] = e;
    if (n == 0) return UNAPI_ERR_NO_DATA;   // letra/pagina sin entradas (o 404)
    g_catN = n; g_catTotal = sc.section;
    g_catLetter = letter; g_catPage = page;
    return UNAPI_ERR_OK;
}

// UTF-8 -> ASCII para la pantalla del MSX (acentos comunes; resto '?')
static void tsxAsciiFold(const char* in, char* out, int cap) {
    int o = 0;
    for (const uint8_t* p = (const uint8_t*)in; *p && o < cap - 1; p++) {
        uint8_t c = *p;
        if (c < 0x80) { out[o++] = (char)c; continue; }
        if (c == 0xC3 && p[1]) {
            uint8_t n = p[1]; p++;
            char t = '?';
            switch (n) {
            case 0x81: case 0xA1: t = (n & 0x20) ? 'a' : 'A'; break; // A/a aguda
            case 0x89: case 0xA9: t = (n & 0x20) ? 'e' : 'E'; break;
            case 0x8D: case 0xAD: t = (n & 0x20) ? 'i' : 'I'; break;
            case 0x93: case 0xB3: t = (n & 0x20) ? 'o' : 'O'; break;
            case 0x9A: case 0xBA: t = (n & 0x20) ? 'u' : 'U'; break;
            case 0x91: case 0xB1: t = (n & 0x20) ? 'n' : 'N'; break;
            case 0x9C: case 0xBC: t = (n & 0x20) ? 'u' : 'U'; break;
            default: t = '?'; break;
            }
            out[o++] = t;
            continue;
        }
        // otras secuencias multibyte: consumir continuaciones y poner '?'
        if (c >= 0xE0) { if (p[1]) p++; if (p[1]) p++; }
        else if (c >= 0xC0) { if (p[1]) p++; }
        out[o++] = '?';
    }
    out[o] = 0;
}

// url-encode del nombre TOSEC (espacios, parentesis, corchetes, apostrofos...)
static String tsxUrlEncode(const char* s) {
    static const char hex[] = "0123456789ABCDEF";
    String r;
    for (const uint8_t* p = (const uint8_t*)s; *p; p++) {
        uint8_t c = *p;
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
            r += (char)c;
        else { r += '%'; r += hex[c >> 4]; r += hex[c & 15]; }
    }
    return r;
}

// ============================================================
// Comandos (los llama received_data_parser del .ino principal)
// ============================================================
void tsxCmdList(uint8_t letter, uint8_t page, uint8_t offset) {
    uint8_t err = tsxEnsurePage((char)letter, page);
    g_tsxErr = err;
    if (err != UNAPI_ERR_OK) { SendQuickResponse(CUSTOM_F_TSX_LIST, err); return; }
    static uint8_t buf[4 + TSX_WINDOW * (4 + TSX_NAME_TX + 1)];
    unsigned bl = 0;
    buf[bl++] = (uint8_t)(g_catTotal & 0xFF);
    buf[bl++] = (uint8_t)(g_catTotal >> 8);
    buf[bl++] = (uint8_t)g_catN;               // entradas en ESTA pagina
    unsigned cpos = bl++;                      // hueco para n de la ventana
    uint8_t n = 0;
    for (uint8_t i = offset; i < g_catN && n < TSX_WINDOW; i++, n++) {
        const CatEntry& e = g_cat[i];
        uint16_t kb = (uint16_t)((e.sizeBytes + 1023) / 1024);
        buf[bl++] = i;
        buf[bl++] = (uint8_t)(kb & 0xFF);
        buf[bl++] = (uint8_t)(kb >> 8);
        buf[bl++] = e.loadcmd;
        char nm[TSX_NAME_TX + 1];
        tsxAsciiFold(e.name, nm, sizeof(nm));
        unsigned l = strlen(nm);
        memcpy(&buf[bl], nm, l + 1);
        bl += l + 1;
    }
    buf[cpos] = n;
    SendResponse(CUSTOM_F_TSX_LIST, UNAPI_ERR_OK, bl, buf);
}

void tsxCmdPlay(uint8_t letter, uint8_t page, uint8_t idx) {
    uint8_t err = tsxEnsurePage((char)letter, page);
    if (err == UNAPI_ERR_OK && idx >= g_catN) err = UNAPI_ERR_INV_PARAM;
    if (err == UNAPI_ERR_OK && tapeBusy()) err = UNAPI_ERR_INV_OPER;
    if (err != UNAPI_ERR_OK) {
        g_tsxErr = err;
        SendQuickResponse(CUSTOM_F_TSX_PLAY, err);
        return;
    }
    const CatEntry& e = g_cat[idx];
    // memoria: descarga (~size) + stream CVS (~size) + margen
    if (e.sizeBytes > TSX_MAX_FILE ||
        ESP.getFreeHeap() < e.sizeBytes * 2 + 40000) {
        g_tsxErr = UNAPI_ERR_BUFFER;
        SendQuickResponse(CUSTOM_F_TSX_PLAY, UNAPI_ERR_BUFFER);
        return;
    }
    std::vector<uint8_t> tsx;
    tsx.reserve(e.sizeBytes);
    String url = String("https://") + TSX_HOST + "/tsx-files/" +
                 tsxUrlEncode(e.name) + ".tsx";
    // Cota = e.sizeBytes (lo reservado y lo que el guard de heap comprobo): si
    // el catalogo infra-reportara el tamano, no crecemos el vector por encima
    // del heap verificado (un fichero mas grande de lo anunciado se trunca y
    // tsx2cvs lo rechazara). fileSize del catalogo = tamano exacto del .tsx.
    err = tsxHttpGetStream(url, [&](uint8_t b) {
        if (tsx.size() < e.sizeBytes) tsx.push_back(b);
    });
    if (err != UNAPI_ERR_OK) {
        g_tsxErr = err;
        SendQuickResponse(CUSTOM_F_TSX_PLAY, err);
        return;
    }
    const char* cerr = tapePlay(tsx.data(), tsx.size());
    g_tsxErr = cerr ? UNAPI_ERR_INV_PARAM : UNAPI_ERR_OK;
    SendQuickResponse(CUSTOM_F_TSX_PLAY, g_tsxErr);
}

void tsxCmdStop() {
    tapeStop();
    g_upBuf.clear(); g_upBuf.shrink_to_fit(); g_upExpected = 0;
    g_tsxErr = UNAPI_ERR_OK;
    SendQuickResponse(CUSTOM_F_TSX_PLAY, UNAPI_ERR_OK);
}

void tsxCmdStatus() {
    uint8_t st[6];
    uint16_t sent  = (uint16_t)(tapeSent() >> 8);   // paginas de 256B
    uint16_t total = (uint16_t)(tapeTotal() >> 8);
    st[0] = tapeBusy() ? 1 : 0;
    st[1] = g_tsxErr;
    st[2] = (uint8_t)(sent & 0xFF);  st[3] = (uint8_t)(sent >> 8);
    st[4] = (uint8_t)(total & 0xFF); st[5] = (uint8_t)(total >> 8);
    SendResponse(CUSTOM_F_TSX_STATUS, UNAPI_ERR_OK, 6, st);
}

// TSX_FIND: busca 'texto' (case/acento-insensible) en el catalogo de la letra
// inicial del texto, paginando; al primer match descarga y reproduce.
// Respuesta: SendResponse OK + [loadcmd u8][nombreZ ASCII] (para que el MSX
// muestre que juego esta cargando y con que comando arrancarlo). Errores:
// UNAPI_ERR_NO_DATA = sin coincidencias.
void tsxCmdFind(const uint8_t* data, unsigned len) {
    if (len == 0 || len > 60) {
        SendQuickResponse(CUSTOM_F_TSX_FIND, UNAPI_ERR_INV_PARAM);
        return;
    }
    if (tapeBusy()) {
        SendQuickResponse(CUSTOM_F_TSX_FIND, UNAPI_ERR_INV_OPER);
        return;
    }
    char needle[64];
    memcpy(needle, data, len);
    needle[len] = 0;
    // a minusculas ASCII para comparar
    for (char* p = needle; *p; p++)
        if (*p >= 'A' && *p <= 'Z') *p += 32;
    char letter = needle[0];
    // buscar paginando la letra (el catalogo pagina de 50 en 50)
    for (uint8_t page = 0; page < 8; page++) {
        uint8_t err = tsxEnsurePage(letter, page);
        if (err != UNAPI_ERR_OK) {
            if (page == 0) { g_tsxErr = err; SendQuickResponse(CUSTOM_F_TSX_FIND, err); return; }
            break;                    // paginas agotadas
        }
        for (uint8_t i = 0; i < g_catN; i++) {
            char hay[TSX_NAME_TX + 1];
            tsxAsciiFold(g_cat[i].name, hay, sizeof(hay));
            for (char* p = hay; *p; p++)
                if (*p >= 'A' && *p <= 'Z') *p += 32;
            if (strstr(hay, needle) == nullptr) continue;
            // match: descargar + reproducir (reusa el camino de PLAY)
            const CatEntry& e = g_cat[i];
            if (e.sizeBytes > TSX_MAX_FILE ||
                ESP.getFreeHeap() < e.sizeBytes * 2 + 40000) {
                g_tsxErr = UNAPI_ERR_BUFFER;
                SendQuickResponse(CUSTOM_F_TSX_FIND, UNAPI_ERR_BUFFER);
                return;
            }
            std::vector<uint8_t> tsx;
            tsx.reserve(e.sizeBytes);
            String url = String("https://") + TSX_HOST + "/tsx-files/" +
                         tsxUrlEncode(e.name) + ".tsx";
            // cota = e.sizeBytes (= lo reservado y lo verificado por el guard de
            // heap); ver la nota identica en tsxCmdPlay.
            err = tsxHttpGetStream(url, [&](uint8_t b) {
                if (tsx.size() < e.sizeBytes) tsx.push_back(b);
            });
            if (err != UNAPI_ERR_OK) {
                g_tsxErr = err;
                SendQuickResponse(CUSTOM_F_TSX_FIND, err);
                return;
            }
            const char* cerr = tapePlay(tsx.data(), tsx.size());
            if (cerr) {
                g_tsxErr = UNAPI_ERR_INV_PARAM;
                SendQuickResponse(CUSTOM_F_TSX_FIND, UNAPI_ERR_INV_PARAM);
                return;
            }
            // OK: devolver loadcmd + nombre plegado a ASCII
            uint8_t resp[2 + TSX_NAME_TX];
            resp[0] = e.loadcmd;
            char nm[TSX_NAME_TX + 1];
            tsxAsciiFold(e.name, nm, sizeof(nm));
            unsigned l = strlen(nm);
            memcpy(&resp[1], nm, l + 1);
            g_tsxErr = UNAPI_ERR_OK;
            SendResponse(CUSTOM_F_TSX_FIND, UNAPI_ERR_OK, 2 + l, resp);
            return;
        }
        if (g_catN < TSX_PAGE_MAX) break;   // ultima pagina de la letra
    }
    g_tsxErr = UNAPI_ERR_NO_DATA;
    SendQuickResponse(CUSTOM_F_TSX_FIND, UNAPI_ERR_NO_DATA);
}

void tsxCmdUploadStart(const uint8_t* data, unsigned len) {
    if (len != 4) { SendQuickResponse(CUSTOM_F_TSX_UPLOAD, UNAPI_ERR_INV_PARAM); return; }
    uint32_t size = (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
                    ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
    if (size == 0 || size > TSX_MAX_FILE ||
        ESP.getFreeHeap() < size * 2 + 40000) {
        g_tsxErr = UNAPI_ERR_BUFFER;
        SendQuickResponse(CUSTOM_F_TSX_UPLOAD, UNAPI_ERR_BUFFER);
        return;
    }
    if (tapeBusy()) tapeStop();
    g_upBuf.clear();
    g_upBuf.reserve(size);
    g_upExpected = size;
    g_tsxErr = UNAPI_ERR_OK;
    SendQuickResponse(CUSTOM_F_TSX_UPLOAD, UNAPI_ERR_OK);
}

void tsxCmdUploadBlock(const uint8_t* data, unsigned len) {
    if (g_upExpected == 0 || g_upBuf.size() + len > g_upExpected) {
        SendQuickResponse(CUSTOM_F_TSX_UPBLOCK, UNAPI_ERR_INV_PARAM);
        return;
    }
    g_upBuf.insert(g_upBuf.end(), data, data + len);
    if (g_upBuf.size() < g_upExpected) {
        SendQuickResponse(CUSTOM_F_TSX_UPBLOCK, UNAPI_ERR_OK);
        return;
    }
    // completo: convertir + reproducir, y liberar
    const char* cerr = tapePlay(g_upBuf.data(), g_upBuf.size());
    g_upBuf.clear(); g_upBuf.shrink_to_fit(); g_upExpected = 0;
    g_tsxErr = cerr ? UNAPI_ERR_INV_PARAM : UNAPI_ERR_OK;
    SendQuickResponse(CUSTOM_F_TSX_UPBLOCK, g_tsxErr);
}

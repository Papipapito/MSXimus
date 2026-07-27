// ============================================================================
// tsxcatalog - Parser INCREMENTAL del catalogo JSON de tsx.eslamejor.com.
//
// Una pagina del catalogo (index_back.php?page=N&idx=LETRA) son ~400KB de
// JSON (50 entradas con el detalle de bloques) -> NO se bufferiza: este DFA
// consume el stream byte a byte y va emitiendo entradas compactas.
// Portable C++11 sin Arduino (host-testable contra el JSON real cacheado).
//
// Orden FIJO de los campos que usamos dentro de cada entrada del array
// "files" (verificado contra el JSON real):
//   "fileSize":"139.568"  (puntos = separador de miles)
//   "TOSEC.NAME":"A Toda Maquina (1989)..."
//   "TSX.LOAD":"BLOAD\"CAS:\",R"   (puede faltar o estar vacio)
// Una entrada se emite al ver el fileSize de la SIGUIENTE, o en cat_end().
// ============================================================================
#ifndef TSXCATALOG_H
#define TSXCATALOG_H

#include <stddef.h>
#include <stdint.h>

#define CAT_NAME_MAX 96

struct CatEntry {
    char     name[CAT_NAME_MAX];   // TOSEC.NAME (truncado, ASCIIZ)
    uint32_t sizeBytes;            // fileSize en bytes
    uint8_t  loadcmd;              // 0=RUN"CAS: 1=BLOAD"CAS:",R 2=otro/desconocido
};

struct CatScanner {
    // progreso de match de las claves (contadores independientes)
    uint8_t  m_fs, m_nm, m_ld, m_sc;
    uint16_t section;              // "sectionCount" (entradas totales de la letra)
    uint8_t  sc_digits;            // leyendo los digitos de sectionCount
    // 0=buscando claves, 1=leyendo fileSize, 2=leyendo nombre, 3=leyendo load
    uint8_t  field;
    uint8_t  await_q;              // tras la clave: esperando la comilla de APERTURA
                                   // (tolera '"clave": "valor"' con o sin espacios)
    uint8_t  esc;                  // dentro de un valor: el byte anterior fue '\'
    uint8_t  uskip;                // digitos hex pendientes de un \uXXXX
    uint16_t uhex;                 // acumulador del codepoint \uXXXX
    // entrada en construccion
    char     name[CAT_NAME_MAX];
    uint16_t nlen;
    uint32_t size;
    uint8_t  have_size, have_name; // la entrada en curso tiene campos
    char     load[24];
    uint8_t  llen;
};

void cat_reset(CatScanner* s);
// Consume un byte. Devuelve 1 si una entrada COMPLETA quedo en *out.
int  cat_feed(CatScanner* s, uint8_t c, CatEntry* out);
// Fin del stream: devuelve 1 si quedaba una ultima entrada en *out.
int  cat_end(CatScanner* s, CatEntry* out);

#endif

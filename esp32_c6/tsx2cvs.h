// ============================================================================
// tsx2cvs - Conversor TSX/CAS -> stream CVS1 para la cinta virtual del
// MSXnano/MSXimus (cas_stream.v). Port C++ FIEL de tsx2rom (tsxcore.py +
// tape_image.py + mkstream.py); se verifica byte-exacto contra el Python
// compilando este MISMO fichero en el PC (host_test/).
//
// C++11 portable: SIN dependencias de Arduino (se usa igual en C6, S3 y PC).
//
// Formato CVS1 (lo consume cas_stream.v por UART):
//   "CVS1" + num_blocks(u16 LE) + por bloque: len(u16 LE) + pilot(u8) +
//   pad(u8=0) + payload.  pilot=1 (piloto largo) en el bloque 0 y en los
//   bloques cabecera MSX (10 bytes repetidos 0xD3/0xD0/0xEA).
// ============================================================================
#ifndef TSX2CVS_H
#define TSX2CVS_H

#include <stddef.h>
#include <stdint.h>
#include <vector>

// Convierte un TSX (firma "ZXTape!\x1a") o un CAS a stream CVS1.
// in/in_len: fichero completo en memoria. out: se rellena con el stream.
// Devuelve nullptr si OK, o un mensaje de error estatico si la cinta no es
// convertible (p.ej. bloque #15 de audio directo) o esta corrupta.
const char* tsx2cvs(const uint8_t* in, size_t in_len, std::vector<uint8_t>& out);

#endif

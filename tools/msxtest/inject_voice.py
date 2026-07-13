#!/usr/bin/env python3
"""inject_voice.py — mete la frase ADPCM en los segmentos 8-11 de msxtest.rom.

La zona plana del ROM (segs 0-3, 4000-BFFF) esta casi llena, asi que la voz
va en segmentos altos y el test la streamea conmutando el bank2 Konami-SCC
(thunk VozStreamSeg en RAM). CONSTANTES EN SYNC con msxtest.c:
    VOICE_SEG0=8  VOICE_LEN=<len de voz_adpcm.bin>  VOICE_DELTA=0x5C00

Uso:  python inject_voice.py <msxtest.rom> <voz_adpcm.bin>
El fichero de voz lo genera el pipeline TTS+encoder (ver memoria del
proyecto): WAV 16k -> recorte -> remuestreo a 49716*delta/65536 ->
encoder deltaT (tablas F1/F2 del Y8950) -> nibbles empaquetados (alto,bajo).
"""
import sys

SEG0 = 8
SEG_SIZE = 8192

rom_path, voz_path = sys.argv[1], sys.argv[2]
rom = bytearray(open(rom_path, 'rb').read())
voz = open(voz_path, 'rb').read()

assert len(rom) == 131072, f"ROM de {len(rom)} bytes (esperaba 128K)"
assert len(voz) <= 4 * SEG_SIZE, f"voz de {len(voz)} bytes > 32K"

off = SEG0 * SEG_SIZE
rom[off:off + len(voz)] = voz
open(rom_path, 'wb').write(rom)
print(f"voz de {len(voz)} bytes inyectada en seg {SEG0}+ (offset 0x{off:05X})")
print(f"RECUERDA: msxtest.c debe tener VOICE_LEN={len(voz)}u")

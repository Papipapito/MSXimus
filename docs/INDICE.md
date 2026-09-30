# Documentación del MSXimus

Índice general. Cada capítulo dice para quién es, en qué estado está y de qué fuente sale, para que se pueda escribir y revisar por separado.

El README del repositorio se queda corto a propósito: qué es, qué hace falta y cómo se instala. Todo lo demás vive aquí.

## Cómo está organizada

| Carpeta | Para quién | Qué contiene |
|---|---|---|
| `docs/manual/` | Quien tiene la placa y quiere usarla | Instalación, tarjeta SD, menú, ROMs, discos, WiFi, audio, vídeo, problemas |
| `docs/tecnica/` | Quien quiere entender o modificar el core | Arquitectura, puertos de E/S, mapas de memoria, pack de BIOS, V9968, SD y DMA, campañas de síntesis, simulación, changelog |
| `docs/historico/` | Nadie en particular | Los documentos del porte de julio de 2026 y los informes de la v2, tal cual se escribieron. Se conservan porque explican decisiones, pero ya no describen el estado actual |

Idioma: castellano. El manual de usuario se traducirá al inglés cuando esté cerrado, como el README. La referencia técnica se queda en castellano.

## Manual de usuario (`docs/manual/`)

| Nº | Capítulo | Estado | De dónde sale |
|---|---|---|---|
| 01 | [Qué es el MSXimus](manual/01-que-es.md): la máquina, lo que trae, lo que hace falta, lo que no es | **escrito** | README |
| 02 | [Instalación](manual/02-instalacion.md): la flash de la placa, el pack, el BL616, el ESP32-C6 con su cableado, actualizar | **escrito** | README, top.v |
| 03 | [La tarjeta SD](manual/03-tarjeta-sd.md): qué tarjeta, formato, qué poner y dónde, ficheros especiales, etiquetas, discos, editar desde el PC | **escrito** | menu_main.asm, srm_saves.asm, gm2.asm |
| 04 | [El menú de arranque](manual/04-menu.md): flujo de arranque, teclas del logo, navegador, lanzar ROM, lanzar disco, Ajustes, WiFi, File-Hunter, Pruebas, mensajes | **escrito** | menu_main.asm, gm2.asm, srm_saves.asm, test_menu.asm |
| 05 | [ROMs y mappers](manual/05-roms-mappers.md): la megaram, los siete mappers, cómo se decide, la SRAM y su guardado, el Game Master 2, ROMs que no lanzan | **escrito** | menu_main.asm, srm_saves.asm, gm2.asm, megaram.v |
| 06 | [MSX-DOS y Nextor](manual/06-msxdos-nextor.md): las dos versiones, arrancar en DOS, discos de imagen, rendimiento, otros sistemas | **escrito** | sd_rw_ports.inc, LEEMEs |
| 07 | [WiFi y File-Hunter](manual/07-wifi-file-hunter.md): qué pone el módulo, la tecla W, la tecla F paso a paso, mensajes, diagnóstico | **escrito** | menu_main.asm, ESP32-for-FPGA |
| 08 | [Audio](manual/08-audio.md): los chips, mono y estéreo, el volumen, lo comprobado, lo que no hay | **escrito** | top.v (mezclador) |
| 09 | [Vídeo](manual/09-video.md): la salida 720p, scanlines, 50 Hz, el panel F12, el V9968 para el usuario | **escrito** | msx2hdmi_v9968.sv, README |
| 10 | [Problemas frecuentes](manual/10-problemas.md): por síntoma, con causa probable y qué hacer; herramientas de diagnóstico; cómo reportar | **escrito** | LEEMEs, test_menu.asm |

## Referencia técnica (`docs/tecnica/`)

| Nº | Capítulo | Estado | De dónde sale |
|---|---|---|---|
| 01 | [Arquitectura](tecnica/01-arquitectura.md): la placa, diagrama de bloques, relojes y dominios, el bus y los slots, la memoria, el vídeo, el audio, los periféricos, la secuencia de arranque | **escrito** | top.v y sus módulos |
| 02 | [Mapa de puertos de E/S](tecnica/02-puertos-es.md): la E/S conmutada 40h-4Fh con los tres dispositivos, los puertos de la SD, y el resto puerto a puerto | **escrito** | top.v, sdc_ioport.sv, swioports.vhd |
| 03 | [Mapas de memoria](tecnica/03-mapas-memoria.md): slots y páginas, la SDRAM física banco a banco, la megaram y sus segmentos reservados, la flash, la DDR3 | **escrito** | top.v, megaram.v, gm2_slot1.v, desmontar_pack.py |
| 04 | [El pack de BIOS](tecnica/04-pack-bios.md): qué es, las diez ROMs y su procedencia, el menú de 32 KB en ROM, construir, un pack para todos los cores | **escrito** | bios-msxnano-msximus |
| 05 | [El V9968 en el MSXimus](tecnica/05-v9968.md): qué es, de dónde sale, las tres generaciones del interfaz de registros y en cuál estamos, el puerto 4, cómo está integrado, cómo se comprueba | **escrito** | fpga/v9968/ORIGEN.txt, hra1129/V9968_Cartridge |
| 06 | [La tarjeta SD y la DMA](tecnica/06-sd-dma.md): el controlador, los cuatro caminos con sus velocidades, cómo funciona la DMA, los dos modos de destino, los contadores de mapper, quién usa qué, las firmas | **escrito** | sd_reader.sv, sdc_ioport.sv, sd_dma.sv, sd_rw_ports.inc |
| 07 | [Síntesis y campañas](tecnica/07-sintesis-campanas.md): herramientas, las dos líneas de build, cómo se lanza una campaña, el gate y la regla de los 0,4 ns, lo aprendido del chip, cómo se entrega | **escrito** | lanzar_campana.ps1, gate_check.ps1 |
| 08 | [Simulación](tecnica/08-simulacion.md): el entorno WSL, los bancos por subsistema, las ROMs de prueba, verificar contra openMSX, qué no tiene banco | **escrito** | tools/ |
| 09 | [Changelog de la era v3](tecnica/09-changelog.md): de la v3.1 a la v3.7.6, con el dado, el margen y los hashes de cada entrega | **escrito** | los LEEME de files/, mi_release/ |
| 10 | [Auditoría externa de septiembre de 2026](tecnica/10-auditoria-externa.md): los 137 hallazgos de los cuatro informes contrastados uno a uno, por qué fallan los críticos, y el plan para los tres repositorios | **escrito** | los informes de Albert, el árbol de cada repo |

## Histórico (`docs/historico/`)

Movidos el 11 de septiembre de 2026, con un [índice propio](historico/README.md): los diecisiete documentos del porte de julio y la carpeta `informes_v2/` con los quince informes de la v2.

Se quedan donde están: `hw/` (esquema de la placa), `img/` (con las fotos de la carcasa en `img/carcasa/`) y `logo/`. La carcasa imprimible vive en [`carcasa/`](../carcasa/README.md), en la raíz del repositorio, con su propio README.

## Pendiente transversal

- Capturas de pantalla del menú para el capítulo 04. Se pueden sacar del emulador con el pack del MSXimus.
- Créditos completos en el README al publicar la v3.6, y enlazar este índice desde el README.
- Traducción al inglés del manual cuando esté cerrado.
- Revisión de Albert de todos los capítulos: están escritos desde el código, no desde el uso.

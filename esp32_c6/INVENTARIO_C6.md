# INVENTARIO TÉCNICO — ESP32-C6 del ecosistema MSX de Albert

**Fecha:** 2026-07-27 · **Motivo:** bifurcación MSXnano/MSXimus. El MSXnano cambia de
pantalla; **el ESP32-C6 (Waveshare ESP32-C6-LCD-1.3) queda como módulo definitivo del
MSXimus**. Este documento es el MAPA para retomar el trabajo dentro de semanas.

**Todos los repos se han leído en SOLO LECTURA. Nada modificado.**
⚠️ Varios repos tienen trabajo sin commitear (MSX_up, MSXnano-cinta, y el propio
ESP32-UNAPI-Firmware tiene ficheros basura sin trackear de shells rotos: `0`, `27M`,
`m_sc`, `{busy`, `print(DEVICE_NAME`, `respetarlo` — son de 0 bytes, artefactos, NO
tocados).

---

## 0. RESUMEN EJECUTIVO — el estado en una tabla

| Pieza | Dónde vive | Estado | Qué falta |
|---|---|---|---|
| **WiFi UNAPI (TCP/IP + TLS + SSH)** | `ESP32-UNAPI-Firmware` rama `msximus` | ✅ **FUNCIONA en placa** (build `_153` del MSXimus) | nada |
| **Pantalla LCD 240×240** | `Display.ino` | ✅ **FUNCIONA en placa** | nada (turbo cableado desde `_156`) |
| **Turbo → LCD** | `esp_turbo_o` (N13) → GPIO3 | ✅ integrado en el core `_156` | verificar en placa el cable J10 p18 |
| **Conversor TSX→CVS1** | `tsx2cvs.{h,cpp}` | ✅ **verificado byte-exacto 5/5** en host | compilar en el IDE Arduino |
| **Catálogo web tsx.eslamejor.com** | `tsxcatalog.{h,cpp}` | ✅ **verificado 50/50** contra Python | ídem |
| **Comandos UNAPI de cinta (L/K/k/X/x/J)** | `TapeWeb.ino` | 🟡 **escrito + auditado, NUNCA compilado ni probado** | compilar; probar en HW |
| **Streaming de cinta al FPGA** | `Tape.ino` | 🟡 **escrito + auditado, NUNCA probado** | 2 cables + RTL |
| **RTL de cinta (`cas_stream.v`+`tape_uart.v`)** | `MSXnano-cinta`, rama `cinta-virtual` | ✅ validado en Icarus (70KB byte-exacto) — **SOLO para el TN20K** | **NO existe en el MSXimus (60K)** |
| **Menú MSX tecla `T` "Cinta web"** | `MSXnano` rama `pico-companion` (commit `2c33197`) | ✅ escrito, sin probar en HW | **NO está en el pack del MSXimus** |
| **Menú gráfico en el C6 (F0)** | scratchpad `frontend_c6` + zip preservado | 🟡 **compila (1.66 MB), modo demo por USB** | todo el lado FPGA (F1) |

**El titular:** en el MSXimus el C6 hace HOY **WiFi + pantalla**. Toda la cinta TSX
está escrita y auditada en el firmware, pero **su contraparte FPGA solo existe en el
MSXnano (TN20K)**: para el MSXimus hay que **portar el RTL, asignar 2 pines más del
J10 y meter la tecla `T` en el pack**. El menú gráfico es una fase posterior (F1).

---

## 1. `ESP32-UNAPI-Firmware` — el firmware que corre en el C6

**Ruta:** `C:\Users\alber\proyectosAI\msx\ESP32-UNAPI-Firmware`
**Origin:** `https://github.com/ducasp/ESP32-UNAPI-Firmware.git` (upstream de ducasp,
**no** un fork propio en GitHub — los commits locales NO están publicados).
**Ramas locales:** `main` (= upstream), `msxnano`, **`msximus` (actual, HEAD `a9416ad`)**.

`msximus` se creó hoy **idéntica a `msxnano`**; los dos commits de cabeza solo cambian
el título del LCD. Es decir: **`msximus` ≡ `msxnano` funcionalmente**.

### 1.1 Historial local (lo que Albert añadió sobre ducasp)

| Commit | Qué aporta |
|---|---|
| `c84096c` | Adaptación al ESP32-C6-LCD-1.3: `ESP32BOARDS.h`, `partitions.csv`, **`Display.ino` NUEVO**, ganchos en el `.ino` principal |
| `cc5fdb0` | Docs: mismo `.fs` sirve para C6 y ESP-01S |
| `2bf5981` | **`tsx2cvs.{h,cpp}`** (conversor) + **`Tape.ino`** (streaming) + `host_test/` |
| `04004f2` | **`tsxcatalog.{h,cpp}`** + **`TapeWeb.ino`** (comandos L/K/k/X/x) + opcodes en `UNAPIESP.h` |
| `31ad9e7` | Comando **`J` TSX_FIND** |
| `e39d5fa` | **Auditoría adversarial: 7 bugs arreglados** (detalle en §3.6) |
| `491003c`,`a9416ad` | Título del LCD → `DEVICE_NAME` (hoy `"MSX"`, neutro) |

### 1.2 UNAPI / WiFi — qué implementa (todo esto es de ducasp, intacto)

`ESP32-UNAPI-Firmware.ino` (**140 KB, ~4000 líneas**) + `UNAPIESP.h`.

- **TCP/IP UNAPI completo** (`enum TcpipUnapiFunctions`, `UNAPIESP.h:124-158`):
  `GET_CAPAB`, `GET_IPINFO`, `NET_STATE`, `SEND/RCV_ECHO` (ping), `DNS_Q`/`DNS_S`,
  UDP `OPEN/CLOSE/STATE/SEND/RCV`, TCP `OPEN/CLOSE/ABORT/STATE/SEND/RCV/FLUSH`,
  RAW `OPEN/CLOSE/STATE/SEND/RCV`, `CONFIG_AUTOIP/IP/TTL/PING`, `WAIT`.
  **Extensiones fuera de spec:** `HTTP_OPEN/RECEIVE/CLOSE` (200-202, © Jeroen
  Taverne) y `DNS_Q_NEW` (206).
- **4 conexiones simultáneas** (`ClientList[4]`, `ServerList[4]`, `Udp1..4`).
  Estados en `enum ConnectionStates`: cerrada / UDP / TCP activo / TCP pasivo /
  **TLS activo** / **SSH**.
- **TLS**: `WiFiClientSecure`, bundle de certificados CA en la partición **FFat**
  (`certs.bin`, generado con el `gen_crt_bundle.py` de esp-idf a partir del PEM de
  curl.se). `loadCACertForClient()` es la función que reusa la cinta. Soporta
  **validación de fingerprint del servidor** y **conexiones anónimas**.
- **SSH UNAPI completo** (`enum SshUnapiFunctions` 129-143, spec de 50 KB en
  `SSH UNAPI specification.md`): PTY y RAW, auth por password / pubkey /
  keyboard-interactive / anónima, `known_hosts` en FFat
  (`/ssh_known_hosts`), generación/exportación/importación de claves,
  terminales VT52/ANSI/XTERM, filtro de secuencias ANSI (`SshFilterState`).
  Librería: **LibSSH-ESP32**.
- **Comandos custom** (`enum CustomFunctions`, `UNAPIESP.h:80-120`) — un byte ASCII
  por comando: `R`eset, `S`can AP, `A` connect AP, `b`/`B` board, `d` setbaud,
  `U`/`u` update firmware/certs por HTTP, `Z`/`Y`/`z`/`E` update por RS232,
  `V`ersion, `T`imer radio-off, `O`/`o` apagar WiFi/RS232, `Q`uery settings,
  `c`/`C` autoclock, `G`et datetime (SNTP), `W`armboot, `H`/`h` hold/release,
  `g` estado AP, `?` query… **+ los 6 de cinta (§3)**.
- **Protocolo del enlace**: `opcode(1B) + tamaño(2B BE) + payload`; respuestas
  `SendResponse()` / `SendQuickResponse()`. Parser: `received_data_parser()`,
  máquina `RX_PARSER_IDLE → WAIT_DATA_SIZE → GET_DATA → PROCCESS_CMD`.
  Buffer de comando **`MAX_CMD_DATA_LEN 2148`**; `Serial.setRxBufferSize(2148)`.
- **Stack del loop**: `SET_LOOP_TASK_STACK_SIZE(65536)` (`ino:71`).

**Cómo habla con la FPGA:** por `Serial` (UART0 del C6) a **859372 bps 8N1 3.3V**.
`setUartSpeed()` (`ino:455-483`) mapea `stDeviceConfiguration.ucBaudRate` a la
velocidad; el enum de baudios está en `ESP32BOARDS.h:47-56` y el **default para C6/S3
es `BR859372`** (`ESP32BOARDS.h:70`). El comentario del propio ducasp dice que 859372
**no va fino en ESP32-WROOM pero sí en C6 y S3**.

> ⚠️ Regla de oro documentada en `setup()` (`ino:519-520`): **nunca imprimir texto de
> diagnóstico por `Serial`** — es la UART hacia el FPGA y cualquier basura corrompe el
> stream UNAPI.

### 1.3 `Display.ino` — la pantalla de estado (181 líneas)

**Librería:** `Arduino_GFX_Library` (moononournation) 1.6.6. **Panel:** ST7789V2
240×240 SPI, instanciado en `Display.ino:50-51`.

**Pines del LCD** (`Display.ino:19-24`) — elegidos para no chocar con la UART 16/17:

| Señal | GPIO |
|---|---|
| SCLK | 7 |
| MOSI | 6 |
| CS | 14 |
| DC | 15 |
| RST | 21 |
| BL (backlight) | 22 |

**`TURBO_PIN = 3`** (`Display.ino:30`), `INPUT_PULLDOWN` → sin cable lee 0 → muestra
"Normal". Viene del FPGA (`esp_turbo_o`, J10 pin 18).

**`DEVICE_NAME "MSX"`** (`Display.ino:29`) — neutro a propósito: el firmware sirve a
las dos máquinas. **Es el único punto de personalización del título.**

**Layout de la pantalla** (`displaySetup()` pinta las 3 reglas horizontales; el resto
lo repinta `displayTask()` **solo cuando el dato cambia**, para no parpadear):

```
 y=0    ┌──────────────────────────────────────┬──●──┐  "MSX" size2 cian (6,6)
        │                                      │     │  punto actividad UART (228,13) r=6
 y=28   ├──────────────────────────────────────────  │  ← drawFastHLine
 y=32   │ Conectado / Sin WiFi   (verde/rojo)        │
        │ SSID:xxxxx                                 │  zona WiFi: fillRect(0,32,240,74)
        │ RSSI:-xx dBm                               │
 y=108  ├───────────────────────────────────────     │  ← drawFastHLine
 y=114  │ ███ TURBO 5.37MHz (naranja) ███            │  barra 6,114,228×32
        │  o  Normal 3.58MHz (gris/verde oscuro)     │
 y=152  ├───────────────────────────────────────     │  ← drawFastHLine
 y=156  │ Uptime hh:mm:ss                            │  zona sistema: fillRect(0,156,240,84)
        │ Temp xx C                                  │
        │ HH:MM  dd/mm/aa   (o "Sincronizando")      │
 y=240  └────────────────────────────────────────────┘
```

**Cadencias de refresco** (todas self-throttled dentro de `displayTask()`, que se
llama sin condición desde `loop()`):

| Zona | Cada | Fuente del dato |
|---|---|---|
| Punto de actividad | 150 ms | `g_lastUartMs` (< 250 ms ⇒ verde) |
| Bloque WiFi | 1000 ms | `WiFi.status()`, `WiFi.SSID()`, `WiFi.RSSI()` |
| Barra TURBO | 400 ms | `digitalRead(TURBO_PIN)` |
| Uptime/Temp/Hora | 3000 ms | `millis()`, **`temperatureRead()`** (sensor interno del C6), `time(nullptr)` |

**Reloj**: `Display.ino:89` arranca **SNTP en cuanto hay WiFi** (`configTime(0,0,
"pool.ntp.org")`) — deliberadamente **no** depende de `bSNTPOK` (que solo se activa si
el MSX pide la hora). La hora local se calcula con `stDeviceConfiguration.iGMT * 3600`
(offset en horas que fija el menú WiFi del MSX). Umbral de validez: `epoch >
1700000000`.

**Ganchos en el firmware base:** `displaySetup()` en `ino:497`, `displayTask()` en
`ino:3900` (primera línea de `loop()`), `g_lastUartMs` declarada en `ino:115` y
actualizada en `ino:3908`.

**Estado: ✅ FUNCIONA EN PLACA** (validado con la build `_153` del MSXimus).

### 1.4 `ESP32BOARDS.h` / defines / compilación

- **Placas soportadas** (uno solo descomentado): `ESP32_C6` ← **activo**,
  `ESP32_S3`, `ESP32_WROOM`.
- **Flash**: `FLASH_4M` ← activo (la Waveshare C6-LCD-1.3 lleva 4 MB).
- **`FIRMWARETYPE` = `"UN32C604"`** (C6 + 4M). Es lo que devuelve el comando `b`.
- **Baudios**: `ESP32BAUDRATE = BR859372` para C6/S3; `BR921600` para WROOM.
- **LED WiFi**: `USE_WIFI_LED` **comentado (desactivado)**. Si se activara: C6 →
  WS2812 en **GPIO8**, azul al 50 % cuando hay IP.

**Particiones** (`partitions.csv`) — 4 MB, **sin OTA doble**:

| Nombre | Tipo | Offset | Tamaño |
|---|---|---|---|
| nvs | data/nvs | 0x9000 | 0x5000 |
| otadata | data/ota | 0xE000 | 0x2000 |
| app0 | app/ota_0 | 0x10000 | **0x2C0000 (2.75 MB)** |
| **ffat** | data/fat | 0x2D0000 | **0x130000 (1.19 MB)** |

La partición **FFat es obligatoria**: el firmware hace `FFat.begin(false)` y si falla
formatea con `FFat.begin(true)` (`ino:521-523`). Ahí viven `certs.bin`,
`ssh_known_hosts` y las claves SSH.

**Compilación (toolchain verificado en esta máquina):**

```bat
set CLI="%LOCALAPPDATA%\Programs\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe"
set CFG="%USERPROFILE%\.arduinoIDE\arduino-cli.yaml"
%CLI% compile --config-file %CFG% --fqbn esp32:esp32:esp32c6:PartitionScheme=huge_app .
%CLI% upload  --config-file %CFG% --fqbn esp32:esp32:esp32c6:PartitionScheme=huge_app -p COM7 .
```

- Core **`esp32:esp32` 3.3.10**; librerías **`GFX_Library_for_Arduino` 1.6.6** y
  **`LibSSH-ESP32`** ya instaladas en el sketchbook de OneDrive.
- Desde el IDE: placa **"ESP32C6 Dev Module"**, **USB CDC On Boot = Disabled**
  (así `Serial` sigue siendo la UART al FPGA), **Flash 4 MB**, **Partition Scheme =
  Custom** (usa el `partitions.csv` del sketch) o `huge_app` (solo relaja el
  verificador de tamaño).
- Flasheo por el **USB-C del propio módulo** (no toca la Tang):
  `esptool --chip esp32c6 --port COMx write_flash 0x0 <merged>.bin`
- El subdirectorio `host_test/` lo ignora Arduino (no es un `.ino`).

---

## 2. Cableado FPGA ↔ C6 en el MSXimus (Tang Console 60K)

**Repo:** `C:\Users\alber\proyectosAI\msx\MSX_up` (rama `th9958`, la línea principal).

**Conector J10** — el 2×20 LIBRE ("SDRAM1 CONN." del esquemático oficial
`Tang_Mega_60K_Console_32001C`; el módulo SDRAM del core va en el OTRO conector).
**Columna PAR, 4 pines consecutivos**, para cable plano de una hilera:

| Pin J10 | Señal | Bola FPGA | Net del esquemático | Lado C6 |
|---|---|---|---|---|
| **11** | +5 V | — | — | **5V** (tira derecha, el último) |
| **12** | GND | — | — | **GND** (tira derecha) |
| **14** | TX (FPGA→C6) | **W21** | SDRAM1_D12 | **IO17** (RX) — tira izquierda |
| **16** | RX (FPGA←C6) | **N17** | SDRAM1_D10 | **IO16** (TX) — tira izquierda |
| **18** | TURBO (FPGA→C6) | **N13** | SDRAM1_D8 | **GPIO3** — tira derecha, el primero |

- **Alimentación por el pin 11 (+5 V) del propio J10**, a la entrada `5V` del módulo
  (04/08: montaje real de Albert; la nota anterior decía «no usar, alimentar por
  USB-C» — el USB-C solo hace falta para grabar el firmware). ⚠️ El módulo LLEVA
  protección para las dos fuentes a la vez (confirmado por Albert), pero la
  recomendación es no tenerlas conectadas simultáneamente: al grabar por USB-C,
  soltar el cable de 5 V o apagar la placa.
- **Pinout físico de las tiras del módulo** (cara trasera, la del USB-C y la microSD),
  leído de la serigrafía: tira **izquierda** `23 · 20 · 17 · 16 · 13 · 12`; tira
  **derecha** `3 · 2 · 1 · 3V3 · GND · 5V`. Foto anotada en `docs/img/esp32_c6_pinout.jpg`.
- **Identificación sin serigrafía** (placa apagada, polímetro en continuidad): el pin
  12 es el **único de todo el conector con continuidad a masa**; sus dos vecinos de
  columna hacia el **lado largo** (el que deja 14 filas, no 5) son el 14 y el 16.
- ⚠️ Si algún día se pincha un 2º módulo SDRAM en J10, **hay que mudar el ESP**.

**Constraints** — `MSX_up/fpga/constraints/msx_console60k.cst:118-136`:
```
IO_LOC "esp_rx_i"    N17;  IO_TYPE=LVCMOS33 PULL_MODE=UP   // pull-up = idle UART sin módulo
IO_LOC "esp_tx_o"    W21;  IO_TYPE=LVCMOS33 DRIVE=8
IO_LOC "esp_turbo_o" N13;  IO_TYPE=LVCMOS33 DRIVE=4
```

**Defines y RTL** — `MSX_up/fpga/top.v`:
- `` `define ENABLE_WIFI_ESP32 `` en **`top.v:18`** (build `_153`). Conmuta la fuente
  de `rx_i` del `wifi_lite` del BL616 onboard (sin antena ni firmware) al C6 externo.
- Puertos declarados en `top.v:65-71`.
- Instancia `wifi uwifi(...)` en **`top.v:1586-1602`**, con `rx_i => esp_rx_i` en
  `top.v:1596` (`` `elsif ENABLE_WIFI_ESP32 ``).
- **Registro de re-temporización a 27 MHz** (`top.v:1576-1585`): el bus del T80 se
  flopea a `clk_27m` antes de entrar al módulo, para arreglar un camino de medio ciclo
  que perdió la lotería de placement en la `_95`. **Sin tocar `wifi_lite.vhd`.**
- `assign esp_tx_o = bl616_uart_tx_w;` (`top.v:4753`); sin `ENABLE_WIFI` queda a `1`
  (idle UART). **Se emite siempre — broadcast inofensivo.**
- `assign esp_turbo_o = turbo_eff;` (`top.v:4760`, build `_156`) — `turbo_eff` es el
  que consume el FSM de waits, cuasi-estático, sin CDC.
- El LED de actividad WiFi de la tira WS2812 usa `~bl616_uart_tx_w | ~esp_rx_i`
  (`top.v:4642`) → **parpadea con el tráfico de la UART**: es el diagnóstico de
  primera línea (si no parpadea al usar CFG8266, el problema es cable o firmware, no
  el core).

**`wifi_lite.vhd`** — `MSX_up/fpga/src/ocm/wifi_lite.vhd` (489 líneas, © ducasp,
rev 1.05_lite, BSD-3 sin uso comercial). Es un **puente UART agnóstico al módulo**:

- **Puertos I/O del Z80:** `0x06` (write = comando de velocidad / read = pop del FIFO
  RX) y `0x07` (write = byte a TX / read = registro de estado).
- **Estado en `0x07`** (bits): 0 = hay datos en FIFO, 1 = TX en curso, 2 = FIFO lleno,
  3 = soporta *quick receive*, 4 = *underrun*, 6/7 = libres (anti-open-bus).
- **Prescaler fijo: `to_unsigned(31,14)`** (`wifi_lite.vhd:205`) → **27 MHz / 31 =
  859372 bps**. La versión `_lite` **eliminó todas las velocidades inferiores**: el
  comando `0x06` solo reconoce el **20 = Clear FIFO**.
- **FIFO RX de 2080 bytes** (`wifi_lite.vhd:219`).
- **Quick Receive**: si el Z80 lee `0x06` con el FIFO vacío, el hardware espera hasta
  **25 ms** (675000 ciclos de 27 MHz) antes de devolver `0xFF` y marcar underrun. Es
  lo que hace rápidas las rutinas de recepción del driver.
- El módulo asserta `/WAIT` durante los ciclos de I/O.

> **El mismo `.fs` sirve para ESP32-C6 y para ESP-01S** — solo cambia el firmware del
> módulo WiFi. Para ESP-01S: binario precompilado v1.4 de
> `ducasp/ESP8266-UNAPI-Firmware` (ya viene a 859372, no hay que compilar).
> ⚠️ **El ESP-01S NO tolera 5 V** — alimentarlo a 3.3 V.

**Copia de trabajo en el repo del core:** `MSX_up/esp32_c6/` contiene una copia del
firmware (Display/ino principal/Tape/TapeWeb/UNAPIESP/`*.h` + `README.md` propio +
`README_upstream.md`). **`Tape.ino` y `TapeWeb.ino` son byte-idénticos** a los del
repo del firmware. **Ojo: faltan `tsx2cvs.cpp` y `tsxcatalog.cpp`** (solo están los
`.h`) — esa copia **no compila por sí sola**; la fuente de verdad es
`proyectosAI\msx\ESP32-UNAPI-Firmware` rama `msximus`.

---

## 3. CINTA / TSX — la pieza grande (escrita, auditada, sin probar)

### 3.1 La cadena completa

```
tsx.eslamejor.com  --HTTPS-->  C6: tsxcatalog (parser JSON incremental)
                                   ↓  el MSX elige por índice / texto
                   --HTTPS-->  C6: descarga el .tsx a RAM (vector)
                                   ↓
                              C6: tsx2cvs  (TSX/CAS → stream CVS1)
                                   ↓
                              C6: Tape.ino  UART1 GPIO20 @115200 8N1
                                   ↓  (flow control: RTR ← GPIO23)
                              FPGA: tape_uart.v (FIFO 2 KB) → cas_stream.v (KCS)
                                   ↓
                              PSG port A bit 7 (CASIN)  →  BIOS: RUN"CAS:"
```

### 3.2 Formato **CVS1** (el contrato C6↔FPGA)

```
[0..3]  "CVS1"                      magia; si no cuadra, el FSM vuelve a S_IDLE
[4..5]  num_blocks (u16 LE)
por bloque:  len (u16 LE) + pilot (u8: bit0=1 → piloto largo) + pad (u8=0) + payload[len]
```

**Descriptores INLINE** — ésa es la diferencia con el `CVT1` antiguo (usado por
`cas_player.v`/BSRAM), que alternaba tabla de descriptores y payloads y **no era
secuencial**. `pilot=1` en el bloque 0 y en los bloques cabecera MSX (10 bytes
repetidos de `0xD3`/`0xD0`/`0xEA` = BASIC/BINARY/ASCII).

### 3.3 `tsx2cvs.{h,cpp}` — el conversor (186 líneas)

Port **C++11 portable sin dependencias de Arduino** (compila igual en C6, S3 y PC) de
`tsxcore.py` + `tape_image.py` + `mkstream.py` de tsx2rom.

- `parse_tsx()` (`tsx2cvs.cpp:46`) — firma `"ZXTape!\x1a"`. Bloques manejados:
  `0x10` standard, `0x11` turbo, `0x12` pure tone, `0x13` pulse seq, `0x14` pure data,
  **`0x15` direct recording → ERROR** (audio crudo, no convertible a bytes),
  `0x20/0x21/0x22/0x24/0x25/0x30/0x31/0x32/0x33` (metadatos, se saltan),
  `0x35` custom info, **`0x4B` MSX KCS ← el importante**, `0x5A` glue.
- `parse_cas()` (`tsx2cvs.cpp:131`) — para `.cas` directos.
- `tsx2cvs()` (`tsx2cvs.cpp:154`) — punto de entrada. Devuelve `nullptr` si OK o un
  mensaje de error estático.
- **Bounds-check estricto**: una cinta corrupta nunca lee fuera del buffer.

**Verificación: ✅ BYTE-EXACTO 5/5** contra la referencia Python
(`host_test/verify_all.sh`, g++ en WSL): **007 (70 KB), 1x2, 747 (56 KB), amc (48 KB)
y A.R.C.O.S.** (bajado de la web real).

### 3.4 `tsxcatalog.{h,cpp}` — el parser del catálogo (160 líneas)

**DFA incremental byte a byte** sobre el stream TLS. Necesario porque **una página del
catálogo son ~400 KB de JSON** (50 entradas con el detalle de bloques) y no caben en
la RAM del C6 bufferizadas.

- Campos capturados en orden fijo dentro de `"files"`: `"fileSize"` (miles separados
  por puntos), `"TOSEC.NAME"`, `"TSX.LOAD"` (opcional). Y `"sectionCount"` (total de
  la letra, para paginar en el MSX).
- **`\uXXXX` → UTF-8 EXACTO** — crítico: el nombre se reusa tal cual para construir la
  URL de descarga.
- Tolera `"clave": "valor"` con o sin espacios (estado `await_q`).
- API: `cat_reset()` / `cat_feed(byte)` → 1 si emitió entrada / `cat_end()`.
- `CatEntry = { name[96], sizeBytes u32, loadcmd u8 }` con
  `loadcmd`: **0 = `RUN"CAS:`, 1 = `BLOAD"CAS:",R`, 2 = otro/desconocido**.

**Verificación: ✅ 50/50 entradas idénticas** al parser Python sobre la página real
cacheada (`host_test/verify_catalog.sh`), incluido truncado por bytes.

### 3.5 Comandos UNAPI custom de cinta

Declarados en **`UNAPIESP.h:112-119`**, ruteados en el `.ino` principal en dos sitios
(`ino:2298-2303` en `WAIT_DATA_SIZE`, `ino:2380-2400` en `PROCCESS_CMD`), e
implementados en **`TapeWeb.ino`** (372 líneas).

| Op | Nombre | Payload MSX→C6 | Respuesta | Función |
|---|---|---|---|---|
| `L` | **TSX_LIST** | `{letra, pág, offset}` | `[total16][pagN][n]` + n×`{idx, sizeKB16, loadcmd, nombreZ ASCII ≤48}` | `tsxCmdList()` :175 |
| `K` | **TSX_PLAY** | `{letra, pág, idx}`; **vacío = STOP** | QuickResponse OK/err | `tsxCmdPlay()` :203 / `tsxCmdStop()` :241 |
| `k` | **TSX_STATUS** | `{}` | 6 B: `{busy, err, sentPag16, totalPag16}` (páginas de 256 B) | `tsxCmdStatus()` :248 |
| `X` | **TSX_UPLOAD** | `{size u32 LE}` | OK/err | `tsxCmdUploadStart()` :338 |
| `x` | **TSX_UPBLOCK** | `{chunk ≤2048 B}` | OK; el último dispara conversión+play | `tsxCmdUploadBlock()` :356 |
| `J` | **TSX_FIND** | `{texto ≤60 B}` | `[loadcmd u8][nombreZ ASCII]` | `tsxCmdFind()` :264 |

Detalles importantes:

- **Servidor**: `TSX_HOST "tsx.eslamejor.com"`, catálogo
  `GET /index_back.php?page=N&idx=LETRA` (**requiere cabecera `Referer`, si no 404**),
  fichero `GET /tsx-files/<TOSEC.NAME>.tsx`. User-Agent propio `"MSXnano-tape/1.0"`.
- **`tsxHttpGetStream()`** (`TapeWeb.ino:60`) — GET por streaming, entrega byte a byte
  a un `std::function`. **NO es un template a propósito**: el generador de prototipos
  del IDE Arduino se atraganta con templates en `.ino`. Usa `loadCACertForClient()`
  con fallback a `setInsecure()` si no hay bundle.
- **PLAY va POR ÍNDICE**, no por nombre: el C6 guarda el nombre UTF-8 exacto en su
  caché (`g_cat[50]`) y el MSX solo recibe una transliteración ASCII para la pantalla
  (`tsxAsciiFold()`, maneja los acentos comunes de `0xC3xx`).
- **Guard de heap**: se exige `freeHeap ≥ sizeBytes*2 + 40000` y `sizeBytes ≤ 256 KB`
  (`TSX_MAX_FILE`) antes de descargar.
- **`J` FIND** pagina hasta 8 páginas de la letra inicial del texto, comparación
  case/acento-insensible; al primer match descarga y reproduce por el mismo camino que
  PLAY. Sin match → `UNAPI_ERR_NO_DATA`.
- El MSX **debe usar timeout generoso** para `K`/`J`: descarga + conversión tardan
  2-5 s (y hasta 40 s en el peor caso del FIND).

### 3.6 `Tape.ino` — el streaming al FPGA (133 líneas)

**Pines del C6** (defines en `Tape.ino:25-30`):

| Señal | GPIO C6 | Pin FPGA (**en el MSXnano/TN20K**) |
|---|---|---|
| TX datos CVS1 | **GPIO20** | pin 26 |
| RTR (flow control, entra) | **GPIO23** (`INPUT_PULLDOWN`) | pin 32 |

⚠️ **NO usar GPIO12/13** — son el USB-JTAG del C6.
**`TAPE_BAUD = 115200`**, `TAPE_CHUNK = 64`.

**Control de flujo**: el FPGA saca RTR (activo-alto = "sigue"); baja al llenarse el
FIFO a 3/4 (1536/2047) dejando ~511 B de margen. El C6 manda ráfagas de ≤64 B tras
comprobar RTR + `Serial1.flush()`; con el buffer TX del ESP (~128 B) el peor caso en
vuelo es ~192 B ≪ 511 → **imposible desbordar** si el cableado es correcto.

**API**: `tapeSetup()` (enganchada en `ino:498`), `tapePlay(buf,len)`, `tapeStop()`,
y los getters `tapeBusy()` / `tapeTotal()` / `tapeSent()` (**pensados para que
`Display.ino` pinte el progreso — hoy NO los usa**).

**Modelo de concurrencia (documentado a fondo en `Tape.ino:34-57` tras la auditoría):**
tarea FreeRTOS `tapefeed` (stack 3072, prioridad 1). **Parada COOPERATIVA**: nunca se
mata la tarea desde fuera; se pide con `g_tapeStopReq` y la tarea sale ella misma en
un punto sin locks, libera el buffer, pone `g_tapeBusy=false` **el último** y hace
`vTaskDelete(nullptr)`. `tapeStop()` hace join esperando a que baje `busy`.

### 3.7 La auditoría de los 7 bugs (commit `e39d5fa`, 24/07)

Revisión adversarial (7 revisores + verificación) **antes** de la prueba en HW.
**7 hallazgos confirmados y corregidos, 1 refutado.** Lo que se arregló:

1. **`tsx2cvs.cpp` — integer overflow de `size_t` de 32 bits (MEDIA).** En los bloques
   `0x4B` y `0x35` la cota `o + 5 + ln > n` **envuelve mod 2³²** en el ESP (`ln` es un
   u32 controlado por un fichero de internet). Un `.tsx` con `len=0xFFFFFFFF` saltaba
   la comprobación → bloque de ~4 GB → `bad_alloc`/reset = **DoS remoto**.
   **Invisible en el host de 64 bits, por eso pasó la verificación byte-exacta.**
   Fix: validar con **resta** (`ln > n - (o+K)`). Test nuevo `host_test/test_overflow.sh`.
2. **`tsxcatalog.cpp` — `classify_load()` sin NUL-terminar** en la ruta de descarga
   truncada → leía texto rancio de la entrada anterior y clasificaba mal RUN/BLOAD.
   Fix: `s->load[s->llen] = 0`.
3-5. **`Tape.ino` — tres carreras de ciclo de vida de la tarea (MEDIA):**
   (a) `vTaskDelete` desde fuera dejaba tomado el mutex del UART/heap si caía dentro de
   `Serial1.write/flush` → **cuelgue permanente del UART**; (b) TOCTOU sobre
   `g_tapeTask` (no volátil) → doble-delete; (c) `g_tapeBusy=false` antes de limpiar el
   handle → clobber + use-after-free. **Fix de raíz: parada cooperativa** (§3.6).
6. **`TapeWeb.ino` — descarga sin `Content-Length` truncada devolvía OK.** Fix: flag
   `stalled`, el timeout de datos ahora da error.
7. **`TapeWeb.ino` — guard de heap con `e.sizeBytes` pero la descarga cortaba en
   `TSX_MAX_FILE`**: si el catálogo infra-reportaba el tamaño, el vector crecía por
   encima del heap verificado → OOM. Fix: cortar en `e.sizeBytes` en `tsxCmdPlay` y
   `tsxCmdFind`.

**Refutado (correcto, no tocar):** el `flush` de `tape_uart` no resetea la FSM del RX —
no es disparable porque el flush solo ocurre con el C6 ocioso.

> **La última línea del propio commit:** *"Tape/TapeWeb pendientes de compilar en el
> IDE Arduino (sin arduino-cli aquí)."* → **ese sigue siendo el estado: NUNCA se ha
> compilado el bloque de cinta.**

### 3.8 `host_test/` — la infraestructura de verificación en PC

| Fichero | Qué hace |
|---|---|
| `verify.cpp` (28 l.) | driver g++: `.tsx` → `.cvs` usando el MISMO `tsx2cvs.cpp` del firmware |
| `verify_all.sh` (37 l.) | compara byte a byte contra la cadena Python (`tsx2msx.py --tape` → `mkstream.py`). Recorre `tsx2rom/test/tsx/*.tsx` + `companion/cache/*.tsx` |
| `verify_catalog.cpp` / `.sh` | parser del catálogo vs. el JSON de Python |
| `test_overflow.sh` (34 l.) | genera dos `.tsx` maliciosos (`0x4B` con `len=0xFFFFFFFF`, `0x35` con `0xFFFFFFF0`) y comprueba que se **rechazan limpios**, y que amc/007 siguen convirtiendo |

Dependen de rutas WSL absolutas: `/mnt/c/.../tsx2rom` y
`/mnt/c/.../MSXnano-cinta/tools/tsx_stream_sim/mkstream.py`.

### 3.9 ⚠️ El lado FPGA **NO existe en el MSXimus**

**Comprobado por grep exhaustivo en `MSX_up`: no hay ni `cas_stream`, ni `tape_uart`,
ni `CVS1`, ni ningún puerto de cinta.** El RTL vive en:

**`C:\Users\alber\proyectosAI\msx\MSXnano-cinta`** (worktree del MSXnano),
rama **`cinta-virtual`** (HEAD `3c1fd57`; también mergeado en `pico-companion`):

- **`fpga/cas_stream.v`** — hermano de `cas_player.v` (que queda intacto: BSRAM
  validado en HW). Emisor KCS copiado literal (`PULSE_ONE=731`, `PULSE_ZERO=1463`,
  `PILOT_LONG/SHORT`); la fuente pasa de memoria direccionable a un **handshake `pop`
  secuencial** (`pop_req` nivel / `pop_valid` / `pop_data`). Valida la magia `"CVS1"`
  (basura → `S_IDLE`), `flush` del FIFO en el load-edge. Reloj: `clk_54m` + `ce` a
  ritmo de T-state del Z80.
- **`fpga/tape_uart.v`** — UART RX 115200 8N1 (patrón `kbd_uart_rx`, 2 flops de
  sincronización, dominio único) → **FIFO 2048×8 (1 BSRAM)** → `pop`.
  **`CLK_FREQ=54_000_000`, `CLKS_PER_BIT = 54e6/115200 = 468`.**
  **RTR por nivel con histéresis `FILL_STOP=1536` / `FILL_GO=512`.**
  El FIFO de 2 KB ≈ **18 s de cinta** a ritmo real (110-120 B/s) → un hipo de WiFi no
  corta la carga.
- **Integración en `top.v`** (commit `cbccb38`): puertos `tape_rx` (**pin 26**,
  PULL UP) y `tape_rtr` (**pin 32**). Reutiliza sin tocar lo ya validado en HW:
  **motor por `OUT(0xAB)`/PC4 del PPI** (no escrituras a `0xAA`), armado automático
  tras reset + re-armado al acabar (el FSM espera la magia en `S_RD`, así que el C6
  puede mandar el stream cuando quiera, **sin puerto de armado**), `casin` → PSG
  port A bit 7.
- **Puertos de diagnóstico de bring-up** (los mismos que se usarán en el MSXimus):
  - `INP(&H2C)` = los primeros 16 bytes consumidos → **debe dar `43 56 53 31` ("CVS1")**
  - `INP(&H2D)` = `{rtr, playing, 00, fsm[3:0]}`
  - `INP(&H2E)` = `fill/8`
  - `OUT &H2C` resetea el índice de lectura
- **Verificación Icarus (`tools/tsx_stream_sim/`)**: CAZA 528 B byte-exacto +
  motor-pause recuperada + 0 drops; **007 de 70 KB → 70.565 bytes BYTE-EXACTOS,
  0 drops, `S_DONE`** (31 min de sim con `SIM_TURBO`).
- Build Gowin del TN20K: 0 errores, `clk_54m` 54.25 MHz, `tape_rx` en 26/IOB6[B],
  `tape_rtr` en 32/IOB18[B]. Serial `12_stream`.

**Estado del RTL: validado en simulación, integrado y compilado para el TN20K,
NUNCA probado en placa. Y no portado al 60K.**

### 3.10 El menú MSX (tecla `T`)

**`MSXnano` rama `pico-companion`, commit `2c33197`**, en
`fpga/src/msxnano_menu/src/menu_main.asm`:

- `cp #54` (`'T'`) → `main_action_tsxweb` (`menu_main.asm:464` y `:2121`).
- Flujo mínimo v1: prompt "Buscar" (40 chars) → comando **`J` FIND** por la
  **UART del `wifi_lite` en I/O `0x06`/`0x07` DIRECTO** (sin driver UNAPI:
  `OUT(6),20` limpia el FIFO, `OUT(7)`=TX, `IN(7)` bit0 + `IN(6)`=RX) → muestra
  nombre + el comando a teclear (RUN/BLOAD según `loadcmd`) → RETURN arranca BASIC
  (la cinta ya está streameando) / ESC manda STOP.
- `TW_LOAD equ #C0DE` (1 byte de RAM con el `loadcmd`).
- Rutinas `tw_rx` (timeout ~2 s/byte) y `tw_rx_long` (~40 s, para la descarga).
- Sustituyó al test UNAPI del File-Hunter fase 0 → devolvió el margen del menú de
  186 a **508 bytes**.

⚠️ **Verificado hoy: el `main_action_tsxweb` SOLO existe en `pico-companion`.**
Las ramas `main`, `dev` y `menu` del MSXnano **no lo tienen** → el pack que usa hoy el
MSXimus (`goauld_rom_int_PACK_V5_149.bin` @ `0x400000`) **no tiene la tecla T**.

---

## 4. `tsx2rom` — el proyecto Python de referencia

**Ruta:** `C:\Users\alber\proyectosAI\msx\tsx2rom` — **NO es un repo git** (carpeta
suelta, sin control de versiones).

**Qué es:** el laboratorio original que resolvió "cómo cargar cintas MSX en máquinas
sin cassette". CLI: `python tsx2msx.py juego.tsx [--cas|--dsk|--tape|--info] -o dir`.

| Parte | Fichero | Corre en | Estado |
|---|---|---|---|
| Núcleo TSX/CAS | `src/tsxcore.py` | PC | ✅ referencia; **portado a C++ en el C6** |
| Imagen de cinta CVT1 | `src/tape_image.py` | PC | ✅ genera `.cvt` para `cas_player.v` |
| Crack a disco | `src/tsx2dsk.py`, `src/dskbuild.py` | PC | ✅ 007/amc/1x2 arrancan; 747 no-convertible (detectado) |
| Stubs Z80 (ROM hook) | `src/stub/`, `build/` | MSX | ⛔ **APARCADO** (dead-end: page-0 RAM shadow no persiste bajo BASIC) |
| Modulador KCS FPGA | `fpga/cas_player.v` | FPGA | ✅ **validado en HW** (BSRAM, formato CVT1) |
| Sims | `fpga/sim/*` (flash, full1x2, banked) | PC | ✅ varios byte-exactos |
| **Companion web** | `companion/tsxweb.py` (5.4 KB) | PC/RPi | ✅ **prototipo validado contra la web real**: `list`/`search`/`get` (verifica md5 del catálogo) / `fetch` / `info`. Stdlib pura, sin pip. **Es el modelo del que salió `tsxcatalog.cpp`** |

**Qué corre en el C6:** nada de este proyecto directamente. **Su valor hoy es doble:**
(1) es la **referencia de verdad** contra la que `host_test/verify_all.sh` compara
byte a byte el `tsx2cvs.cpp` del firmware; (2) `companion/cache/` guarda el JSON real
del catálogo y `.tsx` de prueba que usan los tests.

**Qué corre en RTL:** `cas_player.v` (vía BSRAM, formato CVT1) — la vía **antigua**,
validada en HW pero limitada a juegos pequeños. La vía actual es `cas_stream.v` (CVS1)
en `MSXnano-cinta`.

**Historia condensada** (de la memoria `msx_tsx2rom_proyecto`): BSRAM → bloqueado por
tamaño (48-70 KB no caben) → FLASH → **bloqueada** (`flash_busy` atascado en lecturas
encadenadas, build nº9, sin resolver) → **giro a STREAMING desde companion WiFi**
(15/07) → **decisión: ESP32-C6 todo-en-uno** (16/07). Bluetooth A2DP y BLE evaluados y
descartados. SDRAM descartada (puerto único CPU/VDP, core al 90 % CLS).

> **Gotcha histórico documentado**: para escribir la imagen en flash con el Gowin
> Programmer el fichero **debe ser `.bin` con nombre limpio** — un `.cvt` o con `@` en
> el nombre da **error silencioso** (borra a FF y no escribe).

---

## 5. Prototipo de MENÚ GRÁFICO en el C6 (fase F0)

**Ruta viva (volátil):**
`...\scratchpad\frontend_c6\`
**Copia preservada:** `MSX_up\files\20260726\menu_c6_prototipo_20260727.zip` (139 KB)
+ `menu_c6_demo_20260727_merged.bin` (4 MB, imagen completa de flash)
+ `LEEME_MENU_C6_PROTOTIPO.txt`.

> El propio LEEME lo dice: **"NO ES PARA AHORA: es el frente del frontend
> (post-V9968)."**

### 5.1 La arquitectura decidida

El **C6 es el CEREBRO del menú**: renderiza la UI en un framebuffer virtual
**256×240 @ 4bpp** (paleta de 16 colores, 30720 B = 15 BSRAM) que en F1 viajará por
`FB_BLIT` al `menu_fb.sv` del core y saldrá por el HDMI de la consola. En F0 ese mismo
framebuffer se enseña en el **LCD 240×240** del C6 (recorte central de 240 columnas,
1:1) para poder verlo sin tocar el core. Enlace físico: **la MISMA UART `wifi_lite` de
3 hilos** (en F0, USB-CDC contra un core falso en Python).

### 5.2 El protocolo (`MenuProto.h`, 192 líneas — **el documento de referencia**)

**Entrada al modo menú** (Z80 → C6, por el parser de ducasp):
`'M' + tam(2B BE) + {proto_ver u8}` → `CUSTOM_F_MENU_ENTER`. Respuesta
`SendResponse('M', OK, 2, {MENU_PROTO_VER, flags})`. Tras el OK **el C6 pasa a MASTER**
y el Z80 headless ejecuta su intérprete.

**Trama C6→Z80:** `{op u8, len u16 BE, payload, crc8}` · **crc8 = CRC-8 poly 0x07
init 0x00**.
**Respuesta Z80:** `{0x80|op, status u8, len u16 BE, payload, crc8}`.

| Opcode | Nombre | Payload | Notas |
|---|---|---|---|
| `0x01` | `MOP_PING` | `{}` → `{proto, fpga_maj, fpga_min, loader}` | también sirve para autodetectar el core |
| `0x02` | `MOP_SEC_RD` | `{lba u32 LE}` → 512 B | SD proxy |
| `0x03` | `MOP_SEC_WR` | `{lba, 512B}` | **fase F2** |
| `0x04` | `MOP_LOAD_EXT` | `{n, n×{lba u32, cnt u16}}` | SD → megaram por extents contiguos |
| `0x05` | `MOP_SET_MAPPER` | `{id u8}` | |
| `0x06` | `MOP_SET_CFG` | `{bits}` b0=menu_en b1=turbo b2=scanlines b3=16:9 | |
| `0x07` | `MOP_KBD_STREAM` | `{on u8}` | | 
| `0x08` | `MOP_BAUD` | `{n u8}` | ACK al baud viejo → conmutar → PING → rollback |
| `0x09` | `MOP_FB_PAL` | `{16×{r,g,b}}` | el core trunca a RGB666 |
| `0x0A` | `MOP_FB_BLIT` | `{flags, xB, y, wB, h, datos}` | b0 = payload RLE; xB/wB en **BYTES** (2 px/byte); **wB=0 = fila completa (128 B)** |
| `0x0B` | `MOP_RUN` | `{rom_id u8}` | + evento `GAME_START` + salto |

**Eventos espontáneos Z80→C6** (pueden llegar intercalados mientras se espera una
respuesta):
- Tecla: `{0xC0|fila(0..10), máscara}` — 2 bytes, **sin CRC** (hot path)
- `GAME_START`: `{0xE0, len u8, payload, crc8}` con `{rom_id, mapper, sizeKB u16 BE, nombre}`

> **Desviación deliberada de la spec de arquitectura:** la spec decía tecla =
> `{0x80|fila, máscara}`, pero **`0x80|fila` colisiona con los opcodes de respuesta
> `0x81..0x8B`** cuando una tecla llega mientras se espera un ACK (caso real:
> repintado + usuario navegando). Se movió a `0xC0` y `GAME_START` a `0xE0`: ahora
> respuesta (`0x8x`), tecla (`0xCx`) y evento largo (`0xE0`) son disjuntos.

**Baudios escalonados** (`enum MenuBaudIds`): `MBAUD_859372=0` (arranque, validado en
HW) → `MBAUD_1M=1` (**27M/27 exacto, 0 % de desajuste en ambos extremos**) →
`MBAUD_3M=2` (27M/9, **solo tras medir la integridad del enlace**).

**Límites**: `MENU_TIMEOUT_MS 2000` / `MENU_TIMEOUT_LONG_MS 40000` /
`MENU_CMD_RETRIES 3` / `MENU_BLIT_MAX_PAYLOAD 2048` / `MENU_MAX_ENTRIES 200` /
`MENU_DIR_DEPTH 8`.

### 5.3 Los ficheros

| Fichero | Líneas | Propósito |
|---|---|---|
| `MenuProto.h` | 192 | El contrato. **Documento de referencia para el intérprete Z80 y el `menu_fb.sv` de F1** |
| `MenuFB.ino` | 240 | Framebuffer virtual: `Arduino_Canvas_Indexed` 8bpp, paleta 16×RGB888, dirty-bbox, empaquetado 4bpp (**formato exacto del futuro `menu_fb.sv`**), RLE PackBits, troceo en bandas ≤2 KB con ACK por rect, preview en el LCD |
| `MenuLink.ino` | 322 | Lado master: tramas + CRC8 + timeout + 3 reintentos, eventos intercalados, cola de teclas, API `linkPing/SecRead/LoadExtents/SetMapper/SetCfg/KbdStream/FbPal/FbBlit/Run/SetBaud` |
| `MenuFat.ino` | 251 | Lector FAT16/32 de solo lectura sobre `SEC_RD` (MBR o superfloppy, LFN, cadena de clusters → **extents contiguos para `LOAD_EXT`**). **Sustituye a ~1.180 líneas de FAT del menú Z80** |
| `MenuCore.ino` | 410 | El navegador: pila de directorios, render, teclas, detección de mapper (**stub F0** por tamaño+nombre), flujo de lanzamiento, entrada `'M'` desde el MSX, salida a UNAPI |
| `MenuGame.ino` | 135 | Pantalla "durante el juego": carátula placeholder 128×160 (pipeline real = **F2**), nombre, mapper, tamaño, tiempo de partida, WiFi |
| `MenuDemo.ino` | 129 | Modo demo F0 por USB-CDC (`USBSerial`/HWCDC), autodetección harness-vs-local por PING, árbol simulado. **`MENU_DEMO_USB=0` para el build F1** |
| `host/fake_core.py` | 335 | El "core falso": sirve PING/SEC_RD de una imagen SD, acepta LOAD_EXT/RUN, pinta los FB_BLIT en pygame 256×240×3, manda teclas del PC como matriz MSX. **`--nak-rate 0.05`** inyecta NAKs para probar el reintento |
| `host/make_test_image.py` | 186 | Genera `sd.img` FAT16 32 MB con ROMs falsas (con LFN), sin dependencias |

**Cambios sobre la base de ducasp** (todos marcados `[MENU]`):
`ESP32-UNAPI-Firmware.ino` (include, `menuSetup()`, `menuTask()`, pausa del parser con
`menuOwnsSerial()`, dispatch de `'M'` en 2 sitios) · `UNAPIESP.h`
(`CUSTOM_F_MENU_ENTER = 'M'`, letra libre verificada contra toda la tabla ducasp+TSX) ·
`Display.ino` (accesor `displayGfx()`; `displayTask()` cede el LCD si `menuOwnsLcd()`).

### 5.4 Qué está probado y qué no

**✅ Probado:**
- **Compila limpio** — app **1.66 MB** (cabe de sobra en `huge_app`); imagen merged de
  4 MB generada.
- **Modo demo local por USB**: sin FPGA, sin harness. Arranca solo tras ~1,5 s, hace
  2 PING, no encuentra harness → árbol simulado navegable en el LCD con teclas ASCII
  del monitor serie (`w/s` o `k/j` arriba/abajo, `a/d` página, ENTER entrar/lanzar,
  ESC/retroceso subir/volver). Al "lanzar" sale la pantalla de juego.
- **RLE**: roundtrip encoder (firmware) ↔ decoder (harness) **500/500 OK**, ratio ~10:1
  sobre contenido típico de menú.
- **Imagen FAT de prueba**: estructura verificada con un parser independiente.
- La barra de estado muestra **heap libre real** (`ESP.getFreeHeap()`) y el contador de
  errores CRC — los dos números que la arquitectura pedía medir en F0.

**❌ NO existe / pendiente (fase F1, requiere el árbol del core):**
- **`menu_fb.sv`** — el framebuffer 256×240@4bpp en BSRAM del lado FPGA.
- **El mux en `msx2hdmi`** — para que el framebuffer del menú salga por el HDMI.
- **El registro de baud** en `wifi_lite` — hoy el prescaler está **hardcodeado a 31**
  (`wifi_lite.vhd:205`); el escalón a 1 Mbps/3 Mbps necesita hacerlo escribible.
- **El intérprete Z80** que responde a los opcodes 01-0B.
- Detección de mapper de verdad (hoy stub por tamaño/nombre), pipeline de carátulas
  (F2), benchmark de JPEGDEC (F2), SETBAUD a 1 M por USB (el comando ya existe).

**Flasheo cuando toque** (no pisa nada de la Tang, va por el USB-C del C6):
```
esptool --chip esp32c6 --port COMx write_flash 0x0 menu_c6_demo_20260727_merged.bin
```
⚠️ **Esa imagen SUSTITUYE al firmware UNAPI actual del C6** — para volver, recompilar
la rama `msximus`.

---

## 6. SI MAÑANA QUISIERA ACTIVAR LOS TSX EN EL MSXimus — los pasos

**Lo que ya está hecho:** todo el lado C6 (conversor verificado, catálogo verificado,
6 comandos UNAPI, streaming, auditoría de 7 bugs) y todo el RTL **para el TN20K**
(validado en Icarus con 70 KB byte-exactos).

**Lo que falta, en orden:**

### Paso 0 — compilar el firmware (30 min, sin hardware)
El bloque de cinta **nunca se ha compilado**. Es el riesgo más barato de eliminar:
```bat
%CLI% compile --config-file %CFG% --fqbn esp32:esp32:esp32c6:PartitionScheme=huge_app ^
   C:\Users\alber\proyectosAI\msx\ESP32-UNAPI-Firmware
```
Sospechosos típicos en `.ino`: el generador de prototipos de Arduino y los tipos de
`tsxcatalog.h`/`vector`. (Ya se evitaron los templates a propósito en
`tsxHttpGetStream`.) Y volver a pasar `host_test/verify_all.sh` +
`host_test/test_overflow.sh` en WSL para confirmar que la auditoría no rompió nada.

### Paso 1 — portar el RTL de cinta al 60K (el trabajo real)
Copiar de `MSXnano-cinta` (rama `cinta-virtual`) a `MSX_up/fpga/`:
- `cas_stream.v` y `tape_uart.v` — **hay que revisar el parámetro `CLK_FREQ`**: en el
  TN20K es `54_000_000` (`CLKS_PER_BIT=468`); confirmar el reloj equivalente del 60K
  (`clk_54m` existe en el MSXimus, verificar que es el mismo dominio) y el `ce` a
  ritmo de T-state del Z80.
- Añadirlos a `MSX_up/fpga/build.tcl` (junto al `add_file src/ocm/wifi_lite.vhd` de la
  línea 204).
- Instanciarlos en `MSX_up/fpga/top.v`, replicando lo que hace
  `MSXnano-cinta/fpga/top.v:599-660`: `tape_uart` → `cas_stream` → **`casin` al bit 7
  del port A del PSG**, `motor` desde **`OUT(0xAB)`/PC4 del PPI** (⚠️ **NO** escrituras
  a `0xAA` — ése fue el bug del primer test HW), armado automático tras reset.
- Portar los **puertos de diagnóstico `0x2C`/`0x2D`/`0x2E`** — son imprescindibles para
  el bring-up.

### Paso 2 — 2 pines nuevos en el J10
El C6 necesita **GPIO20 (TX datos) → FPGA** y **GPIO23 (RTR) ← FPGA**. En el TN20K son
los pines 26 y 32; en el 60K **hay que elegir dos bolas nuevas**. Lo natural es
**continuar la columna par del J10 (pines 20 y 22)** para seguir con un cable plano de
una hilera, pero **el mapeo pin→bola no está documentado en el repo**: en el `.cst`
solo constan los cuatro que se usan (12/14/16/18 → GND/W21/N17/N13, nets
SDRAM1_D12/D10/D8). **Hay que sacar del esquemático oficial
`Tang_Mega_60K_Console_32001C` (hoja SDRAM) qué bolas son los pines 20/22 de J10** y
añadir las líneas al `.cst`:
- `tape_rx` (entrada al FPGA) → **`PULL_MODE=UP`** (sin C6 no hay bytes fantasma)
- `tape_rtr` (salida del FPGA) → `DRIVE=4`/`8`

Y **actualizar los defines en `Tape.ino:25-30`** si se decidiera cambiar los GPIO del
lado C6 (por defecto se quedan igual: 20 y 23).

### Paso 3 — la tecla `T` en el menú del MSXimus
El pack del MSXimus (`goauld_rom_int_PACK_V5_*.bin` @ `0x400000`) **no tiene el menú
de cinta**. Hay que traer `main_action_tsxweb` + `tw_rx`/`tw_rx_long` + `TW_LOAD
equ #C0DE` del commit `2c33197` (rama `pico-companion` del MSXnano) al menú con el que
se construye el pack del MSXimus, y rehacer el pack.
Ventaja: **no necesita driver UNAPI** — habla la UART del `wifi_lite` directo por
I/O `0x06`/`0x07`.
⚠️ Vigilar el margen de espacio del menú (el `.org #A010` del File-Hunter **desborda en
silencio**, según la memoria del proyecto).

### Paso 4 — bring-up en placa (el guion)
1. Flashear el firmware al C6 por su USB-C; flashear el `.fs` nuevo + power-cycle.
2. Cablear los 2 hilos de cinta (además de los 4 ya existentes).
3. Menú → **`T`** → teclear p. ej. `"abadia"` → RETURN → `RUN"CAS:"`.
4. **Si falla, la secuencia de diagnóstico** (desde BASIC):
   - `INP(&H2C)` debe devolver **`43 56 53 31`** = `"CVS1"`. Si no → los bytes no
     llegan: cable TX, GPIO20, baudios, o el C6 no está streameando.
   - `INP(&H2D)` = `{rtr, playing, 00, fsm}` → si `rtr`=0 permanente, el FIFO no se
     vacía (motor no arranca); si `playing`=0, el FSM no encontró la magia.
   - `INP(&H2E)` = `fill/8` → llenado del FIFO.
   - `OUT &H2C` resetea el índice de lectura.
   - En el lado C6: el comando **`k` TSX_STATUS** devuelve `{busy, err, sentPag,
     totalPag}` — dice si el C6 cree que está enviando.
   - El **LED WiFi de la tira WS2812** parpadea con el tráfico de la UART UNAPI: si no
     parpadea al usar el menú, el problema es cable/firmware, no el core.

### Paso 5 — flecos conocidos
- **Cargadores que chocan con Nextor**: `1x2` falla con Nextor residente (aislado
  limpio en openMSX: sin extensión ✅, con `SunriseIDE_Nextor` ❌). Pasaría igual desde
  cinta real en cualquier MSX con disco. Arreglo: arrancar BASIC **sin Nextor**
  (`config_enable_sdcard`). Los `.cas`/`.cvt` de un solo fichero simple (`RUN"CAS:"`)
  **sí** van con Nextor.
- **Navegador completo del catálogo**: el comando `L` LIST ya existe en el firmware,
  falta el lado menú (hoy solo está el `J` FIND de un solo match).
- **Subida desde SD**: `X`/`x` ya están en el firmware, falta el lado menú.
- **Progreso en el LCD**: `tapeBusy()`/`tapeTotal()`/`tapeSent()` están expuestos pero
  `Display.ino` **todavía no los pinta**. Es una mejora barata y vistosa.

---

## 7. Rutas de referencia rápida

| Qué | Ruta |
|---|---|
| Firmware del C6 (fuente de verdad) | `C:\Users\alber\proyectosAI\msx\ESP32-UNAPI-Firmware` rama **`msximus`** |
| Copia en el repo del core (parcial) | `C:\Users\alber\proyectosAI\msx\MSX_up\esp32_c6\` |
| Core del MSXimus | `C:\Users\alber\proyectosAI\msx\MSX_up` rama **`th9958`** |
| `wifi_lite.vhd` | `MSX_up\fpga\src\ocm\wifi_lite.vhd` |
| Constraints del 60K | `MSX_up\fpga\constraints\msx_console60k.cst:118-136` |
| RTL de cinta (TN20K) | `C:\Users\alber\proyectosAI\msx\MSXnano-cinta` rama **`cinta-virtual`** → `fpga\cas_stream.v`, `fpga\tape_uart.v` |
| Menú tecla `T` | `C:\Users\alber\proyectosAI\msx\MSXnano` rama **`pico-companion`** commit `2c33197` |
| Laboratorio Python | `C:\Users\alber\proyectosAI\msx\tsx2rom` (sin git) |
| Prototipo de menú gráfico | `MSX_up\files\20260726\menu_c6_prototipo_20260727.zip` + `menu_c6_demo_20260727_merged.bin` + `LEEME_MENU_C6_PROTOTIPO.txt` |
| Notas de entrega del WiFi C6 | `MSX_up\files\20260726\LEEME_153_WIFI_ESP32C6.txt` |

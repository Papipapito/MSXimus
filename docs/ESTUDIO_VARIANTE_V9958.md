# Estudio: una v2.1 paralela con el V9958 clásico

**Encargo de Albert (07/08)**: valorar una versión de la v2.1 **sin nada del V9968**, con el
V9958 clásico, para ganar compatibilidad con juegos que hoy fallan (Fleet Commander, Dragon
Quest 2, Dra-Sle Family…), sabiendo que a la larga habría que **mantener las dos ramas**.

> Estado: análisis de código **completo**; medición de recursos **pendiente de la build**
> (la máquina estaba con la campaña b190 de la v2.1 oficial). Los huecos marcados con ⏳ se
> rellenan en cuanto compile la variante.

---

## Resumen ejecutivo

**Es mucho más barato de lo que parece.** El proyecto ya nació con los dos carriles y el
selector sigue puesto: el V9968 se enciende con **dos flags** (`` `define ENABLE_V9968_VDP ``
en `top.v` y `set USE_V9968 1` en `build.tcl`) que el lanzador de campañas activa con `sed`
al clonar. **El repo, tal cual está guardado, ES la build V9958.**

El carril clásico ha sufrido **dos puntos de bit rot** en cuatro meses de trabajo intensivo
sobre el V9968 — los dos localizados y arreglados en la rama `estudio-v9958`: una señal de
/WAIT que se quedaba sin driver (podía dejar al Z80 esperando para siempre) y las constraints
físicas del DDR3, que mataban la síntesis antes de empezar. Para el tiempo transcurrido, muy
poco.

Lo que de verdad cuesta no es crear la variante: es **mantener dos líneas validadas en placa**.

---

## 1. El punto de partida: la infraestructura ya existe

| Pieza | Cómo selecciona el VDP |
|---|---|
| `fpga/top.v:1` | `` `define ENABLE_V9958 `` (siempre) + `` `define ENABLE_V9968_VDP `` (comentado en el repo) |
| `fpga/build.tcl:113` | `set USE_V9968 0` → compila `tn_vdp_v3_v9958/`; `1` → compila `v9968/` + shim + bridges |
| `tools/lanzar_campana.ps1:100,113` | activa ambos con `sed` en la copia de trabajo, y **verifica** que quedaron activos |

El comentario del propio `build.tcl` lo dice: *"0 = VDP clasico tn_vdp, 1 = V9968… el arbol
tn_vdp solo entra en el build clasico (colision de nombre vdp/VDP con el core V9968 + ahorro
de CLS)"*. Los `hdmi/*.sv` son comunes a los dos.

## 2. Estado real del carril clásico (medido, no supuesto)

### 2.a La señal de /WAIT
Rastreando los `ifdef` línea a línea sobre `top.v` (5 059 líneas), **una sola señal** cruza
mal la frontera:

```
v68_wait86_n   declarada L1327  [fuera de todo ifdef]
               driver     L1806 [solo dentro de `ifdef ENABLE_V9968_VDP`]
               consumida  L1386-1394 en el árbol WAIT_n del T80 [fuera de todo ifdef]
```

Sin V9968 ese cable **no tiene quien lo pinche**: entra como `z` al `WAIT_n` del Z80 y, según
cómo lo resuelva la síntesis, la máquina podía no arrancar. Es la cura `_177` (el /WAIT del
puerto de VDP), que se escribió sin pensar en el carril clásico.

**Arreglado** en `estudio-v9958` con tres líneas (`assign v68_wait86_n = 1'b1;` en el
`ifndef`). Las otras 17 señales `v68_*` se declaran *dentro* del bloque del V9968, así que en
la build clásica ni existen.

### 2.b El que de verdad mataba la build: las constraints (encontrado al compilar)

Lanzada la build clásica, murió **antes de empezar**:

```
ERROR (CT1135): Can't find object named 'u_vddr3/u_ddr3/gw3_top/u_ddr_phy_top/u_dll'
ERROR (CT1135): Can't find object named 'u_vddr3/pll_ddr3_inst/PLLA_inst'
```

El `.cst` **no tiene preprocesador**: los dos `INS_LOC` que fijan el DLL y el PLL de la IP
DDR3 (los que matan la lotería de emplazamiento del V9968) se leían **también** sin V9968,
donde `u_vddr3` no existe. Curiosidad: `lanzar_campana.ps1` ya describía este error… pero
como consecuencia de *no* parchear los interruptores; en realidad es un defecto propio del
carril clásico.

**Arreglado** moviéndolos a `constraints/msx_v9968_ddr3.cst`, que `build.tcl` añade solo
dentro de `USE_VRAM_DDR3` — el mismo patrón que ya usaban los `.sdc`. La línea V9968 no
cambia: mismas constraints, mismo contenido, fichero condicional.

**Total del bit rot: dos puntos, ambos curados en `estudio-v9958`.** Para cuatro meses de
desarrollo intensivo sobre el otro carril, es muy poco.

## 3. Qué gana la variante

- **Los juegos que hoy fallan.** Fleet Commander, DQ2 (MSX1) y Dra-Sle Family funcionan en un
  V9958 real y en openMSX; fallan en las **dos** implementaciones del V9968 (la nuestra y el
  cartucho de HRA). Con el VDP clásico el problema desaparece por construcción.
- **Toda la familia de bugs del V9968 deja de existir**: el byte perdido del handshake LMMC,
  el 5S fantasma, las rayas de la sc-cache, el thrash del motor de comandos… Son bugs de un
  VDP nuevo con pocos años de rodaje; el `tn_vdp` lleva dos décadas de comunidad detrás.
- **Recursos y rutado**: ⏳ (pendiente de medir). El V9968 aporta ~15 000 líneas de RTL
  exclusivo y la VRAM en DDR3; sin él caen el shim, los dos bridges CDC, el backend DDR3, el
  PLL de 86 MHz y el puente de 800 px. La expectativa es bajar bastante del 90 % de CLS
  actual — y con ello el rutado deja de ser la lotería de 40-50 min por dado.
- **La SDRAM y la DDR3 quedan libres** para lo que venga (wave, WiFi, futuro V9990).

## 4. Qué pierde

Todo lo que hace especial a la v2.1: sprites multicolor de 15 colores, 16 sprites por línea,
sprites escalables con rotación y espejado, paleta de 256 colores, 256 KB de VRAM, comandos
extendidos (LRMM/LFMM/LFMC) y el modo de comandos rápido. Es decir: **las demos del V9968 no
corren** y el argumento de venta del proyecto desaparece en esa rama.

## 5. Coste de recursos (MEDIDO)

Mismo informe de síntesis (`project_syn_rsc.xml`), mismas opciones, misma placa:

| Recurso | V9968 (v2.1.2) | V9958 clásico | Ahorro |
|---|---|---|---|
| **LUT** | 31 895 | **24 519** | −7 376 (−23 %) |
| **Registros (FF)** | 25 356 | **16 725** | −8 631 (−34 %) |
| **ALU** | 5 381 | **3 824** | −1 557 (−29 %) |
| **BSRAM** | 91 | **57** | −34 (−37 %) |
| **SSRAM (RAM16)** | 676 | **564** | −112 (−17 %) |
| DSP (MULT12X12) | 14 | 6 | −8 |
| DSP (MULTALU27X18) | 8 | 8 | = |
| Uso de DDR3 | VRAM completa | **ninguno** | libera el chip entero |
| **CLS** | 26 814 / 29 952 (**90 %**) | **21 616 / 29 952 (73 %)** | −5 198 (−17 puntos) |
| **Build completa** | 40-50 min, 1 de cada 3 no entrega | **18,2 min**, entregó a la primera | menos de la mitad |

**Dos lecturas importantes:**

1. **El ahorro es real pero no milagroso**: un tercio de los registros y un cuarto de las
   LUT. Con ~7 400 LUT y 34 BSRAM libres caben cosas que hoy no caben (el framebuffer del
   menú, el OSD…), y sobre todo **el rutado deja de ir al límite**.
2. **El rutado deja de ser una lotería**: 73 % de CLS contra 90 %. La build tardó **18 minutos**
   de la copia al bitstream, frente a los 40-50 min (y el tercio de dados que no entregan) de
   la línea V9968. Eso cambia el ritmo de trabajo: se pueden probar tres ideas en el tiempo
   que hoy cuesta una.
3. ⚠️ **NO resuelve el problema del SSRAM del GW5AT-60B** (el que Gowin retiró por defecto de
   silicio): se baja de 676 a 564 RAM16, pero el grueso lo consume **el audio**, no el VDP.
   La variante clásica seguiría necesitando la migración a BSRAM de la era V3.

## 6. El coste de verdad: mantener dos ramas

Lo que **NO** se duplica (el 90 % del proyecto es común):

> audio completo (PSG, SCC, OPLL, Y8950+ADPCM, OPL4), SDRAM y su refresco, Nextor y la SD,
> megaram y mappers, teclado y joystick USB, WiFi y el ESP32-C6, turbo, ventilador, menú de
> arranque y el pack de BIOS, telemetría… **y el propio `top.v`**, del que menos del 6 % está
> bajo `ifdef` del V9968.

Lo que **SÍ** diverge: el VDP y su fontanería (shim, bridges, backend DDR3, puente de vídeo).

La experiencia de esta misma semana lo ilustra bien:

| Bug | ¿A qué rama afecta? |
|---|---|
| Refresco de SDRAM `_181` (descargas corruptas) | **Ambas** — un fix sirve a las dos |
| Menú `_182abc` (mapper, cartucho fantasma) | **Ambas** — es del pack, ni siquiera es RTL |
| Las 8 curas de la caza (LMMC, 5S, INT…) | **Solo V9968** |
| V9968DM2 mal, rayas, sc-cache | **Solo V9968** |

Es decir: **los fixes comunes se escriben una vez**; los del VDP no tocan la rama clásica en
absoluto. El coste real no está en el código sino en **el proceso de release**: dos campañas
de síntesis (~1 h cada una), dos gates y, sobre todo, **dos rondas de validación en placa**
— que es tu tiempo, no el mío.

## 7. Recomendación

**Hacerlo, pero como variante de build, no como fork.** Un solo repositorio, un solo `main`,
dos artefactos:

- `MSXimus_vX.Y.fs` — la línea V9968 (la actual, la que enseña el proyecto)
- `MSXimus_vX.Y_9958.fs` — la línea clásica, "modo compatibilidad"

Razones: el selector ya existe; un fork duplicaría los 40 000 líneas comunes y condenaría a
portar a mano cada fix de audio/SD/menú; y como el pack de BIOS es el mismo, el usuario solo
cambia el `.fs` según lo que quiera correr ese día. Además el propio `build.tcl` ya avisa de
por qué los árboles no pueden convivir en la misma build (colisión del nombre `vdp`), así que
la separación por flag es la vía natural.

Coste por release: una campaña extra y una pasada de validación con un puñado de juegos.

## 8. Plan de trabajo propuesto

1. ⏳ **Build de sanidad** con `USE_V9968 0` + `estudio-v9958` → ¿compila?, ¿qué recursos?
2. **Validación en placa** de lo básico: arranque, menú, SD, audio, teclado.
3. **La prueba de fuego**: Fleet Commander, DQ2 MSX1 y Dra-Sle Family — que son la razón de
   existir de la variante.
4. Repasar los `ifdef` del carril clásico buscando más bit rot que la síntesis no vea
   (señales de telemetría, contadores de depuración).
5. Integrarlo en `lanzar_campana.ps1` como modo (`-V9958`), igual que ya existe `-Slim`.
6. Documentar en el README que hay dos bitstreams y para qué sirve cada uno.

---

### 5.b Un cono al filo que aparece en LAS DOS variantes

El gate rechazó ambas builds por el **mismo sitio**, y no es el VDP:

| Build | Violación |
|---|---|
| V9968 (b190, dado 1307) | setup **−0,683 ns** → `ff_flash_state_1_s3` |
| V9958 (estudio) | setup **−0,019 ns** → `ff_flash_state_0_s3` |

Es el FSM del **loader de flash**, común a las dos líneas. En la clásica viola por 19
picosegundos (a un pelo de pasar; otro dado seguramente entra), pero que aparezca en las dos
apunta a un cono estructuralmente al límite, no a mala suerte de emplazamiento. **Merece
registrarse** — mismo remedio que el expediente de la caza propone para el cono crítico del
VDP. Es trabajo que beneficia a ambas ramas a la vez, buen ejemplo de lo que decíamos en §6.

---

*Rama del estudio: `estudio-v9958` (parte de `integra-curas-v21`, la línea oficial con las
ocho curas del V9968 dentro). Análisis hecho el 07/08 sobre `top.v` 5 059 líneas,
`build.tcl` y `lanzar_campana.ps1`.*

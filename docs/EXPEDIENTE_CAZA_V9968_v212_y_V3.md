# EXPEDIENTE DE LA CAZA — v2.1.2 y V3
### MSXimus / V9968 · 4-6 de agosto de 2026 · Albert (placa) + Claude (RTL y bancos)

---

## 1. QUÉ SE BUSCABA Y QUÉ SE ENCONTRÓ

Se partía de dos síntomas viejos: **Fleet Commander y Dragon Quest 2 se
colgaban** en MSXimus **y también en el cartucho V9968 de HRA** — un bug
heredado que ni el autor del núcleo había localizado.

Se encontraron y curaron **OCHO defectos reales del VDP**, cada uno con
mecanismo explicado y banco determinista. Ninguno era "el" bug, pero
**todos son defectos verdaderos frente al silicio** y varios viven en el
RTL compartido con HRA.

Al cerrar: **DQ2 pasó de colgarse siempre a jugarse** (le queda un fallo
visual de sprites) y de **Fleet** sabemos que su bucle de muerte pasa por
un hook de disco, lo que probablemente exonera al VDP de ese cuelgue.

---

## 2. LAS OCHO CURAS (todas en la PR #1, con banco)

| # | Nombre | Mecanismo | Banco | Estado |
|---|--------|-----------|-------|--------|
| 1 | **_176 expulsado** | Inundación de la sc-cache: rompía el V9968DM2 (rayas donde debía haber logo translúcido) | bisección s011/s012 + análisis RTL | ✅ curado y confirmado en placa (s015) |
| 2 | **FIFO del motor** | `ff_transfer_ready` es un almacén de UN bit: si la CPU escribe el byte k+1 mientras el motor procesa el k, el paso por `*_next` pone TR=1 y **borra la evidencia** → el motor espera un byte que ya llegó → CE=1 para siempre | `tb_lmmcseam`: v2.1 **16/16 cuelgues**, con FIFO **16/16 OK** | ✅ curado |
| 3 | **_183 TR en reposo** | Cualquier escritura a R#44 baja TR, y **nada lo re-arma en idle**; el chip real en reposo lee S#2 con TR=1. El poll de la BIOS no salía jamás | replay de Fleet + traza openMSX (pc=2bf8) | ✅ curado |
| 4 | **_184 correa del /WAIT** | Timeout del fail-open del glue 12 µs → 48 µs (cubre inanición de VRAM en modos MSX1) | regresión MODE=5 0 fallos | ✅ curado |
| 5 | **_185 reset del latch del par** | **La joya, e idea de Albert**: leer el status **resetea el latch del par de bytes del puerto 1** (herencia TMS9918/V9938). Sin ese reset, un par desincronizado **no se re-sincroniza jamás** → el juego polea el registro equivocado para siempre | `tb_s2fossil` FASE4: viejo **8/8 mal**, nuevo **self-healing 1/8** | ✅ curado |
| 6 | **_186b cola del shim** | En modos MSX1 el fetch de display mata de hambre el drenaje de escrituras (~39 µs) y una ráfaga OTIR desbordaba la cola de 8 → **escrituras perdidas en silencio** | soak byte a byte: **34 fallos → 0** | ✅ curado |
| 7 | **_187 / _187b / _187c 5S fantasma** | El terminador del SAT fuerza el "lleno" y el bloque del 5S usa ese lleno → **cada sprite tras el terminador dispara un 5S falso**; el software de la era TMS guarda datos en la cola del SAT. Además el escáner corría en **líneas del borde**, donde los sprites aparcados (Y≥192, LA convención para ocultarlos) se vuelven "visibles" | `tb_spcol` 4 fases, modos 1 y 2: fantasmas 10/10 → **0/10**, colisión y 5S legítimo intactos | ✅ curado — **es lo que quitó el cuelgue de DQ2** (confirmado por diferencial s033: al revertirlo, el cuelgue vuelve) |
| 8 | **_187d número de sprite** | Con 5S=0, S#0[4:0] debe llevar **el número del último plano examinado** (documentado TMS9918/V9938) y el software TMS lo lee. El _187 lo dejó clavado a 0 | tb_spcol (el número vuelve a variar) | ✅ corregido (regresión de mi propio _187) |
| 9 | **_188 INT tragada por el poll** | La cadena if/else evaluaba los clears antes que los sets: **si el evento coincide con el ciclo de cualquier lectura de status, se pierde**. Poleando S#2 a ~20k lecturas/s = una INT de frame perdida cada ~70-80 s | `tb_intswallow` A/B: la vieja pierde el evento en **4 colisiones distintas**, la nueva **7/7** | ✅ curado (no era el asesino de Fleet, pero es defecto real) |

**Para v2.1.2**: la v2.1 completa **menos _176 y _179**, **más** FIFO + _183 +
_184 + _185 + _186b + _187/b/c/d + _188. Todo validado en banco y con
GATE limpio en las builds entregadas.

**Para HRA**: los números 2, 3, 5, 7, 8 y 9 están en el **RTL compartido**
(`vdp_command.v`, `vdp_cpu_interface.v`, `vdp_sprite_select_visible_planes.v`).
El 5 y el 7 son los más valiosos: explican por qué le fallan los juegos
de la escuela TMS y a nadie más.

---

## 3. LOS DOS FRENTES ABIERTOS (acotados, no resueltos)

### 3.1 Sprites de DQ2 — dentro del pipeline de sprites del VDP

**Síntoma**: sólo se ve el primer sprite; otro aparece **en una posición
que no le corresponde**; el resto desaparecen o parpadean. Idéntico en la
versión MSX1 y en la MSX2 del juego.

**Descartado con datos** (no por intuición):
- **Camino de memoria completo**: `missSP = 0` en placa, en 45 líneas
  seguidas. Los fetches de sprite nunca fallan la caché.
- **Buffer víctima**: invalida por dirección completa en cada escritura
  (verificado en RTL).
- **Presión de caché**: banco `tb_spcount3` con la CPU machacando VRAM →
  3072 px, 100%.
- **Latencia del backend**: banco `tb_spcount4` con 120 ciclos (DDR3 real
  con refresco) → 3072 px, 100%.
- **Dirección de patrón 16×16**: banco `tb_spcount2` con patrones 0/4/8 →
  los tres renderizan.
- **Mis propias curas _187b/c**: A/B de píxeles **idéntico** contra el
  árbol de la s025.

**Lo que queda**: un sprite pintado con **los atributos de otro** sólo
puede nacer en la RAM de sprites seleccionados de
`vdp_sprite_info_collect` — el índice con el que se escribe (durante el
display, con `selected_en`) y con el que se lee (durante el borrado).
Sospechoso concreto: desalineación entre `ff_current_plane` de escritura y
de lectura, o `selected_count` no válido al arrancar la recogida.

**Instrumento ya escrito y validado en sim, pendiente de poder hornearse**:
sonda que cuenta `selected_en` (sprites elegidos) contra `dbg_collected`
(sprites recogidos) y compara en el lector. Si divergen, el bug está
confirmado y localizado. `vdp_sprite_info_collect` ya expone
`dbg_collected` como **puerto** (las referencias jerárquicas las rechaza
el sintetizador de Gowin). Ver §4.

### 3.2 Cuelgue de Fleet — probablemente NO es el VDP

**El bucle de la muerte**, idéntico en tres capturas independientes:

```
D5D7…D5F9 (RAM)  →  FEE4 (HOOK)  →  1B45/1B46 (BIOS)  →  0016/0017/0018  →  vuelta
```

- Es una **rutina real**, no basura: recorrido ordenado, llamadas a BIOS
  que vuelven, bucle estable a velocidad normal.
- **`0xFEE4` cae en el bloque de hooks de DISCO** de la tabla del MSX
  (van de cinco en cinco desde `0xFD9A`; ese es el número 66).
- **El interfaz de disco del MSX va MAPEADO EN MEMORIA, no por puertos**
  (en MSXimus la SD entra por slot). Por eso todas las radiografías
  decían "SIN-I/O" sin que eso excluyera al disco.
- Cuadra el resto: interrupciones cerradas (el driver de disco lo hace en
  su sección crítica), pantalla apagada (aún en fase de carga), cero
  escrituras de VRAM, y el VDP **sano** en ese instante (S#2 correcto).

**Teorías muertas por el camino** (documentadas para no repetirlas):
- "Lecturas de VRAM corruptas envenenan al juego": **los juegos jamás leen
  el puerto 0x98**. El latch de la sonda quedó exonerado en banco
  (`tb_probe98`, 3/3 en ambos puertos con /WAIT).
- "Direccionamiento por encima de 64 KB roto": Fleet escribe de verdad en
  las cuatro páginas de 32 KB.

**Siguiente paso**: analizador lógico contando accesos a la ventana del
disco (código escrito y con banco verde; ver §4).

---

## 4. TAREAS CONCRETAS PARA LA V3

1. **⚠️ REGISTRAR EL CONO CRÍTICO DEL VDP** —
   `u_timing_control/u_ssg/ff_v_count_clone → u_cpu_interface/ff_line_interrupt`.
   Está al filo (−0.338 ns cuando cae mal) y es **preexistente**. Hoy hace
   que **instrumentar el VDP sea una lotería**: tres implementaciones
   distintas de la misma sonda dieron **exactamente el mismo −0.356 ns**
   con el mismo dado, y cuatro dados dieron cuatro resultados distintos.
   Costó cuatro builds esta noche. Con una etapa de registro, toda la
   instrumentación futura deja de ser una tirada de dados.

2. **Hornear la sonda de selección de sprites** (§3.1) una vez hecho el
   punto 1, y cerrar el bug de los sprites de DQ2.

3. **Analizador lógico** (`fpga/src/dbg_trace.v`, ya en la PR): anillo de
   4096 eventos en BRAM que graba fetches M1, I/O y accesos a la ventana
   del disco, se congela con el síntoma del cuelgue y vuelca por el UART.
   Banco `tb_dbgtrace` verde. **Dos avisos aprendidos a golpes**:
   - el COM11 del PC cuelga del pin **E22 (`dbg_pmod1[4]`)**, no de
     `usb_uart_tx`;
   - el disparo por silencio **debe** exigir calentamiento (contar I/O
     real antes de armarse), o dispara en el arranque.

4. **Integrar las ocho curas** en la línea V3 (ya están en la PR sobre la
   v2.1).

5. **Frente aparte, preexistente**: el banco `run_sp2_quick` reproduce
   suciedad con 32 sprites 16×16 + scroll (~25k px frente a 57/frame de
   control). **No es de esta caza** (A/B idéntico antes y después de las
   curas), pero está ahí.

---

## 5. METODOLOGÍA QUE FUNCIONÓ (y la que no)

**Funcionó**:
- **Radiografía in-vivo por COM11** con el juego colgado delante. Los
  replays de trazas de openMSX validan protocolo sano pero **no
  reproducen el estado de fallo de la placa**.
- **Una variable por build**, con MD5 y GATE documentados en cada kit.
- **Regla de "sin banco verde no hay entrega"**, y su hermana: **sin GATE
  limpio tampoco** (se retiraron dos builds por violación de setup, una
  con −0.857 ns).
- **Diferenciales**: revertir una cura para ver qué síntoma vuelve. Así se
  demostró que el _187c es lo que cura el cuelgue de DQ2.
- **Los resultados negativos como producto**: cada teoría muerta con banco
  cierra un camino y se anota en la cabecera del propio banco.

**No funcionó**:
- Diagnosticar por lectura de RTL sin medir: tres hipótesis seguidas
  (dato tardío, número de sprite, INT tragada) eran defectos reales pero
  **ninguna era la causa del síntoma**.
- Confiar en un instrumento sin instrumentarlo: el analizador falló en
  silencio dos veces (cable equivocado, disparo en el arranque) y costó
  tres flasheos antes de ponerle su propio chivato.

---

## 6. ARCHIVO

- **PR #1** — https://github.com/Papipapito/MSXimus/pull/1 : las ocho
  curas, `dbg_trace.v`, y **doce bancos** (`tb_lmmcseam`, `tb_bootreplay`,
  `tb_s2fossil`, `tb_s2fossil2`, `tb_vramsoak_glue`, `tb_spcol`,
  `tb_spcold`, `tb_spcount`, `tb_spcount2/3/4`, `tb_intswallow`,
  `tb_probe98`, `tb_dbgtrace`).
- **Kits en `mi_release/`** — `exp_s015` … `exp_s036`, cada uno con su
  LEEME, MD5(8), veredicto de GATE y protocolo de prueba.
- **Lector canónico** — `mi_release/dbg_radio.py` (v13): decodifica todos
  los esquemas de telemetría de la saga y el volcado del analizador.
- **Decisión pendiente de Albert**: qué contar a HRA y cuándo. Nada se ha
  comunicado.

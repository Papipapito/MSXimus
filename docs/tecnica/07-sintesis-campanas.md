# 07. Síntesis y campañas

Cómo se convierte el RTL en un `.fs` que se pueda entregar. En esta FPGA no basta con sintetizar una vez: el chip va al 98 % de sus celdas lógicas y el rutado es una lotería, así que el procedimiento está pensado para tirar varios dados y quedarse con el que pasa. Sale de `tools/lanzar_campana.ps1`, `tools/gate_check.ps1` y de lo aprendido en las campañas.

## 1. Herramientas

| | |
|---|---|
| Gowin EDA | Edición comercial **1.9.12.03**, en `C:\Gowin\Gowin_V1.9.12.03_x64`. Esa versión retiró el SSRAM de la GW5AT-60 a propósito por un problema del silicio, y la era v3 del core nació sin él: todo va en BSRAM y registros. La 1.9.11 queda solo para reconstruir la era v2.x |
| `fpga/build.tcl` | El guion de síntesis: lista de ficheros, interruptores `USE_V9968` y `USE_VRAM_DDR3`, y las opciones del place and route |
| `fpga/top.v` | Los `` `define `` de la cabecera eligen qué entra en el core |
| `tools/lanzar_campana.ps1` | Lanza una campaña de tres copias en paralelo |
| `tools/gate_check.ps1` | Decide si un bitstream se puede entregar |
| El MCP `gowin` | `gowin_timing`, `gowin_resources` y `gowin_compare` para leer los informes sin abrir la herramienta |

## 2. Las dos líneas de build

Un solo código fuente, dos configuraciones:

| Línea | Qué es | Ocupación | Rutado | Dados que entregan |
|---|---|---|---|---|
| **Completa** | Producción. Todo el audio dentro | 90-98 % de CLS | 40-50 min por dado | Unos dos de cada tres |
| **Ligera** (`-Slim`) | Desarrollo del V9968. Sin MoonSound, sin Y8950 ni ADPCM, sin OPLL | Unos 69 % | Minutos | Todos |

La ligera existe porque al 90 % de ocupación el rutado tarda entre 13 y 23 veces más que al 66 %, y cada intento de arreglo costaba hora y media. Con ella se prueban cinco ideas en una tarde y solo lo que sobrevive pasa a la completa. Es además un instrumento de diagnóstico: un fallo que reproduce en la ligera es de lógica; uno que solo aparece en la completa es de contención de memoria, porque el audio grande es un cliente más de la DDR3 y de la SDRAM.

Lo que la ligera **no** puede validar: cualquier defecto cuya magnitud dependa de la presión de memoria. Esos se revalidan en la completa antes de darlos por curados. El camino de memoria del V9968 no cambia entre las dos líneas.

## 3. Una campaña

```powershell
.\tools\lanzar_campana.ps1 -Campana v36c -Dados 3533,3539,3541
```

El lanzador copia el árbol `fpga/` tres veces al directorio temporal, `%LOCALAPPDATA%\Temp\claude\campanas\<nombre>\bx_c1..3`, nunca dentro del repositorio, y en cada copia:

1. Activa los interruptores que el repositorio deja apagados: descomenta `ENABLE_V9968_VDP` y `ENABLE_VRAM_DDR3` en `top.v` y pone `USE_V9968 1` y `USE_VRAM_DDR3 1` en `build.tcl`. En la línea ligera además comenta los ocho `define` del audio grande, que van juntos porque dependen entre sí.
2. Comprueba que todo ha quedado como debe y aborta si no.
3. Escribe el **dado** en `PERIOD_MS` de `fpga/src/dbg_uart.v`. Los dados son números primos: perturban el placement sin cambiar la función, porque solo tocan el periodo de la telemetría del `dbg_uart` (con la opción `DIETA_V36H`, un latido mínimo). El dado tiene que seguir en el netlist: si se podara, todos los dados darían el mismo bitstream. Y tiene que entrar en una comparación `>=`, no `==`: con una igualdad contra constante la estructura del comparador es la misma para cualquier valor (solo cambia el contenido de las LUT) y el placer devuelve la misma colocación con dados distintos. Se descubrió el 17 de septiembre, cuando tres campañas de la dieta dieron 0 de 15 y varios dados repetían exactamente el mismo número de redes sin rutar: dos síntesis con dados distintos diferían en 390 líneas de netlist con `==` y en 85.000 con `>=`.

**Menos lógica no es mejor rutado.** La *dieta* de la v3.6h quitó un 5 % de LUT (telemetría, tira WS2812, ventilador por temperatura, segundo PSG, un decodificador de teclado) y el placer 1 pasó de rutar 9 de 16 dados a 0 de 13; el mismo día, el netlist completo volvió a rutar 3 de 5. Al 96-98 % de CLS lo que manda es la congestión local, no el área total, y quitar bloques periféricos cambia dónde cae lo denso. La dieta se quedó como opción apagada (`DIETA_V36H`).
4. Lanza la síntesis y el place and route.

Tres copias porque, en la completa, una de cada tres no ruta del todo: se queda con un centenar o dos de nets sin conectar y no produce bitstream. Es normal y no dice nada del diseño.

Dos reglas de operación que no son negociables en el PC de desarrollo: las síntesis se lanzan en primer plano y se vigilan, nunca desde agentes en segundo plano, y no se corre nada pesado en paralelo con ellas.

## 4. El gate: qué se acepta

Cuando la campaña ha terminado del todo, no cuando aparece el `.fs`, porque Gowin escribe el bitstream antes que los informes:

```powershell
.\tools\gate_check.ps1 -Campana $env:LOCALAPPDATA\Temp\claude\campanas\v36c
```

Un dado pasa si cumple las dos:

- **Cero violaciones de setup.**
- Toda violación de **hold** está dentro de la IP DDR3 de Gowin, que no se puede tocar, o va a un pin de BSRAM con menos de 50 ps de holgura negativa.

Lo segundo tiene explicación medida: en este chip el skew entre una columna de lógica y una fila de BSRAM es de 0,19 a 0,20 ns constante, y el tiempo de hold del pin de BSRAM es de 0,037 ns. Esa combinación produce holds de unas decenas de picosegundos que el router, que ya lleva la corrección de hold activada por defecto, no puede alargar más. Es el suelo del silicio; todos los bitstreams entregados lo llevan. Un hold entre dos biestables de lógica, o mayor de 50 ps, sí es un cambio de régimen y merece otro dado.

**El gate no mide margen.** Un dado que pasa puede tener el peor camino de setup a 0,01 ns. Por eso, antes de entregar, se mira siempre el informe de temporización y se aplica la regla de entrega: **el peor setup debe quedar por encima de 0,4 ns**. Los dados que pasan el gate pero no llegan a ese margen se guardan como respaldo, no se entregan.

Un artefacto conocido: el informe dice que `clk_54m` no alcanza su frecuencia aunque no haya ninguna violación de setup. Es una peculiaridad del análisis estático de Gowin con este árbol de relojes y se ignora.

## 5. Qué se aprendió del chip

- **El 98 % de CLS no es falta de área, es congestión.** Los nodos más cargados son IORQ_n y WR_n del Z80: cualquier decodificador combinacional que cuelgue de ellos aparece en el peor camino de la siguiente campaña. La respuesta sistemática es registrar las salidas de los módulos de E/S y convertir las órdenes en pulsos con el dato ya capturado.
- **Los muxes en cascada se aplanan.** Una cascada de diez ternarios que devuelven lo mismo en todas las ramas es un OR plano; el decodificador de slots se reescribió así.
- **Los cruces 54 → 108 MHz** entre el bus y el controlador de memoria son los que más margen pierden; el último fue el término de refresco `cpu_run`, registrado en la 3.6d.
- **La BSRAM está al 100 %.** Cualquier función nueva tiene que hacerse sin ella; la DMA de la SD se diseñó con ese límite.
- **Cuando el peor camino se repite, se arregla el camino, no se tiran más dados.** En la v3.7.5 las escrituras de la CPU a los puertos de configuración y al mapper (`IORQ_n`/`WR_n` → `config*_ff`, `mapper_reg*`, un cruce de 54 a 27 MHz con 9,26 ns) fueron el peor camino de casi todos los rechazos: quince dados dieron un solo candidato con margen. Registrarlas una vez en 27 MHz, como el 44h desde la v3.7, dio tres de cinco en la campaña siguiente. El banco `tools/cfgreg_sim` compara la versión vieja y la nueva con 20.000 OUT.
- **El mux de lectura de la CPU (`cpu_din`) en árbol** (v3.7.4): los ~49 ternarios en cadena van en siete grupos contiguos que se resuelven en paralelo y luego en orden. La prioridad es idéntica (se demuestra con `tools/cpudin_equiv/verify.py`: yosys con miter y SAT, más 200.000 vectores en Icarus). En el MSXnano, con seis dados, llevó el cierre de 3 de 6 a 6 de 6.
- **Un core aislado no predice la build.** Un módulo que cierra temporización solo puede no cerrar dentro del top con el 98 % ocupado; lo que vale es la campaña.

## 6. Entregar

Cada entrega va a `files/<fecha>/`, fuera de git, y lleva:

- El `.fs` y su `_jtag.bin`, siempre en pareja, con el dado en el nombre.
- Un `LEEME_<versión>.txt` con qué cambia, los resultados de la campaña dado a dado con el peor camino de cada uno, los hashes, y qué probar en placa.
- **Todos los candidatos con margen, no solo el mejor.** La calibración de la DDR3 de la VRAM es una lotería por dado: más o menos la mitad de los que pasan el gate no calibran y dan negro con la máquina funcionando por debajo (F11 cambia el turbo). En la v3.7.5 el 5003 pasó con 0,534 ns y dio negro; de los tres de la campaña siguiente, el 5099 calibró. Se prueban desde un cargador, apagando y encendiendo, con `PRINT INP(&H2C) AND 127`.

El `_jtag.bin` sale del `.fs` con el conversor del proyecto y es lo que se flashea por el BL616. Al publicar en GitHub, la pareja se copia además a `mi_release/<versión>/`.

Una advertencia de placa: el USB del PC puede falsear las pruebas, porque alimenta el BL616 y altera el arranque. Las pruebas de placa se hacen con un alimentador de solo corriente.

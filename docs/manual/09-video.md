# 09. Vídeo

Qué sale por el HDMI, qué opciones tiene y qué es el V9968 desde el punto de vista de quien lo usa.

## 1. La salida

Una sola señal: **HDMI 1280×720 a 60 Hz**, con el audio embebido. Cualquier televisor o monitor con HDMI la acepta; los capturadores también.

La imagen del MSX ocupa la pantalla entera. Cada punto del MSX son 4 píxeles de ancho y cada línea 3 de alto, sin fracciones, así que los píxeles salen todos iguales y sin escalones. Se ve el **borde** a los cuatro lados, como en un monitor de tubo: 32 puntos a cada lado del área de 256, que es donde los juegos con scroll esconden y sacan cosas.

No hay modo 4:3 con marco negro ni ajustes de posición: se probaron y se retiraron en favor de un único modo a pantalla completa, el mismo criterio que el MSXnano.

**Scanlines**: en Ajustes, *Enable Scanlines* oscurece al 50 % una de cada tres líneas, el aspecto de un monitor de la época. Se cambia y se guarda desde el menú, sin reiniciar el core.

**50 Hz**: la salida es siempre 720p60. El software que pone el VDP en 50 Hz funciona, con la imagen convertida a 60; es el modo menos probado y su geometría en el V9968 no está medida, así que si algún juego europeo se ve raro en 50 Hz, es lo primero que mirar.

## 2. El panel F12

Con el firmware del BL616 grabado ([capítulo 02](02-instalacion.md)), **F12** congela el MSX y dibuja encima un panel en color con lo que el core dice de sí mismo: versión, Z80 y turbo, vídeo, tarjeta, los ajustes principales (scanlines, estéreo, segundo SCC), qué hay en cada USB-A, ventilador, bloqueo de mayúsculas y la orden para actualizar. Sale en el idioma del menú. F12 otra vez, o ESC, y el juego sigue donde estaba. Es de solo lectura.

Desde la v3.8 el panel lleva color (cada fila con sus combinaciones de fondo y tinta) y dibujos propios: marcos, iconos y letras con tilde. Un firmware del BL616 anterior se sigue viendo como antes, en amarillo y blanco sobre negro.

Porque F12 es del panel, el **turbo va en F11**.

## 3. El V9968

El VDP del MSXimus no es un V9958: es el **V9968** de Takayuki Hara (HRA!), un chip imaginario que amplía el V9958 con lo que Yamaha nunca llegó a sacar:

- **Sprites multicolor**: 15 colores más transparencia por sprite, definidos píxel a píxel.
- **16 sprites por línea** en vez de 8: se acabó el parpadeo cuando hay muchos.
- **Sprites escalables**, con aumento, rotación y espejo.
- **Paleta ampliada**: 32768 colores, en conjuntos de 16.
- **256 KB de VRAM**, comandos nuevos (LRMM rota y escala al copiar, LFMM, LFMC) y un modo rápido de comandos que multiplica la velocidad de los bloques.

Todo eso está desactivado hasta que el software lo pide, así que el MSXimus es un MSX2+ normal para todo el catálogo. Para el software que sí lo pide, la referencia es la [demo DEVCON de HRA!](https://github.com/hra1129/V9968_Cartridge) y las que han salido después; en septiembre de 2026 ya hay demos de terceros escritas para él, y el MSXimus fue el primer hardware real donde corrieron.

Un detalle para quien programe o pruebe software de V9968: hay tres versiones del interfaz de registros del chip, y el MSXimus lleva la que HRA! documenta en su manual desde junio de 2026. El software hecho contra el emulador, que va por detrás, puede necesitar un byte cambiado. Está explicado en el [capítulo 05 de la referencia técnica](../tecnica/05-v9968.md).

El V9968 se identifica como V9958 ante el software que pregunta, y el MSXimus como MSX2+. Los programas de diagnóstico dirán "V9958", y con el programa CHKVDP de HRA! saldrán dos V9968: es correcto, sondea las dos direcciones estándar y el MSXimus responde en las dos.

## 4. Lo que no hay

- Salida analógica de ningún tipo: ni compuesto, ni RGB, ni VGA.
- Modo 4:3 con marco.
- Un V9990: es un plan, no una función.

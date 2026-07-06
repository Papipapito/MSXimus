# MSX_up — Port del core MSXnano a la Tang Console 60K

Repo de **staging** para migrar el core **MSXnano** del **Tang Nano 20K** (Gowin **GW2AR-18C**, SDRAM integrada) a la **Tang Console 60K** (SOM Tang Mega 60K = Gowin **GW5AT-60**, GW5AT-LV60PG484, DDR3 512 MB, BL616 onboard, 2× USB-A host, HDMI, microSD).

> Aquí va cayendo, de forma incremental y validada, el código que se va migrando. **No** es un fork con historia completa: es una base nueva donde cada pieza entra ya adaptada (o marcada como pendiente). El core original de producción sigue viviendo en [`Papipapito/MSXnano`](https://github.com/Papipapito/MSXnano).

## Estado

Fase **F4 (port)** arrancando con enfoque **híbrido**: primero lo específico del 60K que no depende de fixes pre-port (árbol de relojes GW5A, CST/SDC nuevos, wrapper DDR3, IP que porta tal cual); `flash_rw`/SD/`YM2149` entran después ya con sus fixes.

Ver **[docs/PORT_PLAN.md](docs/PORT_PLAN.md)** para el plan completo.

## Base de partida

- Upstream: `Papipapito/MSXnano`, rama **`dev`**, commit **`390132d`** (incluye F0+F1 de limpieza pre-port ya aplicadas).
- Guía del port: **[docs/AUDIT_PRE_PORT_60K.md](docs/AUDIT_PRE_PORT_60K.md)** (auditoría de ~45 findings, 6 bugs confirmados, 4 frentes del port).

## Los 4 frentes del port

1. **Memoria** — SDRAM (GW2AR) → **DDR3** (GW5AT). El bloque más caro. Preservar la interfaz `ram_*`/`vram_*` como frontera estable + requisito "toda escritura VDP se completa" + waits adaptativos.
2. **Árbol de relojes** — `rPLL`→`PLLA`, CLKDIV regenerados para GW5A, constantes absolutas recalculadas para la base nueva (turbo WSX 5.369318 MHz, 859372 bps del ESP, LFSR del RTC…).
3. **Constraints** — `.sdc` y `.cst` **nuevos desde cero** (fallan en silencio si se copian; verificar que cada constraint matchea >0 objetos tras el primer PnR).
4. **Companion BL616** — topología TangCore del 60K; decidir si sigue el dock M0S externo.

## Estructura

```
docs/            Plan del port + auditoría + tablas code-grounded (constantes, memoria, manifiesto, placa)
fpga/src/        RTL portado (se rellena incrementalmente)
fpga/constraints/  msx_console60k.cst / .sdc (skeletons nuevos GW5AT-60)
fpga/ip/         IP GW5A regenerada (PLLA, CLKDIV, controlador DDR3)
```

## Licencia

**GPLv3** — derivado de `Papipapito/MSXnano` (GPLv3). Ver [LICENSE](LICENSE) y **[UPSTREAM.md](UPSTREAM.md)** (atribución + IP de terceros).

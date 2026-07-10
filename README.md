<p align="center"><img src="docs/logo/msximus.svg" alt="MSXimus" width="480"/></p>

# MSXimus — MSX2+ standalone en la Tang Console 60K

**MSXimus** es el hermano mayor del [**MSXnano**](https://github.com/Papipapito/MSXnano): el mismo linaje de core MSX2+ (goauld → MSXnano), portado y ampliado sobre la **Tang Console 60K** (SOM Tang Mega 60K = Gowin **GW5AT-60**, GW5AT-LV60PG484, DDR3 512 MB, BL616 onboard, 2× USB-A host, HDMI, microSD). *Nano* era el pequeño; *Maximus* es el grande.

> El nombre del repo hasta 2026-07-10 era `MSX_up` (staging del port); las URLs antiguas redirigen aquí.

## Estado

Base v3.0 estable + **Fase 3 completa**, todo validado en hardware:

- **Vídeo 720p** desacoplado por puente BRAM propio (HDMI arranca siempre, 4:3/16:9 por menú, scanlines).
- **Audio**: PSG, **doble SCC + estéreo**, OPLL (jt2413).
- **Teclado USB directo** (soft-host en el fabric, sin hub) por los USB-A onboard.
- **Modos consola** SG-1000 / ColecoVision (SN76489).
- Nextor + microSD, megaram (Konami4/Konami-SCC/ASCII8/16), menú de arranque propio.

En cocina (F4+): turbo Panasonic 5.37 MHz, gamepads USB→joystick MSX, MSX-Audio Y8950, y la pista **V9968**/V9990. Plan vivo en [fpga/BASE_MINIMA_60K_PLAN.md](fpga/BASE_MINIMA_60K_PLAN.md).

## Base de partida

- Upstream: `Papipapito/MSXnano`, rama `dev`, commit `390132d`.
- Auditoría del port: [docs/AUDIT_PRE_PORT_60K.md](docs/AUDIT_PRE_PORT_60K.md).
- Los bitstreams se entregan como `msximus_60k_YYYYMMDD_NN.fs` (hasta la _59 el prefijo fue `msxup_60k_`).

## Estructura

```
docs/            Planes, auditoría, logo, tablas code-grounded
fpga/            top.v, build.tcl, video720/ (puente HDMI), src/ (RTL), constraints/
tools/           Testbenches (SCC, vídeo, megaram) y utilidades
```

## Licencia

**GPLv3** — derivado de `Papipapito/MSXnano` (GPLv3). Ver [LICENSE](LICENSE) y [UPSTREAM.md](UPSTREAM.md) (atribución + IP de terceros). El logo (docs/logo/) es del proyecto.

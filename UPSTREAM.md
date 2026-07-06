# Atribución y procedencia (GPLv3)

Este repositorio es una **obra derivada** de:

- **MSXnano** — https://github.com/Papipapito/MSXnano
  - Rama base: `dev`
  - Commit base: `390132d061f14dbc6072bb20d1dbcce7012bd525` ("docs: diseño de frontend grafico…", tip de `dev`; RTL idéntico a `eaa8ac4` = F1 de limpieza pre-port)
  - Licencia: **GNU GPL v3**

Al ser derivado de código GPLv3, **MSX_up es GPLv3** y conserva los avisos de copyright y atribución de todo el código heredado, incluso mientras el repo es privado. Al distribuir el bitstream o el código habrá que acompañar el fuente correspondiente.

## IP de terceros heredada (revisar licencia al portar cada pieza)

Registrado a partir de la auditoría y del historial del proyecto. Confirmar el aviso concreto de cada fichero al migrarlo:

| Componente | Origen | Licencia | Notas de port |
|---|---|---|---|
| Core VDP V9958 | `tn_vdp_v3_v9958/` (basado en trabajos previos de VDP FPGA) | ver cabeceras | Exonerado en la investigación R-Type; porta tal cual (revisar IPs de reloj internas) |
| PSG YM2149 | `PSG_YM2149/YM2149.vhdl` | ver cabecera | Bug #2 (bucle combinacional del envelope) — hacer carga síncrona antes de confiar en placement GW5A |
| OPLL / FM (jt2413, jtopl) | jotego | **GPLv3** | Porta tal cual; base para futuros MSX-Audio Y8950 (jt8950) y OPL4 |
| G80A (T80 / Z80) | `G80A/` | ver cabecera | Porta tal cual |
| SD reader (WonderTANG) | `src/wondertang/sd_reader.sv` | ver cabecera | CRC de lectura ignorado por diseño upstream; fixes #3/#4/#5 antes de portar |
| Companion / SPI (MiSTeryNano) | `src/usb/mcu_spi_new.v`, `sys_ctrl.v`, `fpga_companion.v` | ver cabecera | Topología BL616 del 60K (TangCore); limpiar restos del core Atari ST |
| LPF OCM (KdL / OCM-PLD) | `src/ocm/lpf.vhd` | ver cabecera | Binding cross-language con `psg_filter.v` (LPF1/LPF2); nunca añadir el `lpf.vhd` del tn_vdp al build |
| Firmware ESP UNAPI | ducasp | ver upstream | Reloj fijo 859372 bps — recalcular prescaler `wifi_lite.vhd` para la base nueva |

> Pinout y firmware del companion del 60K: referencias **TangCore / nand2mario** (NESTang / TangCore tienen ports GW5AT-60 funcionando). Documentar procedencia de cualquier `.cst`/firmware reusado.

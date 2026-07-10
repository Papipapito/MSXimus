# Borrador de correo para ducasp (port UNAPI a BL616)

**Para**: ducasp (via GitHub issue en ESP32-UNAPI-Firmware, o su contacto de MSX.org)
**Asunto sugerido**: Porting your UNAPI firmware to the Bouffalo BL616 (new MSX FPGA target) — firmware ID request

---

Hi Daniel,

First of all, thank you for your amazing work on the ESP8266/ESP32 UNAPI
firmware and the whole MSX networking ecosystem — it has been running for
months in my MSXnano project (a standalone MSX2+ on the Tang Nano 20K FPGA,
derived from the Goa'uld/WonderTANG lineage, using your wifi.vhd UART core
and an ESP-01S with your legacy firmware).

I am now working on its bigger brother, "MSXimus": the same MSX2+ core
ported to the Sipeed Tang Console 60K (Gowin GW5AT-60). This board has an
onboard Bouffalo BL616 MCU (WiFi 6 + BT 5.2) with a factory-populated MHF4
antenna connector and a dedicated UART already wired to the FPGA fabric —
so it can become a zero-extra-hardware UNAPI modem.

My plan is to port your firmware to the BL616 as a sibling project
("BL616-UNAPI-Firmware"), using your excellent protocol documentation
(documentation/README.md of the ESP32 repo) as the normative spec, on top
of the Bouffalo SDK (FreeRTOS + lwIP + mbedTLS). Scope: the custom + TCP/IP
UNAPI command sets first (targeting your V2 driver), TLS next; I would
leave SSH out initially. The protocol implementation would remain LGPL-2.1
like your code, with proper attribution.

Two small things I wanted to ask before starting:

1. **Firmware ID**: could you reserve/bless an identifier for this target
   in your naming scheme (something like "UNBL616..." following your
   UN32C6xx pattern), so CFGESP/UPDTESP and future tools can identify it
   cleanly and never confuse it with an ESP build?

2. If you have any advice or "wish I had known" notes about the trickier
   corners of the firmware (the 2KB RX expectations, the update flows, or
   anything the docs understate), I am all ears.

And of course: if a BL616 target is something you would rather see done
differently (or inside your ecosystem in some other form), happy to adapt
— you are the upstream here.

Thanks again for everything you do for the MSX community!

Best regards,
Albert (Papipapito)
MSXnano / MSXimus — https://github.com/Papipapito/MSXimus

---

*Notas para Albert (no enviar): el repo de referencia es
https://github.com/ducasp/ESP32-UNAPI-Firmware — lo natural es abrir un
issue ahí con este texto; menciona Leo Manes/Stargate si responde bien
(él integró aquel port). El plan técnico completo está en la memoria de
Claude (análisis 2026-07-11: fases P0-P3, UART a 869.565 bps, esquema
partner@0x0 + app@0x40000 que conserva el USB-JTAG).*

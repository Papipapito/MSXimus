# menu/assets

El menú de arranque se compila con `make rom` (ver `menu/README.MSXimus.md`), y el resultado, `fm_logo_menu.bin` (16 KB), es la ROM que va en el pack de BIOS: **la FM-BIOS de MSX-MUSIC con el menú detrás**.

Esa base, `16k_msx2p_fm_logo_menu.bin`, lleva la FM-BIOS, que es propietaria, y por eso **no está en este repositorio**. Para compilar el menú hace falta la tuya en esta carpeta, con ese nombre (16 KB: la FM-BIOS de tu máquina con el hueco del menú vacío).

Los packs de BIOS completos, listos para grabar, están en las releases de este repositorio.

---

The boot menu builds with `make rom` (see `menu/README.MSXimus.md`); the result, `fm_logo_menu.bin` (16 KB), is the ROM that goes into the BIOS pack: **the MSX-MUSIC FM-BIOS with the menu behind it**. That base, `16k_msx2p_fm_logo_menu.bin`, contains the proprietary FM-BIOS and is **not in this repository**: put your own in this folder, with that name, to build the menu. Ready-to-flash BIOS packs are in the releases.

//=============================================================================
// msxgl_config.h — Plantilla MSXgl + UNAPI (MSX-DOS 2 .COM)
//
// Config minima y probada para un programa de consola DOS-2 que usa la salida
// de caracteres de DOS (DOS_CharOutput/DOS_StringOutput) y el TCP/IP UNAPI.
// Ajusta los modos VDP / modulos segun tu programa.
//=============================================================================
#pragma once

//-----------------------------------------------------------------------------
// BIOS
//-----------------------------------------------------------------------------
#define BIOS_CALL_MAINROM          BIOS_CALL_DIRECT
#define BIOS_USE_MAINROM           TRUE
#define BIOS_USE_VDP               TRUE
#define BIOS_USE_PSG               FALSE
#define BIOS_USE_SUBROM            FALSE
#define BIOS_USE_DISKROM           FALSE

//-----------------------------------------------------------------------------
// VDP — SCREEN 0 texto 40/80 columnas (T1 + T2)
//-----------------------------------------------------------------------------
#define VDP_VRAM_ADDR              VDP_VRAM_ADDR_17
#define VDP_INIT_50HZ              VDP_INIT_OFF
#define VDP_UNIT                   VDP_UNIT_U8

#define VDP_USE_MODE_T1            TRUE
#define VDP_USE_MODE_T2            TRUE
#define VDP_USE_MODE_G1            FALSE
#define VDP_USE_MODE_G2            FALSE
#define VDP_USE_MODE_MC            FALSE
#define VDP_USE_MODE_G3            FALSE
#define VDP_USE_MODE_G4            FALSE
#define VDP_USE_MODE_G5            FALSE
#define VDP_USE_MODE_G6            FALSE
#define VDP_USE_MODE_G7            FALSE

#define VDP_USE_VRAM16K            FALSE
#define VDP_USE_SPRITE             FALSE
#define VDP_USE_COMMAND            FALSE
#define VDP_USE_CUSTOM_CMD         FALSE
#define VDP_AUTO_INIT              FALSE
#define VDP_USE_UNDOCUMENTED       FALSE
#define VDP_USE_VALIDATOR          FALSE

//-----------------------------------------------------------------------------
// PRINT — no se usa (escribimos via DOS_CharOutput / secuencias VT-52)
//-----------------------------------------------------------------------------
#define PRINT_USE_TEXT             FALSE
#define PRINT_USE_VALIDATOR        FALSE

//-----------------------------------------------------------------------------
// INPUT — macros KEY_xxx necesarias en bios.h aunque no usemos el modulo input
//-----------------------------------------------------------------------------
#define INPUT_USE_KEYBOARD         TRUE
#define INPUT_USE_JOYSTICK         FALSE
#define INPUT_USE_MANAGER          FALSE
#define INPUT_JOY_UPDATE           FALSE
#define INPUT_KB_UPDATE            FALSE
#define INPUT_KB_UPDATE_MIN        0
#define INPUT_KB_UPDATE_MAX        0

//-----------------------------------------------------------------------------
// MEMORY
//-----------------------------------------------------------------------------
#define MEMORY_USE_VALIDATOR       FALSE

//-----------------------------------------------------------------------------
// SYSTEM
//-----------------------------------------------------------------------------
#define SYSTEM_USE_MSX_VERSION     FALSE
#define SYSTEM_USE_SLOT            FALSE

//-----------------------------------------------------------------------------
// DOS — basado en handle, sin FCB (DOS-2)
//-----------------------------------------------------------------------------
#define DOS_USE_FCB                FALSE
#define DOS_USE_HANDLE             TRUE
#define DOS_USE_UTILITIES          TRUE
#define DOS_USE_VALIDATOR          FALSE
#define DOS_USE_ERROR_HANDLER      FALSE
#define DOS_USE_BIOSCALL           TRUE

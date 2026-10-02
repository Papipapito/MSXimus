// project_config.js — Plantilla MSXgl + UNAPI (MSX-DOS 2 .COM)
//
// newproject.sh sustituye mxupdate por el nombre real del proyecto.
// El fichero fuente principal debe llamarse <nombre>.c

DoClean   = false;
DoCompile = true;
DoMake    = true;
DoPackage = true;
DoDeploy  = false;     // no copiamos a disco/floppy — el .com lo recoge build
DoRun     = false;

ProjName = "mxupdate";
ProjModules = [ ProjName ];
LibModules  = [ "system", "bios", "memory", "dos" ];

// Implementacion real de las llamadas TCP/IP UNAPI (la trae MSXgl de serie).
AddSources  = [ "../../engine/src/network/unapi_tcp.asm" ];

Machine = "2";          // MSX2
Target  = "DOS2";       // .COM bajo MSX-DOS 2
DiskSize = "720K";

// Parseamos la linea de comandos a mano si hace falta; no dependemos de la
// convencion de llamada SDCC para main(argc, argv).
DOSParseArg = false;

AppSignature = true;
AppCompany   = "AX";
AppID        = "MU";

Verbose           = true;
CompileComplexity = "Default";
Optim             = "Size";    // el codigo tiene que acabar antes de 4000h (UNAPI); el bucle del CRC ya es ensamblador

// IMPORTANTE (UNAPI + SDCC 4.2.0):
// SDCC 4.2.0 usa por defecto --sdcccall 1 (argumentos por registro: HL/DE).
// unapi_tcp.asm esta escrito para --sdcccall 0 (argumentos por pila).
// NO ponemos CompileOpt="--sdcccall 0" global porque rompe los helpers de
// z80.lib (__divsint, __mulint...) precompilados para sdcccall 1.
// En su lugar, lib/network/unapi_tcp.h declara cada tcpip_* con __sdcccall(0),
// asi SOLO esas llamadas usan la convencion por pila. El resto del codigo
// sigue en sdcccall 1. (El entorno copia esa cabecera en cada build.)

// Forzamos la RAM (codigo + datos) a empezar en $8000 (pagina 2). Asi nuestros
// datos NO caen en pagina 1 ($4000-$7FFF), donde el TSR UNAPI conmuta su mapper
// segment (si no, los datos quedan ocultos tras su codigo -> basura en la red).
ForceRamAddr = 0x8000;

// project_config.js — msxtest: ROM de validacion del MSXnano port 60K
// ROM 32K plana, MSX2+ (V9958). Basado en la config ROM de msx_coco.

DoClean   = false;
DoCompile = true;
DoMake    = true;
DoPackage = true;
DoDeploy  = false;
DoRun     = false;

ProjName    = "msxtest";
ProjModules = [ ProjName ];
LibModules  = [ "system", "bios", "vdp", "print", "input", "memory", "math", "psg", "msx-music", "draw", "clock" ];

Machine = "2P";        // MSX2+ (SCREEN 10/12 = YJK del V9958)
Target  = "ROM_32K";   // ROM plana de 32K (paginas 1 y 2)

AppSignature = true;
AppCompany   = "AX";
AppID        = "MT";

Verbose           = true;
CompileComplexity = "Default";

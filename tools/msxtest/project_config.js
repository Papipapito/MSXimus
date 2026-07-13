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
LibModules  = [ "system", "bios", "vdp", "print", "input", "memory", "math", "psg", "msx-music", "msx-audio", "draw", "clock" ];

Machine = "2P";        // MSX2+ (SCREEN 10/12 = YJK del V9958)
Target  = "ROM_KONAMI_SCC";  // mapper Konami SCC: prueba megaram + chip SCC

AppSignature = true;
AppCompany   = "AX";
AppID        = "MT";

Verbose           = true;
CompileComplexity = "Default";
Optim             = "SIZE";   // v12: el area plana (4000-BFFF) desbordo con
                              // Optim=Speed (Higher=C286) -> basura/resets.
                              // SIZE recupera varios KB. GUARD en build.sh.

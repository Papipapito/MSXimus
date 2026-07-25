// ============================================================================
// ru66_preload.svh — contenido de VRAM de la escena de los conejos de la demo
// ru66-v9968-demo (ver sprite3_ru66_setup.svh para la procedencia de cada dato).
//
// Se instancia a NIVEL DE MODULO y se llama en un `initial` en t=0 (antes de
// soltar reset), asi que la cache del shim arranca FRIA sobre estos datos:
// cero trafico de CPU en el setup (los 8 KB por el puerto VDP costaban ~5 ms
// de simulacion) y el estado es el de REGIMEN, que es lo que se quiere medir.
//
// El TB debe definir antes:  task vram_poke(input [17:0] a, input [7:0] d);
// ============================================================================
`ifndef RU66_X1
 `define RU66_X1 40
`endif
`ifndef RU66_X2
 `define RU66_X2 150
`endif
`ifndef RU66_PAT1
 `define RU66_PAT1 0
`endif
`ifndef RU66_PAT2
 `define RU66_PAT2 0
`endif

integer rp_i, rp_p, rp_a, rp_x;

// un plano de la SAT (8 bytes) tal cual los escribe el OTIR de la demo
task ru66_sat(input integer plane,
              input [15:0] y, input [7:0] mgy, input [7:0] mode,
              input [15:0] x, input [7:0] mgx, input [7:0] pattern);
    integer b;
begin
    b = 18'h10000 + plane*8;
    vram_poke(b[17:0]+0, y[7:0]);
    vram_poke(b[17:0]+1, y[15:8]);      // bits 15:14 = SZ (bit_shift)
    vram_poke(b[17:0]+2, mgy);
    vram_poke(b[17:0]+3, mode);         // [3:0]=palette set [4]=rvx [5]=rvy [7:6]=TP
    vram_poke(b[17:0]+4, x[7:0]);
    vram_poke(b[17:0]+5, x[15:8]);      // bits 6:4 = page
    vram_poke(b[17:0]+6, mgx);
    vram_poke(b[17:0]+7, pattern);
end
endtask

task ru66_preload;
begin
    // ---- SPT @0x8000: 32 KB de datos DISTINTIVOS (nibble != 0 = opaco) ----
    // color alto  = f(linea fuente), color bajo = f(grupo de 8 bytes)
    // => un fetch rancio sale como un color EQUIVOCADO en el volcado.
    for (rp_a = 18'h08000; rp_a < 18'h10000; rp_a = rp_a + 1)
        vram_poke(rp_a[17:0],
                  { 4'(((rp_a >> 7) % 15) + 1), 4'(((rp_a >> 3) % 15) + 1) });

    // ---- SAT @0x10000 ----
    // Planos 0-3: rabbit1 (dir=0 -> mode &= 0xEF), y=31|0xC000 (SZ=3), mgy=128
    for (rp_i = 0; rp_i < 4; rp_i = rp_i + 1) begin
        rp_x = `RU66_X1 + 16*rp_i;
        ru66_sat(rp_i, 16'hC01F, 8'd128, 8'h01,
                 16'(rp_x & 'h3FF), 8'd16, 8'(`RU66_PAT1 + rp_i));
    end
    // Planos 4-7: rabbit2 (dir=1 -> mode |= 0x10 => rvx), patrones descendentes
    for (rp_i = 0; rp_i < 4; rp_i = rp_i + 1) begin
        rp_x = `RU66_X2 + 16*rp_i;
        ru66_sat(4 + rp_i, 16'hC01F, 8'd128, 8'h12,
                 16'(rp_x & 'h3FF), 8'd16, 8'(`RU66_PAT2 + 3 - rp_i));
    end
    // Planos 8-9: sombras (SZ=0, mgy=12, mgx=64, patron 129, TP=50%)
    ru66_sat(8, 16'd153, 8'd12, 8'h81, 16'(`RU66_X1 & 'h3FF), 8'd64, 8'd129);
    ru66_sat(9, 16'd153, 8'd12, 8'h81, 16'(`RU66_X2 & 'h3FF), 8'd64, 8'd129);
    // Planos 10-23: area de mensaje (SZ=1 -> 16x32, mgy=32, patrones 144..157)
    for (rp_i = 0; rp_i < 14; rp_i = rp_i + 1)
        ru66_sat(10 + rp_i, 16'h40AA, 8'd32, 8'h00,
                 16'(16 + 16*rp_i), 8'd16, 8'(144 + rp_i));
    // Plano 24: marco de ventana ya desplegado (mgx=224, patron 128)
    ru66_sat(24, 16'd166, 8'd40, 8'h43, 16'd16, 8'd224, 8'd128);
    // Plano 25: terminador (Y=216)
    ru66_sat(25, 16'd216, 8'd0, 8'h00, 16'd0, 8'd0, 8'd0);

    $display("RU66 PRELOAD: SAT@0x10000 26 planos, SPT@0x8000 32KB | x1=%0d x2=%0d pat1=%0d pat2=%0d",
             `RU66_X1, `RU66_X2, `RU66_PAT1, `RU66_PAT2);
end
endtask

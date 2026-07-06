/*  This file is part of JTOPL.

    JTOPL is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTOPL is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTOPL.  If not, see <http://www.gnu.org/licenses/>.

	Author: Jose Tejada Gomez. Twitter: @topapate
	Version: 1.0
	Date: 19-6-2020
	*/

// stages must be greater than 2
module jtopl_sh #(parameter width=5, stages=24 )
(
	input 				clk,
	input				cen,
	input	[width-1:0]	din,
   	output	[width-1:0]	drop
);

// GW5A port: GowinSynthesis extrae este banco de shift-registers a BSRAM SP con
// WRITE_MODE=2'b10 (read-before-write), que el BSRAM del GW5A NO soporta (PA2122).
// Forzamos registros con syn_srlstyle (SUG550 §5.17; syn_ramstyle NO aplica a
// la extraccion de shift-registers). ~width*stages FFs, sobran en el 60K.
reg [stages-1:0] bits[width-1:0] /* synthesis syn_srlstyle = "registers" */;

genvar i;
generate
	for (i=0; i < width; i=i+1) begin: bit_shifter
		always @(posedge clk) if(cen) begin
			bits[i] <= {bits[i][stages-2:0], din[i]};
		end
		assign drop[i] = bits[i][stages-1];
	end
endgenerate

endmodule

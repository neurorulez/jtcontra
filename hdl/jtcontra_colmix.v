/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 03-05-2020 */

// Equivalent to KONAMI 007593

module jtcontra_colmix(
    input               rst,
    input               clk,
    input               clk24,
    input               pxl2_cen,
    input               pxl_cen,
    input               LHBL,
    input               LVBL,
    output reg          LHBL_dly,
    output reg          LVBL_dly,
    // CPU      interface
    input               pal_cs,
    input               cpu_rnw,
    input               cpu_cen,
    input      [ 7:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    output     [ 7:0]   pal_dout,
    // GFX colour requests
    input      [ 6:0]   gfx1_pxl,
    input      [ 6:0]   gfx2_pxl,
    // Colours
    output reg [ 4:0]   red,
    output reg [ 4:0]   green,
    output reg [ 4:0]   blue
);

wire        pal_we = cpu_cen & ~cpu_rnw & pal_cs;
wire [ 7:0] col_data;
wire [ 7:0] col_addr;
wire        gfx_sel;
reg         pal_half;
reg  [14:0] pxl_aux;
wire [ 6:0] gfx_mux;

assign gfx_sel  = gfx1_pxl[3:0]==4'h0 ? gfx2_pxl[4] : 1'b0;
assign gfx_mux  = gfx_sel ? gfx2_pxl : gfx1_pxl;
assign col_addr = { gfx_mux, pal_half };


jtframe_dual_ram #(.aw(8)) u_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( pal_we    ),
    .q0     ( pal_dout  ),
    // Port 1
    .data1  (           ),
    .addr1  ( col_addr  ),
    .we1    ( 1'b0      ),
    .q1     ( col_data  )
);

always @(posedge clk) begin
    if( rst ) begin
        pal_half <= 0;
        red      <= 5'd0;
        green    <= 5'd0;
        blue     <= 5'd0;
    end else begin
        pxl_aux  <= { pxl_aux[6:0], col_data };
        if( pxl_cen ) begin
            LVBL_dly <= LVBL;
            LHBL_dly <= LHBL;
            { blue, green, red } <= (!LVBL || !LHBL) ? 15'd0 : pxl_aux;
            pal_half <= 1;
        end else 
            pal_half <= ~pal_half;
    end
end

endmodule
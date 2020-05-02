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
    Date: 02-05-2020 */

// Main features of Konami's 007121 hardware
// Some elements have been factored out one level up (H/S timing...)

module jtcontra_gfx(
    input                rst,
    input                clk,
    input                clk24,
    input                pxl2_cen,
    input                pxl_cen,
    input                LHBL,
    input                LVBL,
    input                LHBL_dly,
    input                LVBL_dly,
    input                HS,
    input                VS,
    // CPU      interface
    input                gfx_cs,
    input                cpu_rnw,
    input                cpu_cen,
    input      [12:0]    cpu_addr,
    input      [ 7:0]    cpu_dout,
    output     [ 7:0]    gfx_dout,
    output reg           cpu_irqn
);

reg     last_LVBL;
wire    gfx_we = cpu_cen & ~cpu_rnw & gfx_cs;

jtframe_dual_ram #(.aw(13)) u_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( gfx_we    ),
    .q0     ( gfx_dout  ),
    // Port 1
    .data1  (           ),
    .addr1  (           ),
    .we1    ( 1'b0      ),
    .q1     (           )
);

always @(posedge clk24) begin
    last_LVBL <= LVBL;
    if( !LVBL && last_LVBL ) cpu_irqn <= 0;
    else if( LHBL ) cpu_irqn <= 1;
end


endmodule
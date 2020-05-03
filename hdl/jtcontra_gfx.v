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
    input                HS,
    input                VS,
    input   [8:0]        hdump,
    input   [8:0]        vdump,
    input   [8:0]        vrender,
    input   [8:0]        vrender1,
    output               flip,
    // CPU      interface
    input                vram_cs,
    input                cfg_cs,
    input                cpu_rnw,
    input                cpu_cen,
    input      [12:0]    cpu_addr,
    input      [ 7:0]    cpu_dout,
    output     [ 7:0]    gfx_dout,
    output reg           cpu_irqn,
    // SDRAM interface
    output     [16:0]    rom_addr,
    input      [15:0]    rom_data,
    input                rom_ok,
    output               rom_cs,
    // colour output
    output reg [ 6:0]    pxl_out
);

reg         last_LVBL;
wire        gfx_we = cpu_cen & ~cpu_rnw & vram_cs;
reg  [7:0]  mmr[0:7];
wire [8:0]  hpos = { mmr[1][0], mmr[0] };
wire [7:0]  vpos = mmr[2];
wire [4:0]  tile_extra = { mmr[3][0], mmr[4][3:0] };
wire        obj_update = mmr[3][3];
wire        layout     = mmr[3][4]; // 1 for wide layout
wire [3:0]  extra_mask = mmr[4][7:4];
wire        nmi_en     = mmr[7][0];
wire        irq_en     = mmr[7][1];
wire        firq_en    = mmr[7][2];
assign      flip       = mmr[7][3];

always @(posedge clk24) begin
    if( rst ) begin
        { mmr[7], mmr[6], mmr[5], mmr[4] } <= 32'd0;
        { mmr[3], mmr[2], mmr[1], mmr[0] } <= 32'd0;
    end else if(cpu_cen) begin
        if(!cpu_rnw && cfg_cs)
            mmr[ cpu_addr[2:0] ] <= cpu_dout;
    end
end

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
    if( !LVBL && last_LVBL && irq_en ) cpu_irqn <= 0;
    else if( LHBL ) cpu_irqn <= 1;
end


endmodule
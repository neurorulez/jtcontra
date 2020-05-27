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

module jtcontra_video(
    input               rst,
    input               clk,
    input               clk24,
    output              pxl2_cen,
    output              pxl_cen,
    output              LHBL,
    output              LVBL,
    output              LHBL_dly,
    output              LVBL_dly,
    output              HS,
    output              VS,
    output              flip,
    input               dip_pause,
    input               start_button,
    // PROMs
    input      [ 9:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,
    // CPU      interface
    input               gfx1_vram_cs,
    input               gfx2_vram_cs,
    input               gfx1_cfg_cs,
    input               gfx2_cfg_cs,
    input               pal_cs,
    input               cpu_rnw,
    input               cpu_cen,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    output     [ 7:0]   gfx1_dout,
    output     [ 7:0]   gfx2_dout,
    output     [ 7:0]   pal_dout,
    output              cpu_irqn,
    // SDRAM interface
    output     [17:0]   gfx1_addr,
    input      [15:0]   gfx1_data,
    input               gfx1_ok,
    output              gfx1_cs,
    output     [17:0]   gfx2_addr,
    input      [15:0]   gfx2_data,
    input               gfx2_ok,
    output              gfx2_cs,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    // Test
    input      [ 3:0]   gfx_en
);

wire [8:0] vrender, vrender1, vdump, hdump;
wire [6:0] gfx1_pxl, gfx2_pxl;

jtframe_cen48 u_cen(
    .clk        ( clk       ),    // 48 MHz
    .cen12      ( pxl2_cen  ),
    .cen16      (           ),
    .cen8       (           ),
    .cen6       ( pxl_cen   ),
    .cen4       (           ),
    .cen4_12    (           ), // cen4 based on cen12
    .cen3       (           ),
    .cen3q      (           ), // 1/4 advanced with respect to cen3
    .cen1p5     (           ),
    .cen12b     (           ),
    .cen6b      (           ),
    .cen3b      (           ),
    .cen3qb     (           ),
    .cen1p5b    (           )
);

jtframe_vtimer /*#(.VB_END(9'o17))*/ u_timer(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .H          ( hdump         ),
    .Hinit      (               ),
    .Vinit      (               ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            )
);

wire gfx1_prom_we = ~prog_addr[9] & prom_we;
wire gfx2_prom_we =  prog_addr[9] & prom_we;

jtcontra_gfx u_gfx1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    // PROMs
    .prom_we    ( gfx1_prom_we  ),
    .prog_addr  ( prog_addr[8:0]),
    .prog_data  ( prog_data[3:0]),
    // Screen position
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .flip       ( flip          ),
    // CPU      interface
    .vram_cs    ( gfx1_vram_cs  ),
    .cfg_cs     ( gfx1_cfg_cs   ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .gfx_dout   ( gfx1_dout     ),
    .cpu_irqn   ( cpu_irqn      ),
    // SDRAM interface
    .rom_addr   ( gfx1_addr     ),
    .rom_data   ( gfx1_data     ),
    .rom_cs     ( gfx1_cs       ),
    .rom_ok     ( gfx1_ok       ),
    .pxl_out    ( gfx1_pxl      ),
    // Test
    .gfx_en     ( gfx_en[1:0]   )
);

jtcontra_gfx u_gfx2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    // PROMs
    .prom_we    ( gfx2_prom_we  ),
    .prog_addr  ( prog_addr[8:0]),
    .prog_data  ( prog_data[3:0]),
    // Screen position
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .flip       (               ),
    // CPU      interface
    .vram_cs    ( gfx2_vram_cs  ),
    .cfg_cs     ( gfx2_cfg_cs   ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .gfx_dout   ( gfx2_dout     ),
    .cpu_irqn   (               ),
    // SDRAM interface
    .rom_addr   ( gfx2_addr     ),
    .rom_data   ( gfx2_data     ),
    .rom_cs     ( gfx2_cs       ),
    .rom_ok     ( gfx2_ok       ),
    .pxl_out    ( gfx2_pxl      ),
    // Test
    .gfx_en     ( gfx_en[3:2]   )
);

wire [4:0] cm_red, cm_green, cm_blue;
wire       cm_LHBL, cm_LVBL;

jtcontra_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_dly   ( cm_LHBL       ),
    .LVBL_dly   ( cm_LVBL       ),
    // CPU      interface
    .pal_cs     ( pal_cs        ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr[7:0] ),
    .cpu_dout   ( cpu_dout      ),
    .pal_dout   ( pal_dout      ),
    // Colours
    .gfx1_pxl   ( gfx1_pxl      ),
    .gfx2_pxl   ( gfx2_pxl      ),
    .red        ( cm_red        ),
    .green      ( cm_green      ),
    .blue       ( cm_blue       )
);

`ifdef SIMULATION
`define NOCREDITS
`endif

//`ifdef MISTER_NOHDMI
//`define NOCREDITS
//`endif

`ifndef NOCREDITS
wire [23:0] colmix_rgb = { cm_red, cm_green, cm_blue };

jtframe_credits #(
    .PAGES  (      3 ),
    .COLW   (      5 ),
    .BLKPOL (      0 )
) (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    // input image
    .HB         ( cm_LHBL       ),
    .VB         ( cm_LVBL       ),
    .rgb_in     ( colmix_rgb    ),
    .enable     ( ~dip_pause    ),
    .toggle     ( start_button  ),

    // output image
    .HB_out     ( LHBL_dly      ),
    .VB_out     ( LVBL_dly      ),
    .rgb_out    ( {red, green, blue } )
);
`else
assign {red, green, blue }    = { cm_red, cm_green, cm_blue };
assign { LHBL_dly, LVBL_dly } = { cm_LHBL, cm_LVBL };
`endif

endmodule
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
    // CPU      interface
    input               gfx1_cs,
    input               gfx2_cs,
    input               pal_cs,
    input               cpu_rnw,
    input               cpu_cen,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    output     [ 7:0]   gfx1_dout,
    output     [ 7:0]   gfx2_dout,
    output     [ 7:0]   pal_dout,
    output              cpu_irqn,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue
);

assign LVBL_dly = LVBL;
assign LHBL_dly = LHBL;

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

jtframe_vtimer u_timer(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      (               ),
    .vrender    (               ),
    .vrender1   (               ),
    .H          (               ),
    .Hinit      (               ),
    .Vinit      (               ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            )
);

jtcontra_gfx u_gfx1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),
    .cpu_cen    ( cpu_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        ),
    // CPU      interface
    .gfx_cs     ( gfx1_cs   ),
    .cpu_rnw    ( cpu_rnw   ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .gfx_dout   ( gfx1_dout ),
    .cpu_irqn   ( cpu_irqn  )
);

jtcontra_gfx u_gfx2(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),
    .cpu_cen    ( cpu_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        ),
    // CPU      interface
    .gfx_cs     ( gfx2_cs   ),
    .cpu_rnw    ( cpu_rnw   ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .gfx_dout   ( gfx2_dout ),
    .cpu_irqn   (           )
);

jtcontra_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    // CPU      interface
    .pal_cs     ( pal_cs        ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr[7:0] ),
    .cpu_dout   ( cpu_dout      ),
    .pal_dout   ( pal_dout      ),
    // Colours
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
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
    input           rst,
    input           clk,
    output          pxl2_cen,
    output          pxl_cen,
    output          LHBL,
    output          LVBL,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS
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


endmodule
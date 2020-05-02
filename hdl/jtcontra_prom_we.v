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
    Date: 02-5-2020 */

module jtcontra_prom_we(
    input                clk,
    input                downloading,
    input      [24:0]    ioctl_addr,
    input      [ 7:0]    ioctl_data,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    input                sdram_ack
);

always @(posedge clk) begin
    if ( ioctl_wr && downloading ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_data;
        prog_addr <= ioctl_addr[22:1];
        prog_mask <= ioctl_addr[0] ? 2'b10 : 2'b01;            
    end
    else begin
        if(!downloading || sdram_ack) prog_we  <= 1'b0;
    end
end

endmodule

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

module jtcontra_gfx_obj(
    input                rst,
    input                clk,
    input                pxl_cen,
    input                LHBL,
    input                LVBL,
    input       [ 8:0]   vrender,
    output reg           done,
    output      [ 9:0]   scan_addr, // max 64 sprites in total
    // Line buffer
    input       [ 8:0]   hdump,
    input       [ 8:0]   dump_start,
    output      [ 7:0]   pxl,
    // SDRAM
    output reg           rom_cs,
    output      [17:0]   rom_addr,
    input                rom_ok,
    input       [15:0]   rom_data,
    input       [ 7:0]   obj_scan
);

reg  [13:0] code;
reg  [ 3:0] pal;
reg         line_we;
reg         h4;
reg  [ 2:0] byte_sel;
reg  [ 3:0] st;
reg         last_LHBL;
reg  [ 8:0] hn, vn;
reg  [ 4:0] bank;
reg  [ 7:0] dump_cnt;
reg  [ 3:0] size_cnt;
reg  [15:0] pxl_data;
reg  [ 8:0] xpos;
reg  [ 9:0] scan_base;
reg         obj_we;
reg  [ 7:0] line_din;
wire [ 9:0] line_addr;

reg  [ 5:0] attr;
reg  [ 2:0] height;
reg  [ 8:0] upper_limit;
reg  [ 2:0] vsub;
reg         line;
wire [ 9:0] line_dump = { ~line, hdump };

assign      line_addr = { line, xpos };
assign      scan_addr = scan_base + byte_sel;

always @(*) begin
    case( attr[3:1] )
        3'd0: height = 3'b010; // 16x16
        3'd1: height = 3'b001; // 16x8
        3'd2: height = 3'b010; // 8x16
        3'd3: height = 3'b001; // 8x8
        3'd4: height = 3'b100; // 32x32
        default: height = 3'b010; // 16x16
    endcase
    upper_limit = {1'b0, obj_scan} + { 3'b0, height, 3'd0 };
end

assign rom_addr = { code, vsub, h4 }; // 14+3+1 = 18

always @(posedge clk) begin
    if( rst ) begin
        done    <= 1;
        pal     <= 4'd0;
        code    <= 13'd0;
        line_we <= 0;
        line    <= 0;
        st      <= 3'd0;
        size_cnt<= 4'd0;
        dump_cnt<= 8'd0;
    end else begin
        last_LHBL <= LHBL;
        if( LHBL && !last_LHBL && LVBL) begin
            done      <= 0;
            rom_cs    <= 0;
            st        <= 3'd0;
            scan_base <= 10'd0;
            byte_sel  <= 3'd4;      // get obj size
            line      <= ~line;
        end else begin
            if(!done) st <= st + 1;
            case( st )
                0: begin
                    rom_cs   <= 0;
                    byte_sel <= 3'd2;   // get y position
                end
                1: begin
                    attr        <= obj_scan[5:0];
                    code[13:12] <= obj_scan[7:6];
                    byte_sel    <= 3'd0;   // get code
                    size_cnt    <= obj_scan[3] ? 4'b1 : ( obj_scan[2] ? 4'b11 : 4'b1111 );
                end
                2: begin
                    vsub <= vrender[2:0]-obj_scan[2:0];
                    if( vrender < obj_scan || vrender >= upper_limit ) begin
                        st        <= 9; // next tile
                    end else begin
                        byte_sel <= 3'd1; // get colour
                    end
                end
                3: begin
                    code[9:2] <= obj_scan;
                    byte_sel  <= 3'd3; // x position
                end
                4: begin
                    code[11:10] <= obj_scan[1:0];
                    code[ 1:0 ] <= obj_scan[3:2];
                    pal         <= obj_scan[7:4];
                    rom_cs      <= 1;
                end
                5: begin
                    xpos <= {1'b0, obj_scan} + dump_start;
                end
                6: begin
                    if( rom_ok ) begin
                        pxl_data <= rom_data;
                        rom_cs   <= 0;
                        dump_cnt <= 4'h7;
                        h4       <= 0;
                    end else st <= st;
                end
                7: begin // dumps 4 pixels
                    if( dump_cnt[0] ) st<=st;
                    dump_cnt <= dump_cnt>>1;
                    pxl_data <= pxl_data << 4;
                    xpos     <= xpos + 9'd1;
                    line_din <= { pal, pxl_data[15:12] };
                    line_we  <= 1;
                end
                8: begin
                    line_we <= 0;
                    {code[1:0],h4} <= {code[1:0],h4} + 3'd1;
                    if( !h4 ) size_cnt <= size_cnt>>1;
                    if( !h4 && size_cnt[0] ) begin
                        rom_cs  <= 1;
                        st      <= 6; // wait for new ROM data
                    end else begin                            
                        st      <= 9; // next tile
                    end
                end
                9: begin
                    byte_sel  <= 3'd2;
                    st        <= 0;
                    if( scan_base < 10'h13b ) begin
                        scan_base <= scan_base + 10'd5;
                    end else begin
                        done      <= 1;
                        rom_cs    <= 0;
                    end
                end
            endcase // st
        end
    end
end

jtframe_obj_buffer #(
    .ALPHA(0), 
    .BLANK(0)
) u_line(
    .clk    ( clk           ),
    // New data writes
    .wr_data( line_din      ),
    .wr_addr( line_addr     ),
    .we     ( line_we       ),
    // Old data reads (and erases)
    .rd_addr( line_dump     ),
    .rd     ( pxl_cen       ),  // data will be erased after the rd event
    .rd_data( pxl           )
);


endmodule
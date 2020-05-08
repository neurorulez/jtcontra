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

module jtcontra_gfx_tilemap(
    input                rst,
    input                clk,
    input                LHBL,
    input                LVBL,
    input       [ 8:0]   hpos,
    input       [ 7:0]   vpos,
    input       [ 8:0]   vrender,
    output reg           lyr,
    output reg           line,
    output reg           done,
    output               chr_we,
    output               scr_we,
    output reg  [ 7:0]   line_din,
    output      [ 9:0]   line_addr,
    output      [10:0]   scan_addr,
    // SDRAM
    output reg           rom_cs,
    output      [17:0]   rom_addr,
    input                rom_ok,
    input       [15:0]   rom_data,
    input       [ 7:0]   attr_scan,
    input       [ 7:0]   code_scan,
    // Configuration
    input       [ 8:0]   chr_dump_start,
    input       [ 8:0]   scr_dump_start,
    input                pal_msb,
    input       [ 3:0]   extra_mask,
    input       [ 3:0]   extra_bits,
    input       [ 1:0]   code9_sel,
    input       [ 1:0]   code10_sel,
    input       [ 1:0]   code11_sel,
    input       [ 1:0]   code12_sel
);

reg  [12:0] code;
reg  [ 3:0] pal;
reg         line_we;
reg  [ 2:0] st;
reg         last_LHBL;
reg  [ 8:0] hn, vn;
reg  [ 4:0] bank;
reg  [ 7:0] dump_cnt;
reg  [15:0] pxl_data;
reg  [8:0]  hrender;
assign      line_addr = { line, hrender };

wire [ 9:0] lyr_hn0 = lyr ? 9'd0 : hpos;

assign      chr_we = line_we &  lyr;
assign      scr_we = line_we & ~lyr;
assign      rom_addr  = { 1'b0, code, vn[2:0], hn[2] }; // 13+3+1 = 17!
assign      scan_addr = { lyr, vn[7:3], hn[7:3] }; // 1 + 5 + 5 = 11

always @(*) begin
    bank[0] = attr_scan[7];
    bank[1] = extra_mask[0] ? extra_bits[0] : attr_scan[3+code9_sel ];
    bank[2] = extra_mask[1] ? extra_bits[1] : attr_scan[3+code10_sel];
    bank[3] = extra_mask[2] ? extra_bits[2] : attr_scan[3+code11_sel];
    bank[4] = extra_mask[3] ? extra_bits[3] : attr_scan[3+code12_sel];
end

always @(posedge clk) begin
    if( rst ) begin
        done    <= 1;
        lyr     <= 0;
        pal     <= 4'd0;
        code    <= 13'd0;
        line_we <= 0;
        st      <= 3'd0;
        line    <= 0;
    end else begin
        last_LHBL <= LHBL;
        if( LHBL && !last_LHBL && LVBL) begin
            line   <= ~line;
            lyr    <= 0;
            done   <= 0;
            rom_cs <= 0;
            st     <= 3'd0;
        end else begin
            if(!done) st <= st + 1;
            case( st )
                0: begin
                    vn <= vrender + (lyr ? 9'd0 : {1'b0, vpos})+9'd8;
                    hn <= lyr_hn0;
                    hrender <= { 7'd0, lyr_hn0[1:0] } + 
                        ( lyr ? chr_dump_start : scr_dump_start );
                end
                2: begin
                    code   <= { bank, code_scan };
                    pal    <= { pal_msb & attr_scan[3], attr_scan[2:0] };
                    rom_cs <= 1;
                end
                4: begin
                    if( rom_ok ) begin
                        pxl_data <= rom_data;
                        rom_cs   <= 0;
                        dump_cnt <= 4'h7;
                    end else st <= st;
                end
                5: begin // dumps 4 pixels
                    if( dump_cnt[0] ) st<=st;
                    dump_cnt <= dump_cnt>>1;
                    pxl_data <= pxl_data << 4;
                    hrender  <= hrender + 9'd1;
                    line_din <= { pal, pxl_data[15:12] };
                    line_we  <= 1;
                end
                6: begin
                    line_we <= 0;
                    if( hn < 9'd320 ) begin
                        hn      <= hn + 9'd4;
                        st      <= 7;
                        if( !hn[2] ) begin
                            rom_cs  <= 1;
                            st      <= 3; // wait for new ROM data
                        end else begin
                            st      <= 1; // collect tile info
                        end
                    end else begin
                        st  <= 0;
                        if( !lyr ) begin
                            lyr <= 1;
                        end else begin
                            done <= 1;
                        end
                    end
                end
            endcase // st
        end
    end
end

endmodule
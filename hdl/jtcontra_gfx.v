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
    output     [17:0]    rom_addr,
    input      [15:0]    rom_data,
    input                rom_ok,
    output reg           rom_cs,
    // colour output
    output reg [ 7:0]    pxl_out,
    // test
    input      [ 1:0]    gfx_en
);

parameter H0 = 9'h75; // initial value of hdump after H blanking

reg         last_LVBL;
wire        gfx_we = cpu_cen & ~cpu_rnw & vram_cs;

reg         line;
reg  [8:0]  hrender;
wire [9:0]  line_addr = { line, hrender };
wire [7:0]  chr_pxl, scr_pxl;

////////// Memory Mapped Registers
reg  [7:0]  mmr[0:7];
wire [8:0]  hpos = { mmr[1][0], mmr[0] };
wire [7:0]  vpos = mmr[2];
wire [4:0]  tile_extra = { mmr[3][0], mmr[4][3:0] };
wire        obj_update = mmr[3][3];
wire        layout     = mmr[3][4]; // 1 for wide layout
wire [3:0]  extra_mask = mmr[4][7:4];
wire [1:0]  code9_sel, code10_sel, code11_sel, code12_sel;
wire        nmi_en     = mmr[7][0];
wire        irq_en     = mmr[7][1];
wire        firq_en    = mmr[7][2];
assign      flip       = mmr[7][3];
wire        pal_msb    = mmr[6][0];
wire        hflip_en   = mmr[6][1];
wire        vflip_en   = mmr[6][2];
wire        prio_en    = mmr[6][3];
wire [1:0]  pal_bank   = mmr[6][5:4];
wire        char_en    = 1;
// wire        char_en    =~mmr[7][4];     // undocumented by MAME

assign      { code12_sel, code11_sel, code10_sel, code9_sel } = mmr[5];

// Other configuration
reg  [8:0]  chr_dump_start;
reg  [8:0]  chr_dump_end;
reg  [8:0]  scr_dump_start;
reg  [8:0]  scr_dump_end;

// Scan
reg         lyr, done;
wire [10:0] scan_addr;
wire [10:0] ram_addr = { cpu_addr[11], cpu_addr[9:0] };
wire        attr_we  = gfx_we & ~cpu_addr[10] & ~cpu_addr[12];
wire        code_we  = gfx_we &  cpu_addr[10] & ~cpu_addr[12];
wire        obj_we   = gfx_we &  cpu_addr[12];
wire [7:0]  code_dout, attr_dout, obj_dout;
assign      gfx_dout = cpu_addr[12] ? obj_dout : 
                      (cpu_addr[10] ? code_dout : attr_dout);
reg  [ 4:0] bank;
reg  [12:0] code;
reg  [ 3:0] pal;
reg  [ 7:0] dump_cnt;
reg  [15:0] pxl_data;
wire [ 7:0] code_scan, attr_scan;

reg  [ 7:0] line_din;
reg  [ 8:0] hn, vn;
reg         line_we;

wire        chr_we = line_we &  lyr;
wire        scr_we = line_we & ~lyr;
wire [9:0]  line_dump;

assign      scan_addr = { lyr, vn[7:3], hn[7:3] }; // 1 + 5 + 5 = 11
assign      rom_addr  = { 1'b0, code, vn[2:0], hn[2] }; // 13+3+1 = 17!
assign      line_dump = { ~line, hdump };

always @(posedge clk24) begin
    if( rst ) begin
        { mmr[7], mmr[6], mmr[5], mmr[4] } <= 32'd0;
        { mmr[3], mmr[2], mmr[1], mmr[0] } <= 32'd0;
    end else if(cpu_cen) begin
        if(!cpu_rnw && cfg_cs)
            mmr[ cpu_addr[2:0] ] <= cpu_dout;
        // Apply layout
        if( layout ) begin
            // total 35*8 = 280 visible pixels
            chr_dump_start <= 9'h74;
            chr_dump_end   <= chr_dump_start+5*8;
            scr_dump_start <= chr_dump_end;
            scr_dump_end   <= scr_dump_start+30*8;
        end else begin
            // total 32*8 = 256 visible pixels
            chr_dump_start <= 9'h74+2*8;
            chr_dump_end   <= chr_dump_start+32*8;
            scr_dump_start <= chr_dump_start;
            scr_dump_end   <= chr_dump_end;
        end
    end
end

always @(*) begin
    bank[0] = attr_scan[7];
    bank[1] = attr_scan[3+code9_sel ];
    bank[2] = attr_scan[3+code10_sel];
    bank[3] = attr_scan[3+code11_sel];
    bank[4] = attr_scan[3+code12_sel];
end

jtframe_dual_ram #(.aw(11)) u_attr_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( ram_addr  ),
    .we0    ( attr_we   ),
    .q0     ( attr_dout ),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( attr_scan )
);

jtframe_dual_ram #(.aw(11)) u_code_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( ram_addr  ),
    .we0    ( code_we   ),
    .q0     ( code_dout ),
    // Port 1
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( code_scan )
);

jtframe_dual_ram #(.aw(12)) u_obj_ram(
    .clk0   ( clk24     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr[11:0] ),
    .we0    ( obj_we    ),
    .q0     ( obj_dout  ),
    // Port 1
    .data1  (           ),
    .addr1  (           ),
    .we1    ( 1'b0      ),
    .q1     (           )
);

// Line buffers could work with only AW=9 but it would
// make logic a bit more complex without any benefit in
// the FPGA, as the minimum size BRAM available is normally AW=10
jtframe_dual_ram #(.aw(10)) u_line_char(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( line_din  ),
    .addr0  ( line_addr ),
    .we0    ( chr_we    ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( line_dump ),
    .we1    ( 1'b0      ),
    .q1     ( chr_pxl   )
);

jtframe_dual_ram #(.aw(10)) u_line_scr(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( line_din  ),
    .addr0  ( line_addr ),
    .we0    ( scr_we    ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( line_dump ),
    .we1    ( 1'b0      ),
    .q1     ( scr_pxl   )
);

always @(posedge clk) begin
    if( rst ) begin
        cpu_irqn <= 1;
    end else if(pxl_cen) begin
        last_LVBL <= LVBL;
        if( !LVBL && last_LVBL ) begin
            if( irq_en ) cpu_irqn <= 0;
        end
        else if( LHBL ) cpu_irqn <= 1;
    end
end

wire [7:0] scr_pxl_gated = {8{gfx_en[1]}} & scr_pxl;
wire [7:0] chr_pxl_gated = {8{gfx_en[0] & char_en}} & chr_pxl;
wire       chr_blank     = chr_pxl_gated[3:0] == 4'h0;
wire       chr_area      = hdump>=chr_dump_start && hdump<chr_dump_end;
wire       scr_area      = hdump>=scr_dump_start && hdump<scr_dump_end;
reg        draw_scr;

always @(*) begin
    draw_scr <= ( chr_area && !scr_area) ? 0 : (
                (!chr_area &&  scr_area) ? 1 : (
                 chr_blank ? 1 : 0 ));
end

always @(posedge clk) begin
    if( rst ) begin
        pxl_out <= ~7'd0;
    end else if(pxl_cen) begin
        pxl_out <= draw_scr ? scr_pxl_gated : chr_pxl_gated;
    end
end

reg  [ 2:0] st;
reg         last_LHBL;
wire [ 9:0] lyr_hn0 = lyr ? 9'd0 : hpos;

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
                    vn <= vrender + (lyr ? 9'd0 : {1'b0, vpos});
                    hn <= lyr_hn0;
                    hrender <= { 7'd0, lyr_hn0[1:0] } + 
                        ( lyr ? chr_dump_start : scr_dump_start );
                end
                2: begin
                    code   <= { bank, code_scan };
                    pal    <= { pal_msb, attr_scan[2:0] };
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
                        if( !lyr && char_en ) begin
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
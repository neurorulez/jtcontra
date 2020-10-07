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

//  IRQ triggers once per frame
// FIRQ triggers once per ?
//  NMI triggers once per ?

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
    // PROMs
    input      [ 8:0]    prog_addr,
    input      [ 3:0]    prog_data,
    input                prom_we,
    // CPU      interface
    input                cs,
    input                cpu_rnw,
    input                cpu_cen,
    input      [13:0]    addr,
    input      [ 7:0]    cpu_dout,
    output reg [ 7:0]    dout,
    output reg           cpu_irqn,
    output reg           cpu_nmin,
    // SDRAM interface
    output reg           rom_obj_sel,   // pin H2 of actual chip
    output reg [17:0]    rom_addr,
    input      [15:0]    rom_data,
    input                rom_ok,
    output reg           rom_cs,
    // colour output
    output reg [ 6:0]    pxl_out,
    // test
    input      [ 1:0]    gfx_en
);

parameter   H0 = 9'h75; // initial value of hdump after H blanking
parameter   BYPASS_VPROM=0;
localparam  RCNT=96;

reg         last_LVBL;
wire        gfx_we;
wire        lyr, done, chr_we, scr_we;
wire        vram_cs, cfg_cs;

wire        line;
wire [9:0]  line_addr;
wire [8:0]  chr_pxl, scr_pxl, line_din;

////////// Memory Mapped Registers
reg  [7:0]  mmr[0:RCNT-1];
wire [8:0]  hpos;
wire [7:0]  vpos = mmr[2];
wire        row_en     = mmr[1][1]; // row scroll enable
wire        ch_tx_enb  = mmr[1][3]; // char layer transparency (enable low)
wire        tile_msb   = mmr[3][0];
wire        obj_page   = mmr[3][3]; // select from which page to draw sprites
wire        layout     = mmr[3][4]; // 1 for wide layout
wire        narrow_en  = mmr[3][6] | row_en; // 1 for not displaying first and last columns
wire [3:0]  extra_mask = mmr[4][7:4];
wire [3:0]  extra_bits = mmr[4][3:0];
wire [1:0]  code9_sel, code10_sel, code11_sel, code12_sel;
wire        nmi_en     = mmr[7][0];
wire        irq_en     = mmr[7][1];
wire        firq_en    = mmr[7][2];
assign      flip       = mmr[7][3];
wire        pal_msb    = mmr[6][0];
wire        hflip_en   = mmr[6][1];
wire        vflip_en   = mmr[6][2];
wire        scrwin_en  = mmr[6][3];
wire [1:0]  pal_bank   = mmr[6][5:4];
wire        extra_en   = 1; // there must be a bit in the MMR that turns off all the extra_bits above
                            // because Contra doesn't need them but seems to write to them
wire        char_en    = 1;
// wire        char_en    =~mmr[7][4];     // undocumented by MAME

assign      { code12_sel, code11_sel, code10_sel, code9_sel } = mmr[5];
assign      gfx_we   = cpu_cen & ~cpu_rnw & vram_cs;
assign      cpu_nmin = !(vdump[5:3]!=3'b110 && nmi_en);
// Other configuration
reg  [8:0]  chr_dump_start, chr_render_start;
reg  [8:0]  chr_dump_end;
reg  [8:0]  scr_dump_start, scr_render_start;
reg  [8:0]  scr_dump_end;

// Scan
wire [10:0] scan_addr;
wire [10:0] ram_addr = { addr[11], addr[9:0] };
wire        attr_we  = gfx_we & ~addr[10] & ~addr[12];
wire        code_we  = gfx_we &  addr[10] & ~addr[12];
wire        obj_we   = gfx_we &  addr[12];
wire [ 7:0] code_dout, attr_dout, obj_dout, obj_pxl;
wire [ 7:0] code_scan, attr_scan, obj_scan;

reg  [ 7:0] vprom_addr;
wire [ 3:0] vprom_data, oprom_data;

wire [9:0]  line_dump;

wire        rom_obj_cs, rom_scr_cs;
wire [17:0] rom_scr_addr, rom_obj_addr;

assign      line_dump = { ~line, hdump };

// local SDRAM mux
reg  [ 1:0] data_sel;
reg         rom_scr_ok, rom_obj_ok;
reg  [15:0] rom_scr_data, rom_obj_data;
reg         ok_wait;
reg  [ 1:0] last_cs;

assign      cfg_cs  = (addr < RCNT) && cs;
assign      vram_cs = addr[13] && cs;
assign      hpos    = row_en ? {1'b0, mmr[ {2'b0, vrender[7:3]}+7'h20 ]} : { mmr[1][0], mmr[0] };

// Data bus mux. It'd be nice to latch this:
always @(*) begin
    dout = !addr[13] ?
        mmr[ addr[6:0] ]     // registers, row_scr cannot be read (?)
        : (addr[12] ? obj_dout :            // objects
          (addr[10] ? code_dout : attr_dout)); // tiles
end


always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs      <= 0;
        rom_addr    <= 18'd0;
        rom_obj_sel <= 0;
        data_sel    <= 2'b00;
        ok_wait     <= 0;
    end else begin
        last_cs <= { rom_obj_cs, rom_scr_cs };
        if( rom_obj_cs && !last_cs[1] ) rom_obj_ok<=0;
        if( rom_scr_cs && !last_cs[0] ) rom_scr_ok<=0;
        if( data_sel==2'b00 ) begin
            if( rom_scr_cs & gfx_en[0] ) begin
                rom_cs      <= 1;
                rom_addr    <= rom_scr_addr;
                rom_obj_sel <= 0;
                rom_scr_ok  <= 0;
                data_sel    <= 2'b01;
                ok_wait     <= 0;
            end else if( rom_obj_cs & gfx_en[1] ) begin
                rom_cs      <= 1;
                rom_addr    <= rom_obj_addr;
                rom_obj_sel <= 1;
                rom_obj_ok  <= 0;
                data_sel    <= 2'b10;
                ok_wait     <= 0;
            end
            else rom_cs <= 0;
        end else if( rom_ok & ok_wait) begin
            if( data_sel[0] ) begin
                rom_scr_data <= rom_data;
                rom_scr_ok   <= 1;
            end else if(!gfx_en[0]) begin
                rom_scr_data <= 16'd0;
                rom_scr_ok   <= 1;
            end
            if( data_sel[1] ) begin
                rom_obj_data <= rom_data;
                rom_obj_ok   <= 1;
            end else if( !gfx_en[1] ) begin
                rom_obj_data <= 16'd0;
                rom_obj_ok   <= 1;
            end
            data_sel <= 2'b00;
            rom_cs   <= 0;
        end else begin
            ok_wait <= 1;
        end
    end
end

always @(posedge clk24) begin
    if( rst ) begin
        { mmr[7], mmr[6], mmr[5], mmr[4] } <= 32'd0;
        { mmr[3], mmr[2], mmr[1], mmr[0] } <= 32'd0;
    end else if(cpu_cen) begin
        if(!cpu_rnw && cfg_cs)
            mmr[ addr[6:0] ] <= cpu_dout;
        // Apply layout
        if( layout ) begin
            // total 35*8 = 280 visible pixels: OCTAL!!
            chr_render_start <= 9'o000;
            scr_render_start <= 9'o050;
            if( flip ) begin
                chr_dump_start <= 9'o360;
                chr_dump_end   <= 9'o450;
                scr_dump_start <= 9'o000;
                scr_dump_end   <= 9'o360; // o400 = d256
            end else begin
                chr_dump_start <= 9'o000;
                chr_dump_end   <= 9'o050;
                scr_dump_start <= 9'o050;
                scr_dump_end   <= 9'o450; // o400 = d256
            end
        end else begin
            // total 31*8 = 248 visible pixels: OCTAL!!
            chr_render_start <= 9'o020;
            scr_render_start <= 9'o020;
            chr_dump_start <= 9'o020;
            chr_dump_end   <= 9'o410;
            scr_dump_start <= 9'o020;
            scr_dump_end   <= 9'o410;
        end
    end
end

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

// Local colour mixer
wire [ 7:0] scr_pxl_gated = scr_pxl[7:0];
wire [ 7:0] chr_pxl_gated = chr_pxl[7:0];
wire        chr_blank     = chr_pxl_gated[3:0] == 4'h0;
wire        obj_blank     = oprom_data[3:0] == 4'h0;
wire        tile_blank    = vprom_data[3:0] == 4'h0;
wire        chr_area      = hdump>=chr_dump_start && hdump<chr_dump_end;
wire        scr_area      = hdump>=scr_dump_start && hdump<scr_dump_end;
wire        border_narrow = (hdump<9'o30 || hdump>=9'o410) && narrow_en;
wire        border_wide   = hdump<9'o20 || hdump>=9'o420;
wire        blank_area    = vdump<9'o20 || (!layout && (border_narrow||border_wide));
reg         draw_scr;
wire [11:0] obj_scan_addr;
wire        scrwin        = scr_pxl[8];
wire        tile_prio     = scrwin_en && scrwin;

always @(*) begin
    draw_scr <= ( chr_area && !scr_area) ? 1'b0 : (
                (!chr_area &&  scr_area) ? 1'b1 : (
                 chr_blank ? 1'b1 : 1'b0 ));
end

always @(posedge clk) begin
    if( rst ) begin
        pxl_out    <= ~7'd0;
        vprom_addr <= 8'd0;
    end else begin
        vprom_addr <= draw_scr ? scr_pxl_gated : chr_pxl_gated;
        if(pxl_cen) begin
            if( blank_area )
                pxl_out <= 7'd0;
            else begin
                pxl_out[6:5] <= pal_bank;
                if( obj_blank || (layout && chr_area) || (tile_prio && !tile_blank))
                    pxl_out[4:0] <= { 1'b1, vprom_data }; // Tilemap
                else
                    pxl_out[4:0] <= { 1'b0, oprom_data }; // Object
            end
        end
    end
end

jtcontra_gfx_tilemap u_tilemap(
    .rst                ( rst               ),
    .clk                ( clk               ),
    // screen
    .LHBL               ( LHBL              ),
    .LVBL               ( LVBL              ),
    .hpos               ( hpos              ),
    .vpos               ( vpos              ),
    .vrender            ( vrender           ),
    .flip               ( flip              ),
    .scrwin_en          ( scrwin_en         ),
    .lyr                ( lyr               ),
    .line               ( line              ),
    .line_addr          ( line_addr         ),
    .done               ( done              ),
    .chr_we             ( chr_we            ),
    .scr_we             ( scr_we            ),
    .line_din           ( line_din          ),
    .scan_addr          ( scan_addr         ),
    // SDRAM
    .rom_cs             ( rom_scr_cs        ),
    .rom_addr           ( rom_scr_addr      ),
    .rom_ok             ( rom_scr_ok        ),
    .rom_data           ( rom_scr_data      ),
    .attr_scan          ( attr_scan         ),
    .code_scan          ( code_scan         ),
    // Configuration
    .chr_dump_start     ( chr_render_start  ),
    .scr_dump_start     ( scr_render_start  ),
    .pal_msb            ( pal_msb           ),
    .extra_mask         ( extra_mask        ),
    .extra_en           ( extra_en          ),
    .extra_bits         ( extra_bits        ),
    .tile_msb           ( tile_msb          ),
    .code9_sel          ( code9_sel         ),
    .code10_sel         ( code10_sel        ),
    .code11_sel         ( code11_sel        ),
    .code12_sel         ( code12_sel        )
);

jtcontra_gfx_obj u_obj(
    .rst                ( rst               ),
    .clk                ( clk               ),
    .pxl_cen            ( pxl_cen           ),
    .LHBL               ( LHBL              ),
    .LVBL               ( LVBL              ),
    .vrender            ( vrender           ),
    .flip               ( flip              ),
    .done               (                   ),
    .scan_addr          ( obj_scan_addr[9:0]),
    .hdump              ( hdump             ),
    .pxl                ( obj_pxl           ),
    .dump_start         ( scr_dump_start    ),
    // SDRAM
    .rom_cs             ( rom_obj_cs        ),
    .rom_addr           ( rom_obj_addr      ),
    .rom_ok             ( rom_obj_ok        ),
    .rom_data           ( rom_obj_data      ),
    .obj_scan           ( obj_scan          )
);

assign obj_scan_addr[11] = obj_page;
assign obj_scan_addr[10] = 1'b0;

// Colour PROMs

generate
    if( BYPASS_VPROM ) begin : bypass_vprom
        assign vprom_data = vprom_addr[3:0];
    end else begin : uses_vprom
        jtframe_prom #(.dw(4),.aw(8) ) u_vprom(
            .clk        ( clk                       ),
            .cen        ( 1'b1                      ),
            .data       ( prog_data                 ),
            .rd_addr    ( vprom_addr                ),
            .wr_addr    ( prog_addr[7:0]            ),
            .we         ( prom_we & prog_addr[8]    ),
            .q          ( vprom_data                )
        );
    end
endgenerate

jtframe_prom #(.dw(4),.aw(8) ) u_oprom(
    .clk        ( clk                       ),
    .cen        ( 1'b1                      ),
    .data       ( prog_data                 ),
    .rd_addr    ( obj_pxl                   ),
    .wr_addr    ( prog_addr[7:0]            ),
    .we         ( prom_we & ~prog_addr[8]   ),
    .q          ( oprom_data                )
);

// Line buffers could work with only AW=9 but it would
// make logic a bit more complex without any benefit in
// the FPGA, as the minimum size BRAM available is normally AW=10
jtframe_dual_ram #(.dw(9),.aw(10)) u_line_char(
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

jtframe_dual_ram #(.dw(9),.aw(10)) u_line_scr(
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
    .clk0   ( clk24         ),
    .clk1   ( clk           ),
    // Port 0
    .data0  ( cpu_dout      ),
    .addr0  ( addr[11:0]),
    .we0    ( obj_we        ),
    .q0     ( obj_dout      ),
    // Port 1
    .data1  (               ),
    .addr1  ( obj_scan_addr ),
    .we1    ( 1'b0          ),
    .q1     ( obj_scan      )
);

endmodule
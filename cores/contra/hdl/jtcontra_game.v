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

module jtcontra_game(
    input           rst,
    input           clk,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [4:0]  red,
    output   [4:0]  green,
    output   [4:0]  blue,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [15:0]  data_read,
    input           data_dst,
    input           data_rdy,
    input           sdram_ack,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input   [31:0]  dipsw,
    input           service,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd_left,
    output  signed [15:0] snd_right,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [ 3:0]  gfx_en
);

// Defines which game to render
`ifndef JTCONTRA_PCB
`define  JTCONTRA_PCB 0
`endif

localparam GAME=`JTCONTRA_PCB;
localparam CONTRA=0;

// SDRAM offsets.
localparam SND_OFFSET  = (GAME==CONTRA ? 22'h2_0000 : 22'h3_0000) >> 1;
localparam GFX1_OFFSET =  GAME==CONTRA ? (SND_OFFSET  + (22'h0_8000 >> 1)) : 22'h04_0000>>1;
localparam GFX2_OFFSET =  GAME==CONTRA ? (GFX1_OFFSET + (22'h8_0000 >> 1)) : 22'h14_0000>>1;
localparam PCM_OFFSET  =  22'h1C0000>>1;
localparam PROM_START  =  GAME==CONTRA ? 25'h128_000 : 25'h2C_0000;

wire        main_cs, snd_cs, snd_ok, main_ok, gfx1_ok, gfx2_ok;
wire        pcm_cs,  pcm_ok;
wire        snd_irq;
wire [15:0] gfx1_data, gfx2_data;
wire [ 7:0] pcm_data;
wire [16:0] pcm_addr;
wire [17:0] gfx1_addr, gfx2_addr;

wire [ 7:0] main_data, snd_data, snd_latch;
wire [14:0] snd_addr;
wire [17:0] main_addr;
wire        cen12, cen3, cen1p5, prom_we;
wire        gfx1_cs, gfx2_cs;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;
wire        LHBL, LVBL;

wire [15:0] cpu_addr;
wire        gfx1_romcs, gfx2_romcs, gfx1_cfg_cs, gfx2_cfg_cs, pal_cs;
wire        gfx1_vram_cs, gfx2_vram_cs;
wire        cpu_cen, cpu_rnw, cpu_irqn, cpu_nmin;
wire [ 7:0] gfx1_dout, gfx2_dout, pal_dout, cpu_dout;
wire [ 7:0] video_bank;
wire        prio_latch;

assign prog_rd    = 0;
assign dwnld_busy = downloading;
assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];

jtframe_cen24 u_cen(
    .clk        ( clk24         ),    // 24 MHz
    .cen12      ( cen12         ),
    .cen8       (               ),
    .cen6       (               ),
    .cen4       (               ),
    .cen3       ( cen3          ),
    .cen3q      (               ), // 1/4 advanced with respect to cen3
    .cen1p5     ( cen1p5        ),
    // 180 shifted signals
    .cen12b     (               ),
    .cen6b      (               ),
    .cen3b      (               ),
    .cen3qb     (               ),
    .cen1p5b    (               )
);

jtframe_dwnld #(.PROM_START(PROM_START))
u_dwnld(
    .clk            ( clk           ),
    .downloading    ( downloading   ),
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_dout     ( ioctl_dout    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ( prog_data     ),
    .prog_mask      ( prog_mask     ), // active low
    .prog_we        ( prog_we       ),
    .prom_we        ( prom_we       ),
    .sdram_ack      ( sdram_ack     ),
    .header         (               )
);

`ifdef GFX_ONLY
jtcontra_simloader u_simloader(
    .rst        ( rst           ),
    .clk        ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    // GFX
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),
    .gfx1_cs    ( gfx1_cs       ),
    .gfx2_cs    ( gfx2_cs       ),
    .pal_cs     ( pal_cs        ),
    .video_bank ( video_bank    ),
    .prio_latch ( prio_latch    )
);
`else
`ifndef NOMAIN
jtcontra_main #(.GAME(GAME)) u_main(
    .clk            ( clk24         ),        // 24 MHz
    .rst            ( rst           ),
    .cen12          ( cen12         ),
    .cpu_cen        ( cpu_cen       ),
    // communication with main CPU
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // GFX
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .gfx_irqn       ( cpu_irqn      ),
    .gfx_nmin       ( cpu_nmin      ),
    .gfx1_cs        ( gfx1_cs       ),
    .gfx2_cs        ( gfx2_cs       ),
    .pal_cs         ( pal_cs        ),

    .gfx1_dout      ( gfx1_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),

    .video_bank     ( video_bank    ),
    .prio_latch     ( prio_latch    ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       )
);
`else
// load a sound code for simulation
assign snd_latch = 8'h22;
reg pre_irq=0;
initial begin
    #100_000_000 pre_irq=1;
end

assign snd_irq = pre_irq;
`endif
`endif

`ifndef NOVIDEO
jtcontra_video #(.GAME(GAME)) u_video (
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk24          ( clk24         ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .LHBL_dly       ( LHBL_dly      ),
    .LVBL_dly       ( LVBL_dly      ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( dip_flip      ),
    .dip_pause      ( dip_pause     ),
    .start_button   ( &start_button ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[9:0]),
    .prog_data      ( prog_data[3:0]),
    // GFX - CPU interface
    .cpu_irqn       ( cpu_irqn      ),
    .cpu_nmin       ( cpu_nmin      ),
    .gfx1_cs        ( gfx1_cs       ),
    .gfx2_cs        ( gfx2_cs       ),
    .pal_cs         ( pal_cs        ),
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_cen        ( cpu_cen       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .gfx1_dout      ( gfx1_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),
    .video_bank     ( video_bank    ),
    .prio_latch     ( prio_latch    ),
    // SDRAM
    .gfx1_addr      ( gfx1_addr     ),
    .gfx1_data      ( gfx1_data     ),
    .gfx1_ok        ( gfx1_ok       ),
    .gfx1_romcs     ( gfx1_romcs    ),
    .gfx2_addr      ( gfx2_addr     ),
    .gfx2_data      ( gfx2_data     ),
    .gfx2_ok        ( gfx2_ok       ),
    .gfx2_romcs     ( gfx2_romcs    ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        )
);
`endif

`ifndef NOSOUND
jtcontra_sound u_sound(
    .clk        ( clk24         ), // 24 MHz
    .rst        ( rst           ),
    .cen12      ( cen12         ),
    .cen3       ( cen3          ),
    .cen1p5     ( cen1p5        ),
    // communication with main CPU
    .snd_irq    ( snd_irq       ),
    .snd_latch  ( snd_latch     ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    // ADPCM ROM
    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    // Sound output
    .snd_left   ( snd_left      ),
    .snd_right  ( snd_right     ),
    .sample     ( sample        ),
    .peak       ( game_led      )
);
`else
assign snd_cs   = 0;
assign pcm_cs   = 0;
assign snd_addr = 15'd0;
assign snd_left = 16'd0;
assign snd_right= 16'd0;
assign sample   = 0;
`endif

jtframe_rom #(
    .SLOT0_AW    ( 18              ), // GFX1
    .SLOT0_DW    ( 16              ),
    .SLOT0_OFFSET( GFX1_OFFSET     ),

    .SLOT1_AW    ( 18              ), // GFX2
    .SLOT1_DW    ( 16              ),
    .SLOT1_OFFSET( GFX2_OFFSET     ),

    .SLOT2_AW    ( 17              ), // ADPCM
    .SLOT2_DW    (  8              ),
    .SLOT2_OFFSET( PCM_OFFSET      ),

    .SLOT6_AW    ( 15              ), // Sound
    .SLOT6_DW    (  8              ),
    .SLOT6_OFFSET( SND_OFFSET      ),

    .SLOT7_AW    ( 18              ),
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              )  // Main
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( gfx1_romcs    ),
    .slot1_cs    ( gfx2_romcs    ),
    .slot2_cs    ( pcm_cs        ),
    .slot3_cs    ( 1'b0          ), // unused
    .slot4_cs    ( 1'b0          ), // unused
    .slot5_cs    ( 1'b0          ), // unused
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b0          ),

    .slot0_ok    ( gfx1_ok       ),
    .slot1_ok    ( gfx2_ok       ),
    .slot2_ok    ( pcm_ok        ),
    .slot3_ok    (               ),
    .slot4_ok    (               ),
    .slot5_ok    (               ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    (               ),

    .slot0_addr  ( gfx1_addr     ),
    .slot1_addr  ( gfx2_addr     ),
    .slot2_addr  ( pcm_addr      ),
    .slot3_addr  (               ),
    .slot4_addr  (               ),
    .slot5_addr  (               ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  (               ),

    .slot0_dout  ( gfx1_data     ),
    .slot1_dout  ( gfx2_data     ),
    .slot2_dout  ( pcm_data      ),
    .slot3_dout  (               ),
    .slot4_dout  (               ),
    .slot5_dout  (               ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  (               ),

    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule
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
    Date: 22-8-2021 */

module jtmx5k_sound(
    input           clk,        // 24 MHz
    input           rst,
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output  [16:0]  pcm_addr,
    output          pcm_cs,
    input   [ 7:0]  pcm_data,
    input           pcm_ok,

    // Sound output
    output signed [15:0] snd,
    output               sample,
    output               peak
);

wire        [ 7:0]  cpu_dout, ram_dout, fm_dout;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din;
wire                m1_n, mreq_n, rd_n, wr_n, int_n, iorq_n, rfsh_n;
reg                 ram_cs, latch_cs, fm_cs, irq_cs, div_cs, dac_cs, iock;
wire signed [15:0]  fm_left, fm_right;
wire                cen_fm, cen_fm2;
wire                cpu_cen, irq_ack;
reg                 mem_acc, mem_upper;
wire        [ 7:0]  div_dout;
reg                 pcm_amsb;

assign rom_addr  = A[14:0];
assign irq_ack   = !m1_n && !iorq_n;
assign pcm_cs    = 0;

jtframe_cen3p57 #(.CLK24(1)) u_cen(
    .clk        ( clk       ),
    .cen_3p57   ( cen_fm    ),
    .cen_1p78   ( cen_fm2   )
);

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15] && !rd_n;
    // Devices
    mem_upper = mem_acc && A[15];
    ram_cs    = mem_upper && A[14:12]==0; // 8xxx
    div_cs    = mem_upper && A[14:12]==1; // 9xxx
    latch_cs  = mem_upper && A[14:12]==2; // Axxx
    dac_cs    = mem_upper && A[14:12]==3; // Bxxx
    fm_cs     = mem_upper && A[14:12]==4; // Cxxx
    iock      = mem_upper && A[14:12]==7; // Fxxx
end

always @(*) begin
    case(1'b1)
        rom_cs:      cpu_din = rom_data;
        ram_cs:      cpu_din = ram_dout;
        div_cs:      cpu_din = div_dout;
        latch_cs:    cpu_din = snd_latch;
        fm_cs:       cpu_din = fm_dout;
        default:     cpu_din = 8'hff;
    endcase
end

always @(posedge clk) begin
    if(iock) pcm_amsb <= snd_latch[0];
end

jtframe_mixer #(.W0(16),.W1(16),.W2(10)) u_mixer(
    .rst    ( rst        ),
    .clk    ( clk        ),
    .cen    ( cen_fm     ),
    .ch0    ( fm_left    ),
    .ch1    ( fm_right   ),
    .ch2    ( 10'd0      ),
    .ch3    ( 16'd0      ),
    .gain0  ( 8'h08      ),
    .gain1  ( 8'h08      ),
    .gain2  ( 8'h10      ),
    .gain3  ( 8'd0       ),
    .mixed  ( snd        ),
    .peak   ( peak       )
);

jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( int_n       ),
    .set      ( 1'b0        ),    // active high
    .clr      ( irq_ack     ),    // active high
    .sigedge  ( snd_irq     ) // signal whose edge will trigger the FF
);

jtcontra_007452 u_div(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cs     ( div_cs & cpu_cen ),
    .wrn    ( wr_n      ),
    .addr   ( A[2:0]    ),
    .din    ( cpu_dout  ),
    .dout   ( div_dout  )
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( int_n     ),
    .nmi_n      ( 1'b1      ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( RnW       ), // write
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      (           ),
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_left   ),
    .xright     ( fm_right  ),
    // unsigned outputs for sigma delta converters, full resolution
    .dacleft    (           ),
    .dacright   (           )
);

endmodule

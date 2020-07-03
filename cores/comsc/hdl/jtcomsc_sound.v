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
    Date: 2-7-2019 */

// Note that I have kept jtcontra instead of jtcomsc
// so the module is selected in the qip but the jtcontra_game.v
// makes the same instantiation
module jtcontra_sound(
    input           clk,        // 24 MHz
    input           rst,
    input           cen12,
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,

    // Sound output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample    
);

wire        [ 7:0]  cpu_dout, ram_dout, fm_dout;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din;
wire                m1_n, mreq_n, rd_n, wr_n, int_n, iorq_n, rfsh_n, busrq_n;
reg                 ram_cs, latch_cs, fm_cs, irq_cs;
wire signed [15:0]  fm_snd;
wire        [ 9:0]  psg_snd;
wire                cen_fm, cen_fm2;
wire                cen_640, cen_320;
wire                cpu_cen, irq_ack;
reg                 fm_rstn;
reg                 mem_acc, mem_upper;
wire signed [ 9:0]  psg2x; // DC-removed version of psg01

assign rom_addr  = A[14:0];
assign irq_ack   = !m1_n && !iorq_n && cen_fm2;
assign snd_right = snd_left;

always @(*) begin
    mem_acc  = !mreq_n && !rfsh_n;
    rom_cs   = mem_acc && !A[15] && !rd_n;
    // Devices
    mem_upper= mem_acc &&  A[15];
    ram_cs   = mem_upper && A[14:12]==3'd0; // 8xxx
    fm_rstn  = mem_upper && A[14:12]==3'd1; // 9xxx
    latch_cs = mem_upper && A[14:12]==3'd5; // Dxxx
    fm_cs    = mem_upper && A[14:12]==3'd6; // Exxx
end

always @(*) begin
    case(1'b1)
        rom_cs:   cpu_din = rom_data;
        ram_cs:   cpu_din = ram_dout;
        latch_cs: cpu_din = snd_latch;
        fm_cs:    cpu_din = fm_dout;
        default:  cpu_din = 8'hff;
    endcase
end

jt49_dcrm2 #(.sw(10)) u_dcrm (
    .clk    (  clk      ),
    .cen    (  cen_fm   ),
    .rst    (  rst      ),
    .din    (  psg_snd  ),
    .dout   (  psg2x    )
);

jt12_mixer #(.w0(16),.w1(16),.w2(14),.w3(8),.wout(16)) u_mixer(
    .clk    ( clk          ),
    .cen    ( cen_fm       ),
    .ch0    ( fm_snd       ),
    .ch1    ( 16'd0        ),
    .ch2    ( {psg2x, 4'b0}),
    .ch3    ( 8'd0         ),
    .gain0  ( 8'h40        ),
    .gain1  ( 8'h00        ),
    .gain2  ( 8'h10        ),
    .gain3  ( 8'd0         ),
    .mixed  ( snd_left     )
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

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( ~rst      ), 
    .clk        ( clk       ),
    .cen        ( cen_fm2   ), // 1.5MHz, there is a clock divider in schematics
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( int_n     ),
    .nmi_n      ( 1'b1      ),
    .busrq_n    ( busrq_n   ),
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

jtframe_frac_cen u_fmcen( // 3.57MHz
    .clk        (  clk                ), // 24 MHz
    .n          ( 10'd105             ),
    .m          ( 10'd704             ),
    .cen        ( { cen_fm2, cen_fm } ),
    .cenb       (                     )
);

jtframe_frac_cen u_adpcm_cen( // 640Hz
    .clk        (  clk                ), // 24 MHz
    .n          ( 10'd2               ),
    .m          ( 10'd75              ),
    .cen        ( { cen_320, cen_640 }),
    .cenb       (                     )
);

jt03 u_fm(
    .rst        ( ~rst       ),
    // CPU interface
    .clk        ( clk        ),
    .cen        ( cen_fm     ),
    .din        ( cpu_dout   ),
    .addr       ( A[0]       ),
    .cs_n       ( ~fm_cs     ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( psg_snd    ),
    .fm_snd     ( fm_snd     ),
    .snd_sample ( sample     ),
    .dout       ( fm_dout    ),
    // unused outputs
    .irq_n      (            ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            )
);

`ifdef SIMULATION
always @(negedge snd_irq) $display("INFO: sound latch %X", snd_latch );
`endif

endmodule

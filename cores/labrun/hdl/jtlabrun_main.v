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
    Date: 3-10-2020 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtlabrun_main(
    input               clk,        // 24 MHz
    input               rst,
    input               cen12,
    output              cpu_cen,
    // communication with sound CPU
    output              snd_irq,
    output      [ 7:0]  snd_latch,
    // ROM
    output      [17:0]  rom_addr,
    output              rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // cabinet I/O
    input       [ 1:0]  start_button,
    input       [ 1:0]  coin_input,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,
    // GFX
    output      [15:0]  cpu_addr,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    input               gfx_irqn,
    output              gfx_cs,
    output              pal_cs,

    output     [7:0]    video_bank,
    output              prio_latch,

    input      [7:0]    gfx_dout,
    input      [7:0]    pal_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [3:0]    dipsw_c
);

localparam RAM_AW = 11;

wire [ 7:0] ram_dout, cpu_din;
wire [15:0] A;
wire        RnW, irq_n, irq_ack;
wire        irq_trigger;
wire        ram_cs;

assign irq_trigger = ~gfx_irqn & dip_pause;
assign cpu_addr    = A;
assign cpu_rnw     = RnW;
reg       bank_cs, in_cs, out_cs, pre_gfx, pre_cfg;
reg [3:0] bank;
reg [7:0] port_in;

always @(*) begin
    rom_cs  = (A[15] || A[15:14]==2'b01) && RnW;
    ram_cs  = A[15:11] == 5'b00011; // 18xx-1fxx
    pre_gfx = A[15:13] == 3'b001; // 2xxx 3xxx
    pre_cfg = A[15:8] == 8'd0;
    pal_cs  = A[15:11] == 5'b00010; // 10xx-17xx
    //in_cs       = A[15:10] == 6'b0000_00 && A[4] && RnW;  // 10 -1F
    //out_cs      = A[15:10] == 6'b0000_00 && A[4:3]==2'b11 && !RnW; // 18-1F
    ym0_cs  = 0;
    ym1_cs  = 0;
    bank_cs = 0;
    in_cs   = 0;
    prot_cs = 0;
    if( A[15:12]==4'd0 && A[11] ) begin
        case(A[10:8])
            3'd0: ym0_cs  = 1;
            3'd1: ym1_cs  = 1;
            3'd2: in_cs   = RnW;
            3'd3: sys_cs  = RnW;
            3'd4: bank_cs = !RnW;
            3'd5: prot_cs = 1;
            // 3'd6:  // watchdog
            default:;
        endcase
    end
end

always @(posedge clk) begin
    gfx_cs   <= pre_gfx | pre_cfg;
    gfx_addr <= { ~A[12] & pre_gfx, A[11:0] };
end

always @(*) begin   // doesn't boot up if latched
    case(1'b1)
        rom_cs:  cpu_din = rom_data;
        ram_cs:  cpu_din = ram_dout;
        pal_cs:  cpu_din = pal_dout;
        in_cs:   cpu_din = port_in;
        gfx_cs:  cpu_din = gfx_dout;
        default: cpu_din = 8'hff;
    endcase
end

always @(*) begin
    rom_addr = A[15] ? { 2'b00, A[14:0] } : { bank+4'b0100, A[12:0] }; // 13+4=17
end

wire [7:0] sys_dout ={ ~5'd0, service, coin_input };

always @(posedge clk) begin
    ym_dout <= ym0_cs ? ym0_dout : ym1_dout;
    cabiner <= A[0] ? {2'b11, joystick1[5:4], joystick1[2], joystick1[3], joystick1[0], joystick1[1]} :
                      {2'b11, joystick2[5:4], joystick2[2], joystick2[3], joystick2[0], joystick2[1]};
    port_in <= rom_cs ? rom_data : (
               ram_cs ? ram_dout : (
               gfx_cs ? gfx_dout : (
               in_cs  ? cabinet  : (
               (ym0_cs | ym1_cs) ? ym_dout  : (
               sys_cs            ? sys_dout :
               prot_cs           ? prot_dout : 8'hff )))));
end

always @(posedge clk) begin
    if( rst ) begin
        bank      <= 4'd0;
        snd_irq   <= 0;
        snd_latch <= 8'd0;
    end else if(cpu_cen) begin
        snd_irq   <= 0;
        if( bank_cs ) bank <= cpu_dout[3:0];
        if( out_cs  ) begin
            case( A[2:1] )
                // 2'b00: coin counters
                2'b01: snd_irq   <= 1;
                2'b10: snd_latch <= cpu_dout;
                // 2'b11 watchdog
            endcase
        end
    end
end

jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      (             ),    // active high
    .clr      ( irq_ack     ),    // active high
    .sigedge  ( irq_trigger )     // signal whose edge will trigger the FF
);

jtframe_sys6809 #(.RAM_AW(RAM_AW)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen12     ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .irq_ack    ( irq_ack   ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    .waitn      (           ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

jt03 u_fm0(
    .rst        ( rst        ),
    // CPU interface
    .clk        ( clk        ),
    .cen        ( cen_fm     ),
    .din        ( cpu_dout   ),
    .addr       ( A[0]       ),
    .cs_n       ( ~ym0_cs    ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( psg0_snd   ),
    .fm_snd     ( fm0_snd    ),
    .snd_sample ( sample     ),
    .dout       ( fm0_dout   ),
    .IOA_in     ( dipsw_a    ),
    .IOB_in     ( dipsw_b    ),
    // unused outputs
    .irq_n      (            ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            )
);

jt03 u_fm1(
    .rst        ( rst        ),
    // CPU interface
    .clk        ( clk        ),
    .cen        ( cen_fm     ),
    .din        ( cpu_dout   ),
    .addr       ( A[0]       ),
    .cs_n       ( ~ym1_cs    ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( psg1_snd   ),
    .fm_snd     ( fm1_snd    ),
    .snd_sample ( sample     ),
    .dout       ( fm1_dout   ),
    .IOA_in     ( 8'h00      ),
    .IOB_in     ( dipsw_c    ),
    // unused outputs
    .irq_n      (            ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            )
);

endmodule

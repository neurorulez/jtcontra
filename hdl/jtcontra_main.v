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
    Date: 2-12-2019 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtcontra_main(
    input               clk,        // 24 MHz
    input               rst,
    input               cen12,
    output              cpu_cen,
    // communication with main CPU
    output reg          snd_irq,
    output reg  [ 7:0]  snd_latch,
    // ROM
    output reg  [16:0]  rom_addr,
    output      reg     rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // cabinet I/O
    input       [ 1:0]  start_button,
    input       [ 1:0]  coin_input,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,
    // GFX
    output      [12:0]  cpu_addr,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    input               gfx_irqn,
    output reg          gfx1_vram_cs,
    output reg          gfx2_vram_cs,
    output reg          gfx1_cfg_cs,
    output reg          gfx2_cfg_cs,
    output reg          pal_cs,

    input   [7:0]       gfx1_dout,
    input   [7:0]       gfx2_dout,
    input   [7:0]       pal_dout,
    // DIP switches
    input               dip_pause,
    input   [7:0]       dipsw_a,
    input   [7:0]       dipsw_b,
    input   [3:0]       dipsw_c
);

wire [ 7:0] ram_dout;
wire [15:0] A;
reg  [ 7:0] cpu_din;
wire        RnW, irq_n, irq_ack;
reg         ram_cs, bank_cs, in_cs, out_cs;

reg [3:0] bank;
reg [7:0] port_in;

assign cpu_addr = A[12:0];
assign cpu_rnw  = RnW;

always @(*) begin
    rom_cs      = (A[15] || A[15:13]==3'b011) && RnW;
    bank_cs     = A[15:12] == 4'b0111 && !RnW;
    gfx1_vram_cs= A[15:13] == 3'b001;
    gfx2_vram_cs= A[15:13] == 3'b010;
    ram_cs      = A[15:12] == 4'b0001;
    pal_cs      = A[15:10] == 6'b0000_11;
    gfx1_cfg_cs = ~|A[15:3] & ~RnW; // 00 - 07
    gfx2_cfg_cs = A[15:10] == 6'b0000_00 && A[7:4] == 4'b0110 && !RnW; // 60 - 67
    in_cs       = A[15:10] == 6'b0000_00 && RnW;  // 00 -1F
    out_cs      = A[15:10] == 6'b0000_00 && A[4:3]==2'b11 && !RnW; // 18-1F
end

always @(*) begin   // consider latching
    case(1'b1)
        rom_cs:         cpu_din = rom_data;
        ram_cs:         cpu_din = ram_dout;
        pal_cs:         cpu_din = pal_dout;
        in_cs:          cpu_din = port_in;
        gfx1_vram_cs:   cpu_din = gfx1_dout;
        gfx2_vram_cs:   cpu_din = gfx2_dout;
        default:        cpu_din = 8'hff;
    endcase
end

always @(*) begin
    rom_addr = A[15] ? { 2'b00, A[14:0] } : { bank+4'b0100, A[12:0] }; // 13+4=17
end

always @(posedge clk) begin
    case( A[2:0] )
        3'b000: port_in <= {3'b111, start_button, service, coin_input };
        3'b001: port_in <= {2'b11, joystick1[5:4], joystick1[2], joystick1[3], joystick1[0], joystick1[1]};
        3'b010: port_in <= {2'b11, joystick2[5:4], joystick2[2], joystick2[3], joystick2[0], joystick2[1]};
        3'b100: port_in <= dipsw_a;
        3'b101: port_in <= dipsw_b;
        3'b110: port_in <= { 4'hf, dipsw_c };
    endcase
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

wire irq_trigger = ~gfx_irqn | dip_pause;

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

jtframe_sys6809 #(.RAM_AW(12)) u_cpu(
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

`ifdef SIMULATION
always @(negedge snd_irq) $display("INFO: sound latch %X", snd_latch );
`endif

endmodule

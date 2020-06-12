/*
 * Copyright (c) 2014 Greg Taylor <gtaylor@sonic.net>
 *
 * This file is part of OPL3 FPGA.
 *
 * OPL3 FPGA is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * OPL3 FPGA is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with OPL3 FPGA.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Original Java Code:
 * Copyright (c) 2008 Robson Cozendey <robson@cozendey.com>
 *
 * Original C++ Code:
 * Copyright (c) 2012  Steffen Ohrendorf <steffen.ohrendorf@gmx.de>
 *
 * Some code based on forum posts in:
 * http://forums.submarine.org.uk/phpBB/viewforum.php?f=9,
 * Copyright (c) 2010-2013 by carbon14 and opl3
 *
 * Converted to Verilog and reduced to the OPL2 subset:
 * Copyright (c) 2018 Magnus Karlsson <magnus@saanlima.com>
 *
 * Fixed and refactored:
 * Copyright (c) 2020 Josh Bassett
 */

`timescale 1ns / 1ps

`include "opl.vh"

module timer #(
  parameter TICK_TIMER_COUNT_VALUE // seconds
) (
  input wire clk,
  input wire [`REG_TIMER_WIDTH-1:0] init,
  input wire start,
  output wire overflow
);
  wire tick_pulse;
  wire start_pulse;
  reg [`CLOG2(TICK_TIMER_COUNT_VALUE)-1:0] tick_counter = 0;
  reg [`REG_TIMER_WIDTH-1:0] timer = 0;

  /*
   * Detect when start is initially set, use it to reset the timer value back
   * to the initial value. Also if start is not set clock will not run.
   */
  opl_edge_detector #(
    .EDGE_LEVEL(1),
    .CLK_DLY(1)
  ) start_timer_edge_detect (
    .clk(clk),
    .clk_en(1'b1),
    .in(start),
    .edge_detected(start_pulse)
  );

  always @(posedge clk)
    if (start)
      if (tick_pulse)
        tick_counter <= 0;
      else
        tick_counter <= tick_counter + 1;

  /*
   * Timer gets set to init upon overflow
   */
  always @(posedge clk)
    if (start_pulse)
      timer <= init;
    else if (tick_pulse)
      if (timer == 2**`REG_TIMER_WIDTH - 1)
        timer <= init;
      else
        timer <= timer + 1;

  assign tick_pulse = tick_counter == TICK_TIMER_COUNT_VALUE - 1;
  assign overflow = timer == 2**`REG_TIMER_WIDTH - 1;
endmodule

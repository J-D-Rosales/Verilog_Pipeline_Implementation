`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/17/2025 10:49:27 AM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module top(input  clk, reset, 
           output [31:0] WriteData, DataAdr, 
           output MemWrite);
  
  wire [31:0] PC, Instr, ReadData; 
  
  // instantiate processor and memories
  pipeline pipeline1(
    .clk(clk), 
    .reset(reset), 
    .PCF(PC), 
    .InstrF(Instr), 
    .MemWriteM(MemWrite), 
    .DataAdr(DataAdr), 
    .WriteDataM(WriteData), 
    .ReadDataM(ReadData)
  ); 

  imem imem(
    .a(PC), 
    .rd(Instr)
  ); 

  dmem dmem(
    .clk(clk), 
    .we(MemWrite), 
    .a(DataAdr), 
    .wd(WriteData), 
    .rd(ReadData)
  ); 
endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 08:44:52 PM
// Design Name: 
// Module Name: reg_decode_to_execute
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

// falta agregar lo de hazard unit
module reg_execute_to_memory_control(
    input             clk,
    input             reset,

    // --------- CONTROL desde etapa E ---------
    input             RegWriteE,
    input      [1:0]  ResultSrcE,
    input             MemWriteE,

    // --------- CONTROL hacia etapa M --------
    output reg        RegWriteM,
    output reg [1:0]  ResultSrcM,
    output reg        MemWriteM

);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // CONTROL
            RegWriteM  <= 1'b0;
            ResultSrcM <= 2'b0;
            MemWriteM  <= 1'b0;

        end else begin
            // CONTROL
            RegWriteM  <= RegWriteE;
            ResultSrcM <= ResultSrcE;
            MemWriteM  <= MemWriteE;

        end
    end

endmodule

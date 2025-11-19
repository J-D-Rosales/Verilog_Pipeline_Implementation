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
module reg_memory_to_writeback_control(
    input             clk,
    input             reset,

    // --------- CONTROL desde etapa M ---------
    input             RegWriteM,
    input      [1:0]  ResultSrcM,

    // --------- CONTROL hacia etapa W --------
    output reg        RegWriteW,
    output reg [1:0]  ResultSrcW
);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // CONTROL
            RegWriteW  <= 1'b0;
            ResultSrcW <= 2'b0;

        end else begin
            // CONTROL
            RegWriteW  <= RegWriteM;
            ResultSrcW <= ResultSrcM;

        end
    end

endmodule
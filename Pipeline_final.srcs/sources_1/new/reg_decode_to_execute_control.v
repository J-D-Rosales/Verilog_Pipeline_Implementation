`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 10:06:10 PM
// Design Name: 
// Module Name: reg_decode_to_execute_control
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


`timescale 1ns / 1ps

module reg_decode_to_execute_control (
    input             clk,
    input             reset,
    input             clr, // <--- NUEVO INPUT

    // --------- CONTROL (desde etapa D) ---------
    input             RegWriteD,
    input      [1:0]  ResultSrcD,
    input             MemWriteD,
    input             JumpD,
    input             BranchD,
    input      [2:0]  ALUControlD,
    input             ALUSrcD,

    // --------- CONTROL (hacia etapa E) --------
    output reg        RegWriteE,
    output reg [1:0]  ResultSrcE,
    output reg        MemWriteE,
    output reg        JumpE,
    output reg        BranchE,
    output reg [2:0]  ALUControlE,
    output reg        ALUSrcE
);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            RegWriteE   <= 0; ResultSrcE  <= 0; MemWriteE   <= 0;
            JumpE       <= 0; BranchE     <= 0; ALUControlE <= 0;
            ALUSrcE     <= 0;
        end 
        else begin
            // 🛑 LÓGICA DE FLUSH: Si hay flush, todo a 0 (NOP)
            if (clr) begin
                RegWriteE   <= 0; ResultSrcE  <= 0; MemWriteE   <= 0;
                JumpE       <= 0; BranchE     <= 0; ALUControlE <= 0;
                ALUSrcE     <= 0;
            end 
            else begin
                // Funcionamiento normal
                RegWriteE   <= RegWriteD; ResultSrcE  <= ResultSrcD; MemWriteE   <= MemWriteD;
                JumpE       <= JumpD;     BranchE     <= BranchD;    ALUControlE <= ALUControlD;
                ALUSrcE     <= ALUSrcD;
            end
        end
    end
endmodule
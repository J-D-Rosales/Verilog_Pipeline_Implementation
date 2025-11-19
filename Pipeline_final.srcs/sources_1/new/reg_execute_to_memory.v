`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 08:47:11 PM
// Design Name: 
// Module Name: reg_execute_to_memory
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

//////////////////////////////////////////////////////////////////////////////////
// Execute -> Memory pipeline register
//////////////////////////////////////////////////////////////////////////////////

module reg_execute_to_memory(
    input             clk,
    input             reset,

    // --------- DATOS desde etapa E ----------
    input      [31:0] ALUResultE,
    input      [31:0] WriteDataE,
    input      [4:0]  RdE,
    input      [31:0] PCPlus4E,

    // --------- DATOS hacia etapa M ----------
    output reg [31:0] ALUResultM,
    output reg [31:0] WriteDataM,
    output reg [4:0]  RdM,  
    output reg [31:0] PCPlus4M
);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // DATOS
            ALUResultM <= 32'b0;
            WriteDataM <= 32'b0;
            RdM        <= 5'b0;
            PCPlus4M   <= 32'b0;
        end else begin
            // DATOS
            ALUResultM <= ALUResultE;
            WriteDataM <= WriteDataE;
            RdM        <= RdE;
            PCPlus4M   <= PCPlus4E;
        end
    end

endmodule

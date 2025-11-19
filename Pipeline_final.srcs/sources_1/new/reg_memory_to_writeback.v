`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 09:45:04 PM
// Design Name: 
// Module Name: reg_memory_to_writeback
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
// Memory -> Writeback pipeline register
//////////////////////////////////////////////////////////////////////////////////

module reg_memory_to_writeback(
    input             clk,
    input             reset,

    // --------- DATOS desde etapa M ----------
    input      [31:0] ReadDataM,
    input      [31:0] ALUResultM,
    input      [31:0] PCPlus4M,
    input      [4:0]  RdM,

    // --------- DATOS hacia etapa W ----------
    output reg [31:0] ReadDataW,
    output reg [31:0] ALUResultW,
    output reg [31:0] PCPlus4W,
    output reg [4:0]  RdW
);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin

            // DATOS
            ReadDataW  <= 32'b0;
            ALUResultW <= 32'b0;
            PCPlus4W   <= 32'b0;
            RdW        <= 5'b0;
        end else begin
        
            // DATOS
            ReadDataW  <= ReadDataM;
            ALUResultW <= ALUResultM;
            PCPlus4W   <= PCPlus4M;
            RdW        <= RdM;
        end
    end

endmodule

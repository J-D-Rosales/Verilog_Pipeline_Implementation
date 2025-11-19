`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/17/2025 10:54:15 AM
// Design Name: 
// Module Name: controller
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

module controller(
                  input clk,
                  input reset,
                  input  [6:0] op,
                  input  [2:0] funct3,
                  input        funct7b5,
                  input        ZeroE,
                  input        FlushE,
                  // señales para el datapath
                  output RegWriteW,
                  output [1:0] ResultSrcW, 
                  output MemWriteM, 
                  output PCSrcE, ALUSrcE,  
                  output [1:0] ImmSrcD, 
                  output [2:0] ALUControlE,
                  
                  // para el hazard unit
                  output RegWriteM, 
                  output ResultSrcE_bit0
                  );
  //_____________________
  // fase de DEcode 
  //________________________
  
  wire RegWriteD; //c
  wire [1:0] ResultSrcD; //c
  wire MemWriteD; //c
  wire JumpD; //c
  wire BranchD;
  wire [2:0] ALUControlD; //c
  wire ALUSrcD; //c
  wire [1:0] ALUOp; 
  
  maindec md(
    .op(op), 
    
    .ResultSrc(ResultSrcD), 
    .MemWrite(MemWriteD), 
    .Branch(BranchD),
    .ALUSrcD(ALUSrcD), 
    .RegWrite(RegWriteD), 
    .Jump(JumpD), 
    .ImmSrc(ImmSrcD), //c
    .ALUOp(ALUOp)
  ); 
  

  aludec  ad(
    .opb5(op[5]), 
    .funct3(funct3), 
    .funct7b5(funct7b5),
     
    .ALUOp(ALUOp), 
    .ALUControl(ALUControlD)
  );
   
   
  //_______________________________________________________
  // stage de execute---------------- decode to execute
  //______________________________________________________ 
   
  wire RegWriteE; //c
  wire [1:0] ResultSrcE;
  wire JumpE;
  wire MemWriteE; //c
  wire BranchE;
  // ALUCOntrolE sale como output
  // ALUSrcE sale como output
  wire ResultSrcE_bit0;
  wire FlushE;
  assign ResultSrcE_bit0 = ResultSrcE[0];
  
  reg_decode_to_execute_control reg_decode_to_execute_control_instance(
    .clk(clk),
    .reset(reset),
    // --------- CONTROL (desde etapa D) ---------
    .RegWriteD(RegWriteD),
    .ResultSrcD(ResultSrcD),//[1:0]
    .MemWriteD(MemWriteD), // 
    .JumpD(JumpD),
    .BranchD(BranchD),
    .ALUControlD(ALUControlD), // [2:0]
    .ALUSrcD(ALUSrcD),
    .clr(FlushE),
        // --------- CONTROL (hacia etapa E) --------
    .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),
    .JumpE(JumpE),
    .BranchE(BranchE),
    .ALUControlE(ALUControlE),
    .ALUSrcE(ALUSrcE)
  );
  
    
  assign PCSrcE = (BranchE & ZeroE) | JumpE;
  //________________ fase de Memoery--- Executo to memeory
  //_______________________________________________________
  
  
  wire [1:0] ResultSrcM; //c
  wire RegWriteM;
  // MemWriteM es un output
  
  
  reg_execute_to_memory_control reg_execute_to_memory_control_instance(
    .clk(clk),
    .reset(reset),
    // --------- CONTROL desde etapa E ---------
    .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),

    // --------- CONTROL hacia etapa M --------
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .MemWriteM(MemWriteM)
  );
  
  
  //_______________________________________________-
  // fase de WriteBack memeory to writebacj
  //_______________________________________
  // REgWriteW y ResultSrcW son outputs
  
  reg_memory_to_writeback_control reg_memory_to_writeback_control_instance(
    .clk(clk),
    .reset(reset),

    // --------- CONTROL desde etapa M ---------
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),

    // --------- CONTROL hacia etapa W --------
    .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW)
  );
 
  
endmodule

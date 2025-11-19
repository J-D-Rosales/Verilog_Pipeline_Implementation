`timescale 1ns / 1ps

module pipeline(input  clk, reset,
                output [31:0] PCF,
                input  [31:0] InstrF,
                output MemWriteM,
                output [31:0] DataAdr, 
                output [31:0] WriteDataM,
                input  [31:0] ReadDataM);
  
  // Señales principales
  wire [31:0] ALUResultM, InstrD;
  wire ALUSrcE, RegWriteW, RegWriteM, ZeroE; 
  wire [1:0] ResultSrcW, ImmSrcD; 
  wire [2:0] ALUControlE; 
  wire PCSrcE; 
  
  // 🛑 CABLES DE RIESGO (HAZARD)
  // Asegúrate de que NO estén duplicados ni sean de 1 bit si son buses
  wire [4:0] Rs1E, Rs2E, RdM, RdW, RdE, Rs1D, Rs2D;
  wire [1:0] ForwardAE, ForwardBE;
  wire StallF, StallD, FlushE, FlushD;
  wire ResultSrcE_bit0;
  
  assign DataAdr = ALUResultM;
  
  // 1. INSTANCIA DEL CONTROLLER
  // Revisa que .FlushE esté conectado. Si faltaba esto, el flush no funcionaba.
  controller c(
    .clk(clk),
    .reset(reset), 
    
    // CONEXIÓN CRÍTICA QUE PODRÍA FALTAR:
    .FlushE(FlushE), 
    
    .op(InstrD[6:0]), .funct3(InstrD[14:12]), .funct7b5(InstrD[30]),
    .ZeroE(ZeroE),
    .ResultSrcW(ResultSrcW), .MemWriteM(MemWriteM),
    .PCSrcE(PCSrcE), .ALUSrcE(ALUSrcE), .RegWriteW(RegWriteW),
    .ImmSrcD(ImmSrcD), .ALUControlE(ALUControlE),
    
    .RegWriteM(RegWriteM),
    .ResultSrcE_bit0(ResultSrcE_bit0)
  ); 
  
  // 2. INSTANCIA DEL DATAPATH
  datapath dp(
    .clk(clk), .reset(reset), 
    .ResultSrcW(ResultSrcW), .PCSrcE(PCSrcE), .ALUSrcE(ALUSrcE),
    .RegWriteW(RegWriteW), .ImmSrcD(ImmSrcD), .ALUControlE(ALUControlE),
    .ReadDataM(ReadDataM), .InstrF(InstrF),
    .ZeroE(ZeroE), .PCF(PCF), .InstrD(InstrD),
    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM),

    // Hazard Connections
    .StallF(StallF), .StallD(StallD), .FlushE(FlushE), .FlushD(FlushD),
    .Rs1D(Rs1D), .Rs2D(Rs2D), 
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdM(RdM), .RdW(RdW), .RdE(RdE),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE)
  );
  
  // 3. INSTANCIA DE HAZARD UNIT
  hazard_unit hu (
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdM(RdM), .RdW(RdW),
    .Rs1D(Rs1D), .Rs2D(Rs2D), .RdE(RdE),
    .PCSrcE(PCSrcE),
    .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
    .ResultSrcE_bit0(ResultSrcE_bit0),
    
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .StallF(StallF), .StallD(StallD), 
    .FlushE(FlushE), .FlushD(FlushD)
  );
    
endmodule
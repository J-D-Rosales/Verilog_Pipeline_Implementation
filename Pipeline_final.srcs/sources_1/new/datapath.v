`timescale 1ns / 1ps

module datapath(input  clk, reset,
//________________ inputs del controller
                input  [1:0]  ResultSrcW, 
                input  PCSrcE, ALUSrcE,
                input  RegWriteW,
                input  [1:0]  ImmSrcD, 
                input  [2:0]  ALUControlE,
//inputs de la memoria
                input  [31:0] ReadDataM,
                input  [31:0] InstrF,
// outputs
                output ZeroE,
                output [31:0] PCF,
                output [31:0] InstrD,     
                output [31:0] ALUResultM,
                output [31:0] WriteDataM,
                
                // outputs para el hazard unit
                output [4:0] Rs1E,
                output [4:0] Rs2E,
                output [4:0] RdM,
                output [4:0] RdW,
                output [4:0] Rs1D,
                output [4:0] Rs2D,
                output [4:0] RdE,
                // inputs del hazard unit
                input [1:0] ForwardAE, ForwardBE,
                input StallF,StallD,FlushE,FlushD
                );
  
 localparam WIDTH = 32;

//_________________ fase de fetch
 wire [31:0] PCNextF, PCPlus4F; 
 wire [31:0] PCD, PCPlus4D;  // ✅ InstrD ya está como output, no redeclares
 
  // next PC logic
  flopr #(WIDTH) pcreg(
    .en(~StallF),
    .clk(clk), 
    .reset(reset), 
    .d(PCNextF), 
    .q(PCF)
  ); 

  adder pcadd4(
    .a(PCF), 
    .b(32'd4),
    .y(PCPlus4F)
  ); 
  
  reg_fetch_to_decode reg_fetch_to_decode_instance(
   .clk(clk),
   .reset(reset),
   .en(~StallD),
   .clr(FlushD),
    .InstrF(InstrF),
    .PCF(PCF),
    .PCPlus4F(PCPlus4F),
    .InstrD(InstrD),  // ✅ Conecta con el output del módulo
    .PCD(PCD),
    .PCPlus4D(PCPlus4D)
  );

//_____________________________________
// fase del decode
//_________________________________________
 
 wire [31:0] ImmExtD; 
 wire [31:0] RD1D, RD2D;  
 
// variables para execute
 wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
 wire [4:0] RdE;  // ✅ 5 bits para registro destino

// del hazard
 wire [4:0] Rs1D,Rs2D,Rs1E,Rs2E;

 assign Rs1D = InstrD[19:15];
 assign Rs2D = InstrD[24:20];
// Register file
  regfile rf(
    .clk(clk),  // ✅ Clock normal, sin invertir
    .we3(RegWriteW), 
    .a1(InstrD[19:15]), 
    .a2(InstrD[24:20]), 
    .a3(RdW),  // ✅ RdW es [4:0]
    .wd3(ResultW), 
    .rd1(RD1D), 
    .rd2(RD2D)
  ); 
 
  extend ext(
    .instr(InstrD[31:7]), 
    .immsrc(ImmSrcD), 
    .immext(ImmExtD)
  ); 

  reg_decode_to_execute reg_decode_to_execute_instance(
    .clk(clk),
    .reset(reset),
    .clr(FlushE),
    .RD1D(RD1D),
    .RD2D(RD2D),
    .PCD(PCD),
    .RdD(InstrD[11:7]),  // ✅ 5 bits
    .ImmExtD(ImmExtD),
    .PCPlus4D(PCPlus4D),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .RdE(RdE),  // ✅ 5 bits
    .ImmExtE(ImmExtE),
    .PCPlus4E(PCPlus4E),
    
    // para el hazard unit
    .Rs1D(Rs1D),
    .Rs2D(Rs2D),
    .Rs1E(Rs1E),
    .Rs2E(Rs2E)
);

//_____________________________________________
// fase de Execution
//_____________________________

 wire [31:0] SrcAE, SrcBE, WriteDataE, ALUResultE; 
 wire [31:0] PCTargetE;


// wires que salen de los registros
 wire [31:0] PCPlus4M;
 wire [4:0] RdM;  // ✅ 5 bits
  
 // muxes de 3 para la salida de SrA y SrcB 
// 1. Mux para el Operando A (SrcAE)
  // Selecciona entre: Dato del registro, Dato de Writeback, Dato de Memory
  mux3 #(WIDTH) SrcAmux(
    .d0(RD1E),        // 00: Viene del registro (valor original)
    .d1(ResultW),     // 01: Forwarding desde Writeback
    .d2(ALUResultM),  // 10: Forwarding desde Memory
    .s(ForwardAE),    // Selector desde Hazard Unit
    .y(SrcAE)         // Salida hacia la ALU
  );

  // 2. Mux para el Operando B (Forwarding antes del Mux de Inmediato)
  // Este dato también es el que se usa para 'WriteDataE' (lo que se guarda en memoria en Store)
  mux3 #(WIDTH) SrcBmux(
    .d0(RD2E),        // 00: Viene del registro (valor original)
    .d1(ResultW),     // 01: Forwarding desde Writeback
    .d2(ALUResultM),  // 10: Forwarding desde Memory
    .s(ForwardBE),    // Selector desde Hazard Unit
    .y(WriteDataE)    // Salida: Dato 'fresco' para Store o para operar
  );
  
  mux2 #(WIDTH) AluSrcE_mux(
    .d0(WriteDataE), 
    .d1(ImmExtE), 
    .s(ALUSrcE), 
    .y(SrcBE)
  ); 
 
  alu alu(
    .a(SrcAE), 
    .b(SrcBE), 
    .alucontrol(ALUControlE), 
    .result(ALUResultE), 
    .zero(ZeroE)
  ); 
 
  adder pcaddbranch(
    .a(PCE), 
    .b(ImmExtE), 
    .y(PCTargetE)
  ); 

  reg_execute_to_memory reg_execute_to_memory_instance(
    .clk(clk),
    .reset(reset),
    .ALUResultE(ALUResultE),
    .WriteDataE(WriteDataE),
    .RdE(RdE),  // ✅ 5 bits
    .PCPlus4E(PCPlus4E),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .RdM(RdM),  // ✅ 5 bits
    .PCPlus4M(PCPlus4M)
  );

//_____________________
// fase de Write Back
//_______________________________________

 wire [31:0] ReadDataW, PCPlus4W, ALUResultW;
 wire [4:0] RdW;  // ✅ 5 bits
 wire [31:0] ResultW;
    
  reg_memory_to_writeback reg_memory_to_writeback_instance(
    .clk(clk),
    .reset(reset),
    .ReadDataM(ReadDataM),
    .ALUResultM(ALUResultM),
    .PCPlus4M(PCPlus4M),
    .RdM(RdM),  // ✅ 5 bits
    .ReadDataW(ReadDataW),
    .ALUResultW(ALUResultW),
    .PCPlus4W(PCPlus4W),
    .RdW(RdW)  // ✅ 5 bits
  );
    
  mux3 #(WIDTH) resultmux(
    .d0(ALUResultW), 
    .d1(ReadDataW), 
    .d2(PCPlus4W), 
    .s(ResultSrcW), 
    .y(ResultW)
  ); 

  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4F), 
    .d1(PCTargetE), 
    .s(PCSrcE), 
    .y(PCNextF)
  ); 

endmodule
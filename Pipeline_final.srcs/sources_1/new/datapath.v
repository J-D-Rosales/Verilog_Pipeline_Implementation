`timescale 1ns / 1ps

module datapath(input  clk, reset,
//________________ inputs del controller
                input  [1:0]  ResultSrcW, 
                input  PCSrcE, ALUSrcE,
                input  RegWriteW,
                input  [1:0]  ImmSrcD, 
                input  [2:0]  ALUControlE,
                input FPRegWriteM, // NUEVO
                input FPRegWriteW,   // NUEVO
                input [2:0] FPUControlE, // NUEVO
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
                output [4:0] Rs1E, Rs2E, RdM, RdW, Rs1D, Rs2D, RdE,
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
 wire [31:0] FRD1D, FRD2D;     // NUEVO: Datos de regfile FP
// variables para execute
 wire [31:0] RD1E, RD2E, FRD1E, FRD2E, PCE, ImmExtE, PCPlus4E;

/* Ya esta en la declaracion del modulo: 
 wire [4:0] RdE;  // ✅ 5 bits para registro destino

//del hazard
 wire [4:0] Rs1D,Rs2D,Rs1E,Rs2E;*/

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

  // NUEVO: Register file FLOTANTE
fp_regfile fprf(
    .clk(clk),
    .we3(FPRegWriteW),
    .a1(InstrD[19:15]),
    .a2(InstrD[24:20]),
    .a3(RdW),
    .wd3(FPResultW),
    .rd1(FRD1D),
    .rd2(FRD2D)
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
    .FRD1D(FRD1D), .FRD2D(FRD2D),  // NUEVO
    .PCD(PCD),
    .RdD(InstrD[11:7]),  // ✅ 5 bits
    .ImmExtD(ImmExtD),
    .PCPlus4D(PCPlus4D),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .FRD1E(FRD1E), .FRD2E(FRD2E),  // NUEVO
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
 wire [31:0] FPSrcAE, FPSrcBE, FPResultE;  // NUEVO
 wire [31:0] PCTargetE;
wire [31:0] FPResultM, FPResultW;         // NUEVO


// wires que salen de los registros
 wire [31:0] PCPlus4M;
  
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

  // ========== FPU ==========
  wire [31:0] ForwardDataM = FPRegWriteM ? FPResultM : ALUResultM;
wire [31:0] ForwardDataW = FPRegWriteW ? FPResultW : ResultW;

// Forwarding FP separado
mux3 #(WIDTH) FPSrcAmux(
    .d0(FRD1E),
    .d1(FPResultW),
    .d2(FPResultM),
    .s(ForwardAE_FP),  // ✅ Señal independiente
    .y(FPSrcAE)
);

mux3 #(WIDTH) FPSrcBmux(
    .d0(FRD2E),
    .d1(FPResultW),
    .d2(FPResultM),
    .s(ForwardBE_FP),  // ✅ Señal independiente
    .y(FPSrcBE)
);

// NUEVO: Instancia de la FPU
fpu_top fpu(
    .op_a(FPSrcAE),
    .op_b(FPSrcBE),
    .op_code(FPUControlE),
    .round_mode(1'b0),  // RNE
    .result(FPResultE),
    .flags()  // Flags no usados por ahora
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
    .FPResultE(FPResultE),      // NUEVO
    .WriteDataE(WriteDataE),
    .RdE(RdE),  // ✅ 5 bits
    .PCPlus4E(PCPlus4E),
    .ALUResultM(ALUResultM),
    .FPResultM(FPResultM),      // NUEVO
    .WriteDataM(WriteDataM),
    .RdM(RdM),  // ✅ 5 bits
    .PCPlus4M(PCPlus4M)
  );

//_____________________
// fase de Write Back
//_______________________________________

 wire [31:0] ReadDataW, PCPlus4W, ALUResultW;
 wire [31:0] ResultW;
    
  reg_memory_to_writeback reg_memory_to_writeback_instance(
    .clk(clk),
    .reset(reset),
    .ReadDataM(ReadDataM),
    .ALUResultM(ALUResultM),
    .FPResultM(FPResultM),      // NUEVO
    .PCPlus4M(PCPlus4M),
    .RdM(RdM),  // ✅ 5 bits
    .ReadDataW(ReadDataW),
    .ALUResultW(ALUResultW),
    .FPResultW(FPResultW),      // NUEVO
    .PCPlus4W(PCPlus4W),
    .RdW(RdW)  // ✅ 5 bits
  );

  // Mux para resultado ENTERO

  mux3 #(WIDTH) resultmux(
    .d0(ALUResultW), 
    .d1(ReadDataW), 
    .d2(PCPlus4W), 
    .s(ResultSrcW), 
    .y(ResultW)
  ); 
/* NOTA: FPResultW se escribe directamente en fprf 
ya que utiliza un registro independiente de la ALU entera */
  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4F), 
    .d1(PCTargetE), 
    .s(PCSrcE), 
    .y(PCNextF)
  ); 

endmodule
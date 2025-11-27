
module adder(input  [31:0] a, b,
             output [31:0] y);
  
  assign y = a + b; 
endmodule

module alu(input  [31:0] a, b,
           input  [2:0]  alucontrol,
           output [31:0] result,
           output zero);
  
  wire [31:0] condinvb, sum; 
  wire        v; // overflow
  wire        isAddSub; 

  reg [31:0] result_reg; 
  assign result = result_reg;

  assign condinvb = alucontrol[0] ? ~b : b; 
  assign sum = a + condinvb + alucontrol[0]; 
  assign isAddSub = ~alucontrol[2] & ~alucontrol[1] |
                    ~alucontrol[1] & alucontrol[0]; 

  // 🛑 ESTA LÍNEA FALTABA O ESTABA INCOMPLETA:
  assign v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub;

  always @* case (alucontrol)
      3'b000:  result_reg = sum;          // add
      3'b001:  result_reg = sum;          // subtract
      3'b010:  result_reg = a & b;        // and
      3'b011:  result_reg = a | b;        // or
      3'b100:  result_reg = a ^ b;        // xor
      3'b101:  result_reg = {31'b0, sum[31] ^ v}; // slt (Set Less Than)
      3'b110:  result_reg = a << b[4:0];  // sll
      3'b111:  result_reg = a >> b[4:0];  // srl
      default: result_reg = 32'bx;
    endcase

  assign zero = (result == 32'b0);
endmodule


module aludec(input  opb5,
              input  [2:0] funct3,
              input  funct7b5, 
              input  [1:0] ALUOp,
              output [2:0] ALUControl);
  
  wire  RtypeSub; 
  reg [2:0] ALUControl_reg; 

  assign RtypeSub = funct7b5 & opb5;  // TRUE for R-type subtract instruction
  assign ALUControl = ALUControl_reg;

  always @* case(ALUOp)
      2'b00:                ALUControl_reg = 3'b000; // addition
      2'b01:                ALUControl_reg = 3'b001; // subtraction
      default: case(funct3) // R-type or I-type ALU
                 3'b000:  if (RtypeSub) 
                            ALUControl_reg = 3'b001; // sub
                          else          
                            ALUControl_reg = 3'b000; // add, addi
                 3'b010:    ALUControl_reg = 3'b101; // slt, slti
                 3'b110:    ALUControl_reg = 3'b011; // or, ori
                 3'b111:    ALUControl_reg = 3'b010; // and, andi
                 default:   ALUControl_reg = 3'bxxx; // ???
               endcase
    endcase
endmodule

module controller(
                  input clk,
                  input reset,
                  input  [6:0] op,
                  input  [2:0] funct3,
                  input [6:0] funct7,
                  input        ZeroE,
                  input        FlushE,
                  // señales para el datapath
                  output RegWriteW,
                  output [1:0] ResultSrcW, 
                  output MemWriteM, 
                  output PCSrcE, ALUSrcE,  
                  output [1:0] ImmSrcD, 
                  output [2:0] ALUControlE,
                  
                  // NUEVAS señales FP
                  output FPRegWriteW,
                  output [2:0] FPUControlE,

                  // para el hazard unit
                  output RegWriteM, 
                  output ResultSrcE_bit0,
                  // NUEVO: semejante al register file anterior pero ahora para FP
                  output FPRegWriteM  
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
   // NUEVAS señales FP
  wire FPOpD;
  wire FPRegWriteD;
  wire [2:0] FPUControlD;

  maindec md(
    .op(op), 
    .ResultSrc(ResultSrcD), 
    .MemWrite(MemWriteD), 
    .Branch(BranchD),
    .ALUSrcD(ALUSrcD), 
    .RegWrite(RegWriteD), 
    .Jump(JumpD), 
    .ImmSrc(ImmSrcD), //c
    .ALUOp(ALUOp),
    // Señales FP
    .FPOp(FPOpD),
    .FPRegWrite(FPRegWriteD)
  ); 
  

  aludec  ad(
    .opb5(op[5]), 
    .funct3(funct3), 
    .funct7b5(funct7[5]),
     
    .ALUOp(ALUOp), 
    .ALUControl(ALUControlD)
  );
   
  // FPU decoder
  fpu_dec fpudec(
    .funct7(funct7),  // Reconstruir funct7
    .funct3(funct3),
    .opcode(op),
    .FPUControl(FPUControlD)
);
  //_______________________________________________________
  // stage de execute---------------- decode to execute
  //______________________________________________________ 
   
  wire RegWriteE; //c
  wire [1:0] ResultSrcE;
  wire JumpE;
  wire MemWriteE; //c
  wire BranchE;
  wire FPRegWriteE;

  // ALUCOntrolE sale como output
  // ALUSrcE sale como output
  assign ResultSrcE_bit0 = ResultSrcE[0];
  
  reg_decode_to_execute_control reg_decode_to_execute_control_instance(
            .clk(clk),
        .reset(reset),
        .clr(FlushE),
        
        // Control desde Decode
        .RegWriteD(RegWriteD),
        .ResultSrcD(ResultSrcD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ALUControlD(ALUControlD),
        .ALUSrcD(ALUSrcD),
        .FPRegWriteD(FPRegWriteD),      // NUEVO
        .FPUControlD(FPUControlD),      // NUEVO
        
        // Control hacia Execute
        .RegWriteE(RegWriteE),
        .ResultSrcE(ResultSrcE),
        .MemWriteE(MemWriteE),
        .JumpE(JumpE),
        .BranchE(BranchE),
        .ALUControlE(ALUControlE),
        .ALUSrcE(ALUSrcE),
        .FPRegWriteE(FPRegWriteE),      // NUEVO
        .FPUControlE(FPUControlE)       // NUEVO
  );

    
  assign PCSrcE = (BranchE & ZeroE) | JumpE;
  //________________ fase de Memoery--- Executo to memeory
  //_______________________________________________________
  
  
  wire [1:0] ResultSrcM; //c
  // MemWriteM es un output
  
  
  reg_execute_to_memory_control reg_execute_to_memory_control_instance(
        .clk(clk),
        .reset(reset),
        
        // Control desde Execute
        .RegWriteE(RegWriteE),
        .ResultSrcE(ResultSrcE),
        .MemWriteE(MemWriteE),
        .FPRegWriteE(FPRegWriteE),      // NUEVO
        
        // Control hacia Memory
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .MemWriteM(MemWriteM),
        .FPRegWriteM(FPRegWriteM)       // NUEVO
  );
  
  
  //_______________________________________________-
  // fase de WriteBack memeory to writebacj
  //_______________________________________
  // REgWriteW y ResultSrcW son outputs
  
  reg_memory_to_writeback_control reg_memory_to_writeback_control_instance(
        .clk(clk),
        .reset(reset),
        
        // Control desde Memory
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .FPRegWriteM(FPRegWriteM),      // NUEVO
        
        // Control hacia Writeback
        .RegWriteW(RegWriteW),
        .ResultSrcW(ResultSrcW),
        .FPRegWriteW(FPRegWriteW)       // NUEVO
  );
 
  
endmodule


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
                input [1:0] ForwardAE_FP, ForwardBE_FP,
                input StallF,StallD,FlushE,FlushD
                );
  
 localparam WIDTH = 32;

//_________________ fase de fetch
 wire [31:0] PCNextF, PCPlus4F; 
 wire [31:0] PCD, PCPlus4D;  
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

// === File: dmem.v ===
module dmem(input  clk, we,
            input  [31:0] a, wd,
            output [31:0] rd);
  
  reg [31:0] RAM[63:0]; 

  assign rd = RAM[a[31:2]]; // word aligned

  always @(posedge clk) begin 
    if (we) RAM[a[31:2]] <= wd; 
  end
endmodule

// === File: extend.v ===
module extend(input  [31:7] instr,
              input  [1:0]  immsrc,
              output [31:0] immext);
  
  reg [31:0] immext_reg; 
  assign immext = immext_reg;

  always @* case(immsrc) 
               // I-type 
      3'b00:   immext_reg = {{20{instr[31]}}, instr[31:20]}; 
               // S-type (stores)
      3'b01:   immext_reg = {{20{instr[31]}}, instr[31:25], instr[11:7]}; 
               // B-type (branches)
      3'b10:   immext_reg = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; 
               // J-type (jal)
      3'b11:   immext_reg = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; 

      default: immext_reg = 32'bx; // undefined
    endcase             
endmodule
 localparam WIDTH = 32;

// === File: flopr.v ===
module flopr (input  clk, reset,en,
               input  [WIDTH-1:0] d, 
               output reg [WIDTH-1:0] q);

  parameter WIDTH = 8;


    always @(posedge clk or posedge reset)
            if (reset) q <= 0;
            else if (en) q <= d;
  
endmodule


// Decodificador de operaciones FP
// Convierte funct7 y funct3 en op_code para la FPU
module fpu_dec(
    input [6:0] funct7,
    input [2:0] funct3,
    input [6:0] opcode,
    output reg [2:0] FPUControl  // op_code para fpu_top
);

    always @(*) begin
        FPUControl = 3'b000;  // Default: ADD
        
        // Solo decodifica si es instrucción FP
        if (opcode == 7'b1010011) begin
            case(funct7)
                7'b0000000: FPUControl = 3'b000;  // FADD.S
                7'b0000100: FPUControl = 3'b001;  // FSUB.S
                7'b0001000: FPUControl = 3'b010;  // FMUL.S
                7'b0001100: FPUControl = 3'b011;  // FDIV.S
                
                // FMIN/FMAX se diferencian por funct3
    
                7'b0010100: begin
                    if (funct3 == 3'b000)
                        FPUControl = 3'b100;      // FMIN.S
                    else if (funct3 == 3'b001)
                        FPUControl = 3'b101;      // FMAX.S
                    else
                        FPUControl = 3'b000;
                end
                
                default: FPUControl = 3'b000;
            endcase
        end
    end

endmodule

module hazard_unit(
    input [4:0] Rs1E, Rs2E, Rs1D, Rs2D, RdM, RdW, RdE,
    input RegWriteM, RegWriteW,
    input FPRegWriteM, FPRegWriteW,
    input ResultSrcE_bit0, PCSrcE,
    
    output reg [1:0] ForwardAE, ForwardBE,
    output reg [1:0] ForwardAE_FP, ForwardBE_FP,  // NUEVO
    output wire StallF, StallD, FlushE, FlushD
);

// Forwarding ENTERO 
always @(*) begin
    ForwardAE = 2'b00;
    ForwardBE = 2'b00;
    
    // Forward desde Memory (solo si es write entero)
    if ((Rs1E == RdM) && RegWriteM && !FPRegWriteM && (Rs1E != 0))
        ForwardAE = 2'b10;
    else if ((Rs1E == RdW) && RegWriteW && !FPRegWriteW && (Rs1E != 0))
        ForwardAE = 2'b01;
    
    if ((Rs2E == RdM) && RegWriteM && !FPRegWriteM && (Rs2E != 0))
        ForwardBE = 2'b10;
    else if ((Rs2E == RdW) && RegWriteW && !FPRegWriteW && (Rs2E != 0))
        ForwardBE = 2'b01;
end

// Forwarding FP
always @(*) begin
    ForwardAE_FP = 2'b00;
    ForwardBE_FP = 2'b00;
    
    if ((Rs1E == RdM) && FPRegWriteM && (Rs1E != 0))
        ForwardAE_FP = 2'b10;
    else if ((Rs1E == RdW) && FPRegWriteW && (Rs1E != 0))
        ForwardAE_FP = 2'b01;
    
    if ((Rs2E == RdM) && FPRegWriteM && (Rs2E != 0))
        ForwardBE_FP = 2'b10;
    else if ((Rs2E == RdW) && FPRegWriteW && (Rs2E != 0))
        ForwardBE_FP = 2'b01;
end

wire lwStall = (ResultSrcE_bit0 === 1'b1) ? ((Rs1D == RdE) | (Rs2D == RdE)) : 1'b0;
assign StallF = lwStall;
assign StallD = lwStall;
assign FlushE = lwStall | (PCSrcE === 1'b1);
assign FlushD = (PCSrcE === 1'b1);

endmodule

// === File: imem.v ===
module imem(input  [31:0] a,
            output [31:0] rd);
  
  reg [31:0] RAM[63:0]; 

  initial begin
      $readmemh("riscvtest.txt",RAM); 
  end

  assign rd = RAM[a[31:2]]; // word aligned
endmodule
  
module maindec(
    input  [6:0] op,
    output [1:0] ResultSrc,
    output MemWrite,
    output Branch, ALUSrcD,
    output RegWrite, Jump,
    output [1:0] ImmSrc, 
    output [1:0] ALUOp, 
    output reg FPOp,
    output reg FPRegWrite
);
  
    reg [10:0] controls; 
    assign {RegWrite, ImmSrc, ALUSrcD, MemWrite,
            ResultSrc, Branch, ALUOp, Jump} = controls; 

    always @(*) begin
        // DEFAULTS para evitar 'X'
        FPOp = 1'b0;
        FPRegWrite = 1'b0;
        
        case(op)
            7'b0000011: controls = 11'b1_00_1_0_01_0_00_0; // lw
            7'b0100011: controls = 11'b0_01_1_1_00_0_00_0; // sw
            7'b0110011: controls = 11'b1_xx_0_0_00_0_10_0; // R-type
            7'b1100011: controls = 11'b0_10_0_0_00_1_01_0; // beq
            7'b0010011: controls = 11'b1_00_1_0_00_0_10_0; // I-type ALU
            7'b1101111: controls = 11'b1_11_0_0_10_0_00_1; // jal
            
            7'b1010011: begin  // INSTRUCCIONES FP
                controls = 11'b0_00_0_0_11_0_11_0;
                FPOp = 1'b1;
                FPRegWrite = 1'b1;
            end
            
            default: begin
                controls = 11'b0_00_0_0_10_0_00_0;
                FPOp = 1'b0;
                FPRegWrite = 1'b0;
            end
        endcase
    end
endmodule

module mux2 (input  [WIDTH-1:0] d0, d1, 
              input  s, 
              output [WIDTH-1:0] y);

  parameter WIDTH = 8;

  assign y = s ? d1 : d0; 
endmodule

module mux3 (input  [WIDTH-1:0] d0, d1, d2,
              input  [1:0]       s, 
              output [WIDTH-1:0] y);

  parameter WIDTH = 8;

  assign y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule

  
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

    // NUEVAS señales FP
  wire FPRegWriteW, FPRegWriteM;
  wire [2:0] FPUControlE;
  
  // CABLES DE RIESGO (HAZARD)
  // Asegúrate de que NO estén duplicados ni sean de 1 bit si son buses
  wire [4:0] Rs1E, Rs2E, RdM, RdW, RdE, Rs1D, Rs2D;
  wire [1:0] ForwardAE, ForwardBE;
  wire [1:0] ForwardAE_FP, ForwardBE_FP; 
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
    
    .op(InstrD[6:0]), .funct3(InstrD[14:12]), .funct7(InstrD[31:25]),
    .ZeroE(ZeroE),
    .ResultSrcW(ResultSrcW), .MemWriteM(MemWriteM),
    .PCSrcE(PCSrcE), .ALUSrcE(ALUSrcE), .RegWriteW(RegWriteW),
    .ImmSrcD(ImmSrcD), .ALUControlE(ALUControlE),
    
    .RegWriteM(RegWriteM),
    .ResultSrcE_bit0(ResultSrcE_bit0),

    // NUEVO: Control FP
    .FPRegWriteW(FPRegWriteW),
    .FPUControlE(FPUControlE),
    .FPRegWriteM(FPRegWriteM)
  ); 
  
  // 2. INSTANCIA DEL DATAPATH
  datapath dp(
    .clk(clk), .reset(reset), 
    .ResultSrcW(ResultSrcW), .PCSrcE(PCSrcE), .ALUSrcE(ALUSrcE),
    .RegWriteW(RegWriteW), .ImmSrcD(ImmSrcD), .ALUControlE(ALUControlE),
    .ReadDataM(ReadDataM), .InstrF(InstrF),
    .ZeroE(ZeroE), .PCF(PCF), .InstrD(InstrD),
    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM),

        // NUEVO: Control FP
    .FPRegWriteW(FPRegWriteW),
    .FPUControlE(FPUControlE),
    .FPRegWriteM(FPRegWriteM),   
    // Hazard Connections
    .StallF(StallF), .StallD(StallD), .FlushE(FlushE), .FlushD(FlushD),
    .Rs1D(Rs1D), .Rs2D(Rs2D), 
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdM(RdM), .RdW(RdW), .RdE(RdE),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .ForwardAE_FP(ForwardAE_FP), .ForwardBE_FP(ForwardBE_FP) 
  );
  
  // 3. INSTANCIA DE HAZARD UNIT
  hazard_unit hu (
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdM(RdM), .RdW(RdW),
    .Rs1D(Rs1D), .Rs2D(Rs2D), .RdE(RdE),
    .PCSrcE(PCSrcE),
    .RegWriteM(RegWriteM),  // MODIFICADO: Considerar FP
    .RegWriteW(RegWriteW),  // MODIFICADO: Considerar FP    
    .ResultSrcE_bit0(ResultSrcE_bit0),
    .FPRegWriteM(FPRegWriteM),  // NUEVO PARA FPU
    .FPRegWriteW(FPRegWriteW), // NUEVO PARA FPU
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .ForwardAE_FP(ForwardAE_FP), .ForwardBE_FP(ForwardBE_FP),
    .StallF(StallF), .StallD(StallD), 
    .FlushE(FlushE), .FlushD(FlushD)
  );
    
endmodule

// === File: regfile.v ===
  

module regfile(input  clk, 
               input  we3, 
               input  [4:0] a1, a2, a3, 
               input  [31:0] wd3, 
               output [31:0] rd1, rd2); 

  reg [31:0] rf[31:0]; 

  // ESTO ES LO QUE TE FALTA: INICIALIZAR A CERO
  initial begin :hola
    integer i;
    for (i=0; i<32; i=i+1) begin
        rf[i] = 32'b0;
    end
  end

  // Escritura en flanco de bajada (Mantenemos tu lógica)
  always @(negedge clk) begin 
    if (we3) rf[a3] <= wd3; 
  end
  
  // Lectura con Bypass para evitar lecturas viejas
  // Si intentas leer lo que estás escribiendo en el mismo ciclo, te da el dato nuevo
  assign rd1 = (a1 == 0) ? 0 : 
               ((a1 == a3) && we3) ? wd3 : rf[a1];

  assign rd2 = (a2 == 0) ? 0 : 
               ((a2 == a3) && we3) ? wd3 : rf[a2];

endmodule

module fp_regfile(
    input clk,
    input we3,
    input [4:0] a1, a2, a3,
    input [31:0] wd3,
    output [31:0] rd1, rd2
);
    reg [31:0] fp_regs [31:0];
    
    // INICIALIZACIÓN EXPLÍCITA
    initial begin
        integer i;
        for (i = 0; i < 32; i = i + 1) begin
            fp_regs[i] = 32'h00000000;
        end
        
        // Pre-cargar valores de prueba
        fp_regs[1] = 32'h40200000; // f1 = 2.5
        fp_regs[2] = 32'h40400000; // f2 = 3.0
        fp_regs[3] = 32'h3F800000; // f3 = 1.0
        fp_regs[4] = 32'h40A00000; // f4 = 5.0
        
        $display("[fp_regfile] Registros FP inicializados:");
        $display("  f1 = 0x%h", fp_regs[1]);
        $display("  f2 = 0x%h", fp_regs[2]);
        $display("  f3 = 0x%h", fp_regs[3]);
        $display("  f4 = 0x%h", fp_regs[4]);
    end
    
    // Lectura asíncrona (sin protección de x0 para FP)
    assign rd1 = fp_regs[a1];
    assign rd2 = fp_regs[a2];
    
    // Escritura síncrona
    always @(posedge clk) begin
        if (we3 && a3 != 0) begin
            fp_regs[a3] <= wd3;
            $display("[fp_regfile] Escribiendo f%0d = 0x%h", a3, wd3);
        end
    end
endmodule

module reg_decode_to_execute (
    input             clk,
    input             reset,
    input             clr,

    // --------- DATOS (desde etapa D) ----------
    input      [31:0] RD1D, RD2D, PCD, ImmExtD, PCPlus4D,
    input [31:0] FRD1D,      // NUEVO: Dato FP rs1
    input [31:0] FRD2D,      // NUEVO: Dato FP rs2
    input      [4:0]  RdD,

    // --------- DATOS (hacia etapa E) ----------
    output reg [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E,
    output reg [31:0] FRD1E,  // NUEVO
    output reg [31:0] FRD2E,  // NUEVO
    output reg [4:0]  RdE,
    
    // hazard
    input [4:0] Rs1D, Rs2D, 
    output reg [4:0] Rs1E, Rs2E 
);

    always @ (posedge clk or posedge reset) begin
        if (reset || clr) begin
            RD1E <= 0; RD2E <= 0; PCE <= 0; RdE <= 0; ImmExtE <= 0; PCPlus4E <= 0;
            Rs1E <= 0; Rs2E <= 0;
            FRD1E <= 32'b0;    // NUEVO
            FRD2E <= 32'b0;     //NUEVO
        end else begin
             // ✅ ESTE 'ELSE' FALTABA EN TU CÓDIGO
            // SI NO HAY FLUSH, CARGAMOS DATOS NORMALMENTE
            RD1E <= RD1D; RD2E <= RD2D; PCE <= PCD; RdE <= RdD; ImmExtE <= ImmExtD; PCPlus4E <= PCPlus4D;
            Rs1E <= Rs1D; Rs2E <= Rs2D;
            FRD1E <= FRD1D;    // NUEVO
            FRD2E <= FRD2D;    // NUEVO
        end
    end
endmodule

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
    input FPRegWriteD,      // NUEVO
    input [2:0] FPUControlD, // NUEVO

    // --------- CONTROL (hacia etapa E) --------
    output reg        RegWriteE,
    output reg [1:0]  ResultSrcE,
    output reg        MemWriteE,
    output reg        JumpE,
    output reg        BranchE,
    output reg [2:0]  ALUControlE,
    output reg        ALUSrcE,
    output reg FPRegWriteE,      // NUEVO
    output reg [2:0] FPUControlE // NUEVO

);

    always @(posedge clk or posedge reset) begin
        if (reset || clr) begin
            // Reset/Flush: NOP
            RegWriteE <= 0; ResultSrcE <= 2'b00; MemWriteE <= 0;
            JumpE <= 0; BranchE <= 0; ALUControlE <= 3'b000;
            ALUSrcE <= 0; 
            FPRegWriteE <= 0;      // NUEVO
            FPUControlE <= 3'b000; // NUEVO
        end else begin
            // Propagar señales
            RegWriteE <= RegWriteD; ResultSrcE <= ResultSrcD; MemWriteE <= MemWriteD;
            JumpE <= JumpD; BranchE <= BranchD; ALUControlE <= ALUControlD;
            ALUSrcE <= ALUSrcD;
            FPRegWriteE <= FPRegWriteD;      // NUEVO
            FPUControlE <= FPUControlD;      // NUEVO
        end
    end
endmodule

module reg_execute_to_memory(
    input             clk,
    input             reset,

    // --------- DATOS desde etapa E ----------
    input      [31:0] ALUResultE,
    input [31:0] FPResultE, // NUEVO: Resultado de FPU
    input      [31:0] WriteDataE,
    input      [4:0]  RdE,
    input      [31:0] PCPlus4E,

    // --------- DATOS hacia etapa M ----------
    output reg [31:0] ALUResultM,
    output reg [31:0] FPResultM,  // NUEVO
    output reg [31:0] WriteDataM,
    output reg [4:0]  RdM,  
    output reg [31:0] PCPlus4M
);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // DATOS
            ALUResultM <= 32'b0;
            FPResultM <= 32'b0; //NUEVO
            WriteDataM <= 32'b0;
            RdM        <= 5'b0;
            PCPlus4M   <= 32'b0;
        end else begin
            // DATOS
            ALUResultM <= ALUResultE;
            FPResultM <= FPResultE;   // NUEVO
            WriteDataM <= WriteDataE;
            RdM        <= RdE;
            PCPlus4M   <= PCPlus4E;
        end
    end

endmodule

module reg_execute_to_memory_control(
    input             clk,
    input             reset,

    // --------- CONTROL desde etapa E ---------
    input             RegWriteE,
    input      [1:0]  ResultSrcE,
    input             MemWriteE,
    input FPRegWriteE,  // NUEVO

    // --------- CONTROL hacia etapa M --------
    output reg        RegWriteM,
    output reg [1:0]  ResultSrcM,
    output reg        MemWriteM,
    output reg FPRegWriteM  // NUEVO

);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // CONTROL
            RegWriteM  <= 1'b0;
            ResultSrcM <= 2'b0;
            MemWriteM  <= 1'b0;
            FPRegWriteM <= 0;

        end else begin
            // CONTROL
            RegWriteM  <= RegWriteE;
            ResultSrcM <= ResultSrcE;
            MemWriteM  <= MemWriteE;
            FPRegWriteM <= FPRegWriteE;
        end
    end

endmodule

module reg_fetch_to_decode(
    input             clk,
    input             reset,
    input             en,   // Enable (Active High): Si es 0, congela el registro (Stall)
    input             clr,  // Clear (Active High): Si es 1, limpia el registro (Flush/Burbuja)

    // --------- ENTRADAS DESDE FETCH (F) ---------
    input      [31:0] InstrF,      // instrucción leída de la memoria
    input      [31:0] PCF,         // PC actual en F
    input      [31:0] PCPlus4F,    // PC+4 en F

    // --------- SALIDAS HACIA DECODE (D) ---------
    output reg [31:0] InstrD,      // instrucción latcheada para D
    output reg [31:0] PCD,         // PC en D
    output reg [31:0] PCPlus4D     // PC+4 en D
);

    always @ (posedge clk or posedge reset) begin
        // 1. Reset Asíncrono (Prioridad Máxima: Arranque)
        if (reset) begin
            InstrD    <= 32'b0;
            PCD       <= 32'b0;
            PCPlus4D  <= 32'b0;
        end 
        // 2. Flush Síncrono (Prioridad Media: Branch Taken)
        // Inserta una burbuja (NOP) descartando la instrucción actual
        else if (clr) begin
            InstrD    <= 32'b0;
            PCD       <= 32'b0;
            PCPlus4D  <= 32'b0;
        end 
        // 3. Enable (Prioridad Baja: Operación Normal vs Stall)
        // Si en=1, cargamos datos. Si en=0, mantenemos el valor anterior (Stall).
        else if (en) begin
            InstrD    <= InstrF;
            PCD       <= PCF;
            PCPlus4D  <= PCPlus4F;
        end
    end

endmodule

module reg_memory_to_writeback(
    input             clk,
    input             reset,

    // --------- DATOS desde etapa M ----------
    input      [31:0] ReadDataM,
    input      [31:0] ALUResultM,
    input [31:0] FPResultM, //nuevo
    input      [31:0] PCPlus4M,
    input      [4:0]  RdM,

    // --------- DATOS hacia etapa W ----------
    output reg [31:0] ReadDataW,
    output reg [31:0] ALUResultW,
    output reg [31:0] FPResultW, //nuevo
    output reg [31:0] PCPlus4W,
    output reg [4:0]  RdW
);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin

            // DATOS
            ReadDataW  <= 32'b0;
            ALUResultW <= 32'b0;
            FPResultW  <= 32'b0; //nuevo
            PCPlus4W   <= 32'b0;
            RdW        <= 5'b0;
        end else begin
        
            // DATOS
            ReadDataW  <= ReadDataM;
            ALUResultW <= ALUResultM;
            FPResultW  <= FPResultM; //nuevo
            PCPlus4W   <= PCPlus4M;
            RdW        <= RdM;
        end
    end

endmodule

module reg_memory_to_writeback_control(
    input             clk,
    input             reset,

    // --------- CONTROL desde etapa M ---------
    input             RegWriteM,
    input      [1:0]  ResultSrcM,
    input FPRegWriteM,  // NUEVO

    // --------- CONTROL hacia etapa W --------
    output reg        RegWriteW,
    output reg [1:0]  ResultSrcW,
    output reg FPRegWriteW  // NUEVO
);

    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            // CONTROL
            RegWriteW  <= 1'b0;
            ResultSrcW <= 2'b0;
            FPRegWriteW <= 0; 
        end else begin
            // CONTROL
            RegWriteW  <= RegWriteM;
            ResultSrcW <= ResultSrcM;
            FPRegWriteW <= FPRegWriteM;
        end
    end

endmodule

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


//MODULOS PARA EL FPU_TOP


   module fpu_top (
    input  wire [31:0] op_a,            // Operando A
    input  wire [31:0] op_b,            // Operando B
    input  wire [2:0]  op_code,         // 000 ADD, 001 SUB, 010 MUL, 011 DIV, 100 MIN, 101 MAX
    input  wire        round_mode,      // reservado; los bloques usan RNE
    output wire [31:0] result,          // Resultado (FP32)
    output wire [4:0]  flags            // {invalid, div_by_zero, overflow, underflow, inexact}
    );

    // Códigos de operación (actualizados para 3 bits y nuevas ops)
    parameter OP_ADD = 3'b000;
    parameter OP_SUB = 3'b001;
    parameter OP_MUL = 3'b010;
    parameter OP_DIV = 3'b011;
    parameter OP_MIN = 3'b100;
    parameter OP_MAX = 3'b101;

    // -----------------------------
    // Conversión de entradas (16->32 cuando mode_fp=0)
    // -----------------------------

    // -----------------------------
    // Instancias de los bloques FP32 (puramente combinacionales)
    // -----------------------------
    wire [31:0] y_add, y_mul, y_div, y_minmax;
    wire [4:0]  f_add, f_mul, f_div, f_minmax;

    // Módulo unificado ADD/SUB con op_sel
    // op_sel = 0 para ADD (op_code=000)
    // op_sel = 1 para SUB (op_code=001)
    wire op_sel_addsub = (op_code == OP_SUB) ? 1'b1 : 1'b0;
    
    fpu_add_fp32_vivado u_addsub (
        .op_sel(op_sel_addsub),
        .a(op_a), 
        .b(op_b),
        .result(y_add), 
        .flags(f_add)
    );

    fpu_mul_fp32_vivado u_mul (
        .a(op_a), 
        .b(op_b),
        .result(y_mul), 
        .flags(f_mul)
    );

    fpu_div_fp32_vivado u_div (
        .a(op_a), 
        .b(op_b),
        .result(y_div), 
        .flags(f_div)
    );

    fpu_minmax_fp32_vivado u_minmax_inst (
        .a(op_a), 
        .b(op_b),
        .is_max((op_code == OP_MAX) ? 1'b1 : 1'b0), // Conecta is_max según el op_code
        .result(y_minmax), 
        .flags(f_minmax)
    );

    // -----------------------------
    // Selección del camino activo (FP32)
    // -----------------------------
    reg [31:0] y_sel;
    reg [4:0]  f_sel;
    
    always @(*) begin
        case (op_code)
        OP_ADD: begin 
            y_sel = y_add;    
            f_sel = f_add;    
        end
        OP_SUB: begin 
            y_sel = y_add;    // Misma salida del módulo unificado
            f_sel = f_add;    
        end
        OP_MUL: begin 
            y_sel = y_mul;    
            f_sel = f_mul;    
        end
        OP_DIV: begin 
            y_sel = y_div;    
            f_sel = f_div;    
        end
        OP_MIN: begin 
            y_sel = y_minmax; 
            f_sel = f_minmax; 
        end
        OP_MAX: begin 
            y_sel = y_minmax; 
            f_sel = f_minmax; 
        end
        default: begin 
            y_sel = 32'd0;   
            f_sel = 5'd0;     
        end
        endcase
    end

    // -----------------------------
    // Salidas (con soporte de mode_fp)
    // -----------------------------
    assign result = y_sel;
    assign flags  = f_sel;  // OR de flags si hay conversión
        
    endmodule


module fpu_add_fp32_vivado (
    input  wire        op_sel,       // 0 = add (A+B), 1 = sub (A-B)
    input  wire [31:0] a,            // Operando A (FP32)
    input  wire [31:0] b,            // Operando B (FP32)
    output wire [31:0] result,       // Resultado (FP32)
    output wire [4:0] flags          // Flags de la operación
);

    // -------------------------
    // Etapa 0 (comb): Unpack + clasificación + "specials"
    // -------------------------
    wire sA = a[31];
    wire sB_orig = b[31];
    wire sB = sB_orig ^ op_sel; // Invertir signo de B si es resta
    
    wire [7:0]  eA = a[30:23], eB = b[30:23];
    wire [22:0] fA = a[22:0],  fB = b[22:0];

    wire A_isZero = (eA==8'd0) && (fA==23'd0);
    wire B_isZero = (eB==8'd0) && (fB==23'd0);
    wire A_isSub  = (eA==8'd0) && (fA!=23'd0);
    wire B_isSub  = (eB==8'd0) && (fB!=23'd0);
    wire A_isInf  = (eA==8'hFF) && (fA==23'd0);
    wire B_isInf  = (eB==8'hFF) && (fB==23'd0);
    wire A_isNaN  = (eA==8'hFF) && (fA!=23'd0);
    wire B_isNaN  = (eB==8'hFF) && (fB!=23'd0);

    // Mantisas 24b (bit oculto=1 si normal)
    wire [23:0] MA_c = A_isSub ? {1'b0, fA} : {(eA!=8'd0), fA};
    wire [23:0] MB_c = B_isSub ? {1'b0, fB} : {(eB!=8'd0), fB};

    // Exponentes desbiaseados (convención subnormal = -126)
    function signed [12:0] unbias;
        input [7:0] E;
        begin
            if (E==8'd0) unbias = 13'sd1 - 13'sd127; // -126
            else         unbias = $signed({5'b0,E}) - 13'sd127;
        end
    endfunction
    wire signed [12:0] eA_unb_c = unbias(eA);
    wire signed [12:0] eB_unb_c = unbias(eB);

    // Lógica de "Specials" de suma (directa)
    reg        sp_is_special_c;
    reg [31:0] sp_word_c;
    reg [4:0]  sp_flags_c;

    localparam [31:0] QNAN_CANON = {1'b0, 8'hFF, 1'b1, 22'd0};

    always @* begin
        sp_is_special_c = 1'b0;
        sp_word_c       = 32'b0;
        sp_flags_c      = 5'b0;

        // NaN -> qNaN canónico + invalid
        if (A_isNaN || B_isNaN) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b1_0000;                 // invalid
            sp_word_c       = QNAN_CANON;
        end
        // +Inf + -Inf => qNaN + invalid (considerando op_sel)
        else if ((A_isInf && B_isInf) && (sA ^ sB)) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b1_0000;
            sp_word_c       = QNAN_CANON;
        end
        // Inf + finite  OR Inf + Inf (same sign) => ±Inf
        else if (A_isInf || B_isInf) begin
            sp_is_special_c = 1'b1;
            sp_word_c       = {(A_isInf ? sA : sB), 8'hFF, 23'b0};
        end
    end

    // ---------------------------------------------------------
    // Etapa 1 (comb): Alineación + suma/resta + normalización
    // ---------------------------------------------------------
    // La operación efectiva depende de los signos DESPUÉS de aplicar op_sel
    wire effective_sub = (sA != sB); // RESTA efectiva si signos diferentes
    
    reg        sL_c, sS_c;
    reg signed [12:0] eL_c, eS_c;
    reg [27:0] extL_c, extS_c;
    reg [5:0]  shift_c;
    reg [27:0] S_aligned_c;
    reg        sticky_dropped_c;

    reg        sOUT_c1;
    reg signed [12:0] eSUM1_c1;
    reg [23:0] frac_with_hidden_c1;
    reg        G_c1, R_c1, S_c1;
    reg        exact_zero_c1;

    // Auxiliares para lógica interna
    reg [27:0] sum_ext;
    reg [27:0] diff_ext;
    reg [27:0] diff_norm;
    integer    i;
    integer    lz;
    reg        found;
    reg [27:0] dropped_mask;

    always @* begin
        // Inicialización de defaults
        sL_c = 1'b0; sS_c = 1'b0;
        eL_c = 13'sd0; eS_c = 13'sd0;
        extL_c = 28'd0; extS_c = 28'd0;
        shift_c = 6'd0;
        S_aligned_c = 28'd0;
        sticky_dropped_c = 1'b0;
        exact_zero_c1 = 1'b0;

        // ===== SELECCIÓN DEL MAYOR EN MAGNITUD ABSOLUTA =====
        // Siempre elegir el de mayor magnitud para alinear correctamente
        if (eA_unb_c > eB_unb_c) begin
            // A es mayor en magnitud
            sL_c  = sA; 
            sS_c  = sB;
            eL_c  = eA_unb_c; 
            eS_c  = eB_unb_c;
            extL_c = {1'b0, MA_c, 3'b000};
            extS_c = {1'b0, MB_c, 3'b000};
        
        end else if (eA_unb_c < eB_unb_c) begin
            // B es mayor en magnitud
            sL_c  = sB; 
            sS_c  = sA;
            eL_c  = eB_unb_c; 
            eS_c  = eA_unb_c;
            extL_c = {1'b0, MB_c, 3'b000};
            extS_c = {1'b0, MA_c, 3'b000};
        
        end else begin
            // Exponentes iguales → comparar mantisas
            if (MA_c >= MB_c) begin
                // A mayor o igual en magnitud
                sL_c  = sA; 
                sS_c  = sB;
                eL_c  = eA_unb_c; 
                eS_c  = eB_unb_c;
                extL_c = {1'b0, MA_c, 3'b000};
                extS_c = {1'b0, MB_c, 3'b000};
            end else begin
                // B mayor en magnitud
                sL_c  = sB; 
                sS_c  = sA;
                eL_c  = eB_unb_c; 
                eS_c  = eA_unb_c;
                extL_c = {1'b0, MB_c, 3'b000};
                extS_c = {1'b0, MA_c, 3'b000};
            end
        end

        // ===== ALINEACIÓN CON STICKY BIT =====
        if (eL_c >= eS_c) 
            shift_c = (eL_c - eS_c); 
        else 
            shift_c = 6'd0;
        
        if (shift_c == 0) begin
            S_aligned_c      = extS_c;
            sticky_dropped_c = 1'b0;
        end else if (shift_c >= 6'd28) begin
            // Todo cae -> sticky = OR de todos los bits
            S_aligned_c      = 28'd0;
            sticky_dropped_c = |extS_c;
        end else begin
            S_aligned_c      = (extS_c >> shift_c);
            // Máscara para bits descartados
            dropped_mask     = (28'h1 << shift_c) - 1;
            sticky_dropped_c = |(extS_c & dropped_mask);
        end

        // ===== OPERACIÓN EFECTIVA: SUMA O RESTA =====
        if (!effective_sub) begin
            // ================= SUMA EFECTIVA =================
            // Signos iguales: |A| + |B| con signo común
            sOUT_c1 = sL_c; // Signo común
            sum_ext = extL_c + S_aligned_c;

            if (sum_ext == 28'd0) begin
                // Resultado exacto cero
                exact_zero_c1       = 1'b1;
                frac_with_hidden_c1 = 24'd0;
                G_c1 = 1'b0; R_c1 = 1'b0; S_c1 = 1'b0;
                eSUM1_c1 = 13'sd0;
                // Signo del cero: +0 en RNE, excepto si ambos eran -0
                sOUT_c1  = (A_isZero && B_isZero && sA && sB) ? 1'b1 : 1'b0;
            end
            else if (sum_ext[27]) begin
                // Overflow a bit 27 -> normalizar dividiendo por 2
                frac_with_hidden_c1 = sum_ext[27:4]; // 24 bits
                G_c1 = sum_ext[3];
                R_c1 = sum_ext[2];
                S_c1 = sum_ext[1] | sum_ext[0] | sticky_dropped_c;
                eSUM1_c1 = eL_c + 1;
            end else begin
                // Resultado normalizado en bit 26
                frac_with_hidden_c1 = sum_ext[26:3];
                G_c1 = sum_ext[2];
                R_c1 = sum_ext[1];
                S_c1 = sum_ext[0] | sticky_dropped_c;
                eSUM1_c1 = eL_c;
            end
        end else begin
            // ================ RESTA EFECTIVA =================
            // Signos diferentes: |A| - |B|
            // El signo viene del operando de mayor magnitud (sL_c)
            sOUT_c1  = sL_c;
            diff_ext = extL_c - S_aligned_c;

            if (diff_ext == 28'd0) begin
                // Cancelación exacta -> +0 en modo RNE
                exact_zero_c1       = 1'b1;
                frac_with_hidden_c1 = 24'd0;
                G_c1 = 1'b0; R_c1 = 1'b0; S_c1 = 1'b0;
                eSUM1_c1 = 13'sd0;
                sOUT_c1  = 1'b0; // Siempre +0 en RNE
            end else begin
                // ===== CONTEO DE LEADING ZEROS =====
                // Buscamos el primer '1' desde la posición 26 hacia abajo
                lz    = 0;
                found = 1'b0;
                for (i=26; i>=0; i=i-1) begin
                    if (!found && diff_ext[i]) begin
                        lz    = 26 - i;
                        found = 1'b1;
                    end
                end
                if (!found) lz = 27;

                // Normalizar desplazando a la izquierda
                if (lz >= 27) 
                    diff_norm = 28'd0;
                else 
                    diff_norm = diff_ext << lz;

                // Extraer mantisa y bits de redondeo
                frac_with_hidden_c1 = diff_norm[26:3]; // 24 bits
                G_c1 = diff_norm[2];
                R_c1 = diff_norm[1];
                S_c1 = diff_norm[0] | sticky_dropped_c;
                eSUM1_c1 = eL_c - $signed({7'd0, lz[5:0]});
            end
        end
    end

    // ---------------------------------------------------------
    // Etapa 2 (comb): Redondeo RNE + empaquetado + flags
    // ---------------------------------------------------------
    wire [22:0] frac_pre_c2 = frac_with_hidden_c1[22:0];
    wire        roundUp_c2  = G_c1 && (R_c1 || S_c1 || frac_pre_c2[0]);

    wire [24:0] rounded_c2  = {1'b0, frac_with_hidden_c1} + (roundUp_c2 ? 25'd1 : 25'd0);

    reg  [23:0] frac_fin_c2;
    reg  signed [12:0] eSUM2_c2;
    always @* begin
        if (rounded_c2[24]) begin
            // Overflow por redondeo -> shift derecha
            frac_fin_c2 = rounded_c2[24:1];
            eSUM2_c2    = eSUM1_c1 + 1;
        end else begin
            frac_fin_c2 = rounded_c2[23:0];
            eSUM2_c2    = eSUM1_c1;
        end
    end

    // Detección de casos especiales
    wire is_zero_path_c2 = exact_zero_c1;

    // Exponente re-biased y condiciones
    wire signed [13:0] E_biased_c2     = eSUM2_c2 + 13'sd127;
    wire        overflow_c2            = (E_biased_c2 > 13'sd254);
    wire        under_biased_nonpos_c2 = (E_biased_c2 <= 0);
    wire        inexact_rnd_c2         = (G_c1 | R_c1 | S_c1);

    // Empaquetado final
    reg [31:0] normal_word_c2;
    reg [4:0]  normal_flags_c2;

    integer shift_den;
    reg [23:0] frac_den;
    reg        lost_bits;
    reg [23:0] mask24;

    always @* begin
        normal_word_c2  = 32'b0;
        normal_flags_c2 = 5'b0;
        lost_bits = 1'b0;

        if (is_zero_path_c2) begin
            // Usar el signo correcto del cero
            normal_word_c2  = {sOUT_c1, 8'd0, 23'd0};
            normal_flags_c2 = 5'b0;
        end
        else if (overflow_c2) begin
            // Overflow -> ±Infinito
            normal_word_c2     = {sOUT_c1, 8'hFF, 23'b0};
            normal_flags_c2[2] = 1'b1;    // overflow
            normal_flags_c2[0] = 1'b1;    // inexact (siempre en overflow)
        end
        else if (under_biased_nonpos_c2) begin
            // ===== SUBNORMALIZACIÓN =====
            shift_den = (1 - E_biased_c2); // >= 1
            
            if (shift_den >= 24) begin
                // Todo se pierde -> resultado ±0
                normal_word_c2     = {sOUT_c1, 8'd0, 23'd0};
                normal_flags_c2[1] = 1'b1;                   // underflow
                lost_bits = |frac_fin_c2;
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end else begin
                // Shift dentro del rango [1..23]
                frac_den = frac_fin_c2 >> shift_den;
                normal_word_c2     = {sOUT_c1, 8'd0, frac_den[22:0]};
                normal_flags_c2[1] = 1'b1;                   // underflow
                
                // Detectar bits perdidos
                mask24 = ((24'h1 << shift_den) - 1);
                lost_bits = |(frac_fin_c2 & mask24);
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end
        end
        else begin
            // ===== NÚMERO NORMAL =====
            normal_word_c2     = {sOUT_c1, E_biased_c2[7:0], frac_fin_c2[22:0]};
            normal_flags_c2[0] = inexact_rnd_c2;
        end
    end

    // ===== SALIDAS FINALES =====
    assign result = sp_is_special_c ? sp_word_c  : normal_word_c2;
    assign flags  = sp_is_special_c ? sp_flags_c : normal_flags_c2;

endmodule


module fpu_div_fp32_vivado (
    input  wire [31:0] a,            // Operando A (FP32) - numerador
    input  wire [31:0] b,            // Operando B (FP32) - denominador
    output wire [31:0] result,       // Resultado (FP32)
    output wire [4:0] flags          // {invalid, div_by_zero, overflow, underflow, inexact}
);

    localparam [31:0] QNAN_CANON = {1'b0, 8'hFF, 1'b1, 22'd0};
    localparam BIAS = 127;

    // -------------------------
    // Etapa 0 (comb): Unpack + clasificación + specials
    // -------------------------
    wire sA = a[31], sB = b[31];
    wire [7:0]  eA = a[30:23], eB = b[30:23];
    wire [22:0] fA = a[22:0],  fB = b[22:0];

    wire A_isZero = (eA==8'd0) && (fA==23'd0);
    wire B_isZero = (eB==8'd0) && (fB==23'd0);
    wire A_isSub  = (eA==8'd0) && (fA!=23'd0);
    wire B_isSub  = (eB==8'd0) && (fB!=23'd0);
    wire A_isInf  = (eA==8'hFF) && (fA==23'd0);
    wire B_isInf  = (eB==8'hFF) && (fB==23'd0);
    wire A_isNaN  = (eA==8'hFF) && (fA!=23'd0);
    wire B_isNaN  = (eB==8'hFF) && (fB!=23'd0);

    // Signo de salida
    wire sOUT_c = sA ^ sB;

    // Mantisas 24b (bit oculto=1 si normal)
    wire [23:0] MA_c = A_isSub ? {1'b0, fA} : {(eA!=8'd0), fA};
    wire [23:0] MB_c = B_isSub ? {1'b0, fB} : {(eB!=8'd0), fB};

    // Exponentes desbiaseados (signed)
    function signed [12:0] unbias;
        input [7:0] E;
        begin
            if (E==8'd0) unbias = 13'sd1 - 13'sd127;  // -126
            else         unbias = $signed({5'b0,E}) - 13'sd127;
        end
    endfunction
    wire signed [12:0] eA_unb_c = unbias(eA);
    wire signed [12:0] eB_unb_c = unbias(eB);

    // Specials (comb)
    reg        sp_is_special_c;
    reg [31:0] sp_word_c;
    reg [4:0]  sp_flags_c;

    always @* begin
        sp_is_special_c = 1'b0;
        sp_word_c       = 32'b0;
        sp_flags_c      = 5'b0;

        // NaN en entrada -> qNaN + invalid
        // 0/0 y Inf/Inf también invalid (qNaN)
        if (A_isNaN || B_isNaN || (A_isZero && B_isZero) || (A_isInf && B_isInf)) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b1_0000;    // invalid
            sp_word_c       = QNAN_CANON;
        end
        // x / 0 (x finito no-cero) => ±Inf + div_by_zero
        else if (B_isZero && !(A_isZero || A_isNaN || A_isInf)) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b0_1000;    // div_by_zero
            sp_word_c       = {sOUT_c, 8'hFF, 23'b0};
        end
        // Inf / finite => ±Inf
        else if (A_isInf && !B_isInf) begin
            sp_is_special_c = 1'b1;
            sp_word_c       = {sOUT_c, 8'hFF, 23'b0};
        end
        // 0 / Inf => ±0
        else if (A_isZero && B_isInf) begin
            sp_is_special_c = 1'b1;
            sp_word_c       = {sOUT_c, 8'd0, 23'd0};
        end
        // else -> camino normal
    end

    // Señales de la etapa 0 que alimentan el camino normal
    wire sOUT_e1_input = sOUT_c;
    wire [23:0] MA_e1_input = MA_c;
    wire [23:0] MB_e1_input = MB_c;
    wire signed [12:0] eDIFF0_e1_input = eA_unb_c - eB_unb_c;
    wire sp_is_special_e1_input = sp_is_special_c;
    wire [31:0] sp_word_e1_input = sp_word_c;
    wire [4:0] sp_flags_e1_input = sp_flags_c;

    // ---------------------------------------------------------
    // Etapa 1 (comb): División de mantisas + pre-normalización
    // ---------------------------------------------------------
    // Q_scaled: aproximación a la mantisa escalada (tamaño 26 bits en este diseño)
    // Si MA >= MB calculamos con <<25 (Q_scaled en [2^25 .. 2^26) => bit 25 = 1)
    // Si MA <  MB calculamos con <<26 (Q_scaled en [2^25 .. 2^26) también tras ajustar exp)
    reg  [25:0] Q_scaled_c;
    reg         sticky_rem_c; // indicará si hay resto no-cero (S)
    reg  signed [12:0] eDIFF1_c;

    // temporales para división
    reg [49:0] numer; // lo usamos para crear {MA, shift}
    reg [23:0] denom;

    always @* begin
        // Defaults
        Q_scaled_c    = 26'd0;
        sticky_rem_c  = 1'b0;
        eDIFF1_c      = eDIFF0_e1_input;
        denom         = MB_e1_input;

        if (MB_e1_input == 24'd0) begin
            // debería haber sido manejado por specials; proteger
            Q_scaled_c   = 26'd0;
            sticky_rem_c = 1'b0;
            eDIFF1_c     = eDIFF0_e1_input;
        end
        else if (MA_e1_input >= MB_e1_input) begin
            // Queremos Q_scaled con MSB en bit 25 (1 <= Q < 2)
            numer = {MA_e1_input, 25'd0}; // 24 + 25 = 49 bits
            Q_scaled_c = numer / denom;   // división entera
            sticky_rem_c = ( (numer % denom) != 0 );
            eDIFF1_c = eDIFF0_e1_input;
            // En algunos casos extremos Q_scaled_c[25] podría quedar 0 (teórico),
            // pero usando <<25 con MA>=MB garantizamos Q in [1,2), por tanto bit25=1.
        end
        else begin
            // MA < MB -> queremos normalizar la mantisa (Q in [0.5,1) -> lo transformamos a [1,2) reduciendo expo)
            numer = {MA_e1_input, 26'd0};
            Q_scaled_c = numer / denom;   // ahora Q_scaled in [2^25/2 .. 2^26) -> bit25 may be 1
            sticky_rem_c = ( (numer % denom) != 0 );
            eDIFF1_c = eDIFF0_e1_input - 1;
            // tras esto Q_scaled_c[25] normalmente == 1 (porque numer/denom ~ (MA/MB)*2^26 >= 2^25)
        end
    end

    // Señales Etapa 1 -> Etapa 2
    wire sOUT_e2_input = sOUT_e1_input;
    wire [25:0] Q_scaled_e2_input = Q_scaled_c;
    wire S_e2_input = sticky_rem_c;
    wire signed [12:0] eDIFF1_e2_input = eDIFF1_c;
    wire sp_is_special_e2_input = sp_is_special_e1_input;
    wire [31:0] sp_word_e2_input = sp_word_e1_input;
    wire [4:0] sp_flags_e2_input = sp_flags_e1_input;

    // ---------------------------------------------------------
    // Etapa 2 (comb): RNE + empaquetado + flags
    // ---------------------------------------------------------
    // Interpretación de Q_scaled:
    // Q_scaled[25] = implicit leading bit (debe ser 1 si normalizado)
    // bits [24:2] -> frac_pre (23 bits)
    // bits [1] -> G
    // bits [0] -> R
    wire [22:0] frac_pre_c2 = Q_scaled_e2_input[24:2];
    wire        G_c2        = Q_scaled_e2_input[1];
    wire        R_c2        = Q_scaled_e2_input[0];
    wire        S_c2        = S_e2_input;
    wire        roundUp_c2  = G_c2 && (R_c2 || S_c2 || frac_pre_c2[0]);

    // Mantisa con hidden bit (24 bits)
    wire [23:0] frac_with_hidden_c2 = {Q_scaled_e2_input[25], frac_pre_c2}; // bit25 is hidden
    wire [24:0] rounded_c2 = {1'b0, frac_with_hidden_c2} + (roundUp_c2 ? 25'd1 : 25'd0);

    reg  [23:0] frac_fin_c2;
    reg  signed [12:0] eSUM2_c2;
    always @* begin
        if (rounded_c2[24]) begin
            // overflow en mantisa -> shift right 1 implícito y exponente +1
            frac_fin_c2 = rounded_c2[24:1];
            eSUM2_c2    = eDIFF1_e2_input + 1;
        end else begin
            frac_fin_c2 = rounded_c2[23:0];
            eSUM2_c2    = eDIFF1_e2_input;
        end
    end

    // Exponente re-bias y estados
    wire signed [13:0] E_biased_c2     = eSUM2_c2 + 13'sd127;
    wire        overflow_c2            = (E_biased_c2 > 13'sd254);
    wire        under_biased_nonpos_c2 = (E_biased_c2 <= 0);
    wire        inexact_rnd_c2         = (G_c2 | R_c2 | S_c2);

    // Empaquetado normal/subnormal
    reg [31:0] normal_word_c2;
    reg [4:0]  normal_flags_c2;

    integer shift_den;
    reg [23:0] frac_den;
    reg        lost_bits;
    reg [23:0] mask24;

    always @* begin
        normal_word_c2  = 32'b0;
        normal_flags_c2 = 5'b0;
        lost_bits = 1'b0;

        if (overflow_c2) begin
            // Overflow -> ±Inf; mark inexact (per IEEE when overflow produced by rounding/inexact)
            normal_word_c2     = {sOUT_e2_input, 8'hFF, 23'b0};
            normal_flags_c2[2] = 1'b1; // overflow
            normal_flags_c2[0] = 1'b1; // inexact (set on overflow)
        end
        else if (under_biased_nonpos_c2) begin
            // Subnormalización (underflow)
            shift_den = (1 - E_biased_c2); // >= 1
            if (shift_den >= 24) begin
                // todo se pierde -> ±0
                normal_word_c2     = {sOUT_e2_input, 8'd0, 23'd0};
                normal_flags_c2[1] = 1'b1; // underflow
                lost_bits = |frac_fin_c2;
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end else begin
                // shift_den in [1..23]
                mask24 = ((24'h1 << shift_den) - 1);
                frac_den = frac_fin_c2 >> shift_den;
                normal_word_c2     = {sOUT_e2_input, 8'd0, frac_den[22:0]};
                normal_flags_c2[1] = 1'b1; // underflow
                lost_bits = |(frac_fin_c2 & mask24);
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end
        end
        else begin
            // Normal
            normal_word_c2     = {sOUT_e2_input, E_biased_c2[7:0], frac_fin_c2[22:0]};
            normal_flags_c2[0] = inexact_rnd_c2;
        end
    end

    // Selección final respetando specials
    assign result = sp_is_special_e2_input ? sp_word_e2_input  : normal_word_c2;
    assign flags  = sp_is_special_e2_input ? sp_flags_e2_input : normal_flags_c2;

endmodule


  

module fpu_minmax_fp32_vivado (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        is_max,       // 1 = FMAX.S, 0 = FMIN.S
    output wire [31:0] result,
    output wire [4:0]  flags         // {invalid, div_by_zero, overflow, underflow, inexact}
);

    // Desempaquetado
    wire sA = a[31];
    wire [7:0] eA = a[30:23];
    wire [22:0] fA = a[22:0];

    wire sB = b[31];
    wire [7:0] eB = b[30:23];
    wire [22:0] fB = b[22:0];

    // Clasificación
    wire A_isZero   = (eA == 8'd0) && (fA == 23'd0);
    wire B_isZero   = (eB == 8'd0) && (fB == 23'd0);

    wire A_isSub    = (eA == 8'd0) && (fA != 23'd0);
    wire B_isSub    = (eB == 8'd0) && (fB != 23'd0);

    wire A_isNormal = (eA != 8'd0) && (eA != 8'hFF);
    wire B_isNormal = (eB != 8'd0) && (eB != 8'hFF);

    wire A_isInf    = (eA == 8'hFF) && (fA == 23'd0);
    wire B_isInf    = (eB == 8'hFF) && (fB == 23'd0);

    wire A_isNaN    = (eA == 8'hFF) && (fA != 23'd0);
    wire B_isNaN    = (eB == 8'hFF) && (fB != 23'd0);

    wire A_isSNaN   = A_isNaN && (fA[22] == 1'b0);
    wire B_isSNaN   = B_isNaN && (fB[22] == 1'b0);
    wire A_isQNaN   = A_isNaN && (fA[22] == 1'b1);
    wire B_isQNaN   = B_isNaN && (fB[22] == 1'b1);

    localparam [31:0] QNAN_CANON = {1'b0, 8'hFF, 1'b1, 22'd0}; // +qNaN canónico

    reg [31:0] final_result;
    reg [4:0]  final_flags;

    // auxiliares para comparación
    reg [31:0] val_a_comp;
    reg [31:0] val_b_comp;

    always @(*) begin
        final_result = 32'd0;
        final_flags  = 5'b0;

        // Si hay SNaN -> setear invalid (según v2.2 la espec indica que se setea la flag,
        // pero no obliga a devolver la qNaN si el otro operando no es NaN).
        if (A_isSNaN || B_isSNaN) begin
            final_flags[4] = 1'b1; // invalid (bit alto según tu convención)
        end

        // Casos NaN / propagación conforme a v2.2:
        if (A_isNaN && B_isNaN) begin
            final_result = QNAN_CANON; // ambos NaN -> qNaN canónico
        end else if (A_isNaN) begin
            final_result = b; // propaga el no-NaN
        end else if (B_isNaN) begin
            final_result = a;
        end
        // Ambos ceros
        else if (A_isZero && B_isZero) begin
            if (sA == sB) begin
                // mismos signos -> devolver el operando (conservar signo/payload)
                final_result = a;
            end else begin
                // signos distintos: -0.0 < +0.0
                final_result = (is_max) ? 32'h00000000 : 32'h80000000;
            end
        end
        else begin
            // Comparación lexicográfica: invertir bits cuando negativo para comparar como enteros
            val_a_comp = sA ? ~a : a;
            val_b_comp = sB ? ~b : b;

            if (sA == sB) begin
                if (!sA) begin
                    // ambos positivos
                    final_result = (is_max) ? ((val_a_comp > val_b_comp) ? a : b)
                                           : ((val_a_comp < val_b_comp) ? a : b);
                end else begin
                    // ambos negativos
                    final_result = (is_max) ? ((val_a_comp < val_b_comp) ? a : b)
                                           : ((val_a_comp > val_b_comp) ? a : b);
                end
            end else begin
                // signos distintos: positivo > negativo
              final_result = (is_max) ? (sA ? b : a) : (sA ? a : b); //max:min
            end
        end
    end

    assign result = final_result;
    assign flags  = final_flags;

endmodule


// ============================================================================
// fpu_mul_fp32_vivado  -  FP32 IEEE-754  -  Lógica puramente combinacional
// ----------------------------------------------------------------------------
// Implementación combinacional de multiplicación IEEE-754 simple precisión.
// Pensado como golden model (no sintetizable tal cual).
// Flags: {invalid, div_by_zero, overflow, underflow, inexact}
// ============================================================================

module fpu_mul_fp32_vivado (
    input  wire [31:0] a, b,
    output wire [31:0] result,
    output wire [4:0] flags
);

    localparam [31:0] QNAN = {1'b0, 8'hFF, 1'b1, 22'd0};
    localparam BIAS = 127;

    // =========================================================================
    // Etapa 0 — Unpack + clasificación + specials
    // =========================================================================
    wire sA = a[31], sB = b[31];
    wire [7:0]  eA = a[30:23], eB = b[30:23];
    wire [22:0] fA = a[22:0],  fB = b[22:0];

    wire A_isZero = (eA==8'd0) && (fA==0);
    wire B_isZero = (eB==8'd0) && (fB==0);
    wire A_isSub  = (eA==0)     && (fA!=0);
    wire B_isSub  = (eB==0)     && (fB!=0);
    wire A_isInf  = (eA==8'hFF) && (fA==0);
    wire B_isInf  = (eB==8'hFF) && (fB==0);
    wire A_isNaN  = (eA==8'hFF) && (fA!=0);
    wire B_isNaN  = (eB==8'hFF) && (fB!=0);

    wire sOUT_c = sA ^ sB;

    reg sp_is_special_c;
    reg [31:0] sp_word_c;
    reg [4:0]  sp_flags_c;

    always @* begin
        sp_is_special_c = 0;
        sp_word_c       = 0;
        sp_flags_c      = 0;

        // NaN siempre gana
        if (A_isNaN || B_isNaN) begin
            sp_is_special_c = 1;
            sp_flags_c      = 5'b1_0000; // invalid
            sp_word_c       = QNAN;
        end
        // 0 * Inf => invalid
        else if ((A_isZero && B_isInf) || (A_isInf && B_isZero)) begin
            sp_is_special_c = 1;
            sp_flags_c      = 5'b1_0000; // invalid
            sp_word_c       = QNAN;
        end
        // Inf * finito → Inf
        else if (A_isInf || B_isInf) begin
            sp_is_special_c = 1;
            sp_word_c       = {sOUT_c, 8'hFF, 23'd0};
        end
        // 0 * finito → 0
        else if (A_isZero || B_isZero) begin
            sp_is_special_c = 1;
            sp_word_c       = {sOUT_c, 8'd0, 23'd0};
        end
    end

    // Mantisas con bit oculto
    wire [23:0] MA_c = A_isSub ? {1'b0,fA} : {(eA!=0), fA};
    wire [23:0] MB_c = B_isSub ? {1'b0,fB} : {(eB!=0), fB};

    // Exponentes desbiaseados
    function signed [12:0] unbias(input [7:0] E);
        if (E==0) unbias = 13'sd1 - 13'sd127;
        else      unbias = $signed({5'b0,E}) - 13'sd127;
    endfunction

    wire signed [12:0] eA_unb = unbias(eA);
    wire signed [12:0] eB_unb = unbias(eB);

    wire signed [12:0] eSUM0 = eA_unb + eB_unb;

    // =========================================================================
    // Etapa 1 — Producto de mantisas + pre-normalización
    // =========================================================================
    wire [47:0] PROD = MA_c * MB_c;

    reg [47:0] Pn_c;
    reg signed [12:0] eSUM1_c;

    always @* begin
        if (PROD[47]) begin
            // 10.xxxxxxx
            Pn_c    = PROD >> 1;
            eSUM1_c = eSUM0 + 1;
        end else if (PROD[46]) begin
            // 1.xxxxxxx
            Pn_c    = PROD;
            eSUM1_c = eSUM0;
        end else begin
            // 0.xxxxxxx (solo ocurre con subnormales)
            Pn_c    = PROD << 1;
            eSUM1_c = eSUM0 - 1;
        end
    end

    // =========================================================================
    // Etapa 2 — Round-to-Nearest-Even + empaquetado IEEE
    // =========================================================================
    wire [22:0] frac_pre = Pn_c[45:23];
    wire        G = Pn_c[22];
    wire        R = Pn_c[21];
    wire        S = |Pn_c[20:0];

    wire roundUp = G && (R || S || frac_pre[0]);

    wire [23:0] frac_with_hidden = {Pn_c[46], frac_pre};

    wire [24:0] rounded = {1'b0, frac_with_hidden} +
                          (roundUp ? 25'd1 : 25'd0);

    reg [23:0] frac_fin;
    reg signed [12:0] eSUM2;

    always @* begin
        if (rounded[24]) begin
            // overflow mantisa → shift + exp+1
            frac_fin = rounded[24:1];
            eSUM2    = eSUM1_c + 1;
        end else begin
            frac_fin = rounded[23:0];
            eSUM2    = eSUM1_c;
        end
    end

    // Sesgar exponente
    wire signed [13:0] E_biased = eSUM2 + 13'sd127;

    wire overflow  = (E_biased > 13'sd254);
    wire underflow = (E_biased <= 0);
    wire inexact   = (G | R | S);

    // =========================================================================
    // Empaquetado final (normal/subnormal)
    // =========================================================================
    reg [31:0] normal_word;
    reg [4:0]  normal_flags;

    integer shift;
    reg [23:0] frac_den;
    reg lost_bits;
    reg [23:0] mask;

    always @* begin
        normal_word  = 0;
        normal_flags = 0;
        lost_bits    = 0;

        if (overflow) begin
            normal_word       = {sOUT_c, 8'hFF, 23'd0};
            normal_flags[2]   = 1'b1;  // overflow
            normal_flags[0]   = 1'b1;  // inexact obligatorio
        end

        else if (underflow) begin
            shift = (1 - E_biased);

            if (shift >= 24) begin
                normal_word       = {sOUT_c, 8'd0, 23'd0};
                normal_flags[1]   = 1;
                lost_bits         = |frac_fin;
                normal_flags[0]   = inexact | lost_bits;
            end else begin
                mask = (24'h1 << shift) - 1;
                frac_den = frac_fin >> shift;

                lost_bits = |(frac_fin & mask);

                normal_word       = {sOUT_c, 8'd0, frac_den[22:0]};
                normal_flags[1]   = 1'b1;
                normal_flags[0]   = inexact | lost_bits;
            end
        end

        else begin
            normal_word       = {sOUT_c, E_biased[7:0], frac_fin[22:0]};
            normal_flags[0]   = inexact;
        end
    end

    // =========================================================================
    // Selección final: specials tienen prioridad
    // =========================================================================
    assign result = sp_is_special_c ? sp_word_c  : normal_word;
    assign flags  = sp_is_special_c ? sp_flags_c : normal_flags;

endmodule

`timescale 1ns/1ps

module tb_top_pipeline_debug;
    reg clk;
    reg reset;
    wire [31:0] WriteData;
    wire [31:0] DataAdr;
    wire MemWrite;
    
    // ======================
    //  Instancia del TOP REAL
    // ==========================
    top dut (
        .clk(clk),
        .reset(reset),
        .WriteData(WriteData),
        .DataAdr(DataAdr),
        .MemWrite(MemWrite)
    );
    
    // ==========================
    //  Generador de clock
    // ==========================
    initial clk = 0;
    always #5 clk = ~clk;   // Periodo = 10ns (100MHz)
    
    // Variables para tracking
    integer cycle_count;
    
    // ==========================
    //  FUNCIONES DE DECODIFICACIÓN
    // ==========================
    
    // Decodificar instrucción completa
    function [200*8:1] decode_instruction;
        input [31:0] instr;
        reg [6:0] opcode;
        reg [2:0] funct3;
        reg [6:0] funct7;
        begin
            opcode = instr[6:0];
            funct3 = instr[14:12];
            funct7 = instr[31:25];
            
            case(opcode)
                7'b0110011: begin // R-type
                    if (funct7 == 7'b0000000 && funct3 == 3'b000)
                        decode_instruction = "ADD";
                    else if (funct7 == 7'b0100000 && funct3 == 3'b000)
                        decode_instruction = "SUB";
                    else if (funct3 == 3'b111)
                        decode_instruction = "AND";
                    else if (funct3 == 3'b110)
                        decode_instruction = "OR";
                    else if (funct3 == 3'b100)
                        decode_instruction = "XOR";
                    else
                        decode_instruction = "R-type";
                end
                7'b0010011: begin // I-type ALU
                    if (funct3 == 3'b000)
                        decode_instruction = "ADDI";
                    else if (funct3 == 3'b111)
                        decode_instruction = "ANDI";
                    else if (funct3 == 3'b110)
                        decode_instruction = "ORI";
                    else
                        decode_instruction = "I-ALU";
                end
                7'b0000011: decode_instruction = "LW";
                7'b0100011: decode_instruction = "SW";
                7'b1100011: decode_instruction = "BEQ";
                7'b1101111: decode_instruction = "JAL";
                7'b1010011: begin // FP
                    if (funct7 == 7'b0000000)
                        decode_instruction = "FADD.S";
                    else if (funct7 == 7'b0000100)
                        decode_instruction = "FSUB.S";
                    else if (funct7 == 7'b0001000)
                        decode_instruction = "FMUL.S";
                    else if (funct7 == 7'b0001100)
                        decode_instruction = "FDIV.S";
                    else if (funct7 == 7'b0010100 && funct3 == 3'b000)
                        decode_instruction = "FMIN.S";
                    else if (funct7 == 7'b0010100 && funct3 == 3'b001)
                        decode_instruction = "FMAX.S";
                    else
                        decode_instruction = "FP-OP";
                end
                default: decode_instruction = "NOP";
            endcase
        end
    endfunction
    
    // ==========================
    //  MONITOR DE PIPELINE
    // ==========================
    task display_pipeline_state;
        reg [31:0] instrF, instrD;
        begin
            // Capturar estados de cada etapa (DESDE LAS MEMORIAS/REGISTROS DEL DISEÑO)
            instrF = dut.imem.RAM[dut.pipeline1.PCF[31:2]];  // ✅ Lee desde imem
            instrD = dut.pipeline1.InstrD;
            
            $display("\n========== CICLO %0d ==========", cycle_count);
            $display("Tiempo: %0t ns", $time);
            
            // ETAPA FETCH
            $display("\n[FETCH]");
            $display("  PC:    0x%h", dut.pipeline1.PCF);
            $display("  Instr: 0x%h (%0s)", instrF, decode_instruction(instrF));
            $display("  StallF: %b", dut.pipeline1.StallF);
            
            // ETAPA DECODE
            $display("\n[DECODE]");
            $display("  PC:    0x%h", dut.pipeline1.dp.PCD);
            $display("  Instr: 0x%h (%0s)", instrD, decode_instruction(instrD));
            if (instrD != 32'h00000013 && instrD != 0) begin
                $display("  rs1=%0d rs2=%0d rd=%0d", instrD[19:15], instrD[24:20], instrD[11:7]);
                $display("  RD1D=0x%h RD2D=0x%h", dut.pipeline1.dp.RD1D, dut.pipeline1.dp.RD2D);
                if (instrD[6:0] == 7'b1010011) begin // FP
                    $display("  FRD1D=0x%h FRD2D=0x%h", dut.pipeline1.dp.FRD1D, dut.pipeline1.dp.FRD2D);
                end
                $display("  ImmExt=0x%h", dut.pipeline1.dp.ImmExtD);
            end
            $display("  StallD: %b FlushD: %b", dut.pipeline1.StallD, dut.pipeline1.FlushD);
                              // En display_pipeline_state(), sección DECODE:
if (instrD[6:0] == 7'b1010011) begin
    $display("  [DEBUG] Instrucción FP detectada");
    $display("  [DEBUG] FPRegWriteD = %b", dut.pipeline1.c.md.FPRegWrite);
    $display("  [DEBUG] FPOpD = %b", dut.pipeline1.c.md.FPOp);
end
            
            // ETAPA EX

            $display("\n[EXECUTE]");
            $display("  PC:    0x%h", dut.pipeline1.dp.PCE);
            $display("  rs1=%0d rs2=%0d rd=%0d", dut.pipeline1.Rs1E, dut.pipeline1.Rs2E, dut.pipeline1.RdE);
            $display("  SrcA=0x%h SrcB=0x%h", dut.pipeline1.dp.SrcAE, dut.pipeline1.dp.SrcBE);
            $display("  ALUResult=0x%h", dut.pipeline1.dp.ALUResultE);
            $display("  ALUControl=%b ZeroE=%b", dut.pipeline1.ALUControlE, dut.pipeline1.ZeroE);
            
            // Verificar si es operación FP
            if (dut.pipeline1.c.FPRegWriteE) begin
                $display("  [FP] FPSrcA=0x%h FPSrcB=0x%h", dut.pipeline1.dp.FPSrcAE, dut.pipeline1.dp.FPSrcBE);
                $display("  [FP] FPResult=0x%h", dut.pipeline1.dp.FPResultE);
                $display("  [FP] FPUControl=%b", dut.pipeline1.FPUControlE);
            end
            
            $display("  ForwardA=%b ForwardB=%b", dut.pipeline1.ForwardAE, dut.pipeline1.ForwardBE);
            $display("  FlushE: %b PCSrcE: %b", dut.pipeline1.FlushE, dut.pipeline1.PCSrcE);
            
            // ETAPA MEMORY
            $display("\n[MEMORY]");
            $display("  ALUResult=0x%h", dut.pipeline1.ALUResultM);
            $display("  WriteData=0x%h", dut.pipeline1.WriteDataM);
            $display("  MemWrite=%b DataAdr=0x%h", MemWrite, DataAdr);
            if (dut.pipeline1.c.FPRegWriteM) begin
                $display("  [FP] FPResult=0x%h", dut.pipeline1.dp.FPResultM);
            end
            $display("  rd=%0d RegWriteM=%b", dut.pipeline1.RdM, dut.pipeline1.RegWriteM);
            
            // ETAPA WRITEBACK
            $display("\n[WRITEBACK]");
            $display("  ALUResult=0x%h", dut.pipeline1.dp.ALUResultW);
            $display("  ReadData=0x%h", dut.pipeline1.dp.ReadDataW);
            $display("  Result=0x%h", dut.pipeline1.dp.ResultW);
            if (dut.pipeline1.c.FPRegWriteW) begin
                $display("  [FP] FPResult=0x%h", dut.pipeline1.dp.FPResultW);
            end
            $display("  rd=%0d RegWriteW=%b ResultSrc=%b", 
                     dut.pipeline1.RdW, dut.pipeline1.RegWriteW, dut.pipeline1.ResultSrcW);
            
            $display("==========================================");
        end
    endtask
    
    // ==========================
    //  MONITOR DE REGISTROS
    // ==========================
    task display_registers;
        integer i;
        begin
            $display("\n========== ESTADO DE REGISTROS ==========");
            
            // Registros enteros
            $display("\n[REGISTROS ENTEROS]");
            for (i = 0; i < 32; i = i + 1) begin
                if (dut.pipeline1.dp.rf.rf[i] != 0) begin
                    $display("  x%0d = 0x%h (%0d)", i, dut.pipeline1.dp.rf.rf[i], dut.pipeline1.dp.rf.rf[i]);
                end
            end
            
            // Registros FP
            $display("\n[REGISTROS FLOATING POINT]");
            for (i = 0; i < 32; i = i + 1) begin
                if (dut.pipeline1.dp.fprf.fp_regs[i] != 0) begin
                    $display("  f%0d = 0x%h", i, dut.pipeline1.dp.fprf.fp_regs[i]);
                end
            end
            
            $display("==========================================");
        end
    endtask
    
    // ==========================
    //  MONITOR DE MEMORIA
    // ==========================
    task display_memory;
        integer i;
        begin
            $display("\n========== MEMORIA DE DATOS ==========");
            for (i = 0; i < 16; i = i + 1) begin
                if (dut.dmem.RAM[i] != 0) begin
                    $display("  MEM[0x%h] = 0x%h", i*4, dut.dmem.RAM[i]);
                end
            end
            $display("======================================");
        end
    endtask
    
    // ==========================
    //  SECUENCIA DE SIMULACIÓN
    // ==========================
    initial begin
        $dumpfile("pipelined_debug.vcd");
        $dumpvars(0, tb_top_pipeline_debug);
        
        $display("\n╔════════════════════════════════════════════╗");
        $display("║  TESTBENCH DE DEBUGGING - PIPELINE RISC-V ║");
        $display("╚════════════════════════════════════════════╝\n");
        
        cycle_count = 0;
        
        // Reset
        reset = 1;
        #15;
        reset = 0;
        
        // ✅ INICIALIZAR SOLO REGISTROS FP (NO INSTRUCCIONES)
        // Las instrucciones ya están cargadas por imem desde riscvtest.txt
        @(posedge clk);
        #1; // Pequeño delay después del flanco
        
        $display("\n[INFO] Inicializando registros FP manualmente...");
        force dut.pipeline1.dp.fprf.fp_regs[1] = 32'h40200000; // f1 = 2.5
        force dut.pipeline1.dp.fprf.fp_regs[2] = 32'h40400000; // f2 = 3.0
        force dut.pipeline1.dp.fprf.fp_regs[3] = 32'h3F800000; // f3 = 1.0
        force dut.pipeline1.dp.fprf.fp_regs[4] = 32'h7F800000; // f4 = +inf
        force dut.pipeline1.dp.fprf.fp_regs[12] = 32'h3F800000; // f12=1

        
        #1;
        release dut.pipeline1.dp.fprf.fp_regs[1];
        release dut.pipeline1.dp.fprf.fp_regs[2];
        release dut.pipeline1.dp.fprf.fp_regs[3];
        release dut.pipeline1.dp.fprf.fp_regs[4];
        release dut.pipeline1.dp.fprf.fp_regs[12];
        
        $display("  f1 = 2.5  (0x40200000)");
        $display("  f2 = 3.0  (0x40400000)");
        $display("  f3 = 1.0  (0x3F800000)");
        $display("  f4 = +Inf ");
        $display("  f12= 1.0  (0x3F800000)");
        $display("[INFO] Registros FP inicializados.\n");
        
        // ✅ VERIFICAR QUE LAS INSTRUCCIONES SE CARGARON CORRECTAMENTE
        $display("[INFO] Verificando carga de instrucciones desde riscvtest.txt...");
        $display("  Instr[0x00] = 0x%h", dut.imem.RAM[0]);
        $display("  Instr[0x04] = 0x%h", dut.imem.RAM[1]);
        $display("  Instr[0x08] = 0x%h", dut.imem.RAM[2]);
        $display("[INFO] Instrucciones cargadas correctamente.\n");
        
        $display("\n[INFO] Reset completado. Iniciando ejecución...\n");
        
        // Ejecutar ciclo por ciclo mostrando estado detallado
      repeat(12) begin
            @(posedge clk);
            #1; // Pequeño delay para capturar señales estables
            cycle_count = cycle_count + 1;
            
            // Mostrar estado del pipeline cada ciclo
            display_pipeline_state();
          if (dut.pipeline1.c.FPRegWriteW && dut.pipeline1.RdW != 0) begin
    $display("[ALERT] FP Write: f%0d <= 0x%h", 
             dut.pipeline1.RdW, 
             dut.pipeline1.dp.FPResultW);
end

            
            // Mostrar registros cada 10 ciclos
            if (cycle_count % 10 == 0) begin
                display_registers();
                display_memory();
            end
        end
        
        // Reporte final
        $display("\n╔════════════════════════════════════════════╗");
        $display("║           ESTADO FINAL DEL SISTEMA        ║");
        $display("╚════════════════════════════════════════════╝");
        
        display_registers();
        display_memory();
        
        // Verificaciones específicas
        $display("\n========== VERIFICACIONES ==========");
        
        // Fase 4: FP
        $display("\n[FASE 1: FLOATING POINT]");
        if (dut.pipeline1.dp.fprf.fp_regs[13] == 32'h3F800000)
            $display("  ✓ f13 = 0x3F800000 (FMIN.S -> 1.0)");
        else
            $display("  ✗ f13 = 0x%h (esperado 0x3F800000)", dut.pipeline1.dp.fprf.fp_regs[5]);
            
        if (dut.pipeline1.dp.fprf.fp_regs[14] == 32'h7F800000)
            $display("  ✓ f14 = 0x7F800000 (FMAX.S correcto -> +Inf)");
        else
            $display("  ✗ f14 = 0x%h (esperado 0x7F800000)", dut.pipeline1.dp.fprf.fp_regs[9]);
        
        // Fase 5: Forwarding FP
        $display("\n[FASE 2: FORWARDING FP]");
        if (dut.pipeline1.dp.fprf.fp_regs[10] == 32'h41080000)
            $display("  ✓ f10 = 0x41080000 (Forwarding FP correcto)");
        else
            $display("  ✗ f10 = 0x%h (esperado 0x41080000)", dut.pipeline1.dp.fprf.fp_regs[10]);
        
        $display("\n====================================\n");
        
        $display("\n[INFO] Simulación completada en %0d ciclos", cycle_count);
        $display("[INFO] Total de instrucciones ejecutadas (aprox): %0d\n", cycle_count - 5);
        
        $finish;
    end
    
    // ==========================
    //  TIMEOUT DE SEGURIDAD
    // ==========================
    initial begin
        #500;
        $display("\n[ERROR] TIMEOUT - Simulación excedió 5us");
        $finish;
    end

endmodule
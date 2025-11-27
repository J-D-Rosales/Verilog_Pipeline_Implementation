`timescale 1ns / 1ns

module tb_complete_pipeline;

    // Señales del DUT
    reg clk, reset;
    wire [31:0] PCF;
    reg [31:0] InstrF;
    wire MemWriteM;
    wire [31:0] DataAdr, WriteDataM;
    reg [31:0] ReadDataM;
    
    // Memoria de datos simulada
    reg [31:0] data_mem [0:63];
    
    // Instancia del pipeline
    pipeline dut (
        .clk(clk), .reset(reset),
        .PCF(PCF), .InstrF(InstrF),
        .MemWriteM(MemWriteM),
        .DataAdr(DataAdr),
        .WriteDataM(WriteDataM),
        .ReadDataM(ReadDataM)
    );
    
    // Generación de reloj
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Simulación de memoria de datos
    always @(posedge clk) begin
        if (MemWriteM)
            data_mem[DataAdr[7:2]] <= WriteDataM;
        ReadDataM <= data_mem[DataAdr[7:2]];
    end
    
    // Contadores
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // =========================================================================
    // FUNCIONES AUXILIARES PARA CODIFICAR INSTRUCCIONES
    // =========================================================================
    
    // R-type: ADD, SUB, AND, OR, SLT
    function [31:0] encode_rtype;
        input [6:0] funct7;
        input [4:0] rs2, rs1, rd;
        input [2:0] funct3;
        begin
            encode_rtype = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
        end
    endfunction
    
    // I-type ALU: ADDI, SLTI, ANDI, ORI
    function [31:0] encode_itype_alu;
        input [11:0] imm;
        input [4:0] rs1, rd;
        input [2:0] funct3;
        begin
            encode_itype_alu = {imm, rs1, funct3, rd, 7'b0010011};
        end
    endfunction
    
    // Load: LW
    function [31:0] encode_load;
        input [11:0] offset;
        input [4:0] rs1, rd;
        begin
            encode_load = {offset, rs1, 3'b010, rd, 7'b0000011};
        end
    endfunction
    
    // Store: SW
    function [31:0] encode_store;
        input [11:0] offset;
        input [4:0] rs2, rs1;
        begin
            encode_store = {offset[11:5], rs2, rs1, 3'b010, offset[4:0], 7'b0100011};
        end
    endfunction
    
    // Branch: BEQ
    function [31:0] encode_beq;
        input [12:0] offset;
        input [4:0] rs2, rs1;
        begin
            encode_beq = {offset[12], offset[10:5], rs2, rs1, 3'b000, 
                         offset[4:1], offset[11], 7'b1100011};
        end
    endfunction
    
    // JAL
    function [31:0] encode_jal;
        input [20:0] offset;
        input [4:0] rd;
        begin
            encode_jal = {offset[20], offset[10:1], offset[11], offset[19:12], rd, 7'b1101111};
        end
    endfunction
    
    // FP R-type: FADD, FSUB, FMUL, FDIV
    function [31:0] encode_fp_rtype;
        input [6:0] funct7;
        input [4:0] rs2, rs1, rd;
        input [2:0] funct3;
        begin
            encode_fp_rtype = {funct7, rs2, rs1, funct3, rd, 7'b1010011};
        end
    endfunction
    
    // FMIN/FMAX
    function [31:0] encode_fp_minmax;
        input is_max;
        input [4:0] rs2, rs1, rd;
        begin
            encode_fp_minmax = {7'b0010100, rs2, rs1, (is_max ? 3'b001 : 3'b000), rd, 7'b1010011};
        end
    endfunction
    
    // =========================================================================
    // TASK PARA VERIFICAR RESULTADOS
    // =========================================================================
    task verify_register;
        input [4:0] reg_num;
        input [31:0] expected;
        input [200*8:1] test_name;
        begin
            test_count = test_count + 1;
            if (dut.dp.rf.rf[reg_num] == expected) begin
                $display("  ✓ PASS: %0s | x%0d = 0x%h", test_name, reg_num, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  ✗ FAIL: %0s | x%0d = 0x%h (esperado 0x%h)", 
                         test_name, reg_num, dut.dp.rf.rf[reg_num], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    task verify_fp_register;
        input [4:0] reg_num;
        input [31:0] expected;
        input [200*8:1] test_name;
        begin
            test_count = test_count + 1;
            if (dut.dp.fprf.fp_regs[reg_num] == expected) begin
                $display("  ✓ PASS: %0s | f%0d = 0x%h", test_name, reg_num, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  ✗ FAIL: %0s | f%0d = 0x%h (esperado 0x%h)", 
                         test_name, reg_num, dut.dp.fprf.fp_regs[reg_num], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    task verify_memory;
        input [31:0] addr;
        input [31:0] expected;
        input [200*8:1] test_name;
        begin
            test_count = test_count + 1;
            if (data_mem[addr[7:2]] == expected) begin
                $display("  ✓ PASS: %0s | MEM[0x%h] = 0x%h", test_name, addr, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  ✗ FAIL: %0s | MEM[0x%h] = 0x%h (esperado 0x%h)", 
                         test_name, addr, data_mem[addr[7:2]], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // =========================================================================
    // SECUENCIA PRINCIPAL DE TESTS
    // =========================================================================
    initial begin
        $dumpfile("pipeline_complete.vcd");
        $dumpvars(0, tb_complete_pipeline);
        
        $display("\n========================================");
        $display("  TESTBENCH COMPLETO: ALU + FPU + HAZARDS");
        $display("========================================\n");
        
        // Inicialización
        reset = 1;
        InstrF = 32'h00000013; // NOP
        ReadDataM = 32'h0;
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Inicializar memoria de datos
        for (integer i = 0; i < 64; i = i + 1)
            data_mem[i] = 32'h00000000;
        
        #12;
        reset = 0;
        
        // =====================================================================
        // FASE 1: TESTS DE ALU NORMAL (ENTEROS)
        // =====================================================================
        @(posedge clk);
        $display("========================================");
        $display("  FASE 1: INSTRUCCIONES ALU NORMALES");
        $display("========================================\n");
        
        // Inicializar registros enteros
        force dut.dp.rf.rf[1] = 32'h00000005;  // x1 = 5
        force dut.dp.rf.rf[2] = 32'h00000003;  // x2 = 3
        force dut.dp.rf.rf[3] = 32'h0000000A;  // x3 = 10
        force dut.dp.rf.rf[4] = 32'h00000002;  // x4 = 2
        #1;
        release dut.dp.rf.rf[1];
        release dut.dp.rf.rf[2];
        release dut.dp.rf.rf[3];
        release dut.dp.rf.rf[4];
        
        $display("Valores iniciales:");
        $display("  x1 = 5, x2 = 3, x3 = 10, x4 = 2\n");
        
        // --- Test 1.1: ADD x5 = x1 + x2 (5 + 3 = 8) ---
        $display("Test 1.1: ADD x5, x1, x2");
        @(posedge clk);
        InstrF = encode_rtype(7'b0000000, 5'd2, 5'd1, 5'd5, 3'b000);
        repeat(6) @(posedge clk);
        @(negedge clk);
        verify_register(5, 32'h00000008, "ADD x5, x1, x2");
        
        // --- Test 1.2: SUB x6 = x3 - x4 (10 - 2 = 8) ---
        $display("\nTest 1.2: SUB x6, x3, x4");
        @(posedge clk);
        InstrF = encode_rtype(7'b0100000, 5'd4, 5'd3, 5'd6, 3'b000);
        repeat(6) @(posedge clk);
        @(negedge clk);
        verify_register(6, 32'h00000008, "SUB x6, x3, x4");
        

        
        // --- Test 1.3: AND x8 = x5 & x6 (8 & 8 = 8) ---
      $display("\nTest 1.3: AND x8, x5, x6");
        @(posedge clk);
        InstrF = encode_rtype(7'b0000000, 5'd6, 5'd5, 5'd8, 3'b111);
        repeat(6) @(posedge clk);
        @(negedge clk);
        verify_register(8, 32'h00000008, "AND x8, x5, x6");
      
              // --- Test 1.4: ADDI x7 = x1 + 10 (5 + 10 = 15) ---
      $display("\nTest 1.4: ADDI x7, x1, 10");
        @(posedge clk);
        InstrF = encode_itype_alu(12'd10, 5'd1, 5'd7, 3'b000);
        repeat(6) @(posedge clk);
        @(negedge clk);
        verify_register(7, 32'h0000000F, "ADDI x7, x1, 10");
        
        // --- Test 1.5: OR x9 = x1 | x2 (5 | 3 = 7) ---
        $display("\nTest 1.5: OR x9, x1, x2");
        @(posedge clk);
        InstrF = encode_rtype(7'b0000000, 5'd2, 5'd1, 5'd9, 3'b110);
        repeat(6) @(posedge clk);
      	@(negedge clk);
        verify_register(9, 32'h00000007, "OR x9, x1, x2");
        
        // =====================================================================
        // FASE 2: TESTS DE FORWARDING (ALU)
        // =====================================================================
        @(posedge clk);
        $display("\n========================================");
        $display("  FASE 2: FORWARDING (ALU)");
        $display("========================================\n");
        
        // --- Test 2.1: RAW Hazard - Forwarding EX→EX ---
        $display("Test 2.1: Forwarding EX→EX");
        $display("  ADD x10, x1, x2  // x10 = 5 + 3 = 8");
        $display("  ADD x11, x10, x3 // x11 = 8 + 10 = 18 (usa x10 inmediatamente)");
        
        @(posedge clk);
        InstrF = encode_rtype(7'b0000000, 5'd2, 5'd1, 5'd10, 3'b000);
        @(posedge clk);
        InstrF = encode_rtype(7'b0000000, 5'd3, 5'd10, 5'd11, 3'b000);
        
        repeat(8) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        verify_register(10, 32'h00000008, "ADD x10, x1, x2");
        verify_register(11, 32'h00000012, "ADD x11, x10, x3 (forwarding)");
        
        // --- Test 2.2: Forwarding MEM→EX ---
        $display("\nTest 2.2: Forwarding MEM→EX");
        $display("  ADD x12, x1, x2  // x12 = 8");
        $display("  ADD x13, x12, x4 // x13 = 8 + 2 = 10 (forward desde MEM)");
        
        @(posedge clk);
        InstrF = encode_rtype(7'b0000000, 5'd2, 5'd1, 5'd12, 3'b000);
        @(posedge clk);
        InstrF = encode_rtype(7'b0000000, 5'd4, 5'd12, 5'd13, 3'b000);
        
        repeat(8) @(posedge clk);
        @(negedge clk);
        verify_register(13, 32'h0000000A, "ADD x13, x12, x4 (MEM forwarding)");
        
        // =====================================================================
        // FASE 3: TESTS DE LOAD-USE HAZARD (STALLS)
        // =====================================================================
        @(posedge clk);
        $display("\n========================================");
        $display("  FASE 3: LOAD-USE HAZARD (STALLS)");
        $display("========================================\n");
        
        // Preparar memoria
        data_mem[0] = 32'h0000CAFE;
        data_mem[1] = 32'hDEADBEEF;
        
        // --- Test 3.1: SW seguido de LW (mismo address) ---
        $display("Test 3.1: SW x5, 8(x0)  // Guardar 0x08 en MEM[8]");
        @(posedge clk);
        InstrF = encode_store(12'd8, 5'd5, 5'd0);
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        verify_memory(32'd8, 32'h00000008, "SW x5, 8(x0)");
        
        $display("\nTest 3.2: LW x14, 8(x0)  // Cargar desde MEM[8]");
        @(posedge clk);
        InstrF = encode_load(12'd8, 5'd0, 5'd14);
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        verify_register(14, 32'h00000008, "LW x14, 8(x0)");
        
        // --- Test 3.3: Load-Use Hazard (debe generar stall) ---
        $display("\nTest 3.3: Load-Use Hazard (debe stallear)");
        $display("  LW x15, 0(x0)     // x15 = MEM[0] = 0x0000CAFE");
        $display("  ADD x16, x15, x1  // x16 = x15 + 5 (debe stall)");
        
        @(posedge clk);
        InstrF = encode_load(12'd0, 5'd0, 5'd15);
        @(posedge clk);
        InstrF = encode_rtype(7'b0000000, 5'd1, 5'd15, 5'd16, 3'b000);
        
        repeat(10) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        verify_register(15, 32'h0000CAFE, "LW x15, 0(x0)");
        verify_register(16, 32'h0000CB03, "ADD x16, x15, x1 (after stall)");
        
        // =====================================================================
        // FASE 4: OPERACIONES FP BÁSICAS
        // =====================================================================
        @(posedge clk);
        $display("\n========================================");
        $display("  FASE 4: OPERACIONES FLOATING POINT");
        $display("========================================\n");
        
        // Inicializar registros FP
        force dut.dp.fprf.fp_regs[1] = 32'h40200000; // f1 = 2.5
        force dut.dp.fprf.fp_regs[2] = 32'h40400000; // f2 = 3.0
        force dut.dp.fprf.fp_regs[3] = 32'h3F800000; // f3 = 1.0
        force dut.dp.fprf.fp_regs[4] = 32'h40A00000; // f4 = 5.0
        #1;
        release dut.dp.fprf.fp_regs[1];
        release dut.dp.fprf.fp_regs[2];
        release dut.dp.fprf.fp_regs[3];
        release dut.dp.fprf.fp_regs[4];
        
        $display("Valores iniciales FP:");
        $display("  f1 = 2.5, f2 = 3.0, f3 = 1.0, f4 = 5.0\n");
        
        // --- Test 4.1: FADD.S ---
        $display("Test 4.1: FADD.S f5, f1, f2  // 2.5 + 3.0 = 5.5");
        @(posedge clk);
        InstrF = encode_fp_rtype(7'b0000000, 5'd2, 5'd1, 5'd5, 3'b000);
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        verify_fp_register(5, 32'h40B00000, "FADD.S f5, f1, f2");
        
        // --- Test 4.2: FMUL.S ---
        $display("\nTest 4.2: FMUL.S f6, f1, f2  // 2.5 * 3.0 = 7.5");
        @(posedge clk);
        InstrF = encode_fp_rtype(7'b0001000, 5'd2, 5'd1, 5'd6, 3'b000);
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        verify_fp_register(6, 32'h40F00000, "FMUL.S f6, f1, f2");
        
        // =====================================================================
        // FASE 5: FORWARDING FP
        // =====================================================================
        @(posedge clk);
        $display("\n========================================");
        $display("  FASE 5: FORWARDING FP");
        $display("========================================\n");
        
        // --- Test 5.1: RAW Hazard FP ---
        $display("Test 5.1: FP Forwarding EX→EX");
        $display("  FADD.S f7, f1, f2  // f7 = 5.5");
        $display("  FADD.S f8, f7, f3  // f8 = 6.5 (usa f7 inmediatamente)");
        
        @(posedge clk);
        InstrF = encode_fp_rtype(7'b0000000, 5'd2, 5'd1, 5'd7, 3'b000);
        @(posedge clk);
        InstrF = encode_fp_rtype(7'b0000000, 5'd3, 5'd7, 5'd8, 3'b000);
        
        repeat(8) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        verify_fp_register(7, 32'h40B00000, "FADD.S f7, f1, f2");
        verify_fp_register(8, 32'h40D00000, "FADD.S f8, f7, f3 (forwarding)");
        
        // --- Test 5.2: Cadena de dependencias FP ---
        $display("\nTest 5.2: Cadena de dependencias FP");
        $display("  FMUL.S f9, f1, f2   // f9 = 7.5");
        $display("  FADD.S f10, f9, f3  // f10 = 8.5");
        $display("  FSUB.S f11, f10, f1 // f11 = 6.0");
        
        @(posedge clk);
        InstrF = encode_fp_rtype(7'b0001000, 5'd2, 5'd1, 5'd9, 3'b000);
        @(posedge clk);
        InstrF = encode_fp_rtype(7'b0000000, 5'd3, 5'd9, 5'd10, 3'b000);
        @(posedge clk);
        InstrF = encode_fp_rtype(7'b0000100, 5'd1, 5'd10, 5'd11, 3'b000);
        
        repeat(12) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        verify_fp_register(9, 32'h40F00000, "FMUL.S f9, f1, f2");
        verify_fp_register(10, 32'h41080000, "FADD.S f10, f9, f3");
        verify_fp_register(11, 32'h40C00000, "FSUB.S f11, f10, f1");
        
        // =====================================================================
        // REPORTE FINAL
        // =====================================================================
        repeat(5) @(posedge clk);
        
        $display("\n========================================");
        $display("  REPORTE FINAL");
        $display("========================================");
        $display("  Tests ejecutados: %0d", test_count);
        $display("  Tests pasados:    %0d", pass_count);
        $display("  Tests fallados:   %0d", fail_count);
        $display("========================================");
        
        if (fail_count == 0) begin
            $display("\n  🎉 ¡TODOS LOS TESTS PASARON! 🎉\n");
        end else begin
            $display("\n  ⚠️  ALGUNOS TESTS FALLARON ⚠️\n");
        end
        
        #50;
        $finish;
    end

endmodule
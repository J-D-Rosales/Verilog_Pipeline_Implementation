`timescale 1ns / 1ns

module tb_fpu_simple;

    reg clk, reset;
    wire [31:0] PCF;
    reg [31:0] InstrF;
    wire MemWriteM;
    wire [31:0] DataAdr, WriteDataM;
    reg [31:0] ReadDataM;
    
    pipeline dut (
        .clk(clk), .reset(reset),
        .PCF(PCF), .InstrF(InstrF),
        .MemWriteM(MemWriteM),
        .DataAdr(DataAdr),
        .WriteDataM(WriteDataM),
        .ReadDataM(ReadDataM)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        $dumpfile("pipe.vcd");
        $dumpvars(0, tb_fpu_simple);
        $display("========================================");
        $display("  Testbench FPU Corregido");
        $display("========================================");
        
        // Reset
        reset = 1;
        InstrF = 32'h00000013;
        ReadDataM = 32'h0;
        #12;
        reset = 0;
        
        // ✅ Inicializar registros DESPUÉS del reset
        @(posedge clk);
        $display("\n[INFO] Inicializando registros FP...");
        force dut.dp.fprf.fp_regs[1] = 32'h40200000; // 2.5
        force dut.dp.fprf.fp_regs[2] = 32'h40700000; // 3.75
        force dut.dp.fprf.fp_regs[3] = 32'h3FA00000; // 1.25
        force dut.dp.fprf.fp_regs[4] = 32'h40A00000; // 5.0
        #1;
        release dut.dp.fprf.fp_regs[1];
        release dut.dp.fprf.fp_regs[2];
        release dut.dp.fprf.fp_regs[3];
        release dut.dp.fprf.fp_regs[4];
        
        $display("  f1 = 2.5 (0x40200000)");
        $display("  f2 = 3.75 (0x40700000)");
        $display("  f3 = 1.25 (0x3FA00000)");
        $display("  f4 = 5.0 (0x40A00000)");
        
        // ============================================
        // TEST 1: FADD.S f5, f1, f2
        // ============================================
        $display("\n--- TEST 1: FADD.S f5, f1, f2 ---");
        @(posedge clk);
        InstrF = 32'b0000000_00010_00001_000_00101_1010011;
        $display("  Ejecutando FADD...");
        
        // ✅ Esperar suficientes ciclos (mínimo 5 para pipeline)
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013; // NOP
        
        // ✅ Esperar un ciclo más para estabilizar
        @(negedge clk);
        $display("  Resultado: f5 = 0x%h (esperado 0x40C80000)", dut.dp.fprf.fp_regs[5]);
        
        // ============================================
        // TEST 2: FSUB.S f6, f2, f3
        // ============================================
        $display("\n--- TEST 2: FSUB.S f6, f2, f3 ---");
        @(posedge clk);
        InstrF = 32'b0000100_00011_00010_000_00110_1010011;
        
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        $display("  Resultado: f6 = 0x%h (esperado 0x40200000)", dut.dp.fprf.fp_regs[6]);
        
        // ============================================
        // TEST 3: FMUL.S f7, f1, f3
        // ============================================
        $display("\n--- TEST 3: FMUL.S f7, f1, f3 ---");
        @(posedge clk);
        InstrF = 32'b0001000_00011_00001_000_00111_1010011;
        
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        $display("  Resultado: f7 = 0x%h (esperado 0x40480000)", dut.dp.fprf.fp_regs[7]);
        
        // ============================================
        // TEST 4: FDIV.S f8, f4, f1
        // ============================================
        $display("\n--- TEST 4: FDIV.S f8, f4, f1 ---");
        @(posedge clk);
        InstrF = 32'b0001100_00001_00100_000_01000_1010011;
        
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        $display("  Resultado: f8 = 0x%h (esperado 0x40000000)", dut.dp.fprf.fp_regs[8]);
        
        // ============================================
        // TEST 5: FMIN.S f9, f1, f3
        // ============================================
        $display("\n--- TEST 5: FMIN.S f9, f1, f3 ---");
        @(posedge clk);
        InstrF = 32'b0010100_00011_00001_000_01001_1010011;
        
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        $display("  Resultado: f9 = 0x%h (esperado 0x3FA00000)", dut.dp.fprf.fp_regs[9]);
        
        // ============================================
        // TEST 6: FMAX.S f10, f1, f4
        // ============================================
        $display("\n--- TEST 6: FMAX.S f10, f1, f4 ---");
        @(posedge clk);
        InstrF = 32'b0010100_00100_00001_001_01010_1010011;
        
        repeat(6) @(posedge clk);
        InstrF = 32'h00000013;
        @(negedge clk);
        $display("  Resultado: f10 = 0x%h (esperado 0x40A00000)", dut.dp.fprf.fp_regs[10]);
        
        // ============================================
        // REPORTE FINAL
        // ============================================
        $display("\n========================================");
        $display("  RESUMEN FINAL DE TESTS");
        $display("========================================");
        $display("  f5 (FADD):  0x%h %s", dut.dp.fprf.fp_regs[5],
                 (dut.dp.fprf.fp_regs[5] == 32'h40C80000) ? "✓ PASS" : "✗ FAIL");
        $display("  f6 (FSUB):  0x%h %s", dut.dp.fprf.fp_regs[6],
                 (dut.dp.fprf.fp_regs[6] == 32'h40200000) ? "✓ PASS" : "✗ FAIL");
        $display("  f7 (FMUL):  0x%h %s", dut.dp.fprf.fp_regs[7],
                 (dut.dp.fprf.fp_regs[7] == 32'h40480000) ? "✓ PASS" : "✗ FAIL");
        $display("  f8 (FDIV):  0x%h %s", dut.dp.fprf.fp_regs[8],
                 (dut.dp.fprf.fp_regs[8] == 32'h40000000) ? "✓ PASS" : "✗ FAIL");
        $display("  f9 (FMIN):  0x%h %s", dut.dp.fprf.fp_regs[9],
                 (dut.dp.fprf.fp_regs[9] == 32'h3FA00000) ? "✓ PASS" : "✗ FAIL");
        $display("  f10 (FMAX): 0x%h %s", dut.dp.fprf.fp_regs[10],
                 (dut.dp.fprf.fp_regs[10] == 32'h40A00000) ? "✓ PASS" : "✗ FAIL");
        $display("========================================\n");
        
        #50;
        $finish;
    end

endmodule
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
        
        // Pre-cargar valores de prueba (valores normales ya presentes)
        fp_regs[1]  = 32'h40200000; // f1  = 2.5
        fp_regs[2]  = 32'h40400000; // f2  = 3.0
        fp_regs[3]  = 32'h3F800000; // f3  = 1.0
        fp_regs[4]  = 32'h40A00000; // f4  = 5.0
        
        // ===== EDGE CASES: ZEROS =====
        fp_regs[15] = 32'h00000000; // f15 = +0.0
        fp_regs[16] = 32'h80000000; // f16 = -0.0
        
        // ===== EDGE CASES: INFINITY =====
        fp_regs[17] = 32'h7F800000; // f17 = +Inf
        fp_regs[18] = 32'hFF800000; // f18 = -Inf
        
        // ===== EDGE CASES: NaN =====
        fp_regs[19] = 32'h7FC00000; // f19 = qNaN
        
        // ===== EDGE CASES: OVERFLOW =====
        fp_regs[20] = 32'h7F000000; // f20 = 1.7e38 (valor cercano al overflow)
        
        // ===== EDGE CASES: PRECISION =====
        fp_regs[21] = 32'h33800000; // f21 = 5.96e-8
        fp_regs[22] = 32'h4B800000; // f22 = 16777216.0
        
        // ===== SUBNORMALES =====
        fp_regs[23] = 32'h00000001; // f23 = min subnormal
        fp_regs[24] = 32'h007FFFFF; // f24 = max subnormal

        $display("[fp_regfile] Registros FP inicializados:");
        $display("  f1 = 0x%h", fp_regs[1]);
        $display("  f2 = 0x%h", fp_regs[2]);
        $display("  f3 = 0x%h", fp_regs[3]);
        $display("  f4 = 0x%h", fp_regs[4]);

        $display("\n  ===== VALORES NORMALES =====");
        $display("  f1  = 2.5             (0x40200000)");
        $display("  f2  = 3.0             (0x40400000)");
        $display("  f3  = 1.0             (0x3F800000)");
        $display("  f4  = 5.0             (0x40A00000)");

        $display("\n  ===== EDGE CASES: ZEROS =====");
        $display("  f15 = +0.0            (0x00000000)");
        $display("  f16 = -0.0            (0x80000000)");

        $display("\n  ===== EDGE CASES: INFINITY =====");
        $display("  f17 = +Inf            (0x7F800000)");
        $display("  f18 = -Inf            (0xFF800000)");

        $display("\n  ===== EDGE CASES: NaN =====");
        $display("  f19 = qNaN            (0x7FC00000)");

        $display("\n  ===== EDGE CASES: OVERFLOW =====");
        $display("  f20 = 1.7e38          (0x7F000000)");

        $display("\n  ===== EDGE CASES: PRECISION =====");
        $display("  f21 = 5.96e-8         (0x33800000)");
        $display("  f22 = 16777216.0      (0x4B800000)");

        $display("\n  ===== SUBNORMALES =====");
        $display("  f23 = min subnormal   (0x00000001)");
        $display("  f24 = max subnormal   (0x007FFFFF)");
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
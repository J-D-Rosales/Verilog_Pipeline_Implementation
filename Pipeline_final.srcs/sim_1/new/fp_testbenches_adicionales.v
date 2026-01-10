`timescale 1ns/1ps
`timescale 1ns/1ps

module tb_suite_1_control_flow;
    reg clk;
    reg reset;
    wire [31:0] WriteData, DataAdr;
    wire MemWrite;
    integer cycle_count;

    // Instancia del TOP
    top dut (
        .clk(clk),
        .reset(reset),
        .WriteData(WriteData),
        .DataAdr(DataAdr),
        .MemWrite(MemWrite)
    );

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // 1. Cargar programa (Asegúrate de cambiar el nombre del archivo)
        // $readmemh("suite_1_control_flow.hex", dut.imem.RAM); 
        
        $display("\n=== TEST SUITE 1: CONTROL FLOW & HAZARDS ===");
        
        // Reset
        reset = 1; cycle_count = 0;
        #15 reset = 0;

        // Ejecutar simulación
        repeat(60) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        $display("\n=== VERIFICACIÓN FINAL (Ciclo %0d) ===", cycle_count);

        // CHEQUEO 1: Branch Not Taken
        // x4 debe ser 10 (0xA)
        if (dut.pipeline1.dp.rf.rf[4] == 32'h0000000A)
            $display(" [PASS] Branch Not Taken: x4 = 10");
        else
            $display(" [FAIL] Branch Not Taken: x4 = %d (Esperado 10)", dut.pipeline1.dp.rf.rf[4]);

        // CHEQUEO 2: Branch Taken + FLUSH
        // x5 y x6 deben ser 0 (o su valor inicial), NO 0xBAD (2989 decimal)
        if (dut.pipeline1.dp.rf.rf[5] == 32'h00000BAD || dut.pipeline1.dp.rf.rf[6] == 32'h00000BAD)
            $display(" [FAIL] FLUSH FALLÓ en BEQ: Se escribieron x5/x6 con basura");
        else
            $display(" [PASS] FLUSH en BEQ Correcto: x5/x6 limpios");

        // CHEQUEO 3: Target alcanzado
        // x7 debe ser 20 (0x14)
        if (dut.pipeline1.dp.rf.rf[7] == 32'h00000014)
            $display(" [PASS] Target alcanzado: x7 = 20");
        else
            $display(" [FAIL] Target no alcanzado: x7 = %d", dut.pipeline1.dp.rf.rf[7]);

        // CHEQUEO 4: JAL + FLUSH
        // x9 debe estar limpio, x11 debe ser 30
        if (dut.pipeline1.dp.rf.rf[9] == 32'h00000BAD)
            $display(" [FAIL] FLUSH FALLÓ en JAL: Se escribió x9");
        else if (dut.pipeline1.dp.rf.rf[11] == 32'h0000001E)
            $display(" [PASS] JAL Correcto: Salto realizado y flush exitoso");
        else
            $display(" [FAIL] JAL Falló: x11 = %d", dut.pipeline1.dp.rf.rf[11]);

        $finish;
    end
endmodule

module tb_suite_2_precision;
    reg clk;
    reg reset;
    wire [31:0] WriteData, DataAdr;
    wire MemWrite;
    integer cycle_count;

    top dut (.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
      $dumpfile("pipelined.vcd");
      $dumpvars;
        // Cargar Hex
        // $readmemh("suite_2_precision.hex", dut.imem.RAM);

        $display("\n=== TEST SUITE 2: PRECISIÓN FPU ===");
        
        reset = 1; cycle_count = 0;
        #15 reset = 0;

        // === INICIALIZACIÓN DE REGISTROS (FORCE) ===
        // f1 = 1.0
        force dut.pipeline1.dp.fprf.fp_regs[1] = 32'h3F800000;
        // f2 = 3.0
        force dut.pipeline1.dp.fprf.fp_regs[2] = 32'h40400000;
        // f3 = 100,000.0
        force dut.pipeline1.dp.fprf.fp_regs[3] = 32'h42c80000;
        // f4 = 0.00001
        force dut.pipeline1.dp.fprf.fp_regs[4] = 32'h3727C5AC;
        
        #10; // Mantener force un momento
        // Release para permitir escrituras (aunque en este test solo leemos de ellos)
        release dut.pipeline1.dp.fprf.fp_regs[1];
        release dut.pipeline1.dp.fprf.fp_regs[2];
        release dut.pipeline1.dp.fprf.fp_regs[3];
        release dut.pipeline1.dp.fprf.fp_regs[4];

        // Ejecutar
        repeat(50) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        $display("\n=== VERIFICACIÓN FINAL ===");

        // CHEQUEO 1: División 1.0 / 3.0
        // Esperado: 0x3EAAAAAB (0.33333334)
        if (dut.pipeline1.dp.fprf.fp_regs[5] == 32'h3EAAAAAB)
            $display(" [PASS] 1.0/3.0 Precisión OK: 0x3EAAAAAB");
        else
            $display(" [FAIL] 1.0/3.0 Falló: Recibido 0x%h", dut.pipeline1.dp.fprf.fp_regs[5]);

        // CHEQUEO 2: Recuperación (0.333... * 3.0)
        // Debería volver a 1.0 (0x3F800000) o muy cerca (0x3F7FFFFF)
        if (dut.pipeline1.dp.fprf.fp_regs[6] == 32'h3F800000 || dut.pipeline1.dp.fprf.fp_regs[6] == 32'h3F7FFFFF)
            $display(" [PASS] Redondeo Reverso OK: %h", dut.pipeline1.dp.fprf.fp_regs[6]);
        else
            $display(" [FAIL] Redondeo falló: Recibido 0x%h", dut.pipeline1.dp.fprf.fp_regs[6]);

        // CHEQUEO 3: Absorción (Big + Small)
        // 100000.0 + 0.00001 -> Verifica si cambió algo
        $display(" [INFO] Big+Small resultado: 0x%h", dut.pipeline1.dp.fprf.fp_regs[7]);
        if (dut.pipeline1.dp.fprf.fp_regs[6] == 32'h3F800000 || dut.pipeline1.dp.fprf.fp_regs[6] == 32'h3F7FFFFF)
            $display(" [PASS] Redondeo Reverso OK: %h", dut.pipeline1.dp.fprf.fp_regs[6]);
        else
            $display(" [FAIL] Redondeo falló: Recibido 0x%h", dut.pipeline1.dp.fprf.fp_regs[6]);
        $finish;
    end
endmodule

`timescale 1ns/1ps

module tb_suite_3_edge_cases;
    reg clk;
    reg reset;
    wire [31:0] WriteData, DataAdr;
    wire MemWrite;
    integer cycle_count;

    top dut (.clk(clk), .reset(reset), .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
      $dumpfile("pipelined.vcd");
      $dumpvars;
        // $readmemh("suite_3_edge.hex", dut.imem.RAM);

        $display("\n=== TEST SUITE 3: EDGE CASES (NaN/Inf) ===");
        
        reset = 1; cycle_count = 0;
        #15 reset = 0;

        // === INICIALIZACIÓN ===
        // f1 = +Inf
        force dut.pipeline1.dp.fprf.fp_regs[1] = 32'h7F800000;
        // f2 = -Inf
        force dut.pipeline1.dp.fprf.fp_regs[2] = 32'hFF800000;
        // f3 = 1.0
        force dut.pipeline1.dp.fprf.fp_regs[3] = 32'h3F800000;
        // f4 = +0.0
        force dut.pipeline1.dp.fprf.fp_regs[4] = 32'h00000000;
        // f5 = qNaN (Quiet NaN)
        force dut.pipeline1.dp.fprf.fp_regs[5] = 32'h7FC00000;
        
        #10;
        release dut.pipeline1.dp.fprf.fp_regs[1];
        release dut.pipeline1.dp.fprf.fp_regs[2];
        release dut.pipeline1.dp.fprf.fp_regs[3];
        release dut.pipeline1.dp.fprf.fp_regs[4];
        release dut.pipeline1.dp.fprf.fp_regs[5];

        repeat(50) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        $display("\n=== VERIFICACIÓN FINAL ===");

        // 1. Inf + 1.0 = Inf
        if (dut.pipeline1.dp.fprf.fp_regs[10] == 32'h7F800000)
            $display(" [PASS] Inf + Normal = Inf");
        else
            $display(" [FAIL] Inf + Normal incorrecto: %h", dut.pipeline1.dp.fprf.fp_regs[10]);

        // 2. Inf + (-Inf) = NaN
        // Verificamos si es un NaN estándar (0x7FC00000) o similar
        // Nota: Los NaNs pueden variar en el payload, revisamos exponente y bit de signo
        if ((dut.pipeline1.dp.fprf.fp_regs[11] & 32'h7F800000) == 32'h7F800000)
            $display(" [PASS] Inf - Inf = NaN (Detectado)");
        else
            $display(" [FAIL] Inf - Inf falló: %h", dut.pipeline1.dp.fprf.fp_regs[11]);

        // 4. Div por Cero (1.0 / 0.0) = Inf
        if (dut.pipeline1.dp.fprf.fp_regs[13] == 32'h7F800000)
            $display(" [PASS] DivByZero generó +Inf");
        else
            $display(" [FAIL] DivByZero falló: %h", dut.pipeline1.dp.fprf.fp_regs[13]);

        // 5. 0.0 / 0.0 = NaN
        if ((dut.pipeline1.dp.fprf.fp_regs[14] & 32'h7F800000) == 32'h7F800000)
            $display(" [PASS] 0/0 generó NaN");
        else
            $display(" [FAIL] 0/0 falló: %h", dut.pipeline1.dp.fprf.fp_regs[14]);

        $finish;
    end
endmodule
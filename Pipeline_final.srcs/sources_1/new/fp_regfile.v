module fp_regfile(
    input clk,
    input we3,              // Write enable
    input [4:0] a1, a2, a3, // Direcciones rs1, rs2, rd
    input [31:0] wd3,       // Dato a escribir
    output [31:0] rd1, rd2  // Datos leídos
);
    reg [31:0] fp_regs [31:0]; // 32 registros flotantes
    //Inicialización de registros a cero
  	initial begin
        integer i;
        for (i = 0; i < 32; i = i + 1) begin
            fp_regs[i] = 32'h00000000;
        end
    end
    // Lectura asíncrona
    assign rd1 = (a1 != 0) ? fp_regs[a1] : 0;
    assign rd2 = (a2 != 0) ? fp_regs[a2] : 0;
    
    // Escritura síncrona
    always @(posedge clk) begin //ver 
        if (we3 && a3 != 0)
            fp_regs[a3] <= wd3;
    end
endmodule
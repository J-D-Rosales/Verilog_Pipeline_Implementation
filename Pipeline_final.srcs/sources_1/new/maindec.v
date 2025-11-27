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
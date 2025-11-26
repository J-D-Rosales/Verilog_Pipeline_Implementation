module hazard_unit(
    input [4:0] Rs1E, Rs2E, Rs1D, Rs2D, RdM, RdW, RdE,
    input RegWriteM, RegWriteW,
    input FPRegWriteM, FPRegWriteW,
    input ResultSrcE_bit0, PCSrcE,
    
    output reg [1:0] ForwardAE, ForwardBE,       // ALU entera
    output reg [1:0] ForwardAE_FP, ForwardBE_FP, // FPU
    output wire StallF, StallD, FlushE, FlushD
);

// Forwarding ENTERO
always @(*) begin
    if ((Rs1E == RdM) && RegWriteM && !FPRegWriteM && (Rs1E != 0))
        ForwardAE = 2'b10;
    else if ((Rs1E == RdW) && RegWriteW && !FPRegWriteW && (Rs1E != 0))
        ForwardAE = 2'b01;
    else
        ForwardAE = 2'b00;

    if ((Rs2E == RdM) && RegWriteM && !FPRegWriteM && (Rs2E != 0))
        ForwardBE = 2'b10;
    else if ((Rs2E == RdW) && RegWriteW && !FPRegWriteW && (Rs2E != 0))
        ForwardBE = 2'b01;
    else
        ForwardBE = 2'b00;
end

// Forwarding FP (solo considera writes FP)
always @(*) begin
    if ((Rs1E == RdM) && FPRegWriteM && (Rs1E != 0))
        ForwardAE_FP = 2'b10;
    else if ((Rs1E == RdW) && FPRegWriteW && (Rs1E != 0))
        ForwardAE_FP = 2'b01;
    else
        ForwardAE_FP = 2'b00;

    if ((Rs2E == RdM) && FPRegWriteM && (Rs2E != 0))
        ForwardBE_FP = 2'b10;
    else if ((Rs2E == RdW) && FPRegWriteW && (Rs2E != 0))
        ForwardBE_FP = 2'b01;
    else
        ForwardBE_FP = 2'b00;
end

// Stalls y Flushes (sin cambios)
wire lwStall = (ResultSrcE_bit0 === 1'b1) ? ((Rs1D == RdE) | (Rs2D == RdE)) : 1'b0;
assign StallF = lwStall;
assign StallD = lwStall;
assign FlushE = lwStall | (PCSrcE === 1'b1);
assign FlushD = (PCSrcE === 1'b1);

endmodule
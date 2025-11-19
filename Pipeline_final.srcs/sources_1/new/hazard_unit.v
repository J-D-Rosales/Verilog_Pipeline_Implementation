`timescale 1ns / 1ps

module hazard_unit(
    input [4:0] Rs1E, Rs2E, 
    input [4:0] Rs1D, Rs2D, 
    input [4:0] RdM, RdW, RdE,
    input RegWriteM, RegWriteW,
    input ResultSrcE_bit0, 
    input PCSrcE,
    
    output reg [1:0] ForwardAE, ForwardBE,
    output wire StallF, StallD, FlushE, FlushD
    );
    
    // Forwarding
    always @(*) begin
        if      ((Rs1E == RdM) && RegWriteM && (Rs1E != 0)) ForwardAE = 2'b10;
        else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 0)) ForwardAE = 2'b01;
        else                                                ForwardAE = 2'b00;

        if      ((Rs2E == RdM) && RegWriteM && (Rs2E != 0)) ForwardBE = 2'b10;
        else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 0)) ForwardBE = 2'b01;
        else                                                ForwardBE = 2'b00;
    end

    // STALLS Y FLUSHES BLINDADOS (ANTI-X)
    // Usamos (=== 1'b1) para que si la señal es 'x', se trate como '0'
    
    wire lwStall;
    assign lwStall = (ResultSrcE_bit0 === 1'b1) ? ((Rs1D == RdE) | (Rs2D == RdE)) : 1'b0;
    
    assign StallF = lwStall;
    assign StallD = lwStall;
    
    // Si PCSrcE es 'x', NO hacemos flush. Solo flush si es 1 confirmado.
    assign FlushE = lwStall | (PCSrcE === 1'b1); 
    assign FlushD = (PCSrcE === 1'b1); 

endmodule
// fpu_div_fp32_vivado.v
// FP32 division combinational

module fpu_div_fp32_vivado (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result,
    output wire [4:0] flags
);

    localparam [31:0] QNAN_CANON = {1'b0, 8'hFF, 1'b1, 22'd0};
    localparam BIAS = 127;

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

    wire sOUT_c = sA ^ sB;

    wire [23:0] MA_c = A_isSub ? {1'b0, fA} : {(eA!=8'd0), fA};
    wire [23:0] MB_c = B_isSub ? {1'b0, fB} : {(eB!=8'd0), fB};

    function signed [12:0] unbias;
        input [7:0] E;
        begin
            if (E==8'd0) unbias = 13'sd1 - 13'sd127;  // -126
            else         unbias = $signed({5'b0,E}) - 13'sd127;
        end
    endfunction
    wire signed [12:0] eA_unb_c = unbias(eA);
    wire signed [12:0] eB_unb_c = unbias(eB);

    reg        sp_is_special_c;
    reg [31:0] sp_word_c;
    reg [4:0]  sp_flags_c;

    always @* begin
        sp_is_special_c = 1'b0;
        sp_word_c       = 32'b0;
        sp_flags_c      = 5'b0;

        if (A_isNaN || B_isNaN || (A_isZero && B_isZero) || (A_isInf && B_isInf)) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b1_0000;    // invalid
            sp_word_c       = QNAN_CANON;
        end
        else if (B_isZero && !(A_isZero || A_isNaN || A_isInf)) begin
            sp_is_special_c = 1'b1;
            sp_flags_c      = 5'b0_1000;    // div_by_zero
            sp_word_c       = {sOUT_c, 8'hFF, 23'b0};
        end
        else if (A_isInf && !B_isInf) begin
            sp_is_special_c = 1'b1;
            sp_word_c       = {sOUT_c, 8'hFF, 23'b0};
        end
        else if (A_isZero && B_isInf) begin
            sp_is_special_c = 1'b1;
            sp_word_c       = {sOUT_c, 8'd0, 23'd0};
        end
    end

    wire sOUT_e1_input = sOUT_c;
    wire [23:0] MA_e1_input = MA_c;
    wire [23:0] MB_e1_input = MB_c;
    wire signed [12:0] eDIFF0_e1_input = eA_unb_c - eB_unb_c;
    wire sp_is_special_e1_input = sp_is_special_c;
    wire [31:0] sp_word_e1_input = sp_word_c;
    wire [4:0] sp_flags_e1_input = sp_flags_c;

    reg  [25:0] Q_scaled_c;
    reg         sticky_rem_c;
    reg  signed [12:0] eDIFF1_c;

    reg [49:0] numer;
    reg [23:0] denom;

    always @* begin
        Q_scaled_c    = 26'd0;
        sticky_rem_c  = 1'b0;
        eDIFF1_c      = eDIFF0_e1_input;
        denom         = MB_e1_input;

        if (MB_e1_input == 24'd0) begin
            Q_scaled_c   = 26'd0;
            sticky_rem_c = 1'b0;
            eDIFF1_c     = eDIFF0_e1_input;
        end
        else if (MA_e1_input >= MB_e1_input) begin
            numer = {MA_e1_input, 25'd0};
            Q_scaled_c = numer / denom;
            sticky_rem_c = ( (numer % denom) != 0 );
            eDIFF1_c = eDIFF0_e1_input;
        end
        else begin
            numer = {MA_e1_input, 26'd0};
            Q_scaled_c = numer / denom;
            sticky_rem_c = ( (numer % denom) != 0 );
            eDIFF1_c = eDIFF0_e1_input - 1;
        end
    end

    wire sOUT_e2_input = sOUT_e1_input;
    wire [25:0] Q_scaled_e2_input = Q_scaled_c;
    wire S_e2_input = sticky_rem_c;
    wire signed [12:0] eDIFF1_e2_input = eDIFF1_c;
    wire sp_is_special_e2_input = sp_is_special_e1_input;
    wire [31:0] sp_word_e2_input = sp_word_e1_input;
    wire [4:0] sp_flags_e2_input = sp_flags_e1_input;

    wire [22:0] frac_pre_c2 = Q_scaled_e2_input[24:2];
    wire        G_c2        = Q_scaled_e2_input[1];
    wire        R_c2        = Q_scaled_e2_input[0];
    wire        S_c2        = S_e2_input;
    wire        roundUp_c2  = G_c2 && (R_c2 || S_c2 || frac_pre_c2[0]);

    wire [23:0] frac_with_hidden_c2 = {Q_scaled_e2_input[25], frac_pre_c2};
    wire [24:0] rounded_c2 = {1'b0, frac_with_hidden_c2} + (roundUp_c2 ? 25'd1 : 25'd0);

    reg  [23:0] frac_fin_c2;
    reg  signed [12:0] eSUM2_c2;
    always @* begin
        if (rounded_c2[24]) begin
            frac_fin_c2 = rounded_c2[24:1];
            eSUM2_c2    = eDIFF1_e2_input + 1;
        end else begin
            frac_fin_c2 = rounded_c2[23:0];
            eSUM2_c2    = eDIFF1_e2_input;
        end
    end

    wire signed [13:0] E_biased_c2     = eSUM2_c2 + 13'sd127;
    wire        overflow_c2            = (E_biased_c2 > 13'sd254);
    wire        under_biased_nonpos_c2 = (E_biased_c2 <= 0);
    wire        inexact_rnd_c2         = (G_c2 | R_c2 | S_c2);

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
            normal_word_c2     = {sOUT_e2_input, 8'hFF, 23'b0};
            normal_flags_c2[2] = 1'b1; // overflow
            normal_flags_c2[0] = 1'b1; // inexact
        end
        else if (under_biased_nonpos_c2) begin
            shift_den = (1 - E_biased_c2);
            if (shift_den >= 24) begin
                normal_word_c2     = {sOUT_e2_input, 8'd0, 23'd0};
                normal_flags_c2[1] = 1'b1; // underflow
                lost_bits = |frac_fin_c2;
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end else begin
                mask24 = ((24'h1 << shift_den) - 1);
                frac_den = frac_fin_c2 >> shift_den;
                normal_word_c2     = {sOUT_e2_input, 8'd0, frac_den[22:0]};
                normal_flags_c2[1] = 1'b1; // underflow
                lost_bits = |(frac_fin_c2 & mask24);
                normal_flags_c2[0] = inexact_rnd_c2 | lost_bits;
            end
        end
        else begin
            normal_word_c2     = {sOUT_e2_input, E_biased_c2[7:0], frac_fin_c2[22:0]};
            normal_flags_c2[0] = inexact_rnd_c2;
        end
    end

    assign result = sp_is_special_e2_input ? sp_word_e2_input  : normal_word_c2;
    assign flags  = sp_is_special_e2_input ? sp_flags_e2_input : normal_flags_c2;

endmodule

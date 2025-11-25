// fpu_top.v
// Top-level FPU (FP32) combinational ALU
// Extracted from edaplaground.v

module fpu_top (
  input  wire [31:0] op_a,
  input  wire [31:0] op_b,
  input  wire [2:0]  op_code,
  input  wire        round_mode,
  output wire [31:0] result,
  output wire [4:0]  flags
);

  parameter OP_ADD = 3'b000;
  parameter OP_SUB = 3'b001;
  parameter OP_MUL = 3'b010;
  parameter OP_DIV = 3'b011;
  parameter OP_MIN = 3'b100;
  parameter OP_MAX = 3'b101;

  wire [31:0] y_add, y_mul, y_div, y_minmax;
  wire [4:0]  f_add, f_mul, f_div, f_minmax;

  wire op_sel_addsub = (op_code == OP_SUB) ? 1'b1 : 1'b0;
  
  fpu_add_fp32_vivado u_addsub (
    .op_sel(op_sel_addsub),
    .a(op_a), 
    .b(op_b),
    .result(y_add), 
    .flags(f_add)
  );

  fpu_mul_fp32_vivado u_mul (
    .a(op_a), 
    .b(op_b),
    .result(y_mul), 
    .flags(f_mul)
  );

  fpu_div_fp32_vivado u_div (
    .a(op_a), 
    .b(op_b),
    .result(y_div), 
    .flags(f_div)
  );

  fpu_minmax_fp32_vivado u_minmax_inst (
    .a(op_a), 
    .b(op_b),
    .is_max((op_code == OP_MAX) ? 1'b1 : 1'b0),
    .result(y_minmax), 
    .flags(f_minmax)
  );

  reg [31:0] y_sel;
  reg [4:0]  f_sel;
  
  always @(*) begin
    case (op_code)
      OP_ADD: begin y_sel = y_add;    f_sel = f_add; end
      OP_SUB: begin y_sel = y_add;    f_sel = f_add; end
      OP_MUL: begin y_sel = y_mul;    f_sel = f_mul; end
      OP_DIV: begin y_sel = y_div;    f_sel = f_div; end
      OP_MIN: begin y_sel = y_minmax; f_sel = f_minmax; end
      OP_MAX: begin y_sel = y_minmax; f_sel = f_minmax; end
      default: begin y_sel = 32'd0; f_sel = 5'd0; end
    endcase
  end

  assign result = y_sel;
  assign flags  = f_sel;

endmodule

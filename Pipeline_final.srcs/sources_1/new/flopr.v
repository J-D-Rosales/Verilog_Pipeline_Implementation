module flopr (input  clk, reset,en,
               input  [WIDTH-1:0] d, 
               output reg [WIDTH-1:0] q);

  parameter WIDTH = 8;


    always @(posedge clk or posedge reset)
            if (reset) q <= 0;
            else if (en) q <= d;
  
endmodule
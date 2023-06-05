module COL_DIST
(
  c,
  c1,
  c2,
  c3,
  d1,
  d2,
  d3
);

input [23:0] c, c1, c2, c3;
output [17:0] d1, d2, d3;

wire [7:0] d1_r, d1_g, d1_b, d2_r, d2_g, d2_b, d3_r, d3_g, d3_b;
wire [7:0] red, green, blue;

assign red = c[23:16];
assign green = c[15:8];
assign blue = c[7:0];

assign d1_r = c1[23:16];
assign d1_g = c1[15:8];
assign d1_b = c1[7:0];

assign d2_r = c2[23:16];
assign d2_g = c2[15:8];
assign d2_b = c2[7:0];

assign d3_r = c3[23:16];
assign d3_g = c3[15:8];
assign d3_b = c3[7:0];

assign d1 = (d1_r > red ? d1_r - red : red - d1_r)**2 + (d1_g > green ? d1_g - green : green - d1_g)**2 + (d1_b > blue ? d1_b - blue : blue - d1_b)**2; 
assign d2 = (d2_r > red ? d2_r - red : red - d2_r)**2 + (d2_g > green ? d2_g - green : green - d2_g)**2 + (d2_b > blue ? d2_b - blue : blue - d2_b)**2; 
assign d3 = (d3_r > red ? d3_r - red : red - d3_r)**2 + (d3_g > green ? d3_g - green : green - d3_g)**2 + (d3_b > blue ? d3_b - blue : blue - d3_b)**2; 

endmodule


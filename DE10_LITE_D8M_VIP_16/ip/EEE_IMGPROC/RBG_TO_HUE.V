module RGB_TO_HUE(
  red,
  green,
  blue,
  hue,
  saturation,
  value
);

input [7:0] red, green, blue;
output [7:0] hue, saturation, value;


reg [1:0] max_colour; // 00 is red, 01 green, 10 blue
reg [7:0] max_value, min_value, diff, tmp_hue;
wire [7:0] intermediate;


// find the max, min values and which colour is max
// compute differences so they are always positive
always@(*) begin
  if (red > green && red > blue) begin
    max_colour = 2'b00;
    max_value = red;
    if (blue > green) begin
      min_value = green;
      diff = blue - green;
    end
    else begin
      min_value = blue;
      diff = green - blue;
    end
  end
  else if (blue > green) begin
    max_colour = 2'b10;
    max_value = blue;
    if (red > green) begin
      min_value = green;
      diff = red - green;
    end
    else begin
      min_value = red;
      diff = green - red;
    end
  end
  else begin
    max_colour = 2'b01;
    max_value = green;
    if (red > blue) begin
      min_value = blue;
      diff = red - blue;
    end
    else begin 
      min_value = red;
      diff = blue - red;
    end
  end
end

assign intermediate = (43 * diff) / (max_value - min_value);


always@(*) begin
  case(max_colour)
    2'b00: begin // red is max
      tmp_hue = intermediate;
    end
    2'b01: begin // green is max
      tmp_hue = 85 + intermediate;
    end
    2'b10: begin // blue is max
      tmp_hue = 171 + intermediate;
    end
    default: tmp_hue = 0; // should never trigger hopefully
  endcase
end

assign hue = tmp_hue;
assign saturation = (max_value - min_value) / max_value; // always the same regardless of which colour is max
assign value = max_value;

endmodule
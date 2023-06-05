module EEE_IMGPROC(
	// global clock & reset
	clk,
	reset_n,
	
	// mm slave
	s_chipselect,
	s_read,
	s_write,
	s_readdata,
	s_writedata,
	s_address,

	// stream sink
	sink_data,
	sink_valid,
	sink_ready,
	sink_sop,
	sink_eop,
	
	// streaming source
	source_data,
	source_valid,
	source_ready,
	source_sop,
	source_eop,
	
	// conduit
	mode
	
);


// global clock & reset
input	clk;
input	reset_n;

// mm slave
input							s_chipselect;
input							s_read;
input							s_write;
output	reg	[31:0]	s_readdata;
input	[31:0]				s_writedata;
input	[2:0]					s_address;


// streaming sink
input	[23:0]            	sink_data;
input								sink_valid;
output							sink_ready;
input								sink_sop;
input								sink_eop;

// streaming source
output	[23:0]			  	   source_data;
output								source_valid;
input									source_ready;
output								source_sop;
output								source_eop;

// conduit export
input                         mode;

////////////////////////////////////////////////////////////////////////
//
parameter IMAGE_W = 11'd640;
parameter IMAGE_H = 11'd480;
parameter MESSAGE_BUF_MAX = 256;
parameter MSG_INTERVAL = 6;
parameter BB_COL = 24'h00ff00;
parameter COL_DETECT_DEFAULT = 24'hFF0000; // detect red
parameter COL_DETECT_THRESH_DEF = 17'hFFFF;
parameter AVG_FRAMES = 10;
parameter CROSSHAIR_COLOUR = 24'h00ff00; 
parameter MIN_AVG_NUM = 20;

wire [7:0]   red, green, blue, grey;
wire [7:0]   red_out, green_out, blue_out;

wire         sop, eop, in_valid, out_ready;
////////////////////////////////////////////////////////////////////////

wire [17:0] dist_red, dist_yellow, dist_blue;

COL_DIST col_distance(
  .c({red, green, blue}),
  .c1(des_red),
  .c2(des_yellow),
  .c3(des_blue),
  .d1(dist_red),
  .d2(dist_yellow),
  .d3(dist_blue)
);

wire [1:0] detected_colour;
assign detected_colour = ((dist_red < dist_yellow) && (dist_red < dist_blue)) ? 2'b00 : ((dist_yellow < dist_blue) ? 2'b01 : 2'b10);
// determine if colour matches or not
wire colour_detect;
assign colour_detect = (dist_red < red_thresh) | (dist_yellow < yellow_thresh) | (dist_blue < blue_thresh);

// Show bounding box
wire [23:0] new_image;
wire c1_active;
wire c2_active;
wire c3_active;

// Highlight detected areas
wire [23:0] col_high;	
assign grey = green[7:1] + red[7:2] + blue[7:2]; //Grey = green/2 + red/4 + blue/4
assign col_high = colour_detect ? (detected_colour == 2'b00 ? des_red : (detected_colour == 2'b01 ? des_yellow : des_blue) ) : {grey, grey, grey}; 

// Find boundary of cursor box
// assign bb_active = (((x == left) | (x == right)) & ( y <= bottom && y >= top) ) | ( ((y == top) | (y == bottom)) & ( x <= right && x >= left) ); // top and bottom are flipped for some reason??
assign c1_active = ( x == c1_x ) | ( y == c1_y);
assign c2_active = ( x == c2_x ) | ( y == c2_y);
assign c3_active = ( x == c3_x ) | ( y == c3_y);

assign new_image = c1_active ? 24'hFF00FF : ( c2_active ? 24'h00FF00 : ( c3_active ? 24'h00FFFF : col_high ));

// Switch output pixels depending on mode switch
// Don't modify the start-of-packet word - it's a packet discriptor
// Don't modify data in non-video packets
assign {red_out, green_out, blue_out} = (mode & ~sop & packet_video) ? new_image : {red,green,blue};



// always@(*) begin
//   if (colour_detect) begin
//     if () begin
//       detected_colour <= 2'b00; // red colour detected
//       // col_high <= des_red;
//     end
//     else if (dist_yellow < dist_blue) begin
//       detected_colour <= 2'b01; // yellow colour detected
//       // col_high <= des_yellow;
//     end
//     else begin
//       detected_colour <= 2'b10; // blue colour detected
//       // col_high <= des_blue;
//     end
//   end
// end


//Count valid pixels to get the image coordinates. Reset and detect packet type on Start of Packet.
reg [10:0] x, y;
reg packet_video;
always@(posedge clk) begin
	if (sop) begin
		x <= 11'h0;
		y <= 11'h0;
		packet_video <= (blue[3:0] == 3'h0);
	end
	else if (in_valid) begin
		if (x == IMAGE_W-1) begin
			x <= 11'h0;
			y <= y + 11'h1;
		end
		else begin
			x <= x + 11'h1;
		end
	end
end

//Find first and last red pixels
// reg [10:0] x_min, y_min, x_max, y_max;
reg [31:0] sum1_x, sum1_y, sum2_x, sum2_y, sum3_x, sum3_y; // assign a bunch of bits since the sum can become quite large
reg [20:0] num_highs1, num_highs2, num_highs3; // numbers of detected pixels

//Process bounding box and centering at the end of the frame.
reg [1:0] msg_state;
reg [10:0] left, right, top, bottom;
reg [7:0] frame_count;
reg [10:0] c1_x, c1_y, c2_x, c2_y, c3_x, c3_y;
reg [3:0] frame_averaging;

always@(posedge clk) begin
	if (colour_detect & in_valid) begin	//Update bounds when the pixel is red
    
    if (detected_colour == 2'b00) begin
      num_highs1 <= num_highs1 + 1; // increment number of total detected pixels
      // increment sums
      sum1_x <= sum1_x + x;
      sum1_y <= sum1_y + y;
    end
    else if (detected_colour == 2'b01) begin
      num_highs2 <= num_highs2 + 1;
      sum2_x <= sum2_x + x;
      sum2_y <= sum2_y + y;
    end
    else if (detected_colour == 2'b10) begin
      num_highs3 <= num_highs3 + 1;
      sum3_x <= sum3_x + x;
      sum3_y <= sum3_y + y;
    end

		// if (x < x_min) x_min <= x;
		// if (x > x_max) x_max <= x;
		// if (y < y_min) y_min <= y;
		// y_max <= y;	// because y is always increasing
	end
	// if (sop & in_valid) begin	//Reset bounds on start of packet
	// 	x_min <= IMAGE_W-11'h1;
	// 	x_max <= 0;
	// 	y_min <= IMAGE_H-11'h1;
	// 	y_max <= 0;
	// end

	if (eop & in_valid & packet_video) begin  //Ignore non-video packets
		
		//Latch edges for display overlay on next frame
		// left <= x_min;
		// right <= x_max;
		// top <= y_min;
		// bottom <= y_max;
		
    if (frame_averaging >= AVG_FRAMES) begin
      if (num_highs1 >= MIN_AVG_NUM) begin
        c1_x <= sum1_x / num_highs1;
        c1_y <= sum1_y / num_highs1;
        sum1_x <= 0;
        sum1_y <= 0;
      end
      num_highs1 <= 0;

      if (num_highs2 >= MIN_AVG_NUM) begin
        c2_x <= sum2_x / num_highs2;
        c2_y <= sum2_y / num_highs2;
        sum2_x <= 0;
        sum2_y <= 0;
      end
      num_highs2 <= 0;

      if (num_highs3 >= MIN_AVG_NUM) begin
        c3_x <= sum3_x / num_highs3;
        c3_y <= sum3_y / num_highs3;
        sum3_x <= 0;
        sum3_y <= 0;
      end
      num_highs3 <= 0;

      frame_averaging <= 0;
    end
    else frame_averaging <= frame_averaging + 1;
		
		//Start message writer FSM once every MSG_INTERVAL frames, if there is room in the FIFO
		frame_count <= frame_count - 1;
		
		if (frame_count == 0 && msg_buf_size < MESSAGE_BUF_MAX - 3) begin
			msg_state <= 2'b01;
			frame_count <= MSG_INTERVAL-1;
		end
	end
	
	//Cycle through message writer states once started
	if (msg_state != 2'b00) msg_state <= msg_state + 2'b01;

end
	
//Generate output messages for CPU
reg [31:0] msg_buf_in; 
wire [31:0] msg_buf_out;
reg msg_buf_wr;
wire msg_buf_rd, msg_buf_flush;
wire [7:0] msg_buf_size;
wire msg_buf_empty;

`define RED_BOX_MSG_ID "RBB"

always@(*) begin	//Write words to FIFO as state machine advances
	case(msg_state)
		2'b00: begin
			msg_buf_in = 32'b0;
			msg_buf_wr = 1'b0;
		end
		2'b01: begin
			msg_buf_in = `RED_BOX_MSG_ID;	//Message ID
			msg_buf_wr = 1'b1;
		end
		2'b10: begin
			// msg_buf_in = {5'b0, x_min, 5'b0, y_min};	//Top left coordinate
			msg_buf_wr = 1'b1;
		end
		2'b11: begin
			// msg_buf_in = {5'b0, x_max, 5'b0, y_max}; //Bottom right coordinate
			msg_buf_wr = 1'b1;
		end
	endcase
end


//Output message FIFO
MSG_FIFO	MSG_FIFO_inst (
	.clock (clk),
	.data (msg_buf_in),
	.rdreq (msg_buf_rd),
	.sclr (~reset_n | msg_buf_flush),
	.wrreq (msg_buf_wr),
	.q (msg_buf_out),
	.usedw (msg_buf_size),
	.empty (msg_buf_empty)
	);


//Streaming registers to buffer video signal
STREAM_REG #(.DATA_WIDTH(26)) in_reg (
	.clk(clk),
	.rst_n(reset_n),
	.ready_out(sink_ready),
	.valid_out(in_valid),
	.data_out({red,green,blue,sop,eop}),
	.ready_in(out_ready),
	.valid_in(sink_valid),
	.data_in({sink_data,sink_sop,sink_eop})
);

STREAM_REG #(.DATA_WIDTH(26)) out_reg (
	.clk(clk),
	.rst_n(reset_n),
	.ready_out(out_ready),
	.valid_out(source_valid),
	.data_out({source_data,source_sop,source_eop}),
	.ready_in(source_ready),
	.valid_in(in_valid),
	.data_in({red_out, green_out, blue_out, sop, eop})
);


/////////////////////////////////
/// Memory-mapped port		 /////
/////////////////////////////////

// Addresses
`define REG_STATUS    			0
`define READ_MSG    				1
`define READ_ID    				2
`define REG_BBCOL					3

//Status register bits
// 31:16 - unimplemented
// 15:8 - number of words in message buffer (read only)
// 7:5 - unused
// 4 - flush message buffer (write only - read as 0)
// 3:0 - unused


// Process write

reg  [7:0]   reg_status;
reg [17:0]  red_thresh, yellow_thresh, blue_thresh;
reg [23:0]  des_red, des_yellow, des_blue;

always @ (posedge clk)
begin
	if (~reset_n)
	begin
		reg_status <= 8'b0;

    des_red <= COL_DETECT_DEFAULT;
    des_yellow <= COL_DETECT_DEFAULT;
    des_blue <= COL_DETECT_DEFAULT;

    red_thresh <= COL_DETECT_THRESH_DEF;
    yellow_thresh <= COL_DETECT_THRESH_DEF;
    blue_thresh <= COL_DETECT_THRESH_DEF;
	end
	else begin
		if(s_chipselect & s_write) begin
		   if      (s_address == `REG_STATUS)	reg_status <= s_writedata[7:0];
		   if      (s_address == `REG_BBCOL) begin
          if (s_writedata[31:29] == 3'b100) red_thresh <= s_writedata[17:0]; // update threshold
          if (s_writedata[31:29] == 3'b101) yellow_thresh <= s_writedata[17:0]; 
          if (s_writedata[31:29] == 3'b110) blue_thresh <= s_writedata[17:0]; // update threshold

          if (s_writedata[31:29] == 3'b000) des_red <= s_writedata[23:0]; // update threshold
          if (s_writedata[31:29] == 3'b001) des_yellow <= s_writedata[23:0]; // update threshold
          if (s_writedata[31:29] == 3'b010) des_blue <= s_writedata[23:0]; // update threshold
       end
		end
	end
end


//Flush the message buffer if 1 is written to status register bit 4
assign msg_buf_flush = (s_chipselect & s_write & (s_address == `REG_STATUS) & s_writedata[4]);


// Process reads
reg read_d; //Store the read signal for correct updating of the message buffer

// Copy the requested word to the output port when there is a read.
always @ (posedge clk)
begin
   if (~reset_n) begin
	   s_readdata <= {32'b0};
		read_d <= 1'b0;
	end
	
	else if (s_chipselect & s_read) begin
		if   (s_address == `REG_STATUS) s_readdata <= {16'b0,msg_buf_size,reg_status};
		if   (s_address == `READ_MSG) s_readdata <= {msg_buf_out};
		if   (s_address == `READ_ID) s_readdata <= 32'h1234EEE2;
		// if   (s_address == `REG_BBCOL) s_readdata <= {8'h0, bb_col};
	end
	
	read_d <= s_read;
end

//Fetch next word from message buffer after read from READ_MSG
assign msg_buf_rd = s_chipselect & s_read & ~read_d & ~msg_buf_empty & (s_address == `READ_MSG);
						


endmodule


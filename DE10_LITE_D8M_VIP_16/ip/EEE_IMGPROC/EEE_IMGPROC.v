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

wire [7:0]   red, green, blue, grey;
wire [7:0]   red_out, green_out, blue_out;

wire         sop, eop, in_valid, out_ready;
////////////////////////////////////////////////////////////////////////

// compute distances from desired colour
wire [7:0] d_red, d_blue, d_green;

// compute absolute distances between each value of RGB 
assign d_red = {des_colour[23:16]} > red ? {des_colour[23:16]} - red : red - {des_colour[23:16]};
assign d_green = {des_colour[15:8]} > green ? {des_colour[15:8]} - green : green - {des_colour[15:8]};
assign d_blue = {des_colour[7:0]} > blue ? {des_colour[7:0]} - blue : blue - {des_colour[7:0]};


// find combined distance from desired colour
wire [17:0] distance_from_col; // 18 bits becasue the max value is 255^2 * 3
assign distance_from_col = (d_red * d_red) + (d_blue * d_blue) + (d_green * d_green);


// determine if colour matches or not
wire colour_detect;
assign colour_detect = (distance_from_col < col_detect_thresh);


// Highlight detected areas
wire [23:0] col_high;	
assign grey = green[7:1] + red[7:2] + blue[7:2]; //Grey = green/2 + red/4 + blue/4

assign col_high = colour_detect ? des_colour : {grey, grey, grey}; 

// Show bounding box
wire [23:0] new_image;
wire bb_active;
wire cursor_active;


// Find boundary of cursor box
assign bb_active = (((x == left) | (x == right)) & ( y <= bottom && y >= top) ) | ( ((y == top) | (y == bottom)) & ( x <= right && x >= left) ); // top and bottom are flipped for some reason??
assign cursor_active = ( x == centre_x ) | ( y == centre_y);

assign new_image = (bb_active | cursor_active) ? (cursor_active ? CROSSHAIR_COLOUR : BB_COL) : col_high;

// Switch output pixels depending on mode switch
// Don't modify the start-of-packet word - it's a packet discriptor
// Don't modify data in non-video packets
assign {red_out, green_out, blue_out} = (mode & ~sop & packet_video) ? new_image : {red,green,blue};

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
reg [10:0] x_min, y_min, x_max, y_max;
reg [31:0] sum_x, sum_y; // assign a bunch of bits since the sum can become quite large
reg [20:0] num_highs; // numbers of detected pixels

//Process bounding box and centering at the end of the frame.
reg [1:0] msg_state;
reg [10:0] left, right, top, bottom;
reg [7:0] frame_count;
reg [10:0] centre_x, centre_y;
reg [3:0] frame_averaging;

always@(posedge clk) begin
	if (colour_detect & in_valid) begin	//Update bounds when the pixel is red
    num_highs <= num_highs + 1; // increment number of total detected pixels
    // increment sums
    sum_x <= sum_x + x;
    sum_y <= sum_y + y;

		if (x < x_min) x_min <= x;
		if (x > x_max) x_max <= x;
		if (y < y_min) y_min <= y;
		y_max <= y;	// because y is always increasing
	end
	if (sop & in_valid) begin	//Reset bounds on start of packet
		x_min <= IMAGE_W-11'h1;
		x_max <= 0;
		y_min <= IMAGE_H-11'h1;
		y_max <= 0;
	end

	if (eop & in_valid & packet_video) begin  //Ignore non-video packets
		
		//Latch edges for display overlay on next frame
		left <= x_min;
		right <= x_max;
		top <= y_min;
		bottom <= y_max;
		
    if (frame_averaging >= AVG_FRAMES) begin
      centre_x <= sum_x / num_highs;
      centre_y <= sum_y / num_highs;
      sum_x <= 0;
      sum_y <= 0;
      num_highs <= 0;
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
			msg_buf_in = {5'b0, x_max, 5'b0, y_max}; //Bottom right coordinate
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
reg [17:0]  col_detect_thresh;
reg [23:0]  des_colour;

always @ (posedge clk)
begin
	if (~reset_n)
	begin
		reg_status <= 8'b0;
    des_colour <= COL_DETECT_DEFAULT;
		col_detect_thresh <= COL_DETECT_THRESH_DEF;
	end
	else begin
		if(s_chipselect & s_write) begin
		   if      (s_address == `REG_STATUS)	reg_status <= s_writedata[7:0];
		   if      ((s_address == `REG_BBCOL) && s_writedata[31])	col_detect_thresh <= s_writedata[17:0]; // update threshold
       if      ((s_address == `REG_BBCOL) && !s_writedata[31])	des_colour <= s_writedata[23:0]; // update colour
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




#include <stdio.h>
#include "I2C_core.h"
#include "terasic_includes.h"
#include "mipi_camera_config.h"
#include "mipi_bridge_config.h"

#include "auto_focus.h"

#include <fcntl.h>
#include <unistd.h>

// debug
#define DEBUG FALSE

//EEE_IMGPROC defines
#define EEE_IMGPROC_MSG_START ('R'<<16 | 'B'<<8 | 'B')

// BEACONS defines
#define MAX_AVG 100
#define NUM_PIX_THRESH 10

//offsets
#define EEE_IMGPROC_STATUS 0
#define EEE_IMGPROC_MSG 1
#define EEE_IMGPROC_ID 2
#define EEE_IMGPROC_BBCOL 3

#define EXPOSURE_INIT 0x2d0
#define EXPOSURE_STEP 0x50
#define GAIN_INIT 0x040
#define GAIN_STEP 0x040
#define THRESH_INIT 0x1d3d
#define DEFAULT_LEVEL 3

#define MIPI_REG_PHYClkCtl		0x0056
#define MIPI_REG_PHYData0Ctl	0x0058
#define MIPI_REG_PHYData1Ctl	0x005A
#define MIPI_REG_PHYData2Ctl	0x005C
#define MIPI_REG_PHYData3Ctl	0x005E
#define MIPI_REG_PHYTimDly		0x0060
#define MIPI_REG_PHYSta			0x0062
#define MIPI_REG_CSIStatus		0x0064
#define MIPI_REG_CSIErrEn		0x0066
#define MIPI_REG_MDLSynErr		0x0068
#define MIPI_REG_FrmErrCnt		0x0080
#define MIPI_REG_MDLErrCnt		0x0090

void mipi_clear_error(void){
	MipiBridgeRegWrite(MIPI_REG_CSIStatus,0x01FF); // clear error
	MipiBridgeRegWrite(MIPI_REG_MDLSynErr,0x0000); // clear error
	MipiBridgeRegWrite(MIPI_REG_FrmErrCnt,0x0000); // clear error
	MipiBridgeRegWrite(MIPI_REG_MDLErrCnt, 0x0000); // clear error

  	MipiBridgeRegWrite(0x0082,0x00);
  	MipiBridgeRegWrite(0x0084,0x00);
  	MipiBridgeRegWrite(0x0086,0x00);
  	MipiBridgeRegWrite(0x0088,0x00);
  	MipiBridgeRegWrite(0x008A,0x00);
  	MipiBridgeRegWrite(0x008C,0x00);
  	MipiBridgeRegWrite(0x008E,0x00);
  	MipiBridgeRegWrite(0x0090,0x00);
}

void mipi_show_error_info(void){

	alt_u16 PHY_status, SCI_status, MDLSynErr, FrmErrCnt, MDLErrCnt;

	PHY_status = MipiBridgeRegRead(MIPI_REG_PHYSta);
	SCI_status = MipiBridgeRegRead(MIPI_REG_CSIStatus);
	MDLSynErr = MipiBridgeRegRead(MIPI_REG_MDLSynErr);
	FrmErrCnt = MipiBridgeRegRead(MIPI_REG_FrmErrCnt);
	MDLErrCnt = MipiBridgeRegRead(MIPI_REG_MDLErrCnt);
	printf("PHY_status=%xh, CSI_status=%xh, MDLSynErr=%xh, FrmErrCnt=%xh, MDLErrCnt=%xh\r\n", PHY_status, SCI_status, MDLSynErr,FrmErrCnt, MDLErrCnt);
}

void mipi_show_error_info_more(void){
    printf("FrmErrCnt = %d\n",MipiBridgeRegRead(0x0080));
    printf("CRCErrCnt = %d\n",MipiBridgeRegRead(0x0082));
    printf("CorErrCnt = %d\n",MipiBridgeRegRead(0x0084));
    printf("HdrErrCnt = %d\n",MipiBridgeRegRead(0x0086));
    printf("EIDErrCnt = %d\n",MipiBridgeRegRead(0x0088));
    printf("CtlErrCnt = %d\n",MipiBridgeRegRead(0x008A));
    printf("SoTErrCnt = %d\n",MipiBridgeRegRead(0x008C));
    printf("SynErrCnt = %d\n",MipiBridgeRegRead(0x008E));
    printf("MDLErrCnt = %d\n",MipiBridgeRegRead(0x0090));
    printf("FIFOSTATUS = %d\n",MipiBridgeRegRead(0x00F8));
    printf("DataType = 0x%04x\n",MipiBridgeRegRead(0x006A));
    printf("CSIPktLen = %d\n",MipiBridgeRegRead(0x006E));
}



bool MIPI_Init(void){
	bool bSuccess;


	bSuccess = oc_i2c_init_ex(I2C_OPENCORES_MIPI_BASE, 50*1000*1000,400*1000); //I2C: 400K
	if (!bSuccess)
		printf("failed to init MIPI- Bridge i2c\r\n");

    usleep(50*1000);
    MipiBridgeInit();

    usleep(500*1000);

//	bSuccess = oc_i2c_init_ex(I2C_OPENCORES_CAMERA_BASE, 50*1000*1000,400*1000); //I2C: 400K
//	if (!bSuccess)
//		printf("failed to init MIPI- Camera i2c\r\n");

    MipiCameraInit();
    MIPI_BIN_LEVEL(DEFAULT_LEVEL);
//    OV8865_FOCUS_Move_to(340);

//    oc_i2c_uninit(I2C_OPENCORES_CAMERA_BASE);  // Release I2C bus , due to two I2C master shared!


 	usleep(1000);


//    oc_i2c_uninit(I2C_OPENCORES_MIPI_BASE);

	return bSuccess;
}

int hex2int(char byte) {
    // int val = 0;
    // while (*hex) {
    //     // get current character then increment
    //     int byte = *hex++; 
        // transform hex character to the 4bit equivalent number, using the ascii table indexes
        if (byte >= '0' && byte <= '9') byte = byte - '0';
        else if (byte >= 'a' && byte <='f') byte = byte - 'a' + 10;
        else if (byte >= 'A' && byte <='F') byte = byte - 'A' + 10;    

        return byte;
        // shift 4 to make space for new digit, and add the 4 bits of the new digit 
    //     val = (val << 4) | (byte & 0xF);
    // }
    // return val;
}


int main()
{

	fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);

  printf("DE10-LITE D8M\n");
  printf("Imperial College EEE2 Magenta Project\n");

  IOWR(MIPI_PWDN_N_BASE, 0x00, 0x00);
  IOWR(MIPI_RESET_N_BASE, 0x00, 0x00);

  usleep(2000);
  IOWR(MIPI_PWDN_N_BASE, 0x00, 0xFF);
  usleep(2000);
  IOWR(MIPI_RESET_N_BASE, 0x00, 0xFF);

  printf("Image Processor ID: %x\n",IORD(0x42000,EEE_IMGPROC_ID));
//   //printf("Image Processor ID: %x\n",IORD(EEE_IMGPROC_0_BASE,EEE_IMGPROC_ID)); //Don't know why this doesn't work - definition is in system.h in BSP


  usleep(2000);


  // MIPI Init
   if (!MIPI_Init()){
	  printf("MIPI_Init Init failed!\r\n");
  }else{
	  printf("MIPI_Init Init successfully!\r\n");
  }

//   while(1){
 	    mipi_clear_error();
	 	usleep(50*1000);
 	    mipi_clear_error();
	 	usleep(1000*1000);
	    mipi_show_error_info();
//	    mipi_show_error_info_more();
	    printf("\n");
//   }

  //////////////////////////////////////////////////////////
  alt_u16 bin_level = DEFAULT_LEVEL;
  alt_u8  manual_focus_step = 10;
  alt_u16  current_focus = 300;
  int boundingBoxColour = 0;
  alt_u32 exposureTime = EXPOSURE_INIT;
  alt_u16 gain = GAIN_INIT;

  alt_u16 colour_threshold = THRESH_INIT;
  alt_u8  colour_thresh_step = 50;
  alt_u32 colour = 0xff2200;
  int min_pixel_thresh = NUM_PIX_THRESH;

  // SET DEFAULT SETTINGS
  OV8865SetExposure(exposureTime);
  OV8865SetGain(gain);
  // Focus_Init();

  // if the MS bit is set then the threshold is begin updated
  IOWR(0x42000, EEE_IMGPROC_BBCOL, (0b00 << 30) | colour_threshold); // update the threshold for colour detection
  IOWR(0x42000, EEE_IMGPROC_BBCOL, (0b01 << 30) | colour); // update the colour being detected
  IOWR(0x42000, EEE_IMGPROC_BBCOL, (0b10 << 30) | 10); // update the number 


  FILE* esp_write = fopen("/dev/uart_0", "wb+"); // use this only for writing
  if(esp_write){
    printf("Opened UART for writing\n");
  } else {
    printf("Failed to open UART for writing\n");
    while (1);
  }

  int write_code;
  if ( (write_code = fprintf(esp_write, "Hello from nios!\n")) <= 0 ) printf("Error writing to UART\n"); 
  else printf("Wrote to UART with code: %d\n", write_code);

  int esp_read;
  esp_read = open("/dev/uart_0", O_RDONLY | O_NONBLOCK);

  if (esp_read == -1){
    printf("Failed to open UART for reading\n");
  } else printf("Opened UART read\n");

  char incoming_char;
  int c;

  // rolling average
  float beacon_xs[MAX_AVG];
  int beacon_pntr = 0;
  int num_avg;
  float beacon_x;
  bool saturated = FALSE;
  int saturation = 0;
  bool awaiting_pos = FALSE;

  printf("Entering main loop\n");

  while(1){

    // READ FROM ESP 
    c = read(esp_read, &incoming_char, 1);
    if (c > 0) {
      #if DEBUG
        printf("Start reading:\n");
        printf("First:%c/\\", incoming_char);
      #endif

      if (incoming_char != 'B') { // handle camera and colour setting requests
        int val = 0;
        char next_char = 0;

        c = read(esp_read, &next_char, 1);
        while (next_char != '\n') {
          if (c > 0) {
            val = val << 4 | hex2int(next_char);

            #if DEBUG          
              printf("|%c, %d|", next_char, hex2int(next_char));
            #endif
          }
          c = read(esp_read, &next_char, 1);
        }
        #if DEBUG
          printf("\nFinished reading\n");
        #endif
        printf("ESP %c: %08x\n", incoming_char, val);

        switch(incoming_char){
          case 'E': {
            OV8865SetExposure(val);
            printf("\nExposure = %x", val);
            break;
          }
          case 'G': {
            OV8865SetGain(val);
            printf("\nGain = %x ", val);
            break;
          }
          case 'H': {
            IOWR(0x42000, EEE_IMGPROC_BBCOL, (0b01 << 30) | ((0x3FFFFFFF >> 2) & val)); // update the colour being detected
            colour = val;
            printf("\nColour = %x ", val);
            break;
          }
          case 'T': {
            IOWR(0x42000, EEE_IMGPROC_BBCOL, (0b00 << 30) | ((0x3FFFFFFF >> 2) & val)); // update the colour being detected
            printf("\nColour Threshold= %x ", val);
            break;
          }
          case 'F': {
            OV8865_FOCUS_Move_to(val); // update the colour being detected
            printf("\nFocus= %x ", val);
            break;
          }
          case 'A': {
            if (val <= MAX_AVG) num_avg = val;
            else num_avg = MAX_AVG;
            // reset the buffer and corresponding vars
            memset(beacon_xs, 0, sizeof beacon_xs);
            saturation = 0;
            saturated = FALSE;
            printf("\nFrame Averaging= %x ", val);
            break;
          }
          case 'P': {
            min_pixel_thresh = val;
            printf("\nMin pixel Threshold= %x ", min_pixel_thresh);
            break;
          }
          default: {
            printf("\nInvalid Command");
            break;
          }
          // printf("\n");  
        }
      } else { // handle beacon position request
        printf("\nReceived beacon posiiton request\n");
        awaiting_pos = TRUE;
        // if (saturated) {
        //   fprintf(esp_write, "H%08x\nB%08x\n", colour, (int) beacon_x); // if ready, send the hex being detected and the corresponding position
        // }
      }
    }

    int msg_num = 0;
    int x_sum, y_sum, num, hw_x, hw_y, left, right, bottom, top;
    float x, y, x_b, y_b;
    //Read messages from the image processor and print them on the terminal
    while ((IORD(0x42000,EEE_IMGPROC_STATUS)>>8) & 0xff) { 	//Find out if there are words to read
      int word = IORD(0x42000,EEE_IMGPROC_MSG); 			//Get next word from message buffer
      // if (fwrite(&word, 4, 1, ser) != 1) printf("Error writing to UART");
      if (word == EEE_IMGPROC_MSG_START)	
      {
        // printf("\n");//Newline on message identifier
      } else {
        #if DEBUG
          printf("%d:%d,",msg_num, word);
        #endif
        if (msg_num == 0) x_sum = word;
        else if (msg_num == 1) y_sum = word;
        else if (msg_num == 2) num = word;
        else if (msg_num == 3) {
          hw_x = word >> 16;
          hw_y = word & 0xFFFF;
        }
        else if (msg_num == 4) {
          left = word >> 16;
          right = word & 0xFFFF;
        }
        else if (msg_num == 5) {
          bottom = word >> 16;
          top = word & 0xFFFF;
        }

        msg_num++;
      }
    }

    if (msg_num != 0) { // new message arrived
      if (num > min_pixel_thresh) { // there were pixels detected
        #if DEBUG
        x = x_sum / (float) num;
        y = y_sum / (float) num;

        y_b = (float) (bottom + top) / 2;
        #endif
        x_b = (float) (left + right) / 2; // only value that matters
      } else {
        x_b = -1;
      }

      // if (beacon_pntr < num_avg) beacon_xs[beacon_pntr++] = x_b;
      // else beacon_xs[beacon_pntr = 0] = x_b;

      beacon_xs[beacon_pntr++%num_avg] = x_b;



      if (!saturated) saturated = ++saturation == num_avg; // determine if the buffer is saturated 
      else { // buffer is saturated and rolling avg can be computed
        beacon_x = 0;
        for (__uint8_t i = 0; i < num_avg; i++) beacon_x += beacon_xs[i];
        beacon_x /= num_avg;
        if (awaiting_pos) {
          // write the hex values and position and whether or not there are any pixels being detected
          // assuming that if no pixels where detected while the robot was observing, then it will be the case when it is being sampled
          fprintf(esp_write, "D%cB%08x\nH%08x\n", ((num > min_pixel_thresh) ? '1' : '0'), (int) beacon_x, colour); 
          // printf("D%cB%08x\nH%08x\n", ((num > min_pixel_thresh) ? '1' : '0'), (int) beacon_x, colour); 
          awaiting_pos = FALSE;
        }
      }

      #if DEBUG
        printf("x: %.2f, y: %.2f| bb x: %.2f, y: %.2f| hw x:%i, y:%i|", x, y, x_b, y_b, hw_x, hw_y);
      #endif

      // printf("\nx_avg: %.2f\n", beacon_x);

      // printf("%c %i\n", (saturated ? '1' : '0'), saturation);
    }

    usleep(10000);

  }

  return 0;
}



#include <stdio.h>
#include "I2C_core.h"
#include "terasic_includes.h"
#include "mipi_camera_config.h"
#include "mipi_bridge_config.h"

#include "auto_focus.h"

#include <fcntl.h>
#include <unistd.h>

//EEE_IMGPROC defines
#define EEE_IMGPROC_MSG_START ('R'<<16 | 'B'<<8 | 'B')

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




int main()
{

	fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);

  printf("DE10-LITE D8M VGA Demo\n");
  printf("Imperial College EEE2 Project version\n");
  IOWR(MIPI_PWDN_N_BASE, 0x00, 0x00);
  IOWR(MIPI_RESET_N_BASE, 0x00, 0x00);

  usleep(2000);
  IOWR(MIPI_PWDN_N_BASE, 0x00, 0xFF);
  usleep(2000);
  IOWR(MIPI_RESET_N_BASE, 0x00, 0xFF);

  printf("Image Processor ID: %x\n",IORD(0x42000,EEE_IMGPROC_ID));
  //printf("Image Processor ID: %x\n",IORD(EEE_IMGPROC_0_BASE,EEE_IMGPROC_ID)); //Don't know why this doesn't work - definition is in system.h in BSP


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

  OV8865SetExposure(exposureTime);
  OV8865SetGain(gain);
  // Focus_Init();

  // if the MS bit is set then the threshold is begin updated
  IOWR(0x42000, EEE_IMGPROC_BBCOL, (0x1 << 31) | colour_threshold); // update the threshold for colour detection
  IOWR(0x42000, EEE_IMGPROC_BBCOL,  0xff2200 & 0x0FFFFFFF); // update the colour being detected

  FILE* ser = fopen("/dev/uart_0", "rb+");
  if(ser){
    printf("Opened UART\n");
  } else {
    printf("Failed to open UART\n");
    while (1);
  }

  while(1){
    
    //Process input commands
    int in = getchar();
    switch (in) {
        case 'e': {
          exposureTime += EXPOSURE_STEP;
          OV8865SetExposure(exposureTime);
          printf("\nExposure = %x ", exposureTime);
            break;}
        case 'd': {
          exposureTime -= EXPOSURE_STEP;
          OV8865SetExposure(exposureTime);
          printf("\nExposure = %x ", exposureTime);
            break;}
        case 't': {
          gain += GAIN_STEP;
          OV8865SetGain(gain);
          printf("\nGain = %x ", gain);
            break;}
        case 'g': {
          gain -= GAIN_STEP;
          OV8865SetGain(gain);
          printf("\nGain = %x ", gain);
            break;}
        case 'r': {
          current_focus += manual_focus_step;
          if(current_focus >1023) current_focus = 1023;
          OV8865_FOCUS_Move_to(current_focus);
          printf("\nFocus = %x ",current_focus);
            break;}
        case 'f': {
          if(current_focus > manual_focus_step) current_focus -= manual_focus_step;
          OV8865_FOCUS_Move_to(current_focus);
          printf("\nFocus = %x ",current_focus);
            break;}
        case 'w': {
          colour_threshold += colour_thresh_step;
          if(colour_threshold > 0x0FFFFFFF) colour_threshold = 0x0FFFFFFF;
          IOWR(0x42000, EEE_IMGPROC_BBCOL, (0x1 << 31) | colour_threshold); // update the threshold for colour detection
          printf("\nColour Thresh = %x ",colour_threshold);
            break;}
        case 's': {
          colour_threshold -= colour_thresh_step;
          if (colour_threshold < 0) colour_threshold = 0;
          IOWR(0x42000, EEE_IMGPROC_BBCOL, (0x1 << 31) | colour_threshold); // update the threshold for colour detection
          printf("\nColour Thresh = %x ",colour_threshold);
            break;}
    }


    int msg_num = 0;
    int x_sum, y_sum, num;
    double x, y;
    //Read messages from the image processor and print them on the terminal
    while ((IORD(0x42000,EEE_IMGPROC_STATUS)>>8) & 0xff) { 	//Find out if there are words to read
      int word = IORD(0x42000,EEE_IMGPROC_MSG); 			//Get next word from message buffer
      if (fwrite(&word, 4, 1, ser) != 1) printf("Error writing to UART");
      if (word == EEE_IMGPROC_MSG_START)	printf("\n");//Newline on message identifier
      else {
        printf("%d ",word);
        if (msg_num == 0) x_sum = word;
        if (msg_num == 1) y_sum = word;
        if (msg_num == 2) num = word;

        msg_num++;
      }
    }

    if (msg_num != 0) { // new message arrived
      x = x_sum / (double) num;
      y = y_sum / (double) num;

      printf("\n");
      printf("x: %f, y: %f", x, y);
    }

    usleep(10000);

   };
  return 0;
}

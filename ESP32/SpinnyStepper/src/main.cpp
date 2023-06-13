#include <Arduino.h>
#include <Stepper.h>

// Defines the number of steps per rotation
const double stepsPerRevolution = 2037.8864;

// ULN2003 Motor Driver Pins
#define IN1 19
#define IN2 22
#define IN3 5
#define IN4 21

// initialize the stepper library
Stepper myStepper(stepsPerRevolution, IN1, IN3, IN2, IN4);

void setup() {
    // Nothing to do (Stepper Library sets pins as outputs)

    Serial.begin(115200);
}

int num_steps = 0;

void loop() {
	// Rotate CW slowly at 5 RPM

  
  while(!Serial.available());

  if(Serial.available()){
    num_steps = int(double(Serial.parseInt()) * stepsPerRevolution / 360);
    Serial.printf("Stepping %d\n", num_steps);
  }

	myStepper.setSpeed(5);
	myStepper.step(num_steps);
	delay(1000);
  Serial.println("stepped");
  // }

	
	// // Rotate CCW quickly at 10 RPM
	// myStepper.setSpeed(5);
	// myStepper.step(-1016);
	// delay(1000);
}
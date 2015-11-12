//--------------------------------------------------------------------------
// Code to test basic Hapkit functionality (sensing and force output)
// 04.11.14
// Updated by Sam Schorr 10.05.15
//--------------------------------------------------------------------------

// Includes
#include <math.h>

//define calibration constants
const float calib_intercept = 2.8343E-3;
const float calib_slope = 2.0944E-4;
const int MOTOR_DIRECTION = 1;

// Pin declares
const int pwmPin = 5; // PWM output pin for motor 1
const int dirPin = 8; // direction output pin for motor 1
const int sensorPosPin = A2; // input pin for MR sensor
const int fsrPin = A3; // input pin for FSR sensor

const double temp_damping = 5; //temporarily adding damping to the handle motion

// Position tracking variables
int updatedPos = 0;     // keeps track of the latest updated value of the MR sensor reading
int rawPos = 0;         // current raw reading from MR sensor
int lastRawPos = 0;     // last raw reading from MR sensor
int lastLastRawPos = 0; // last last raw reading from MR sensor
int flipNumber = 0;     // keeps track of the number of flips over the 180deg mark
int tempOffset = 0;
int rawDiff = 0;
int lastRawDiff = 0;
int rawOffset = 0;
int lastRawOffset = 0;
const int flipThresh = 700;  // threshold to determine whether or not a flip over the 180 degree mark occurred
boolean flipped = false;
double OFFSET = 980;
double OFFSET_NEG = 15;

// Kinematics variables
double xh = 0;           // position of the handle [m]
double vh = 0;              //velocity of the handle [m/s]
double vh_last = 0;          //velocity of the handle at the last step (for filtering)
double xh_last = 0;          // position of the handle [m], for filtering
const double iir_alpha = 0.05; //iir filter constant for the velocity, alpha in [0,1] larger alpha lets higher frequencies though.

//timestep
//const double timestep = 0.001; //assuming it takes 1 ms to complete the loop
double timestep = 0.001;
int timecount = -1;
unsigned long time = 0;
const int timecount_reset = 1000; //calculate time every 1000 loops
const int timecount_serial= 10; //send serial info every 10 cycles - one cycle takes about 0.3ms from measurement, so 10 of them should take about 3ms

// Force output variables
double force = 0;           // force at the handle
double Tp = 0;              // torque of the motor pulley
double duty = 0;            // duty cylce (between 0 and 255)
unsigned int output = 0;    // output command to the motor

// Serial communication buffer
String inString = "";    // string to hold input

// --------------------------------------------------------------
// Setup function -- NO NEED TO EDIT
// --------------------------------------------------------------
void setup() 
{
  // Set up serial communication
  Serial.begin(115200);
  
  // Set PWM frequency 
  setPwmFrequency(pwmPin,1); 
  
  // Input pins
  pinMode(sensorPosPin, INPUT); // set MR sensor pin to be an input
  pinMode(fsrPin, INPUT);       // set FSR sensor pin to be an input

  // Output pins
  pinMode(pwmPin, OUTPUT);  // PWM pin for motor A
  pinMode(dirPin, OUTPUT);  // dir pin for motor A
  
  // Initialize motor 
  analogWrite(pwmPin, 0);     // set to not be spinning (0/255)
  digitalWrite(dirPin, LOW);  // set direction
  
  // Initialize position valiables
  lastLastRawPos = analogRead(sensorPosPin);
  lastRawPos = analogRead(sensorPosPin);
  flipNumber = 0;
  
  //Serial.println("Starting rendering.");
}


// --------------------------------------------------------------
// Main Loop
// --------------------------------------------------------------
void loop()
{
  
  /*******  Calculate timestep  ********/
  timecount += 1;
  if(timecount == 0) {
    time = micros()/64; //note:the micros function takes 4 ms
  }
  else if(timecount == timecount_reset) {
    time = micros()/64 - time;
    timestep = ((double)(time)/(timecount_reset))/1E6;
    //Serial.println(timestep*1E6); //time in microsseconds
    timecount = -1;
  }
  
  
  //*************************************************************
  //*** Section 1. Compute position in counts (do not change) ***  
  //*************************************************************
  // Get voltage output by MR sensor
  rawPos = analogRead(sensorPosPin);  //current raw position from MR sensor
  // Calculate differences between subsequent MR sensor readings
  rawDiff = rawPos - lastRawPos;          //difference btwn current raw position and last raw position
  lastRawDiff = rawPos - lastLastRawPos;  //difference btwn current raw position and last last raw position
  lastRawOffset = abs(lastRawDiff);
  
  // Update position record-keeping vairables
  lastLastRawPos = lastRawPos;
  lastRawPos = rawPos;
  
  // Keep track of flips over 180 degrees
  if((lastRawOffset > flipThresh) && (!flipped)) { // enter this anytime the last offset is greater than the flip threshold AND it has not just flipped
    if(lastRawDiff > 0) {        // check to see which direction the drive wheel was turning
      flipNumber--;              // cw rotation 
    } else {                     // if(rawDiff < 0)
      flipNumber++;              // ccw rotation
    }
    flipped = true;            // set boolean so that the next time through the loop won't trigger a flip
  } else {                        // anytime no flip has occurred
    flipped = false;
  }
   updatedPos = rawPos + flipNumber*OFFSET; // need to update pos based on what most recent offset is 

 
  //*************************************************************
  //*** Section 2. Compute position in meters *******************
  //*************************************************************

  // ADD YOUR CODE HERE
  // Define kinematic parameters you may need
  const double rh = 0.075;   //[m]
  double ts = calib_intercept + ((double)updatedPos)*calib_slope; // Compute the angle of the sector pulley (ts) in radians based on updatedPos
  double xh = -ts*rh;       // Compute the position of the handle (in meters) based on ts (in radians)

  
  //low pass filtered handle velocity (Infinite Impulse Response filter)
  vh = (xh - xh_last)/timestep;
  vh = iir_alpha*vh + (1-iir_alpha)*vh_last;
  vh_last = vh;
  xh_last = xh;
  
  // Define kinematic parameters you may need
  const double rp = 4.725E-3;   //[m] 3/8in
  const double rs = 0.075;   //[m] 
      
  // Step C.2: 
  Tp = force*(rh*rp/rs); 
  // Compute the require motor pulley torque (Tp) to generate that force
 

  // Determine correct direction for motor torque
  if(force*MOTOR_DIRECTION > 0) { 
    digitalWrite(dirPin, HIGH);
  } else {
    digitalWrite(dirPin, LOW);
  }

  // Compute the duty cycle required to generate Tp (torque at the motor pulley)
  duty = sqrt(abs(Tp)/0.0183);
  //Serial.println(duty);
  
  // Make sure the duty cycle is between 0 and 100%
  if (duty > 1) {            
    duty = 1;
  } else if (duty < 0) { 
    duty = 0;
  }  
  output = (int)(duty* 255);   // convert duty cycle to output signal
  analogWrite(pwmPin,output);  // output the signal
  
  
  /*****  send serial messages at >60Hz (<16ms) ********/
  if((timecount % timecount_serial) == 0) {
   Serial.println(-ts); //send position data - angle in mm
   //Serial.println(force);
   //Serial.println(vh);
  }
}

void serialEvent() {
  while (Serial.available()) {
    int inChar = Serial.read();

    if (inChar != '\n') { 

      // As long as the incoming byte
      // is not a newline,
      // convert the incoming byte to a char
      // and add it to the string
      inString += (char)inChar;
    }
    // if you get a newline, print the string,
    // then the string's value as a float:
    else {
//      Serial.print("Input string: ");
//      Serial.println(inString);
//      Serial.print("\tAfter conversion to float:");
      force = inString.toFloat();
      force = force - temp_damping*vh;
      // clear the string for new input:
      inString = "";
    }
    //force = Serial.parseFloat();
  }
}

// --------------------------------------------------------------
// Function to set PWM Freq -- DO NOT EDIT
// --------------------------------------------------------------
void setPwmFrequency(int pin, int divisor) {
  byte mode;
  if(pin == 5 || pin == 6 || pin == 9 || pin == 10) {
    switch(divisor) {
      case 1: mode = 0x01; break;
      case 8: mode = 0x02; break;
      case 64: mode = 0x03; break;
      case 256: mode = 0x04; break;
      case 1024: mode = 0x05; break;
      default: return;
    }
    if(pin == 5 || pin == 6) {
      TCCR0B = TCCR0B & 0b11111000 | mode;
    } else {
      TCCR1B = TCCR1B & 0b11111000 | mode;
    }
  } else if(pin == 3 || pin == 11) {
    switch(divisor) {
      case 1: mode = 0x01; break;
      case 8: mode = 0x02; break;
      case 32: mode = 0x03; break;
      case 64: mode = 0x04; break;
      case 128: mode = 0x05; break;
      case 256: mode = 0x06; break;
      case 1024: mode = 0x7; break;
      default: return;
    }
    TCCR2B = TCCR2B & 0b11111000 | mode;
  }
}


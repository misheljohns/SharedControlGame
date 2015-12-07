//Communication with Hapkit
import processing.serial.*;
Serial myPort;        // The serial port

//initialize Serial communication with Hapkit
void initSerial() {
  println(Serial.list());
  myPort = new Serial(this, Serial.list()[0], 115200);
  myPort.bufferUntil('\n');
}

//called when there is data on the Serial buffer, read input to steering angle, then send steering torque output. This means that it is the hapkit communication frequency that decides torque message timing
void serialEvent (Serial myPort1) {
  String inString = myPort1.readStringUntil('\n');
  if (inString != null) {
    inString = trim(inString); // trim off any whitespace:
    //println("Data received : " + inString);
    float inByte = float(inString); // convert to a float
    //println(inByte);
    steerAngle = inByte;
    myPort1.write(String.format("%.3f", steerTorque)+'\n'); //send torque to hapkit motor
    //print("Torque Sent: " + String.format("%.3f", steerTorque)+'\n');
    messagecount += 1;
  }
}
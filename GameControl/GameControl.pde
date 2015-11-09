/**********  Code to simulate game and provide assistance methods **********/

//Communication with Hapkit
import processing.serial.*;
Serial myPort;        // The serial port

//TCPsocket for motor control
import processing.net.*;
import java.nio.ByteBuffer;
int port = 10002; 
int cnt = 0;
Server myServer;        
byte[] byteBuffer = new byte[8];

//Image rendering
//PImage block; 

//Block positions array
PVector blockPositions[];

//number and density of blocks
int npartTotal = 100; //number of blocks
float partSize = 20;
float partSpread = 5.0; //how much vertical space the blocks are spread over - reducing this value increases density, difficulty; needs to be >1

//speed of movement
float worldVelocity = 0.5; //number of frame sizes that is passed in one second

//player position
float playerPosx = 0.5;

//Steering Control
float steerAngle = 0.0;
float steerTorque = 0.0;

//Frame rate and timing stuff
int fcount, lastm;
float frate;
//int fint = 3;

//time for world simulation
int ctime = 0;//current time
int ltime = 0;//last time

void setup() {
  //size(640, 480, P3D);
  size(800, 600);//, P3D);
  frameRate(60);
  rectMode(RADIUS); // I like to draw around the center position of the rectangles
  ellipseMode(RADIUS); // I like to draw around the center position of the circles
  fill(255); //white fill for now
  
  
  //hapkit communication
  //initSerial();
  
  //motor control from realtime OS
  //initServer();
  
  //block = loadImage("block.png");

  initPositions(); //initial block positions
  thread("runWorld"); //this thread generates blocks and integrates over time

  // Writing to the depth buffer is disabled to avoid rendering
  // artifacts due to the fact that the particles are semi-transparent
  // but not z-sorted.
  // hint(DISABLE_DEPTH_MASK);
} 

void draw () {
  background(0);
  
  drawPlayer(playerPosx);

  for (int n = 0; n < npartTotal; n++) {
    if((blockPositions[n].y < 1) && (blockPositions[n].y > 0)) { //within window
      drawBlock(blockPositions[n]);
    }
  }
  
  fcount += 1;
  int m = millis();
  if (m - lastm > 1000) {
    frate = float(fcount);
    fcount = 0;
    lastm = m;
    println("fps: " + frate); 
  }  
}

void drawPlayer(float playerPos) {
  ellipse(playerPos*width,height-10,30,30);
}

void drawBlock(PVector center) {
  rect(center.x*width,(1-center.y)*height,50,50);
}

//block positions at Start
void initPositions() {
  blockPositions = new PVector[npartTotal];
  for (int n = 0; n < blockPositions.length; n++) {
    //blockPositions[n] = new PVector(-1,0);
    blockPositions[n] = new PVector(random(-1, 1), random(0, partSpread));
  }  
}

//runs the world - moves block down according to velocity, creates new blocks as blocks leave the world, moves player according to steering angle
void runWorld() {
  while(true) {
    ctime = millis();
    float move = ((float) (ctime - ltime))*worldVelocity/1000; //time in ms, so we divide by 1000
    //print(move);
    for (int n = 0; n < blockPositions.length; n++) {
      blockPositions[n].y -= move;
      if(blockPositions[n].y < 0) {
        blockPositions[n] = new PVector(random(-1, 1), random(1, partSpread));//block randomly appears in the queue above you
      }
    } 
    ltime = ctime;
    try{
      Thread.sleep(10);//wait 10ms
    }
    catch(Exception E)
    { //throws InterruptedException
    }
  }
}

//initialize Serial communication with Hapkit
void initSerial() {
  println(Serial.list());
  myPort = new Serial(this, Serial.list()[0], 115200);
  myPort.bufferUntil('\n');
}

//called when there is data on the Serial buffer, read input to steering angle, then send steering torque output. This means that it is the hapkit communication frequency that decides torque message timing
void serialEvent (Serial myPort) {
   String inString = myPort.readStringUntil('\n');
   if (inString != null) {
     inString = trim(inString); // trim off any whitespace:
     float inByte = float(inString); // convert to a float
     //println(inByte);
     steerAngle = inByte;
     myPort.write(String.valueOf(steerTorque)+'\n'); //send torque to hapkit motor
   }
}

//initialize server for communication with motor control C++ program
void initServer() {
  myServer = new Server(this, port);
  thread("runServer");
}

//run the server, accept position inputs, send force outputs
void runServer () {
  while(true) {
    Client thisClient = myServer.available();
    // If the client is not null, and says something, display what it said
    if (thisClient !=null) { 
      String whatClientSaid = thisClient.readString();
      if (whatClientSaid != null) {
        double data_received = Double.parseDouble(whatClientSaid);
        println("Data received : " + data_received);
        steerAngle = (float) data_received;
        thisClient.write(String.valueOf(steerTorque));
      } 
      
      /*int byteCnt = thisClient.readBytes(byteBuffer); //readString()
      if (byteCnt > 0) {
        //if (cnt++ % 1000 == 0)
        println(ByteBuffer.wrap(byteBuffer).getDouble());
        
        thisClient.write("sending from processing"); //thisClient.ip() + "t" + whatClientSaid + ""
      } */
    }
  }
}

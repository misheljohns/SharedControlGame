//Communication with Hapkit
import processing.serial.*;
Serial myPort;        // The serial port

//TCPscoket for motor control
import processing.net.*;
import java.nio.ByteBuffer;
int port = 10002; 
int cnt = 0;
Server myServer;        
byte[] byteBuffer = new byte[8];

//Image rendering
PImage block; 

//Block positions array
PVector blockPositions[];

//number and density of blocks
int npartTotal = 100; //number of blocks
float partSize = 20;
float partSpread = 20.0; //how much vertical space the blocks are spread over - reducing this value increases density, difficulty; needs to be >1

//speed of movement
float worldVelocity = 0.5; //number of frame sizes that is passed in one second

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

void drawBlock(PVector center) {
  rect(center.x*width,(1-center.y)*height,50,50);
}

void initPositions() {
  blockPositions = new PVector[npartTotal];
  for (int n = 0; n < blockPositions.length; n++) {
    //blockPositions[n] = new PVector(-1,0);
    blockPositions[n] = new PVector(random(-1, 1), random(0, partSpread));
  }  
}

//runs the world - moves block down according to velocity, creates new blocks as blocks leave the world
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

void initSerial() {
  println(Serial.list());
  myPort = new Serial(this, Serial.list()[0], 115200);
  myPort.bufferUntil('\n');
}

void serialEvent (Serial myPort) {
   String inString = myPort.readStringUntil('\n');
   if (inString != null) {
     // trim off any whitespace:
     inString = trim(inString);
     // convert to a float
     float inByte = float(inString);
     //println(inByte);
     steerAngle = inByte;
   }
}

void initServer() {
  myServer = new Server(this, port);
  thread("runServer");
}

void runServer () {
  while(true) {
    Client thisClient = myServer.available();
    // If the client is not null, and says something, display what it said
    if (thisClient !=null) {
      
      String whatClientSaid = thisClient.readString();
      double data_received = Double.parseDouble(whatClientSaid);
      if (whatClientSaid != null) {
        println("Data received : " + data_received);
        thisClient.write(thisClient.ip() + "t" + whatClientSaid);
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

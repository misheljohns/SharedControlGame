/**********  Code to simulate game and provide assistance methods **********/

//TODO: 
//ADD damping to shared control


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


/*
//Block positions array
PVector blockPositions[];

//Image rendering
//PImage block; 

//number and density of blocks
static final int nblockTotal = 10; //number of blocks
static final float blockSpread = 5.0; //how much vertical space the blocks are spread over - reducing this value increases density, difficulty; needs to be >1
static final float blockHeight = 0.5; //height of block
static final float blockWidth = 0.1; //width of block
*/

//single available path
float roadPositions[];
static final int nroadPositions = 12; //number of road positions cached, roadStepY*nroadPositions has to be greateer than 1 to be beigger than the screen size
static final float roadStepY = 0.1; //the road horizontal position changes every x fraction of the screen size
float roadYPosition = 0.0; //vertical movement of the world
static final float roadStepX = 0.08; //max sideways step of the road in one vertical step
static final float roadWidth = 0.3;//width of the road

//speed of movement
static final float worldVelocity = 0.5; //number of frame sizes that is passed in one second
static final float playerVelocity = 0.5; //adjusting how much the player moves with the steering or keypress

//alternate movement - steering angle corresponds to actual position
static final float steerScale = 1.0; //1 rad of rotation = steerScale movement on screen

//margin zones
static final float marginZone = 0.05;

//player image
static final float playerWidth = 0.02;
static final float playerHeight = 0.05;

//player position
float playerPosx = 0.5;

//Steering Control
float steerAngle = 0.0;
float steerTorque = 0.0;

//keyboard control
static final float steerKeyStep = 0.1; //one press of the left or right key changes the steering angle by this much, in radians

//Frame rate and timing stuff
int fcount, lastm;
float frate;
//int fint = 3;

//time for world simulation
int ctime = 0;//current time
int ltime = 0;//last time

//wallforce
static final float kwall = 10.0; //force constant for wall

//shared control
static final float kFeedback = 4.0; //force coefficient for shared control
static final float alphaFeedback = 0.6; //percentage of force applied


void setup() {
  //size(640, 480, P3D);
  size(800, 600);//, P3D);
  frameRate(60);
  rectMode(RADIUS); // I like to draw around the center position of the rectangles
  ellipseMode(RADIUS); // I like to draw around the center position of the circles
  
  strokeCap(ROUND); //line ends should be rounded
  strokeJoin(ROUND); //lines join in rounded edge, for the road
  
  fill(255); //white fill for now


  //hapkit communication
  initSerial();

  //motor control from realtime OS
  //initServer();

  //road = loadImage("road.png");

  initPositions(); //initial road positions
  thread("runWorld"); //this thread generates blocks and integrates over time

  // Writing to the depth buffer is disabled to avoid rendering
  // artifacts due to the fact that the particles are semi-transparent
  // but not z-sorted.
  // hint(DISABLE_DEPTH_MASK);
} 

void draw () {
  background(0);

  drawRoad();
  drawPlayer(playerPosx);
  
  drawIdealPos();
  
  drawDetectFailure();
  
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
  fill(255,0,0);
  noStroke();
  ellipse(playerPos*width, height-10, playerWidth*width, playerHeight*height);
  stroke(255);
  fill(255);
}

void drawRoad() {
  noFill();
  stroke(255);
  strokeWeight((int)(roadWidth*width));
  beginShape();
  for (int n = 0; n < nroadPositions; n++) {
    vertex(roadPositions[n]*width, (1 - n*roadStepY + roadYPosition)*height);
  }
  endShape();
  fill(255);
}

void drawIdealPos() {
  float idealPosX = roadPositions[0] + (roadYPosition/roadStepY)*(roadPositions[1]-roadPositions[0]);
  fill(0,255,0);
  noStroke();
  ellipse(idealPosX*width, height-10, 10, 10);
  stroke(255);
  fill(255);
}

void drawDetectFailure() {
  float idealPosX = roadPositions[0] + (roadYPosition/roadStepY)*(roadPositions[1]-roadPositions[0]);
  if(abs(idealPosX - playerPosx) > (roadWidth/2 - playerWidth)) {
    stroke(255,0,0);
    line(0,0,0,height);
    line(width,0,width,height);
    stroke(255);
  }
}

//block positions at Start
void initPositions() {
  roadPositions = new float[nroadPositions];
  roadPositions[0] = 0.5;
  for (int n = 1; n < nroadPositions; n++) {
    //blockPositions[n] = new PVector(-1,0);
    if(roadPositions[n-1] <= marginZone + roadWidth/2) {
      roadPositions[n] = roadPositions[n-1] + random(0, roadStepX);
    }
    else if(roadPositions[n-1] >= 1 - marginZone - roadWidth/2) {
      roadPositions[n] = roadPositions[n-1] - random(0, roadStepX);
    }
    else {
      roadPositions[n] = roadPositions[n-1] + random(-roadStepX, roadStepX);
    }
  }
}

//runs the world - moves block down according to velocity, creates new blocks as blocks leave the world, moves player according to steering angle
void runWorld() {
  while (true) {
    ctime = millis();
    
    //moving the world
    float move = ((float) (ctime - ltime))*worldVelocity/1000; //time in ms, so we divide by 1000
    roadYPosition += move; //move forward by move
    if(roadYPosition > roadStepY) { //we have moved more than a step, we can jump to next step and create a new step
      roadYPosition -= roadStepY;
      for (int n = 0; n < (nroadPositions - 1); n++) {
        roadPositions[n] = roadPositions[n+1];
      }
      if(roadPositions[nroadPositions - 2] <= marginZone + roadWidth/2) {
        roadPositions[nroadPositions - 1] = roadPositions[nroadPositions - 2] + random(0, roadStepX);
      }
      else if(roadPositions[nroadPositions - 2] >= 1 - marginZone - roadWidth/2) {
        roadPositions[nroadPositions - 1] = roadPositions[nroadPositions - 2] - random(0, roadStepX);
      }
      else {
        roadPositions[nroadPositions - 1] = roadPositions[nroadPositions - 2] + random(-roadStepX, roadStepX);
      }
    }
    
    /****************************  Player position control  ****************************/ 
    //update player position
    //playerPosx += playerVelocity*steerAngle*((float) (ctime - ltime))/1000; 
    playerPosx = 0.5 + steerAngle*steerScale;
    
    //edge of window forces
    if(playerPosx > 1 - marginZone) {
     steerTorque = -kwall*(playerPosx - (1 - marginZone));
    }
    else if(playerPosx < marginZone) {
     steerTorque = kwall*(marginZone - playerPosx);
    } 
    else {
      steerTorque = 0.0;
      
      //shared control forces
      float idealPosX = roadPositions[0] + (roadYPosition/roadStepY)*(roadPositions[1]-roadPositions[0]);
      steerTorque = alphaFeedback*kFeedback*(idealPosX - playerPosx);
    }
    
    ltime = ctime;
    try {
      Thread.sleep(1);//wait 10ms
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
void serialEvent (Serial myPort1) {
  String inString = myPort1.readStringUntil('\n');
  if (inString != null) {
    inString = trim(inString); // trim off any whitespace:
    //println("Data received : " + inString);
    float inByte = float(inString); // convert to a float
    //println(inByte);
    steerAngle = inByte;
    myPort1.write(String.valueOf(steerTorque)+'\n'); //send torque to hapkit motor
    //print("Torque Sent: " + String.valueOf(steerTorque)+'\n');
  }
}

//initialize server for communication with motor control C++ program
void initServer() {
  myServer = new Server(this, port);
  thread("runServer");
}

//run the server, accept position inputs, send force outputs
void runServer () {
  while (true) {
    Client thisClient = myServer.available();
    // If the client is not null, and says something, display what it said
    if (thisClient !=null) { 
      String whatClientSaid = thisClient.readString();
      if (whatClientSaid != null) {
        double data_received = Double.parseDouble(whatClientSaid);
        //println("Data received : " + data_received);
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

//moves player with the arrow keys
void keyPressed() {
  if (keyCode == RIGHT) {
    steerAngle += steerKeyStep;
  } else if (keyCode == LEFT) {
    steerAngle -= steerKeyStep;
  } 
}


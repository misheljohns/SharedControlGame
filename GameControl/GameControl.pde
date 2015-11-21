/**********  Code to simulate game and provide assistance methods **********/

//TODO: 
//ADD damping to shared control
//increasing difficulty, levels
//shared control functions
//capture performance measures
//usernames, highscores
//randomly assign conditions to users
//export performance data to file - user ID, game condition, section condition, DVs
//create qualtrics survey
// make a curved center of the road instead of  discrete sections at angles - or discretize further to smooth - then the discretization will need to be at greater than 200 Hz to not be felt directly; might still cause resonance issues

//NOTE:
// made variables accessed by the threads volatile, so that any updates are seen immediately by the other threads
// I do not need to make it atomic, because there's one thread setting the value and another reading it

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


//single available path
static final int nroadPositions = 15; //number of road positions cached, roadStepY*nroadPositions has to be greateer than 1 to be beigger than the screen size
static final float roadStepY = 0.1;//0.1; //the road horizontal position changes every vertical movement that is roadStepY fraction of the screen size
static final float roadStepX = 0.08; //max sideways step of the road in one vertical step
static final float roadWidth = 0.15;//width of the road
static final int nroadPositionsBeneath = 2; //number of road positions that extend beneath the screen - this is to avoid changes in the road when one vertex is removed at the bottom - we need two vertices below the screen to maintain position and slope

//store path
volatile float roadPositions[];
volatile float roadYPosition = 0.0; //vertical movement of the world

//speed of movement
static final float worldVelocity = 0.9; //number of frame sizes that is passed in one second
static final float playerVelocity = 0.5; //adjusting how much the player moves with the steering or keypress

//alternate movement - steering angle corresponds to actual position
static final float steerScale = 1.0; //1 rad of rotation = steerScale movement on screen
static final float steerTorqueMax = 2.0; //max force that can be applied to the motor

//margin zones
static final float marginZone = 0.05;

//safety factor in detection of leaving the road
static final float roadSafety = 0.02;

//player image
static final float playerWidth = 0.05;
static final float playerHeight = 0.05;

//visual occlusion
static final boolean occlusionEnabled = false;
boolean visible = true;

//player position
volatile float playerPosx = 0.5;

//Steering Control
volatile float steerAngle = 0.0;
volatile float steerTorque = 0.0;

//keyboard control
static final float steerKeyStep = 0.01; //one press of the left or right key changes the steering angle by this much, in radians

//Frame rate and timing stuff
int fcount= 0;
int lastm = 0;
int messagecount = 0;
int worldcount = 0;

//time for world simulation
int ctime = 0;//current time
int ltime = 0;//last time

//wallforce
static final float kwall = 20.0; //force constant for wall

//shared control
static final float kFeedback = 5.0; //force coefficient for shared control
static final float alphaFeedback = 1.0; //fraction of force applied

//road ideal positions
volatile float idealPosX = 0; //position of center of road (in fraction of screen)
volatile float idealVelX = 0; //velocity of road center (in fraction of screen per second)

void setup() {
  //size(640, 480, P3D);
  size(800, 600);//, P3D);
  frameRate(60);
  rectMode(RADIUS); // I like to draw around the center position of the rectangles
  ellipseMode(RADIUS); // I like to draw around the center position of the circles
  
  strokeCap(ROUND); //line ends should be rounded
  strokeJoin(ROUND); //lines join in rounded edge, for the road

  //hapkit communication
  //initSerial();

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
  drawDetectFailure();
  drawIdealPos();
  
  
  drawStats();
  
  
  
  fcount += 1;
  int m = millis();
  if (m - lastm > 1000) {
    print("fps: " + fcount + "; ");
    print("worldupd: " + worldcount + "; ");
    println("motormsg: " + messagecount + "; ");
    messagecount = 0;
    worldcount = 0;
    fcount = 0;
    lastm = m;
   // print("steertorque: " + steerTorque);
   
   /***********************  visibility occlusion ********************************/
   if(occlusionEnabled) {
     if(visible) {
       visible = false;
     }
     else {
       visible = true;
     }
   }
   
  }
  if(!visible) {
     background(0);
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
    vertex(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  endShape();
  stroke(255,0,0);
  strokeWeight(2);
  beginShape();
  for (int n = 0; n < nroadPositions; n++) {
    vertex(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    //line(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height,roadPositions[n - 1]*width, (1 - (n - 1 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  endShape();
  stroke(255);
  fill(255);
}

void drawIdealPos() {
  fill(0,255,0);
  noStroke();
  ellipse(idealPosX*width, height-10, 10, 10);
  stroke(255);
  fill(255);
}

void drawDetectFailure() {
  if(abs(idealPosX - playerPosx) > (roadWidth/2 + roadSafety - playerWidth)) {
    stroke(255,0,0);
    strokeWeight(20);
    line(0,0,0,height);
    line(width,0,width,height);
    stroke(255);
  }
}

void drawStats() {
  stroke(0,255,0);
  strokeWeight(20);
  line(0,0,width,0);
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

//runs the world - moves block down according to velocity, creates new blocks as blocks leave the world, moves player according to steering angle and applies feedback forces
void runWorld() {
  while (true) {
    ctime = millis();
    
    //moving the world
    float move = ((float) (ctime - ltime))*worldVelocity/1000; //time in ms, so we divide by 1000
    roadYPosition += move; //move forward by move
    if(roadYPosition > roadStepY) { //we have moved more than a step, we can jump to next step and create a new step
      roadYPosition -= roadStepY;
      for (int n = 0; n < (nroadPositions - 1); n++) {
        roadPositions[n] = roadPositions[n+1]; //move steps along
      }
      //randomly assign new step position
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
    
    
    
    
    
    /*******************************  Applying Forces  ********************************/ 
    //edge of window forces
    if(playerPosx > 1 - marginZone) {
     steerTorque = -kwall*(playerPosx - (1 - marginZone));
    }
    else if(playerPosx < marginZone) {
     steerTorque = kwall*(marginZone - playerPosx);
    } 
    else {
      steerTorque = 0.0;
    }  
    
    //shared control forces
    idealPosX = roadPositions[nroadPositionsBeneath] + (roadYPosition/roadStepY)*(roadPositions[nroadPositionsBeneath + 1]-roadPositions[nroadPositionsBeneath]); //position of center of road
    idealVelX = (roadPositions[nroadPositionsBeneath + 1] - roadPositions[nroadPositionsBeneath])*worldVelocity/roadStepY; //velocity, in fraction of screen per second, if we just follow the center of the road all the time , d(roadYPosition)/dt = worldVelocity
    
    
    
    //float idealPosX = roadPositions[1] + (roadYPosition/roadStepY)*(roadPositions[2]-roadPositions[1]); //doing it a step ahead
    steerTorque += alphaFeedback*kFeedback*(idealPosX - playerPosx);
    
    
    //saturation
    if(steerTorque >= steerTorqueMax) {
      steerTorque = steerTorqueMax;
    }
    else if(steerTorque <= -steerTorqueMax) {
      steerTorque = -steerTorqueMax;
    }
    ltime = ctime;
    try {
      Thread.sleep(0,100000);//wait 0ms and 100,000ns (=0.1ms(
    }
    catch(Exception E)
    { //throws InterruptedException
    }
    worldcount += 1;
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
    myPort1.write(String.format("%.3f", steerTorque)+'\n'); //send torque to hapkit motor
    //print("Torque Sent: " + String.format("%.3f", steerTorque)+'\n');
    messagecount += 1;
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
        messagecount += 1;
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
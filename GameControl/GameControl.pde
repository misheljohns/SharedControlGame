/**********  Code to simulate game and provide assistance methods **********/

//TODO: 
//increasing difficulty, levels - set velocity and max slope change
//display highscores
//randomly assign conditions to users
//export performance data to file - user ID, game condition, section condition, DVs
//create qualtrics survey
//better colours, actual road image, 
//curves instead of lines

//LATER:
//more shared control functions

//NOTE:
// made variables accessed by the threads volatile, so that any updates are seen immediately by the other threads
// I do not need to make it atomic, because there's one thread setting the value and another reading it

//file writer for appending data to performance file
import java.io.FileWriter;

//game state
int gameState = 1;

//single available path
static final int nroadPositions = 15; //number of road positions cached, roadStepY*nroadPositions has to be greateer than 1 to be beigger than the screen size
static final float roadStepY = 0.1;//0.1; //the road horizontal position changes every vertical movement that is roadStepY fraction of the screen size
//static final float roadStepX = 0.08; //max sideways step of the road in one vertical step
static final float roadStepSlope = 0.1; //max change in average slope between two sections of the road
static final float roadWidth = 0.15; //width of the road
static final int nroadPositionsBeneath = 2; //number of road positions that extend beneath the screen - this is to avoid changes in the road when one vertex is removed at the bottom - we need two vertices below the screen to maintain position and slope
static final float roadSlopeLimit = 0.6; //the max distance at which the slope line can intersect the edge (smaller values allower shallower slopes = more difficult play) 

//store path
volatile float roadPositions[]; //positions of the road
volatile float roadSlopes[]; //we now use slopes to calculate positions; this holds delta_x/delta_y
volatile float roadControlPoints[]; //points calculated according to the slope, in order to plot quadratic bezier curves
volatile float roadYPosition = 0.0; //vertical movement of the world

//speed of movement
volatile float worldVelocity = 0.9; //number of frame sizes that is passed in one second
static final float playerVelocity = 0.5; //adjusting how much the player moves with the steering or keypress

//alternate movement - steering angle corresponds to actual position
static final float steerScale = 1.0; //1 rad of rotation = steerScale movement on screen
static final float steerTorqueMax = 2.0; //max force that can be applied to the motor

//margin zones
static final float marginZone = 0.05;
static final float cautionDist = 0.02;

//safety factor in detection of leaving the road
static final float roadSafety = 0.02;

//player image
static final float playerWidth = 0.03;
static final float playerHeight = 0.05;

//visual occlusion
static final boolean occlusionEnabled = false;
boolean visible = true;

//player position
volatile float playerPosX = 0.5;

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
volatile int feedbackType = 1; //type of shared control

//road ideal positions
volatile float idealPosX = 0; //position of center of road (in fraction of screen)
volatile float idealVelX = 0; //velocity of road center (in fraction of screen per second)


//player score etc
volatile int playerScore = 0;
volatile float playerTime = 0.0;
//int lives = 3;
String playerLevel = "";

//durations of levels
static final float trainingTime = 30.0; //30s of training
static final float unsupportedTime1 = 30.0 + 45.0; //45s
static final float supportedTime1 = 30.0 + 45.0 + 45.0;
static final float unsupportedTime2 = 30.0 + 45.0 + 45.0 + 45.0;

//player performance data
float meanSquaredError = 0.0; //mean performance data
long nError = 0; //number of points this mean is over

//intro screen
String username = "";
int userId = 0;

//file data output
PrintWriter rawOutput;
FileWriter perfOutput; //lets us append to a file

//levels
static final float trainingVelocity = 0.09;
static final float gameVelocity = 0.9;

void setup() {
  //size(640, 480, P3D);
  //size(1366, 768);//, P3D);
  fullScreen();
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

} 

void draw () {
  background(0);

  switch(gameState) {
    case 0: //gameplay
      drawRoad();
      drawPlayer(playerPosX);
      drawDetectFailure();
      drawIdealPos();
      
      getPerformance();
      drawStats();
      
      changeLevels();
      writeRawData();
      
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
        //println("slopes[0]: " + roadSlopes[0]);
      }
      break;
    case 1: //intro screen
      textSize(40);
      fill(0,0,255);
      text("Username: "+username, 300, 0.5*height);
      break;
      
    case 2: //end screen
      textSize(40);
      fill(0,0,255);
      text("The study has ended. Thank you for your participation, "+username, 50, 0.5*height);
      break;
  }
     
   /***********************  visibility occlusion ********************************/
  int m = millis();
  if (m - lastm > 1000) {
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


void changeLevels() {
  if((playerTime > 0) && playerLevel == "") {
    playerLevel = "Training";
    worldVelocity = trainingVelocity;
    feedbackType = 0;//no shared control
  }
  else if(playerLevel == "Training" && (playerTime < trainingTime)) { //in training mode, slowly increase velocity
    if(worldVelocity < gameVelocity) {
      worldVelocity += 0.001; //increase speed by 0.001 each frame (when this function is called in draw()
    }
  }
  else if((playerTime > trainingTime) && playerLevel == "Training") { //training ends, moving into first unsupported section
    writePerfData(); //write performance data before shifting level
    playerLevel = "Unsupported1";
    feedbackType = 0;//no shared control
    meanSquaredError = 0.0; //reset perfromance data
    nError = 0;
  }
  else if((playerTime > unsupportedTime1) && playerLevel == "Unsupported1") { //unsupported1 ends, moving into first supported section
    writePerfData(); //write performance data before shifting level
    playerLevel = "Supported1";
    feedbackType = 1;//shared control
    meanSquaredError = 0.0; //reset perfromance data
    nError = 0;
  }
  else if((playerTime > supportedTime1) && playerLevel == "Supported1") { //supported1 ends, moving into first unsupported section
    writePerfData(); //write performance data before shifting level
    playerLevel = "Unsupported2";
    feedbackType = 0;//no shared control
    meanSquaredError = 0.0; //reset perfromance data
    nError = 0;
  }
  else if((playerTime > unsupportedTime2) && playerLevel == "Unsupported2") {//unsupported2 ends
    writePerfData(); //write performance data before shifting level
    playerLevel = "End";
    gameState = 2;
  }

}

void getPerformance() {
  float error = playerPosX - idealPosX;
  meanSquaredError = (meanSquaredError*nError + error*error)/++nError;
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
  strokeWeight(1);//(int)(roadWidth*width));
  beginShape();
  vertex(roadPositions[0]*width, (1 - (0 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  for (int n = 1; n < nroadPositions; n++) {
    vertex(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    float yc = (roadPositions[n] - roadPositions[n-1])/(roadSlopes[n] - roadSlopes[n-1]) + roadSlopes[n]*roadStepY/(roadSlopes[n] - roadSlopes[n-1]) +  n*roadStepY;
    //quadraticVertex((roadPositions[n-1] + roadSlopes[n-1]*(yc - n*roadStepY))*width,(yc + nroadPositionsBeneath*roadStepY + roadYPosition)*height,roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    //quadraticVertex((roadPositions[n-1] + (roadSlopes[n]*(roadPositions[n]-roadPositions[n-1]) + roadSlopes[n]*roadSlopes[n-1]*roadStepY)/(roadSlopes[n] - roadSlopes[n-1]))*width,(1 - (n - 0.5 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height,roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    point((roadPositions[n-1] + (roadSlopes[n]*(roadPositions[n]-roadPositions[n-1]) + roadSlopes[n]*roadSlopes[n-1]*roadStepY)/(roadSlopes[n] - roadSlopes[n-1]))*width,(1 - (n - 0.5 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  endShape();
  /*
  stroke(255,0,0);
  strokeWeight(2);
  beginShape();
  for (int n = 0; n < nroadPositions; n++) {
    vertex(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    //line(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height,roadPositions[n - 1]*width, (1 - (n - 1 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  endShape();
  */
  stroke(0,0,255);
  for (int n = 0; n < nroadPositions; n++) {
    line(0, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height, width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  
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
  if(abs(idealPosX - playerPosX) > (roadWidth/2 + roadSafety - playerWidth)) {
    stroke(255,0,0); //red
    strokeWeight(20);
    line(0,0,0,height);
    line(width,0,width,height);
    stroke(255);
  }
  else if(abs(idealPosX - playerPosX) > (roadWidth/2 - playerWidth - cautionDist )) {
    stroke(200,200,0); //yellow
    strokeWeight(20);
    line(0,0,0,height);
    line(width,0,width,height);
    stroke(255);
  }
  else {
    stroke(50,255,50); //green
    strokeWeight(20);
    line(0,0,0,height);
    line(width,0,width,height);
    stroke(255);
  }
}

void drawStats() {
  stroke(0,255,0);
  strokeWeight(40);
  line(0,0,width,0);
  textSize(20);
  fill(255);
  text("Score: "+Integer.toString(playerScore), 100, 15);
  text("Level: "+playerLevel, 0.5*width - 50, 15);
  text("Error: "+Float.toString(sqrt(meanSquaredError)), width - 200, 15);
}

//road positions at Start
void initPositions() {
  roadPositions = new float[nroadPositions];
  roadSlopes = new float[nroadPositions];
  roadControlPoints = new float[nroadPositions];
  roadPositions[0] = 0.5;
  roadSlopes[0] = 0;
  for (int n = 1; n < nroadPositions; n++) {
    roadSlopes[n] = random(max(-roadPositions[n-1]/roadSlopeLimit,roadSlopes[n-1] - roadStepSlope), 
                           min((1 - roadPositions[n-1])/roadSlopeLimit,roadSlopes[n-1] + roadStepSlope));
    roadPositions[n] = roadPositions[n-1] + roadStepY*(roadSlopes[n-1] + roadSlopes[n])/2;
  }
}



//moves player with the arrow keys
void keyPressed() {
  switch(gameState) {
    case 0: //gameplay
      if (keyCode == RIGHT) {
        steerAngle += steerKeyStep;
      } else if (keyCode == LEFT) {
        steerAngle -= steerKeyStep;
      }
      break;
    case 1: //intro screen
      if(key == BACKSPACE) { //remove one character
        if (username != null && username.length() != 0) {
          username = username.substring(0, username.length()-1);
        }
      }
      else if(key == '\n') { //done, set username, switch to game
        gameState = 0;
        openFiles();
      }
      else if(username.length() <= 10){
        username += key;
      }
      break;
  }
}

//called when the program is exited
void stop(){
  closeFiles();
  super.stop();
}
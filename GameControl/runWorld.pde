
//runs the world - moves block down according to velocity, creates new blocks as blocks leave the world, moves player according to steering angle and applies feedback forces
void runWorld() {
  while (true) {  //run when game is being played
    ctime = millis();
    float move = 0;
    //moving the world
    if(gameState == 0) {
    move = ((float) (ctime - ltime))*worldVelocity/1000; //time in ms, so we divide by 1000
    playerTime += ((float) (ctime - ltime))/1000;
    }
    roadYPosition += move; //move forward by move
    if(roadYPosition > roadStepY) { //we have moved more than a step, we can jump to next step and create a new step
      roadYPosition -= roadStepY;
      playerScore += 1; //player score increases with each segment passed
      for (int n = 0; n < (nroadPositions - 1); n++) {
        roadPositions[n] = roadPositions[n+1]; //move steps along
        roadSlopes[n] = roadSlopes[n+1]; //move steps along
      }
      //randomly assign new step position
      roadSlopes[nroadPositions - 1] = random(max(-roadPositions[nroadPositions - 2]/roadSlopeLimit,roadSlopes[nroadPositions - 2] - roadStepSlope), min((1 - roadPositions[nroadPositions - 2])/roadSlopeLimit,roadSlopes[nroadPositions - 2] + roadStepSlope));
      roadPositions[nroadPositions - 1] = roadPositions[nroadPositions - 2] + roadStepY*(roadSlopes[nroadPositions - 2] + roadSlopes[nroadPositions - 1])/2;
    }
    
    /****************************  Player position control  ****************************/ 
    //update player position
    //playerPosX += playerVelocity*steerAngle*((float) (ctime - ltime))/1000; 
    playerPosX = 0.5 + steerAngle*steerScale;
    
    
    
    
    float wallTorque = 0;
    /*******************************  Applying Forces  ********************************/ 
    //edge of window forces
    if(playerPosX > 1 - marginZone) {
     wallTorque = -kwall*(playerPosX - (1 - marginZone));
    }
    else if(playerPosX < marginZone) {
     wallTorque = kwall*(marginZone - playerPosX);     
    } 
    else {
      wallTorque = 0.0;
    }  
    
    //shared control forces
    idealPosX = roadPositions[nroadPositionsBeneath] + (roadYPosition/roadStepY)*(roadPositions[nroadPositionsBeneath + 1]-roadPositions[nroadPositionsBeneath]); //position of center of road
    idealVelX = (roadPositions[nroadPositionsBeneath + 1] - roadPositions[nroadPositionsBeneath])*worldVelocity/roadStepY; //velocity, in fraction of screen per second, if we just follow the center of the road all the time , d(roadYPosition)/dt = worldVelocity
      
    
    //float idealPosX = roadPositions[1] + (roadYPosition/roadStepY)*(roadPositions[2]-roadPositions[1]); //doing it a step ahead
    
    float sharedTorque = 0;
    switch(feedbackType) {
      case 0:
        sharedTorque = 0;
        break;
      
      case 1:
        sharedTorque = alphaFeedback*kFeedback*(idealPosX - playerPosX);
        break;
    }
    
    
    steerTorque = wallTorque + sharedTorque;
    //println(steerTorque);
    //saturation
    if(steerTorque >= steerTorqueMax) {
      steerTorque = steerTorqueMax;
    }
    else if(steerTorque <= -steerTorqueMax) {
      steerTorque = -steerTorqueMax;
    }
    if(gameState != 0) {//not in gameplay mode
      steerTorque = 0;
    }
    ltime = ctime;
    try {
      //Thread.sleep(0,100000);//wait 0ms and 100,000ns (=0.1ms(
    }
    catch(Exception E)
    { //throws InterruptedException
    }
    worldcount += 1;
  }
}
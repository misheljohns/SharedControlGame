void drawPlayer() {
  fill(255,0,0);
  noStroke();
  //ellipse(playerPosX*width, height-10, playerWidth*width, playerHeight*height);
  triangle(playerPosX*width - playerWidth*width, height, playerPosX*width, height - playerHeight*height, playerPosX*width + playerWidth*width, height);
  stroke(255);
  fill(255);
}

void drawRoad() {
  background(19,156,28); //green
  //background(178,103,38); //brown
  noFill();
  
  stroke(178,103,38);
  strokeWeight((int)(roadWidth*width) + 40);
  beginShape();
  for (int n = 0; n < nroadPositions; n++) {
    vertex(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    //line(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height,roadPositions[n - 1]*width, (1 - (n - 1 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  endShape();
  
  
  
  stroke(128,128,128);
  strokeWeight((int)(roadWidth*width));
  beginShape();
  for (int n = 0; n < nroadPositions; n++) {
    vertex(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    //line(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height,roadPositions[n - 1]*width, (1 - (n - 1 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  endShape();
  
  /*
  stroke(57,41,23);
  strokeWeight(10);//(int)(roadWidth*width));
  beginShape();
  vertex(roadPositions[0]*width, (1 - (0 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  for (int n = 1; n < nroadPositions; n++) {
    vertex(roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    float yc = (roadPositions[n] - roadPositions[n-1])/(roadSlopes[n] - roadSlopes[n-1]) + roadSlopes[n]*roadStepY/(roadSlopes[n] - roadSlopes[n-1]) +  n*roadStepY;
    //quadraticVertex((roadPositions[n-1] + roadSlopes[n-1]*(yc - n*roadStepY))*width,(yc + nroadPositionsBeneath*roadStepY + roadYPosition)*height,roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    //quadraticVertex((roadPositions[n-1] + (roadSlopes[n]*(roadPositions[n]-roadPositions[n-1]) + roadSlopes[n]*roadSlopes[n-1]*roadStepY)/(roadSlopes[n] - roadSlopes[n-1]))*width,(1 - (n - 0.5 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height,roadPositions[n]*width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
    //point((roadPositions[n-1] + (roadSlopes[n]*(roadPositions[n]-roadPositions[n-1]) + roadSlopes[n]*roadSlopes[n-1]*roadStepY)/(roadSlopes[n] - roadSlopes[n-1]))*width,(1 - (n - 0.5 - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  endShape();
  */
  /*
  stroke(0,0,255);
  for (int n = 0; n < nroadPositions; n++) {
    line(0, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height, width, (1 - (n - nroadPositionsBeneath)*roadStepY + roadYPosition)*height);
  }
  */
  
  stroke(255);
  fill(255);
}

void drawIdealPos() {
  fill(0,255,0);
  stroke(0,255,0);
  strokeWeight(4);
  //ellipse(idealPosX*width, height-10, 10, 10);
  for (int i = 0; i <= 5; i++) {
    float x = lerp(idealPosX*width - playerWidth*width, idealPosX*width, i/5.0) + 10;
    float y = lerp(height, height - playerHeight*height, i/5.0);
    point(x, y);
  }
  for (int i = 0; i <= 5; i++) {
    float x = lerp(idealPosX*width, idealPosX*width + playerWidth*width, i/5.0) + 10;
    float y = lerp(height - playerHeight*height, height, i/5.0);
    point(x, y);
  }
  for (int i = 0; i <= 5; i++) {
    float x = lerp(idealPosX*width + playerWidth*width, idealPosX*width - playerWidth*width, i/5.0) + 10;
    float y = lerp(height, height, i/5.0);
    point(x, y);
  }
  //triangle(playerPos*width - playerWidth*width, height, playerPos*width, height - playerHeight*height, playerPos*width + playerWidth*width, height);
  
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
  stroke(0);
  strokeWeight(40);
  line(0,0,width,0);
  textSize(20);
  fill(255);
  text("Score: "+Integer.toString(playerScore), 100, 15);
  text("Level: "+playerLevel, 0.5*width - 50, 15);
  text("Error: "+Float.toString(sqrt(meanSquaredError)), width - 200, 15);
}
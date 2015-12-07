//player performance data
float meanSquaredError = 0.0; //mean performance data
long nError = 0; //number of points this mean is over
int reversalCount = 0; //number of steering reversals

float minSteerAngle = 0;
float maxSteerAngle = 0;
boolean directionRight = true;
boolean directionFlipped = false;
float prevSteerAngle = 0;
static final float reversalThreshold = 0.1; //0.1 rad is threshold for reversal

void getPerformance() {
  float error = playerPosX - idealPosX;
  meanSquaredError = (meanSquaredError*nError + error*error)/++nError;
  
  if(directionRight == true) {
    if(steerAngle > prevSteerAngle){ //still going right
      if(((steerAngle - minSteerAngle) > reversalThreshold) && directionFlipped) {//is waiting to reach threshold, reaches, so reversal counted
        reversalCount++;
        directionFlipped = false;
      }
    }
    else {//direction has changed from going right to going left
      directionFlipped = true;
      maxSteerAngle = steerAngle;
      directionRight = false;
    }
  }
  else { 
    if(steerAngle < prevSteerAngle){ //still going left
      if(((maxSteerAngle - steerAngle) > reversalThreshold) && directionFlipped) {//is waiting to reach threshold, reaches, so reversal counted
        reversalCount++;
        directionFlipped = false;
      }
    }
    else {//direction has changed from going right to going left
      directionFlipped = true;
      minSteerAngle = steerAngle;
      directionRight = true;
    }
  }  
}
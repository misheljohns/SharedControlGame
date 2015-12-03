
void getPerformance() {
  float error = playerPosX - idealPosX;
  meanSquaredError = (meanSquaredError*nError + error*error)/++nError;
}
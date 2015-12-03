
void closeFiles() {
  rawOutput.flush();  // Writes the remaining data to the file
  rawOutput.close();  // Finishes the file
  try{
    perfOutput.flush();  // Writes the remaining data to the file
    perfOutput.close();  // Finishes the file
    }
  catch(IOException e) {
    
  }
}

void openFiles() {
  rawOutput = createWriter("../Data/raw_"+username+".csv");
  try{
    perfOutput = new FileWriter("../Data/perf_data.csv",true); //the true will append the new data
  }
  catch(IOException e) {
    
  }
}

void writePerfData() {
  try{
    perfOutput.write(username+","+playerLevel+","+playerTime+","+meanSquaredError);
  }
  catch(IOException e) {
    
  }
}

void writeRawData() {
  rawOutput.println(playerPosX+","+idealPosX+","+steerTorque+","+idealVelX);
}
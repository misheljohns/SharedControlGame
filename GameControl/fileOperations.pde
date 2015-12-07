
void closeFiles() {
  rawOutput.flush();  // Writes the remaining data to the file
  rawOutput.close();  // Finishes the file
  try{
    perfOutput.flush();  // Writes the remaining data to the file
    perfOutput.close();  // Finishes the file
    }
  catch(IOException e) {
    println("file close failed :"+e);
    exit();
  }
}

void openFiles() {
  rawOutput = createWriter("../Data/raw_"+username+".csv");
  try{
    perfOutput = new FileWriter("C:/Storage/Acads/ME327/Project/Code/Data/perf_data.csv",true); //the 'true' will append new data
  }
  catch(IOException e) {
    println("file open failed :"+e);
    exit();
  }
}

void writePerfData() {
  try{
    perfOutput.write(username+","+playerLevel+","+playerTime+","+meanSquaredError+","+reversalCount+"\n");
  }
  catch(IOException e) {
    println("file write failed :"+e);
    exit();
  }
}

void writeRawData() {
  rawOutput.println(playerPosX+","+idealPosX+","+steerTorque+","+idealVelX);
}
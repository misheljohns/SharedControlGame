//TCPsocket for motor control
import processing.net.*;
import java.nio.ByteBuffer;
int port = 10002; 
int cnt = 0;
Server myServer;        
byte[] byteBuffer = new byte[8];

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
        println("Data received : " + data_received);
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
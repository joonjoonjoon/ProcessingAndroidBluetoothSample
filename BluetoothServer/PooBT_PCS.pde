/*
 * PooBT_ PC Server
 * Jonatan Van Hove - JVAH@ITU.DK
 * 22/03/2012
 *
 * @author Jonatan Van Hove
 * -- Heavily based on work by Luu Gia Thuy's Java Android example http://luugiathuy.com/2011/02/android-java-bluetooth/
 *
 */

import javax.bluetooth.DiscoveryAgent;
import javax.bluetooth.LocalDevice;
import javax.bluetooth.UUID;
import javax.microedition.io.Connector;
import javax.microedition.io.StreamConnection;
import javax.microedition.io.StreamConnectionNotifier;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Method;

public class PooBT_PCS {
  //------------------------------------------------------------
  // These parameters need to be the same over all PooBT modules
  //------------------------------------------------------------
  final String uuid = "04c6093b-0000-1000-8000-00805f9b34fb";       // Should be the same as in the server
  final int bufferSize = 32;
  //------------------------------------------------------------
  
  Object context;
  boolean btReady = false;
  boolean btFailed = false;
  boolean btDebug = true;
  ConnectThread connectThread;
  ManageThread manageThread;
  Method btEvent;

  // ========================================================
  // Constructor
  //
  // PooBT_PCS(parent)
  //
  // Should be used with 'this' as argument.  
  // ========================================================
  public PooBT_PCS(Object parent) {
    this.context = parent;
  }

  // ========================================================
  // init()
  //
  // Sets up the event listener
  // ========================================================  
  public void init()
  {
    try
    {
      // Setup the listener for when packets are received.      
      btEvent = context.getClass().getMethod("PooBT_ReceivedListener", new Class[] { byte[].class });
    }
    catch (Exception e) {
      // No listener found
      btFailed = true;
      debugPrint("You should set up PooBT_ReceivedListener(byte[]) first.");
      debugPrint(e.getMessage());
    }        
    
    connectThread = new ConnectThread(); 
    connectThread.start();
  }
  
  // ========================================================
  // write(bytes)
  //
  // bytes = the bytes you wish to write.
  // Writes a bytestream to the server
  // ======================================================== 
  public void write(byte[] bytes)
  {
    if(btReady)
    {
      manageThread.write(bytes);
    }
  }
  
  // ========================================================
  // Class ConnectThread (extends Thread)
  //
  // A separate thread to attempt connection. 
  // Connection polling blocks until it either fails or succeeds, hence the thread.
  // ======================================================== 
  private class ConnectThread extends Thread {
    public ConnectThread()
    {
    }
    
    public void run() {
      // retrieve the local Bluetooth device object
      LocalDevice local = null;

      StreamConnectionNotifier notifier;
      StreamConnection connection = null;

      // setup the server to listen for connection
      try {
        local = LocalDevice.getLocalDevice();
        local.setDiscoverable(DiscoveryAgent.GIAC);
        String url = "btspp://localhost:" + uuid.replace("-", "") + ";name=RemoteBluetooth";
        notifier = (StreamConnectionNotifier)Connector.open(url);
      } 
      catch (Exception e) {
        e.printStackTrace();
        return;
      }

      // waiting for connection
      while (true) {
        try {
          debugPrint("waiting for connection...");
          connection = notifier.acceptAndOpen();

          // When the connection arrives, start it in a new thread 
          manageThread = new ManageThread(connection);
          manageThread.start();
          btReady = true;
        } 
        catch (Exception e) {
          e.printStackTrace();
          return;
        }
      }
    }
  }

  // ========================================================
  // ProcessConnectionThread()
  //
  // Once a connection is made, this thread will take over 
  //
  // Modification from: http://luugiathuy.com/2011/02/android-java-bluetooth/
  // ========================================================
  private class ManageThread extends Thread{
    private StreamConnection mConnection;
    private OutputStream outputStream;

    public ManageThread(StreamConnection connection)
    {
      mConnection = connection;
    }

    public void run() {
      try {
        byte[] buffer = new byte[bufferSize];  // buffer store for the stream
        int bytes; // bytes returned from read()

        // prepare to receive data
        InputStream inputStream = mConnection.openInputStream();
        outputStream = mConnection.openOutputStream();

        debugPrint("waiting for input...");

        while (true) {
          bytes = inputStream.read(buffer);
          if (btEvent != null)
          {
            try {
              // Invoke the main apps way of dealing with transmitted data
              debugPrint("Receiving data...");              
              btEvent.invoke(context, new Object[] { buffer });
              buffer = new byte[bufferSize];
            }
            catch (Exception e) {
              debugPrint(e.getMessage());
            }
          }
        }
      } 
      catch (Exception e) {
        e.printStackTrace();
      }
    }
    
    public void write(byte[] bytes) {
      try {
        debugPrint("Sending data...");
        outputStream.write(bytes);
        outputStream.flush();
      } 
      catch (IOException e) {
        debugPrint("Something went wrong while sending");
      }
    }    
  }

  // ========================================================
  // debugPrint(message)
  //
  // Internal method to print debug info to the log. Can be suppressed by setting btDebug to false
  // ========================================================  
  private void debugPrint(String message)
  {
    if (btDebug)
    {
      println("PooBT PC Server: " + message);
    }
  }
}


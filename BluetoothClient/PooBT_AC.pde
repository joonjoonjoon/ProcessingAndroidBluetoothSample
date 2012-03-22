/*
 * PooBT_ Android Client
 * Jonatan Van Hove - JVAH@ITU.DK
 * 22/03/2012
 *
 * @author Jonatan Van Hove
 * -- Most code comes from http://developer.android.com/guide/topics/wireless/bluetooth.html
 */

import android.bluetooth.*;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.BroadcastReceiver;
import android.util.Log;
import java.util.UUID;
import java.lang.reflect.Method;

public class PooBT_AC {
  //------------------------------------------------------------
  // These parameters need to be the same over all PooBT modules
  //------------------------------------------------------------
  final String uuid = "04c6093b-0000-1000-8000-00805f9b34fb";       // Should be the same as in the server
  final int bufferSize = 32;
  //------------------------------------------------------------

  final int REQUEST_ENABLE_BT = 2;                            // Local constant required to init BT

  Context context;
  BluetoothAdapter mBluetoothAdapter;


  String btRemoteName;
  Method btEvent;
  boolean btReady = false;
  boolean btFailed = false;
  boolean btDebug = true;

  ConnectThread connectThread;                                // launched when connection is initiated
  ManageThread manageThread;                                  // launched when connection is successful
  OutputStream mmOutStream;

  // ========================================================
  // Constructor
  //
  // PooBT_AC(parent)
  //
  // Should be used with 'this' as argument.
  // ========================================================
  public PooBT_AC(Context parent)
  {
    this.context = parent;
  }

  // ========================================================
  // isReady()
  //
  // returns true if connection is successfully established.
  // ========================================================
  public boolean isReady()
  {
    return btReady;
  }

  // ========================================================
  // isReady()
  //
  // returns true if connection has failed explicitly.
  // ========================================================
  public boolean isFailed()
  {
    return btFailed;
  }

  // ========================================================
  // init(btRemoteName)
  //
  // btRemoteName = the name of the Bluetooth server device.
  // Attempts to connect to BT server.
  // ========================================================  
  public void init(String btRemoteName)
  {
    this.btRemoteName = btRemoteName;
    btReady = false;
    btFailed = false;
    try
    {
      // Setup the listener for when packets are received.      
      btEvent = context.getClass().getMethod("PooBT_ReceivedListener", new Class[] {  
        byte[].class
      } 
      );
    }
    catch (Exception e) {
      // No listener found
      btFailed = true;
      debugPrint("You should set up PooBT_ReceivedListener(byte[]) first.");
      debugPrint(e.getMessage());
    }    

    debugPrint("Launching BT app");
    mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
    if (mBluetoothAdapter == null) {
      debugPrint("Device does not support BT");
      btFailed = true;
    }
    else
    {
      debugPrint("Device supports BT");
      if (!mBluetoothAdapter.isEnabled()) {
        Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
        startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT);
        debugPrint("Enabling BT");
      }
      debugPrint("BT enabled");

      // We need to register a bc server to catch any incoming messages from the discovery service
      debugPrint("Registering broadcast server"); 
      registerReceiver(mReceiver, new IntentFilter(BluetoothDevice.ACTION_FOUND)); 

      // startDiscovery() returns true if the discovery was successful.
      debugPrint("Enabling discovery");
      if (mBluetoothAdapter.startDiscovery())
      {
        debugPrint("Discovery started");
      }
      else
      { 
        btFailed = true;
        debugPrint("Discovery failed to start");
      }
    }
  }

  // ========================================================
  // destroy()
  //
  // Clean up method. Needs to be in onDestroy() in the main activity
  // ======================================================== 
  public void destroy()
  {
    unregisterReceiver(mReceiver);
    mBluetoothAdapter.cancelDiscovery();
  }

  // ========================================================
  // write(bytes)
  //
  // bytes = the bytes you wish to write.
  // Writes a bytestream to the server
  // ======================================================== 
  public void write(byte[] bytes)
  {
    if (btReady)
    {
      try {
        debugPrint("Sending data...");
        mmOutStream.write(bytes);
        mmOutStream.flush();
      } 
      catch (Exception e) {
        debugPrint("Something went wrong while sending");
      }
    }
  }

  // ========================================================
  // Class ConnectThread (extends Thread)
  //
  // A separate thread to attempt connection. 
  // Connection blocks until it either fails or succeeds, hence the thread.
  //
  // Modification from: Source: http://developer.android.com/guide/topics/wireless/bluetooth.html
  // ======================================================== 
  private class ConnectThread extends Thread {
    private final BluetoothSocket mmSocket;
    private final BluetoothDevice mmDevice;

    public ConnectThread(BluetoothDevice device) {
      // Use a temporary object that is later assigned to mmSocket,
      // because mmSocket is final
      BluetoothSocket tmp = null;
      mmDevice = device;
      // Get a BluetoothSocket to connect with the given BluetoothDevice
      try {
        UUID muuid = UUID.fromString(uuid);

        // WARNING:
        // The original code says this:
        //     tmp = device.createRfcommSocketToServiceRecord(muuid);
        // However this does not work on all devices. 
        // See here: http://stackoverflow.com/questions/3397071/service-discovery-failed-exception-using-bluetooth-on-android
        Method m = device.getClass().getMethod("createRfcommSocket", new Class[] {
          int.class
        }
        );
        tmp = (BluetoothSocket) m.invoke(device, 1);      

        debugPrint(muuid.toString() + " " + tmp.getRemoteDevice());
      } 
      catch (Exception e) { 
        btFailed = true;
        debugPrint(e.getMessage());
      }

      mmSocket = tmp;
    }

    public void run() {
      // Cancel discovery because it will slow down the connection
      mBluetoothAdapter.cancelDiscovery();
      debugPrint("Attempting to connect...");
      try {
        // Connect the device through the socket. This will block
        // until it succeeds or throws an exception
        mmSocket.connect();
      } 
      catch (IOException connectException) {
        debugPrint("Unable to connect.");
        btFailed = true;
        try {
          mmSocket.close();
        }
        catch (IOException closeException2) 
        {
        }
        return;
      }
      debugPrint("We made it! Connection established.");
      btReady = true;                              // let the main app know we're ready
      manageThread = new ManageThread(mmSocket);   // launch the socket manager, again in a separate thread
      manageThread.start();
    }

    public void cancel() {
      try {
        mmSocket.close();
      } 
      catch (IOException e) {
      }
    }
  }

  // ========================================================
  // Class ManageThread (extends Thread)
  //
  // Once a connection is made, this thread will take over 
  //
  // Modification from: http://developer.android.com/guide/topics/wireless/bluetooth.html
  // ======================================================== 
  private class ManageThread extends Thread {
    private final BluetoothSocket mmSocket;
    private final InputStream mmInStream;
    //private final OutputStream mmOutStream;

    public ManageThread(BluetoothSocket socket) {
      mmSocket = socket;
      InputStream tmpIn = null;
      OutputStream tmpOut = null;

      // Get the input and output streams, using temp objects because
      // member streams are final
      try {
        tmpIn = socket.getInputStream();
        tmpOut = socket.getOutputStream();
      } 
      catch (IOException e) {
      }
      mmInStream = tmpIn;
      mmOutStream = tmpOut;
    }

    public void run() {
      byte[] buffer = new byte[bufferSize];  // buffer store for the stream
      int bytes; // bytes returned from read()

      // Keep listening to the InputStream until an exception occurs
      while (true) {
        try {
          // Read from the InputStream
          bytes = mmInStream.read(buffer);
          // Send the obtained bytes to the UI activity

          if (btEvent != null)
          {
            try {
              // Invoke the main apps way of dealing with transmitted data
              debugPrint("Receiving data...");
              btEvent.invoke(context, new Object[] { buffer}            );
              buffer = new byte[bufferSize];
            }
            catch (Exception e) {
              debugPrint(e.getMessage());
            }
          }
        } 
        catch (IOException e) {
          break;
        }
      }
    }


    /* Call this from the main activity to shutdown the connection */
    public void cancel() {
      try {
        mmSocket.close();
      } 
      catch (IOException e) {
      }
    }
  }

  // ========================================================
  // BroadcastReceiver -> Overriding onReceive()
  //
  // Source: http://developer.android.com/guide/topics/wireless/bluetooth.html
  // ========================================================  
  private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
    public void onReceive(Context context, Intent intent) {
      String action = intent.getAction();
      // When discovery finds a device
      if (BluetoothDevice.ACTION_FOUND.equals(action)) {
        // Get the BluetoothDevice object from the Intent
        BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
        // Add the name and address to an array adapter to show in a ListView
        debugPrint(device.getName() + "\n" + device.getAddress());
        if (device.getName().equals(btRemoteName))
        {
          connectThread = new ConnectThread(device);
          connectThread.start();
        }
      }
    }
  };

  // ========================================================
  // debugPrint(message)
  //
  // Internal method to print debug info to the log. Can be suppressed by setting btDebug to false
  // ========================================================  
  private void debugPrint(String message)
  {
    if (btDebug)
    {
      println("PooBT Android Client: " + message);
      Log.w("PooBT", message);
    }
  }
}


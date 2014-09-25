/* --------------------------------------------------------------------------
 * SimpleOpenNI NITE Slider2d
 * --------------------------------------------------------------------------
 * Processing Wrapper for the OpenNI/Kinect library
 * http://code.google.com/p/simple-openni
 * --------------------------------------------------------------------------
 * prog:  Max Rheiner / Interaction Design / zhdk / http://iad.zhdk.ch/
 * date:  03/28/2011 (m/d/y)
 * ----------------------------------------------------------------------------
 * prog:  Edwin Hernandez, PhD
 * date:  06/01/2013 (m/d/y)
 *
 * ----------------------------------------------------------------------------
 */
import SimpleOpenNI.*;
import processing.serial.*;
import java.io.*;

//import Processing.net.*;

SimpleOpenNI          context;

// NITE
XnVSessionManager     sessionManager;
XnVSelectableSlider2D trackPad;

int gridX = 30;
int gridY = 30;
int[][] trackPadArray = new int[gridX][gridY];

Trackpad    trackPadViz;
Training    training; 
Validate    validate;
HTTPPostAirthenticate httppost; 

void setup()
{
  context = new SimpleOpenNI(this,SimpleOpenNI.RUN_MODE_MULTI_THREADED);
   
  // mirror is by default enabled
  context.setMirror(true);
  //context.setMirror(false);
  
  // enable depthMap generation 
  if(context.enableDepth() == false)
  {
     println("Can't open the depthMap, maybe the camera is not connected!"); 
     exit();
     return;
  }
  
  // enable the hands + gesture
  context.enableGesture();
  context.enableHands();
 
  // setup NITE 
  sessionManager = context.createSessionManager("Click,Wave", "RaiseHand");

  trackPad = new XnVSelectableSlider2D(gridX,gridY);
  sessionManager.AddListener(trackPad);

  trackPad.RegisterItemHover(this);
  trackPad.RegisterValueChange(this);
  trackPad.RegisterItemSelect(this);
  
  trackPad.RegisterPrimaryPointCreate(this);
  trackPad.RegisterPrimaryPointDestroy(this);

  // create gui viz
  trackPadViz = new Trackpad(new PVector(context.depthWidth()/2, context.depthHeight()/2,0),
                                         gridX,gridY,6,6,2);  

  size(context.depthWidth(), context.depthHeight()); 
  smooth();
  
   // info text
  println("-------------------------------");  
  println("1. Wave till the tiles get green");  
  println("2. The relative hand movement will select the tiles");  
  println("-------------------------------");   
}

void draw()
{
  // update the cam
  context.update();
  
  // update nite
  context.update(sessionManager);
  
  // draw depthImage
  image(context.depthImage(),0,0);
  fill(000);
  rect(0,0,context.depthWidth(), context.depthHeight());   
  trackPadViz.draw();
}



void keyPressed()
{
  String filename;
  switch(key)
  {
    
  case 'c': 
     println("Clear all");
     training.clearall();
     validate.setState(false);
     training.setState(false);
     break;
  case 't':
     println("Training the system");
     training.setState(true);
     validate.setState(false);
     break;
  case 's':
      println("Training Finish");
      if (validate.getState() != true) {
         filename = "training.png";
      } else {
         filename = "validate.png";
      }
      saveFrame(filename);
      if (validate.getState() == true) {
         training.postTrainImage(filename);
      } else {
         validate.postSignatureData(filename); 
      }
      training.setState(false);
      validate.setState(false);
      training.clearall();
      break;
  case 'v':
      println("Validate ...");
      validate.setState(true);
      training.setState(false);
      break;
  /*case 'n':
      print ("Adding a new Training set ");
      training.addNewSet();
      break;*/
  case 'e':
    // end sessions
    sessionManager.EndSession();
    println("end session");
    break;
  }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// session callbacks

void onStartSession(PVector pos)
{
  println("onStartSession: " + pos);
}

void onEndSession()
{
  println("onEndSession: ");
}

void onFocusSession(String strFocus,PVector pos,float progress)
{
  println("onFocusSession: focus=" + strFocus + ",pos=" + pos + ",progress=" + progress);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// XnVSelectableSlider2D callbacks

void onItemHover(int nXIndex,int nYIndex)
{
  if (training.getState() || validate.getState())
      println("onItemHover: nXIndex=" + nXIndex +" nYIndex=" + nYIndex);
  
  trackPadViz.update(nXIndex,nYIndex);
}

void onValueChange(float fXValue,float fYValue)
{
 // println("onValueChange: fXValue=" + fXValue +" fYValue=" + fYValue);
}

void onItemSelect(int nXIndex,int nYIndex,int eDir)
{
  println("onItemSelect: nXIndex=" + nXIndex + " nYIndex=" + nYIndex + " eDir=" + eDir);
  trackPadViz.push(nXIndex,nYIndex,eDir);
}

void onPrimaryPointCreate(XnVHandPointContext pContext,XnPoint3D ptFocus)
{
  println("onPrimaryPointCreate");
  
  trackPadViz.enable();
}

void onPrimaryPointDestroy(int nID)
{
  //println("onPrimaryPointDestroy");
  
  trackPadViz.disable();
}

/* Training information */
class tInfo {
    int pos_x;
    int pos_y;
    long timestamp;
    
    tInfo(int x, int y, int timestamp) {
          this.pos_x = x;
          this.pos_y = y;
          this.timestamp = timestamp;
    }
}


class HTTPPostAirthenticate {
  String url_train;
  String url_authenticate;
  String returnedValues;   
  
  HTTPPostAirthenticate()
  {
      url_train           = "http://airthenticate.com/api/train.php";
      url_authenticate    = "http://airthenticate.com/api/authenticate.php";
  }
  
  void postData(boolean train, String image_name) {
    String myserver;
    if (train!=true) {
        myserver = url_train;
    }
    else {
        myserver = url_authenticate;
    }
        
    try{
         println("Contacting server ..."+ myserver +"  "+image_name);
         Process process = Runtime.getRuntime().exec("curl -i -F user_id=PrimeSense -F file_contents=@/Users/edwinhm/Downloads/SimpleOpenNI/examples/Nite/AirThenticate/"+image_name+" "+myserver);
         //println("Return data = "+retdata);
         int i = process.waitFor();
 
        // if we have an output, print to screen
        if (i == 0) {
          // BufferedReader used to get values back from the command
          BufferedReader stdInput = new BufferedReader(new InputStreamReader(process.getInputStream()));
          // read the output from the command
          while ( (returnedValues = stdInput.readLine ()) != null) {
            println(returnedValues);
          }
        }
      // if there are any error messages but we can still get an output, they print here
      else {
        BufferedReader stdErr = new BufferedReader(new InputStreamReader(process.getErrorStream()));
        // if something is returned (ie: not null) print the result
        while ( (returnedValues = stdErr.readLine ()) != null) {
          println(returnedValues);
         }
       }

    }
    catch(java.io.IOException e){
      println(e);
    }
    catch (Exception e) {
      println(e);
    }
  }  
  
  
}

/*
*
*/
class Validate {
      ArrayList s_data;
      int Tolerance = 10; // 10% Tolearance from 0 to 100
      boolean state = false;
      
      Validate(){
        s_data = new ArrayList();
      }
      
      void addSignatureData(int x, int y, int timestamp) {
             s_data.add(new tInfo(x,y,timestamp));         
             ///println(" Adding x=" + x +" y="+ y +" Timestamp = "+timestamp ); 
      }
   
      void setState(boolean state) {
          this.state = state;
      }
  
     boolean getState(){
       return state;
     }
     
     void postSignatureData(String fileName) {
        httppost.postData(false, fileName);
     }
}

/* 
*  Training data for Signature 
*/
class Training
{
    int nTimes;
    ArrayList[] t;
    boolean state = false;
    int cur_id = 0;
    
    Training(int nTimes){   
         this.nTimes = nTimes;
         PImage img = loadImage("learning.jpg");       
         t = new ArrayList[nTimes];
         
         for (int k=0; k<nTimes; k++) {
             println(" Initializing...arrays for training "+ k);
             t[k] = new ArrayList();
         }
         //center = center.get();
         image(img, 0, 0); 
     }
     
     boolean getState(){
       return state;
     }
     
     void clearall() {
       this.cur_id = 0;
       for (int x=0; x<gridY; x++){
            for (int y=0; y<gridY; y++) {
                trackPadArray[x][y]=0;
            }
       }
       
       for (int k=0; k<this.nTimes; k++) {
             println(" Initializing...arrays for training "+ k);
             t[k] = new ArrayList();
         } 
     }
     
     void addNewSet() {
         this.cur_id ++;
         println("Adding a new set.... Set ID = "+ this.cur_id);
         if (this.cur_id < this.nTimes) 
            this.cur_id = 0; 
     }
     
     void postTrainImage(String fileName) {
         httppost.postData(true, fileName);  
     }
     
     void addTrainingData(int x, int y, int timestamp ) {      
             t[this.cur_id].add(new tInfo(x,y,timestamp));         
             println(" Adding x=" + x +"y="+ y +" Timestamp = "+timestamp );    
     }
     
     void setState(boolean state) {
          this.state = state;
     }
  
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Trackpad

class Trackpad
{
  int     xRes;
  int     yRes;
  int     width;
  int     height;
  
  boolean active;
  PVector center;
  PVector offset;
  
  int      space;
  
  int      focusX;
  int      focusY;
  int      selX;
  int      selY;
  int      dir;
  
  
  Trackpad(PVector center,int xRes,int yRes,int width,int height,int space)
  {
    this.xRes     = xRes;
    this.yRes     = yRes;
    this.width    = width;
    this.height   = height;
    active        = false;
    training = new Training(5);
    training.setState(false);   
    validate = new Validate();
    validate.setState(false);  
    httppost = new HTTPPostAirthenticate();
    this.center = center.get();
    offset = new PVector();
    offset.set(-(float)(xRes * width + (xRes -1) * space) * .5f,
               -(float)(yRes * height + (yRes -1) * space) * .5f,
               0.0f);
    offset.add(this.center);
    
    this.space = space;
  }
  
  void enable()
  {
    active = true;
    
    focusX = -1;
    focusY = -1;
    selX = -1;
    selY = -1;
  }
  
  void update(int indexX,int indexY)
  {
    focusX = indexX;
    focusY = (yRes-1) - indexY;
  }
  
  void push(int indexX,int indexY,int dir)
  {
    selX = indexX;
    selY =  (yRes-1) - indexY;
    this.dir = dir;
  }
  
  void disable()
  {
    active = false;
  }
  
  void draw()
  {    
      pushStyle();
      pushMatrix();
      int cols = 10;
       
      translate(offset.x,offset.y);
      int rows = 10;
      //rect(
      for(int y=0;y < yRes;y++)
      {
        for(int x=0;x < xRes;x++)
        {
         
          if(active && (selX == x) && (selY == y))
          { // selected object 
            fill(100,100,220,190);
            strokeWeight(3);
            stroke(100,200,100,220);
          } else if (active && (focusX == x) && (focusY == y) && (training.getState()) ){
             int timestamp = millis();
             println("Training on x="+x+" y="+y);
             trackPadArray[x][y] = 1;
             // training.addTrainingData(x,y, timestamp);            
             fill(255, 0, 0);
             strokeWeight(3);
             stroke(255,0,0,0);
          } else if (active && (focusX == x) && (focusY == y) && (validate.getState()) ){
             println("Validating x="+x+" y="+y);
             int timestamp = millis();
             //validate.addSignatureData(x,y, timestamp);   
             trackPadArray[x][y] = 1;
             fill(0, 0, 255);
             strokeWeight(3);
             stroke(0,0,255);
          }
          else if(active && (focusX == x) && (focusY == y))
          { // focus object 
            fill(100,255,100,220);
            strokeWeight(3);
            stroke(100,200,100,220);
          }
          else if(active)
          {  // normal
            strokeWeight(3);
            stroke(100,200,100,190);
            if (trackPadArray[x][y] == 0) {
               noFill();
            }
             else {
               if (training.getState()) {
                  fill(0,0,255);
               } else
                  fill(0,0,255);
               }
            
          }
          else
          {
            //println( "All else");
            strokeWeight(2);
            stroke(200,100,100,60);
            if ((training.getState() == false) && (validate.getState()==false)) {
                noFill();
            }
            else {
               if (training.getState()) {
                  fill(255,0,0);
               } else
                  fill(0,0,255);
            }
          }
           rect(x * (width + space),y * (width + space),width,height);  
        }
      }
    popMatrix();
    popStyle();  
  }
}

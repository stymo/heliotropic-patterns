import java.util.HashSet;
import java.util.Arrays;

import oscP5.*;
import netP5.*;

/**
 * Animation 
 *
 * Listens for OSC messages from Supercollider and maps values from those messages to determine
 * animation paramters. 
 */


// Map of file path to map of grid size (num images per side) to PImage appropriately scaled
// Ex: {'/some/path/data/my_img.jpg': {3: <PImage scaled for drawing 3x3 grid>}}
HashMap<String, HashMap<Integer, PImage>> allImgs = new HashMap<>();

// Map of "voice" or data stream from SuperCollider to that voice's current value
// Ex: {"/vc0": 42} 
HashMap<String, Integer> scVoiceToCurrVal = new HashMap<>();

// Map of grid cell to sc "voice" number
// Ex: {42: "vc3"} means grid cell 42 is listening to SC voice vc3
HashMap<Integer, String> gridCellToScVoice = new HashMap<>();

// List of absolute paths to all images that are currently loaded in animation. 
// Usually only showing a subset of this the on grid at any time.
ArrayList<String> currImgPool = new ArrayList<String>();

// List of absolute paths to images that have been removed from the pool of possible images to 
// show because new images took their place 
ArrayList<String> replacedImgs = new ArrayList<String>();

// this is the voices we are currently listening to, which is a <= 12, usually ~4
// {"/vc1","/vc2","/vc3","/vc4"};
ArrayList<String> recvVoices = new ArrayList<String>();


int gridSizeCurr = 1;
int gridSizePrev = gridSizeCurr;

boolean changeImagesGate = true;
boolean threshCrossed = false;
// time since last image change
int lastImgChange = 0;

int WIDTH_INIT = 1000;
int HEIGHT_INIT = 1000;

// LIVE PARAMS
boolean AUTO_IMG_CHANGE = true;
boolean AUTO_GRID_RESIZE  = true;
boolean ALLOW_TINT_CHANGE = true;
int MAX_GRID_SIZE = 8;
int MAX_POOL_SIZE = 64;

/*
// DEBUGGING PARAMS
boolean AUTO_IMG_CHANGE = true;
boolean AUTO_GRID_RESIZE  = false;
boolean ALLOW_TINT_CHANGE = false;
int MAX_GRID_SIZE = 2;
int MAX_POOL_SIZE = 4;
*/



void setup() {
  println("total mem - setup start: " + totalMem());
  // aparrently can't use variables here 
  size(1000, 1000);
  surface.setResizable(true);
 
  new OscP5(this, 12000);
  new NetAddress("127.0.0.1", 12000);

  loadImagesFromDataDir();  
  
  // initialize all voices - this will be more than recvVoices
  for (int i=1; i<13; i++) {
    scVoiceToCurrVal.put("/vc" + i, 0);        
  }

  // Initialize with 4 voices to listen to from SC
  for (int i=1; i<5; i++) {
    recvVoices.add("/vc" + i);        
  }

  // initialize gridCellToScVoice 
  mapGridCellToScVoice(); 
  // DEBUG
  // noLoop();
  println("total mem - setup end: " + totalMem());
}


void draw() {
  background(0);
  int millis = millis();
  if (millis % 32 == 0) {
    // handleDeletedImages();
    loadImagesFromDataDir();
    if (millis % 64 == 0) {
      removeImages();
      System.gc();
      println("num replaced images: " + replacedImgs.size());
    }
  }
  handleImageChange();
  drawGrid(gridSizeCurr);

  if(frameCount % 50 == 0){
    int percent = (int)(100*(double)usedMem()/totalMem());
    println("memory usage: " + percent + "%");
  }
}


void loadImagesFromDataDir() {
  File dir = new File(dataPath(""));
  File[] files = dir.listFiles();
  for (File theFile : files) {
    // println(theFile);
    // TODO: probably faster as a FileFilter | FilenameFilter but that's confusing...
    String theFilename = theFile.getAbsolutePath();
    // if we find a new jpeg file
    if ((theFilename.toLowerCase().endsWith(".jpg") || theFilename.toLowerCase().endsWith(".jpeg")) && !currImgPool.contains(theFilename) && !replacedImgs.contains(theFilename)) {
       // TODO: try/except here. maybe do retries? if we fail, track this file in a list that shouldn't be retried
      if (currImgPool.size() >= MAX_POOL_SIZE) {
        String oldImg = currImgPool.get(0);
        // seems risky removing this, but hasn't errored, probably b/c the only reader would be in same thread
        allImgs.remove(oldImg);
        replacedImgs.add(oldImg);
        currImgPool.remove(oldImg);  
        println("Replacing img. Old img: " + oldImg + "New img: " + theFilename);
      } 
      // normal img load
      println("Loading image: " + theFilename);
      currImgPool.add(theFilename);
      // TODO initial capacity MAX_GRID_SIZE?
      allImgs.put(theFilename, new HashMap<>());
      PImage theImage = loadImage(theFilename);
      // step through each possible grid size and load the copy of img scaled for that grid size 
      for (int possibleGridSize = 1; possibleGridSize <= MAX_GRID_SIZE; possibleGridSize++) { 
        PImage theImageCopy = theImage.copy();
        // scale to original width so that images loaded later are same size as original images
        int imgMaxDim = WIDTH_INIT / possibleGridSize;
        if (theImage.width >= theImage.height){
          theImageCopy.resize(imgMaxDim, 0);
        } else {
          theImageCopy.resize(0, imgMaxDim);
        }
        allImgs.get(theFilename).put(possibleGridSize, theImageCopy);
      }
    }
  }
}


void removeImages() {
  File dir = new File(dataPath(""));
  File[] files = dir.listFiles();
  String[] filenamesInDataDir = new String[files.length];
  for (int i=0; i<files.length; i++) {
    filenamesInDataDir[i] = files[i].getAbsolutePath();
  }
  HashSet<String> inDataDir = new HashSet<>(Arrays.asList(filenamesInDataDir));
  HashSet<String> inCurrImgPool = new HashSet<>(currImgPool);
  HashSet<String> removedFromDir = new HashSet<>(inCurrImgPool);
  removedFromDir.removeAll(inDataDir);
  if (!removedFromDir.isEmpty()) {
    println("Removing files + " + removedFromDir);
    for (String removedFilename: removedFromDir) {
      // NOTE: this assumes we have images that have been replaced. In practice, this will be true because we will only
      // manually remove images that have been added after animation start, but this should be made safer
      String replacementImg = replacedImgs.remove(0);
      println("Remplacing removed img + " + removedFilename + " with " + replacementImg);
      currImgPool.remove(removedFilename);  
      // same as initial image load, so encapsulate?
      println("Loading image: " + replacementImg);
      currImgPool.add(replacementImg);
      allImgs.put(replacementImg, new HashMap<>());
      PImage theImage = loadImage(replacementImg);
      // step through each possible grid size and load the copy of img scaled for that grid size 
      for (int possibleGridSize = 1; possibleGridSize <= MAX_GRID_SIZE; possibleGridSize++) { 
        PImage theImageCopy = theImage.copy();
        // scale to original width so that images loaded later are same size as original images
        int imgMaxDim = WIDTH_INIT / possibleGridSize;
        if (theImage.width >= theImage.height){
          theImageCopy.resize(imgMaxDim, 0);
        } else {
          theImageCopy.resize(0, imgMaxDim);
        }
        allImgs.get(replacementImg).put(possibleGridSize, theImageCopy);
      }
    }
  }
}


/**
 * Handles decision of whether or not to change images. Currently this is based on whether
 * values from SC are under a threshold, which means we only change images when the animation
 * is dark.
 */
void handleImageChange() {
  // set grid size to a random number each time all voices from SC are 0
  //  also changes grid size unless flag is off
  if (!AUTO_IMG_CHANGE) { 
    return;
  }
  int now = millis();
  if (now - lastImgChange < 3000) {
    return;
  }
  boolean doImagesChange = false;
  int vcsValSum = 0;
  // ConcurrentModificationException
  for (String vc : recvVoices) {
    vcsValSum += scVoiceToCurrVal.get(vc);
  }
  // println(vcsValSum);
  // if total is under threshold
  if (vcsValSum < 10) {
    // println("under thresh");
    if (threshCrossed == false) {
      doImagesChange = true;
      threshCrossed = true;
    }
  } else {
    threshCrossed = false;
  }
  if (doImagesChange) {
      gridSizePrev = gridSizeCurr;
      if (AUTO_GRID_RESIZE) {
        gridSizeCurr = int(random(MAX_GRID_SIZE)) + 1;
      }
      // println("doImagesChange");
      changeImagesGate = true;
  } 
} 


void mapGridCellToScVoice() {
  if (!recvVoices.isEmpty()) {
    for (int cellNum=0; cellNum < gridSizeCurr*gridSizeCurr; cellNum++) {
      gridCellToScVoice.put(cellNum, recvVoices.get(cellNum % recvVoices.size()));
    }
    // println("gridCellToScVoice ----");
    // gridCellToScVoice.forEach((key, value) -> println(key + " " + value));
  }
}


void drawGrid(int gridSizeLoc) {
  // println("gridSizeLoc: " + gridSizeLoc);
  if (changeImagesGate) {
    // if gridSizeCurr has changed, update sc voice mapping
    if (gridSizeCurr != gridSizePrev) {
      mapGridCellToScVoice();
      lastImgChange = millis();
    }
    // rotate (and eventually randomize) img pool  
    String firstImg = currImgPool.get(0);
    for (int i = 0; i < currImgPool.size(); i++) {
      if (i < currImgPool.size() - 1) {
        currImgPool.set(i, currImgPool.get(i+1)); 
      } else {
        // firstImage becomes last  
        currImgPool.set(i, firstImg);
      } 
    }
    changeImagesGate = false;
  }

  // TODO: encapsulate
  // gridSizeLoc 2 means a square grid of 2x2 images
  int cellNum = 0;
  // row
  for (int i=0; i<gridSizeLoc; i=i+1) {
    // println(i);
    // col
    for (int j=0; j<gridSizeLoc; j=j+1) {
      int imgLocW = j * (width/gridSizeLoc);
      int imgLocH = i * (height/gridSizeLoc);
      // get sc voice mapped to this cell
      // TODO still getting NPEs here or next line
      String cellVoice = gridCellToScVoice.get(cellNum);
      // get the last value emitted by that voice
      int cellVal = scVoiceToCurrVal.get(cellVoice);
      // map value from SC to image transparency
      if (ALLOW_TINT_CHANGE) { 
        tint(255, map(cellVal, 0, 25, 0, 255));
      } else {
        tint(255, 255);  
      }
      // got out of bounds here
      String cellFilename = currImgPool.get(cellNum);
      HashMap<Integer, PImage> sizeToPImage = allImgs.get(cellFilename);
      PImage cellImg = sizeToPImage.get(gridSizeLoc); 

      // center image in cell
      int imgW = cellImg.width;
      int imgH = cellImg.height;
      int cellW = width / gridSizeLoc; int cellH = height / gridSizeLoc;
      imgLocW = imgLocW + ((cellW - imgW) / 2);    
      imgLocH = imgLocH + ((cellH - imgH) / 2);    

      // draw image
      image(cellImg, imgLocW, imgLocH);
      cellNum++;
    }
  }
  gridSizePrev = gridSizeCurr;
} 


void oscEvent(OscMessage msg) {

  if (msg.checkAddrPattern("/gridSize")) {
     // not used now
     gridSizePrev = gridSizeCurr;
     gridSizeCurr = msg.get(0).intValue(); 
     changeImagesGate = true;
  } else if (msg.checkAddrPattern("/changeImgs")) {
     changeImagesGate = true;
  } else if (msg.checkAddrPattern("/setRecvVoices")) {
    // println(msg);
    // msg.printData();
    // recvVoices.clear();
    ArrayList<String> recvVoicesSwap = new ArrayList<String>();
    for (int i = 0; i < msg.arguments().length; i++) {  
      recvVoicesSwap.add(msg.get(i).stringValue());  
    }
    recvVoices = recvVoicesSwap;
    println(recvVoices);
  } else {
    // get SC voice values and load into a data struct
    // /vc0, /vc1, etc
    String addrPattern = msg.addrPattern();
    
    scVoiceToCurrVal.put(addrPattern, msg.get(0).intValue()); 
    // println("scVoiceToCurrVal ----");
    // scVoiceToCurrVal.forEach((key, value) -> println(key + " " + value));
  }
}


public long totalMem() {
  return Runtime.getRuntime().totalMemory();
}

public long usedMem() {
  return Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
}


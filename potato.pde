/**
 * POTATO 1.0.1-SNAPSHOT
 * =====================
 *
 * Experimental Video Processing.
 *
 * Based on previous _Vegetables_ sketch.
 *
 * The following process is used:
 * - Grayscale conversion
 *  - Quantization
 *  - Gamma correction
 *  - Brightness adjustment
 * - Downsample and average
 * - Differentiate (with gradient threshold)
 * - De-noise (with neighbour threshold)
 *
 * The process is paramaterised using the following variables and default values,
 * withing the given constraints:
 * - Subsampling window - 4, [ 2, 128 ]
 * - Gradient threshold - 0.25, [ 0.0, 1.0 ]
 * - Neighbour count - 6, [ 1, 9 ]
 * - Gamma - 1.0, [ 0.1, 5.0 ]
 * - Brightness - 1.0, [ 0.1, 5.0 ]
 * - Levels - 16
 *
 * When running, the parameters can be changed using the number keys, and the `v`,
 * `g` and `z` keys will toggle display of video, grayscale conversion and de-noising.
 * The spacebar will save the current image and `q` will quit the program. The
 * current parameter values are displayed in an info banner at the top of the screen.
 * Press 'r' to reset the parameters to their initial values.
 * 
 * ----
 * [Andrew Donald Kennedy](mailto:adk@abstractvisitorpattern.co.uk)
 * Copyright 2009-2017 by Andrew Kennedy
 * [Apache 2.0 License](http://www.apache.org/licenses/LICENSE-2.0)
 */

import processing.video.*;

// global variables
static final String VERSION = "1.0.1-SNAPSHOT";
static final boolean DEBUG = false;
static final boolean FULLSCREEN = false;
static final int TEXTSIZE = 20, MARGINX = 10, MARGINY = 5;
static final int TEXTHEIGHT = TEXTSIZE + MARGINY + MARGINY;

// feature flags
static final boolean _SEGMENT = false;

// defaults
static float GAMMA = 1f, BRIGHT = 1f, EDGE_THRESHOLD = 0.25f;
static int SUBSAMPLING = 4, NOISE_THRESHOLD = 6;
static boolean SAVE_FRAME = false, SHOW_VIDEO = true, GRAYSCALE = false, DENOISE = true, SHOW_NEIGHBOURS = false;

// state flags
static boolean saveframe = SAVE_FRAME;
static boolean showvideo = SHOW_VIDEO;
static boolean grayscale = GRAYSCALE;
static boolean denoise = DENOISE;
static boolean showneighbors = SHOW_NEIGHBOURS;

// screen size
static int w, h, p;

// quantize levels
static int levels = 16;

// subsampling factor
static int s = SUBSAMPLING;
static int q;

// correction
static float gamma = GAMMA;
static float bright = BRIGHT;

// image count
static int counter, total;

// edge threshold
static float threshold = EDGE_THRESHOLD;

// noise threshold
static int neighbors = NOISE_THRESHOLD;

// video capture library interface
Capture video; 

// data storage for pipeline stages
int data[];
float gray[], sub[], diff[];
boolean edge[], line[];
int noise[];
ArrayList<PShape> lines = new ArrayList<PShape>();

// colour and shade constants
color DIM = 0x64, BLACK = 0x00, WHITE = 0xff, FADE = #c8c8c8;
color RED = #f02040, YELLOW = #f0f070, GREEN = #109030, BLUE = #3020a0;
color CYAN = #407090, MAGENTA = #901060, LIGHT = 0xee;

PImage banner;

// font choice list
String fonts[] = {
  "Consolas", "Inconsolata", "Courier New", "Courier"
  // "Consolas", "Monaco", "Inconsolata", "Andale Mono", "Courier New", "Courier"
  // "Lucida Grande", "Century Gothic", "Verdana", "Helvetica", "Arial"
};

void cameraList() {
  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }
  }
}

// reset state
void resetState() {
  gamma = GAMMA;
  bright = BRIGHT;
  threshold = EDGE_THRESHOLD;
  neighbors = NOISE_THRESHOLD;
  s = SUBSAMPLING;
  q = ((width * height) - (s * width)) / (s * s);
  saveframe = SAVE_FRAME;
  showvideo = SHOW_VIDEO;
  grayscale = GRAYSCALE;
  denoise = DENOISE;
  showneighbors = SHOW_NEIGHBOURS;
}

// allocate space for image processing data
void alloc() {
  w = width;
  h = height;
  p = w * h;
  if (DEBUG) println("screen size " + w + "x" + h + " ("+p+"px)");
  
  // data storage for pipeline stages
  int n = (w + 2) * (h + 2); // safety factor
  data = new int[n];
  gray = new float[n];
  sub = new float[n];
  diff = new float[n];
  edge = new boolean[n];
  line = new boolean[n];
  noise = new int[n];
}

/**
 * initial setup of screen, video and drawing properties
 */
void setup() {
  // setup graphics environment
  size(1024, 768, P3D);
  frameRate(30);
  noCursor();
  smooth();
  strokeJoin(ROUND);
  strokeCap(ROUND);
  ellipseMode(CENTER);
  strokeWeight(2);
  noStroke();

  // set state variables to initial values
  resetState();

  // allocate image processing memory
  alloc();

  // setup video capture
  if (DEBUG) cameraList();
  video = new Capture(this, w, h, 15);
  video.start();

  // create font for text
  PFont font = findFont(fonts, TEXTSIZE);
  textFont(font);
  textSize(TEXTSIZE);

  // reset frame number counters to zero
  saveBytes("data/frames.dat", new byte[] { 0x00, 0x00, 0x00, 0x00 });
  
  // load frame counter
  byte bytes[] = loadBytes("data/frames.dat"); 
  counter = (int) (bytes[0] & 0xff) * 256 + (int) (bytes[1] & 0xff); // get frame number
  total = (int) (bytes[2] & 0xff) * 256 + (int) (bytes[3] & 0xff); // get offline frames total
  
  // save gray background for image fade later
  background(FADE);
  banner = get(0, 0, w, TEXTHEIGHT); 
}

/**
 * load a font from a list of preferences
 */
PFont findFont(String[] choices, int size) {
  String[] available = PFont.list();
  for (int i = 0; i < choices.length; i++) {
    for (int j = 0; j < available.length; j++) {
      if (available[j].equals(choices[i])) {
        return createFont(choices[i], size, true);
      }
    }
  }
  return createFont(available[0], size, true); // give up?
}

/**
 * draw each frame of video and detect edges
 */
void draw() {
  if (video.available()) {
    video.read(); // get webcam data
    PImage frame = video.get();

    if (showvideo) {
      image(frame, 0, 0, w, h); // show video
      if (grayscale) filter(GRAY); // grayscale
    } else {
      background(WHITE); // fill background
    }
    
    // extract pixels
    frame.loadPixels();
    data = frame.pixels;
  }
    
  // convert to grayscale and quantize
  for (int i = 0; i < p; i++) {
    float value = brightness(data[i]) / 256.0f;
    value = bright * pow(value, gamma);
    gray[i] = (float) floor(value * levels) / (float) levels;
  }

  // downsample and average
  for (int i = 0; i < q; i++) {
    int pixel = pixel(i);
    float sample = 0.0f;
    for (int x = 0; x < s; x++) {
      for (int y = 0; y < s; y++) {
        sample += gray[pixel + x + (y * w)];
      }
    }
    sub[i] = sample / (float) (s * s);
  }

  // differentiate
  for (int i = 0; i < q; i++) {
    float value = sub[i];
    float gradient = 0.0f;
    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        float sample = sub[min(p / s * s, max(0, i + x + (y * (w / s))))];
        float magnitude = abs(sample - value); 
        gradient += magnitude;
      }
    }
    diff[i] = gradient;
    edge[i] = diff[i] >= threshold;
  }

  // denoise
  for (int i = 0; i < q; i++) {
    int count = 0;
    if (edge[i]) {
      for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
          if (edge[min(p / s * s, max(0, i + x + (y * (w / s))))]) {
            count++;
          }
        }
      }
      noise[i] = count;
      line[i] = count >= neighbors;
    }
  }

  // display
  for (int i = 0; i < q; i++) {
    float gradient = diff[i];
    if ((!denoise && edge[i]) || (denoise && edge[i] && noise[i] >= neighbors)) {
      fill(showvideo ? RED : BLACK, denoise ? 128 : 128 * gradient);
      rect((sx(i) - 0.5f) * s, (sy(i) - 0.5f) * s, s * 2, s * 2);
    }
  }
  
  // experimental segment feature
  if (_SEGMENT) {
    PShape segment = null;
    int x, y;
    for (int i = 0; i < q; i++) {
      x = sx(i); y = sy(i);
      if (line[i]) {
        if (segment == null) {
          segment = createShape();
          segment.beginShape();
          segment.vertex(x * s, y * s);
        }
        line(segment, x, y, 20);
        segment.endShape(CLOSE);
        stroke(GREEN);
        shape(segment);
        segment = null;
      }
    }
  }

  // save file if key pressed
  if (saveframe) {
    counter++; total++;
    save("save/potato-" + nf(counter, 5) + ".png");
    saveframe = false;
  }

  // show info
  info();
}

void line(PShape segment, int x, int y, int d) {
  // try and add a line from x,y that is d long
  for (int a = 0; a < 360; a++) {
    float t = radians(a);
    int hits = 0;
    for (int l = 0; l < d; l++) {
      int dy = floor(l * sin(t));
      int dx = floor(l * cos(t));
      int i = subpixel(x + dx, y + dy);
      if (i < 0 || i > p / s * s) continue;
      if (line[i]) hits++;
    }
    if (hits > (0.8 * d)) {
      for (int l = 0; l < d; l++) {
        int dy = floor(l * sin(t));
        int dx = floor(l * cos(t));
        int i = subpixel(x + dx, y + dy);
        for (int lx = -2; lx <= 2; lx++) {
          for (int ly = -2; ly <= 2; ly++) {
            line[min(p / s * s, max(0, i + x + (y * (w / s))))] = false;
          }
        }
      }
      x += floor(d * sin(t));
      y += floor(d * cos(t));
      segment.vertex(s * x, s * y);
      line(segment, x, y, d);
      return;
    }
  }
}

/** Pixel index for (x, y) co-ordinates. */
int pixel(int x, int y) {
  return x + (w * y);
}
int x(int pixel) {
  return pixel % w;
}
int y(int pixel) {
  return pixel / w;
}
int pixel(int subpixel) {
  return pixel(sx(subpixel) * s, sy(subpixel) * s);
}

/** Sub-samples pixel index for (x, y) co-ordinates. */
int subpixel(int sx, int sy) {
  return (s * sx) + (w * sy * s);
}
int sx(int subpixel) {
  return subpixel % (w / s);
}
int sy(int subpixel) {
  return subpixel / (w / s);
}

/**
 * change various parameters up and down using number keypresses.
 */
void keyPressed() {
  int ds = 0;
  float dthreshold = 0.0;
  int dneighbors = 0;
  float dgamma = 0;
  float dbright = 0;
  
  // change delta based on keypress
  if (key == '1') ds  = -1;
  if (key == '2') ds  = +1;
  if (key == '3') dthreshold  = -0.05;
  if (key == '4') dthreshold  = +0.05;
  if (key == '5') dneighbors  = -1;
  if (key == '6') dneighbors  = +1;
  if (key == '7') dgamma  = -0.1;
  if (key == '8') dgamma  = +0.1;
  if (key == '9') dbright  = -0.1;
  if (key == '0') dbright  = +0.1;

  // update paramaters
  
  s *= pow(2, ds);
  s = min(128, max(s, 2));
  q = (p - (s * w)) / (s * s);
  
  threshold += dthreshold;
  threshold = min(1.0, max(threshold, 0.0));
  
  neighbors += dneighbors;
  neighbors = min(30, max(neighbors, 0));
  
  gamma += dgamma;
  gamma = min(5.0, max(gamma, 0.1));
  
  bright += dbright;
  bright = min(5.0, max(bright, 0.1));
}
  
/**
 * save frame on space key, reset on 'r' and toggle various states on others,
 * quit and so on.
 */
void keyReleased() {
  if (key != CODED) {
    if (key == ' ') saveframe = true;
    if (key == 'v' || key == 'V') showvideo = !showvideo;
    if (key == 'g' || key == 'G') grayscale = !grayscale;
    if (key == 'z' || key == 'Z') denoise = !denoise;
    if (key == 'r' || key == 'R') resetState();
    if (key == 'q' || key == 'Q') {
      video.stop();
      exit();
    }
  }
}

/**
 * cheap bold text trick
 */
public void bold(String msg, int x, int y) {
  text(msg, x, y);
  text(msg, x, y + 1);
}

  
void saveData() {
  byte[] bytes = {
    (byte) (counter / 256), (byte) (counter % 256),
    (byte) (total / 256), (byte) (total % 256),
  };
  saveBytes("data/frames.dat", bytes);
}

/**
 * display system information over video at top of screen.
 */
public void info() {
  blend(banner, 0, 0, w, TEXTHEIGHT, 0, 0, w, TEXTHEIGHT, HARD_LIGHT);
  
  // program name and date bold text in black
  fill(BLACK);
  textAlign(LEFT, TOP);
  bold("Potato " + VERSION, MARGINX, MARGINY);
  textAlign(RIGHT, TOP);
  String info = String.format("%d/%s/%d/%s/%s %c%c%c %s fps #%s",
      s,
      nf(threshold, 1, 2),
      neighbors,
      nf(gamma, 1, 1),
      nf(bright, 1, 1),
      showvideo ? 'v' : '-',
      grayscale ? 'g' : '-',
      denoise ? 'z' : '-',
      nf(frameRate, 2, 2),
      nf(counter, 3));
  bold(info, w - MARGINX, MARGINY);
}
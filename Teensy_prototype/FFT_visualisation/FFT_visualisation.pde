import processing.serial.*;

Serial myPort;        // The serial port
PrintWriter output;
int xStart = 70;
int yStart = 50;
int xPos = xStart;         // horizontal position of the graph
int speed = 0;
int oldspeed = 0;
int num_fft_bins;
float spec_speed = 0;
int sample_rate = 12000;
float fft_bin_width = sample_rate/1024;
float speed_conversion = fft_bin_width/44.0; //44100/1024/44; //1.578125;
int max_frequency = 100;

String inString;
float oldpeak = 0;
int baseline;
PImage img;
int window_height = num_fft_bins+yStart;
int zoom = 1;
int step;

int[] num = new int[512];
byte[] inBuffer = new byte[16];
int mic_gain;
int max_freq_Index;
int peak_int;
float peak;
float min_fft = 0;
float max_fft = 0;
int start_sequence; 


void setup () {
  size(1000, 561);
  // set the window size:
  //size(displayWidth, displayHeight);
  //fullScreen();
  
  windowResizable(false);
  
  // List all the available serial ports
  // if using Processing 2.1 or later, use Serial.printArray()
  println(Serial.list());
  myPort = new Serial(this, Serial.list()[8], 9600);

  //create file to write to
  output = createWriter( "recorded_data/radar_data_" + timestamp() + ".csv" );

  // set initial background:
  background(255);
  
  draw_axis(); 
}

void windowResized() {
  draw_axis();
}

void draw_axis () { 
  baseline = height-yStart;
  img = createImage(1, baseline, RGB);
  
  // axis
  stroke(#FFFFFF);
  fill(#FFFFFF);
  background(255);
  
  stroke(#ff0000);
  line(xStart-1, 0, xStart-1, baseline);
  if(zoom>=4){
    step=5;
  }else{
    step=20;
  }
  if(zoom>=18){
    step=1;
  }
     
  for(int s =0; s < 1000; s=s+step){
    int tick_label = s;
    float tick_position = map(tick_label/speed_conversion, 0, num_fft_bins/zoom, baseline, 0);
    line(xStart-10, tick_position, xStart-1, tick_position);
    fill(#ff0000);
    textSize(20);
    textAlign(RIGHT,CENTER);
    text(tick_label, xStart-13, tick_position-5);
  }
  textAlign(CENTER, CENTER);
  translate(10, baseline/2);
  rotate(radians(-90));
  text("Geschwindigkeit (km/h)", 0, 0);
}

void draw () {
  oldspeed = speed;
  myPort.clear();
  myPort.write("d");
  
  while(myPort.available()<9){
    delay(1);
  }

  print("mic_gain:");
  mic_gain = (myPort.read());
  print(mic_gain);
  
  print(", max_freq_index:");
  max_freq_Index = (myPort.read()) + (myPort.read()<<8);
  speed = max_freq_Index;
  print(max_freq_Index);
  
  print(", peak:");
  peak_int = myPort.read() + (myPort.read()<<8) + (myPort.read()<<16) + (myPort.read()<<24);
  peak = Float.intBitsToFloat(peak_int);
  print(round(peak*100)/100.0);
  
  print(", numfft:");
  num_fft_bins = (myPort.read()) + (myPort.read()<<8);
  print(num_fft_bins);
  
  int[] nums_int = new int[num_fft_bins];
  float[] nums = new float[num_fft_bins];

  for(int i = 0; i < num_fft_bins; i++){
      //print(",");
      while(myPort.available()<4){
        delay(1);
      }
      nums_int[i] = myPort.read() + (myPort.read()<<8) + (myPort.read()<<16) + (myPort.read()<<24);
      nums[i] = Float.intBitsToFloat(nums_int[i]);
      min_fft = min(min_fft, nums[i]);
      max_fft = max(max_fft, nums[i]);
      //print(nums[i]);
  }
  
  print(",min:");
  print(min_fft);
  print(",max:");
  print(max_fft);
  
  println();
  
  oldpeak = oldpeak*0.999;
  
  // write to data file
  output.print(inString);
  
  // draw waterfall spectrogramm
  img.loadPixels();
  int j = img.height-1;
  int k = 0;
  for (int i = 0; i < img.height ; i++) {
    if(k > (num_fft_bins-1)){
      img.pixels[j] = color(255,255,255);
    }else{
      float col = map(nums[k], -190, 1, 255, 0);
      img.pixels[j] = color(col,col,col);
      //img.pixels[j+1] = color(23,120,30);
    }
    j--;
    if(i%zoom==0){
      k++;
    }
    
  }
  //img.pixels[img.height-1-(speed*zoom)-zoom/2] = color(200,20,40);
  img.updatePixels();
  image(img, xPos,0);
  
  // draw the line:
  stroke(#ff0000);
  //if(peak>0.05){
    //line(xPos-1, map(oldspeed, 0, (num_fft_bins/zoom), baseline, 0), xPos, map(speed, 0, num_fft_bins/zoom, baseline, 0));
  //}

  // at the edge of the screen, go back to the beginning:
  if (xPos >= width) {
    xPos = xStart;
    //background(0);
  } else {
    // increment the horizontal position:
    xPos++;
  }
  
  //draw speed as text
  fill(255);
  stroke(255);
  //rect(width-220, 0, 220, 90); 
  fill(#ff0000);
  textSize(104); 
  textAlign(RIGHT);
  //if(peak > 0.01){
    //text(round(speed*speed_conversion), width, 80);
  //}
  if(peak >= 1.0){
    fill(#ff0000);
  }else{
    fill(#51A351);
  }
  rect(width/2-25, 0, 50, 30);
  fill(#000000);
  textAlign(CENTER, TOP);
  textSize(23);
  text(round(mic_gain), width/2, 0);
}

void keyPressed() {
  if (key == CODED) {
    if (keyCode == UP) {
      zoom = min(zoom+1,100);
      draw_axis();
    } else if (keyCode == DOWN) {
      zoom = max(zoom-1, 1);
      draw_axis();
    }
  } else if (key == 's') {
    String filename = "screenshots/radar_spectrum_" + timestamp() + ".png"; 
    println(filename);
    save(filename);
  } else if (key== 'q') {
    output.flush();  // Writes the remaining data to the file
    output.close();  // Finishes the file
    exit();  // Stops the program
  } else if (key == '+'){
    myPort.write(1);
    println("increasing mic gain");
  } else if (key == '-'){
    myPort.write(0);
    println("decreasing mic gain");
  }
}

String timestamp() {
  String[] timestamp = new String[6];
  timestamp[0] = String.valueOf(year());
  timestamp[1] = String.valueOf(month());
  timestamp[2] = String.valueOf(day());
  timestamp[3] = String.valueOf(hour());
  timestamp[4] = String.valueOf(minute());
  timestamp[5] = String.valueOf(second());
  String timestamp_str = join(timestamp, "-");
  return(timestamp_str);
}

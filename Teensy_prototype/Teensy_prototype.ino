#include <Audio.h>
#include "OpenAudio_ArduinoLibrary.h"
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include <SerialFlash.h>
#include <utility/imxrt_hw.h>

void setI2SFreq(int freq) {
  // PLL between 27*24 = 648MHz und 54*24=1296MHz
  int n1 = 4; //SAI prescaler 4 => (n1*n2) = multiple of 4
  int n2 = 1 + (24000000 * 27) / (freq * 256 * n1);
  double C = ((double)freq * 256 * n1 * n2) / 24000000;
  int c0 = C;
  int c2 = 10000;
  int c1 = C * c2 - (c0 * c2);
  set_audioClock(c0, c1, c2, true);
  CCM_CS1CDR = (CCM_CS1CDR & ~(CCM_CS1CDR_SAI1_CLK_PRED_MASK | CCM_CS1CDR_SAI1_CLK_PODF_MASK))
       | CCM_CS1CDR_SAI1_CLK_PRED(n1-1) // &0x07
       | CCM_CS1CDR_SAI1_CLK_PODF(n2-1); // &0x3f 
}

const int sample_rate = 12000;
uint16_t max_amplitude;                   //highest signal in spectrum              
uint16_t max_freq_Index;
float speed_conversion = (sample_rate/1024)/44.0;
int input;
char command[1];
uint8_t mic_gain = 16;
float saveDat[512];
bool send_output = false;
float peak;
uint16_t send_max_fft_bins = 514;

AudioAnalyzeFFT1024_F32      fft1024;      
AudioAnalyzePeak_F32         peak1;          

AudioInputI2S_F32            mic;           
AudioOutputI2S_F32           headphone;           
AudioControlSGTL5000         sgtl5000_1;     
AudioConnection_F32          patchCord3(mic, 0, fft1024, 0);
AudioConnection_F32          patchCord5(mic, 0, peak1, 0);
AudioConnection_F32          patchCord6(mic, 0, headphone, 0);
AudioConnection_F32          patchCord7(mic, 0, headphone, 1);


void setup() {
  setI2SFreq(sample_rate);

  // Audio connections require memory to work.  For more
  // detailed information, see the MemoryAndCpuUsage example
  AudioMemory_F32(60);

  // Enable the audio shield, select input, and enable output
  sgtl5000_1.enable();
  sgtl5000_1.inputSelect(AUDIO_INPUT_MIC); //AUDIO_INPUT_LINEIN
  sgtl5000_1.micGain(mic_gain); 
  //sgtl5000_1.lineInLevel(0);
  sgtl5000_1.volume(.5);

  fft1024.windowFunction(AudioWindowHanning1024);
  fft1024.setNAverage(1);
  fft1024.setOutputType(FFT_DBFS);   // FFT_RMS or FFT_POWER or FFT_DBFS

  pinMode(PIN_A8, OUTPUT);
  digitalWrite(PIN_A8, LOW); 

  Serial.begin(9600);
}


void loop() {

  if (Serial.available() > 0) {
    input = Serial.read();
    if((input==0) & (mic_gain > 0)){
      mic_gain--;
      sgtl5000_1.micGain(mic_gain);
    }
    if((input==1) & (mic_gain<63)){
      mic_gain++;
      sgtl5000_1.micGain(mic_gain);
    }      

    if(input==100){
      send_output=true;
    }
  }

  uint32_t i;

  if(fft1024.available() & send_output)
  {
    //save fft result in variable
    float* pointer = fft1024.getData();
    for (int kk=0; kk<512; kk++) saveDat[kk]= *(pointer + kk);
    
    Serial.write((byte*)&mic_gain, 1);
         
    // detect highest frequency
    max_amplitude = 0;
    max_freq_Index = 0;
    for(i = 1; i < 512; i++) {    
      if ((saveDat[i] > 5) & (saveDat[i] > max_amplitude)) {
        max_amplitude = saveDat[i];        //remember highest amplitude
        max_freq_Index = i;                    //remember frequency index
      }
    }
    Serial.write((byte*)&max_freq_Index, 2);
    
    peak = peak1.read();
    Serial.write((byte*)&peak, 4);

    Serial.write((byte*)&send_max_fft_bins, 2);

    // send spectrum
    for(i = 0; i < send_max_fft_bins; i++)
    {
      Serial.write((byte*)&saveDat[i], 4);
    }
    
    send_output = false;
  }

}



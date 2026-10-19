// UVScan fixed-packet sensor example for an Arduino Uno or Nano.
//
// The same idea as arduino-text.ino, sent as binary packets instead of text:
// smaller, and the way many commercial boxes (Zeitronix, Tech Edge) send.
// Ten times a second, 8 bytes:
//
//   byte 0-1  AA 55            the start: UVScan finds each packet by it
//   byte 2-3  EGT              degrees C, most significant byte first
//   byte 4-5  boost x 100      signed (below zero is vacuum), most significant first
//   byte 6    battery x 10     volts (up to 25.5)
//   byte 7    counter          goes up by one each packet
//
// arduino-packet.uvsensor describes this to UVScan with the layout
//   start AA 55; length 8; egt 2-3; boost 4-5 signed; battery 6; count 7
// and its PIDs scale the raw numbers (boost: N0 / 100, battery: N0 / 10).
//
// Wiring - change the scaling to suit your parts:
//   A0  EGT amplifier, e.g. an AD8495 board: 1.25 V at 0 C, 5 mV per degree C
//   A2  MAP sensor, 0.5-4.5 V for 0-300 kPa absolute
//   A3  battery through a 30k / 10k divider (a quarter of the voltage)

const float VREF = 5.0;  // the Arduino's analog reference
byte counter = 0;

float volts(int pin) {
  return analogRead(pin) * VREF / 1023.0;
}

void setup() {
  Serial.begin(115200);
}

void loop() {
  int egt = (int)((volts(A0) - 1.25) / 0.005);
  float kpa = (volts(A2) - 0.5) * 300.0 / 4.0;
  int boost100 = (int)((kpa - 101.3) * 0.145 * 100.0);
  int battery10 = (int)(volts(A3) * 4.0 * 10.0);

  byte packet[8] = {
    0xAA, 0x55,
    highByte(egt), lowByte(egt),
    highByte(boost100), lowByte(boost100),
    (byte)constrain(battery10, 0, 255),
    counter++
  };
  Serial.write(packet, sizeof(packet));
  delay(100);
}

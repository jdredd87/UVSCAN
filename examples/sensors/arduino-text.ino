// UVScan text sensor example for an Arduino Uno or Nano.
//
// Reads an EGT amplifier, an oil pressure sender and a MAP sensor and sends
// them as a line of text ten times a second:
//
//   egt=812 oilp=45.2 boost=7.3
//
// In UVScan: Sensors > Import > arduino-text.uvsensor, choose the Arduino's
// port (115200 baud), Start test, Save, then tick its PIDs.
//
// Wiring - change the scaling in loop() to suit your parts:
//   A0  EGT amplifier, e.g. an AD8495 board: 1.25 V at 0 C, 5 mV per degree C
//   A1  oil pressure sender, 0.5-4.5 V for 0-100 psi (a 3-wire, 5 V sender)
//   A2  MAP sensor, 0.5-4.5 V for 0-300 kPa absolute
//
// Any other value works the same way: add "name=value" to the line, and in
// UVScan's test pick the new field and Add a PID for it.

const float VREF = 5.0;  // the Arduino's analog reference

float volts(int pin) {
  return analogRead(pin) * VREF / 1023.0;
}

void setup() {
  Serial.begin(115200);
}

void loop() {
  float egt = (volts(A0) - 1.25) / 0.005;       // degrees C
  float oil = (volts(A1) - 0.5) * 100.0 / 4.0;  // psi
  float kpa = (volts(A2) - 0.5) * 300.0 / 4.0;  // kPa absolute
  float boost = (kpa - 101.3) * 0.145;          // psi above the air outside

  Serial.print("egt=");
  Serial.print(egt, 0);
  Serial.print(" oilp=");
  Serial.print(oil, 1);
  Serial.print(" boost=");
  Serial.println(boost, 1);  // println ends the line
  delay(100);
}

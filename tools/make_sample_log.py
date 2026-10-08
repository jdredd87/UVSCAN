"""Writes a made-up but plausible UVScan log to try the log viewer with.

A 25-minute drive in a 2001 3800 V6 with a 4T65E, logged at 10 rows a second
like a real scan with up to 4 DPIDs: a cold start and warm-up idle, city
driving, an on-ramp at wide-open throttle with knock retard, highway cruise
with the converter clutch locked, two passing pulls, an exit, more city, a
hard 1st-to-3rd pull, and a long hot idle with the fan and A/C cycling.

Usage: python make_sample_log.py [output.csv]
(default: UVScan_sample_drive.csv in Documents\\UVScan Logs)
"""

import math
import os
import random
import sys

HZ = 10
GEARS = [2.92, 1.57, 1.00, 0.705]   # 4T65E
FINAL = 3.05
TIRE_IN = 26.0                       # tire diameter, inches
RPM_PER_MPH = FINAL * 336 / TIRE_IN  # times the gear ratio

# (seconds, target mph, throttle style); speed ramps toward the target.
# style: idle, cruise, gentle, brisk, wot, coast
ROUTE = [
    (2, 0, 'off'),
    (150, 0, 'idle'),         # cold start, warm-up idle
    (20, 25, 'gentle'), (25, 25, 'cruise'), (12, 0, 'coast'), (15, 0, 'idle'),
    (18, 35, 'brisk'), (40, 35, 'cruise'), (10, 15, 'coast'), (12, 30, 'gentle'),
    (30, 30, 'cruise'), (12, 0, 'coast'), (25, 0, 'idle'),
    (15, 20, 'gentle'), (12, 72, 'wot'),          # on-ramp
    (240, 70, 'cruise'),
    (9, 92, 'wot'), (60, 75, 'cruise'),           # passing pull
    (180, 68, 'cruise'),
    (8, 88, 'wot'), (90, 70, 'cruise'),           # second pass
    (25, 35, 'coast'), (15, 0, 'coast'), (20, 0, 'idle'),   # exit, light
    (20, 40, 'brisk'), (60, 40, 'cruise'), (12, 0, 'coast'), (30, 0, 'idle'),
    (11, 62, 'wot'), (14, 30, 'coast'), (10, 0, 'coast'),   # hard 1-3 pull
    (15, 25, 'gentle'), (40, 25, 'cruise'), (12, 0, 'coast'),
    (240, 0, 'idle'),                              # hot idle, fan and A/C
    (3, 0, 'off'),
]

COLUMNS = [
    ('RPM', 'RPM'), ('MPH', 'MPH'), ('TPS', '%'), ('MAP', 'kPa'), ('MAF', 'g/s'),
    ('ECT', 'Deg F'), ('IAT', 'Deg F'), ('KR', 'Degrees'), ('Spark Adv', 'Degrees'),
    ('O2 B1S1', 'mV'), ('O2 B2S1', 'mV'), ('STFT', '%'), ('LTFT', '%'),
    ('Inj PW', 'ms'), ('IAC', 'Steps'), ('Gear', ''), ('TCC', ''), ('Fan 1', ''),
    ('A/C Relay', ''), ('IGN V', 'V'),
]


def onoff(b):
    return 'ON' if b else 'OFF'


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.expanduser('~'), 'Documents', 'UVScan Logs', 'UVScan_sample_drive.csv')
    rnd = random.Random(2001)

    # expand the route into a per-sample target / style
    steps = []
    for secs, mph, style in ROUTE:
        steps += [(mph, style)] * int(secs * HZ)

    mph = 0.0
    gear = 1
    ect = 58.0          # F, cold morning
    iat = 55.0
    ltft = 2.5
    stft = 0.0
    o2_phase = 0.0
    kr = 0.0
    fan = False
    ac = False
    tcc = False
    rpm = 0.0
    tps = 0.0
    shift_hold = 0
    rows = []
    t0 = 0.023
    for i, (target, style) in enumerate(steps):
        t = t0 + i / HZ
        running = style != 'off'
        # speed toward the target
        rate = {'gentle': 3.5, 'brisk': 6.0, 'wot': 9.5, 'coast': -6.0, 'cruise': 1.5, 'idle': -8, 'off': -8}[style]
        if target > mph:
            if style == 'wot':
                rate = [8.0, 5.0, 3.2, 2.0][gear - 1]  # mph a second at full throttle, by gear
            step = max(0.05, rate if rate > 0 else 2.0) / HZ
            mph = min(target, mph + step)
        elif target < mph:
            step = (abs(rate) if rate < 0 else 2.0) / HZ
            mph = max(target, mph - step)
        if style == 'cruise':
            mph += math.sin(t / 7.0) * 0.03 + rnd.uniform(-0.02, 0.02)
        mph = max(0.0, mph)

        # throttle
        if not running:
            want_tps = 0
        elif style == 'wot':
            want_tps = 96
        elif style == 'brisk':
            want_tps = 45
        elif style == 'gentle':
            want_tps = 22
        elif style == 'cruise':
            want_tps = 11 + mph * 0.12 + math.sin(t / 5.0) * 2
        else:
            want_tps = 0
        tps += (want_tps - tps) * (0.6 if style == 'wot' else 0.25)
        tps_out = max(0.0, tps + rnd.uniform(-0.3, 0.3)) if running else 0.0

        # gear: upshift points depend on throttle
        up = [0, 15, 28, 42] if tps < 30 else ([0, 38, 62, 95] if tps < 80 else [0, 999, 999, 999])
        if shift_hold > 0:
            shift_hold -= 1
        elif gear < 4 and (mph > up[gear] or mph * GEARS[gear - 1] * RPM_PER_MPH > 5000):  # WOT: shift at 5000
            gear += 1
            shift_hold = 8
        elif gear > 1 and mph < [0, 15, 28, 42][gear - 1] - 6:  # down: light-throttle points
            gear -= 1
            shift_hold = 8
        if tps > 80 and shift_hold == 0:  # kickdown
            if gear == 4 and mph < 85:
                gear, shift_hold = 3, 8
            elif gear == 3 and mph < 50:
                gear, shift_hold = 2, 8
        if mph < 1:
            gear = 1

        # converter clutch: locked in 3rd/4th at steady light throttle
        tcc = running and gear >= 3 and mph > 40 and tps < 30 and style == 'cruise'
        wheel_rpm = mph * GEARS[gear - 1] * RPM_PER_MPH
        warm = min(1.0, max(0.0, (ect - 60) / 100))
        idle_rpm = 1050 - 330 * warm + (40 if ac else 0)
        if not running:
            want_rpm = 0
        elif mph < 3:
            want_rpm = idle_rpm + (tps * 20)  # against the converter (stall about 2500)
        else:
            slip = 0 if tcc else min(1900, (120 + tps * 18) * max(0.15, 1 - mph / 35))
            want_rpm = max(idle_rpm, wheel_rpm + slip)
        rpm += (want_rpm - rpm) * (0.5 if running else 0.35)
        if running and mph < 3 and rpm < idle_rpm - 200:
            rpm = idle_rpm * 0.8  # cranking catches
        rpm_out = max(0.0, round((rpm + rnd.uniform(-6, 6)) * 4) / 4) if rpm > 50 else 0.0

        # load
        if not running:
            map_kpa = 98.5
        elif style == 'wot':
            map_kpa = 96 + rnd.uniform(-0.6, 0.6)
        elif style == 'coast' and mph > 5:
            map_kpa = 22 + rnd.uniform(-0.8, 0.8)
        else:
            map_kpa = 30 + tps * 0.62 + rnd.uniform(-0.7, 0.7) + (4 if ac else 0)
        map_kpa = min(100.0, map_kpa)
        maf = rpm_out * map_kpa / 100 * 3.8 * 0.0105 * (1 + rnd.uniform(-0.01, 0.01)) if running else 0.0

        # temperatures
        if running:
            heat = 0.012 + rpm_out / 3400 * 0.05
            cool = (0.0008 + mph / 70 * 0.03) * max(0, ect - 195) if not fan else 0.004 * max(0, ect - 190)
            ect += heat - (cool if ect > 195 else 0)
            if mph < 5 and ect > 195:
                ect += 0.03  # heat soak at idle
        if not fan and ect > 214:
            fan = True
        if fan and ect < 205:
            fan = False
        ect = min(ect, 228)
        iat_target = 60 + (ect - 60) * 0.18 + (22 if mph < 5 else 0) - mph * 0.08
        iat += (iat_target - iat) * 0.004
        # A/C: on after warm-up; cycles on the hot idle
        if t > 160:
            if style == 'idle' and t > 1200:
                ac = (int(t) // 25) % 2 == 0
            else:
                ac = True

        # knock retard: wide-open pulls at high load and heat
        if style == 'wot' and rpm_out > 2800 and rnd.random() < 0.12:
            kr = min(6.0, kr + rnd.choice([0.5, 1.0, 1.0, 1.5, 2.0]) * (1 + (iat - 70) / 80))
        else:
            kr = max(0.0, kr - 0.25)
        spark = 0.0
        if running:
            if mph < 3 and tps < 5:
                spark = 16 + rnd.uniform(-2, 2)
            elif style == 'wot':
                spark = 21 + rpm_out / 1000 - kr
            elif style == 'coast':
                spark = 28 + rnd.uniform(-1, 1)
            else:
                spark = 36 - map_kpa * 0.12 + rpm_out / 900 + rnd.uniform(-0.8, 0.8)

        # fuel: open loop cold / at WOT, decel fuel cut, closed loop switching otherwise
        closed = running and ect > 120 and style not in ('wot',) and not (style == 'coast' and mph > 8)
        o2_phase += (1.1 + rpm_out / 2500) / HZ * 2 * math.pi
        if not running:
            o2a = o2b = 450
        elif style == 'wot':
            o2a, o2b = 880 + rnd.uniform(-15, 15), 870 + rnd.uniform(-15, 15)
        elif style == 'coast' and mph > 8:
            o2a, o2b = 60 + rnd.uniform(0, 20), 55 + rnd.uniform(0, 20)
        elif not closed:
            o2a = o2b = 450 + rnd.uniform(-60, 60) if ect < 100 else 600
        else:
            o2a = 450 + 400 * math.tanh(4 * math.sin(o2_phase)) + rnd.uniform(-20, 20)
            o2b = 450 + 400 * math.tanh(4 * math.sin(o2_phase + 1.3)) + rnd.uniform(-20, 20)
        if closed:
            stft += (-0.9 if o2a > 450 else 0.9) + rnd.uniform(-0.4, 0.4)
            stft = max(-10, min(10, stft))
            ltft += (stft * 0.0004)
        else:
            stft *= 0.9
        ltft = max(-6, min(9, ltft))
        inj = (map_kpa / 100 * 7.8 * (1 + (stft + ltft) / 100) + 0.8) if running and not (style == 'coast' and mph > 8) else 0.0
        if running and not closed and ect < 120:
            inj *= 1 + (120 - ect) / 200   # cold enrichment
        iac = (40 + (1 - warm) * 45 + (12 if ac else 0) + (8 if fan else 0) + rnd.randint(-2, 2)) if running else 0
        if running and mph > 5:
            iac = max(0, iac - 15)
        volts = (14.15 - (0.25 if fan else 0) - (0.15 if ac else 0) + rnd.uniform(-0.05, 0.05)) if running else 12.4

        rows.append([
            f'{t:.3f}', f'{rpm_out:.2f}'.rstrip('0').rstrip('.') if rpm_out else '0', f'{mph:.1f}',
            f'{tps_out:.1f}', f'{map_kpa:.0f}', f'{maf:.2f}', f'{ect:.0f}', f'{iat:.0f}', f'{kr:.1f}',
            f'{spark:.1f}', f'{o2a:.0f}', f'{o2b:.0f}', f'{stft:.1f}', f'{ltft:.1f}', f'{inj:.2f}',
            str(int(iac)), str(gear if running else 0), onoff(tcc), onoff(fan), onoff(ac and running),
            f'{volts:.1f}',
        ])

    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, 'w', encoding='utf-8', newline='') as f:
        f.write('Time (s),' + ','.join(f'{n} ({u})' if u else n for n, u in COLUMNS) + '\r\n')
        for r in rows:
            f.write(','.join(r) + '\r\n')
    print(f'{out}: {len(rows)} rows, {len(rows) / HZ / 60:.1f} minutes, {len(COLUMNS)} channels')


if __name__ == '__main__':
    main()

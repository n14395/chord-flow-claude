#!/usr/bin/env python3
"""Generate a minimal SF2 SoundFont with a piano-like timbre.

Produces a multi-layered instrument with synthesised samples at C2, C3, C4, C5, C6
so AVAudioUnitSampler can pitch-shift between them for reasonable quality across
the keyboard. Each sample is a decaying harmonic series (~1.5 seconds, 44100 Hz, 16-bit mono).

Output: Xcode/ChordFlowApp/ChordFlowPiano.sf2
"""

import struct, math, os

SAMPLE_RATE = 44100
DURATION = 2.0  # seconds per sample
NUM_FRAMES = int(SAMPLE_RATE * DURATION)

# MIDI notes for each sample layer
LAYERS = [
    # (midi_note, name, key_lo, key_hi, root_key)
    (36, b"C2-Piano", 0, 44, 36),  # C2 covers low range
    (48, b"C3-Piano", 45, 56, 48),  # C3
    (60, b"C4-Piano", 57, 68, 60),  # C4 (middle C)
    (72, b"C5-Piano", 69, 80, 72),  # C5
    (84, b"C6-Piano", 81, 127, 84),  # C6 covers high range
]


def generate_sample(midi_note):
    """Generate a piano-like decaying tone for the given MIDI note."""
    hz = 440.0 * (2.0 ** ((midi_note - 69) / 12.0))
    frames = []
    for i in range(NUM_FRAMES):
        t = i / SAMPLE_RATE
        age = t

        # Envelope: fast attack, dual-stage decay (body + tail)
        attack = min(1.0, t / 0.005)
        body = 0.65 * math.exp(-age * 2.8)
        tail = 0.35 * math.exp(-age * 0.8)
        envelope = attack * (body + tail)

        # Timbre: rich harmonic series, brightness decays over time
        brightness = math.exp(-age * 4.0)
        bright2 = math.exp(-age * 8.0)

        angle = 2.0 * math.pi * hz * t
        s = math.sin(angle)  # fundamental
        s += 0.50 * brightness * math.sin(angle * 2.003)  # 2nd harmonic
        s += 0.35 * brightness * math.sin(angle * 3.001)  # 3rd harmonic
        s += 0.25 * bright2 * math.sin(angle * 4.009)  # 4th harmonic
        s += 0.15 * bright2 * math.sin(angle * 5.002)  # 5th harmonic
        s += 0.08 * bright2 * math.sin(angle * 6.013)  # 6th harmonic
        s += 0.04 * bright2 * math.sin(angle * 7.997)  # 8th harmonic

        # Slight inharmonicity for realism (higher partials sharper)
        s += 0.03 * bright2 * math.sin(angle * 10.05)
        s += 0.015 * bright2 * math.sin(angle * 12.08)

        sample = s * envelope * 0.45  # headroom
        sample = max(-1.0, min(1.0, sample))
        frames.append(int(sample * 32000))  # 16-bit range with margin

    return frames


def pack_samples(all_frames):
    """Pack all sample frames as little-endian 16-bit PCM."""
    data = b""
    for frame_list in all_frames:
        for s in frame_list:
            data += struct.pack("<h", s)
    return data


def pad_to_even(data):
    """SF2 chunks must be even-length."""
    if len(data) % 2:
        data += b"\x00"
    return data


def make_chunk(tag, data):
    data = pad_to_even(data)
    return tag + struct.pack("<I", len(data)) + data


def make_list(tag, contents):
    inner = tag + contents
    inner = pad_to_even(inner)
    return b"LIST" + struct.pack("<I", len(inner)) + inner


def build_sf2(sample_data_list):
    """Build a complete SF2 file."""
    num_layers = len(LAYERS)

    # ---- Sample data (smpl sub-chunk) ----
    # Each sample is followed by 46 zero frames (loop point padding required by SF2 spec)
    PADDING = 46
    raw_pcm = b""
    sample_offsets = []  # (start_frame, end_frame)
    current_frame = 0
    for frames in sample_data_list:
        start = current_frame
        end = current_frame + len(frames) - 1
        sample_offsets.append((start, end))
        for s in frames:
            raw_pcm += struct.pack("<h", s)
        # Padding zeros
        raw_pcm += b"\x00\x00" * PADDING
        current_frame += len(frames) + PADDING

    smpl_chunk = make_chunk(b"smpl", raw_pcm)
    sdta = make_list(b"sdta", smpl_chunk)

    # ---- INFO sub-chunks ----
    info_data = b""
    info_data += make_chunk(b"ifil", struct.pack("<HH", 2, 1))  # SF2 v2.1
    info_data += make_chunk(b"isng", b"EMU8000\x00")
    info_data += make_chunk(b"INAM", b"ChordFlow Piano\x00")
    info = make_list(b"INFO", info_data)

    # ---- Preset/Instrument/Sample headers (pdta) ----
    # We build the required 9 sub-chunks of pdta.

    # -- phdr: preset headers --
    # One preset "Piano" + terminal
    phdr = b""
    preset_name = b"Piano\x00" + b"\x00" * (20 - 6)  # 20 chars
    phdr += preset_name
    phdr += struct.pack("<HH", 0, 0)  # preset, bank
    phdr += struct.pack("<H", 0)  # presetBagNdx
    phdr += struct.pack("<III", 0, 0, 0)  # library, genre, morphology
    # Terminal
    phdr += b"EOP\x00" + b"\x00" * 16
    phdr += struct.pack("<HH", 0, 0)
    phdr += struct.pack("<H", 1)  # presetBagNdx = 1 (points past last bag)
    phdr += struct.pack("<III", 0, 0, 0)
    phdr_chunk = make_chunk(b"phdr", phdr)

    # -- pbag: preset bags --
    # One bag for the preset + terminal
    pbag = b""
    pbag += struct.pack("<HH", 0, 0)  # genNdx=0, modNdx=0
    pbag += struct.pack("<HH", 1, 0)  # terminal: genNdx=1, modNdx=0
    pbag_chunk = make_chunk(b"pbag", pbag)

    # -- pmod: preset modulators (empty) --
    pmod = struct.pack("<HHHHH", 0, 0, 0, 0, 0)  # terminal
    pmod_chunk = make_chunk(b"pmod", pmod)

    # -- pgen: preset generators --
    # One generator: instrument index = 0
    pgen = b""
    pgen += struct.pack("<HH", 41, 0)  # genOper=41 (instrument), value=0
    pgen += struct.pack("<HH", 0, 0)  # terminal
    pgen_chunk = make_chunk(b"pgen", pgen)

    # -- inst: instrument headers --
    inst = b""
    inst_name = b"Piano\x00" + b"\x00" * (20 - 6)
    inst += inst_name
    inst += struct.pack("<H", 0)  # instBagNdx
    # Terminal
    inst += b"EOI\x00" + b"\x00" * 16
    inst += struct.pack("<H", num_layers)  # points past last bag
    inst_chunk = make_chunk(b"inst", inst)

    # -- ibag: instrument bags --
    # One bag per sample layer + terminal
    ibag = b""
    gen_ndx = 0
    for i in range(num_layers):
        ibag += struct.pack("<HH", gen_ndx, 0)
        gen_ndx += 4  # each zone has 4 generators
    ibag += struct.pack("<HH", gen_ndx, 0)  # terminal
    ibag_chunk = make_chunk(b"ibag", ibag)

    # -- imod: instrument modulators (empty) --
    imod = struct.pack("<HHHHH", 0, 0, 0, 0, 0)  # terminal
    imod_chunk = make_chunk(b"imod", imod)

    # -- igen: instrument generators --
    igen = b""
    for i, (midi_note, name, key_lo, key_hi, root_key) in enumerate(LAYERS):
        # keyRange
        igen += struct.pack("<HBB", 43, key_lo, key_hi)  # genOper=43 keyRange
        # overridingRootKey
        igen += struct.pack("<HH", 58, root_key)  # genOper=58
        # releaseVolEnv (longer release for piano-like sustain, in timecents)
        igen += struct.pack("<Hh", 38, -3000)  # genOper=38, ~350ms release
        # sampleID
        igen += struct.pack("<HH", 53, i)  # genOper=53 sampleID
    # Terminal
    igen += struct.pack("<HH", 0, 0)
    igen_chunk = make_chunk(b"igen", igen)

    # -- shdr: sample headers --
    shdr = b""
    for i, (midi_note, name, key_lo, key_hi, root_key) in enumerate(LAYERS):
        start, end = sample_offsets[i]
        loop_start = start
        loop_end = end
        padded_name = name + b"\x00" * (20 - len(name))
        shdr += padded_name
        shdr += struct.pack("<I", start)  # start
        shdr += struct.pack("<I", end)  # end
        shdr += struct.pack("<I", loop_start)  # startLoop
        shdr += struct.pack("<I", loop_end)  # endLoop
        shdr += struct.pack("<I", SAMPLE_RATE)  # sampleRate
        shdr += struct.pack("<B", root_key)  # originalPitch
        shdr += struct.pack("<b", 0)  # pitchCorrection
        shdr += struct.pack("<H", 0)  # sampleLink
        shdr += struct.pack("<H", 1)  # sampleType = monoSample
    # Terminal
    shdr += b"EOS\x00" + b"\x00" * 16
    shdr += struct.pack("<IIIII", 0, 0, 0, 0, 0)
    shdr += struct.pack("<B", 0)
    shdr += struct.pack("<b", 0)
    shdr += struct.pack("<H", 0)
    shdr += struct.pack("<H", 0)
    shdr_chunk = make_chunk(b"shdr", shdr)

    # Assemble pdta
    pdta_contents = (
        phdr_chunk
        + pbag_chunk
        + pmod_chunk
        + pgen_chunk
        + inst_chunk
        + ibag_chunk
        + imod_chunk
        + igen_chunk
        + shdr_chunk
    )
    pdta = make_list(b"pdta", pdta_contents)

    # Assemble RIFF
    riff_body = info + sdta + pdta
    riff = (
        b"RIFF" + struct.pack("<I", len(b"sfbk") + len(riff_body)) + b"sfbk" + riff_body
    )
    return riff


def main():
    print("Generating piano samples...")
    sample_data = []
    for midi_note, name, _, _, _ in LAYERS:
        print(f"  {name.decode()} (MIDI {midi_note})...")
        frames = generate_sample(midi_note)
        sample_data.append(frames)

    print("Building SF2...")
    sf2 = build_sf2(sample_data)

    out_dir = os.path.join(os.path.dirname(__file__), "Xcode", "ChordFlowApp")
    out_path = os.path.join(out_dir, "ChordFlowPiano.sf2")
    with open(out_path, "wb") as f:
        f.write(sf2)

    size_kb = len(sf2) / 1024
    print(f"Wrote {out_path} ({size_kb:.1f} KB)")


if __name__ == "__main__":
    main()

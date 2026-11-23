"""Read public recording previews and encode the radio with libsndfile."""

from array import array
import ctypes
from ctypes.util import find_library
import os

SFM_READ = 0x10
SFM_WRITE = 0x20
SF_FORMAT_OGG_VORBIS = 0x200060


class AudioInfo(ctypes.Structure):
    _fields_ = [
        ("frames", ctypes.c_int64), ("samplerate", ctypes.c_int),
        ("channels", ctypes.c_int), ("format", ctypes.c_int),
        ("sections", ctypes.c_int), ("seekable", ctypes.c_int),
    ]


def library():
    name = find_library("sndfile")
    if not name:
        raise RuntimeError("Install libsndfile to build the audio assets.")
    lib = ctypes.CDLL(name)
    lib.sf_open.argtypes = (ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(AudioInfo))
    lib.sf_open.restype = ctypes.c_void_p
    lib.sf_close.argtypes = (ctypes.c_void_p,)
    lib.sf_strerror.argtypes = (ctypes.c_void_p,)
    lib.sf_strerror.restype = ctypes.c_char_p
    lib.sf_seek.argtypes = (ctypes.c_void_p, ctypes.c_int64, ctypes.c_int)
    lib.sf_seek.restype = ctypes.c_int64
    for operation in (lib.sf_readf_float, lib.sf_writef_float):
        operation.argtypes = (ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int64)
        operation.restype = ctypes.c_int64
    return lib


def open_file(lib, path, mode, info):
    sound = lib.sf_open(os.fsencode(path), mode, ctypes.byref(info))
    if not sound:
        raise OSError(f"{path}: {lib.sf_strerror(None).decode()}")
    return sound


def read_mono(path, start=0.0, seconds=None):
    lib = library()
    info = AudioInfo()
    sound = open_file(lib, path, SFM_READ, info)
    try:
        first = round(start * info.samplerate)
        frames = info.frames - first if seconds is None else round(seconds * info.samplerate)
        frames = min(frames, info.frames - first)
        if frames <= 0 or lib.sf_seek(sound, first, os.SEEK_SET) != first:
            raise ValueError(f"Invalid sample region in {path}")
        block = (ctypes.c_float * (frames * info.channels))()
        count = lib.sf_readf_float(sound, block, frames)
        if count <= 0:
            raise OSError(f"Could not read audio from {path}")
    finally:
        lib.sf_close(sound)
    if info.channels == 1:
        samples = array("f", block[:count])
    else:
        samples = array("f", (sum(block[i:i + info.channels]) / info.channels
                              for i in range(0, count * info.channels, info.channels)))
    return info.samplerate, samples


def write_vorbis(path, left, right, rate):
    lib = library()
    info = AudioInfo(samplerate=rate, channels=2, format=SF_FORMAT_OGG_VORBIS)
    sound = open_file(lib, path, SFM_WRITE, info)
    try:
        for start in range(0, len(left), 4096):
            end = min(start + 4096, len(left))
            packed = array("f", [0.0]) * ((end - start) * 2)
            packed[0::2] = left[start:end]
            packed[1::2] = right[start:end]
            block = (ctypes.c_float * len(packed)).from_buffer(packed)
            if lib.sf_writef_float(sound, block, end - start) != end - start:
                raise OSError(f"Could not write audio to {path}")
    finally:
        lib.sf_close(sound)
